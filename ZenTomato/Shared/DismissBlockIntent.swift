import AppIntents

/// The Dismiss button that appears on the Lock Screen, in the Dynamic Island,
/// and on the full-screen alert iOS shows when a block's alarm goes off.
///
/// WHAT AN "APP INTENT" IS, FOR A READER WHO DOES NOT WRITE SWIFT
/// A button drawn on the Lock Screen is drawn by iOS, not by ZenTomato, and iOS
/// will not hand a piece of ZenTomato's code around to run whenever it likes.
/// So a Lock Screen button cannot be given an ordinary action. Instead the app
/// declares a small named *command* — this type — and the button says "run that
/// command". When somebody taps it, iOS wakes ZenTomato and runs the command
/// inside the app, where the timer lives.
///
/// WHY IT DOES ALMOST NOTHING ITSELF
/// Everything this command does is a single call into the timer engine. That is
/// deliberate. Dismiss means two completely different things depending on when
/// it is tapped:
///
///   * the block had already finished and the alarm was sounding — the block was
///     *completed*, and dismissing is just silencing the alarm;
///   * the block was still running — the block was *abandoned*, and must not be
///     counted as a finished pomodoro.
///
/// That decision is made by comparing the current time to the block's end time,
/// and it is a decision about the data rather than about the button. It
/// therefore lives in one place inside the engine, where it is tested, rather
/// than here where it would be a second copy of the same rule.
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
  /// It is the Lock Screen button's plumbing, not a feature. Offering "Dismiss
  /// block" as a shortcut a person could run at any moment would be offering a
  /// way to abandon a block from outside the app, which nothing in the spec asks
  /// for.
  static let isDiscoverable = false

  /// Runs when the button is tapped.
  ///
  /// In the app this reaches the running engine through `TimerEngineHolder` and
  /// lets it decide what the tap meant. If the app is not resident — iOS took
  /// its memory back while the phone sat locked — there is no engine to reach,
  /// the call does nothing, and the next time the app comes to the foreground
  /// its reconciliation pass works out what happened from the stored end time.
  /// Nothing is lost by doing nothing here.
  func perform() async throws -> some IntentResult {
    #if !WIDGET_EXTENSION
    await TimerEngineHolder.dismissRunningBlock()
    #endif
    return .result()
  }
}
