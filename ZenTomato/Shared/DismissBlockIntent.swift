import AppIntents

/// The Stop button on the full-screen alert iOS shows when a block's alarm goes
/// off. That is now the *only* place it appears.
///
/// WHAT AN "APP INTENT" IS, FOR A READER WHO DOES NOT WRITE SWIFT
/// A button drawn on the Lock Screen is drawn by iOS, not by ZenTomato, and iOS
/// will not hand a piece of ZenTomato's code around to run whenever it likes.
/// So a Lock Screen button cannot be given an ordinary action. Instead the app
/// declares a small named *command* — this type — and the button says "run that
/// command". When somebody taps it, iOS wakes ZenTomato and runs the command
/// inside the app, where the timer lives.
///
/// WHY THERE IS NO LONGER A DISMISS BUTTON ON THE RUNNING COUNTDOWN
/// There was one, and it was removed, because a Lock Screen button cannot be
/// trusted to record what it did. iOS reclaims a backgrounded app's memory
/// whenever it likes; a tap that arrives with no app running reaches nothing,
/// and the block is left to be reconciled later from its end time alone — which
/// reads it as *finished*. So deliberately abandoning a block from a locked
/// phone quietly added a pomodoro you had not earned, to the one number this
/// whole app exists to produce.
///
/// Abandoning a block now happens in the app, where the engine is certainly
/// running and can record what actually happened.
///
/// WHY IT DOES ALMOST NOTHING ITSELF
/// Everything this command does is a single call into the timer engine, which
/// decides what the tap meant by comparing the current time to the block's end
/// time. Reaching this command at all now implies the alarm was sounding, so the
/// answer will be *completed* — but the engine is still asked rather than told.
/// The rule lives in one tested place, and a button that assumed the answer
/// would be a second copy of it that could drift.
///
/// THIS FILE IS COMPILED INTO BOTH PROGRAMS
/// The widget extension needs the *name* of this command so its button can refer
/// to it; the app needs the *body* so it can run it. Hence the compile-time
/// switch below: the widget gets a command that does nothing, because iOS never
/// runs a Live Activity command in the widget's process — it always runs it in
/// the app's.
struct DismissBlockIntent: LiveActivityIntent {
  /// The name iOS uses for this command.
  ///
  /// It must be `static let` and not `static var`. Swift 6 refuses a mutable
  /// shared value here outright — a name that anything could change while the
  /// system was reading it is exactly the kind of shared mutable state the
  /// language now rejects — and the error message is unhelpful enough to be
  /// worth naming in a comment.
  static let title: LocalizedStringResource = "Dismiss block"

  /// Keeps this command out of Shortcuts and Spotlight.
  ///
  /// It is the alarm alert's plumbing, not a feature. Offering "Dismiss block"
  /// as a shortcut a person could run at any moment would put back exactly the
  /// outside-the-app abandon path that was just removed.
  static let isDiscoverable = false

  /// Runs when the button is tapped.
  ///
  /// In the app this reaches the running engine through `TimerEngineHolder` and
  /// lets it decide what the tap meant. If the app is not resident — iOS took
  /// its memory back while the phone sat locked — there is no engine to reach
  /// and the call does nothing; the next foreground reconciles from the stored
  /// end time and records the block as completed.
  ///
  /// That fallback is now *correct* rather than merely tolerable, which is the
  /// point of removing the mid-block button: the only way to arrive here is a
  /// sounding alarm, so a block reconciled as finished really did finish.
  func perform() async throws -> some IntentResult {
    #if !WIDGET_EXTENSION
    await TimerEngineHolder.dismissRunningBlock()
    #endif
    return .result()
  }
}
