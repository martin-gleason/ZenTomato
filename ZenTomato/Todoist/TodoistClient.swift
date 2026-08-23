import Foundation

/// Every conversation this app has with Todoist.
///
/// WHAT IT DOES, AND THE ONE SENTENCE THAT MATTERS
/// It reads three lists — projects, sections, tasks — and it can close one
/// task. **That is all it can do, and the design is what makes that a fact
/// rather than a claim:**
///
///   * there is exactly one place in this whole codebase where a request is
///     built, and it is `makeRequest` below;
///   * the method of that request is never chosen there. It comes from the
///     address it is being sent to, and the four addresses live in
///     `TodoistAPI`, where exactly one of them is a write;
///   * **the request never carries a body.** Not "does not today" — there is no
///     line in this file that could put one on. Creating a task means sending
///     one, so a client with no body-writing code cannot grow into one by
///     accident.
///
/// WHAT IT DELIBERATELY CANNOT SEE
/// It never touches the database. It reads a token, sends bytes, and hands back
/// plain immutable values; storing any of that is somebody else's job, one layer
/// up. That separation is what lets the whole of this file run off the main
/// thread while every database row in the app stays on it.
///
/// It is a `struct`, so it holds nothing that can change, and `Sendable`, so it
/// can be used from any thread at once.
struct TodoistClient: Sendable {
  // MARK: The three things it is handed

  /// Where bytes actually go. Real in the app; a stand-in with prepared answers
  /// in every test.
  private let transport: any TodoistTransport

  /// Where the token comes from. The client reads it for each request and never
  /// keeps a copy — one fewer place a credential can be found.
  private let tokens: any TokenStore

  /// How the single retry waits. Real in the app; a recorder that returns at
  /// once in tests, so no test ever pauses.
  private let waiting: any TodoistRetryWaiting

  /// The ceiling on how many pages one list may be fetched in.
  ///
  /// 250 pages at 200 rows is 50,000 rows — past any real account. It exists
  /// for a server that keeps saying "there is more": without it the refresh
  /// would spin forever behind a spinner, with no error and nothing on screen.
  /// Reaching the ceiling fails loudly instead.
  private static let pageCap = 250

  init(
    transport: any TodoistTransport,
    tokens: any TokenStore,
    waiting: any TodoistRetryWaiting = SystemRetryWaiting()) {
    self.transport = transport
    self.tokens = tokens
    self.waiting = waiting
  }

  // MARK: Reading

  /// Every project on the account, in Todoist's own order.
  func fetchProjects() async throws -> [TodoistProjectDTO] {
    try await fetchEveryPage(of: TodoistProjectDTO.self, from: TodoistAPI.projects)
  }

  /// Every section of every project.
  func fetchSections() async throws -> [TodoistSectionDTO] {
    try await fetchEveryPage(of: TodoistSectionDTO.self, from: TodoistAPI.sections)
  }

  /// Every open task on the account.
  ///
  /// **All of them, with no filter.** The spec requires the picker to show
  /// everything, so there is nothing to narrow down here — and a filter applied
  /// at this end would be a decision about somebody's tasks that this app has no
  /// business making.
  func fetchTasks() async throws -> [TodoistTaskDTO] {
    try await fetchEveryPage(of: TodoistTaskDTO.self, from: TodoistAPI.tasks)
  }

  // MARK: The one write

  /// Ticks one task off in Todoist.
  ///
  /// **This is the only non-reading request this app can make.** One request,
  /// no body, no check beforehand and no check afterwards: a request sent to
  /// confirm the first one would be a second thing that could fail, and it could
  /// not tell us anything the answer to the first one did not.
  ///
  /// - Parameter id: the task's opaque Todoist identifier.
  /// - Throws: `TodoistError.server(status: 404)` when the task is not there any
  ///   more — which means it was finished or deleted somewhere else, and the two
  ///   cannot be told apart. `.tokenRejected`, `.offline` and the rest as usual.
  func closeTask(id: String) async throws {
    // THE ONE PIECE OF A REQUEST THAT IS ASSEMBLED AT RUNTIME, AND THE ONE
    // CHECK THAT KEEPS IT SEALED.
    //
    // Every address this app can name is a constant except this identifier,
    // which arrives from a Todoist answer. Building a web address does not
    // remove dot segments — `a/../..` stays exactly that — so an odd identifier
    // could point the request at a different address from the one written here.
    // Today it still could not reach a write, because the identifier is
    // substituted *before* a literal `/close` and no Todoist write address ends
    // that way. That is an accident of the shape rather than a guarantee, so the
    // identifier is checked instead: Todoist documents these as opaque strings
    // such as `6XGgmFVcrG5RRjVr`, and anything else is refused before a request
    // exists.
    guard TodoistAPI.isOpaqueIdentifier(id) else { throw TodoistError.malformedResponse }

    // The answer's body is documented as an empty object. It is deliberately
    // not decoded: there is nothing in it, and a decoder here would be a way for
    // a future field to start meaning something.
    _ = try await perform(TodoistAPI.closeTask(id: id), cursor: nil)
  }

  // MARK: Following pages

  /// Fetches one list to exhaustion, following Todoist's cursors.
  ///
  /// HOW TODOIST'S PAGING WORKS, AND THE TRAP IN IT
  /// Each answer carries some rows and, sometimes, a marker meaning "ask again
  /// with this". The list is finished when there is no marker — **and by no
  /// other sign**. In particular a page with fewer rows than were asked for is
  /// not the end; Todoist's documentation says so explicitly, and a loop that
  /// assumed otherwise would quietly drop the tail of a large account's tasks.
  ///
  /// Duplicate rows are possible when somebody edits Todoist mid-fetch, and the
  /// documentation says to expect them. They are not dealt with here: the cache
  /// keys every row by its identifier when it stores them, so two copies of one
  /// row collapse into one there, in one place, rather than being guarded
  /// against in three.
  private func fetchEveryPage<Element: Decodable & Sendable>(
    of type: Element.Type,
    from endpoint: TodoistAPI.Endpoint) async throws -> [Element] {
    var rows: [Element] = []
    var cursor: String?
    var pagesFetched = 0

    while true {
      guard pagesFetched < Self.pageCap else { throw TodoistError.paginationDidNotTerminate }
      pagesFetched += 1

      let data = try await perform(endpoint, cursor: cursor)
      let page: TodoistPage<Element>
      do {
        page = try JSONDecoder().decode(TodoistPage<Element>.self, from: data)
      } catch {
        // The decoding error is deliberately dropped rather than wrapped: its
        // description quotes the data it choked on, and data from the wire is
        // the one thing this app's errors never carry.
        throw TodoistError.malformedResponse
      }
      rows.append(contentsOf: page.results)

      // An empty marker is treated as no marker. The documented end is `null`,
      // but an empty piece of text would send the loop round for a page that
      // cannot exist.
      guard let next = page.nextCursor, !next.isEmpty else { return rows }
      cursor = next
    }
  }

  // MARK: One request, and what its answer means

  /// Sends one request and turns Todoist's answer into either a body or a
  /// named failure.
  ///
  /// THE RETRY, AND WHY THERE IS EXACTLY ONE — AND WHY READS ONLY
  /// When Todoist answers "slow down" it usually says for how long. If that is a
  /// sane wait — a minute or less — the request is made once more after waiting,
  /// and once more only. An automatic retry that kept going would be a hang
  /// rather than a courtesy: this runs inside a refresh somebody is watching,
  /// and it would sit there with a spinner instead of telling them what
  /// happened.
  ///
  /// **The retry is bound to the method, and it is the read method.** Re-sending
  /// a read costs nothing: the answer is the same list. Re-sending the close
  /// would be a second write to somebody's real account that nobody asked for
  /// and nobody can see — and Todoist's own documentation for that address says
  /// a recurring task is *"scheduled to its next occurrence"*, so closing twice
  /// silently skips a day. One tap must mean one close, so a rate-limited close
  /// falls straight through to the failure below and the retry is a person
  /// tapping the button again. `oneTapOnCompleteIsOneCloseEvenWhenRateLimited`
  /// fails the moment this condition loses its first clause.
  private func perform(_ endpoint: TodoistAPI.Endpoint, cursor: String?) async throws -> Data {
    let request = try makeRequest(endpoint, cursor: cursor)
    let (data, response) = try await send(request)

    if endpoint.method == .get,
       response.statusCode == 429,
       let delay = Self.retryDelay(from: response),
       delay <= .seconds(60) {
      try await waiting.wait(for: delay)
      let (retriedData, retriedResponse) = try await send(request)
      return try body(retriedData, response: retriedResponse)
    }

    return try body(data, response: response)
  }

  /// Hands the request to the transport, and turns the network layer's own
  /// failures into this app's vocabulary.
  private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    do {
      return try await transport.send(request)
    } catch let error as URLError {
      // Only the numeric code is kept. A `URLError` carries the address that
      // failed, and an address is the sort of thing that ends up in a log.
      if Self.offlineCodes.contains(error.code) { throw TodoistError.offline }
      throw TodoistError.server(status: error.errorCode)
    }
  }

  /// Turns one answer into a body, or into the failure it represents.
  private func body(_ data: Data, response: HTTPURLResponse) throws -> Data {
    switch response.statusCode {
    case 200..<300:
      return data

    case 401:
      // The token was revoked or regenerated in Todoist, and the old one stops
      // working the moment that happens. Removing it here is what sends the
      // person to the screen that asks for a new one; the cache, the plan and
      // the completion history are all left exactly as they are, because a
      // credential going stale is not a decision to disconnect.
      do {
        try tokens.clear()
      } catch {
        // Nothing useful can be done about a Keychain that refuses to delete,
        // and the failure that matters is the one being thrown next. It is
        // swallowed here deliberately, not by omission.
      }
      throw TodoistError.tokenRejected

    case 429:
      throw TodoistError.rateLimited(retryAfter: Self.retryDelay(from: response))

    default:
      throw TodoistError.server(status: response.statusCode)
    }
  }

  // MARK: Building the request — the only place in the app that does

  /// Builds one request: the address, the method, and two headers.
  ///
  /// **It never sets a body.** See the note at the top of this file.
  ///
  /// - Throws: `TodoistError.notSignedIn` when there is no usable token.
  private func makeRequest(_ endpoint: TodoistAPI.Endpoint, cursor: String?) throws -> URLRequest {
    let stored: String?
    do {
      stored = try tokens.read()
    } catch {
      // The Keychain refused. There is no usable credential either way, and the
      // only honest thing the app can do is ask for a new one — which is what
      // this failure makes it do. The Keychain's own status code is deliberately
      // not carried forward: it would end up in front of somebody who could do
      // nothing with it, and this app's failures carry nothing from the place a
      // credential is kept.
      throw TodoistError.notSignedIn
    }
    let token = stored?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !token.isEmpty else { throw TodoistError.notSignedIn }

    var url = TodoistAPI.baseURL.appending(path: endpoint.path)
    if endpoint.method == .get {
      var query = [URLQueryItem(name: "limit", value: String(TodoistAPI.pageSize))]
      if let cursor {
        // Passed back exactly as it arrived. The documentation is explicit that
        // a cursor must not be decoded, parsed or modified — and it is never
        // saved anywhere, because it is meaningless a few minutes later.
        query.append(URLQueryItem(name: "cursor", value: cursor))
      }
      url = url.appending(queryItems: query)
    }

    var request = URLRequest(url: url)
    request.httpMethod = endpoint.method.rawValue
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  // MARK: Small facts about the network

  /// How long Todoist asked us to wait, if it said.
  ///
  /// Todoist sends the number of seconds in a `Retry-After` header, and the same
  /// number again inside the body. The header is read because it is the standard
  /// place and because reading it does not mean decoding a body that may not be
  /// the shape we expect.
  private static func retryDelay(from response: HTTPURLResponse) -> Duration? {
    guard let value = response.value(forHTTPHeaderField: "Retry-After"),
          let seconds = Int(value.trimmingCharacters(in: .whitespaces)),
          seconds >= 0 else {
      return nil
    }
    return .seconds(seconds)
  }

  /// The network failures that mean "this never reached Todoist".
  ///
  /// They are grouped because the app says the same true thing about all of
  /// them — nothing happened at the other end, so a task is still open — and
  /// because that sentence is the whole reason a person can trust the Complete
  /// button.
  private static let offlineCodes: Set<URLError.Code> = [
    .notConnectedToInternet,
    .networkConnectionLost,
    .timedOut,
    .cannotFindHost,
    .cannotConnectToHost,
    .dataNotAllowed,
    .internationalRoamingOff
  ]
}
