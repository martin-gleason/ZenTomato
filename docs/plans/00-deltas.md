# Proposed spec deltas — v0.1

`SPEC.md` is the contract and the agent never edits it. These are the deltas the plans depend on.
**Nothing in `docs/plans/F1.md`–`F7.md` may be built until you merge these into `SPEC.md` yourself.**

Each delta states the current spec text, the proposed text, and why.

---

## D1 — Minimum iOS 18.0 → 26.0

**Currently:** *Locked decisions* table — `Minimum iOS | 18.0 (adjust to Marty's phone at C2).`
**Proposed:** `Minimum iOS | 26.0. Minimum watchOS 26.0.`

**Why:** C2 is answered — the phone runs iOS 26. The spec anticipated this adjustment, so this is a
fill-in-the-blank rather than a change of intent. It is listed here because the table value is stale
and because two other deltas (D2, D3) are only possible at 26.0.

---

## D2 — watchOS companion moves from Phase 2 into v0.1 as F7

**Currently:** *Out of scope for v0.1* — `watchOS (remote and standalone) · macOS · …`
**Proposed:** replace with `standalone watchOS · macOS · …`, and add to the feature list:

> **F7 — Watch companion.** watchOS 26 companion app. The phone is the source of truth and runs the
> only timer engine. The watch displays the running block, the block kind, and the attached task, and
> puts the I and E distraction buttons on the wrist. The watch never runs a timer of its own, never
> controls music, never picks a task, and never edits a distraction note. *Done when:* three wrist taps
> during a pomodoro, with the phone in another room, yield three records on the phone with the right
> task and timestamps.

**Why:** The distraction log is the stated point of the app, and its one real failure mode is friction
at the moment of capture — noticing a distraction and then having to pick up the phone is itself a
distraction. The wrist is where that capture wants to live. Everything else stays on the phone.

**Cost, stated plainly:** one extra feature gate, a second physical device in the test loop, and a
delivery layer (WatchConnectivity) with genuine offline edge cases. Against a **September 13, 2026**
hard stop this is the feature most likely to be the one abandoned unmerged. It is sequenced last for
exactly that reason — see the build order in `F1.md`.

---

## D3 — F2 alerting: AlarmKit primary, Live Activity promoted to required

**Currently:** *F2* — `Survives backgrounding (state persisted, local notification fires when a block
ends). Live Activity on the Lock Screen if it fits in budget; otherwise notification only.`
**Proposed:** `Survives backgrounding (state persisted). Block ends fire through AlarmKit, so the alert
sounds through silent mode and through an active Focus. A Live Activity on the Lock Screen and in the
Dynamic Island is required, not optional — AlarmKit's countdown API mandates one.`

**Why:** F2 was written against iOS 18, where a local notification was the only tool available. On
iOS 26, AlarmKit schedules against the system's real alarm infrastructure. The difference matters:
a `UNUserNotificationCenter` notification is swallowed by silent mode and by a Focus session — and a
Focus session is precisely the state a Pomodoro user is in. A timer whose end-of-block alert can be
silenced by the thing the timer exists to support is not a timer.

The Live Activity comes along for free because AlarmKit requires it for countdowns, which is why F2's
stretch goal becomes its baseline.

**Consequence:** AlarmKit has its own authorization prompt, separate from notifications. If it is
denied, the app has no reliable way to alert. F2 handles that as a blocking explainer rather than by
silently degrading — see `F2.md`, "Authorization denied".

---

## D4 — End-of-pomodoro sequence made explicit

**Currently:** F5 says the app `prompts for one sentence per tap (skippable)` at the end of a pomodoro.
F3 says `complete a task with one button at the end of a pomodoro`. The settings list includes
`auto-start next block on/off`. The spec does not say how these three share the same moment.
**Proposed:** add to F5:

> At the end of a pomodoro the app presents one sheet containing a sentence field per distraction tap
> (each skippable) and, once F3 has landed, the Complete-task button. The break timer starts running
> the instant the block ends, behind the sheet — reflection never consumes break time. The
> auto-start-next-block setting governs the pomodoro after the break, not this sheet.

**Why:** Three features were each specified to own the same instant, which is a merge conflict waiting
to happen at F5's gate. Starting the break behind the sheet is the load-bearing part: if the sheet
blocked the break, a slow or interrupted reflection would silently stretch the day and the timer would
stop being a clock you can trust.

---

## D5 — Todoist API version (verification result, recorded for the file)

Not a change of intent — F3 already instructs *"verify at build time the current Todoist API version
and rate limits."* This records the answer so it is not re-derived later.

**Result:** Todoist's REST v2 and Sync v9 APIs were **permanently removed on 2026-02-10**. The unified
**API v1** at `https://api.todoist.com/api/v1` is the only live surface, and object IDs from the old
APIs do not carry over. F3 targets v1 from the first commit.

This is the incident F3's warning refers to. The relevant lesson for us is the second-order one: pin
the API version in one file, and make the version visible in the PR, so the next deprecation is a
one-file change rather than an archaeology project.

---

## Ratification

Merge D1–D5 into `SPEC.md`, or reject any of them, and say so. Rejecting D2 deletes `F7.md` and costs
nothing else. Rejecting D3 reverts F2 to notification-only and Live Activity returns to a stretch goal.
D1, D4, and D5 are load-bearing for every plan below.

---

## D6 — ~~Secrets live in `.env`~~ **REJECTED 2026-08-22. Superseded by D6b.**

Not a `SPEC.md` delta — `SPEC.md` only says *"put the client ID and secret where CLAUDE.md says
secrets go."* This is a **CLAUDE.md** edit, recorded here because it changes a stated non-negotiable.

**Currently:** *Non-negotiable* — `Todoist client credentials come from a git-ignored
Secrets.xcconfig; the user token lives in Keychain.`
**Proposed:** `All build-time secrets live in a single git-ignored .env. A build phase generates a
git-ignored Secrets.xcconfig from it; nothing reads .env at runtime. The user's Todoist token lives in
Keychain, never in .env.`

**Why:** You keep every project's secrets in `.env`, and one habit beats a per-project convention.
The mechanical problem is that Xcode has no idea what a `.env` is — it consumes `.xcconfig`. So `.env`
stays the thing you edit and the only thing that holds a real value, and `Secrets.xcconfig` becomes a
generated, git-ignored, disposable artifact. Both are ignored; neither is ever committed.

```
.env                  ← you edit this. Ignored. The only real secrets on disk.
   │  scripts/gen-secrets.sh  (Xcode build phase, runs before compile)
   ▼
Secrets.xcconfig      ← generated. Ignored. Deletable; regenerates on next build.
   │  Xcode build settings → Info.plist
   ▼
Bundle.main           ← client ID and the OAuth callback scheme
```

`.env.example` is committed with empty values, so the repo documents which keys are required without
ever holding one. CI has no `.env` — it reads the same keys from GitHub Actions encrypted secrets, and
the F1 gitleaks hook runs against the tree either way.

**REJECTED.** The owner rejected this on 2026-08-22: `.env` was habit carried in from other projects
rather than a decision, and Xcode has its own configuration mechanism that should have been used from
the start. See **D6b**. The note below is kept because it is unchanged by that rejection and became
*more* important, not less.

**Note on what this does and does not protect.** A git-ignored file keeps the secret out of *git*. It
does not keep the Todoist client secret out of the *built app* — you ratified that trade in the auth decision, and it
is acceptable only because this build is never distributed. If ZenTomato is ever shipped to anyone
else, the client secret must move behind a token-exchange service and this note becomes a blocker.

---

## Chore status (recorded 2026-08-21)

- **C1** (repo, LICENSE, branch protection) — **done**
- **C2** (minimum iOS, developer account, App ID with MusicKit) — **done**; answer is iOS 26 / watchOS 26, see D1
- **C3** (Todoist OAuth app registered, credentials placed) — **done**; credentials in `Config/Secrets.xcconfig`, see D6b
- **C4** (install builds on the iPhone) — **done 2026-08-22**, moved up. `make device` installs to the iPhone 15 Pro Max on iOS 26.6. This no longer gates anything.
- **C5** (fixed afternoon PR-review slot) — deferred to beta

C4 was front-loaded on 2026-08-22 rather than left to beta, which was the right call: F2 immediately
proved why. A simulator cannot answer a permission prompt, so **AlarmKit was never once authorised in
any automated run** — every alarm-dependent behaviour in F2 is verified only against a protocol
stand-in that cannot fail. Had C4 stayed deferred, four features would have queued up in a
`verified-pending-device` state and their device-only bugs would all have surfaced in one sitting.

---

## Ratified 2026-08-21

D1–D6 accepted; build authorised starting at F1. Also decided at this gate:

- **No pause control.** Confirmed. The timer runs; a block can be skipped or stopped, never paused.
  The AlarmKit Live Activity therefore offers dismiss only. See `F2.md`, F2-T2.
- **F7 stays on the list.** Attempted in order, after F6. The September 13 clause still governs it.
- **Design tokens, not themes.** See the scope note below.

### Scope note — design tokens are not the "themes" the spec excludes

`SPEC.md` puts **themes** in the out-of-scope list, and v0.1 will carry a semantic design-token layer
ported from the Civic Data design system. These are not the same thing, and the line between them is
the thing the adversarial reviewer must police:

**In scope for v0.1** — a two-layer token system (primitives → semantic roles) and light/dark support.
Every app has colours; naming them by role instead of scattering literals is ordinary structure, and
light/dark is a system-level user setting that iOS apps are expected to honour, not a feature.

**Out of scope for v0.1** — a theme *picker*, a second selectable theme, any user-facing appearance
setting, or a `Theme` model with more than one instance. `AppSettings` gains no new field.

The v1.5 modularity is a consequence of doing the token layer properly, not an extra thing built now:
if components only ever reference semantic roles, adding a theme later is a new mapping file and
nothing else. Nothing is stubbed, scaffolded, or "prepared" for it.

---

## D7 — Fence exception: the countdown numeral may state a raw point size

**Ratified 2026-08-22.**

The F1 scope fence bans letter-spacing tokens and pins every type role to one of Apple's named text
styles. The ratified timer-screen design calls for the numeral at 96pt with −0.015em tracking —
"the entire interface", roughly 5.6× the next-largest text. Apple's largest style is about 34pt, so
the design is unbuildable inside the fence, and the engineer correctly refused to break it.

**Exception granted, narrowly:** `Typography` may state one raw point size (`numeralBaseSize`) and
one tracking ratio (`numeralTrackingRatio`), for the countdown numeral only. Both are consumed at
exactly one call site.

**Why the exception is safe.** Dynamic Type is not traded away: the call site pairs the size with
`@ScaledMetric(relativeTo: .largeTitle)`, which puts the numeral back on Apple's own growth curve,
including the compression at the top accessibility sizes. Tracking is expressed as a *fraction* of
the size rather than a fixed number of points, so it scales with the numeral instead of drifting
apart from it.

**What it also fixes.** At AX5 the kicker was growing on `.caption`'s curve while the numeral grew on
`.largeTitle`'s, collapsing the size hierarchy from ~2.9× to ~1.4× — the label became nearly as loud
as the number. Raising the numeral's base fixes the root cause; no Dynamic Type cap was added, and
the ratified "no `.dynamicTypeSize(...)` cap anywhere on this screen" rule stands.

**The fence still holds everywhere else.** A second raw point size appearing in `Typography.swift` is
a defect, and the file says so in its own documentation.

---

## D8 — A launch-screen colour set is added to the asset catalog

**Ratified 2026-08-22.**

The architect's file layout enumerated the asset catalog's contents and said "create exactly these,
no others". `LaunchBackground` was not among them, so `UILaunchScreen` shipped empty — meaning every
cold launch painted pure white (or pure black) before the app's warm stone page appeared, on the app
whose entire stated direction is "stone rather than pure white".

**Exception granted:** one colour set, `LaunchBackground` (Any `#F6F5F2`, Dark `#1C1F22`), and
`UILaunchScreen: { UIColorName: LaunchBackground }` in `project.yml`. The designer's token spec had
already authorised exactly one asset-catalog colour for this and only this reason; the file list
simply did not carry it across.

**With a mechanism, not a promise.** An asset catalog is data, so nothing in the compiler can hold it
equal to `ColorRole.surfacePrimary`. `ZenTomatoTests/LaunchBackgroundTests.swift` decodes the real
`Contents.json` and compares both appearances against the role. It was verified to fail on a
one-hex-digit drift and to pass when restored — this is a colour that goes wrong by neglect rather
than by edit, since the natural place to change the page colour is `Palette.swift`, three directories
away from the JSON that also has to move.

---

## D6b — Build settings use Xcode's own `.xcconfig` mechanism

**Ratified 2026-08-22, replacing the rejected D6.**

Not a `SPEC.md` delta — `SPEC.md` only says *"put the client ID and secret where CLAUDE.md says
secrets go."* This is the **CLAUDE.md** text that sentence points at.

```
Config/App.xcconfig              committed. Safe defaults. Ends with:
  └── #include? "Secrets.xcconfig"
Config/Secrets.xcconfig          git-ignored. The only file holding a real value.
Config/Secrets.example.xcconfig  committed. Same keys, every value empty.
        │
        ▼  Xcode reads this when it loads the project
  build settings ──▶ Info.plist via $(KEY) ──▶ Bundle.main at runtime
```

**Why this replaces the `.env` pipeline.** `.env` is a convention from other ecosystems, and Xcode has
no idea what one is — which is why D6 needed a generator script, a build-phase staleness guard, and
four tests to prove the generator worked. An `.xcconfig` is what Xcode reads natively. Removing the
translation step removes the script, the guard, the generated artifact, and everything that could
drift between them. It also let `ENABLE_USER_SCRIPT_SANDBOXING` go back to its secure default, which
was only ever disabled so the generator could write into the source directory.

**The `?` in `#include?` is the load-bearing character.** It means "include if present". A fresh clone
with no secrets file builds and tests green — verified — which matters because nothing in the app
reads a credential yet, and a skeleton that refuses to compile without one is a gate that cannot run.

**What this does *not* fix, and it is now the bigger problem.** See **D9**.

---

## D9 — ~~Shipping invalidates the F3 authentication decision~~ **RESOLVED by D18, 2026-08-23**

**Raised 2026-08-22. Needs a decision before F3. Not urgent today; blocking then.**

The owner's reason for moving to Xcode-standard configuration was *"because this will eventually
ship."* That sentence changes something the earlier F3 auth decision explicitly depended on.

When OAuth-as-specced was ratified, it was ratified with this stated trade: the Todoist **client
secret is embedded in the built app**, which is *"acceptable only because this build is never
distributed. If ZenTomato is ever shipped to anyone else, the client secret must move behind a
token-exchange service and this note becomes a blocker."*

**Moving to `.xcconfig` does not change that.** Neither did `.env`. Both keep the secret out of *git*;
neither keeps it out of the *app*. A build setting becomes an `Info.plist` entry, and `Info.plist` is
plain text inside the `.app` bundle — anyone who downloads a shipped build can read it in seconds.
There is no file format, no obfuscation, and no Apple-provided store that changes this. **A secret
shipped inside an app is a published secret.**

Todoist's OAuth makes this unavoidable rather than merely awkward: it has no PKCE, so exchanging the
authorization code for a token *requires* the client secret. A public client has nowhere safe to keep
it.

Three ways out, and none is free:

| Option | Cost | Spec impact |
|---|---|---|
| **Personal API token per user** — each person pastes their own Todoist token, straight to Keychain | No client secret exists anywhere. Worse first-run UX. | Delta against F3's "OAuth sign-in" |
| **Token-exchange service** — a small server holds the secret; the app never sees it | Hosting, a domain, uptime, and an ongoing cost | Contradicts **"Local only… no server"**, a stated non-negotiable |
| **Never distribute** — personal build only, installed by Xcode | Nothing changes | None — this is what is ratified today |

Note that the second option, the conventional answer for a shipping app, is ruled out by `CLAUDE.md`'s
*Local only* rule as currently written. So a shipping ZenTomato most likely means the **personal API
token**, which is the option offered and declined at the F3 gate — declined on the explicit
understanding that the app was personal.

**No action needed now.** F1 ships no Todoist code, and F3 is two gates away. This is recorded so the
decision is made deliberately at that gate rather than discovered during a release. If the answer is
"personal token", F3's plan gets simpler, not harder.

---

## D10 — F2 gains the settings screen

**Raised and ratified 2026-08-22, during the F2 gate.**

**This is a spec defect, not a scope request.** `SPEC.md` line 30 locks *Timer customization — work
length, short break, long break, pomodoros-per-sprint, sound on/off, auto-start next block on/off*.
But F1 builds only the settings *model*, F2 only *reads* it, and no feature in F1–F6 ever builds a
screen that writes one. As the feature list stands, v0.1 ships permanently locked at 25/5/15/4 and the
locked decision on line 30 is unreachable.

**Proposed:** amend F2 to read:

> **F2 — Timer engine.** Pomodoro / short / long break cycle per settings, and the screen that sets
> them — the six values in *Timer customization* and nothing else. Survives backgrounding…

**Why F2 rather than a feature of its own.** F2 already reads all six values, so putting the writer
beside the reader keeps one feature owning the whole of "the timer behaves the way you configured it".

There is also a practical reason that matters more than the tidiness one: **F2's device check is
otherwise 25 minutes of waiting.** With the screen in the same feature, the cycle can be exercised at
one minute per block — so the whole work/short/work/short/work/short/work/long sequence takes eight
minutes instead of two hours, and the full-length run becomes a final confirmation rather than the only
way to see the engine work at all.

**Scope fence, unchanged.** Six fields. No seventh. No theme control, no appearance setting, no music
toggle — the music on/off is session state owned by F4, and `SPEC.md` says "Nothing else."

---

## D11 — Completed tasks are recorded and exported

**Raised and ratified 2026-08-22.**

F3 completes a task in Todoist, and F6 counts *pomodoros* per task, project and day. Neither records
**which tasks were finished**, so the Rhodia review can say how much time went where but not what came
out of it.

**Proposed:** add to F3, "…and the completion is recorded locally with its timestamp"; and to F6's
list, "…plus the tasks completed in the period."

**Why record it rather than read Todoist.** Todoist knows what you completed and is the only place
tasks live — that rule is not in question. But the export is a document assembled offline for a paper
review, and reaching across the network to build it would make a two-week retrospective depend on being
signed in and online. The local row is a *record of something this app did*, which is a different thing
from a task model: it stores the task's id and a snapshot of its title, exactly as the pomodoro rows
already do, and it is append-only. It creates no hierarchy, no local task list, and nothing that could
grow into one.

**Cost:** one small model and one export section. The recording lands in F3, the export in F6.


---

## D12 — The Live Activity has no controls

**Ratified 2026-08-23, during F2's device review.**

The running-block Live Activity shipped with a Dismiss button on the Lock Screen card and in the
expanded Dynamic Island. Both are removed. The card now reads and does not act.

**Why.** A Lock Screen button cannot be trusted to record what it did. iOS reclaims a backgrounded
app's memory whenever it likes, and a Live Activity button reaches the app through an App Intent that
does nothing at all if the app is not resident. The tap silently reached nothing; the block was left
to be reconciled at the next foreground from its stored end time alone — and by then that time had
passed, so it was recorded as **completed**.

The consequence is the part that matters: deliberately abandoning a block from a locked phone added a
pomodoro you had not earned. Not to a cosmetic counter, but to the one number the whole app exists to
produce and that the two-week review is read from. It also directly contradicted the decision taken at
this same gate that a block ended early is abandoned and excluded from counts.

**Why removal rather than a fix.** Making the button honest needs a field on `TimerState` plus a
cross-process channel from the widget back to the app — real design, and design for a control nobody
asked for. `SPEC.md` never promised a Lock Screen control; F2's plan named "dismiss" as the one
affordance the Live Activity would carry, and this delta withdraws it. Abandoning a block now happens
in the app, where the engine is certainly running and can record what actually happened. That is one
extra tap, on a deliberate act.

**What is kept.** `DismissBlockIntent` survives as the Stop button on the full-screen alert iOS draws
when a block's alarm *fires*. Reaching it now implies the alarm was sounding, so the reconciliation
fallback — record it as completed — is correct rather than merely tolerable. The engine still asks
rather than assumes: it compares the clock to the block's end time, so the rule lives in one tested
place.

---

## D13 — One exit, and it costs a sentence

**Ratified 2026-08-23, from the F2 device review.**

The owner, having run the timer on the phone: *"I didn't want a stop button. When a pomodoro starts,
it doesn't stop."*

That is the classic technique's own rule — the pomodoro is **indivisible**; interrupt it and it is
void rather than paused. F2 shipped Skip and Stop as two free, single-tap exits because the plan
assumed them, not because `SPEC.md` asked for either.

**Proposed:**

1. **Skip is removed.** There is no way to cut a block short and move to the next one. The only way
   past a block is to finish it.
2. **Stop is the single exit, and it demands a written reason.** Tapping Stop presents a sheet asking
   why. The confirm button stays disabled until something is written; a "Keep going" button dismisses
   the sheet and lets the block continue. The reason is stored on the session.
3. `PomodoroSession` gains `abandonReason: String?` — non-nil exactly when a person stopped a block
   and said why.

**Why an exit has to exist at all.** A block that genuinely cannot be ended means a mistyped
120-minute focus length traps you for two hours with an alarm you cannot call off. The only remaining
escape would be force-quitting the app — and a force-quit reconciles from the stored end time and
records the block as *completed*, which is precisely the false-count bug D12 just removed from the
Lock Screen, arriving through a different door. The exit is not a weakening of the rule; it is what
stops the rule producing wrong data.

**Why the sentence is required rather than skippable.** F5's distraction prompt treats skipping as a
first-class outcome, and that is right there: a tap already carries the data, and the sentence is a
bonus. This is the opposite case. The *fact* of stopping is one bit; the reason is the entire content.
And the day you least want to write it — the day you bailed out and would rather not think about
why — is the day it is worth the most. A stop is the largest distraction event there is, and the app
currently records nothing about it.

**This is not a capture surface.** The no-capture rule forbids the app accepting a new *task*. This
field accepts a reflection, which is the same thing F5's end-of-pomodoro prompt already does and which
`SPEC.md` explicitly asks for. It creates nothing in Todoist and nothing that could become a task.

**Consequence for F6 (noted, not built):** `abandonReason` is a column the export will want — "why I
stopped" beside "what distracted me" is the shape of a real review. F6 decides at its own gate.

---

## Recorded for after v0.1 — not built, not prepared for

Raised during the F2 device review and parked deliberately, so they are neither lost nor smuggled in:

- **A choice of alarm sound (v1.1).** *"This alarm kinda stinks — folks will want to change it."*
  Agreed, and out of scope: `SPEC.md`'s customization list is closed at six values and says "Nothing
  else." AlarmKit takes an `AlertConfiguration.AlertSound`, so the mechanism is one parameter — the
  work is the picker and the settings field, both of which need a delta. **Do not add a seventh
  settings field before that delta exists.**
- **~~Dynamic Island presentation.~~ Verified working on device 2026-08-23.** Not a v1.1 item after
  all — it shipped in F2 and it works.
- **Calendar time-blocking, in v1.5 — and it is EventKit, not Fantastical.** The owner's shape:
  *"time blocks in Fantastical, projects and to-dos in Todoist, and use pomodoro to work."*

  The thing worth knowing before anyone starts: **Fantastical has no integration surface.** It is a
  client, not a service — it reads and writes the system calendar, the same one Apple's Calendar app
  uses. So "connect to Fantastical" is really **EventKit**, and the integration is with the calendar
  store both apps share. That is good news: it works whatever calendar app is in front of it, it needs
  no account, no API key and no network, and a block ZenTomato reads was authored in Fantastical
  without either app knowing about the other.

  Consequences to weigh at that gate: EventKit is a new permission prompt and a new privacy string; it
  does NOT breach *"Local only… no network calls except Todoist and MusicKit"*, since EventKit is
  entirely on-device; and the natural first version is **read-only** — see today's blocks, start a
  pomodoro against one — which needs no write access at all and is a much smaller ask of the user than
  full calendar access.

- **Gamification, in v1.5.** `SPEC.md`'s out-of-scope list ends with *"streaks, badges, or any
  gamification layered on top of Todoist's own"*, and the owner has placed that at v1.5 rather than
  never. Nothing changes for v0.1 — the exclusion stands and F6's review is still pointed at it,
  because a stats screen is exactly where that pressure appears first. Noted so the eventual delta is
  a decision rather than a drift.

- **A tomato that builds itself as the block runs (v1.1).** The owner's idea, and a good one: instead
  of a countdown readout, the Live Activity draws a tomato that assembles as the minutes pass, so the
  Lock Screen shows progress as a *picture* rather than a number.

  Worth stating why it is genuinely v1.1 and not a quick swap. The countdown works today because
  `Text(timerInterval:)` renders client-side from the alarm's `fireDate` with no updates pushed at
  all — that is the entire reason the wall-clock design holds and the Live Activity costs nothing. A
  drawing that changes with time cannot use that trick: SwiftUI's timer text is a special case, and an
  arbitrary view has to be re-rendered, which means pushed activity updates, which means an update
  budget and a battery cost. It is buildable — most likely by drawing the tomato in discrete stages
  and pushing one update per stage rather than continuously — but it is a real design problem with a
  real cost, not a change of view code.

  It also needs the icon's vector artwork factored out of `Design/icon/make-icon.sh` and into
  something the widget can draw. **Do not start any of this before a ratified delta.**

---

## D16 — Designed so bi-directional sync is *possible* later, without preparing for it now

**Ratified 2026-08-23.** The owner: *"I want, eventually, actions from ZenTomato to write to Todoist
as well as be updated from Todoist. It should be bi-directional. Stick to the 1.0 spec on this, but
build the functions in such a way to allow for this to be updated in v1.1 or v1.5."*

This sits directly on a non-negotiable — *"Do not build it, stub it, or 'prepare for it.'"* — so the
line has to be exact, because both halves are right.

### The distinction

**Good design that happens to be extensible is not preparation.** Preparation is code that exists
only to serve a feature that does not. The test is simple: *would I write this the same way if
bi-directional sync were never coming?* If yes, it is design. If no, it is preparation.

### What v0.1 does, all of which passes that test

| | Why it is design, not preparation |
|---|---|
| **Every Todoist request in one type.** `TodoistAPI.swift` holds the base URL, the version and every endpoint constant. | Already in F3's plan, written before this delta existed. Scattering HTTP through views is bad regardless. |
| **The endpoint allowlist stays.** `scripts/todoist-allowed-endpoints.txt`, enforced pre-commit and in CI. | This is the *mechanism* by which a future write is added: a visible, committed, reviewable diff. It does not need loosening later; it needs to keep working. |
| **The cache is a genuine mirror.** No invented fields, no local ordering, no local hierarchy. | The rule already. It also happens to mean there is no divergent local state to reconcile when sync arrives. |
| **Title snapshots on records.** | Already required so a two-week-old review reads truthfully. Independently, it means history is not rewritten when Todoist changes. |
| **Reads and the single write are separate paths.** | Ordinary separation of concerns. |

### What v0.1 must NOT contain

Every one of these fails the test — it would only exist for a feature that does not:

- A `TodoistWriting` protocol, or any method named `create`, `update`, `move` or `comment`, however
  it is stubbed or documented.
- A pending-changes queue, an outbox, a dirty flag, a `syncedAt` used for anything but cache freshness.
- Conflict-resolution machinery, merge policy, or last-writer-wins bookkeeping.
- Any locally mutable task field. The cache is read-only to the app.
- Weakening or removing the no-writes hook "so it is easier later".

### The honest part

**Nothing done now makes bi-directional sync easy later.** It is a hard problem in its own right —
conflict resolution, offline queues, deletion semantics, idempotent retries, and deciding what wins
when the same task changed in both places. No amount of foresight in v0.1 removes that work.

What v0.1 *can* do is avoid making it **harder**, and the way it does that is by accumulating no local
state that would later have to be reconciled. A v0.1 that invented its own task ordering, or let you
rename a cached task, would leave a v1.1 sync facing a divergence it did not create. This one will not.

### A local task model is not forbidden forever — it is forbidden *now*

Clarified by the owner on 2026-08-23: *"local task model will happen eventually as a bidirectional
work; however, that will happen when we can work on v1.5."*

This is worth stating because it changes what the v0.1 fence *means*. It is not a claim that a local
model is a bad idea — bi-directional sync will very likely need one, since reconciling two systems
requires somewhere to hold "what we think Todoist looks like" and "what we have changed since". That
is a real design and it belongs in v1.5, designed on purpose, with conflict rules written down.

What the fence prevents is a local model arriving **by accident, one reasonable field at a time**,
before anyone has decided what it is for. A due date added so the plan can sort by urgency. A priority
after it. A completion flag so finished items grey out. Each defensible; the destination is a second
task model nobody designed, with no conflict rules, that a v1.5 sync would have to reconcile against
Todoist without ever having agreed what wins.

So the rule for v0.1 is unchanged and the reasoning is now sharper: **the cache mirrors, the plan
references, and neither invents.** When v1.5 builds a real local model it starts from a clean
divergence-free base and gets to choose its own shape — rather than inheriting one that accumulated
while nobody was looking.

### The no-capture rule is what v1.5 is really deciding

This has now come up three times in different clothes: *"plan my pomodoros with Todoist or the
ZenTomato"*, *"a local task model will happen eventually"*, and *"put what's needed or unfinished in
Todoist — or, if the moment is right, ZenTomato."*

It is worth naming that these are all **one decision**, because they will otherwise be re-litigated
one at a time. Writing a task to Todoist from ZenTomato *is* capture. The no-capture rule and the
bi-directional sync plan are the same question seen from two sides, and v1.5 is where both are
answered together or neither is.

**Nothing changes for v0.1.** `CLAUDE.md` calls no-capture *"a standing rule from the owner's
productivity system, not a feature gap"*, and it is enforced by a hook. That holds until it is
deliberately replaced — not eroded by a search box that offers to create what you typed, or a plan
item that quietly grows a title you can edit.

What v1.5 inherits from holding the line now is a clean starting point: an app that has never invented
a task, so the first one it ever writes is one somebody designed on purpose.

### One consequence to flag now

Expanding writes makes **D9** sharper, not softer. The Todoist client secret is embedded in the app;
today it can only ever complete a task. A build that can create, edit and delete on the user's behalf
with a published secret is a materially different risk. **D9 should be decided before write scope
grows, not after.**

---

## D17 — A session plan: several Todoist items, in the order you will work them

**Ratified 2026-08-23**, from the owner's use case: *"I want to select a project AND some
non-in-project tasks and break them down."*

**Currently:** `SPEC.md` line 16 — *"A pomodoro is attached to exactly one Todoist task (or, if no
task is chosen, to a project)."*
**Proposed:** keep that sentence — it stays true of every individual pomodoro — and add:

> Before a sprint, the user may build a **session plan**: an ordered list of Todoist tasks and
> projects, drawn from the cache, which the timer works through. Each pomodoro attaches to the plan's
> current item, so the one-task-per-pomodoro rule is unchanged. A plan creates nothing and writes
> nothing.

**Why it belongs in v0.1.** Choosing what to work on is a planning act, and doing it eight times an
afternoon at the start of each block is the wrong moment for it — you are trying to begin, not decide.
Deciding once, up front, is what makes the timer something you run rather than something you operate.
"Breaking them down" happens in Todoist, which is where task-shaping belongs.

### The fence, which matters more than the feature

An ordered list of tasks is one bad decision away from being exactly the local task model D16 and
`CLAUDE.md` forbid. So, precisely:

**A plan item stores two things: a Todoist id, and a title snapshot for display.** Nothing else.

It does **not** store, and must never gain: task content, notes, due dates, priority, labels, parent
or child links, completion state, or any editable field. It defines no hierarchy — a plan is flat,
even when it contains a project and tasks from inside it. It is a **queue of references**, in the
sense a playlist is a queue of references and not a music library.

The plan is replaced when a new one is made. It is not history: what actually happened is already
recorded on `PomodoroSession`, and a plan that outlived its session would be a second, competing
account of the day.

**The test from D16 applies here too.** A plan item with a field that is nil today and meaningful
after sync lands is preparation, and fails.

### Ordering, and what happens when reality diverges

The order is the user's, set when the plan is built. The timer takes the next item at each block.

A planned task may be completed in Todoist, renamed, or deleted between planning and working it. The
plan does not chase those changes: the id stops resolving, the item shows its snapshot title with a
note that it is gone, and it can be skipped over. **The plan is a record of intent, and intent is not
invalidated by the world moving.** This is also why the snapshot exists rather than a live lookup.

### Where it lands

**F3**, which already builds the picker and the cache. The picker gains multi-select and an ordered
list; the attach step takes the plan's current item instead of a single chosen task. No new feature
gate — but F3's own gate does not pass until this fence is demonstrably held.

---

## D18 — Todoist authenticates with a personal API token. D9 is resolved.

**Ratified 2026-08-23, at the F3 gate.**

**Currently:** `SPEC.md` F3 — *"OAuth sign-in."*
**Proposed:** *"Sign in with a Todoist personal API token, entered once and stored in Keychain."*

This settles **D9**. Todoist's OAuth has no PKCE, so the code-for-token exchange requires the client
secret; a public client has nowhere safe to keep it, and neither `.env` nor `.xcconfig` changed that —
both keep it out of git, neither keeps it out of the `.app` bundle where `Info.plist` is plain text.

Two things said since D9 was raised made the answer forced rather than balanced. The app **will ship**,
and it will eventually **write** to Todoist (D16). A published secret that can only complete a task is
one risk; a published secret on a build that can create, edit and delete on the user's behalf is a
materially different one, and it would have arrived quietly along with the write scope.

**A personal token has no client secret at all.** There is nothing in the binary to extract, because
the credential is the user's own and never leaves their Keychain.

### What this deletes

| | |
|---|---|
| `TODOIST_CLIENT_ID`, `TODOIST_CLIENT_SECRET` | No longer needed. Removed from `Config/Secrets.example.xcconfig`. |
| The OAuth callback URL scheme | No `CFBundleURLTypes`, no custom scheme to register. |
| `ASWebAuthenticationSession`, the `state` CSRF guard, the token-exchange request | None of it exists. |
| **C3** — register an OAuth app in the Todoist developer console | **No longer required.** |
| The "acceptable only because never distributed" caveat throughout the docs | Gone. The build is shippable as it stands. |

Less code, fewer failure modes, one less credential in the world, and a chore removed.

### The cost, stated honestly

**First run is worse.** Instead of tapping *Sign in with Todoist*, the user opens Todoist's settings,
finds Integrations, copies a long string, and pastes it in. That is a real regression in polish and it
lands on the very first screen anybody sees.

Two mitigations, and no pretending it is solved: the screen gives the exact path in Todoist rather than
saying "get a token", and it is a **once ever** action, not once per launch.

### The one thing to be careful about

The token field is a **text field on the first screen of an app with a standing no-capture rule**. It
accepts a credential, not a task; it creates nothing and reaches nothing but Keychain. But it is
exactly the shape the rule forbids, so it must be unmistakably a credential field — its label, its
placeholder, its keyboard, and its neighbours all saying so. A reviewer should never have to think
about whether it is a way to enter a task.

### Consequence for the future

This is also the shape bi-directional sync wants. Each user's token is their own, scoped to their own
account, revocable by them from Todoist's settings without touching the app. There is no shared
credential to rotate, and no single secret whose exposure affects every install.

---

## D19 — Three decisions taken at the F4 gate

**Ratified 2026-08-23.**

### 1. Switching music on means ZenTomato handles the audio

If something else is already playing when a focus block starts with music on, ZenTomato takes over
with the chosen playlist. When the sprint ends it stops and leaves the system player alone.

**Why not "leave what's playing".** Because then the toggle sometimes does nothing, and whether it
worked depends on something happening in another app. A control that silently no-ops is one you stop
trusting — and you would have to remember what else was playing to predict what it does.

### 2. No subscription, or authorization denied → the toggle dims and the timer is untouched

Music is an accessory to this app, not the point. Every music failure degrades to a **silent working
timer**, never a broken one, with one plain line saying why.

**This is deliberately the opposite of F2's alarm permission**, where denial is blocking. The
difference is whether the permission *is* the feature: a Pomodoro timer that cannot tell you a block
ended has no working state to degrade into, whereas one that is merely quiet works fine. Same app,
opposite handling, and the reason should be legible in both places.

### 3. The skip button appears only while music is actually playing — in reserved space

Skip is visible during work blocks when something is playing, and absent during breaks when it is
paused and skipping would mean nothing. Nothing on screen offers a control that does nothing.

**This runs straight into a ratified rule and must not break it.** The countdown moves exactly once in
a whole cycle. A control that appears and disappears at every block boundary is precisely that
movement — and this is not hypothetical: F3 suppressed an affordance for this same reason and made an
entire feature unreachable, which took a device session to find.

**The resolution is to reserve the space rather than suppress the control.** The music row occupies a
fixed height for the whole cycle. The skip button appears and disappears *within* it; nothing above or
below moves, and the countdown never shifts by a pixel. The rule is honoured by layout rather than by
removing something the user needs.

That is the general answer to this tension, and it is worth stating once here: **when a rule about
movement conflicts with an affordance somebody needs, reserve the space.** Suppressing the affordance
was tried in F3 and the cost was the whole feature.
