# F4 — Build contract (Apple Music)

**Architect's document. Two engineers implement this literally.**
Branch `F4/apple-music`. Governing delta: **D19**. Feature plan: `docs/plans/F4.md`.
Nothing here may be widened without a `Proposed spec delta:` in the PR summary.

---

## 0. What MusicKit actually is on this machine

Read from the SDK, not from memory. Source of every name below:

```
/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/
  iPhoneOS.sdk/System/Library/Frameworks/MusicKit.framework/Modules/
  MusicKit.swiftmodule/arm64e-apple-ios.swiftinterface     (3807 lines)
```

Module flags on line 3 of that file: `-target arm64e-apple-ios26.5 … -swift-version 5`.
**MusicKit is a Swift 5 module.** It declares no global-actor isolation anywhere — `grep -n
"MainActor" ` over the whole interface returns exactly one hit, `nonisolated public static var
allCases` on an unrelated enum. This governs §4.

| What F4 needs | Real declaration | Line |
|---|---|---|
| Authorization status | `public struct MusicAuthorization` → `static var currentStatus: MusicAuthorization.Status` | 46–48 |
| Ask for authorization | `static func request() async -> MusicAuthorization.Status` | 50 |
| The four answers | `enum Status: String, Sendable { case notDetermined, denied, restricted, authorized }` | 55–59 |
| Subscription | `public struct MusicSubscription: Equatable, Hashable, Sendable` | 3649 |
| Read it | `static var current: MusicSubscription { get async throws }` | 3653 |
| Its three facts | `let canPlayCatalogContent: Bool`, `let canBecomeSubscriber: Bool`, `let hasCloudLibraryEnabled: Bool` | 3650–3652 |
| Watch it change | `static var subscriptionUpdates: MusicSubscription.Updates` (an `AsyncSequence` of `MusicSubscription`) | 3612–3628 |
| Subscription errors | `enum MusicSubscription.Error: String, LocalizedError { case unknown, permissionDenied, privacyAcknowledgementRequired }` | 3666–3672 |
| Library query | `public struct MusicLibraryRequest<MusicItemType> where MusicItemType: MusicLibraryRequestable` | 158 |
| Run it | `func response() async throws -> MusicLibraryResponse<MusicItemType>` | 172 |
| Its result | `MusicLibraryResponse.items: MusicItemCollection<MusicItemType>` (`Sendable`, line 551) | 200 |
| Filtering | `mutating func filter(matching:equalTo:)`, `filter(matching:contains:)`, `filter(text:)`, `sort(by:ascending:)` | 166–171 |
| Playlist is queryable | `extension Playlist: MusicLibraryRequestable { typealias LibraryFilter = LibraryPlaylistFilter }` | 1574 |
| …filterable on | `protocol LibraryPlaylistFilter { var id: MusicItemID; var name: String }` | 1578 |
| …sortable on | `protocol LibraryPlaylistSortProperties { lastPlayedDate, libraryAddedDate, name }` | 1583 |
| Song is queryable | `extension Song: MusicLibraryRequestable { typealias LibraryFilter = LibrarySongFilter }` | 2087 |
| …filterable on | `protocol LibrarySongFilter { id, albums, artists, genres, albumTitle, artistName, composerName, title }` | 2092 |
| Playlist identity/title | `Playlist.id: MusicItemID` (`let`), `Playlist.name: String` | 1450, 1474 |
| Song identity/title | `Song.id: MusicItemID` (`let`), `Song.title: String`, `Song.artistName: String` | 1900, 1907 |
| The identifier type | `@frozen struct MusicItemID: Equatable, Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral` (`rawValue: String`) | 571 |
| Both are `Sendable` | `struct Playlist: MusicItem, …, Sendable` / `struct Song: MusicItem, …, Sendable` | 1449, 1899 |
| Both are playable | `extension Playlist: PlayableMusicItem`, `extension Song: PlayableMusicItem` | 1547, 2059 |
| The player | `public class ApplicationMusicPlayer: MusicPlayer` — `static let shared` | 3170–3171 |
| Its queue **type** | `var queue: ApplicationMusicPlayer.Queue` (get **and set**); `class ApplicationMusicPlayer.Queue: MusicPlayer.Queue` | 3172, 3191 |
| Building a queue | `init(for:startingAt:)` over any `Sequence` of `PlayableMusicItem`; `init(arrayLiteral: any PlayableMusicItem...)`; `init(playlist:startingAt:)` | 3192–3198 |
| Loop | `player.state.repeatMode` — **`MusicPlayer.RepeatMode?` (optional)** on `MusicPlayer.State`, cases `.none`, `.one`, `.all` | 3470–3473, 3505 |
| Skip | `func skipToNextEntry() async throws` on `MusicPlayer` | 3278 |
| Transport actually offered by the SDK | `play() async throws`, `pause()`, `stop()`, `prepareToPlay()`, `playbackTime` (**settable**), `beginSeekingForward()`, `beginSeekingBackward()`, `endSeeking()`, `restartCurrentEntry()`, **`skipToPreviousEntry() async throws`** | 3268–3281 |
| Playback status | `enum MusicPlayer.PlaybackStatus: Sendable { stopped, playing, paused, interrupted, seekingForward, seekingBackward }` | 3452–3458 |
| The one we must not use | `public class SystemMusicPlayer: MusicPlayer` — `static let shared` | 3249–3250 |

### Where the SDK differs from `docs/plans/F4.md` — **the SDK wins**

1. **`MusicSubscription.current` is `get async throws`, not a plain property.** F4.md says "Check
   `MusicSubscription.current`" as though it were free. It suspends and it can throw
   (`MusicSubscription.Error`). Availability is therefore an `async` read with three outcomes, not a
   boolean, and a *throw* must degrade to "music unavailable", never to a broken timer.
2. **There is no `isSubscribed`.** The nearest true fact is `canPlayCatalogContent`. That is the flag
   F4 gates on, and the honest wording of the dimmed line follows from it, not from the word
   "subscription".
3. **`repeatMode` is not on the queue and not on the player — it is `player.state.repeatMode`, and
   it is an `Optional`.** F4.md's "queue from the chosen playlist with `repeatMode = .all`" is one
   level off. Correct: `ApplicationMusicPlayer.shared.state.repeatMode = .all`.
4. **The engine does not "publish block transitions for the Live Activity".** F4.md and the brief
   both say F4 subscribes to an existing transition signal. `grep -rn "ActivityKit"` returns
   `ZenTomato/Alarm/AlarmKitScheduler.swift` and `ZenTomatoActivity/BlockLiveActivity.swift`: the
   Live Activity is **AlarmKit's**, driven by the scheduled alarm, and the app never posts an
   activity update itself. The engine's actual publication mechanism is `@Observable` on
   `TimerEngine` (`ZenTomato/Timer/TimerEngine.swift:59-83`: `@MainActor @Observable final class
   TimerEngine` with `private(set) var kind: BlockKind` and `private(set) var isRunning: Bool`).
   **That is the signal F4 subscribes to, and no second notion of "the block changed" is
   invented.** §3 says exactly how.
5. **`MusicPlayer` exposes seek, previous-track and a settable `playbackTime`.** F4.md treats
   "skip-forward only" as a UI decision. It cannot be: the concrete type hands an engineer
   `skipToPreviousEntry()` and `playbackTime = 0` on the same object. §2 makes those unreachable by
   type rather than by review.
6. **`ApplicationMusicPlayer` is `@available(watchOS, unavailable)`** — irrelevant to v0.1 and worth
   knowing before anyone proposes F7.

---

## 1. File layout

### New — `ZenTomato/Music/` (new directory)

| File | What it is |
|---|---|
| `MusicSelection.swift` | The chosen playlist or song as a plain `Sendable` value: kind, identifier string, title snapshot. **Names no MusicKit type.** |
| `MusicPlaying.swift` | §2. The playback protocol. The skip-only fence. |
| `MusicPlaybackError.swift` | `enum MusicPlaybackError: Error { case selectionMissing, playbackFailed }`. `selectionMissing` is what drives "that playlist is gone, pick another". |
| `MusicAvailability.swift` | `enum MusicAvailability: Equatable, Sendable` — the answer to "may we play at all", plus the one plain line of copy for each unavailable case. |
| `MusicAvailabilityChecking.swift` | Protocol: ask for authorization, read availability, watch it change. |
| `MusicPreferenceStoring.swift` | Protocol the coordinator persists through. Owned by A; implemented by B. |
| `MusicPlaybackPhase.swift` | `struct MusicPlaybackPhase` — the one pure function that decides sound/silence. §3. |
| `MusicCoordinator.swift` | The logic. `@MainActor @Observable`. Owns enabled + selection + availability, receives block changes, drives `MusicPlaying`. |
| `BlockPhaseObserver.swift` | The adapter that turns `TimerEngine`'s `@Observable` changes into `MusicCoordinator` calls. §3, §4. |
| `AudioSessionInterruptions.swift` | `AVAudioSession` category setup and the interruption stream. §3. |
| `AppleMusicPlayer.swift` | **The only file that touches `ApplicationMusicPlayer`.** Conforms to `MusicPlaying`. |
| `AppleMusicAvailability.swift` | The only file that touches `MusicAuthorization` / `MusicSubscription`. |
| `MusicPreference.swift` | `@Model`, exactly four columns. F4's own store row — **not** `AppSettings`. |
| `MusicPreferenceStore.swift` | Single-row accessor + save, in the shape of `TimerState.current(in:)`. |
| `MusicLibraryReading.swift` | Protocol for the library read. Read-only by construction. |
| `AppleMusicLibrary.swift` | The only file that touches `MusicLibraryRequest`. |

### New — `ZenTomato/Views/`

| File | What it is |
|---|---|
| `MusicRowModel.swift` | Pure value: what the music row draws, in every state. No SwiftUI. |
| `MusicRow.swift` | The fixed-height row: label, one status line, and the skip slot. |
| `MusicPickerScreenModel.swift` | Pure value: the picker's rows. **Exactly two row kinds, no catch-all** — the `NoCaptureSurfaceTests` idiom. |
| `MusicPickerView.swift` | The library picker sheet. |

### Changed

| File | Change, and nothing else |
|---|---|
| `ZenTomato/Views/TimerScreen.swift` | One `musicRow` slot in `column`, above `capturePair`. |
| `ZenTomato/Views/TimerScreenModel.swift` | One new stored property `let music: MusicRowModel`, **no default value**, plus the previews it forces. |
| `ZenTomato/Views/TimerView.swift` | Wiring: build the row model, present the picker, forward toggle/skip. |
| `ZenTomato/App/AppModelContainer.swift` | One line: `MusicPreference.self` in the schema array, and one sentence in the prose list above it. |
| `ZenTomato/App/ZenTomatoApp.swift` | Build the music stack beside the Todoist stack; hand it down; start the observer. |
| `project.yml` | §5. Two Info.plist keys. |

### New tests — `ZenTomatoTests/`

`Support/SpyMusicPlayer.swift`, `Support/StubMusicAvailability.swift`, `Support/StubMusicLibrary.swift`,
`Support/StubMusicPreferenceStore.swift`,
`MusicTransitionTests.swift`, `MusicInterruptionTests.swift`, `MusicAvailabilityTests.swift`,
`MusicSelectionTests.swift`, `MusicRowModelTests.swift`, `MusicPickerScreenModelTests.swift`,
`MusicFenceTests.swift`.

### Explicitly unchanged (zero diff lines; the reviewer will run this)

`ZenTomato/Models/AppSettings.swift` · `ZenTomato/Distraction/` · `ZenTomato/Todoist/` ·
`ZenTomato/Plan/` · `ZenTomato/Timer/` · `ZenTomato/Alarm/` · `ZenTomato/DesignSystem/` ·
`ZenTomatoActivity/` · `scripts/` · `.githooks/` · `.github/` · `Config/` · `Makefile` ·
`.swiftlint.yml` · `docs/specs/` · `docs/plans/00-deltas.md`.

**`ZenTomato/Timer/TimerEngine.swift` is on that list.** F4 subscribes to the engine; it does not
add a hook to it. If an engineer believes a hook is required, that is a `Proposed spec delta:` and a
stop, not a commit.

---

## 2. The playback protocol

`ZenTomato/Music/MusicPlaying.swift`. This is the whole of what the rest of the app may ask of a
music player. It is written as a fence, and the fence is the *type* — not a comment, not a review.

```swift
@MainActor
protocol MusicPlaying: AnyObject {
  /// What is queued right now, or `nil` if nothing is.
  var loaded: MusicSelection? { get }

  /// Whether sound is actually coming out right now.
  var isPlaying: Bool { get }

  /// Queue this selection, set it to loop for ever, and start it from the top.
  /// The only thing in this app that can start a track from its beginning.
  func load(_ selection: MusicSelection) async throws

  /// Continue from wherever the queue already stands. Does nothing if nothing
  /// is loaded. **Takes no position argument — that is deliberate.**
  func resume() async throws

  /// Silence, keeping the position.
  func pause()

  /// Silence, and let go of the queue.
  func stop()

  /// Move to the next track. The only transport control this app has.
  func skipForward() async throws
}
```

Seven members. Each earns its place:

* `loaded` answers "is this already queued", which is what makes resume-not-restart decidable
  without asking the player where it is.
* `isPlaying` is what the skip button's presence is derived from (D19.3).
* `load` / `resume` are two separate verbs on purpose. **`resume()` takes no argument, so
  "resume from the beginning" is not a sentence this protocol can say.** Mid-track resume is not a
  behaviour to be remembered; it is the only behaviour available.
* `pause` keeps the position, `stop` releases the queue. The difference is the whole of D19.1's
  "at sprint end it stops and leaves the system player alone".
* `skipForward` is the single transport control.

### What cannot be expressed, and why that is the point

The concrete `MusicPlayer` offers `skipToPreviousEntry()`, `beginSeekingForward()`,
`beginSeekingBackward()`, `endSeeking()`, `restartCurrentEntry()`, a settable `playbackTime`, a
settable `shuffleMode` and a settable `repeatMode`. **None of them appears above.** There is no
`previous`, no `seek`, no `position`, no `volume`, no `shuffle`, no `repeat` toggle and no way to
read or write the queue. Looping is not a mode anyone can turn off: it is a fixed property of
`load`, set inside `AppleMusicPlayer` and named nowhere else.

An engineer who wants a scrubber cannot add one without editing this file, and that edit is a diff
the owner reads. That is the mechanism.

### Supporting values

```swift
struct MusicSelection: Equatable, Hashable, Sendable, Codable {
  enum Kind: String, Equatable, Hashable, Sendable, Codable { case playlist, song }
  let kind: Kind
  /// `MusicItemID.rawValue`. A plain string, so this type names no MusicKit type
  /// and the spy needs no framework.
  let identifier: String
  /// The title as it read when it was chosen. Snapshotted for the same reason
  /// F3 snapshots task titles: a playlist can be renamed or deleted.
  let title: String
}

enum MusicAvailability: Equatable, Sendable {
  case ready
  case notAsked                     // authorization never requested
  case denied                       // MusicAuthorization.Status.denied
  case restricted                   // .restricted
  case noSubscription               // canPlayCatalogContent == false
  case couldNotBeChecked            // MusicSubscription.current threw

  /// The one plain line the dimmed row shows. `nil` for `.ready` and `.notAsked`.
  var explanation: String? { … }
}
```

`MusicAvailability` carries its own copy so the row cannot invent wording and so
`MusicAvailabilityTests` can assert the exact sentence. Keep every line to one sentence, no
exclamation, no "Oops", and **no link, button or call to action** — a "Subscribe" button would be a
new surface, and the spec's whole posture here is that music is an accessory.

### The library read is also a fence

```swift
@MainActor
protocol MusicLibraryReading: AnyObject {
  /// Every playlist in the user's own library.
  func playlists() async throws -> [MusicSelection]
  /// Every song in the user's own library.
  func songs() async throws -> [MusicSelection]
  /// Whether this selection is still in the library, and its current title.
  func resolve(_ selection: MusicSelection) async throws -> MusicSelection?
}
```

Three reads and no writes. There is no `add`, no `create`, no `rename`, no `reorder`. `Playlist`
conforms to `MusicLibraryAddable` and `MusicPlaylistAddable` in the SDK (interface lines 1556,
1563); neither name may appear anywhere in this repo. `resolve` returning `nil` is the stale
identifier, and it is the only route to that state.

`AppleMusicLibrary` implements these with `MusicLibraryRequest<Playlist>` and
`MusicLibraryRequest<Song>` and **never `MusicCatalogSearchRequest` or any `MusicCatalog…` type**.
Library only — `SPEC.md:25`, "from their library".

---

## 3. Transition handling

### The one rule everything is derived from

```swift
struct MusicPlaybackPhase {
  /// Sound is permitted **only** here. Everywhere else is silence.
  static func shouldSound(
    isRunning: Bool,
    kind: BlockKind,
    isEnabled: Bool,
    availability: MusicAvailability,
    selection: MusicSelection?) -> Bool {
    isRunning && kind == .work && isEnabled && availability == .ready && selection != nil
  }
}
```

A free function over five finished values, testable with no timer, no player and no database — the
`TimerScreenModel.Capture.forBlock` idiom this codebase already uses.

**The coordinator has exactly one method that can produce sound**, `apply()`, and every event routes
through it. A block change, an interruption ending, a subscription lapsing, a toggle, a selection
being chosen — all five call `apply()`. There is no second path, which is what makes "resuming into
a break is impossible" a structural fact rather than a checked condition.

```
apply():
  want = MusicPlaybackPhase.shouldSound(…)
  if want:
      if player.loaded == selection  → await player.resume()
      else                            → await player.load(selection)
  else:
      if sprintIsOver or !isEnabled or availability != .ready → player.stop()
      else                                                    → player.pause()
```

`pause` vs `stop` on the silent branch is the only judgement in the whole method, and it is stated
once here.

### Every transition, explicitly

| Transition | `shouldSound` | What playback does | Why |
|---|---|---|---|
| idle → work (Start) | true | `loaded == selection ? resume() : load()` | After a sprint end the queue was released, so this is a `load()` and the playlist starts at the top. **This is D19.1 takeover**: `ApplicationMusicPlayer.play()` takes the audio session from whatever else was playing. |
| work → short break | false | `pause()` | Position kept. |
| short break → work | true | `resume()` | `loaded` still equals `selection`, so `load()` is not reached and the track cannot restart. This is the `resumePreservesPosition` guarantee, and it is a consequence of the branch above rather than a separate rule. |
| work → long break | false | `pause()` | Same as the short break. There is no different behaviour for the two breaks anywhere in F4. |
| long break → idle (sprint ends) | false | `stop()` | D19.1: "at sprint end it stops and leaves the system player alone". `stop()` releases the queue, so `loaded` becomes `nil` and the next Start is a clean `load()`. |
| any block → idle (user taps Stop) | false | `stop()` | Same as a sprint end. An abandoned sprint is over. |
| idle → idle (auto-start off, block ended) | false | `pause()` then, once the engine reports the sprint finished, `stop()` | With auto-start off the engine goes idle at every boundary (`TimerEngine.goIdle`). Between blocks we hold the position with `pause()`; only a finished sprint or a Stop releases the queue. |
| work → work | true | nothing changes | Unreachable — `TimerCycle` always inserts a break. Handled by `apply()` being idempotent, not by a special case. |
| idle → break, break → break | false | `pause()` | Also unreachable. `apply()` produces silence for them because the rule says so. |

The test drives the whole sequence `idle→work→short→work→short→work→short→work→long→idle` through
the spy and asserts the call log, plus the invariant that **`load` is called exactly once per
sprint**. A second `load` in a sprint is a restarted track and is the bug this table exists to
prevent.

### The awkward ones

**An audio-session interruption (a phone call) that ends during a break.**
`AVAudioSession.interruptionNotification`. On `.began`, note nothing and do nothing — iOS has
already silenced us. On `.ended`, **do not read `AVAudioSessionInterruptionOptions.shouldResume` as
an instruction.** Treat it as a *permission*: if `.shouldResume` is absent, stay silent; if present,
call `apply()` and let the rule decide. A call that ends nine minutes into a fifteen-minute break
finds `kind == .longBreak`, `shouldSound == false`, and the player stays paused. The guarantee is
that the interruption handler contains no `resume()` call of its own — it can only ask `apply()`,
and `apply()` cannot be argued with. Test: `interruptionDuringBreakDoesNotResume`.

**A settings change mid-sprint.** `AppSettings` has no music field and gains none (§6), so timer
settings cannot reach playback at all. The two music settings that exist — the toggle and the
selection — are **idle-only in two independent places**, the same belt-and-braces the capture
buttons use:

1. `MusicCoordinator.setEnabled(_:)` and `setSelection(_:)` both open with
   `guard !isRunning else { return }`. A future caller cannot get past it.
2. `MusicRowModel` reports the toggle as non-interactive and the row draws it `.disabled(true)`,
   so it cannot be reached by a tap, by VoiceOver, or by Full Keyboard Access.

Test `toggleLockedDuringSprint` asserts (1) — the model-level refusal — because that is the one that
holds for any future caller.

**A subscription lapsing mid-sprint.** `MusicSubscription.subscriptionUpdates` is an `AsyncSequence`.
`AppleMusicAvailability` iterates it and reports a new `MusicAvailability` to the coordinator, which
calls `apply()`. `availability != .ready` ⇒ `stop()`. **The timer does not observe this and is not
told about it.** The row's explanation appears at the next idle. This is D19.2 in its sharpest form:
the most a lapsed subscription can do to this app is make it quiet.

**The app being backgrounded.** `UIBackgroundModes: audio` plus an `AVAudioSession` configured
`.playback` keeps the process alive **while sound is playing**. It does not keep it alive while
paused. So, stated honestly rather than discovered in review:

* Music playing through a locked screen for a whole focus block: expected to work, and that is
  what the device check measures.
* A break: we pause, the app has no audio, and iOS may suspend it. `TimerEngine`'s boundary task
  does not fire while suspended (F2 review, finding 1–2). The end-of-break AlarmKit alarm wakes the
  app, and `apply()` runs then. **Whether music resumes at the boundary instant or a moment after
  the alarm is exactly what the device check must narrate.** No claim is made here.
* The app being killed: the queue dies with the process. On relaunch the coordinator finds
  `loaded == nil` and issues `load()`, which restarts the track. **Mid-track position does not
  survive an app kill**, and F4 does not persist it — persisting it would need `playbackTime`, which
  §2 deliberately makes unreachable. Documented, accepted, and stated in the PR.

**The honesty item the reviewer will ask about.** We cannot suppress the system's own transport
controls. Control Centre, the Lock Screen, AirPods and CarPlay all offer play/pause/back for whatever
is playing, because that is iOS's contract with the user and no app can opt out. What F4 controls is
its own UI. **This sentence goes in three places**: the doc comment at the top of `MusicPlaying.swift`,
the doc comment on `MusicRow.swift`, and the PR description. If a system control is used, the app's
own state and the player's can disagree until the next `apply()`; `apply()` reconciles them at the
next block change, and `isPlaying` is read live so the skip button follows reality rather than our
memory of it.

### The row, and D19.3

**The music row is present in every state of the timer screen, including idle, including when music
is unavailable.** It never appears and never disappears, so it can never move the countdown. Its
height is fixed by construction, with no new design token and no literal number:

* the label and the toggle are always drawn;
* the status line is always exactly one `Text`, with `.lineLimit(2, reservesSpace: true)`, so a
  one-line state and a two-line state occupy the same height;
* the skip slot always contains a skip button, `.hidden()` + `.allowsHitTesting(false)` +
  `.accessibilityHidden(true)` when music is not playing — the exact idiom `capturePair` already
  uses in `TimerScreen.swift:258-265`, for the exact reason stated there.

Skip is therefore **absent, not greyed** — genuinely unreachable by eye, by rotor, by Voice Control
and by keyboard — while the space it occupies never changes. F3 suppressed an affordance to protect
the movement rule and made a feature unreachable; D19 answers that with "reserve the space", and
this is that answer implemented.

`MusicRowModel` is a plain value with a `skip: Skip?` field whose `nil` means "reserve, do not draw",
mirroring `TimerScreenModel.Capture`'s `nil`. Its states, all covered by `MusicRowModelTests`:

| Timer | Availability | Enabled | Row |
|---|---|---|---|
| idle | `.notAsked` | off | toggle live, no status line content, no skip |
| idle | `.ready` | off | toggle live, "Off", no skip |
| idle | `.ready` | on, nothing chosen | toggle live, "Choose a playlist or song ›", no skip |
| idle | `.ready` | on, chosen | toggle live, the title, no skip |
| idle | `.ready` | on, chosen but gone | toggle live, "*Title* · not in your library any more", no skip |
| idle | `.denied` / `.restricted` / `.noSubscription` / `.couldNotBeChecked` | forced off | toggle dimmed, the one plain line, no skip |
| work running | `.ready` | on | toggle dimmed, the title, **skip drawn** |
| break running | `.ready` | on | toggle dimmed, the title, skip reserved |
| any running | anything | off | toggle dimmed, "Off", skip reserved |

---

## 4. Concurrency posture

Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY = complete`.

**Everything in `ZenTomato/Music/` is `@MainActor`.** No exceptions, and it is not caution for its
own sake — it is the same argument `AlarmScheduling` makes in its own doc comment: it removes every
question about whether a pause issued at a boundary and a resume issued by an interruption can
arrive out of order. It also matches `ModelContext`, which is not `Sendable` and which
`MusicPreferenceStore` holds.

**MusicKit's isolation, stated from the SDK.** MusicKit is `-swift-version 5` and annotates nothing
with a global actor. `ApplicationMusicPlayer.shared` is a `static let` of a non-`Sendable` class, so
under complete checking the compiler may diagnose the access. The prescription, in order:

1. `@preconcurrency import MusicKit` in `AppleMusicPlayer.swift`, `AppleMusicAvailability.swift` and
   `AppleMusicLibrary.swift`. Those three files are the only ones in the repo that import MusicKit.
2. Touch `ApplicationMusicPlayer.shared` only from inside `AppleMusicPlayer`, which is `@MainActor
   final class`, through one private computed accessor. **`ApplicationMusicPlayer` is chosen over
   `SystemMusicPlayer`, and the comment saying why lives on that accessor**: the application player
   is scoped to this app, whereas the system player is the user's Music.app queue, so starting a
   pomodoro would wipe out whatever they had queued elsewhere.
3. If a diagnostic survives, the answer is a narrower `@MainActor` wrapper — **never
   `nonisolated(unsafe)`, never `@unchecked Sendable`, never a suppression at a call site.**

`Playlist`, `Song`, `MusicItemID`, `MusicItemCollection` and `MusicSubscription` are all `Sendable`
in the interface, so nothing needs to cross an isolation boundary except plain values anyway.

**How the transition subscription reaches playback without a race.** `TimerEngine` is `@MainActor
@Observable`. `BlockPhaseObserver` is a `@MainActor final class` that runs a re-arming
`withObservationTracking` loop over `engine.kind` and `engine.isRunning` and calls
`coordinator.blockChanged(to:isRunning:)`. Both ends are already on the main actor, so the hand-off
is a plain call with no hop and no possible interleaving *at the point of observation*.

The interleaving that *can* happen is inside `apply()`, because `load`, `resume` and `skipForward`
are `async`. Two rules, both non-negotiable, both learned from F2's first blocking finding:

* `MusicCoordinator` holds one `private var inFlight: Task<Void, Never>?` and one
  `private var generation: Int`. Every `apply()` bumps the generation, cancels `inFlight`, and
  starts a new `Task { @MainActor in … }`.
* **The awaiting task re-checks its generation after every `await` and returns without touching the
  player if it has been superseded.** An older `resume()` that completes late therefore cannot leave
  sound running into a break. Cancellation alone is not enough — `ApplicationMusicPlayer.play()` may
  already have started by the time the cancel lands, which is precisely how F2's alarm bug worked.

No detached tasks. No `Task {}` anywhere without an owner that cancels it in `deinit`. The
subscription-updates loop and the interruption loop are both `Task`s stored on their owning object
and cancelled there.

`AVAudioSession` is configured once — category `.playback`, mode `.default`, activated lazily on the
first `load()` and never deactivated by us — from the main actor inside `AudioSessionInterruptions`.
Interruptions are consumed as `for await notification in NotificationCenter.default.notifications(
named: AVAudioSession.interruptionNotification)` inside a `@MainActor` task, not through a callback
block that would need `MainActor.assumeIsolated`.

---

## 5. `project.yml` changes

Two keys, both under `targets.ZenTomato.info.properties`, in the style of the keys already there —
each with a comment saying what breaks silently without it. Nothing else in the file changes: no new
target, no new dependency, no entitlements file, no build setting. C2 already put the MusicKit
capability on the App ID, so no capability entry is needed here.

```yaml
        # F2's scope fence forbade both of the keys below and F4 is where they
        # legitimately arrive — see docs/plans/00-deltas.md, D19.
        #
        # Without this, iOS suspends the app seconds after the screen locks and
        # the music simply stops. It presents as "music works until I put the
        # phone down", with no crash and nothing in the log. It is the key the
        # spec's "verify background audio at build time" clause points at, and
        # the verification is the device check, not this line.
        UIBackgroundModes:
          - audio
        # The sentence iOS shows the first time somebody switches music on.
        # MusicKit refuses the authorization request outright when it is
        # missing, which presents as "music permission is always denied".
        NSAppleMusicUsageDescription: >-
          ZenTomato plays a playlist or song from your Apple Music library during
          focus blocks and pauses it during breaks. It only reads your library
          and never changes anything in it.
```

The usage string is written to be true of what F4 does and of nothing more. It says *reads*, it says
*never changes*, and it names the pause-on-break behaviour — a person reading the prompt learns the
feature, which is the standard `NSAlarmKitUsageDescription` already sets in this file.

---

## 6. Scope fence

Greppable and concrete. These are the commands the reviewers will run; every one of them must come
back the way it says.

**Files with zero changed lines** — `git diff main --stat -- <path>` empty for each:

```
ZenTomato/Models/AppSettings.swift
ZenTomato/Timer/            ZenTomato/Alarm/         ZenTomato/Todoist/
ZenTomato/Plan/             ZenTomato/Distraction/   ZenTomato/DesignSystem/
ZenTomatoActivity/          scripts/                 .githooks/
.github/                    Config/                  Makefile
.swiftlint.yml              docs/specs/              docs/plans/00-deltas.md
```

**Skip-only fence** — zero hits anywhere in the repo:

```
grep -rn "skipToPreviousEntry\|beginSeekingBackward\|beginSeekingForward\|endSeeking" ZenTomato/
grep -rn "restartCurrentEntry\|playbackTime\|shuffleMode\|ShuffleMode" ZenTomato/
grep -rn "SystemMusicPlayer" ZenTomato/
grep -rni "scrub\|seek\|previous\|volume\|repeatToggle" ZenTomato/Music ZenTomato/Views/Music*
```

`repeatMode` has **exactly one hit**, inside `AppleMusicPlayer.swift`, where loop is set once:

```
grep -rn "repeatMode" ZenTomato/ | wc -l   →  1
```

**No-playlist-creation fence** — zero hits anywhere in the repo:

```
grep -rn "MusicLibraryAddable\|MusicPlaylistAddable" ZenTomato/
grep -rn "MusicLibrary.shared\|addToLibrary\|\.add(" ZenTomato/Music
grep -rni "createPlaylist\|newPlaylist\|focus playlist\|make a playlist" ZenTomato/
```

**Library, never the catalogue** — zero hits:

```
grep -rn "MusicCatalog" ZenTomato/
```

**No capture surface** — zero hits in every F4 view:

```
grep -rn "TextField\|SecureField\|searchable\|TextEditor" ZenTomato/Views/Music*
```

`MusicPickerScreenModel.Row` has exactly two cases and `MusicPickerScreenModelTests` switches over
it with **no `default`**, so a third kind stops the test bundle compiling — the
`NoCaptureSurfaceTests` mechanism, applied to this picker.

**MusicKit is confined to three files:**

```
grep -rln "import MusicKit" ZenTomato/   →  exactly
  ZenTomato/Music/AppleMusicPlayer.swift
  ZenTomato/Music/AppleMusicAvailability.swift
  ZenTomato/Music/AppleMusicLibrary.swift
```

**The six-field rule:**

```
grep -rn "musicEnabled\|musicSelection\|playlistID" ZenTomato/Models/   →  zero
```
plus `AppSettingsTests` continues to assert six columns, unchanged, and a new
`MusicFenceTests.musicPreferenceHasFourStoredProperties` asserts
`Schema([MusicPreference.self])` has exactly `["isEnabled", "selectionKind", "selectionID",
"selectionTitle"]` — the `SessionPlanFenceTests` mechanism.

**Phase-2 words** — zero hits under `ZenTomato/Music` and `ZenTomato/Views/Music*`:

```
grep -rni "watch\|CloudKit\|export\|chart\|streak\|badge\|theme\|stats\|widget" …
```

**Design-system rules already enforced by `.swiftlint.yml`** (do not weaken, do not add an
exemption): no `Palette.` in a view, no colour literal, no hex. Additionally, zero hits for
`grep -rn "\.frame(height:" ZenTomato/Views/Music*` — the reserved height comes from
`reservesSpace:` and the hidden-button idiom, not from a number.

**Swift hygiene** — zero hits under `ZenTomato/Music/` and `ZenTomato/Views/Music*`:

```
grep -rn "try!\|as!\|fatalError\|nonisolated(unsafe)\|@unchecked Sendable" 
```
and no bare `try?` that discards a real error: every catch either sets `MusicAvailability` or
surfaces `MusicPlaybackError`.

**Evidence the PR must carry**, per CLAUDE.md's "assertions are not evidence": the full output of
`make test` and `make lint`, and the device check narrated block by block — what played, what paused,
where it resumed — plus a screen recording of one break transition. A `xcodebuild` summary line
alone is a finding.

---

## 7. The A/B seam

Two engineers, strictly disjoint file sets, no shared file. The seam is the set of signatures in §2
and §3 — both engineers code against those from minute one, so neither waits for the other.

### Engineer A — the mechanism. No SwiftUI, no SwiftData.

**Owns and creates**

```
ZenTomato/Music/MusicSelection.swift
ZenTomato/Music/MusicPlaying.swift
ZenTomato/Music/MusicPlaybackError.swift
ZenTomato/Music/MusicAvailability.swift
ZenTomato/Music/MusicAvailabilityChecking.swift
ZenTomato/Music/MusicPreferenceStoring.swift
ZenTomato/Music/MusicPlaybackPhase.swift
ZenTomato/Music/MusicCoordinator.swift
ZenTomato/Music/BlockPhaseObserver.swift
ZenTomato/Music/AudioSessionInterruptions.swift
ZenTomato/Music/AppleMusicPlayer.swift
ZenTomato/Music/AppleMusicAvailability.swift
ZenTomatoTests/Support/SpyMusicPlayer.swift
ZenTomatoTests/Support/StubMusicAvailability.swift
ZenTomatoTests/Support/StubMusicPreferenceStore.swift
ZenTomatoTests/MusicTransitionTests.swift
ZenTomatoTests/MusicInterruptionTests.swift
ZenTomatoTests/MusicAvailabilityTests.swift
project.yml
```

**Delivers** — `pausesOnBreakResumesOnWork`, `resumePreservesPosition` (asserts `load` called exactly
once across a whole sprint), `sprintEndPauses` (and stays stopped), `toggleOffStopsPlayback`,
`toggleLockedDuringSprint`, `interruptionDuringBreakDoesNotResume`,
`noSubscriptionDisablesMusicOnly` and `deniedAuthDisablesMusicOnly` (both assert a full
idle→work→break→work sequence completes with the spy never asked to play).

**A owns the honest split**: `SpyMusicPlayer` records a call log and nothing more. The doc comment at
the top of `MusicPlaying.swift` states, in the PR's own words, that playback itself is not
unit-testable — there is no simulator for "sound came out of the phone" — that the logic is proved
against the spy, and that the device check is what covers the reality. It also carries the
system-transport-controls paragraph from §3.

### Engineer B — the store, the library read, and the screen.

**Owns and creates**

```
ZenTomato/Music/MusicPreference.swift
ZenTomato/Music/MusicPreferenceStore.swift
ZenTomato/Music/MusicLibraryReading.swift
ZenTomato/Music/AppleMusicLibrary.swift
ZenTomato/Views/MusicRowModel.swift
ZenTomato/Views/MusicRow.swift
ZenTomato/Views/MusicPickerScreenModel.swift
ZenTomato/Views/MusicPickerView.swift
ZenTomatoTests/Support/StubMusicLibrary.swift
ZenTomatoTests/MusicRowModelTests.swift
ZenTomatoTests/MusicPickerScreenModelTests.swift
ZenTomatoTests/MusicSelectionTests.swift
ZenTomatoTests/MusicFenceTests.swift
```

**Owns and changes**

```
ZenTomato/Views/TimerScreen.swift
ZenTomato/Views/TimerScreenModel.swift
ZenTomato/Views/TimerView.swift
ZenTomato/App/AppModelContainer.swift
ZenTomato/App/ZenTomatoApp.swift
```

**Delivers** — `skipIsTheOnlyControl` (the row exposes exactly one transport action, asserted over
every state of `MusicRowModel`), `missingPlaylistPromptsReselect` (`resolve` returns `nil` ⇒ the
explanatory state, no crash), the reserved-height assertions, the two-row-kinds fence, the
four-column schema fence, and the greps in §6 as a test where a grep can be written as one.

### The seam, precisely

* A defines `MusicSelection`, `MusicAvailability`, `MusicPlaying`, `MusicPreferenceStoring` and the
  public surface of `MusicCoordinator`. B consumes all five and implements
  `MusicPreferenceStoring` (in `MusicPreferenceStore`) and `MusicLibraryReading`.
* `MusicCoordinator`'s public surface, fixed here so neither engineer waits:

```swift
@MainActor @Observable final class MusicCoordinator {
  init(player: any MusicPlaying,
       availability: any MusicAvailabilityChecking,
       library: any MusicLibraryReading,
       preferences: any MusicPreferenceStoring)

  private(set) var isEnabled: Bool
  private(set) var selection: MusicSelection?
  private(set) var availability: MusicAvailability
  var isPlaying: Bool { get }          // read live from the player

  func blockChanged(to kind: BlockKind, isRunning: Bool)
  func setEnabled(_ isEnabled: Bool) async   // idle only; asks for authorization on first `true`
  func setSelection(_ selection: MusicSelection?)  // idle only
  func skipForward()
  func start()   // begins the availability + interruption watches
}
```

* Only **B** touches any file that existed before F4. A's entire footprint is new files plus
  `project.yml`. That is deliberate: it keeps every merge conflict on one desk, and it means the
  scope-fence greps over pre-existing paths have exactly one author to answer for them.
* Neither engineer touches `ZenTomato/Timer/TimerEngine.swift`. If either believes they must, they
  stop and write `Proposed spec delta:`.

---

## 8. Risks, most likely first

1. **The full-sprint device check is the only thing that can validate this feature, and it is two
   hours.** Four pomodoros, three short breaks, a long break, screen locked, once with headphones and
   once without. Every test in §7 runs against a spy; the simulator has no music library and no
   Apple Music. If the device session cannot be scheduled, F4's gate cannot close however green CI is.
2. **Resume after a long pause in a suspended app.** The single most likely disappointment, named in
   F4.md and unchanged by anything in this contract. A fifteen-minute long break with the app
   suspended, then an alarm, then `apply()`. Nothing here claims it works; the device check measures
   it and the PR narrates the result.
3. **`repeatMode` is optional and lives on `state`, not on the queue.** The obvious wrong line
   (`queue.repeatMode = .all`) does not compile, but the *silently* wrong one — setting it before the
   queue is assigned, where MusicKit may drop it — does. Set it immediately after `player.queue = …`
   and before `play()`, and confirm the loop on the device with a two-track playlist rather than
   asserting it.
4. **Swift 6 vs a Swift 5 MusicKit.** `ApplicationMusicPlayer.shared` may not compile cleanly under
   complete checking. The fix is §4's ladder. The risk is an engineer reaching for
   `nonisolated(unsafe)` because it is one line and it works, which would put the player outside the
   main actor and quietly reintroduce the ordering race F2 spent a blocking finding on.
5. **Scope pressure once it plays.** A volume slider, a now-playing row with artwork, a shuffle
   toggle and a "smart" default playlist will all feel obvious and each is out of scope; the last is
   named in `SPEC.md`'s out-of-scope list by name. §2's protocol and §6's greps exist because prose
   did not hold in F3 or F5.
6. **The music row is a new element on the calmest screen in the app.** It must not become a second
   focal point. `textMuted` ink, no artwork, no colour: the one piece of colour on that screen is the
   word above the number and `TimerScreen.swift` already says so twice.
7. **The picker over a large library.** `MusicLibraryRequest` has `limit` and `offset` and defaults
   are not documented in the interface. A library of ten thousand songs loaded in one request is a
   visible stall on the first tap. Page it, and if paging turns out to need a search field, that
   field must offer nothing when it finds nothing — `NoCaptureSurfaceTests` already covers the idiom
   and the same test must cover this picker.
8. **The system transport controls make our state and the player's disagree.** Pausing from Control
   Centre mid-block leaves the app believing music is playing until the next `apply()`. `isPlaying`
   is read live from the player rather than cached, which keeps the skip button honest; anything
   beyond that is out of our hands and is documented rather than fought.
