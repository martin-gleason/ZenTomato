import Foundation
import SwiftData

/// The user's timer preferences — the only thing this app stores about itself.
///
/// WHAT A READER WHO DOES NOT WRITE SWIFT NEEDS TO KNOW
/// `@Model` is SwiftData's marker for "this is a thing to save to disk". The
/// six properties below become six columns in a local database file on the
/// phone; changing one of them in memory and calling `save()` writes it. There
/// is no server, no account, and nothing leaves the device.
///
/// EXACTLY SIX PROPERTIES, AND WHY THAT IS A RULE RATHER THAN A COINCIDENCE
/// `SPEC.md`'s locked decisions table reads:
///
///   > Timer customization | Work length, short break, long break,
///   > pomodoros-per-sprint, sound on/off, auto-start next block on/off.
///   > **Nothing else.**
///
/// Two absences are deliberate and worth naming, because both look reasonable
/// and both would be scope creep:
///
///   * There is no `musicEnabled`. The spec describes music on/off as a toggle
///     "before a sprint", which makes it session state belonging to the music
///     feature, not a stored timer preference.
///   * There is no `theme` or `appearance`. Light and dark follow the system
///     setting, with no control anywhere in the app. Themes are explicitly out
///     of scope for v0.1.
///
/// WHY SWIFTDATA AND NOT `UserDefaults`
/// So there is one store to reason about, one backup story, and one place to
/// look when something is wrong — rather than preferences in one system and
/// everything the app is actually for in another.
@Model
final class AppSettings {
  // MARK: Stored properties

  /// Length of a work block, in minutes. The spec's default is 25.
  var workMinutes: Int

  /// Length of the short break that follows most work blocks, in minutes.
  /// The spec's default is 5.
  var shortBreakMinutes: Int

  /// Length of the long break that ends a sprint, in minutes. The spec's
  /// default is 15.
  var longBreakMinutes: Int

  /// How many work blocks make up one sprint, after which the long break is
  /// taken instead of the short one. The spec's default is 4.
  var pomodorosPerSprint: Int

  /// Whether the app makes a sound when a block ends. Defaults to on: the
  /// whole point of a timer is that it tells you without being watched.
  var soundEnabled: Bool

  /// Which sound the alarm makes, as `AlertSound`'s raw value.
  ///
  /// **The seventh setting, and `SPEC.md` line 30 moved by exactly one to admit
  /// it** — keeping "Nothing else." on the end, which is the fence the list
  /// exists to be.
  ///
  /// **Stored as a `String` rather than the enum, deliberately.** A value written
  /// by a later version — a sound this build has never heard of — must read back
  /// as the default rather than fail to decode. `AlertSound.stored(_:)` is where
  /// that softening happens, and it is the reason a person can move a database
  /// between versions without losing a fortnight of distraction log over an
  /// alarm tone.
  ///
  /// **Optional because this is a migration.** Every row written before `D24`
  /// has no value here, and SwiftData fills it with `nil` rather than refusing to
  /// open the store. `nil` means the system default, which is exactly what those
  /// installs were already hearing — so the migration changes no behaviour, which
  /// is the only kind of migration worth trusting.
  var alertSoundRawValue: String?

  /// Whether the next block begins by itself when one ends. Defaults to OFF —
  /// a timer that starts a work block while you are still away from the desk
  /// is a timer that lies about how long you worked.
  var autoStartNextBlock: Bool

  // MARK: Initialisation

  /// Creates a settings row.
  ///
  /// Every parameter has the default the spec names, so `AppSettings()` is the
  /// first-launch state. The defaults live here, in one place, rather than
  /// being repeated at each call site where they could quietly disagree.
  init(
    workMinutes: Int = 25,
    shortBreakMinutes: Int = 5,
    longBreakMinutes: Int = 15,
    pomodorosPerSprint: Int = 4,
    soundEnabled: Bool = true,
    alertSoundRawValue: String? = nil,
    autoStartNextBlock: Bool = false
  ) {
    self.workMinutes = workMinutes
    self.shortBreakMinutes = shortBreakMinutes
    self.longBreakMinutes = longBreakMinutes
    self.pomodorosPerSprint = pomodorosPerSprint
    self.soundEnabled = soundEnabled
    self.alertSoundRawValue = alertSoundRawValue
    self.autoStartNextBlock = autoStartNextBlock
  }

  // MARK: The single-row accessor

  /// Returns the app's one and only settings row, creating it with the spec's
  /// defaults the first time the app is ever launched.
  ///
  /// THIS MODEL IS A SINGLETON ROW ON PURPOSE. DO NOT "FIX" IT INTO A LIST.
  /// SwiftData is a database and databases hold many rows, so the natural
  /// instinct on reading this file is that something is missing — a name, an
  /// identifier, a way to have several profiles. There is nothing missing.
  /// The app has one user with one set of preferences; a second row would not
  /// mean anything, and the first piece of code to fetch "the settings" would
  /// have to invent a rule for which one wins. Keeping it to one row means
  /// that rule never has to exist.
  ///
  /// The consequence a future reader must respect: this accessor is the ONLY
  /// way to obtain an `AppSettings`. Nothing else may insert one.
  ///
  /// WHY IT IS MAIN-ACTOR ONLY, AND WHY THAT IS WHAT MAKES IT CORRECT
  /// `@MainActor` means "this can only run on the app's main thread". That is
  /// not a performance choice; it is what makes the check-then-insert below
  /// safe. The method looks for a row and inserts one if it finds none, and if
  /// two threads could run it at once they could both look, both find nothing,
  /// and both insert — leaving exactly the two rows this design exists to
  /// prevent. Confining it to one thread makes that race impossible rather
  /// than unlikely.
  ///
  /// It is also required: SwiftData's `ModelContext` — the handle through
  /// which anything is read or written — is not safe to share between
  /// threads, so every use of one in this app is main-actor bound.
  ///
  /// - Parameter context: the SwiftData context to read and write through.
  /// - Returns: the settings row, freshly created with defaults on first
  ///   launch and fetched from disk on every launch after that.
  /// - Throws: whatever SwiftData throws if the store cannot be read or
  ///   written. The caller decides what to do about it; this method never
  ///   swallows the error, because settings that silently fail to save are
  ///   worse than an app that says it is broken.
  @MainActor
  static func current(in context: ModelContext) throws -> AppSettings {
    var descriptor = FetchDescriptor<AppSettings>()
    // There is at most one row by construction, so asking for more than one
    // would be asking the database a question whose answer is already known.
    descriptor.fetchLimit = 1

    if let existing = try context.fetch(descriptor).first {
      return existing
    }

    let created = AppSettings()
    context.insert(created)
    // Saved immediately rather than left pending. If the app is killed between
    // first launch and the first settings change, the next launch must find
    // the row rather than create a second one.
    try context.save()
    return created
  }
}
