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

## D9 — Shipping invalidates the F3 authentication decision

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
