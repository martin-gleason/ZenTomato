import SwiftData
import SwiftUI

/// The application itself: the first thing that runs, the only place the
/// on-device database is opened, and the only place the timer engine is built.
///
/// **What happens at launch, in order.**
/// 1. `init()` asks `AppModelContainer` to open the store and make sure the
///    settings row exists. That work either succeeds or it does not, and the
///    answer is kept as a `Result` — a value that holds *either* the opened store
///    *or* the error that stopped it.
/// 2. On success it builds the timer engine on top of that store, and registers
///    it in the one place a Lock Screen button can reach it.
/// 3. `body` looks at that answer and shows one of two screens: the timer, or a
///    plain-language explanation of what went wrong.
/// 4. Every time the app comes to the foreground, the engine is asked to
///    reconcile itself with the wall clock. That is the correctness guarantee for
///    the whole feature: the app can be suspended, killed, or left overnight, and
///    the first thing it does on the way back is work out what actually happened
///    while it was away.
///
/// **Why there is no crash-on-failure here.** The obvious shortcut would be to
/// insist the store opens and let the app die if it does not. That would mean a
/// user whose device is out of disk space, or whose database file has been
/// damaged, sees the app bounce off the home screen with no explanation and no
/// clue what to do. `StoreUnavailableView` exists so that never happens, and it
/// is the reason this codebase contains no forced-success operators anywhere.
///
/// **Why the store is opened here and not inside a screen.** Opening a database
/// is expensive and must happen exactly once. SwiftUI rebuilds a screen's
/// contents many times a second; opening the store inside one would open it many
/// times. Doing it in `init()` and handing the result down is the supported
/// pattern, and the same argument applies to the engine.
@main
struct ZenTomatoApp: App {
  // MARK: Lifecycle

  init() {
    let result = AppModelContainer.bootstrap().map { container in
      RunningApp(
        container: container,
        engine: TimerEngine(
          context: container.mainContext,
          // Real time, and real alarms. The engine names neither: it is handed a
          // clock and an alerting system, which is what lets its tests hand it a
          // clock that does not move and an alarm system that does not exist.
          clock: SystemTimerClock(),
          alarms: AlarmKitScheduler()))
    }

    bootstrapResult = result

    if case .success(let running) = result {
      // The app owns the engine for as long as it runs. This second reference is
      // weak and exists for one caller: the Dismiss button on the Lock Screen,
      // which iOS runs with nothing handed to it. See `TimerEngineHolder`.
      TimerEngineHolder.engine = running.engine
    }
  }

  // MARK: Internal

  var body: some Scene {
    WindowGroup {
      rootView
        // The app's single accent colour, set once at the root so that every
        // standard iOS control below it inherits the brand green rather than
        // the system's default blue. Setting it here rather than in an asset
        // file keeps one source of truth for the accent: `ColorRole.action`.
        .tint(Color(.action))
    }
  }

  // MARK: Private

  /// An open database and the timer built on top of it. They succeed or fail
  /// together, so they are held together rather than as two values that could
  /// disagree about whether the app is working.
  private struct RunningApp {
    let container: ModelContainer
    let engine: TimerEngine
  }

  /// Either the running app, or the error that prevented it.
  ///
  /// Resolved once at launch and never changed afterwards, which is why it is a
  /// constant rather than a piece of observed state.
  private let bootstrapResult: Result<RunningApp, any Error>

  /// Whether the app is in front of the user, behind another app, or on its way
  /// out. Watched so the timer can be reconciled on every return.
  @Environment(\.scenePhase) private var scenePhase

  /// The timer if the store opened, the explanation screen if it did not.
  @ViewBuilder
  private var rootView: some View {
    switch bootstrapResult {
    case .success(let running):
      TimerView()
        .modelContainer(running.container)
        .environment(running.engine)
        // Runs once at launch and again on every change of phase, which is what
        // makes returning to the app the moment the timer catches up: a block
        // that ended while the app was asleep is recorded, a clock that moved is
        // corrected, and a permission that changed is noticed.
        //
        // A `.task` rather than a loose piece of background work, so it is tied
        // to the screen's lifetime and cancelled with it — there is no
        // unattended work anywhere in this app.
        .task(id: scenePhase) {
          guard scenePhase == .active else { return }
          await running.engine.synchronize()
        }

    case .failure(let error):
      StoreUnavailableView(technicalDetail: error.localizedDescription)
    }
  }
}
