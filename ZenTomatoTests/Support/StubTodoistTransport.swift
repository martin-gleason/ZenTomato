import Foundation
import Synchronization
import Testing

@testable import ZenTomato

/// Todoist, replaced by a script.
///
/// WHY EVERY TEST IN THIS BUNDLE USES THIS
/// **No test in this project touches the network.** One that did would need a
/// Todoist account, a connection and somebody's real tasks; it would fail on a
/// train, and it would fail in continuous integration for reasons that had
/// nothing to do with the code being tested. So the one piece of the app that
/// actually sends bytes is replaced here by a list of prepared answers.
///
/// It does two jobs, and the second one is the important one:
///
///   1. it hands back the answers it was given, in order;
///   2. **it writes down every request it was asked to send.**
///
/// The second is what makes `noMutatingRequestsOtherThanClose` possible: a test
/// can run a whole session — connect, refresh, plan, work a block, complete a
/// task — and then read back every single request the app made and check that
/// exactly one of them was not a read. That is the running companion to the
/// script that reads the source code before every commit. One checks what is
/// written; this checks what is sent.
///
/// It is safe to use from any thread — the client runs off the main one — which
/// is why the two lists live behind a lock rather than as plain properties.
final class StubTodoistTransport: TodoistTransport {
  // MARK: What it can answer with

  /// One prepared answer.
  enum Answer: Sendable {
    /// Todoist replied, with this status, this body, and these headers.
    case status(Int, Data, headers: [String: String])

    /// The request never got there — no connection, or the connection dropped.
    case failure(URLError)

    // MARK: Building one

    /// One page of results in Todoist's own envelope.
    ///
    /// - Parameters:
    ///   - rows: the rows in this page.
    ///   - nextCursor: the marker meaning "ask again with this", or `nil` for
    ///     the end of the list.
    ///   - status: the HTTP status. Defaults to success.
    static func page(
      rows: [[String: Any]],
      nextCursor: String? = nil,
      status: Int = 200) -> Answer {
      let envelope: [String: Any] = [
        "results": rows,
        "next_cursor": nextCursor ?? NSNull()
      ]
      do {
        return .status(status, try JSONSerialization.data(withJSONObject: envelope), headers: [:])
      } catch {
        Issue.record("Could not build a stubbed page: \(error)")
        return .status(status, Data(), headers: [:])
      }
    }

    /// An answer with no useful body — a failure, or the empty object Todoist
    /// returns from a successful close.
    static func bare(status: Int, headers: [String: String] = [:]) -> Answer {
      .status(status, Data("{}".utf8), headers: headers)
    }
  }

  // MARK: What it is holding

  /// The script and the log, together behind one lock so they cannot disagree
  /// about how far through the script the test has got.
  private struct State {
    var answers: [Answer]
    var requests: [URLRequest] = []
    var repeatLastAnswer: Bool
  }

  private let state: Mutex<State>

  /// Builds a stand-in.
  ///
  /// - Parameters:
  ///   - answers: the answers to give, in order.
  ///   - repeatingLastAnswer: when true, the final answer is given again for
  ///     every request after it. Used by the one test that needs a server which
  ///     never stops saying "there is more", which would otherwise need hundreds
  ///     of identical lines.
  init(answers: [Answer], repeatingLastAnswer: Bool = false) {
    state = Mutex(State(answers: answers, repeatLastAnswer: repeatingLastAnswer))
  }

  // MARK: Being the network

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let answer: Answer? = state.withLock { state in
      state.requests.append(request)
      guard !state.answers.isEmpty else { return nil }
      return state.answers.count == 1 && state.repeatLastAnswer
        ? state.answers[0]
        : state.answers.removeFirst()
    }

    switch answer {
    case .status(let code, let data, let headers):
      guard let url = request.url,
            let response = HTTPURLResponse(
              url: url,
              statusCode: code,
              httpVersion: "HTTP/1.1",
              headerFields: headers) else {
        throw URLError(.badServerResponse)
      }
      return (data, response)

    case .failure(let error):
      throw error

    case nil:
      // The script ran out. That is a mistake in the test rather than a
      // behaviour of the app, and it is reported as one instead of being
      // answered with something invented.
      Issue.record("The stubbed transport was asked for more answers than it was given.")
      throw URLError(.unknown)
    }
  }

  // MARK: What the test reads back

  /// Every request the app asked to have sent, oldest first.
  var recordedRequests: [URLRequest] {
    state.withLock { $0.requests }
  }

  /// Every request that was not a read.
  ///
  /// **This should be empty, or hold exactly one close command, and nothing
  /// else, ever.** It is the assertion the whole feature is judged on.
  var requestsThatWereNotReads: [URLRequest] {
    recordedRequests.filter { $0.httpMethod != TodoistAPI.Method.get.rawValue }
  }

  // MARK: Rows, in the shape Todoist sends them

  /// One project, with only the three fields this app reads. Deliberately not
  /// more: the real answer is a mixture of two shapes, and the app decodes only
  /// what both of them carry.
  static func projectRow(id: String, name: String, order: Int = 0) -> [String: Any] {
    ["id": id, "name": name, "child_order": order]
  }

  /// One section.
  static func sectionRow(
    id: String,
    name: String,
    projectID: String,
    order: Int = 0) -> [String: Any] {
    ["id": id, "name": name, "project_id": projectID, "section_order": order]
  }

  /// One task. `sectionID` is left out entirely when it is `nil`, which is how
  /// Todoist sends a task that is loose in its project.
  static func taskRow(
    id: String,
    content: String,
    projectID: String,
    sectionID: String? = nil,
    order: Int = 0) -> [String: Any] {
    [
      "id": id,
      "content": content,
      "project_id": projectID,
      "section_id": sectionID ?? NSNull(),
      "child_order": order
    ]
  }
}
