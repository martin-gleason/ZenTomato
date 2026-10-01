import AlarmKit

/// Everything the Lock Screen and the Dynamic Island need in order to draw a
/// running block.
///
/// WHY THIS TYPE EXISTS AT ALL, FOR A READER WHO DOES NOT WRITE SWIFT
/// The countdown you see on a locked phone is not drawn by ZenTomato. iOS draws
/// it, by running a second, tiny program that ships inside the app — the widget
/// extension. That second program is a *separate process*: it cannot open the
/// app's database, it cannot see the timer, and it cannot ask the app anything.
/// Whatever it is going to show has to be handed to it in advance.
///
/// This is that hand-over. When a block starts, the app fills in the three
/// values below and gives them to the system along with the alarm. iOS carries
/// them across to the Lock Screen and hands them back to the widget when it
/// draws. They are decided once, at the moment the block starts, and are frozen
/// for the life of that block.
///
/// FOUR FIELDS, AND THE FOURTH ARRIVED WITH THE THING THAT FILLS IT IN
/// This said three, and refused an empty fourth for a later screen naming the
/// work: a field that is always empty looks finished. The fourth is the theme
/// (`D58`), and it is filled in at every block start. The refusal stands for
/// anything else.
///
/// **The fourth is optional, and that is what keeps the Lock Screen from going
/// blank across an update.** An alarm scheduled by the previous build carries no
/// theme. If the field were required, decoding that alarm would fail — and the
/// failure mode described below is a blank card with no error anywhere. Optional,
/// it decodes as `nil` and draws Sage.
///
/// THIS FILE IS COMPILED INTO BOTH PROGRAMS
/// It is listed in the sources of the app *and* of the widget extension, so
/// there is exactly one definition of the shape of this data. Copying it into
/// the widget instead would be the single most reliable way to ship a blank
/// Lock Screen: the two copies would encode slightly differently, the decode
/// would fail, and nothing anywhere would report an error.
///
/// `AlarmMetadataTests` checks that the sharing is still declared, by reading
/// the project description and looking for this directory in the widget's list
/// of sources. It is worth being precise about what that does and does not
/// prove, because a comment claiming a guarantee nobody implemented is worse
/// than claiming none. It proves the two programs are still told to compile the
/// same file. It cannot compare the widget's copy of this type against the
/// app's, because the test target links only the app.
///
/// `AlarmMetadata` is AlarmKit's name for "data that travels with an alarm". It
/// requires the value to be convertible to and from a stream of bytes
/// (`Codable`), comparable (`Hashable`), and safe to move between threads
/// (`Sendable`) — all three of which Swift works out by itself here, because
/// every field is one of those already.
struct FocusAlarmMetadata: AlarmMetadata {
  // MARK: Stored properties

  /// Which kind of block is running: focus, short break, or long break.
  ///
  /// The Lock Screen prints its name, and the Dynamic Island chooses its symbol
  /// from it.
  let kind: BlockKind

  /// How much of the sprint is finished, from 0 to 1 — **the tomato's fill** under `D52`, restored by
  /// `D57`.
  ///
  /// **`nil` when there is no sprint count to divide by.** That is the same absence `SprintCount`
  /// refuses to invent a number for, and the reason is the same: zero is not *no answer*, it is the
  /// claim *no pomodoros finished yet*, and this is the case where the activity cannot make a claim.
  /// The glyph draws an empty fruit rather than a wrong one. It is also the divide-by-zero.
  ///
  /// **IT LIVES ON THE METADATA AND NOT IN THE VIEW, AND THAT IS THE WHOLE REASON IT IS TESTABLE.**
  /// This project has no UI test target, so anything expressed inside a SwiftUI `body` is beyond every
  /// instrument the repository owns — and the widget is the surface where that already cost something
  /// (`A25`, a sprint count squeezed to zero width for the life of the card, invisible to a green
  /// suite). The arithmetic is four cases and belongs where a test can reach it; the drawing is checked
  /// on hardware by `F2f-T5` and nowhere else, which is stated rather than implied.
  var sprintFill: Double? {
    guard pomodorosPerSprint > 0 else { return nil }
    return min(max(Double(completedInSprint) / Double(pomodorosPerSprint), 0), 1)
  }

  /// How many focus blocks of this sprint have been *finished* by the time this
  /// block started. Skipped blocks do not count, exactly as they do not count in
  /// the app's own progress indicator — the Lock Screen and the app cannot be
  /// allowed to disagree about what a pomodoro is.
  let completedInSprint: Int

  /// How many focus blocks make up the sprint this block belongs to, between 1
  /// and 12. Carried rather than looked up because the widget has no settings to
  /// look it up in.
  let pomodorosPerSprint: Int

  /// The theme the block started in, as `Theme`'s raw value (`D58`) — already
  /// resolved, so Auto never reaches the widget. `nil` from an alarm scheduled
  /// before themes existed.
  ///
  /// **A `String`, not the enum, for the reason `AppSettings` stores one:** a
  /// theme name this build does not know must draw Sage, not fail to decode.
  var themeRawValue: String?

  /// The theme to draw the Lock Screen and the Island in. Sage when absent or unknown.
  var theme: Theme {
    themeRawValue.flatMap(Theme.init(rawValue:)) ?? .sage
  }
}
