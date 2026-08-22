import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Tests for the settings row: that it starts with the values the contract
/// names, that a change survives the app being closed, and that there is only
/// ever one of it.
///
/// `@MainActor` on the whole suite, not on individual tests. SwiftData's
/// `ModelContext` is not safe to use from more than one thread, so every test
/// that touches the store runs on the main one. Annotating the suite rather
/// than each test means a future test cannot forget.
@Suite("AppSettings")
@MainActor
struct AppSettingsTests {
  /// A brand-new store must produce the six defaults `SPEC.md` names, and no
  /// others.
  ///
  /// This is the test that would catch somebody "improving" a default — a
  /// 30-minute work block, auto-start switched on — which sounds harmless and
  /// changes what the app is.
  @Test("settingsDefaultsOnFirstLaunch")
  func settingsDefaultsOnFirstLaunch() throws {
    // The container is held for the whole test on purpose: it owns the store,
    // and a context outlives its store only in the sense that it crashes.
    let container = try TestStore.inMemoryContainer()

    let settings = try AppSettings.current(in: container.mainContext)

    #expect(settings.workMinutes == 25)
    #expect(settings.shortBreakMinutes == 5)
    #expect(settings.longBreakMinutes == 15)
    #expect(settings.pomodorosPerSprint == 4)
    #expect(settings.soundEnabled == true)
    // Off by default: a timer that starts a work block while you are still
    // away from the desk is a timer that lies about how long you worked.
    #expect(settings.autoStartNextBlock == false)
  }

  /// A changed value must still be there after the store is closed and opened
  /// again.
  ///
  /// WHY THIS ONE USES A REAL FILE AND THE OTHERS DO NOT
  /// "It persists" is a claim about what happens after everything in memory is
  /// gone. An in-memory store cannot answer that question — it disappears
  /// together with the thing being tested — so this test writes to an actual
  /// file in a temporary directory, releases the container completely, and
  /// then opens the same file fresh.
  @Test("settingsRoundTrip")
  func settingsRoundTrip() throws {
    let store = try TestStore.temporaryFileStore()
    defer { store.remove() }

    // Written inside its own function so that the container it opens is
    // released the moment the function returns. Persistence cannot be honestly
    // tested while the writer is still holding the store open.
    try writeWorkMinutes(37, to: store.storeURL)

    let reopened = try AppModelContainer.make(.file(store.storeURL))
    let settings = try AppSettings.current(in: reopened.mainContext)

    #expect(settings.workMinutes == 37)
    // The untouched values must have survived too. A store that persisted only
    // the field the test changed would pass a weaker version of this check.
    #expect(settings.shortBreakMinutes == 5)
    #expect(settings.pomodorosPerSprint == 4)
  }

  /// Asking for the settings twice must return the same single row.
  ///
  /// The accessor creates a row when it does not find one. If it ever failed to
  /// find the row it just created, the app would accumulate a new settings row
  /// on every launch and the timer would silently reset to its defaults. This
  /// test is the reason that cannot happen unnoticed.
  @Test("settingsSingletonRow")
  func settingsSingletonRow() throws {
    // Held for the whole test: see `settingsDefaultsOnFirstLaunch`.
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext

    let first = try AppSettings.current(in: context)
    first.workMinutes = 50
    try context.save()

    let second = try AppSettings.current(in: context)

    // The same row, not merely an equal one: the second call must have found
    // the first rather than created a second with the same defaults.
    #expect(second.workMinutes == 50)
    #expect(first.persistentModelID == second.persistentModelID)

    // And the store itself must contain exactly one.
    let all = try context.fetch(FetchDescriptor<AppSettings>())
    #expect(all.count == 1)
  }

  // MARK: Helpers

  /// Opens the store at `url`, sets the work length, saves, and lets the
  /// container go.
  private func writeWorkMinutes(_ minutes: Int, to url: URL) throws {
    let container = try AppModelContainer.make(.file(url))
    let settings = try AppSettings.current(in: container.mainContext)
    settings.workMinutes = minutes
    try container.mainContext.save()
  }
}
