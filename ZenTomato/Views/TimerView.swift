import SwiftData
import SwiftUI

/// The timer screen, wired to the engine.
///
/// WHAT THIS FILE DOES AND WHAT IT DELIBERATELY DOES NOT
/// It reads the engine, turns what it finds into finished strings and numbers,
/// and hands them to `TimerScreen`, which draws them. It owns the settings sheet
/// and the blocking cover that appears when alarms are switched off. It contains
/// no layout and no colours; those are all in `TimerScreen`.
///
/// THE NUMBER IS NOT COUNTED DOWN
/// Nothing in this app decrements a number once a second. The engine records the
/// wall-clock instant the block ends, and this screen asks it "how much is left
/// *at this moment*" each time it redraws. That is the difference between a timer
/// that survives being backgrounded and one that quietly loses four minutes
/// because iOS suspended the app.
///
/// The redraw comes from `TimelineView`, which is SwiftUI's own once-a-second
/// heartbeat. It is used rather than a repeating timer for one reason: it stops
/// on its own when the screen goes away, so there is no cancellation to get
/// wrong. It is only a nudge to redraw — never the record of how much time has
/// passed — and while no block is running it is not used at all.
struct TimerView: View {
  // MARK: Internal

  var body: some View {
    screen
      .sheet(isPresented: $showingSettings, onDismiss: settingsSheetClosed) {
        SettingsView()
      }
      // A blocking cover, presented *by this screen*, which is what gives the two
      // failure screens their order: if the database will not open this view is
      // never built, so the alarm explainer can never be drawn on top of the
      // database explainer. The precedence is structural rather than a condition
      // somebody has to remember.
      .fullScreenCover(isPresented: alarmsAreOff) {
        AlarmPermissionView()
      }
  }

  // MARK: Private

  /// How often the number is redrawn while a block runs.
  private static let refreshInterval: TimeInterval = 1

  /// What the screen shows when there is no settings row to read.
  ///
  /// It cannot happen in practice: the app creates the row at launch, before this
  /// screen is ever shown. It used to fall back to the number 25 — which is also
  /// the number a healthy first launch produces — so a database that opened but
  /// held nothing looked exactly like one that was working perfectly. Dashes
  /// cannot be mistaken for a working timer from across the room, which is the
  /// whole point.
  private static let missingReading = "--:--"

  /// The running timer. Handed down by the app, which owns it.
  @Environment(TimerEngine.self) private var engine

  /// The settings row. This comes back as a list because that is the only shape
  /// SwiftData offers, but there is exactly one row by design.
  ///
  /// The screen does not read the six values out of it — the engine holds those,
  /// and reading them twice is how two numbers on one screen start to disagree.
  /// It is here to answer one question: is there a settings row at all?
  @Query private var settings: [AppSettings]

  @State private var showingSettings = false

  /// The screen, redrawn once a second only while something is actually counting.
  @ViewBuilder
  private var screen: some View {
    if engine.isRunning {
      TimelineView(.periodic(from: .now, by: Self.refreshInterval)) { context in
        timerScreen(at: context.date)
      }
    } else {
      timerScreen(at: .now)
    }
  }

  /// Whether the alarm explainer should be covering the screen.
  ///
  /// A one-way binding: the cover has no way to close itself, so nothing writes
  /// back. It lifts when the answer changes, which happens on the app's next
  /// return to the foreground — and since the only place the switch can be
  /// changed is the Settings app, coming back is unavoidable. That is what makes
  /// the promise in the cover's own words ("come back to this screen and it'll
  /// let you through by itself") a promise the code keeps.
  private var alarmsAreOff: Binding<Bool> {
    Binding(get: { self.engine.authorization == .denied }, set: { _ in })
  }

  private func timerScreen(at instant: Date) -> TimerScreen {
    TimerScreen(
      model: model(at: instant),
      onStart: { self.startBlock() },
      onSkip: { self.skipBlock() },
      onStop: { self.stopBlock() },
      onOpenSettings: { self.showingSettings = true })
  }

  // MARK: Turning the engine into something to draw

  private func model(at instant: Date) -> TimerScreenModel {
    guard settings.first != nil else {
      return .noSettingsRow(numeral: Self.missingReading)
    }

    let kind = engine.kind
    // While a block runs this is what is left of it; while the screen is idle the
    // engine returns the whole length of the block Start would begin, because
    // nothing has run yet and all of it is left. One question, one answer, in
    // both states — which is why the idle screen cannot show a different number
    // from the one the next block will actually use.
    let secondsLeft = Self.wholeSeconds(engine.remaining(at: instant))
    let spokenBlock = Self.spokenName(for: kind)

    return TimerScreenModel(
      blockName: spokenBlock.capitalizedFirst,
      kicker: kind.displayName,
      numeral: Self.clockLabel(seconds: secondsLeft),
      spokenNumeral: engine.isRunning
        ? Self.spokenRemaining(seconds: secondsLeft)
        : Self.spokenMinutes(secondsLeft / 60),
      progress: progress,
      completionNote: completionNote,
      // Written by the engine, not by this screen. There is one wording for each
      // failure and it lives with the thing that can fail.
      failureNote: engine.lastFailure?.message,
      controls: engine.isRunning
        ? .running
        : .start(
          isEnabled: true,
          spokenLabel: "Start \(spokenBlock), \(Self.spokenMinutes(secondsLeft / 60))"))
  }

  /// How many pomodoros to draw as done, out of how many.
  ///
  /// While a sprint has just finished the engine's own count is already back to
  /// zero — correctly, because the next sprint starts from nothing — so the rule
  /// reads the size of the sprint that just ended instead. It is the only idle
  /// state in which every segment is filled.
  private var progress: TimerScreenModel.Progress? {
    if let size = engine.lastCompletedSprintSize {
      return TimerScreenModel.Progress(completed: size, total: size)
    }
    return TimerScreenModel.Progress(
      completed: engine.completedInSprint,
      total: engine.pomodorosPerSprint)
  }

  private var completionNote: String? {
    guard let size = engine.lastCompletedSprintSize else { return nil }
    // The singular matters: a sprint of one pomodoro is a real setting, and it is
    // the first thing a reader would notice written as "1 pomodoros done".
    let unit = size == 1 ? "pomodoro" : "pomodoros"
    return "Sprint complete — \(size) \(unit) done."
  }

  // MARK: Commands

  /// Each of these hands the engine a job from inside a button, which is a
  /// synchronous place, so a small piece of asynchronous work is started to carry
  /// it. That is safe here for one specific reason: the engine writes down what
  /// happened *before* it waits for anything, so a piece of work that is
  /// cancelled part way through can lose an alarm — which the app repairs on its
  /// next return to the foreground — and can never lose a block.
  private func startBlock() {
    Task { await engine.start() }
  }

  private func skipBlock() {
    Task { await engine.skip() }
  }

  private func stopBlock() {
    Task { await engine.stop() }
  }

  /// The settings sheet has closed.
  ///
  /// The engine keeps its own copy of the six values, taken at the last block
  /// boundary, and a running block is never allowed to notice a change. But an
  /// *idle* screen must show the new focus length as soon as the sheet is
  /// dismissed, so the engine is asked to re-read. This is the only thing that
  /// happens when the sheet closes: there is no Save, because every change was
  /// already written the moment it was made.
  private func settingsSheetClosed() {
    Task { await engine.synchronize() }
  }

  // MARK: Formatting

  /// How VoiceOver names the block inside a sentence: "Start focus block, 25
  /// minutes".
  private static func spokenName(for kind: BlockKind) -> String {
    switch kind {
    case .work: "focus block"
    case .shortBreak: "short break"
    case .longBreak: "long break"
    }
  }

  /// Rounds a remaining time up to whole seconds.
  ///
  /// Up rather than down, so that a block which has just started reads `25:00`
  /// rather than `24:59`, and `00:00` appears exactly when the block is over
  /// rather than for the whole of its last second.
  private static func wholeSeconds(_ remaining: Duration) -> Int {
    let parts = remaining.components
    guard parts.seconds > 0 || parts.attoseconds > 0 else { return 0 }
    return Int(parts.seconds) + (parts.attoseconds > 0 ? 1 : 0)
  }

  /// Minutes are not carried into hours. A two-hour block reads `120:00`, which
  /// is longer than it is pretty and is unambiguous, where `2:00:00` next to
  /// `04:31` on another day would not be.
  private static func clockLabel(seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }

  private static func spokenMinutes(_ minutes: Int) -> String {
    "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
  }

  private static func spokenRemaining(seconds: Int) -> String {
    let wholeMinutes = seconds / 60
    let remainder = seconds % 60
    let secondsPart = "\(remainder) \(remainder == 1 ? "second" : "seconds")"
    guard wholeMinutes > 0 else { return "\(secondsPart) remaining" }
    return "\(spokenMinutes(wholeMinutes)) \(secondsPart) remaining"
  }
}

// MARK: - String helper

private extension String {
  /// "focus block" becomes "Focus block".
  ///
  /// The same phrase is needed in two shapes: inside a sentence VoiceOver reads
  /// ("Start focus block, 25 minutes") and on its own as the name of the element
  /// ("Focus block"). Deriving one from the other means they cannot drift apart,
  /// and it keeps the phrase written down exactly once.
  var capitalizedFirst: String {
    guard let first else { return self }
    return first.uppercased() + dropFirst()
  }
}

// MARK: - Previews

/// The wired screen, on a throwaway database that lives in memory only.
///
/// Every *state* of this screen is previewed next door in `TimerScreen.swift`,
/// where neither a database nor a timer is needed. This pair exists to check the
/// wiring itself — that the engine reaches the screen, in both appearances.
#Preview("Wired, light") {
  TimerViewPreviewHost(appearance: .light)
}

#Preview("Wired, dark") {
  TimerViewPreviewHost(appearance: .dark)
}

/// Preview scaffolding, never part of what ships.
///
/// A preview has no running app around it, so no database is open and the timer
/// would have nothing to read. This opens a throwaway store that lives in memory
/// only and disappears when the preview closes.
private struct TimerViewPreviewHost: View {
  // MARK: Internal

  /// Forces the preview into light or dark, so the pair is a real check that
  /// colours resolve for both.
  let appearance: ColorScheme

  var body: some View {
    switch bootstrap {
    case .success(let running):
      TimerView()
        .modelContainer(running.container)
        .environment(running.engine)
        .preferredColorScheme(appearance)

    case .failure(let error):
      StoreUnavailableView(technicalDetail: error.localizedDescription)
    }
  }

  // MARK: Private

  /// A container and an engine, built once per preview rather than on every
  /// redraw of the canvas.
  private struct PreviewRun {
    let container: ModelContainer
    let engine: TimerEngine
  }

  @State private var bootstrap: Result<PreviewRun, any Error> = Result {
    let container = try AppModelContainer.make(.inMemory)
    _ = try AppSettings.current(in: container.mainContext)
    return PreviewRun(
      container: container,
      engine: TimerEngine(
        context: container.mainContext,
        clock: SystemTimerClock(),
        alarms: AlarmKitScheduler()))
  }
}
