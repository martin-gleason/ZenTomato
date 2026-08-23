import Foundation

/// Everything that can go wrong between this app and Todoist, named.
///
/// THE ONE PROPERTY THIS TYPE IS JUDGED ON: **NO CASE CARRIES THE TOKEN.**
/// Not the token, not the request it was attached to, not the response body,
/// and not a web address that could have one in it. Every value below is either
/// nothing at all, a number, or a length of time. That is not a promise made in
/// prose — it is visible in the seven lines of declarations, and
/// `tokenNeverAppearsInErrors` reads every case's text and checks it.
///
/// WHY THAT MATTERS MORE HERE THAN ANYWHERE ELSE
/// The secret scanner that runs before every commit catches a credential
/// *committed to the repository*. It cannot catch one printed into a crash log,
/// a console line, or an error message shown on screen — and the most likely
/// route for that is not somebody writing `print(token)`. It is an error type
/// that quietly carries the request it failed on, and a description that helpfully
/// prints it out. So the errors carry nothing, and the messages are written by
/// hand rather than borrowed from the system.
///
/// `Equatable` is here so tests can say "this exact failure" rather than
/// matching on text.
enum TodoistError: Error, Equatable {
  /// There is no token in the Keychain, so no request can be made at all. Not a
  /// failure of anything — it is the state of an app nobody has connected yet.
  case notSignedIn

  /// Todoist refused the token: HTTP 401.
  ///
  /// In practice this means one thing — the token was revoked or regenerated in
  /// the Todoist account, and the old one stops working the moment that
  /// happens. The token is removed from the Keychain when this is thrown; the
  /// cache, the plan and the local completion history are left alone, because a
  /// credential going stale is not a decision to disconnect.
  case tokenRejected

  /// Todoist asked us to slow down: HTTP 429.
  ///
  /// - Parameter retryAfter: how long Todoist asked us to wait, when it said.
  ///   `nil` when the response carried no `Retry-After` header.
  case rateLimited(retryAfter: Duration?)

  /// The request never reached Todoist. No connection, the connection dropped,
  /// or it timed out. **Nothing happened at the other end**, which is the fact
  /// the screens are careful to state: a task is still open after this.
  case offline

  /// Todoist answered with something other than success.
  ///
  /// - Parameter status: the HTTP status code — 404 when a task is no longer
  ///   there, 5xx when Todoist itself is having trouble. **A negative number
  ///   here is not an HTTP status**: it is the operating system's own network
  ///   error code, for the failures that are neither "offline" nor an answer
  ///   from Todoist (a certificate problem, say). HTTP statuses are positive,
  ///   so the sign is how a reader tells the two apart.
  case server(status: Int)

  /// Todoist answered, and the answer was not the shape the API documents.
  /// Either it was not an HTTP response at all, or the JSON did not decode.
  case malformedResponse

  /// The page loop hit its ceiling.
  ///
  /// Pages are followed until Todoist says there are no more. A server that
  /// kept handing back the same "there is more" marker would otherwise spin
  /// forever inside a refresh, with nothing on screen and no error. The loop
  /// stops after 250 pages — 50,000 rows, far past any real account — and fails
  /// loudly instead.
  case paginationDidNotTerminate
}

// MARK: - What a person is told

/// The sentences shown to a person, written by hand.
///
/// None of them is borrowed from the operating system or from Todoist's
/// response body. That is deliberate twice over: a borrowed message can carry a
/// web address (and so, one day, a credential), and it is written for a
/// developer rather than for the person holding the phone.
extension TodoistError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .notSignedIn:
      "ZenTomato is not connected to Todoist."
    case .tokenRejected:
      "Todoist rejected this token. It was probably revoked. Enter a new one."
    case .rateLimited:
      "Todoist asked us to slow down."
    case .offline:
      "Couldn't reach Todoist."
    case .server:
      "Todoist couldn't answer just now."
    case .malformedResponse:
      "Todoist's answer wasn't in a shape ZenTomato understands."
    case .paginationDidNotTerminate:
      "Todoist kept saying there was more to fetch, so ZenTomato stopped asking."
    }
  }
}
