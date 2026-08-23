import Foundation
import SwiftData

/// The one place F4's two remembered facts are read and written.
///
/// WHAT IT IS, FOR A READER WHO DOES NOT WRITE SWIFT
/// `MusicPreference` is the row on disk. This is the handle the rest of the app
/// holds: it finds that row (creating it the first time the app is ever run),
/// hands out the two values in a shape a screen can draw, and writes them back
/// when they change. Nothing else in the app may touch the row.
///
/// IT IS SHAPED LIKE `TimerState.current(in:)`, DELIBERATELY
/// The single-row accessor below is the same pattern `AppSettings` and
/// `TimerState` already use, for the same reason: there is exactly one of these,
/// so the rule "which row wins" never has to exist. Copying an established shape
/// rather than inventing a third one means a reader who has understood either of
/// those two has already understood this.
///
/// WHY THE VALUES ARE MIRRORED IN MEMORY RATHER THAN READ THROUGH EVERY TIME
/// The timer screen redraws once a second while a block runs. Reaching into the
/// database on every redraw to ask whether music is on would put a fetch on the
/// path of the calmest screen in the app. The two values are read once at start
/// up and kept in step by the two mutators below, which are the only things that
/// can change them.
///
/// WHAT IT REFUSES TO DO
/// It does not decide whether music may play, it does not ask for permission and
/// it never touches a player. It holds two facts. The decision lives in one pure
/// function on `MusicPlaybackPhase`, and the only thing that can produce sound is
/// `MusicCoordinator.apply()`.
///
/// MAIN-THREAD ONLY, because it holds a `ModelContext` and those are not safe to
/// share between threads. That is the same rule every other store in this app
/// follows.
@MainActor
@Observable
final class MusicPreferenceStore: MusicPreferenceStoring {
  // MARK: Lifecycle

  /// - Parameter context: the app's database handle. Held, not copied.
  init(context: ModelContext) {
    self.context = context
    reload()
  }

  // MARK: What is remembered

  /// Whether music should play during focus blocks.
  ///
  /// `false` when the row has never been created, and `false` when the database
  /// refused to be read — which is the same answer from where a person is
  /// standing, and the safe one: a timer that is quiet works.
  private(set) var isEnabled = false

  /// The one chosen playlist or song, or `nil` when nothing has been chosen.
  ///
  /// **Exactly one, ever.** There is no list here and no history of things that
  /// were chosen before. Choosing something replaces whatever was chosen, which
  /// is why the picker needs no way to un-choose: the switch is the off control,
  /// in one place.
  private(set) var selection: MusicSelection?

  /// Whether the last attempt to write these values to disk was refused.
  ///
  /// **Reported rather than swallowed, and deliberately not shown on the timer
  /// screen.** The consequence of a refused write is that the switch or the
  /// chosen item is back where it was at the next launch — a working silent
  /// timer, which is what D19.2 says every failure in this feature degrades to.
  /// Putting an amber row on the timer screen for it would say the app is broken,
  /// which is the one thing D19.2 forbids. It is here so that a future caller has
  /// something honest to read instead of a discarded error.
  private(set) var lastWriteFailed = false

  // MARK: Changing them

  /// Turns music on or off.
  ///
  /// **This writes the preference and nothing else.** It does not start or stop
  /// anything, and it does not ask whether the timer is idle — the coordinator
  /// owns both of those, and refusing here as well would put the same rule in two
  /// places that could disagree.
  func setEnabled(_ isEnabled: Bool) {
    self.isEnabled = isEnabled
    write { row in row.isEnabled = isEnabled }
  }

  /// Records the chosen playlist or song, or that nothing is chosen.
  ///
  /// The title travels with it and is stored as it reads now. See
  /// `MusicPreference.selectionTitle` for why a snapshot rather than a lookup.
  func setSelection(_ selection: MusicSelection?) {
    self.selection = selection
    write { row in
      row.selectionKind = selection?.kind.rawValue
      row.selectionID = selection?.identifier
      row.selectionTitle = selection?.title
    }
  }

  // MARK: The single-row accessor

  /// Returns the app's one and only music preference row, creating it with the
  /// first-launch state the first time it is asked for.
  ///
  /// THIS IS A SINGLETON ROW ON PURPOSE. DO NOT "FIX" IT INTO A LIST.
  /// The same argument `AppSettings.current(in:)` makes at greater length: one
  /// person, one preference, and no rule needed for which of two rows wins.
  ///
  /// `@MainActor` is what makes the look-then-insert below safe rather than
  /// merely usually right. Two threads could both look, both find nothing, and
  /// both insert — leaving exactly the two rows this design exists to prevent.
  ///
  /// - Parameter context: the SwiftData context to read and write through.
  /// - Returns: the preference row, freshly created on first launch and fetched
  ///   from disk on every launch after that.
  /// - Throws: whatever SwiftData throws if the store cannot be read or written.
  ///   The error is never swallowed here; the caller decides what to do with it.
  @MainActor
  static func current(in context: ModelContext) throws -> MusicPreference {
    var descriptor = FetchDescriptor<MusicPreference>()
    // There is at most one row by construction, so asking for more than one would
    // be asking the database a question whose answer is already known.
    descriptor.fetchLimit = 1

    if let existing = try context.fetch(descriptor).first {
      return existing
    }

    let created = MusicPreference()
    context.insert(created)
    // Saved immediately rather than left pending. If the app is killed between
    // first launch and the first change, the next launch must find the row rather
    // than create a second one.
    try context.save()
    return created
  }

  // MARK: Private

  private let context: ModelContext

  /// Reads the row into the two values above.
  ///
  /// A database that cannot be read leaves music off with nothing chosen, which
  /// is the first-launch state and produces a timer that simply does not play
  /// anything. Nothing is announced and nothing is amber: see `lastWriteFailed`.
  private func reload() {
    do {
      let row = try Self.current(in: context)
      isEnabled = row.isEnabled
      selection = Self.selection(from: row)
    } catch {
      isEnabled = false
      selection = nil
      lastWriteFailed = true
    }
  }

  /// Applies a change to the row and commits it.
  ///
  /// The in-memory values above are set by the callers *before* this runs, so the
  /// screen follows what the person just did even when the disk refuses. What a
  /// refusal costs is the next launch, which starts from whatever was last
  /// written — and it is recorded rather than discarded.
  private func write(_ change: (MusicPreference) -> Void) {
    do {
      let row = try Self.current(in: context)
      change(row)
      try context.save()
      lastWriteFailed = false
    } catch {
      lastWriteFailed = true
    }
  }

  /// Turns the row's three optional columns into one value, or `nil`.
  ///
  /// **All three or none.** A row holding an identifier with no kind cannot be
  /// looked up, and a kind with no identifier names nothing — either is a
  /// half-written row, and the honest reading of a half-written row is that
  /// nothing is chosen. A kind that is not one of the two known words is treated
  /// the same way: it is data from an older or newer version of this app, and
  /// guessing at it would put a wrong title on the timer screen.
  private static func selection(from row: MusicPreference) -> MusicSelection? {
    guard let rawKind = row.selectionKind,
          let kind = MusicSelection.Kind(rawValue: rawKind),
          let identifier = row.selectionID,
          identifier.isEmpty == false,
          let title = row.selectionTitle else { return nil }

    return MusicSelection(kind: kind, identifier: identifier, title: title)
  }
}
