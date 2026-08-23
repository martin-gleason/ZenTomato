import Foundation

/// The one place bytes actually leave the device.
///
/// WHY THIS EXISTS AS A SEPARATE, TINY THING
/// Everything else about talking to Todoist — which address, which method,
/// which page, what a 401 means — is ordinary logic that can be checked by a
/// test. *Actually sending a request over the network* cannot: a test that did
/// it would need a Todoist account, a connection, and somebody's real tasks,
/// and it would fail on a train for reasons that had nothing to do with the
/// code. So sending is separated out behind this one-method description, the
/// real implementation is used only by the app, and every test hands the client
/// a stand-in that returns prepared answers and writes down what it was asked
/// for.
///
/// **No test in this project constructs `URLSessionTransport`, and no test
/// touches the network.** That is not a convention; it is the reason the seam
/// is here.
///
/// `Sendable` marks it safe to use from any thread, which everything on this
/// side of the app is: nothing here goes near the database.
protocol TodoistTransport: Sendable {
  /// Sends one prepared request and hands back the answer.
  ///
  /// - Parameter request: a request built by `TodoistClient`, which is the only
  ///   thing in the codebase that builds one.
  /// - Returns: the body, and the HTTP response it came with.
  /// - Throws: whatever the network layer throws — most usefully `URLError`,
  ///   which is how "there is no connection" arrives.
  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// The real one: Apple's networking, with its own private session.
///
/// **It holds its own session rather than using the shared one.** A shared
/// session is reachable from anywhere, including from a test that meant to use
/// the stand-in, and a test that can reach the network is a test that will one
/// day reach it by accident. Its own session cannot be got at from anywhere
/// else.
struct URLSessionTransport: TodoistTransport {
  // MARK: The session

  private let session: URLSession

  /// Builds a transport with a session configured the way Todoist's own
  /// documentation describes its side of the conversation.
  ///
  /// The 15-second ceiling is not a guess: Todoist publishes a *"standard
  /// request processing timeout"* of 15 seconds, so a request still waiting
  /// after that is not going to be answered, and waiting longer only means the
  /// person watches a spinner for longer.
  init() {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 15
    // The refresh is either fresh or it is the cache; a stale copy held by the
    // networking layer would be a third answer nobody asked for.
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    session = URLSession(configuration: configuration)
  }

  // MARK: Sending

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      // Not reachable over HTTPS, but the type system cannot know that, and the
      // alternative spelling is the force-cast this project forbids.
      throw TodoistError.malformedResponse
    }
    return (data, http)
  }
}
