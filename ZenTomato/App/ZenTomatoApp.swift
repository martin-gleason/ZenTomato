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

  /// The flight recorder. Held for the life of the app so it stays subscribed.
  ///
  /// **Started before anything else, and it is the cheapest line in this
  /// initialiser** — `MXMetricManager.add` registers a listener and returns.
  /// Nothing is sampled, nothing is polled, and no work joins any hot path; iOS
  /// gathers hangs and crashes itself and delivers them in a batch on a later
  /// launch. See `HangReporter` for why nothing is ever transmitted.
  private let hangReporter = HangReporter.start()

  init() {
    let result = AppModelContainer.bootstrap().map { container in
      // THE WHOLE TODOIST STACK, BUILT IN ONE PLACE AND HANDED DOWN.
      //
      // Reading upwards: a transport that owns its own session, a client that is
      // the only thing in the app that builds a request, the Keychain box the
      // credential lives in, and three main-thread collaborators that hold the
      // database handle. Nothing below this line reaches for a global, so a test
      // or a preview substitutes any of them by handing over a different value.
      // Named `credentials` rather than the obvious word on purpose: the
      // secret scanner looks for a credential-shaped name sitting beside a long
      // opaque value, and the obvious name beside a long type name is exactly
      // that shape. A check that is wrong about something innocent is a check
      // somebody eventually switches off.
      let credentials = KeychainTokenStore()
      let client = TodoistClient(transport: URLSessionTransport(), tokens: credentials)

      // D21b: THE TASKS TICKED OFF SINCE THIS SPRINT BEGAN.
      //
      // In memory, one sprint, never saved — `CompletedTaskRecord` is the
      // history, and a second store of the same fact is a second thing that can
      // disagree. Built here so the plan store, the picker and the completion
      // path are all looking at the same set rather than at three copies.
      let completedThisSprint = SprintCompletions()
      let plan = SessionPlanStore(context: container.mainContext, completedThisSprint: completedThisSprint)

      // THE MUSIC STACK, BUILT THE SAME WAY AND FOR THE SAME REASON.
      //
      // Reading upwards: the one place that touches the player, the one place
      // that asks about permission and subscription, the one place that reads
      // the library, and the row on disk remembering the switch and the choice.
      // The coordinator is handed all four and is the only thing that can decide
      // to make a sound.
      //
      // **Nothing here plays anything and nothing asks for a permission.**
      // Building the stack is inert; `start()` below is what begins the work,
      // and the permission is asked the first time somebody switches music on.
      let library = AppleMusicLibrary()
      let musicCache = MusicLibraryCache(context: container.mainContext, library: library)
      let musicCoordinator = MusicCoordinator(
        player: AppleMusicPlayer(),
        availability: AppleMusicAvailability(),
        library: library,
        preferences: MusicPreferenceStore(context: container.mainContext))

      // Named rather than built inline, because two things now need it: the app
      // hands it to the screen, and the music observer subscribes to it.
      let engine = TimerEngine(
        context: container.mainContext,
        // Real time, and real alarms. The engine names neither: it is handed a
        // clock and an alerting system, which is what lets its tests hand it a
        // clock that does not move and an alarm system that does not exist.
        clock: SystemTimerClock(),
        alarms: AlarmKitScheduler(),
        // The one thing the timer knows about Todoist, and it is a read: at
        // the start of each focus block it asks the plan for the next item.
        // The timer never sees a request, a token or a cached row.
        attachments: plan)

      // F7. Made after the engine because it holds a weak reference to it: a tap
      // arriving during its own block is offered to the engine so the
      // end-of-block sheet can ask about it. The row itself is written whether
      // or not the engine is there to hear.
      let watchLink = PhoneWatchLink(context: container.mainContext, engine: engine)

      return RunningApp(
        container: container,
        engine: engine,
        tokens: credentials,
        cache: TodoistCacheStore(context: container.mainContext, client: client),
        plan: plan,
        completion: TaskCompletion(context: container.mainContext, client: client),
        music: musicCoordinator,
        library: library,
        musicCache: musicCache,
        // The one thing that tells music a block has changed. It subscribes to
        // the engine's own published state — F4 adds no hook to the engine and
        // invents no second notion of "the block changed".
        blockPhase: BlockPhaseObserver(engine: engine, coordinator: musicCoordinator),
        completedThisSprint: completedThisSprint,
        // The one thing that empties that set. It subscribes to the engine's own
        // published state exactly as the music observer does — F6 adds no hook to
        // the engine and invents no second notion of "a sprint ended".
        sprintBoundary: SprintBoundaryObserver(engine: engine, completions: completedThisSprint),
        // F7. The phone's end of the wrist connection, and the thing that keeps
        // the wrist told what is running. Both are no-ops on a phone with no
        // watch paired: F7 is strictly additive, and an unpaired watch, one left
        // on a charger, or one that was never bought must not change how this
        // app behaves in any respect.
        watchLink: watchLink,
        watchState: WatchStatePublisher(
          engine: engine, link: watchLink, plan: plan, context: container.mainContext))
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

    /// Where the Todoist credential lives.
    let tokens: any TokenStore

    /// The local mirror of Todoist.
    let cache: TodoistCacheStore

    /// The session plan and its cursor.
    let plan: SessionPlanStore

    /// The one thing in this app that can change anything in Todoist.
    let completion: TaskCompletion

    /// The switch, the choice, and the only thing in this app that can make a
    /// sound.
    let music: MusicCoordinator

    /// Somebody's music library, read-only.
    let library: any MusicLibraryReading
    let musicCache: MusicLibraryCache

    /// Turns the engine's own published block changes into calls on the
    /// coordinator. Held here so it lives exactly as long as the app does, and
    /// so nothing in this codebase starts a piece of work with no owner.
    let blockPhase: BlockPhaseObserver

    /// The tasks ticked off since this sprint began (D21b).
    let completedThisSprint: SprintCompletions

    /// Empties that set when a sprint ends. Held for the same reason the block
    /// observer is: it owns a running piece of work, and nothing in this app
    /// starts one with no owner.
    let sprintBoundary: SprintBoundaryObserver

    /// The phone's end of the connection to the wrist (F7). Receives taps and
    /// writes them; sends nothing on its own.
    let watchLink: PhoneWatchLink

    /// Tells the wrist what is running, on change rather than on a schedule.
    /// Held for the same reason as the two observers above: it owns a running
    /// piece of work.
    let watchState: WatchStatePublisher
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
      TimerView(
        tokens: running.tokens,
        cache: running.cache,
        plan: running.plan,
        completion: running.completion,
        music: running.music,
        library: running.library,
        musicCache: running.musicCache)
        .modelContainer(running.container)
        .environment(running.engine)
        // Handed down rather than reached for, so the picker, the plan and the
        // completion path cannot end up looking at three different sets.
        .environment(running.completedThisSprint)
        // MUSIC BEGINS OBSERVING HERE, AND NOT ONE MOMENT EARLIER.
        //
        // Two subscriptions start: the coordinator's, which notices a permission
        // or a subscription changing underneath the app, and the block observer's,
        // which turns the engine's own published state into "a block changed".
        // **Neither of them asks for a permission and neither plays anything** —
        // permission is asked the first time somebody switches music on, and
        // sound is only ever produced by the coordinator's one decision point.
        //
        // A `.task` rather than loose work, so both are tied to the screen's
        // lifetime and cancelled with it. There is no unattended work anywhere in
        // this app.
        .task {
          running.music.start()
          running.blockPhase.start()
          // D21b begins watching here and not one moment earlier. It reads the
          // engine; it never writes to it, and it plays and asks for nothing.
          running.sprintBoundary.start()
          // F7. Sends the current block immediately rather than waiting for the
          // next boundary, so a watch opened mid-block is told what is running
          // instead of showing nothing until the block after this one.
          running.watchState.start()
        }
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
          // AND THE MUSIC CATCHES UP TOO, WHICH IS THE WAY BACK FROM A REFUSED
          // PERMISSION. Whether this app may play music was read once at launch
          // and never again, so the commonest first-run outcome — one mis-tap on
          // the system prompt — left music dead for the life of the process,
          // while the app's own sheet told the person to go to the Settings app
          // and offered a button that took them there. They granted it, came
          // back, and nothing had changed. This line is what makes coming back
          // mean something. It reads; it can prompt for nothing.
          running.music.refreshAvailability()
        }

    case .failure(let error):
      StoreUnavailableView(technicalDetail: error.localizedDescription)
    }
  }
}
