<title>F2 Build Contract</title>

# F2 — Build contract

**Architect's contract for `docs/plans/F2.md`. Two engineers, one tree, one branch (`F2/timer-engine`).**

This document is normative. Where it disagrees with a reviewer's taste, this document wins; where it
disagrees with `docs/specs/SPEC.md` or `CLAUDE.md`, those win and this document is the defect.

Read `docs/plans/F2.md` first — it is the *what*. This is the *where, in which file, owned by whom*.

---

## 0. What was verified against the SDK before writing this

`docs/learnings/alarmkit-api.md` was spot-checked against the `.swiftinterface` it names. Four
corrections and confirmations that change what you write:

1. **`AlarmPresentation.Alert.stopButton` is deprecated as of iOS 26.1**, and a new
   `init(title:secondaryButton:secondaryButtonBehavior:)` exists that is `@available(iOS 26.1, *)`.
   Our deployment target is **26.0**, so we use the older
   `init(title:stopButton:secondaryButton:secondaryButtonBehavior:)`. It is marked
   `@available(iOS, deprecated: 26.1, …)`, which at a 26.0 deployment target emits **no warning** —
   verified by type-checking a probe with `-target arm64-apple-ios26.0 -swift-version 6
   -strict-concurrency=complete`, which produced zero diagnostics. Do not add an `#available` branch
   for the 26.1 initialiser; that is preparing for a platform we do not target.

2. **AlarmKit is usable from Swift 6 strict-concurrency code with no ceremony.** `AlarmManager` is a
   non-`Sendable` class and `AlarmManager.shared` is a plain `static let`, which looks like it should
   trip `complete` checking. It does not — verified: a probe touching `authorizationState`,
   `schedule(id:configuration:)` and `cancel(id:)` from both a `@MainActor` class and a `nonisolated`
   function type-checked clean. No `@preconcurrency import`, no `nonisolated(unsafe)`. If you find
   yourself reaching for either, stop and re-read this paragraph.

3. **`ActivityConfiguration(for: AlarmAttributes<Metadata>.self)` + `DynamicIsland` + a
   `LiveActivityIntent` all type-check** under the same flags. One gotcha, and it is a hard error:
   an App Intent's `title` must be `static let`, never `static var` — `static var` fails with
   *"static property 'title' is not concurrency-safe because it is nonisolated global shared mutable
   state"*. Verified both ways.

4. `AlarmManager.AlarmError` has exactly one case, `.maximumLimitReached`. Every other failure
   arrives as some other `Error`. Do not `switch` exhaustively over AlarmKit errors expecting more.

**Everything else in `docs/learnings/alarmkit-api.md` stands.** `AlarmConfiguration.timer` takes a
`TimeInterval` duration, `Countdown.pauseButton` is optional, control methods are synchronous and
throwing, and the extension is a separate process that cannot read SwiftData.

---

## 1. The two ideas this feature is built on

Everything below is downstream of these. If a line of code contradicts one of them, the line is wrong.

**The timer does not count.** `endsAt: Date` is the truth. Nothing derives the truth from a tick.
A `TimelineView` refreshes the label once a second; a `Task.sleep` wakes the engine at the boundary.
Both are *notifications that time has passed*, never the record of how much.

**Settings are read once, at a block boundary, into an immutable snapshot.** The running block holds a
`TimerSettingsSnapshot` — a `Sendable` struct copy of the six values taken the instant the block
started. Nothing running ever re-reads `AppSettings`. This is what makes "settings apply at the next
boundary" true *by construction* rather than by anybody remembering, and it is why
`settingsChangeMidBlock` is a cheap test rather than a careful one.

---

## 2. Decisions this contract takes, so no engineer has to

These were left open by `F2.md` and are now closed. Do not relitigate; do not "improve" them.

| # | Decision |
|---|---|
| D-a | **`skip()` advances the cycle exactly as a completed block would, except a skipped WORK block does not increment `completedInSprint`.** Skipping work #4 of 4 therefore leads to a short break, then work #4 again. The long break is earned by four *completed* pomodoros, never by four attempts. |
| D-b | **A skipped break is also recorded with `wasAbandoned = true`,** and it *does* advance the cycle. F6 counts pomodoros as work blocks with `wasAbandoned == false`; the break rows are there for honesty, not for counting. |
| D-c | **`stop()` abandons the sprint.** It records the running block as abandoned, cancels the alarm, sets `completedInSprint = 0`, and returns to idle with `.work` next. That is what distinguishes it from `skip()`. |
| D-d | **Auto-start only chains blocks the app is alive to observe ending.** On restore-with-expiry the engine records exactly **one** session — the block that was running — and returns to **idle**, whatever `autoStartNextBlock` says. This is the direct answer to `restoreAfterLongGap`: there is no replay loop, because there is nothing to replay. Auto-starting a block that began at 3 a.m. is a lie about how long you worked. |
| D-e | **The block recorded on restore-with-expiry has `wasAbandoned = false`.** It ran to its end and the alarm fired; the user simply was not looking. |
| D-f | **The display refresh is `TimelineView(.periodic(from:by: 1))`, not a `Timer`.** No `Timer.publish`, no `scheduledTimer`, no `DispatchQueue.main.asyncAfter`. A `TimelineView` stops on its own when the view leaves the screen and has no cancellation story to get wrong. |
| D-g | **The boundary is one cancellable `Task` owned by the engine**, sleeping on the *continuous* clock until the deadline. It is cancelled and replaced on every transition. It is a convenience: `synchronize()` on foreground is the correctness guarantee, and the engine must be correct with the task never running at all. |
| D-h | **`cancelOutstanding()` cancels every alarm this app has scheduled**, by reading `AlarmManager.shared.alarms` — not by remembering an id. After a relaunch the scheduler has no memory, and "cancel everything of ours" is the only self-healing answer. It is also the defence against `maximumLimitReached`. |
| D-i | **The dismiss decision lives in the engine, not the intent.** `DismissBlockIntent.perform()` calls one engine method; the engine compares the current instant to `endsAt` and decides *completed* versus *abandoned*. One decision point, tested. |
| D-j | **Settings is a sheet, not a navigation bar.** `TimerView` keeps F1's bare screen — no `NavigationStack` wrapping the timer, no toolbar. A small gear button sits as a top-trailing overlay and presents `SettingsView` in a sheet, which has its own `NavigationStack` and a Done button. |
| D-k | **Settings inputs are `Stepper` and `Toggle` only.** No `TextField`, no `TextEditor`, no numeric keypad. This is the no-capture-surface rule; a free-text field on the only writable screen in the app is the exact thing the reviewer greps for. Bounds are enforced by the `Stepper`'s range *and* clamped again when the snapshot is taken. |
| D-l | **State is persisted before any `await`.** `start()`, `skip()` and `stop()` write `TimerState` and `PomodoroSession` and `save()` *first*, then await the alarm. A cancelled Task can therefore lose an alarm — which reconciliation repairs — but can never lose a block. |
| D-m | **The engine never imports AlarmKit.** It talks to `any AlarmScheduling` and to our own `AlarmAuthorization` enum. `AlarmKitScheduler.swift` is the single file in the app target that says `import AlarmKit`. The test target links none of it. |

---

## 3. File layout

Every file F2 adds or changes. Nothing else may appear in the diff.

### 3.1 New — the pure domain (`ZenTomato/Timer/`)

No SwiftData, no SwiftUI, no AlarmKit. `import Foundation` only. This is the part that is provable.

| File | Purpose |
|---|---|
| `BlockKind.swift` | `enum BlockKind: String, Codable, Sendable, CaseIterable { case work, shortBreak, longBreak }`. Carries `displayName: String` ("Focus", "Short break", "Long break") — the Live Activity and the timer screen both read it, so it lives with the type rather than in two views. String raw value so a stored row stays readable and reorderable. |
| `TimerSettingsSnapshot.swift` | The six values as an immutable `Sendable` struct, plus `init(clamping: AppSettings)` and `func duration(for: BlockKind) -> Duration`. The clamping initialiser is the second line of defence behind the `Stepper` ranges. |
| `SettingsBounds.swift` | `enum SettingsBounds` with `static let minutes: ClosedRange<Int> = 1...120` and `static let pomodorosPerSprint: ClosedRange<Int> = 1...12`. One definition, consumed by the snapshot's clamp and by the settings screen's steppers, so the two cannot drift. Doc comment must say why 1 minute is a real setting (D10: it makes the cycle hand-testable in eight minutes). |
| `TimerCycle.swift` | The state machine, as pure static functions. See §6 for the exact contract. This file is where `cycleWithDefaults`, `cycleWithSprintOfOne` and `longBreakResetsCount` are proved, with no clock and no database anywhere near them. |
| `TimerClock.swift` | `protocol TimerClock: Sendable` — `var now: Date`, `var continuousNow: ContinuousClock.Instant`, `func sleep(until: ContinuousClock.Instant) async throws`. Plus `struct SystemTimerClock: TimerClock`. Injecting `sleep` is what lets the boundary task exist and still leave no test able to sleep. |
| `TimerEngine.swift` | `@MainActor @Observable final class TimerEngine`. The whole of F2-T2 and F2-T4. Exact surface in §5. |
| `TimerEngineFailure.swift` | `enum TimerEngineFailure: Equatable, Sendable { case alarmSchedulingFailed, alarmCancellationFailed, persistenceFailed }`. Surfaced on the engine as `lastFailure` and shown as an inline warning row on the timer screen. An alarm that silently fails to schedule is the worst bug this feature can ship; it must be visible. |

### 3.2 New — the alarm seam (`ZenTomato/Alarm/`)

| File | Purpose |
|---|---|
| `AlarmScheduling.swift` | `@MainActor protocol AlarmScheduling: AnyObject`. **The mitigation `F2.md` promises for its largest risk.** Four members, no AlarmKit types anywhere in the signature. See §5.2. |
| `AlarmAuthorization.swift` | `enum AlarmAuthorization: Sendable { case notDetermined, denied, authorized }`. Our mirror of AlarmKit's enum, so the engine, the views and the tests never import AlarmKit. |
| `BlockAlarmRequest.swift` | `struct BlockAlarmRequest: Equatable, Sendable { let id: UUID; let kind: BlockKind; let endsAt: Date; let soundEnabled: Bool }`. `id` is the block's `sessionID`. |
| `AlarmKitScheduler.swift` | **The only `import AlarmKit` in the app target.** Implements `AlarmScheduling`. Contains the single `endsAt.timeIntervalSince(now)` conversion site, the cancel-before-schedule order, and the `AlarmAttributes` construction. If AlarmKit disappoints, this one file is replaced. |
| `TimerEngineHolder.swift` | `@MainActor enum TimerEngineHolder { static weak var engine: TimerEngine? }`. How `DismissBlockIntent` — which the system invokes in our process with no view hierarchy — reaches the running engine. Registered once by `ZenTomatoApp`. Documented as the *only* global in the app, with the reason: an App Intent has no other route in. |

### 3.3 New — shared between app and extension (`ZenTomato/Shared/`)

Compiled into **both** the app target and `ZenTomatoActivity`. See §4 for why that is right.

| File | Purpose |
|---|---|
| `FocusAlarmMetadata.swift` | `struct FocusAlarmMetadata: AlarmMetadata` — `kind: BlockKind`, `completedInSprint: Int`, `pomodorosPerSprint: Int`. Everything the Lock Screen needs, because **the extension is a separate process and cannot read SwiftData**. It imports AlarmKit for the protocol conformance and nothing else. No task title, no task id: F3 adds that field, F2 does not reserve space for it. |
| `DismissBlockIntent.swift` | `struct DismissBlockIntent: LiveActivityIntent`. `static let title` — never `static var`. `perform()` is `@MainActor`, resolves `TimerEngineHolder.engine`, calls `handleDismiss()`, returns `.result()`. If the engine is absent (app not resident), it returns cleanly and the next foreground `synchronize()` does the work. |

### 3.4 New — the widget extension (`ZenTomatoActivity/`)

| File | Purpose |
|---|---|
| `ZenTomatoActivityBundle.swift` | `@main struct ZenTomatoActivityBundle: WidgetBundle` with one widget in it. |
| `BlockLiveActivity.swift` | `ActivityConfiguration(for: AlarmAttributes<FocusAlarmMetadata>.self)` — Lock Screen presentation and `DynamicIsland` (expanded, compactLeading, compactTrailing, minimal). Renders the countdown from `context.state.mode`'s `.countdown(let c)` → `Text(timerInterval: Date.now...c.fireDate, countsDown: true)`. **No pushed updates, ever** — the countdown is client-side from `fireDate`. Colours come from `ColorRole`; type from `Typography`. |
| `SprintDots.swift` | The `● ● ○ ○` progress indicator, drawn from `metadata.completedInSprint` and `metadata.pomodorosPerSprint`. Lives here rather than in `Shared/` because the timer screen's version has different sizing and accessibility needs; two small views beat one view with a mode flag. |

### 3.5 New — screens (`ZenTomato/Views/`)

| File | Purpose |
|---|---|
| `SettingsView.swift` | F2-T5. A `Form`. Six controls: four `Stepper`s and two `Toggle`s, bounded by `SettingsBounds`. Shows a note when `engine.isRunning` saying changes apply to the next block. Reads and writes the single `AppSettings` row via `@Query`. No seventh control. |
| `AlarmPermissionView.swift` | The blocking explainer for `authorization == .denied`, with an Open Settings button (`UIApplication.openSettingsURLString`, opened via `if let url = URL(string:)` — no force unwrap). Its copy must state *why there is no fallback*: a Pomodoro timer that cannot reliably tell you a block ended has no working state to degrade into. This is the file the reviewer will look for when checking "notification permission denied", so the reasoning belongs here in prose, not in a plan. |
| `SprintProgressView.swift` | The `● ● ○ ○` dots for the timer screen, with a VoiceOver label ("2 of 4 pomodoros"). |

### 3.6 Changed

| File | Change | Owner |
|---|---|---|
| `ZenTomato/Views/TimerView.swift` | Rewritten around the engine. `TimelineView` drives the numeral. Start / Skip / Stop. `.disabled(true)` **removed** — grep for it in the diff; its absence is a done-when. Gear overlay → settings sheet. Sprint dots. Inline failure row when `engine.lastFailure != nil`. Full-screen cover when `authorization == .denied`. Keeps every F1 property: `@ScaledMetric` numeral, `minimumScaleFactor`, no `NavigationStack`, no `Color` literal. | B |
| `ZenTomato/App/ZenTomatoApp.swift` | Builds the `TimerEngine` after a successful bootstrap, registers it in `TimerEngineHolder`, injects it with `.environment(_:)`, and calls `synchronize()` on launch and on every `.active` transition of `scenePhase`. | B |
| `ZenTomato/App/AppModelContainer.swift` | `Schema([AppSettings.self])` → `Schema([AppSettings.self, TimerState.self, PomodoroSession.self])`. **One line, plus its comment.** Nothing else in this file moves. | A |
| `project.yml` | The widget target, the app's dependency on it, `NSSupportsLiveActivities`. Full text in §4. | B |
| `.swiftlint.yml` | `included:` gains `ZenTomatoActivity`. The `palette_outside_token_layer` custom rule's `included:` regex gains the new directories. Text in §4.4. | B |
| `.gitignore` | Gains `Support/ZenTomatoActivity-Info.plist` beside the existing `Support/ZenTomato-Info.plist` — XcodeGen generates it, so it is a build product. | B |
| `docs/reviews/F2.md` | Created at the end, after the adversarial review. Not during. | both |

### 3.7 Changed — models (`ZenTomato/Models/`)

| File | Purpose |
|---|---|
| `TimerState.swift` (new) | `@Model final class TimerState`. Exactly one row, same singleton pattern and same `@MainActor static func current(in:)` accessor as `AppSettings` — read that file first and match its shape and its documentation density. Fields: `kind: BlockKind`, `startedAt: Date`, `endsAt: Date`, `completedInSprint: Int`, `sessionID: UUID`, `isRunning: Bool`, and the snapshot the running block was started with (`workMinutes`, `shortBreakMinutes`, `longBreakMinutes`, `pomodorosPerSprint`, `soundEnabled`, `autoStartNextBlock` — stored flat, because a struct property on a `@Model` is a composite SwiftData does not need to understand here). |
| `PomodoroSession.swift` (new) | `@Model final class PomodoroSession` — `id: UUID`, `kind: BlockKind`, `startedAt: Date`, `endedAt: Date`, `wasAbandoned: Bool`. Nothing else. F3 adds the Todoist columns to *this* model; F2 writes no field it does not populate. |
| `AppSettings.swift` | **NOT MODIFIED.** Zero lines. It already has the six fields F2 needs and adding anything to it is the scope violation this project polices hardest. If you believe you need to touch it, you have found a design error — stop and escalate. |

**On storing `BlockKind` directly in a `@Model`.** SwiftData persists `Codable` enums natively, and
`F2.md` writes the models that way. Do that. If the compiler or the runtime rejects it, fall back to a
stored `kindRaw: String` with a computed `kind` accessor, and **report the difference in the PR** — do
not silently change the model shape the plan describes.

### 3.8 New — tests (`ZenTomatoTests/`)

| File | Purpose |
|---|---|
| `Support/TestClock.swift` | A `TimerClock` whose `now` and `continuousNow` are set by the test, independently — that independence *is* the clock-skew test. `sleep(until:)` suspends on a continuation the test can fire explicitly, or never fires at all. **No test sleeps.** |
| `Support/SpyAlarmScheduler.swift` | An `AlarmScheduling` that records every `schedule` and `cancelOutstanding` call in order, exposes `outstanding: BlockAlarmRequest?`, and can be told to throw. `skipCancelsAlarm` and `stopCancelsAlarm` assert against `outstanding == nil` *and* against the call order — cancel must precede schedule. |
| `TimerCycleTests.swift` | `cycleWithDefaults`, `cycleWithSprintOfOne`, `longBreakResetsCount`. Pure; no container, no clock. |
| `TimerEngineTests.swift` | `settingsChangeMidBlock`, `abandonedBlockRecorded`, `skippedWorkBlockIsAbandoned`, `sprintEndReturnsToIdle`, `autoStartAdvancesWithinSprint`. |
| `TimerRestorationTests.swift` | `restoreWhileRunning`, `restoreAfterExpiry`, `restoreAfterLongGap`, `clockMovedForward`. |
| `AlarmSchedulingTests.swift` | `skipCancelsAlarm`, `stopCancelsAlarm`, plus: a scheduling failure sets `lastFailure`, and the request's `endsAt` matches the engine's. |
| `AlarmMetadataTests.swift` | `FocusAlarmMetadata` survives a `JSONEncoder`/`JSONDecoder` round trip. This is the only thing that crosses the process boundary to the Live Activity; if it stops encoding, the Lock Screen goes blank and nothing else in the app notices. |
| `SettingsBoundsTests.swift` | The bounds are 1...120 and 1...12; `TimerSettingsSnapshot(clamping:)` pulls an out-of-range stored value back inside. Proves the second line of defence, not just the stepper. |

All 14 tests named in `F2.md`'s table appear above. Swift Testing (`@Test` / `#expect`), never XCTest.

---

## 4. `project.yml` changes

CI regenerates the project from this file on every run, so this YAML is the build. Comment it at the
density the existing file uses — the owner reviews it and does not write Swift.

### 4.1 The app target gains a dependency and one Info.plist key

Inside `targets.ZenTomato`:

```yaml
    # The Live Activity lives in its own bundle inside the app. Listing it as a
    # dependency is what makes Xcode build it and embed it in the app's PlugIns
    # folder; without this line the extension compiles and is never installed,
    # which presents as "the Live Activity simply does not appear" with no error
    # anywhere.
    dependencies:
      - target: ZenTomatoActivity

    info:
      path: Support/ZenTomato-Info.plist
      properties:
        # … every existing key stays exactly as it is …

        # Required for ActivityKit. AlarmKit's countdown alarms present through a
        # Live Activity, so without this key the alarm schedules and nothing is
        # ever drawn on the Lock Screen.
        NSSupportsLiveActivities: true
```

### 4.2 The widget extension target, in full

Add after `ZenTomato` and before `ZenTomatoTests`:

```yaml
  # The Live Activity. A separate bundle because iOS requires one: the Lock
  # Screen and the Dynamic Island are drawn by a different process from the app,
  # and that process cannot read the app's database. Everything the Lock Screen
  # shows therefore travels inside the alarm's metadata — see
  # ZenTomato/Shared/FocusAlarmMetadata.swift.
  ZenTomatoActivity:
    type: app-extension
    platform: iOS
    sources:
      # The extension's own views.
      - path: ZenTomatoActivity
      # Compiled into BOTH bundles. Two targets may list the same directory;
      # XcodeGen supports it, and it is the right answer here — see the note
      # below on why this is not a Swift package and not a copied file.
      - path: ZenTomato/Shared
      - path: ZenTomato/DesignSystem
    configFiles:
      Debug: Config/App.xcconfig
      Release: Config/App.xcconfig
    info:
      # Generated, git-ignored, and reviewed here as YAML rather than as XML in a
      # second file — the same arrangement the app target uses.
      path: Support/ZenTomatoActivity-Info.plist
      properties:
        CFBundleDisplayName: ZenTomato
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        # This is the whole of what makes the bundle a widget extension. The
        # identifier is Apple's, not ours, and it must be exact.
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    settings:
      base:
        # A child of the app's identifier. iOS requires an extension's bundle id
        # to be prefixed by its container app's, and the existing wildcard
        # provisioning profile (KH6NBQRZBY.*) covers it, so no new profile is
        # needed for `make device`.
        PRODUCT_BUNDLE_IDENTIFIER: com.martingleason.ZenTomato.Activity
        # Kept in step with the app deliberately: two bundles installed together
        # with different versions is a support question nobody wants.
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        TARGETED_DEVICE_FAMILY: "1"
        # An extension is installed by its container app, never on its own.
        SKIP_INSTALL: "YES"
```

The scheme needs no change: building `ZenTomato` builds its dependency.

### 4.3 Why two targets share a source directory, and why that is the right answer here

The extension needs two things the app also needs: the metadata type that crosses the process boundary,
and the design tokens, because a Live Activity drawn in system blue with `Font.system` would break the
one rule F1 spent a whole feature establishing.

There are three ways to share Swift between two targets, and the other two are wrong here:

- **A Swift package.** The scope fence forbids a new dependency, a `Package.swift` is a new build
  system inside the build system, and it buys nothing at this size.
- **Copying the files.** Two copies of a `Codable` type that must encode identically on both sides of a
  process boundary is the most reliable way to ship a blank Lock Screen. The whole point of the
  metadata type is that both processes agree on it.
- **Listing the directory in both targets.** Each target compiles its own copy of the source into its
  own module. Costs a second compile of about a dozen small files. Buys: one source of truth, no
  package manifest, no cross-module `public` annotations, and a diff a non-Swift reader can follow.

Take the third. The constraint it imposes, and it is the one to police in review: **nothing that
touches SwiftData, AlarmKit's `AlarmManager`, or the engine may be placed in `ZenTomato/Shared/` or
`ZenTomato/DesignSystem/`.** An extension that imports SwiftData is an extension that will one day try
to open the store. `ZenTomato/Shared/` holds exactly the two files listed in §3.3 and nothing else
without an architect's note in the PR.

### 4.4 `.swiftlint.yml`

```yaml
included:
  - ZenTomato
  - ZenTomatoActivity
  - ZenTomatoTests
```

and the custom rule's path filter widens to cover every place a screen can now be written:

```yaml
  palette_outside_token_layer:
    included: "(ZenTomato/(App|Views|Models|Timer|Alarm|Shared)|ZenTomatoActivity)/.*\\.swift"
```

The Live Activity is a screen. If the rule does not reach it, the rule does not exist.

---

## 5. The exact surfaces both engineers build against

Copy these signatures literally. Engineer A commits them **first**, before implementing anything —
see §8. Engineer B compiles against them from that commit on.

### 5.1 `TimerEngine`

```swift
@MainActor
@Observable
final class TimerEngine {

  init(context: ModelContext, clock: any TimerClock, alarms: any AlarmScheduling)

  // --- Read surface. The screens read only these. ---

  /// The block that is running, or — when idle — the one `start()` would begin.
  private(set) var kind: BlockKind
  private(set) var isRunning: Bool
  private(set) var completedInSprint: Int
  /// From the running block's snapshot while running, from the saved settings while idle.
  private(set) var pomodorosPerSprint: Int
  /// `nil` when idle.
  private(set) var endsAt: Date?
  private(set) var authorization: AlarmAuthorization
  /// Non-nil when the last command could not do what it said. Shown on the timer screen.
  private(set) var lastFailure: TimerEngineFailure?

  /// How long is left at a given instant, clamped at zero. Pure: takes the instant
  /// rather than reading a clock, so a `TimelineView` can drive it from its own date
  /// and a test can ask about any moment without moving anything.
  func remaining(at instant: Date) -> Duration

  // --- Commands. Each persists before it awaits. ---

  /// Requests alarm authorization if it has not been asked for, then begins the next block.
  /// Does nothing but set `authorization` if permission is refused.
  func start() async

  /// Ends the current block early and moves to the next one. See decision D-a.
  func skip() async

  /// Abandons the sprint: records the running block, cancels the alarm, resets the
  /// count, returns to idle. See decision D-c.
  func stop() async

  // --- Reconciliation. ---

  /// Brings the engine back into agreement with the wall clock. Call at launch and on
  /// every transition to `.active`. Idempotent, and safe to call when idle.
  func synchronize() async

  /// The Live Activity's dismiss button arrived. The engine decides completed versus
  /// abandoned by comparing the current instant to `endsAt`. See decision D-i.
  func handleDismiss() async
}
```

### 5.2 `AlarmScheduling` — the seam

```swift
/// Everything F2 needs from an alerting system, and nothing about which one.
///
/// This protocol is `F2.md`'s stated mitigation for its largest risk: AlarmKit is
/// young, and if it disappoints, replacing `AlarmKitScheduler` is a one-file change
/// rather than a rewrite. Nothing in this file may name an AlarmKit type.
@MainActor
protocol AlarmScheduling: AnyObject {
  var authorization: AlarmAuthorization { get }
  func requestAuthorization() async -> AlarmAuthorization
  /// Cancels anything outstanding, then schedules this one. Cancel-before-schedule
  /// is part of the contract, not an implementation detail: a stale alarm firing four
  /// minutes after a skip is this feature's most likely user-visible bug.
  func schedule(_ request: BlockAlarmRequest) async throws
  func cancelOutstanding() throws
}
```

### 5.3 `TimerCycle`

```swift
enum TimerCycle {

  struct Transition: Equatable, Sendable {
    let kind: BlockKind
    let completedInSprint: Int
    /// True only when a long break just ended. The engine returns to idle on this
    /// even with auto-start on — four pomodoros and a long break is a stopping point.
    let endsSprint: Bool
  }

  /// - Parameter completed: false when the block was skipped or dismissed early.
  static func next(
    after kind: BlockKind,
    completedInSprint: Int,
    completed: Bool,
    settings: TimerSettingsSnapshot)
    -> Transition
}
```

The rules, exhaustively — an engineer implementing anything else is implementing a different feature:

| From | `completed` | Next kind | New `completedInSprint` | `endsSprint` |
|---|---|---|---|---|
| `.work` | `true`, and `completedInSprint + 1 >= perSprint` | `.longBreak` | `completedInSprint + 1` | `false` |
| `.work` | `true`, otherwise | `.shortBreak` | `completedInSprint + 1` | `false` |
| `.work` | `false` | `.shortBreak` | unchanged | `false` |
| `.shortBreak` | either | `.work` | unchanged | `false` |
| `.longBreak` | either | `.work` | `0` | `true` |

With defaults (perSprint 4): work, short, work, short, work, short, work, **long** — then idle.
With perSprint 1: work → long break → idle. A short break never occurs, which is correct and has a test.

### 5.4 `TimerClock`

```swift
protocol TimerClock: Sendable {
  /// Wall-clock time. Moves when the user, a timezone, or NTP moves it.
  var now: Date { get }
  /// Monotonic time since boot. Immune to every one of those.
  var continuousNow: ContinuousClock.Instant { get }
  /// Suspends until the deadline on the monotonic clock. Injected so the boundary
  /// task can exist without any test being allowed to sleep.
  func sleep(until deadline: ContinuousClock.Instant) async throws
}
```

---

## 6. Clock skew — the part that must not be simplified away

The engine holds, in memory only, `private var continuousDeadline: ContinuousClock.Instant?` alongside
the persisted `endsAt`. `synchronize()` compares them:

```
wallRemaining       = endsAt.timeIntervalSince(clock.now)
continuousRemaining = seconds from clock.continuousNow to continuousDeadline
```

If `abs(wallRemaining - continuousRemaining) > TimerEngine.clockSkewTolerance` (**5 seconds**, a named
constant with a comment), the wall clock moved. The continuous clock wins: rewrite
`endsAt = clock.now + continuousRemaining`, persist it, and reschedule the alarm — the alarm was
scheduled as a *duration*, so it may or may not have moved with the system clock and re-issuing it is
the only way to be sure.

**`ContinuousClock.Instant` cannot be persisted.** It is meaningless across a reboot and undefined
across a process launch. Do not try to store it, encode it, or reconstruct it from a stored `Date` —
reconstructing it from `endsAt` would make the guard compare a value against itself and always agree,
which is a guard that has been quietly deleted while still looking present. After a cold launch
`continuousDeadline` is `nil` and the wall clock is the only truth available; that is a real and
accepted limitation and the comment must say so.

This is the one place F2's code is more complicated than it looks like it needs to be. It gets a comment
explaining *why*, so that a future reader simplifies it back into a bug over the architect's dead body.

---

## 7. Concurrency posture — Swift 6, `SWIFT_STRICT_CONCURRENCY = complete`

| Thing | Isolation | Why |
|---|---|---|
| `TimerEngine` | `@MainActor` | It owns a `ModelContext`, which is **not `Sendable`**. Every SwiftData access in this app is main-actor bound, and the doc comment on the engine must say that in one sentence — this is a stated requirement of the brief. |
| `TimerState`, `PomodoroSession` | `@Model`, touched only from `@MainActor` code | Same reason. Their `current(in:)` accessors are `@MainActor` exactly as `AppSettings.current(in:)` is, and for the same check-then-insert race. |
| `AlarmScheduling`, `AlarmKitScheduler`, `TimerEngineHolder` | `@MainActor` | They are called only by the engine and by an App Intent that already runs on the main actor. Keeping the whole alarm path on one actor removes every ordering question between cancel and schedule. |
| `TimerClock`, `SystemTimerClock`, `TestClock` | `nonisolated`, `Sendable` | A clock has no state worth protecting. `SystemTimerClock` is an empty struct; `TestClock` is a `final class` with its mutable state behind a lock or an actor of its own — a `@MainActor` test clock would be simpler and is acceptable, since every test that uses it is `@MainActor` anyway. Prefer the `@MainActor` version. |
| `BlockKind`, `BlockAlarmRequest`, `TimerSettingsSnapshot`, `AlarmAuthorization`, `TimerEngineFailure`, `FocusAlarmMetadata`, `TimerCycle.Transition` | `Sendable` value types | They cross between the engine, the scheduler and (for the metadata) a process boundary. |
| `DismissBlockIntent.perform()` | `@MainActor` | It touches the engine. Its `title` is `static let` — `static var` is a hard compile error under `complete`, verified. |
| The widget extension | No shared mutable state at all | SwiftUI views reading `context.state` and `context.attributes`. No `Task`, no timer, no storage. If the extension needs to *do* something, the design has drifted. |

**Unstructured `Task`s — the complete list allowed in F2.** There are exactly two shapes:

1. `TimerEngine.boundaryTask`, one at a time, stored, cancelled and replaced on every transition and
   before every new one is created. It only ever calls `clock.sleep(until:)` and then `synchronize()`.
2. `Task { await engine.start() }` and its siblings inside SwiftUI `Button` actions, because a
   `Button` action is synchronous and this is the idiomatic bridge. Permitted **because of decision
   D-l**: the engine has already persisted its state before it awaits, so a cancelled button task can
   lose an alarm — which reconciliation repairs — and can never lose a block. Each such site carries a
   one-line comment saying so.

Anything else — a detached task, a `Task` in a view body, a `Task` nobody holds that mutates state — is
a review finding. `ZenTomatoApp` calls `synchronize()` through a `.task` modifier and an
`.onChange(of: scenePhase)`, not through a bare `Task` at the scene level.

---

## 8. The A/B seam

Two engineers, one tree, one branch, in parallel. The lists in the structured response are **strictly
disjoint**: a file in both lists corrupts the build. Nobody edits a file they do not own — not to fix a
typo, not to add an import.

**Where the seam falls, and why there.** The natural instinct is "engine versus UI", which splits
badly: the engine plus its tests is dense but self-contained, while AlarmKit plus the Live Activity plus
two screens is broader but shallower. Putting the *protocol* on A's side of the line and the
*implementation* on B's is what makes the halves independent — A's six test files never link AlarmKit,
and B never needs to understand the cycle rules to draw a countdown. It also means the risk that
`F2.md` names as largest (AlarmKit disappointing) is contained entirely within one engineer's files.

**A owns the vocabulary. B owns the surfaces that speak it.**

**The first commit is a coordination protocol, not a task.** Engineer A's first commit contains the
type declarations and method signatures from §5 with empty or `fatalError`-free stub bodies — return a
fixed value, do nothing — and nothing else. It is pushed before A writes any logic. Engineer B does not
start until it lands, and from then on B compiles against it and never edits it. Suggested message:

```
feat(F2-T1): the seam — BlockKind, the cycle, the clock, the alarm protocol
```

Everything A implements afterwards fills those bodies in without changing a signature. **If a signature
in §5 turns out to be wrong, A does not change it unilaterally: A says so, both engineers agree, and it
changes in one commit that names the reason.** A silently changed signature is the one thing here that
can cost an afternoon.

**Files neither engineer may touch:** `docs/specs/SPEC.md`, `docs/plans/00-deltas.md`,
`ZenTomato/Models/AppSettings.swift`, everything under `Config/` and `scripts/`,
`.github/workflows/ci.yml`, `.githooks/`, `Makefile`, and every file in `ZenTomato/DesignSystem/`.
If F2 appears to need a new colour role or a new spacing token, that is an architect's call — raise it,
do not add it.

---

## 9. Verification, and what counts as evidence

`CLAUDE.md`: assertions are not evidence. The PR carries the command and its output.

```
make checks      # lint --strict, Todoist allowlist, gitleaks, script tests
make test        # all 14 named tests plus the metadata and bounds tests
```

Plus, and this is easy to forget with a new target in the file:

```
make clean && make generate && make build
```

A widget extension that only builds incrementally is a widget extension that breaks CI, because **CI
regenerates the project from `project.yml` on every run**. Prove it from clean before opening the PR.

**Device check is gated on nothing now — C4 is closed** (`make device` succeeded on 2026-08-22). So the
device evidence `F2.md` asks for is obtainable and must be in the PR: a one-minute work block started,
app backgrounded, phone locked, **a Focus turned on**, and the alarm firing on time through it; the
same again with the app force-quit; and a Lock Screen screenshot of the Live Activity plus the Dynamic
Island counting down. The one-minute setting exists precisely so this takes eight minutes instead of two
hours — that is D10's second argument for putting the settings screen in this feature.

---

## 10. Scope fence

The greppable list is in the structured response and the reviewers search for it. Two clarifications
that a literal grep cannot express:

- **"No task plumbing"** means `FocusAlarmMetadata` has three fields and no fourth that is `nil` today.
  A field named `taskTitle` that is always `nil` is F3 starting early, and it is worse than absent
  because it looks finished.
- **"No pause"** means the *absence* of the control is deliberate and documented. `AlarmPresentation`
  is constructed with `countdown: .init(title:, pauseButton: nil)` and `paused:` omitted entirely, and
  the file says in prose that AlarmKit's own guidance suggests a pause control and we are declining it.
  Without that sentence the next reader will "fix" the omission.

---

## 11. Risks, and what to do about each

1. **AlarmKit's rescheduling and cancellation behaviour is the least-documented part of iOS 26.**
   Mitigation is the `AlarmScheduling` protocol: if it disappoints, one file is replaced. The engine
   and all six of A's test files are unaffected because none of them links AlarmKit. If it *does*
   disappoint, that is a spec question (D3 assumed it works), not a quiet fallback to notifications —
   `UNUserNotificationCenter` is on the scope fence for exactly that reason.

2. **The extension's bundle id and signing.** `com.martingleason.ZenTomato.Activity` is covered by the
   existing `KH6NBQRZBY.*` wildcard profile, so `make device` should need no change. If it does,
   `scripts/install-device.sh` is outside both engineers' ownership — raise it.

3. **A Live Activity that never appears, with no error anywhere.** The three ways this happens are all
   configuration: the missing `dependencies:` entry (extension never embedded), the missing
   `NSSupportsLiveActivities` key, and a mismatched `AlarmAttributes<Metadata>` generic between the two
   processes. All three are silent. Check them first, before debugging any Swift.

4. **`FocusAlarmMetadata` drifting between the two compiled copies.** Impossible while the file is
   shared, which is why §4.3 rejects copying. `AlarmMetadataTests` is the tripwire if someone "tidies"
   the sharing away later.

5. **Someone persisting `ContinuousClock.Instant`.** See §6. It looks like a small omission and it
   deletes the skew guard while leaving it visible.

6. **`Support/Secrets.xcconfig` is still on disk** — an orphan from the pre-D6b design that the F1b
   review believed deleted. It is git-ignored at any depth and every value in it is empty (checked by
   printing key names and value *lengths* only), so nothing leaks; it is noted here so the next person
   to find it knows it is dead, is not part of F2, and is not either engineer's to delete.
