import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The token screen's one command, and the two ways it used to make things
/// worse.
///
/// The screen is reachable from Settings while a perfectly good credential is
/// already stored, so "tap Connect and it fails" is not a first-run-only story.
/// What that must never do is leave somebody signed out, and what it must never
/// look like is two warnings at once.
///
/// Nothing here touches the network or the real Keychain: the transport is a
/// script of prepared answers and the store is in memory.
@Suite("SignInScreenModel")
@MainActor
struct SignInScreenModelTests {
  // MARK: Lifecycle

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  // MARK: A failed attempt must not sign somebody out

  /// Offline is the case that matters most: it is the one failure that is
  /// definitely not the token's fault, and it is the one most likely to happen
  /// on a train.
  ///
  /// The credential has to be stored before it can be tried, because the request
  /// builder reads it from the store. That used to mean a failure left the
  /// Keychain empty — signed out, with no dialog, by an action whose own message
  /// says "Nothing has been saved".
  @Test("aFailedAttemptLeavesAWorkingTokenWhereItWas")
  func aFailedAttemptLeavesAWorkingTokenWhereItWas() async throws {
    let credentials = FakeTokenStore(token: "the-one-that-works")
    let model = SignInScreenModel(tokens: credentials, cache: offlineCache(credentials))
    model.token = "a-stale-one"

    #expect(await model.connect() == false)

    // The screen says nothing has been saved, and now that is true of the old
    // credential as well as the new one.
    #expect(model.errorMessage?.contains("Nothing has been saved") == true)
    #expect(try credentials.read() == "the-one-that-works")
  }

  /// With nothing stored to begin with, nothing is stored afterwards — which is
  /// the other half of the same sentence.
  @Test("aFailedAttemptOnAnEmptyStoreLeavesItEmpty")
  func aFailedAttemptOnAnEmptyStoreLeavesItEmpty() async throws {
    let credentials = FakeTokenStore(token: nil)
    let model = SignInScreenModel(tokens: credentials, cache: offlineCache(credentials))
    model.token = "a-first-attempt"

    #expect(await model.connect() == false)
    #expect(credentials.holdsAToken == false)
  }

  // MARK: One amber thing at a time

  /// Starting a fresh attempt clears the banner, so a refusal replaces it rather
  /// than stacking under it.
  ///
  /// The commonest route to this screen is a revoked token, which arrives with
  /// an amber banner. One fumbled paste after that used to put a second warning
  /// triangle underneath the first — and two amber rows on one screen is the
  /// state that makes amber stop meaning anything.
  @Test("aFreshAttemptClearsTheBannerSoThereIsOnlyEverOneAmberRow")
  func aFreshAttemptClearsTheBannerSoThereIsOnlyEverOneAmberRow() async throws {
    let credentials = FakeTokenStore(token: nil)
    let model = SignInScreenModel(
      tokens: credentials,
      cache: offlineCache(credentials),
      banner: .revoked)
    model.token = "a-fresh-one"

    #expect(model.banner == .revoked)

    #expect(await model.connect() == false)

    #expect(model.banner == nil)
    #expect(model.errorMessage != nil)
  }

  /// A token that is accepted is kept, and the field is emptied.
  @Test("anAcceptedTokenIsKeptAndTheFieldIsEmptied")
  func anAcceptedTokenIsKeptAndTheFieldIsEmptied() async throws {
    let credentials = FakeTokenStore(token: nil)
    let stub = StubTodoistTransport(answers: [.page(rows: []), .page(rows: []), .page(rows: [])])
    let cache = TodoistCacheStore(
      context: context,
      client: TodoistClient(transport: stub, tokens: credentials, waiting: RecordingRetryWaiting()))
    let model = SignInScreenModel(tokens: credentials, cache: cache)
    model.token = "  a-good-one\n"

    #expect(await model.connect())

    #expect(try credentials.read() == "a-good-one")
    #expect(model.token.isEmpty)
    #expect(model.isRevealed == false)
    #expect(model.errorMessage == nil)

    // Checking a token is an ordinary read. Nothing was written to Todoist.
    #expect(stub.requestsThatWereNotReads.isEmpty)
  }

  // MARK: Private

  private let container: ModelContainer

  private var context: ModelContext { container.mainContext }

  /// A mirror whose every request fails with no connection.
  private func offlineCache(_ credentials: FakeTokenStore) -> TodoistCacheStore {
    let stub = StubTodoistTransport(
      answers: [.failure(URLError(.notConnectedToInternet))],
      repeatingLastAnswer: true)
    return TodoistCacheStore(
      context: context,
      client: TodoistClient(transport: stub, tokens: credentials, waiting: RecordingRetryWaiting()))
  }
}
