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
/// THREE FIELDS, AND WHY THERE IS NOT A FOURTH
/// A later version of this screen will name what is being worked on rather than
/// which kind of block is running, and it would be easy to add an empty field
/// for that now. It is deliberately not done: a field that is always empty looks
/// finished, so the next person to read this file would believe the work was
/// already half done. Three fields today; a fourth arrives with the thing that
/// fills it in.
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

  /// How many focus blocks of this sprint have been *finished* by the time this
  /// block started. Skipped blocks do not count, exactly as they do not count in
  /// the app's own progress indicator — the Lock Screen and the app cannot be
  /// allowed to disagree about what a pomodoro is.
  let completedInSprint: Int

  /// How many focus blocks make up the sprint this block belongs to, between 1
  /// and 12. Carried rather than looked up because the widget has no settings to
  /// look it up in.
  let pomodorosPerSprint: Int
}
