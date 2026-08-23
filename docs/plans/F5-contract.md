<title>F5 Build Contract</title>

# F5 — Build contract

**Architect's contract for `docs/plans/F5.md`. Two engineers, one tree, one branch (`F5/distraction-tally`).**

This document is normative. Where it disagrees with a reviewer's taste, this document wins; where it
disagrees with `docs/specs/SPEC.md` or `CLAUDE.md`, those win and this document is the defect.

Read `docs/plans/F5.md` first — it is the *what*. This is the *where, in which file, owned by whom*.
Read `docs/plans/F2-contract.md` §7–§10 second: F5 inherits its concurrency posture, its seam
protocol and its fence discipline unchanged, and this document only states the deltas.

---

## 0. The one sentence the whole feature is judged on

**The tap is the record.**

Tapping I or E writes a durable row before anything else happens. The sentence is an optional
annotation added later to a row that already exists. The adversarial reviewer asks directly whether a
record can be lost between the tap and the prompt, and the answer here is *no, structurally* — not
*no, probably*. §4 is where that is cashed out. Everything else in this document is downstream of it.

There is a second sentence that follows from the first and that every engineer keeps getting wrong in
their head, so it is written here:

**The haptic is the receipt, not the starting gun.** `F5.md` writes the sequence as
*tap → haptic → write*. That ordering is wrong and this contract inverts it. The engine's recording
method is synchronous and returns a `Bool`; the view fires the haptic **only when it returns `true`**.
So the buzz in your hand is proof that a row is committed to disk, rather than a promise that one is
about to be. This is strictly stronger than what the plan asked for and it costs nothing.

---

## 1. What was verified in the tree before writing this

Facts checked against the merged code, not assumed. Each one changes what you write.

1. **`PomodoroSession` does not exist while its block is running.** `TimerEngine.recordSession(...)`
   inserts it inside `end()` and `stop()` — that is, at the *end* of the block
   (`ZenTomato/Timer/TimerEngine.swift:415`). At the instant of a tap there is no session row to
   point at. This single fact decides the model in §3 and it is the most important line in this
   document.

2. **The running block's identity already exists and is already the join key.**
   `TimerState.sessionID: UUID` is minted in `begin()` and handed to `PomodoroSession.init(id:)`
   verbatim when the block ends. So `Distraction.sessionID == PomodoroSession.id` is true by
   construction with no new machinery, and F2's device evidence already exercises it.

3. **`TimerState` is `private var state` on the engine.** No view can see it and none may be given a
   way to. That is what makes "the view never reaches into the engine's internals" enforceable rather
   than aspirational.

4. **Every suspension point in the engine leaves `TimerState` self-consistent.** Walked by hand:
   `begin()` mutates and `persist()`s the whole row *before* its only `await`; `stop()` is `async`
   with no `await` in its body at all; `end()`'s only suspension is the one inside `begin()`;
   `start()` awaits authorization while `isRunning` is still false. §4.4 turns this into a rule the
   engineer must preserve.

5. **`project.yml` globs `- path: ZenTomato`.** A new file under `ZenTomato/Distraction/` is compiled
   with no project change. **`ZenTomato/Distraction/` is NOT in `ZenTomatoActivity`'s source list**,
   so nothing in this feature can leak into the widget process. Do not add it. Wrist capture is F7.

6. **`AppModelContainer.make(_:)` builds `Schema([AppSettings.self, TimerState.self,
   PomodoroSession.self])`.** A `@Model` type absent from that array is a runtime trap on first
   insert, in every test and in the app. See risk #1.

7. **`TimerEngineFailure` already has `.persistenceFailed`, and `TimerScreen` already draws it and
   announces it to VoiceOver.** F5 needs no new failure case and must add none. Zero changed lines in
   `TimerEngineFailure.swift`.

8. **`StopReasonSheet` carries `.interactiveDismissDisabled()`.** That stays. §6.4 explains why the
   *other* sheet must not have it.

---

## 2. Decisions this contract takes, so no engineer has to

Closed. Do not relitigate; do not "improve" them.

| # | Decision |
|---|---|
| **E-a** | **The engine is the only writer of `Distraction` rows.** Both the tap and the note go through `TimerEngine`. There is no `DistractionStore`, no `DistractionRepository`, no second `ModelContext`. Argued in full in §5. |
| **E-b** | **`Distraction` carries `sessionID: UUID` as a plain value, not a SwiftData `@Relationship`.** The session row does not exist at tap time (§1.1). Argued in §3.2. |
| **E-c** | **`recordDistraction(_:)` is synchronous, `@MainActor`, and contains no `await`.** Not a style preference — it is the atomicity guarantee. A tap therefore cannot interleave with a block transition. |
| **E-d** | **It returns `Bool`: `true` iff a row is committed.** The view fires the haptic and nothing else on `true`. On `false` nothing at all happens — no buzz, no badge, no toast. |
| **E-e** | **A tap is attributed to the block that owns the *instant of the tap*, or it is refused.** Never reassigned to a neighbouring block, never held for one. The guard is `isRunning && state.isRunning && state.kind == .work && clock.now < state.endsAt`. |
| **E-f** | **`currentBlockDistractions: [DistractionPrompt]` on the engine is a derived read-model, not a buffer.** It is rebuilt from the store in `init` and in `synchronize()`, and a test proves that by relaunching. Deleting it would change what the screen shows and nothing about what is stored. |
| **E-g** | **The reflection prompt is offered on exactly one path: `boundaryReached()`.** That is the only path in the engine that can establish the app was awake and on time when the block ended — it already carries F2's tested `clockSkewTolerance` lateness guard for precisely that question. `synchronize()` and `handleDismiss()` record the rows and stay silent. This is the ratified "the sheet is not re-presented later", implemented by reusing an existing tested condition rather than inventing a second one. |
| **E-h** | **`stop()` never publishes a reflection.** D14's merged sheet has already collected the sentences before `stop()` is called. Two modal sheets back to back is the defect D14 exists to prevent. |
| **E-i** | **Notes are written before the block is stopped, not after.** At the stop-confirm site: `engine.attachNotes(...)` then `Task { await engine.stop(reason:) }`. If the app dies between the two, the notes are saved and the block is still running — recoverable. The other order loses the notes. |
| **E-j** | **A note that is whitespace after trimming is `nil`, not `""`.** One tested pure function, `DistractionNote.normalised(_:)`, used by both sheets and by the engine. This is what makes "skipped" distinguishable from "deliberately empty", which is a named test. |
| **E-k** | **`taskTitle` and `projectTitle` exist as optional columns, always `nil` in F5.** A knowingly-taken exception to the F2 fence precedent. Argued and bounded in §3.3. **No `taskID`. No Todoist import. No fetch. Nothing reads them.** |
| **E-l** | **`tapsOnlyDuringWork` is enforced twice: once in `TimerScreenModel` (the buttons do not exist during a break) and once in the engine guard.** Deliberate belt-and-braces. The view guard is what a person sees; the engine guard is what makes it true for any future caller. A reviewer will ask why both — the answer is in this row and must also be in the code's prose. |
| **E-m** | **No new colour role, no new spacing token, no new type role.** If F5 appears to need one, that is an architect's call: raise it, do not add it. `ZenTomato/DesignSystem/` has **zero changed lines** in this diff. |
| **E-n** | **No `Task { }` anywhere in the tap path.** The button action is synchronous end to end. This is a strict improvement on the Start/Stop precedent and it is the entire point: there is no async gap in which a tap can be lost. |

---

## 3. The `Distraction` model

### 3.1 The shape

`ZenTomato/Distraction/Distraction.swift`

```swift
@Model
final class Distraction {
  var id: UUID
  var kind: DistractionKind
  var timestamp: Date
  var note: String?
  var sessionID: UUID
  var taskTitle: String?
  var projectTitle: String?

  init(
    id: UUID = UUID(),
    kind: DistractionKind,
    timestamp: Date,
    sessionID: UUID,
    note: String? = nil,
    taskTitle: String? = nil,
    projectTitle: String? = nil)
}
```

Field by field, with the reason each one is here:

| Field | Why |
|---|---|
| `id: UUID` | The row's own identity. It is what a sentence is later attached *to*: the sheet hands back a `[UUID: String]` and the engine matches on this. Without it, "the note belongs to the second tap" would have to be expressed as a position in a list, and a list can be reordered or refetched in a different order. `notesAttachToCorrectTap` is a named test and this field is what makes it cheap. |
| `kind: DistractionKind` | The spec's I and E. **Owner-written, in `DistractionTally.swift`. Do not redefine it, do not move it, do not add a case.** |
| `timestamp: Date` | The instant of the **tap**, taken from `clock.now` inside the engine — never the instant of the note, never `Date()` read in a view. The spec's *Done when* is "three records with the right task and timestamps", and a timestamp written when the sheet was filled in would answer a different question. Taken from the injected clock so a test can assert exact values without sleeping. |
| `note: String?` | The sentence, or `nil`. **`nil` means skipped and skipping is a first-class outcome.** It is an optional rather than an empty-string default precisely so that "said nothing" and "deliberately wrote nothing" stay different facts. F6 will render them differently. |
| `sessionID: UUID` | Which block this happened in. A copy of `TimerState.sessionID`, which is the same value `PomodoroSession.id` later carries. See §3.2 — this is the design decision the whole model turns on. |
| `taskTitle: String?` | F3's. Always `nil` in F5. See §3.3. |
| `projectTitle: String?` | F3's. Always `nil` in F5. See §3.3. |

Everything is a stored value; there are no computed properties, no relationships, and no methods on
this type. It is a row. `DistractionTally.summary(of:)` and `DistractionNote.normalised(_:)` are the
only logic in the feature and neither lives here.

### 3.2 Why `sessionID` is a value and not a relationship — the load-bearing argument

The obvious SwiftData shape is `var session: PomodoroSession?` with an inverse on `PomodoroSession`.
`F5.md`'s sketch even writes it that way. **It is wrong here, and the reason is a fact about F2's
engine rather than a preference about modelling.**

1. **The session row does not exist yet.** `PomodoroSession` is inserted when the block *ends*
   (§1.1). A relationship would therefore be `nil` at insert and would have to be back-filled when
   the block finished. That makes the durable row's link to its block depend on a *later* write
   succeeding — which is exactly the loss window this feature exists to close, reintroduced through
   a side door. A tap at 14:32 whose block is force-quit at 14:40 would leave an orphan pointing at
   nothing, on the one path where durability matters most.

2. **The join key already exists and is already correct.** `begin()` mints `state.sessionID` and
   `recordSession()` passes it straight into `PomodoroSession.init(id:)`. Copying that UUID at tap
   time produces a complete, final, self-sufficient row in one write. Nothing has to be revisited.

3. **A relationship would require editing `PomodoroSession.swift`**, whose own doc comment says
   "FIVE FIELDS AND NOT ONE MORE" and whose file is F2's, currently in review. This contract keeps
   **zero changed lines** there.

4. **Denormalisation is right for an append-only log.** `F5.md` already makes this argument for the
   title snapshots. The same argument covers the key: the row records what was true at 14:32 and
   nothing later may change it.

**The cost, stated plainly.** SQLite will not enforce that every `sessionID` has a matching session
row, so a bug elsewhere could produce an orphan and nothing would catch it. Two mitigations, and both
are honest rather than clever: every path out of a running block in F2 calls `recordSession()` — there
is no exit that skips it — and F6 must render an orphaned row as "no block" rather than crashing. That
second obligation is recorded here and in §11 so F6 does not discover it.

**How a `Distraction` finds its session without a view reaching into the engine.** It does not have
to. The view calls `engine.recordDistraction(.internalInterruption)`; the engine reads its own
`private var state`. The view's only new reads of the engine are two `Sendable` value types. **No
`ModelContext`, no `TimerState`, and no `Distraction` object ever crosses into `ZenTomato/Views/`.**
That is greppable: no file under `ZenTomato/Views/` may contain the identifier `Distraction` (the
model), `TimerState`, or `ModelContext`.

### 3.3 The title snapshots — a recorded exception, not an oversight

`F2-contract.md` §10 states the fence in words the reviewer will quote back: *"a field named
`taskTitle` that is always `nil` is F3 starting early, and it is worse than absent because it looks
finished."* `docs/plans/F5.md`'s own risk section says *"F3 must add the columns."*

**The F5 brief nevertheless ratifies them into this feature**, and the ratification wins. So they are
here, and this section exists so the reviewer finds the argument rather than the surprise.

The exception is bounded to exactly this, and every clause is greppable:

- **Two columns, not three.** `taskTitle: String?` and `projectTitle: String?`. **No `taskID`** — an
  identifier is plumbing, since only Todoist code could ever fill it or resolve it, and it is the one
  field on the list that would be useless without a client.
- **No `import` of anything Todoist-shaped**, no URL, no endpoint string, no `taskTitle` appearing
  anywhere outside `Distraction.swift`.
- **Nothing reads them.** Not the sheets, not the buttons, not the tally. `grep -rn "taskTitle"
  ZenTomato/` returns exactly one file.
- **A test asserts they are `nil`.** `titleSnapshotsAreNilForEverythingF5Captures` — so the day F3
  starts writing them, the test that breaks names the feature that broke it.
- **The doc comment says whose they are and that nothing may assume non-`nil`**, in F3 and forever
  after, because rows captured before F3 lands are real data the owner will have generated.

### 3.4 The one change outside the feature's own directories

`ZenTomato/App/AppModelContainer.swift`, one line:

```swift
let schema = Schema([AppSettings.self, TimerState.self, PomodoroSession.self, Distraction.self])
```

This is risk #1. Its doc comment already says "When a future feature adds a saved type, it is added
to this array and nowhere else" — F5 is that future feature. **Do this in the seam commit, first,
before anything else.**

---

## 4. Durability — how a tap becomes a durable row

This is the section the review will be won or lost in. It is written as: the method, then the four
failure scenarios the brief names, then what proves each one.

### 4.1 The method, exactly

```swift
@MainActor
extension TimerEngine {          // ZenTomato/Timer/TimerEngine.swift — NOT a separate file:
                                 // the stored properties in §4.2 must live beside it.
  @discardableResult
  func recordDistraction(_ kind: DistractionKind) -> Bool {
    // 1. Is there a work block that owns this instant?
    guard isRunning, let state, state.isRunning, state.kind == .work else { return false }
    let now = clock.now
    guard now < state.endsAt else { return false }

    // 2. Build the complete row. Nothing about it is filled in later.
    let row = Distraction(kind: kind, timestamp: now, sessionID: state.sessionID)

    // 3. Insert and COMMIT. Synchronously. This is the whole feature.
    context.insert(row)
    do {
      try context.save()
    } catch {
      // The row never became real, so it must not be left pending: a later
      // successful save would commit it silently, minutes after the person got
      // no buzz and saw no badge, and it would not be in any prompt list.
      context.delete(row)
      lastFailure = .persistenceFailed
      return false
    }

    // 4. Only now does the screen learn anything.
    currentBlockDistractions.append(DistractionPrompt(row))
    return true
  }
}
```

Four properties of this that must survive review:

- **No `await`.** Step 3 is the last thing that can fail and it has already happened before the
  method returns. There is no window.
- **No `try?`.** The failure is caught, surfaced on `lastFailure` (which `TimerScreen` already draws
  in amber and announces to VoiceOver), and reported to the caller.
- **`currentBlockDistractions` is touched *after* the commit, never before.** If the append came
  first, the badge would count a row that does not exist.
- **The return value is the haptic's precondition**, not decoration. `@discardableResult` is there
  only so tests may ignore it; the view may not.

### 4.2 What the engine gains, in full

Stored properties, in `TimerEngine.swift` (a Swift extension cannot hold stored properties, which is
why this feature edits that file rather than adding `TimerEngine+Distractions.swift`):

```swift
/// The taps recorded in the block that is running now, oldest first.
///
/// A DERIVED VIEW OF THE STORE, NOT A BUFFER. Every element here is already a
/// committed row. Deleting this property would change what the screen shows and
/// nothing whatsoever about what is stored. It is rebuilt from the database in
/// `init` and in `synchronize()`, which is what proves that claim.
private(set) var currentBlockDistractions: [DistractionPrompt] = []

/// Set once, at the end of a work block the app was awake to see end, when that
/// block had at least one tap. The screen consumes it and clears it.
private(set) var pendingReflection: BlockReflection?
```

Methods:

| Member | Contract |
|---|---|
| `func recordDistraction(_:) -> Bool` | §4.1. |
| `func attachNotes(_ notes: [UUID: String])` | Fetches the named rows, sets `note = DistractionNote.normalised(text)`, saves once. A `nil` normalisation **leaves the row's note `nil`** — it never writes `""`. Unknown ids are ignored, not an error. Synchronous, no `await`. On a save failure: `lastFailure = .persistenceFailed`. |
| `func consumePendingReflection() -> BlockReflection?` | Returns `pendingReflection` and sets it to `nil` in one call. Named *consume* because a value that can be read twice can be presented twice, and a second sheet appearing after the first is dismissed is the exact defect D14 forbids. |

Changes to existing engine methods:

| Method | Change |
|---|---|
| `init` | After `adopt(row)`, call `rehydrateDistractions()`. |
| `synchronize()` | On the *still running* branch (after `adopt(state); armBoundary()`), call `rehydrateDistractions()`. |
| `begin(...)` | `currentBlockDistractions = []` immediately after `state.sessionID = UUID()`. A new block starts with an empty badge. |
| `end(state:completed:at:mayAutoStart:mayPromptForReflection:)` | **Gains one parameter.** Capture `let prompts = currentBlockDistractions` and `let endedKind = state.kind` at the top. Assign `pendingReflection` as the **last statement on both exit paths** (§4.5). |
| `boundaryReached()` | Passes `mayPromptForReflection: true`. The only site that does. |
| `synchronize()`, `handleDismiss()` | Pass `mayPromptForReflection: false`. |
| `stop(reason:)` | `currentBlockDistractions = []` and `pendingReflection = nil` before `goIdle`. Per E-h. |

**Why `mayPromptForReflection` is a separate parameter when it is `true` on exactly the same path as
`mayAutoStart`.** Today the two conditions coincide, so reusing `mayAutoStart` would be correct and
would save a line. It would also be a trap: `mayAutoStart` means "the app is permitted to chain a
block", and the first future caller that passes it `true` for some other reason would silently start
presenting sheets. A parameter that says what it means costs one line.

`private func rehydrateDistractions()` fetches rows whose `sessionID` matches `state.sessionID`,
sorted by `timestamp`, and assigns the mapped array; when the timer is idle it assigns `[]`. On any
fetch failure it assigns `[]` and sets `lastFailure = .persistenceFailed` — the badge is cosmetic and
must never be a reason not to run a timer.

### 4.3 The four scenarios the brief names

**(a) The app is killed a moment after the tap.**
Guaranteed by step 3: `context.save()` has returned before `recordDistraction` returns, so the row is
committed to the SQLite file before the button's action completes and before the haptic fires. There
is no in-memory stage the process can die in.
*Test:* `killedBetweenTapAndPrompt` — `TestStore.temporaryFileStore()`, build an engine, start a work
block, tap twice, then **release the container entirely** and open a second one at the same URL. Two
rows, right kinds, right timestamps, `note == nil` on both. Releasing the container is the only
honest simulation of a kill available in-process, and the helper for it already exists.
*And:* `tapIsDurableBeforePrompt` — after the tap, read through a **second `ModelContext` on the same
container**. A fresh context sees committed data only, so a row appearing there is proof the save
happened rather than proof the object is in memory.

**(b) The sheet never appears.**
Nothing on the sheet path writes a row. `pendingReflection` is a presentation signal; `attachNotes`
only ever *modifies* rows that already exist. A block whose sheet is never presented, or is swiped
away, or is killed with, leaves exactly the rows the taps made, with `note == nil`.
*Test:* `noTapsNoSheet` (zero taps ⇒ `pendingReflection == nil`) and
`aBlockEndedWhileClosedRecordsRowsAndNoPrompt` (E-g: the `synchronize()` path leaves the rows and no
sheet).

**(c) The block ends in the same instant as the tap.** Two distinct sub-cases and E-e answers both.
- *The tap lands after `end()` has run.* `state.isRunning` is false, or `state.kind` is now a break
  and `state.sessionID` is a new UUID. The guard returns `false`. **A tap is never attributed to the
  wrong block.** The buttons are also already gone from the screen by then (E-l), so this path is
  reachable only by a queued gesture.
- *The tap lands before `end()` runs but after `state.endsAt` has passed* — the boundary task has not
  fired yet, or the app was suspended across the boundary. Without the second guard, this row would be
  written against a work block that is already over by the wall clock and would then be swept into
  that block's reflection: a distraction recorded during a break, presented as if it happened during
  work. `guard now < state.endsAt` is that guard. **It is not redundant with `state.isRunning` and
  deleting it is a defect, not a simplification.**
*Test:* `tapAfterTheBlocksEndInstantIsRefused` — advance the test clock past `endsAt` without running
the boundary, tap, assert `false` and zero rows.

**(d) A tap arrives while the engine is mid-transition.**
Answered structurally by E-c plus §1.4. `recordDistraction` contains no `await`, so on the main actor
it runs to completion as one indivisible step: it cannot be interleaved by `begin()`, `end()` or
`stop()`. The only question left is what `state` looks like at each of the engine's *existing*
suspension points, and the answer was walked by hand:

| Suspension point | What `state` says | What a tap gets |
|---|---|---|
| `start()` → `await alarms.requestAuthorization()` | `isRunning == false` | Refused. Correct — nothing has started. |
| `begin()` → `await scheduleAlarm(for:)` | Fully mutated and `persist()`ed to describe the **new** block | Attributed to the new block. Correct if it is work; refused if it is a break. |
| `end()` → `await begin(...)` | The ended block, `endsAt` in the past | Refused by the second guard. Correct. |
| `stop(reason:)` | No `await` in the body at all | Cannot be interleaved. |

**The rule this creates, and it is now part of the engine's contract:** *any new `await` added to
`TimerEngine` must be checked against the tap guard.* Put that sentence in `TimerEngine.swift`'s own
prose, next to the recording method, because it is the kind of invariant that is deleted by a
well-meaning refactor a year later.
*Test:* `tapDuringATransitionAttachesToTheBlockThatOwnsTheInstant` — using
`ZenTomatoTests/Support/ReentrantAlarmScheduler.swift`, a new stand-in whose `schedule(_:)` runs a
test-supplied closure at its suspension point. The closure taps; the assertion is that the row's
`sessionID` equals the engine's newly-current block, and that a tap during a *break's* `begin()` is
refused. This is the only way to exercise that window deterministically. **Do not modify
`SpyAlarmScheduler.swift`** — it is F2's, it is in review, and a new file costs less than a conflict.

### 4.4 What is *not* covered by a test, said out loud

The `catch` in step 3 — a refused `save()` — has no test. SwiftData offers no supported way to make
`save()` fail in-process, and a fake `ModelContext` is not a thing. Two honest mitigations instead of
a fake one:

- The branch is four lines and reads correctly at a glance: delete, record the failure, return
  `false`.
- The consequence is visible in the diff without running anything: the view fires the haptic on
  `true` only, so a failed save produces no buzz, no badge, and an amber line that VoiceOver
  announces. That is the behaviour a reader can check by reading.

Claiming coverage here would be worse than admitting its absence. `CLAUDE.md`: assertions are not
evidence.

### 4.5 The break starts behind the sheet (D4)

`end()` captures the ended block's prompts into a local at the top, performs the whole transition —
`recordSession`, `TimerCycle.next`, then either `goIdle(); persist()` or `await begin(...)` — and
assigns `pendingReflection` as its **last statement on both exit paths**. The transition never waits
for the sheet, because the sheet does not exist until the transition has finished.

*Test:* `breakStartsBehindSheet` — auto-start on, one tap in a work block, run the boundary. Assert in
one test, in this order: `engine.pendingReflection != nil`; `engine.kind == .shortBreak`;
`engine.isRunning == true`; and `engine.endsAt` equals *the work block's end instant* plus the
**ended block's frozen** `shortBreakMinutes × 60`. That last clause is the whole assertion: the
break's clock started at the block boundary, not at the moment anything was dismissed.
*And:* `reflectionSheetDoesNotDelayAnything` — call `consumePendingReflection()` an hour of test-clock
time later and assert `endsAt` is unchanged.
*And, for auto-start off:* `pendingReflection != nil` while the engine is idle, and consuming it
leaves the engine idle.

---

## 5. The architectural question: engine, or a separate store type?

Asked directly by the brief. Argued, then decided.

### The case for a separate `DistractionStore`

`TimerEngine.swift` is 549 lines and already carries a `// swiftlint:disable file_length` with a
paragraph justifying it. Distraction capture is not timing. A small `@MainActor final class
DistractionStore { let context: ModelContext }` would keep the engine's surface unchanged and would
be independently testable.

### Why that is rejected

1. **A second writer needs the same answer to "which block is running?" and cannot get it safely.**
   Its only route is `TimerState.current(in:)`. Handed the *same* context, it observes the engine's
   in-flight, uncommitted mutations mid-`begin()` — it would be reading a half-transitioned row it has
   no way to interpret. Handed a *different* context, it reads a stale snapshot and would attribute a
   tap to a block that ended seconds ago. **Both failure modes are silent and both produce exactly the
   defect this feature exists to prevent.** There is no third option.

2. **Only the engine can offer atomicity.** E-c's guarantee — a tap cannot interleave with a
   transition — holds because the recording method is a synchronous main-actor method on the object
   that owns the transitions. A separate type would be a separate main-actor hop with the engine's
   `await`s in between: the very window §4.3(d) closes would reopen.

3. **One `ModelContext`, guaranteed rather than coincidental.** A store type would take its context
   from `@Environment(\.modelContext)` in a view. That happens to be `container.mainContext` today —
   the same object the engine holds — but only because `ZenTomatoApp` passes `.modelContainer(...)`.
   Relying on that identity is relying on SwiftUI plumbing nobody has written down.

4. **`lastFailure` already exists.** A persistence failure in a separate type would be invisible, or
   would need a second failure channel and a second amber row.

5. **The addition is genuinely small**: two stored properties, three methods, five touched lines in
   existing methods. It does not justify a second object that owns half a question.

### Decided

**E-a: the engine owns it.** Its file grows by roughly one screen of code and two of prose. The
`file_length` exemption already covers that and its stated justification — "this file is the feature's
one dense piece of behaviour" — now covers one more.

**What is *not* in the engine.** Two pure things live outside it, and neither ever asks which block is
running, which is why they are not a second writer:

- `DistractionNote.normalised(_:)` — trimming and the nil-versus-empty rule.
- `DistractionTally.summary(of:)` — already written by the owner. **F5 must actually use it**, as the
  header line of both sheets. A hand-written function with no caller is a function nobody would
  notice going wrong.

---

## 6. File layout

Every file F5 adds or changes. **Nothing else may appear in the diff.**

### 6.1 New — the record (`ZenTomato/Distraction/`)

| File | Purpose |
|---|---|
| `Distraction.swift` | The `@Model` from §3.1. One type, seven stored properties, no methods. Its prose must argue §3.2 (why a UUID, not a relationship) and §3.3 (whose the title columns are). |
| `DistractionPrompt.swift` | `struct DistractionPrompt: Identifiable, Hashable, Sendable { let id: UUID; let kind: DistractionKind; let timestamp: Date }`, plus `init(_ row: Distraction)`. **The only shape a distraction takes when it crosses into a view.** Immutable, value-typed, carries no `note` — a prompt is a question, and the answer travels back separately as `[UUID: String]`. |
| `BlockReflection.swift` | `struct BlockReflection: Identifiable, Equatable, Sendable { let id: UUID /* the sessionID */; let kind: BlockKind; let prompts: [DistractionPrompt] }`. `Identifiable` so the sheet can be presented with `.sheet(item:)`, which makes double-presentation impossible rather than unlikely. Never constructed with an empty `prompts` array — E-h and `noTapsNoSheet` depend on `nil` meaning "nothing to ask about". |
| `DistractionNote.swift` | `enum DistractionNote { static func normalised(_ raw: String) -> String? }`. Trims whitespace and newlines; returns `nil` when nothing is left. Pure, `nonisolated`, no imports beyond `Foundation`. Its prose states E-j: whitespace is not a sentence, and a stored `""` would look like a reflection that happened. |
| `CaptureHaptic.swift` | `@MainActor enum CaptureHaptic { static func tapRecorded() }`, wrapping `UIImpactFeedbackGenerator(style: .medium)`. **The only `import UIKit` in the app target** — say so in its prose and keep it true. Called from exactly one place, on `true` only. |

### 6.2 Changed — the engine and the store

| File | Change |
|---|---|
| `ZenTomato/Timer/TimerEngine.swift` | §4.1 and §4.2. Two stored properties, three new methods, one private helper, one new parameter on `end(...)`, five touched lines in existing methods. Nothing else moves. |
| `ZenTomato/App/AppModelContainer.swift` | §3.4. One line. |

**Unchanged, and the review will check:** `ZenTomato/Models/AppSettings.swift` (six fields),
`ZenTomato/Models/PomodoroSession.swift` (five fields), `ZenTomato/Models/TimerState.swift`,
`ZenTomato/Distraction/DistractionTally.swift`, `ZenTomato/Timer/TimerEngineFailure.swift`,
everything under `ZenTomato/DesignSystem/`, `ZenTomato/Shared/`, `ZenTomatoActivity/`, `Config/`,
`scripts/`, `.githooks/`, `.github/workflows/`, `Makefile`, `project.yml`, `.swiftlint.yml`,
`docs/specs/SPEC.md`, `docs/plans/00-deltas.md`, `docs/plans/F5.md`.

### 6.3 New — screens (`ZenTomato/Views/`)

| File | Purpose |
|---|---|
| `DistractionButtons.swift` | The I and E pair, drawn from finished values with closures out — the same discipline as `TimerScreen`. Takes `internalCount: Int`, `externalCount: Int`, `onInternal: () -> Void`, `onExternal: () -> Void`. Previews for zero counts, mixed counts, dark, and **AX5**. |
| `ReflectionFieldList.swift` | One field per tap: kind, time, and a `TextField`. `prompts: [DistractionPrompt]`, `@Binding notes: [UUID: String]`. **Used by both sheets** — this file is what makes D14 one composition instead of two copies that drift. Header line is `DistractionTally.summary(of: prompts.map(\.kind))`. |
| `BlockReflectionSheet.swift` | The end-of-block sheet: block name, the tally line, `ReflectionFieldList`, one `Done` button. No Complete-task button (F3's). |

### 6.4 Changed — screens

| File | Change |
|---|---|
| `StopReasonSheet.swift` | Gains `prompts: [DistractionPrompt]` and `@Binding notes: [UUID: String]`, and renders `ReflectionFieldList` between the reason field and the buttons **only when `prompts` is non-empty** — D14's "a block stopped with no taps shows only the top half". `Stop the timer` stays gated on the reason alone (D13's requirement level is unchanged; F5's is unchanged). The body moves into a `ScrollView` with `.scrollDismissesKeyboard(.interactively)`: with the keyboard up and three fields, a plain `VStack` puts the confirm button off-screen. **`.interactiveDismissDisabled()` stays** — a dismissed stop sheet would leave the timer undecided. Its existing doc comment, which already explains why its sentence is required and F5's is not, gets one paragraph for why both live in one sheet. |
| `TimerScreenModel.swift` | Gains `struct Capture { let internalCount: Int; let externalCount: Int }` and `let capture: Capture?`. **`nil` unless a *work* block is running** — E-l's first guard, expressed as a type rather than a condition in a view. Update the stale `Controls.running` doc comment, which still says "Skip and Stop"; D13 removed Skip. |
| `TimerScreen.swift` | Draws `DistractionButtons` when `model.capture != nil`, in a new row between the sprint rule and `controls`. No other change. |
| `TimerView.swift` | Wires it: builds `capture`, calls `engine.recordDistraction(_:)` **synchronously** and fires `CaptureHaptic.tapRecorded()` on `true`; owns the note drafts for both sheets; presents `BlockReflectionSheet` via `.sheet(item:)` driven by an `.onChange(of: engine.pendingReflection)` that immediately calls `consumePendingReflection()`; passes the running block's prompts into `StopReasonSheet`; calls `engine.attachNotes(...)` **before** `engine.stop(reason:)` (E-i). |

### 6.5 New — tests (`ZenTomatoTests/`)

| File | Covers |
|---|---|
| `DistractionCaptureTests.swift` | `threeTapsThreeRecords` (the spec's *Done when*, verbatim: three taps ⇒ three rows, right kinds, right `sessionID`, timestamps strictly increasing), `tapsOnlyDuringWork` (short and long break both refused, zero rows), `tapAfterTheBlocksEndInstantIsRefused`, `tapWhileIdleIsRefused`, `badgeCountsMatchTheRows`, `titleSnapshotsAreNilForEverythingF5Captures`. |
| `DistractionDurabilityTests.swift` | `tapIsDurableBeforePrompt` (second context), `killedBetweenTapAndPrompt` (file store, reopen), `relaunchRebuildsTheBadgeFromTheStore` (proves E-f: the array is derived), `tapDuringATransitionAttachesToTheBlockThatOwnsTheInstant`. |
| `DistractionReflectionTests.swift` | `breakStartsBehindSheet`, `reflectionSheetDoesNotDelayAnything`, `noTapsNoSheet`, `aBlockEndedWhileClosedRecordsRowsAndNoPrompt` (E-g), `consumingIsOneShot`, `stoppingDoesNotAlsoPresentTheReflectionSheet` (E-h), `skippingLeavesNilNotNotEmpty`, `notesAttachToCorrectTap`, `notesSurviveTheBlockEnding`. |
| `DistractionNoteTests.swift` | The pure normaliser: empty, spaces, newlines, a real sentence, a sentence with surrounding whitespace, and the `""`-versus-`nil` distinction stated as its own case. |
| `Support/ReentrantAlarmScheduler.swift` | §4.3(d). A fresh `AlarmScheduling` stand-in with `var duringSchedule: (@MainActor () -> Void)?`. Does not touch `SpyAlarmScheduler.swift`. |
| `DistractionScreenModelTests.swift` (B) | `TimerScreenModel.capture` is `nil` while idle, `nil` during both breaks, and non-`nil` with the right counts during work. Pure, no store, no engine. |

**Untouched:** `ZenTomatoTests/DistractionTallyTests.swift` (F5-T0, owner-written) and every F2 test
file and support file.

---

## 7. Concurrency posture — Swift 6, `SWIFT_STRICT_CONCURRENCY = complete`

Inherits `F2-contract.md` §7. The deltas:

| Thing | Isolation | Why |
|---|---|---|
| `Distraction` | `@Model`, touched only from `@MainActor` code | It is a SwiftData object reached through a `ModelContext`, which is **not `Sendable`**. **It must never be made `Sendable`, never captured in a `Task`, never crossed into a view, and never stored in a `Sendable` value type.** `DistractionPrompt` exists so nothing is ever tempted to. |
| `DistractionKind` | already `Codable, Hashable, Sendable` | Owner-written. Do not touch the file. |
| `DistractionPrompt`, `BlockReflection` | `Sendable` immutable structs | They are the only things that cross from the engine into a view. Value semantics mean the screen cannot mutate what the store believes. |
| `TimerEngine.recordDistraction(_:)`, `.attachNotes(_:)`, `.consumePendingReflection()` | `@MainActor`, **synchronous, no `await` in the body** | E-c. This is the atomicity guarantee, not a style choice. A doc comment must say so, in those words, or the next person will make one of them `async` for symmetry and delete the guarantee while leaving the code looking identical. |
| `DistractionNote` | `nonisolated`, pure | No state, no imports beyond `Foundation`. |
| `CaptureHaptic` | `@MainActor` | `UIFeedbackGenerator` is main-actor-only. The single `import UIKit` in the app target. |
| `ZenTomato/Distraction/` and the widget | **no relationship at all** | The directory is not in `ZenTomatoActivity`'s sources and must not be added. An extension that can see the database is an extension that will one day try to open it. |

**Unstructured `Task`s added by F5: zero.**

The tap path is synchronous from the `Button` action to `context.save()` and back, so the F2
precedent — `Task { await engine.start() }` inside a button, permitted because the engine persists
before it awaits — **is not needed here and must not be copied**. A `Task` in the I/E button action
would reintroduce exactly the gap this feature exists to close, and it is the single most likely thing
an engineer does out of habit. The only `Task` in the diff is the existing
`Task { await engine.stop(reason:) }` at the stop-confirm site, unchanged.

Greppable: `ZenTomato/Views/DistractionButtons.swift` contains no `Task`, no `async`, and no `await`.

---

## 8. The A/B seam

Two engineers, one tree, one branch, in parallel. The lists in the structured response are **strictly
disjoint**: a file in both lists corrupts the build. Nobody edits a file they do not own — not to fix
a typo, not to add an import.

**Where the seam falls, and why there.** The instinct is "model versus UI", and here that is also the
correct answer, because the interesting risk is entirely on one side of it. Everything that can lose
data lives in A's files: the model, the guard, the commit, the rehydration, the transition hooks. B
cannot lose a row no matter what B writes, because B never touches a `ModelContext` — B's whole job is
to call a `Bool`-returning method and draw what comes back. That means the durability review is a
review of one engineer's work, and the accessibility and Dynamic Type review is a review of the
other's, with no overlap in either direction.

**A owns the record. B owns the surfaces that ask for it.**

**The first commit is a coordination protocol, not a task.** Engineer A's first commit contains, and
contains only:

- `Distraction.swift`, `DistractionPrompt.swift`, `BlockReflection.swift`, `DistractionNote.swift` —
  complete, since they are small value types with no logic worth staging;
- the one-line `Schema` change in `AppModelContainer.swift`;
- the three new engine methods and two stored properties, with **stub bodies that return a fixed
  value and do nothing** — no `fatalError`, no `TODO`;
- the new `mayPromptForReflection` parameter on `end(...)`, threaded through its three call sites.

It is pushed before A writes any logic. Engineer B does not start until it lands, and from then on B
compiles against it and never edits it. Suggested message:

```
feat(F5-T1): the seam — the Distraction row, the prompt, and the engine's surface
```

Everything A implements afterwards fills those bodies in without changing a signature. **If a
signature turns out to be wrong, A does not change it unilaterally: A says so, both engineers agree,
and it changes in one commit that names the reason.**

**Files neither engineer may touch:** everything in §6.2's *Unchanged* list.

---

## 9. Verification, and what counts as evidence

`CLAUDE.md`: assertions are not evidence. The PR carries the command and its output.

```
make ci          # lint --strict, Todoist allowlist, gitleaks, script tests, then the full suite
make clean && make generate && make build
```

Screenshots, four, from the simulator:

1. A running work block with the I and E buttons, one of them showing a count.
2. A running **short break** — proof the buttons are absent, not merely disabled.
3. The end-of-block sheet with three fields and the tally line.
4. The merged stop sheet with a reason field above and two tap fields below (D14), and the same
   screen at **AX5** to show the layout holds.

**The device check, and the cost `F5-T3` accepted.** F5 builds no reading-back UI, so its *Done when*
cannot be checked by looking at the app. It is checked by reading the store off the phone, exactly as
F2's cycle was on 2026-08-23:

```
xcrun devicectl device copy from --device <udid> \
  --domain-type appDataContainer --domain-identifier com.martingleason.ZenTomato \
  --source Library/Application\ Support --destination ./pull

sqlite3 ./pull/default.store \
  "SELECT datetime(ZTIMESTAMP + 978307200, 'unixepoch', 'localtime'),
          COALESCE(ZINTERNALINTERRUPTION, ZEXTERNALINTERRUPTION), ZNOTE
     FROM ZDISTRACTION ORDER BY ZTIMESTAMP;"

  -- NOT ZKIND. SwiftData stores a raw-value-less Codable enum as one VARCHAR per
  -- case, exactly one populated per row. Verified against a real store.
```

The `+ 978307200` is not optional: Core Data stores dates as seconds since 2001, and without it every
timestamp reads as 1970-something and the evidence looks broken. Run one real pomodoro, tap I twice
and E once at moments you can remember, write a sentence for one and skip the others. Three rows,
correct kinds, timestamps matching when you actually tapped, exactly one non-null note, and two
genuine `NULL`s — **not empty strings**. That last clause is the device-level proof of E-j.

Two regression checks that must be demonstrated failing without their fix, since a test nobody has
seen fail is decoration:

- delete `guard now < state.endsAt` ⇒ `tapAfterTheBlocksEndInstantIsRefused` fails;
- move the `pendingReflection` assignment above the transition in `end()` ⇒ `breakStartsBehindSheet`
  still passes, so instead delete the assignment from the auto-start exit path ⇒ it fails. Say which
  you did.

---

## 10. Scope fence

The greppable list is in the structured response and the reviewers search it. Four clarifications a
literal grep cannot express:

- **"No reading-back UI"** means there is no screen, list, count, sheet, or debug view anywhere in the
  app that displays a past `Distraction`. The badge on the I/E buttons shows the count for the block
  running *right now* and is not a history view. `DistractionTally.summary(of:)` appears in exactly
  two places, both of them sheets about the block that just happened. F6 owns everything else.
- **"No capture surface"** means no field, anywhere, that accepts a new *task*. The sentence fields
  accept a reflection, which is what `SPEC.md` explicitly asks for and what D13 already ratified for
  the stop sheet. Nothing may read as task entry: no placeholder that suggests one, no "add", no
  plus, no list that grows.
- **"No Todoist plumbing"** means `taskTitle` and `projectTitle` are two `String?` columns and
  nothing else in the tree mentions them. No id column, no import, no endpoint, no fetch, no reader.
  §3.3.
- **"No pause, no skip"** means neither word appears as a control anywhere in the diff. D13 removed
  Skip; a new button beside I and E that ends a block early is Skip returning under a new name.

---

## 11. Risks, most likely first

1. **`Distraction.self` is left out of `AppModelContainer`'s `Schema`.** Every insert traps at
   runtime, in the app and in every test, with an error that names SwiftData rather than the missing
   line. It is one line in a file neither engineer would otherwise open. **Do it in the seam commit,
   first.**

2. **Someone reaches for `@Relationship`.** It is the idiomatic SwiftData shape and `F5.md`'s own
   sketch writes it that way. It is wrong here for the reason in §3.2, and the way it goes wrong is
   the worst available: nil at insert, back-filled at block end, and therefore a durable row whose
   link to its block depends on a later write. If you find yourself writing `session:
   PomodoroSession?`, stop and re-read §3.2.

3. **A `Task { }` appears in the tap handler**, copied from the Start and Stop precedent two lines
   above it in the same file. §7 forbids it; the grep is `Task` in `DistractionButtons.swift` and in
   `TimerView`'s tap handler.

4. **A second writer appears anyway**, as `@Environment(\.modelContext)` inside a sheet writing notes
   directly. It would work in the simulator and would be a second context by design. §5, E-a.

5. **`taskTitle` reads to the reviewer as F3 starting early.** §3.3 is the defence and it must be
   quoted in the PR description, not left to be discovered. If the reviewer rejects it, the fix is
   deleting two lines and one test — cheap, and cheaper still if the argument is already on the page.

6. **AX5 layout.** Two large buttons plus a 96pt countdown plus the sprint rule plus Stop, on one
   screen, at the largest accessibility text size. `ViewThatFits` with a horizontal pair falling back
   to a vertical stack; no `.dynamicTypeSize(...)` cap anywhere (D7's ratified rule stands); the
   preview is required evidence, not optional.

7. **`end()` has two exit paths and only one gets the assignment.** The auto-start branch and the
   go-idle branch. Both tests in §4.5 exist because of this specific shape.

8. **The merged stop sheet outgrows the screen** with the keyboard up and three tap fields. §6.4
   prescribes the `ScrollView`; without it the confirm button is off-screen at exactly the moment the
   sheet is being used.

9. **`#Predicate` on `sessionID`.** SwiftData's predicate compiler is fussy about captured values.
   If `#Predicate<Distraction> { $0.sessionID == id }` will not compile or returns nothing, fetch the
   block's rows without a predicate and filter in Swift — a block holds single-digit rows and this is
   a rehydration path that runs at launch and on foreground, not in a loop. Do not spend an afternoon
   on the predicate.

10. **The reflection sheet is swipe-dismissible and a typed-but-unsaved sentence is lost.** This is
    ratified (`F5.md` F5-T2: "dismissed by swipe or by the app being killed ⇒ notes stay `nil`") and
    is implemented rather than worked around. The mitigation is that `Done` is the only large control
    on the sheet. Recorded as an accepted cost, not a defect. The same applies if the sheet is still
    open when the break ends — the view holds its own copy, so the sheet survives the boundary, but
    the rows are what persists and the sentence is not.

11. **The AlarmKit race `F5.md` names is dissolved rather than mitigated, and that should be said.**
    If the phone is locked at the boundary, `boundaryReached()` does not run on time and E-g means no
    prompt is ever produced — the rows are recorded by `synchronize()` on the next foreground and the
    app stays quiet. So there is no presentation race to lose: the sheet either appears immediately,
    with the app in front of the person, or never. State that in the PR; a reviewer reading `F5.md`
    will be looking for the mitigation and should find the reason it is not needed.

-----
August 23, 2026

#AI/Claude
