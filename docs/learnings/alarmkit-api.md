# AlarmKit, as it actually exists

**Read from the SDK, not from documentation:**
`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/AlarmKit.framework/Modules/AlarmKit.swiftmodule/arm64e-apple-ios.swiftinterface`
— 335 lines, every symbol `@available(iOS 26.0, *)`, `@available(macCatalyst, unavailable)`.

Written down because AlarmKit is new enough that guessing at it is a real risk, and because the first
attempt to gather this cost a 46,000-character agent response that was truncated and thrown away.
Verify against the file above before trusting anything here.

## Authorization

```swift
AlarmManager.shared                                       // public static let, on a plain class
var authorizationState: AlarmManager.AuthorizationState   // SYNCHRONOUS getter — not async, not throwing
func requestAuthorization() async throws -> AuthorizationState
var authorizationUpdates: some AsyncSequence<AuthorizationState, Never>

enum AuthorizationState: Codable, Sendable { case notDetermined, denied, authorized }
```

## Scheduling a countdown

```swift
AlarmManager.AlarmConfiguration<Metadata>.timer(
  duration: TimeInterval,                       // ← A DURATION, NOT AN END DATE
  attributes: AlarmAttributes<Metadata>,
  stopIntent: (any LiveActivityIntent)? = nil,
  secondaryIntent: (any LiveActivityIntent)? = nil,
  sound: ActivityKit.AlertConfiguration.AlertSound = .default)

func schedule<Metadata>(id: Alarm.ID, configuration: AlarmConfiguration<Metadata>) async throws -> Alarm
```

**`timer(duration:)` takes a `TimeInterval`, not a `Date`.** This matters for our wall-clock design:
the engine's source of truth stays `endsAt: Date`, and scheduling converts with
`endsAt.timeIntervalSinceNow` *at the moment of scheduling*. It does not change the design — but the
conversion has to happen at exactly one place, and rescheduling after a settings change must
recompute it rather than reuse a stale interval.

`Alarm.Schedule.fixed(Date)` exists and is **not** the countdown path — that is the alarm-clock case
(a specific wall time, optionally recurring weekly). Do not reach for it because it takes a `Date`.

## Control — all synchronous and throwing, except `schedule`

```swift
func countdown(id: Alarm.ID) throws
func cancel(id: Alarm.ID) throws
func stop(id: Alarm.ID) throws
func pause(id: Alarm.ID) throws
func resume(id: Alarm.ID) throws

var alarms: [Alarm] { get throws }
var alarmUpdates: some AsyncSequence<[Alarm], Never>
```

`cancel(id:)` is what skip and stop must call before scheduling anything new. It is synchronous, so
there is no excuse for a race between cancelling and rescheduling.

## The Live Activity is an ActivityKit activity

```swift
struct AlarmAttributes<Metadata: AlarmMetadata>: ActivityAttributes, Sendable {
  var presentation: AlarmPresentation
  var metadata: Metadata?
  var tintColor: SwiftUICore.Color
}

protocol AlarmMetadata: Codable, Hashable, Sendable {}
```

So the widget extension declares an `ActivityConfiguration` for `AlarmAttributes<OurMetadata>`.
Whatever the Lock Screen needs to draw must travel in `metadata` — **the extension is a separate
process and cannot read the app's SwiftData.**

### Presentation

```swift
struct AlarmPresentation {
  var alert: AlarmPresentation.Alert          // required
  var countdown: AlarmPresentation.Countdown? // optional
  var paused: AlarmPresentation.Paused?       // optional
}

struct Alert {
  var title: LocalizedStringResource
  var stopButton: AlarmButton
  var secondaryButton: AlarmButton?
  var secondaryButtonBehavior: SecondaryButtonBehavior?   // .countdown | .custom
}

struct Countdown {
  var title: LocalizedStringResource
  var pauseButton: AlarmButton?               // ← OPTIONAL. This is how we get no-pause.
}

struct AlarmButton { var text: LocalizedStringResource; var textColor: Color; var systemImageName: String }
```

**`Countdown.pauseButton` being optional is what lets us honour the no-pause decision cleanly.** Pass
`nil` and no pause control is offered; omit `presentation.paused` entirely for the same reason. We are
not fighting the framework to leave pause out — it is a supported configuration.

### State the extension renders from

```swift
struct AlarmPresentationState {
  var alarmID: Alarm.ID
  var mode: Mode          // .alert | .countdown(Countdown) | .paused(Paused)
}

Mode.Countdown {
  var totalCountdownDuration: TimeInterval
  var previouslyElapsedDuration: TimeInterval
  var startDate: Date
  var fireDate: Date      // ← render the countdown from THIS
}
```

`fireDate` is why the Live Activity needs no pushed updates: SwiftUI's `Text(timerInterval:)` counts
down client-side from it. If we ever find ourselves pushing frequent activity updates, the design has
drifted off the wall-clock model.

## Other facts worth having

- `Alarm.State`: `.scheduled`, `.countdown`, `.paused`, `.alerting`.
- `Alarm.CountdownDuration(preAlert:postAlert:)` — the pre-alert is the countdown itself; post-alert is
  the snooze-ish interval after it fires.
- `AlarmManager.AlarmError.maximumLimitReached` — there IS a cap on scheduled alarms. One block at a
  time means we should never approach it, but a leak (scheduling without cancelling) would find it.
- `stopIntent` / `secondaryIntent` are `AppIntents.LiveActivityIntent`. A button in the Live Activity
  that does something in our app needs an App Intent, not a closure.
- `tintColor` is a plain `Color` on the attributes — a semantic role from the design system, not a literal.
