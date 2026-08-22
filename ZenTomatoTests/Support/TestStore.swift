import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Store helpers shared by the persistence tests.
///
/// WHY THIS FILE EXISTS
/// Two patterns are needed, they are easy to get subtly wrong, and getting
/// either wrong produces a test that passes for the wrong reason. Writing them
/// once here means they are never reinvented per test:
///
///   * `inMemoryContainer()` — a brand-new store that lives only in memory.
///     This is what almost every test wants: fast, isolated, and physically
///     unable to touch the real database on the phone.
///
///   * `temporaryFileStore()` — a real store in a real file, in a fresh
///     directory under the system's temporary folder. Exactly one test needs
///     this, and the reason is worth stating: proving a value SURVIVES means
///     closing the store and opening it again, and an in-memory store cannot
///     express that, because it ceases to exist the moment the container that
///     holds it is released.
///
/// EVERYTHING HERE IS `@MainActor` — main-thread only. SwiftData's
/// `ModelContext`, the handle through which anything is read or written, is
/// not safe to share between threads, so this whole file is confined to one.
/// That is also why every persistence test suite is annotated the same way.
///
/// NO TEST TOUCHES THE REAL STORE. Neither helper ever asks for the app's
/// default location, so running the test suite cannot read, corrupt, or delete
/// anything the app has saved.
@MainActor
enum TestStore {
  // MARK: In-memory

  /// A fresh, empty, in-memory store. Read and write it through
  /// `.mainContext`.
  ///
  /// A new container is built on every call and never shared between tests, so
  /// no test can see another test's rows and the order the tests run in cannot
  /// change the result.
  ///
  /// THE CONTAINER IS RETURNED, NOT THE CONTEXT, AND THAT IS THE WHOLE POINT.
  /// A container's `mainContext` does not keep the container alive. So writing
  /// `make(.inMemory).mainContext` and keeping only the context hands back a
  /// handle to a store that has already been thrown away, and the first read
  /// through it stops the whole test process dead inside SwiftData — not with
  /// a failed check, but with a crash that takes the other tests down with it.
  /// Returning the container makes the caller hold the store open for as long
  /// as it is using it, which is the only thing that makes the context valid.
  static func inMemoryContainer() throws -> ModelContainer {
    try AppModelContainer.make(.inMemory)
  }

  // MARK: On disk, temporarily

  /// A private directory holding one on-disk store, for tests that must close
  /// and reopen it.
  struct TemporaryFileStore {
    /// The directory this store owns. Removing it removes the store and every
    /// side file SwiftData creates next to it — the write-ahead log and the
    /// shared-memory file, which is why a directory is handed out rather than
    /// a bare file path.
    let directoryURL: URL

    /// The database file itself.
    var storeURL: URL {
      directoryURL.appending(path: "ZenTomato.store")
    }

    /// Deletes the directory and everything in it.
    ///
    /// Call it from a `defer` so it runs even when the test fails partway
    /// through — otherwise a failing test leaves litter behind that the next
    /// run has to be careful not to trip over.
    func remove() {
      guard FileManager.default.fileExists(atPath: directoryURL.path(percentEncoded: false)) else {
        return
      }
      do {
        try FileManager.default.removeItem(at: directoryURL)
      } catch {
        // A cleanup failure does not make the test's result wrong, so it is
        // reported rather than thrown. The directory is under the system's
        // temporary path, which the operating system reclaims on its own.
        Issue.record("Could not remove the temporary store at \(directoryURL): \(error)")
      }
    }
  }

  /// Creates an empty directory under the system's temporary folder for one
  /// test's exclusive use.
  ///
  /// The name carries a fresh identifier every time, so two tests — or two
  /// simultaneous runs of the same suite — can never collide on the same path.
  static func temporaryFileStore() throws -> TemporaryFileStore {
    let directoryURL = FileManager.default.temporaryDirectory
      .appending(path: "ZenTomatoTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    return TemporaryFileStore(directoryURL: directoryURL)
  }
}
