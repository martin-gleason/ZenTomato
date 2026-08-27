# Amendments to apply to `SPEC.md`

**For the owner. The agent never edits the contract — this proposes, you apply.**

Seven ratified deltas whose text has never reached `SPEC.md`. Each block below gives the **exact
current line** and the **exact replacement**, so applying one is a copy and a paste rather than a
judgement. Nothing here is new: every one was ratified between 21 and 23 August 2026 and is already
built and shipped in the app.

**Do them in any order except that `A2` unblocks `F7`**, which cannot begin until it lands — by that
plan's own opening line.

After each, add the delta's id to the `## Amendments applied` list at the bottom of `SPEC.md` (create
it if it is not there yet) and lower the number in `docs/specs/AMENDMENT-BASELINE.txt` by one.
`DeltaIntegrityTests` counts what is left on every run.

---

## A1 — D1: minimum iOS, and watchOS

**Line 32**, in the *Locked decisions* table.

Current:
```
| Minimum iOS | 18.0 (adjust to Marty's phone at C2). |
```
Replace with:
```
| Minimum iOS | 26.0. Minimum watchOS 26.0. |
```

*Why: the phone runs iOS 26.6 and the app uses AlarmKit, which does not exist before 26. C2 is done.*

---

## A2 — D2: the watch companion. **This one unblocks F7.**

**Line 57**, the out-of-scope list. Change only the first item:

Current:
```
watchOS (remote and standalone) · macOS · CloudKit sync · …
```
Replace with:
```
standalone watchOS · macOS · CloudKit sync · …
```
*(Leave the rest of that line exactly as it is.)*

**Line 6**, the platform line.

Current:
```
**Platform:** iOS only. Watch, Mac, CloudKit sync, playlist creation, and task *creation* are Phase 2 — see Out of Scope.
```
Replace with:
```
**Platform:** iOS, with a watchOS companion (F7). Mac, CloudKit sync, playlist creation, and task *creation* are Phase 2 — see Out of Scope.
```

**And add to the feature list**, after F6:
```
- **F7 — Watch companion.** watchOS 26 companion app. The phone is the source of truth and runs the only timer engine. The watch displays the running block, the block kind, and the attached task, and puts the I and E distraction buttons on the wrist. The watch never runs a timer of its own, never controls music, never picks a task, and never edits a distraction note. *Done when:* three wrist taps during a pomodoro, with the phone in another room, yield three records on the phone with the right task and timestamps.
```

*Why: the distraction log is the point of the app, and its one real failure mode is friction at the
moment of capture — reaching for the phone to record a distraction is itself a distraction. The
standalone watch stays out.*

---

## A3 — D3: AlarmKit, and the Live Activity is required

**Line 39**, F2.

Current:
```
Survives backgrounding (state persisted, local notification fires when a block ends). Live Activity on the Lock Screen if it fits in budget; otherwise notification only.
```
Replace with:
```
Survives backgrounding (state persisted). Block ends fire through AlarmKit, so the alert sounds through silent mode and through an active Focus. A Live Activity on the Lock Screen and in the Dynamic Island is required, not optional — AlarmKit's countdown API mandates one.
```

*Why: a local notification is silenced by a Focus, which is exactly when a focus timer is running.
AlarmKit is not optional for that reason, and it will not give you a countdown without a Live
Activity — so the "if it fits in budget" clause describes a choice that does not exist.*

---

## A4 — D4: the end-of-pomodoro sheet

**Add to F5** (line 42), after the existing text:
```
At the end of a pomodoro the app presents one sheet containing a sentence field per distraction tap (each skippable) and, once F3 has landed, the Complete-task button. The break timer starts running the instant the block ends, behind the sheet — reflection never consumes break time. The auto-start-next-block setting governs the pomodoro after the break, not this sheet.
```

*Why: F3, F5 and the settings list each claimed the same instant. Starting the break behind the sheet
is the load-bearing half — if the sheet held the break, a slow reflection would silently stretch the
day and the timer would stop being a clock you can trust.*

---

## A5 — D17: the session plan

**Line 16.** Keep the existing sentence — it stays true of every individual pomodoro — and **add**
after it:
```
Before a sprint, the user may build a **session plan**: an ordered list of Todoist tasks and projects, drawn from the cache, which the timer works through. Each pomodoro attaches to the plan's current item, so the one-task-per-pomodoro rule is unchanged. A plan creates nothing and writes nothing.
```

*Why: choosing what to work on is a planning act, and doing it at the start of every block is the
wrong moment — you are trying to begin, not decide. A plan writes nothing to Todoist, so the
no-capture rule is untouched.*

---

## A6 — D18: a personal API token, not OAuth

**Line 40**, F3. Change only the first clause:

Current:
```
- **F3 — Todoist.** OAuth sign-in; fetch projects, sections, tasks; …
```
Replace with:
```
- **F3 — Todoist.** Sign in with a Todoist personal API token, entered once and stored in Keychain; fetch projects, sections, tasks; …
```

Also, in the same entry's *Done when*:

Current:
```
*Done when:* sign-in, pick, and complete work against Marty's real account.
```
Replace with:
```
*Done when:* token entry, pick, and complete work against Marty's real account.
```

*Why: Todoist's OAuth has no PKCE, so exchanging the code for a token needs the client secret — and a
phone app has nowhere safe to keep one. Neither `.env` nor `.xcconfig` changed that: both keep it out
of git, neither keeps it out of the `.app` bundle. A pasted personal token removes the secret from the
world entirely, and removes chore C3 with it.*

**This is the amendment the automated check cannot see** — it quotes the spec as `"OAuth sign-in."`
while the spec reads `"OAuth sign-in;"`. Lower the baseline by one by hand when you apply it.

---

## A7 — D20: stop, beside skip

**Line 26**, in the *Locked decisions* table.

Current:
```
| Music during a sprint | Skip-forward is the only control. Music can be toggled on/off before a sprint. |
```
Replace with:
```
| Music during a sprint | Skip-forward and stop are the only controls. Stop silences the music for the remainder of the current block; the timer is unaffected and the next block starts music again. Music can be toggled on/off before a sprint. |
```

*Why: found on the device — music that will not stop mid-block means picking up the phone, opening
Music, and stopping it there, which is worse for focus than a button in the app.*

---

## While you are in the file

**Line 3** still reads `**Status:** DRAFT for ratification.` The build was authorised on 21 August
2026 and six features have shipped against it. If it is the contract, it should say so.

## Then add, at the end of `SPEC.md`

```
## Amendments applied

D1 D2 D3 D4 D17 D18 D20
```

List only the ones you have actually applied. `DeltaIntegrityTests` reads this section, and the
backlog count drops as the old text disappears from the file.

---

## A8 — D25: music can be switched on during a break

**Ratified by the owner 2026-08-27.** Unlike `A1`–`A7`, this one is **not yet built** — the
behaviour it describes does not exist in the app today, and will not until `F4f` lands.

**Line 27**, in the *Locked decisions* table.

Current:
```
| Music during breaks | Pauses. Resumes at the next pomodoro. |
```
Replace with:
```
| Music during breaks | Pauses, and can be switched back on by hand. Resumes by itself at the next pomodoro. |
```

**Why this one is urgent in a way the others are not.** `DeltaIntegrityTests` counts ratified
deltas whose replacement text has not reached `SPEC.md`, and fails when that count **grows**. The
baseline is pinned at zero. So `D25` is deliberately still marked *proposed* in `00-deltas.md`
until this paste happens — stamping it ratified first would turn CI red and block every merge
under branch protection.

**The sequence, therefore:** paste the line above, add `D25` to the `## Amendments applied` list at
the bottom of `SPEC.md`, and tell the agent. The agent then stamps the delta ratified in the same
commit, and the count never leaves zero.
