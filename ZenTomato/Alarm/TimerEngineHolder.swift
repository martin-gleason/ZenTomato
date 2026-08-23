import Foundation

/// The one way a Lock Screen button can reach the running timer.
///
/// THIS IS THE ONLY GLOBAL VARIABLE IN THE APP, AND IT IS HERE FOR ONE REASON
/// Every other part of ZenTomato receives what it needs from whatever created
/// it: screens are handed the engine, the engine is handed a database and a
/// clock. That is the arrangement that makes each piece testable in isolation,
/// and it is worth defending.
///
/// `DismissBlockIntent` is the exception, and it is not an exception by choice.
/// iOS creates and runs that command itself, from scratch, with nothing handed
/// to it — there is no screen above it, no engine passed in, and no opportunity
/// to pass one. A command invoked by the system has no route into the app's
/// object graph except a known, fixed place to look. This is that place.
///
/// WHY THE REFERENCE IS `weak`
/// `weak` means "point at this, but do not keep it alive". The engine's real
/// owner is the app itself, which holds it for as long as the app runs. If this
/// held a second, ordinary reference, then the day the app stopped owning an
/// engine — a future where the engine is rebuilt, or a test that makes one and
/// throws it away — this variable would quietly keep the old one alive and the
/// app would have two engines, one of them stale, both writing to the same
/// database. A weak reference simply becomes empty instead.
///
/// WHY IT IS `@MainActor`
/// The engine touches the database, and SwiftData's read/write handle is not
/// safe to use from more than one thread. Everything that touches it in this app
/// is confined to the main thread, this included. Swift enforces that: a global
/// that anything could read from any thread would not compile under this
/// project's concurrency settings, and confining it is what makes it legal as
/// well as correct.
@MainActor
enum TimerEngineHolder {
  // MARK: Internal

  /// The engine belonging to the running app, if there is one.
  ///
  /// Set once, at launch, by `ZenTomatoApp`. Nothing else may write to it.
  static weak var engine: TimerEngine?

  /// Tells the running engine that somebody tapped Dismiss.
  ///
  /// A named function rather than letting the command reach in and call the
  /// engine itself, for two reasons. It keeps the one place that knows this
  /// global exists down to this file — the command that calls it is compiled
  /// into the widget extension too, where there is no engine and no database to
  /// have one. And it means the awkward part of the arrangement, that this may
  /// legitimately do nothing at all, is explained once here rather than at the
  /// call site.
  ///
  /// **What happens when this does nothing, stated exactly.** It does nothing
  /// when iOS has already reclaimed the app's memory, which on a locked phone is
  /// most of the time. The block is not lost — the next time the app comes to
  /// the foreground, reconciliation reads the block's stored end time and writes
  /// it down. But reconciliation has no way of knowing this button was ever
  /// pressed, so it records the block as **completed**, and a block the person
  /// deliberately abandoned four minutes in is counted as a finished pomodoro
  /// that fills a progress segment and earns a step towards the long break.
  ///
  /// That loss is accepted rather than hidden. Fixing it would mean the Lock
  /// Screen leaving a note somewhere the app can find later, and the widget has
  /// no database, no shared file and no way to reach one. The honest summary is
  /// that dismissing a running block from a locked phone is reliably recorded
  /// only while the app is still resident.
  static func dismissRunningBlock() async {
    await engine?.handleDismiss()
  }
}
