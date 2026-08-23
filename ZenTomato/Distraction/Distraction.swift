import Foundation
import SwiftData

/// One recorded distraction: the thing this whole app exists to collect.
///
/// WHAT A READER WHO DOES NOT WRITE SWIFT NEEDS TO KNOW
/// `@Model` marks a type whose instances are rows in the app's local database.
/// Creating one and handing it to a `ModelContext` — SwiftData's read/write
/// handle — is how a row comes into existence; saving that context is what
/// writes it to the file on the phone.
///
/// THE ONE SENTENCE THIS FILE IS JUDGED ON: THE TAP IS THE RECORD.
/// A row is built and committed inside `TimerEngine.recordDistraction(_:)`
/// before that method returns, and before the phone buzzes in the person's
/// hand. There is no in-memory buffer, no batching, no "save when the sheet is
/// dismissed". Every field below is filled in at the instant of the tap and
/// only `note` is ever written again. That is why killing the app one
/// millisecond after a tap cannot lose it: by then it is already on disk.
///
/// IT IS A ROW AND NOTHING ELSE.
/// Five stored values, no computed properties, no methods, no relationships.
/// The two pieces of logic in this feature —
/// `DistractionTally.summary(of:)`, which turns a block's taps into one line of
/// prose, and `DistractionNote.normalised(_:)`, which decides whether a typed
/// sentence counts as one — both live outside this file, because a row that
/// can do things is a row somebody will ask to do more.
///
/// WHY IT IS TOUCHED ONLY FROM THE MAIN THREAD
/// A `ModelContext` is not safe to share between threads, so nothing reached
/// through one is either. This type is never marked `Sendable`, never captured
/// in a background task, and never handed to a screen. `DistractionPrompt` is
/// the immutable copy that crosses into the user interface, and it exists
/// precisely so that nothing is ever tempted to pass one of these instead.
@Model
final class Distraction {
  // MARK: What was recorded

  /// This row's own identity.
  ///
  /// It is what a sentence is later attached *to*. The end-of-block sheet hands
  /// back a dictionary of `id → text` and the engine matches on this value, so
  /// "the note belongs to the second tap" is expressed as a name rather than as
  /// a position in a list — and a list can come back from the database in a
  /// different order than it went in.
  var id: UUID

  /// Internal or external: the spec's I and E.
  ///
  /// `DistractionKind` is defined in `DistractionTally.swift` and was written
  /// by the owner. It is not redefined, moved, or extended here.
  var kind: DistractionKind

  /// The instant of the **tap**, never the instant of the note.
  ///
  /// Taken from the timer engine's injected clock, which is the real one in the
  /// app and a controlled one in tests. Two consequences worth stating: a test
  /// can assert an exact time without anything having to wait, and a sentence
  /// typed four minutes later cannot drag the timestamp forward with it. The
  /// spec's *done when* is "three records with the right timestamps", and a
  /// timestamp written when the sheet was filled in would be answering a
  /// different question.
  var timestamp: Date

  /// The sentence the person wrote about this tap, or `nil` if they did not.
  ///
  /// **`nil` means skipped, and skipping is a first-class outcome.** This is an
  /// optional rather than a text field defaulting to empty precisely so that
  /// "said nothing" and "deliberately wrote nothing" stay different facts in
  /// the store. `DistractionNote.normalised(_:)` is the only thing that ever
  /// decides which of the two a typed field is, and it never writes `""`.
  var note: String?

  /// Which block this happened in.
  ///
  /// A plain copy of the running timer's `sessionID`, taken at tap time. It is
  /// the same value the finished-block row (`PomodoroSession.id`) carries when
  /// that block ends, so the two match by construction.
  ///
  /// WHY THIS IS A COPIED IDENTIFIER AND NOT A DATABASE RELATIONSHIP
  /// The obvious shape in SwiftData would be `var session: PomodoroSession?`,
  /// with the database itself maintaining the link. It is wrong here, and the
  /// reason is a fact about the timer rather than a matter of taste: **the
  /// finished-block row does not exist yet when a tap happens.** The engine
  /// writes it when the block *ends*. A relationship would therefore be empty
  /// at the moment the row is created and would have to be filled in later —
  /// which would make this durable row's link to its block depend on a *second*
  /// write, minutes afterwards, that might never happen. That is exactly the
  /// window this feature exists to close, reopened through a side door. Copying
  /// the identifier produces a complete, final, self-sufficient row in one
  /// write, and nothing about it is ever revisited.
  ///
  /// THE COST, STATED PLAINLY. The database will not check that every
  /// `sessionID` here matches a real block, so a bug elsewhere could leave a
  /// row pointing at nothing and nothing would complain. Two honest answers
  /// rather than one clever one: every way out of a running block in the engine
  /// writes the block row — there is no exit that skips it — and the feature
  /// that eventually displays these must show an unmatched row as "no block"
  /// rather than treating it as an error.
  var sessionID: UUID

  // MARK: Initialisation

  /// Creates a complete record of one tap.
  ///
  /// The three values with no default are the three a caller must be right
  /// about. `note` is the only one with a default, because the sentence — if
  /// there ever is one — is added afterwards.
  ///
  /// WHAT IS DELIBERATELY NOT HERE
  /// There is no task title, no project title and no task identifier. Todoist
  /// arrives in F3 and `docs/plans/F5.md` says plainly that F3 adds those
  /// columns; adding them here would be F5 preparing for a feature it does not
  /// own, which `CLAUDE.md` forbids by name. A SwiftData optional column costs
  /// nothing to add later, so there is no durability argument for landing them
  /// early. See the PR description's proposed spec delta.
  ///
  /// - Parameters:
  ///   - id: this row's identity. Defaults to a fresh one; supplied explicitly
  ///     only by tests that want to name a row.
  ///   - kind: internal or external.
  ///   - timestamp: the instant of the tap, from the engine's clock.
  ///   - sessionID: the identity of the block the tap happened in.
  ///   - note: the sentence, if one has already been written. Normally `nil`.
  init(
    id: UUID = UUID(),
    kind: DistractionKind,
    timestamp: Date,
    sessionID: UUID,
    note: String? = nil) {
    self.id = id
    self.kind = kind
    self.timestamp = timestamp
    self.sessionID = sessionID
    self.note = note
  }
}
