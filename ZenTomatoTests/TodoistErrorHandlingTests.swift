import Foundation
import Testing

@testable import ZenTomato

/// Tests for what the app does when Todoist says no.
///
/// Four situations, and each is handled differently on purpose:
///
///   * **the token was refused** — it is thrown away, because it was revoked or
///     regenerated in Todoist and will never work again;
///   * **slow down** — one retry, after the wait Todoist asked for, and never a
///     second;
///   * **no connection** — nothing happened at the other end, which is the fact
///     every screen goes on to state;
///   * **nobody has connected an account** — no request is attempted at all.
///
/// And running through all of them, the property this file exists to protect:
/// **no failure carries a character of the token.**
@Suite("TodoistErrorHandling")
struct TodoistErrorHandlingTests {
  // MARK: A refused token

  /// A refusal throws the credential away.
  ///
  /// A token that used to work and stopped was revoked or regenerated in
  /// Todoist, and the old one stops working the instant that happens. Keeping it
  /// would mean every later request failed the same way, silently, forever.
  @Test("unauthorizedClearsToken")
  func unauthorizedClearsToken() async throws {
    let tokens = InMemoryTokenStore()
    let stub = StubTodoistTransport(answers: [.bare(status: 401)])
    let client = TodoistClient(transport: stub, tokens: tokens, waiting: RecordingRetryWaiting())

    await #expect(throws: TodoistError.tokenRejected) {
      _ = try await client.fetchProjects()
    }
    #expect(tokens.holdsAToken == false)
  }

  // MARK: Being asked to slow down

  /// One retry, after exactly the wait Todoist asked for.
  ///
  /// **Nothing in this test waits.** The waiting is a stand-in that writes down
  /// what it was asked for and returns at once, so the assertion is on the app's
  /// decision rather than on a stopwatch.
  @Test("rateLimitBacksOff")
  func rateLimitBacksOff() async throws {
    let waiting = RecordingRetryWaiting()
    let stub = StubTodoistTransport(answers: [
      .bare(status: 429, headers: ["Retry-After": "3"]),
      .page(rows: [StubTodoistTransport.projectRow(id: "p1", name: "Deep work")])
    ])
    let client = TodoistClient(transport: stub, tokens: InMemoryTokenStore(), waiting: waiting)

    let projects = try await client.fetchProjects()

    #expect(projects.map(\.id) == ["p1"])
    #expect(waiting.requestedWaits == [.seconds(3)])
    #expect(stub.recordedRequests.count == 2)
  }

  /// Two refusals in a row give up. There is no second retry, ever.
  ///
  /// An unbounded backoff inside a refresh somebody is watching is a hang
  /// wearing the costume of politeness.
  @Test("rateLimitDoesNotRetryForever")
  func rateLimitDoesNotRetryForever() async throws {
    let waiting = RecordingRetryWaiting()
    let stub = StubTodoistTransport(answers: [
      .bare(status: 429, headers: ["Retry-After": "3"]),
      .bare(status: 429, headers: ["Retry-After": "3"])
    ])
    let client = TodoistClient(transport: stub, tokens: InMemoryTokenStore(), waiting: waiting)

    await #expect(throws: TodoistError.rateLimited(retryAfter: .seconds(3))) {
      _ = try await client.fetchProjects()
    }
    #expect(waiting.requestedWaits.count == 1)
    #expect(stub.recordedRequests.count == 2)
  }

  /// A wait longer than a minute is not waited out. The person is told instead.
  @Test("rateLimitBeyondTheCeilingIsReportedNotSlept")
  func rateLimitBeyondTheCeilingIsReportedNotSlept() async throws {
    let waiting = RecordingRetryWaiting()
    let stub = StubTodoistTransport(answers: [.bare(status: 429, headers: ["Retry-After": "3600"])])
    let client = TodoistClient(transport: stub, tokens: InMemoryTokenStore(), waiting: waiting)

    await #expect(throws: TodoistError.rateLimited(retryAfter: .seconds(3600))) {
      _ = try await client.fetchProjects()
    }
    #expect(waiting.requestedWaits.isEmpty)
    #expect(stub.recordedRequests.count == 1)
  }

  /// With no wait named, nothing is retried and nothing is guessed at.
  @Test("rateLimitWithNoRetryAfterIsNotRetried")
  func rateLimitWithNoRetryAfterIsNotRetried() async throws {
    let waiting = RecordingRetryWaiting()
    let stub = StubTodoistTransport(answers: [.bare(status: 429)])
    let client = TodoistClient(transport: stub, tokens: InMemoryTokenStore(), waiting: waiting)

    await #expect(throws: TodoistError.rateLimited(retryAfter: nil)) {
      _ = try await client.fetchProjects()
    }
    #expect(waiting.requestedWaits.isEmpty)
    #expect(stub.recordedRequests.count == 1)
  }

  // MARK: No connection

  /// The failures that mean "this never got there" all arrive as one thing, so
  /// that every screen can say the same true sentence about them.
  @Test("networkFailuresAreReportedAsOffline", arguments: [
    URLError.Code.notConnectedToInternet,
    .networkConnectionLost,
    .timedOut,
    .cannotConnectToHost
  ])
  func networkFailuresAreReportedAsOffline(code: URLError.Code) async throws {
    let stub = StubTodoistTransport(answers: [.failure(URLError(code))])
    let client = TodoistClient(
      transport: stub,
      tokens: InMemoryTokenStore(),
      waiting: RecordingRetryWaiting())

    await #expect(throws: TodoistError.offline) {
      _ = try await client.fetchProjects()
    }
  }

  // MARK: No account

  /// With no token stored, no request is even attempted.
  ///
  /// The count is the interesting half. Failing after sending a request without
  /// a credential would put a pointless call on somebody's rate budget and, in
  /// the close case, would be a write attempted with no account behind it.
  @Test("noTokenMeansNoRequest")
  func noTokenMeansNoRequest() async throws {
    let stub = StubTodoistTransport(answers: [])
    let client = TodoistClient(
      transport: stub,
      tokens: InMemoryTokenStore(token: nil),
      waiting: RecordingRetryWaiting())

    await #expect(throws: TodoistError.notSignedIn) {
      _ = try await client.fetchProjects()
    }
    #expect(stub.recordedRequests.isEmpty)
  }

  // MARK: The credential never appears

  /// No failure this app can produce says any part of the token, in any of the
  /// three ways a value gets read out of an error.
  ///
  /// THE ROUTE THIS IS GUARDING, WHICH IS NOT `print`
  /// Nobody writes the token to a log on purpose. What happens is that a failure
  /// carries the request it failed on "for debugging", or the system's own
  /// network error is passed through and its description quotes the address —
  /// and the address is one header away from the credential. The check is
  /// therefore made against every case of the failure type, including the ones
  /// that carry a value, and against a failure produced by a real request made
  /// with a real header.
  @Test("tokenNeverAppearsInErrors")
  func tokenNeverAppearsInErrors() async throws {
    let token = "not-a-real-token"
    let stub = StubTodoistTransport(answers: [.bare(status: 500)])
    let client = TodoistClient(
      transport: stub,
      tokens: InMemoryTokenStore(token: token),
      waiting: RecordingRetryWaiting())

    // The request really was made, and really did carry the credential, so this
    // is not a test of a code path nobody uses.
    var thrown: (any Error)?
    do {
      _ = try await client.fetchProjects()
    } catch {
      thrown = error
    }
    let failure = try #require(thrown)
    #expect(stub.recordedRequests.count == 1)
    #expect(
      stub.recordedRequests[0].value(forHTTPHeaderField: "Authorization")?.contains(token) == true)

    for text in Self.readableForms(of: failure) {
      #expect(text.localizedCaseInsensitiveContains(token) == false)
      #expect(text.localizedCaseInsensitiveContains("authorization") == false)
      #expect(text.localizedCaseInsensitiveContains("bearer") == false)
    }

    // And the same for every failure the app can name, not only the one just
    // produced.
    let everyFailure: [TodoistError] = [
      .notSignedIn,
      .tokenRejected,
      .rateLimited(retryAfter: .seconds(3)),
      .rateLimited(retryAfter: nil),
      .offline,
      .server(status: 500),
      .malformedResponse,
      .paginationDidNotTerminate
    ]
    for failure in everyFailure {
      for text in Self.readableForms(of: failure) {
        #expect(text.isEmpty == false)
        #expect(text.localizedCaseInsensitiveContains(token) == false)
        #expect(text.localizedCaseInsensitiveContains("bearer") == false)
      }
    }
  }

  /// The three ways a failure ends up as words on a screen or in a log.
  private static func readableForms(of error: any Error) -> [String] {
    [
      String(describing: error),
      error.localizedDescription,
      (error as? any LocalizedError)?.errorDescription ?? "—"
    ]
  }
}
