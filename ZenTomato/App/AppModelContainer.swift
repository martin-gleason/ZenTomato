import Foundation
import SwiftData

/// Opens the app's local database.
///
/// WHAT THIS IS, FOR A READER WHO DOES NOT WRITE SWIFT
/// SwiftData needs two things before anything can be saved or read: a
/// description of what kinds of object exist (the *schema*), and a place to
/// keep them (the *container*). This type builds both, in one place, so that
/// the app, the previews, and the tests all open the store the same way.
///
/// It is an `enum` with no cases, which is Swift's way of writing "a namespace,
/// not a thing" — there is never an instance of `AppModelContainer`; it only
/// holds the two functions below.
///
/// THE ONE FACT THE THREADING RULES FOLLOW FROM
/// A `ModelContainer` is safe to hand between threads. A `ModelContext` — the
/// handle you actually read and write through — is not. So building the
/// container has no threading restriction, while every use of a context, and
/// every touch of a saved object, happens on the main thread. That split is
/// exactly the split between the two functions below, and it is the reason
/// each carries the annotation it does.
enum AppModelContainer {
  // MARK: Where the store lives

  /// Which file, if any, the store is backed by.
  ///
  /// Three cases, one per situation this project actually has:
  ///
  ///   * `appDefault` — the real app. SwiftData picks the standard location
  ///     inside the app's private storage on the phone.
  ///   * `inMemory` — a store that exists only for as long as the container
  ///     does and is never written to disk. Every test that needs a clean
  ///     store uses this: it is fast, and it cannot possibly touch the real
  ///     one.
  ///   * `file(URL)` — a store at a chosen path. Used by the one test that
  ///     must close the store and open it again to prove a value survived,
  ///     which an in-memory store cannot express because it dies with its
  ///     container.
  ///
  /// `Sendable` marks it as safe to pass between threads, which it is: it is a
  /// plain description of a location and holds nothing mutable.
  enum StoreLocation: Sendable {
    case appDefault
    case inMemory
    case file(URL)
  }

  // MARK: Building the container

  /// Builds a SwiftData container for the given location.
  ///
  /// `nonisolated` says this may run on any thread. It is spelled out rather
  /// than left implicit because it is a deliberate decision that the rest of
  /// the file depends on: a container is safe to move between threads, so
  /// there is no reason to make callers wait for the main one just to open a
  /// database.
  ///
  /// The schema is built here, freshly, on every call. It lists every kind of
  /// object the app saves — the settings row, the one row describing the
  /// running timer, and one row per finished block. When a future feature adds
  /// a saved type, it is added to this array and nowhere else.
  ///
  /// - Parameter location: where the store should live. Defaults to the real
  ///   app's location.
  /// - Returns: an open container.
  /// - Throws: SwiftData's error if the store cannot be opened — a corrupt
  ///   file, a full disk, a path that cannot be written. The caller is
  ///   expected to show that to the user rather than crash; see `bootstrap()`.
  nonisolated static func make(_ location: StoreLocation = .appDefault) throws -> ModelContainer {
    let schema = Schema([AppSettings.self, TimerState.self, PomodoroSession.self])

    let configuration: ModelConfiguration
    switch location {
    case .appDefault:
      configuration = ModelConfiguration(schema: schema)
    case .inMemory:
      configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    case .file(let url):
      configuration = ModelConfiguration(schema: schema, url: url)
    }

    return try ModelContainer(for: schema, configurations: [configuration])
  }

  // MARK: The app's start-up seam

  /// Opens the real store and makes sure the settings row exists.
  ///
  /// This is the single point where the persistence layer meets the app's user
  /// interface. The app entry point calls it once, at launch, and shows either
  /// the timer or a failure screen depending on what comes back.
  ///
  /// WHY IT RETURNS A `Result` INSTEAD OF THROWING OR CRASHING
  /// Opening a database can fail, and the usual shortcut — writing `try!`,
  /// which means "crash if this fails" — turns a bad disk into an app that
  /// dies on launch with no explanation. A `Result` is Swift's "either the
  /// thing, or the reason there isn't one": the caller must look at which it
  /// got, so the failure has to be handled rather than ignored. That is why
  /// there is no force-try anywhere in this codebase, and why there is a
  /// plain-language screen for the failing case.
  ///
  /// WHY IT IS `@MainActor`
  /// Because it touches `container.mainContext` in order to create the
  /// settings row on first launch, and contexts are main-thread only.
  ///
  /// - Returns: the open container on success, or the error that stopped it.
  @MainActor
  static func bootstrap() -> Result<ModelContainer, any Error> {
    do {
      let container = try make()
      // Force the settings row into existence now, at launch, rather than
      // leaving the first screen that needs it to discover it is missing.
      // The returned value is deliberately unused here: this call is being
      // made for its effect on the store, not for the row itself.
      _ = try AppSettings.current(in: container.mainContext)
      return .success(container)
    } catch {
      return .failure(error)
    }
  }
}
