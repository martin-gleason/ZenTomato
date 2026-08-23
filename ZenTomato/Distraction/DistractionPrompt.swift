import Foundation

/// One recorded tap, in the only shape it takes when it leaves the engine.
///
/// WHY THIS TYPE EXISTS AT ALL, WHEN `Distraction` ALREADY HOLDS THE SAME FACTS
/// A `Distraction` is a database row. Reaching one is only safe on the main
/// thread, its values can be changed by anybody holding it, and it belongs to
/// the context that fetched it. None of that is true of this: it is a plain
/// value, it is immutable, it can be copied and compared freely, and handing it
/// to a screen gives the screen nothing it could use to write to the database.
///
/// **No `Distraction`, no `TimerState` and no `ModelContext` ever crosses into
/// `ZenTomato/Views/`.** This type and `BlockReflection` are the only two
/// things that do. That is what makes "the screens cannot lose or corrupt a
/// row" a property of the code's shape rather than a rule somebody has to
/// remember.
///
/// IT CARRIES NO `note`, AND THAT IS DELIBERATE.
/// A prompt is a *question* — "you tapped Internal at 14:32; would you like to
/// say why?". The answer travels back separately, as a dictionary of
/// `id → text`, and only the engine ever writes it down. A prompt that carried
/// the note would invite a screen to edit it in place, which would mean two
/// things believing they own the same sentence.
///
/// `Identifiable` lets SwiftUI tell one row of the sheet from another without
/// counting positions. `Hashable` lets it sit in a `Set` or act as a dictionary
/// key. `Sendable` is Swift's promise that a value is safe to pass between
/// threads, which this is because every one of its three values is a constant.
struct DistractionPrompt: Identifiable, Hashable, Sendable {
  // MARK: The three facts a sheet needs

  /// The identity of the row this asks about. The sentence written in answer is
  /// sent back under this name, which is how it reaches the right tap.
  let id: UUID

  /// Internal or external. The sheet draws the word; `DistractionTally` counts
  /// these to produce the summary line.
  let kind: DistractionKind

  /// The instant of the tap, so the sheet can say "Internal · 14:32" and the
  /// person can remember which moment it is asking about.
  let timestamp: Date

  // MARK: Initialisation

  /// Builds a prompt from its parts. Used by previews and tests, which have no
  /// database to build one from.
  init(id: UUID, kind: DistractionKind, timestamp: Date) {
    self.id = id
    self.kind = kind
    self.timestamp = timestamp
  }

  /// Copies the three facts a sheet needs out of a saved row.
  ///
  /// `@MainActor` because it reads a SwiftData object, and everything reached
  /// through a `ModelContext` in this app is read on the main thread. The
  /// resulting value has no such restriction — that is the entire point of
  /// making the copy.
  ///
  /// - Parameter row: the saved distraction to describe.
  @MainActor
  init(_ row: Distraction) {
    id = row.id
    kind = row.kind
    timestamp = row.timestamp
  }
}
