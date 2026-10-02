# Proposed spec deltas — v0.1

`SPEC.md` is the contract and the agent never edits it. These are the deltas the plans depend on.
**Nothing in `docs/plans/F1.md`–`F7.md` may be built until you merge these into `SPEC.md` yourself.**

Each delta states the current spec text, the proposed text, and why.

---

## Index

Every delta in numeric order, because the file below is in the order decisions were *taken* —
`D6b` sits after `D8`, `D15` after `D20` — and renumbering is not an option: these ids are cited
by name across production code. Read the file in any order; find things here.

**Spec text?** `yes` means the delta proposes replacement wording for `SPEC.md` and therefore owes
an amendment. `docs/specs/AMENDMENT-BASELINE.txt` counts how many of those are still outstanding,
and `DeltaIntegrityTests` fails if that number grows.

| Delta | Status | Spec text? | Line | |
|---|---|---|---|---|
| **D1** | ratified | yes | 52 | Minimum iOS 18.0 → 26.0 |
| **D2** | ratified | yes | 65 | watchOS companion moves from Phase 2 into v0.1 as F7 |
| **D3** | ratified | yes | 90 | F2 alerting: AlarmKit primary, Live Activity promoted to requ… |
| **D4** | ratified | yes | 115 | End-of-pomodoro sequence made explicit |
| **D5** | ratified | — | 136 | Todoist API version (verification result, recorded for the file) |
| **D6** | REJECTED | yes | 161 | ~~Secrets live in `.env`~~ **REJECTED 2026-08-22. Superseded … |
| **D6b** | ratified | — | 299 | Build settings use Xcode's own `.xcconfig` mechanism |
| **D7** | ratified | — | 247 | Fence exception: the countdown numeral may state a raw point … |
| **D8** | ratified | — | 276 | A launch-screen colour set is added to the asset catalog |
| **D9** | RESOLVED | — | 331 | ~~Shipping invalidates the F3 authentication decision~~ **RES… |
| **D10** | ratified | — | 372 | F2 gains the settings screen |
| **D11** | ratified | — | 403 | Completed tasks are recorded and exported |
| **D12** | ratified | — | 429 | The Live Activity has no controls |
| **D13** | ratified | — | 462 | One exit, and it costs a sentence |
| **D14** | ratified | yes | 868 | Stopping mid-block shows one sheet, not two |
| **D15** | ratified | — | 915 | What the Rhodia export contains, and what stays out of the co… |
| **D16** | ratified | — | 571 | Designed so bi-directional sync is *possible* later, without … |
| **D17** | ratified | yes | 666 | A session plan: several Todoist items, in the order you will … |
| **D18** | ratified | yes | 721 | Todoist authenticates with a personal API token. D9 is resolved. |
| **D19** | ratified | — | 777 | Three decisions taken at the F4 gate |
| **D20** | ratified | yes | 821 | A Stop control for music, beside skip |
| **D21** | ratified | yes | 956 | A completion records whether the task was recurring |
| **D21b** | ratified | — | 992 | A task completed during a sprint does not come back into it |
| **D22** | ratified | — | 1049 | A block records which project it was for, and the export labe… |
| **D23** | ratified | — | 1132 | The music picker gets a search field; scope was never exceeded |
| **D24** | ratified | yes, applied | — | The alarm sound can be chosen; `AppSettings` gains a seventh field |
| **D25** | ratified | yes, applied | — | Music can be switched on during a break |
| **D26** | ratified | yes, applied | — | A ringing alarm can be silenced from inside the app |
| **D27** | ratified | yes, applied | — | Settings are read-only while a block is running |
| **D28** | ratified | yes, applied | — | The alert sound can be previewed from Settings |
| **D29** | ratified | yes, applied | — | A locked phone is somebody being there |
| **D30** | ratified | yes, pending | — | A watch-face complication |
| **D31** | ratified | no | — | C22 is struck; the licence question was already answered |
| **D32** | ratified | no | — | A shape is stored, in one file, outside SwiftData |
| **D33** | ratified | no | — | v1.5 admits two more units, and the order is restated |
| **D34** | ratified | no | — | The shape store speaks to a medium, to buy sync-readiness now |
| **D35** | ratified | **yes** | 5 | v1.5 ends at TestFlight; the September 13 date is struck |
| **D36** | ratified | no | — | Agent findings get a register of their own (`A`) |
| **D37** | ratified | no | — | The register's decisions are generated from 00-deltas.md |
| **D38** | ratified | no | — | The missing registers open now — `M`, `H`, `RR` |
| **D39** | ratified | no | — | F8 is halted at T3 and re-gated; `O37` is held |
| **D40** | ratified | no — v1.5 | — | D33 is applied; CLAUDE.md stops enumerating the order |
| **D41** | ratified | no | — | The amendment ratchet learns both spellings, and gains a second baseline |
| **D42** | ratified | no | — | The register is authoritative; OPEN.md is a view generated from it |
| **D43** | ratified | no | — | The shape screen lets you set the number of pomodoros (F8 re-gate) |
| **D44** | ratified | **yes — v1.5** | 1 | v1.5's amendment ledger moves inside the baseline |
| **D45** | **proposed** | no | — | A silent alarm and a haptic on the watch when the phone's sound is off |
| **D46** | **proposed** | no | — | The watch fires the same controls as the phone — contradicts D2 |
| **D47** | ~~rejected~~ | no | — | ~~The shape store in UserDefaults~~ — duplicate of D32 |
| **D48** | ratified | **yes** | 1 | The garden accumulates, and nothing gamified may be lost |
| **D49** | ratified | no | — | The shape's position gets one hour, not thirty-six — supersedes part of D32 |
| **D50** | ratified — **v2.0** | no | — | A push reminder about the work in progress — parked, **not built** |
| **D51** | ratified — **v1.5** | no | — | The export leaves as text *and* as a file, so a notes app takes it as a note |
| **D52** | ratified — **v1.5**, applied | **yes — v1.5** | 1 | `F2f` — the tomato fills by finished pomodoro; the cup stays on breaks |
| **D53** | ratified — **v2.0** | no | — | Notes apps tied in directly — parked, **not built** |
| **D54** | **proposed** | **yes — v1.5** | 1 | `F20` — a plan can be reordered |
| **D55** | ratified — **v1.5** | no | — | The Island tomato fills by elapsed time per the handoff — supersedes `D52`'s fill rule |
| **D56** | ratified — **v1.5**, applied | **yes — v1.5** | 1 | `F8b` — fitting writes the settings; editing a setting wins back |
| **D57** | ratified — **v1.5** | no | — | The tomato fills by finished pomodoro after all — supersedes `D55`, restores `D52` |
| **D58** | ratified — **v1.5** | yes | 2 | `F12` — themes: a fixed, audited set, chosen in Settings; the tomato and the Lock Screen follow it |

*60 deltas. Regenerate this table whenever one is added — `DeltaIntegrityTests`
asserts every delta appears here.*

---

## D1 — Minimum iOS 18.0 → 26.0

**Ratified 2026-08-21**, under *Ratified 2026-08-21 — D1–D6 accepted; build authorised starting at F1* below.

**Currently:** *Locked decisions* table — `Minimum iOS | 18.0 (adjust to Marty's phone at C2).`
**Proposed:** `Minimum iOS | 26.0. Minimum watchOS 26.0.`

**Why:** C2 is answered — the phone runs iOS 26. The spec anticipated this adjustment, so this is a
fill-in-the-blank rather than a change of intent. It is listed here because the table value is stale
and because two other deltas (D2, D3) are only possible at 26.0.

---

## D2 — watchOS companion moves from Phase 2 into v0.1 as F7

**Ratified 2026-08-21**, under *Ratified 2026-08-21 — D1–D6 accepted; build authorised starting at F1* below.

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

**Ratified 2026-08-21**, under *Ratified 2026-08-21 — D1–D6 accepted; build authorised starting at F1* below.

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

**Ratified 2026-08-21**, under *Ratified 2026-08-21 — D1–D6 accepted; build authorised starting at F1* below.

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

**Ratified 2026-08-21**, under *Ratified 2026-08-21 — D1–D6 accepted; build authorised starting at F1* below.

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

**Ratified 2026-08-22**, at the gate that authorised the feature it belongs to.

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

**Ratified 2026-08-22**, at the gate that authorised the feature it belongs to.

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

- **A tomato that fills as the block runs — on the TIMER SCREEN as well (v1.1).** The owner extended
  the Live Activity idea below to the app's own countdown: an outline of a tomato that fills over the
  focus block, rather than only a number.

  On the timer screen this is much cheaper than in the Live Activity, because the app is in front of
  you and redrawing is free — no update budget, no battery cost. The artwork already exists as vector
  paths in `Design/icon/make-icon.sh`; the work is factoring them out of that script into something a
  view can draw and stroke progressively.

  The one design question to settle at that gate: the ratified rule is that the numeral is the loudest
  thing on the screen and the countdown moves exactly once per cycle. A filling shape is continuous
  movement by definition, so it either replaces the numeral or has to be quiet enough not to compete
  with it. That is a real decision, not a detail.

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

---

## D20 — A Stop control for music, beside skip

**Ratified 2026-08-23**, from the device session.

**Currently:** `SPEC.md` line 27 — *"Skip-forward is the only control."*
**Proposed:** *"Skip-forward and stop are the only controls. Stop silences the music for the remainder
of the current block; the timer is unaffected and the next block starts music again."*

### The gap it fills

The music switch is deliberately locked while a block runs (music is chosen *before* a sprint). The
consequence, which only became visible on a real phone: **mid-block there was no way to silence music
at all.** The choices were to endure it, or to Stop the timer — which since D13 costs a written
sentence and abandons the pomodoro.

So a playlist that turns out to be wrong for the work in front of you could cost you the block. That
is a worse outcome than the one skip-only was protecting against.

### What Stop does, exactly

Silences the music. **The timer does not notice** — the block runs on, the alarm is untouched, and
nothing is recorded. The next block starts music again, because the silence is about *this* block and
not a change of mind about music.

That last part is what keeps it a transport control rather than a setting in disguise. A button that
looked like transport and quietly flipped a persistent switch would be two different kinds of thing
wearing one icon.

### The fence, and why it barely moves

**The playback protocol does not change.** It already has `pause()` — used on every break — and this
is the same verb reached from a different place. Nothing new becomes expressible: still no previous,
no seek, no scrub, no shuffle, no volume.

What widens is the *UI*, from one button to two. That is the honest cost, and the scope fence updates
from "skip is the only control" to "skip and stop are the only controls" — still checkable, still
greppable, and still excluding everything MusicKit offers on the same object.

### Why not simply unlock the toggle mid-sprint

It was the other candidate and it loses on two counts. The toggle lives in the music row rather than
beside the countdown, so it is a longer reach at the moment somebody is trying not to break
concentration. And the toggle means *"I use music"* whereas this means *"not this block"* — collapsing
them would make one control answer two questions.

---

## D14 — Stopping mid-block shows one sheet, not two

**Ratified 2026-08-23 at the F5 gate. Written down 2026-08-24 from its own implementation** — it was
decided, built, cited by name in five production files, and never recorded. D15's preamble names this
exact failure mode one section below; D15 was caught at the time and this was not. `C6` found it by
cross-checking every `D<n>` cited in the tree against the headings in this file, and `H1`'s
`DeltaIntegrityTests` now does that check on every run.

**Currently:** D13 requires a written reason to stop mid-block. F5 asks for one optional sentence per
distraction tap at the end of a block. Nothing said what happens when a block with taps in it is
stopped — both want the same instant.

**Proposed, and built:** **one sheet, not two back to back.** The required reason sits on top, under
the question, with no header of its own; the skippable sentences sit below a rule, under a header that
announces itself as a subordinate topic.

### Why

Two modal sheets in succession — at the moment somebody has decided to quit — is the surest way to
train them to dismiss both without reading. **The one that would get dismissed is the one that
matters:** the reason for stopping is the sentence the app charges for a stop, and the day somebody
least wants to write it, the day they bailed and would rather not think about why, is the day it is
worth the most.

### What it does not change

Both requirement levels stay exactly as their own deltas set them. Five signals separate them before a
word is typed, and every one is additive rather than corrective — position, resting height, outline
weight, one quiet word on the required field only, and the confirm button being visibly switched off.

**No red, no amber, no asterisk, no badge, no count of what is missing**, and nothing appears, moves
or changes colour if the switched-off button is tapped. Stopping is not an error and the person is not
in trouble.

### Where it lives

`ZenTomato/Views/StopReasonSheet.swift` is the merged sheet. `ZenTomato/Views/ReflectionFieldList.swift`
is the shared row list, a file of its own precisely so the two sheets that draw these rows are one
composition rather than two layouts that drift apart the first time either is touched.

A second consequence, recorded because the code cites D14 for it too: the end-of-block prompt is never
presented on top of the stop sheet. The offer is left unconsumed and is replaced when the next block
ends. See `TimerView.presentReflectionIfPossible()`, which excludes the stop sheet deliberately while
re-presenting after the settings and history sheets.

---

## D15 — What the Rhodia export contains, and what stays out of the counts

**Ratified 2026-08-22 at the F6 gate. Written down 2026-08-23** — it was decided, described in
conversation, and never recorded, which is how a decision becomes a thing nobody can check.

### The document reads top-down as a review

```
42 pomodoros · 17h 30m · 23 distractions (14 internal / 9 external)

## Days            when
## Projects        where the time went
## Completed       what came out of it          (D11)
## Distractions    what interrupted me, by task
## Stopped early   where I bailed, and why      (D13)
```

Not a data dump in five sections — an order of questions. *How did the fortnight go, when did I work,
on what, what came of it, what interrupted me, where did I give up.* Each answers the previous one's
"and then what".

**Stopped-early gets its own section rather than sitting among the distractions.** Stops are rarer and
heavier: a distraction is a moment, a stop is a decision. Buried in a list of taps they would
disappear, and you paid a written sentence for each one (D13) specifically so they would be worth
reading later.

### Abandoned blocks are excluded from every count

`42 pomodoros` keeps meaning **blocks you finished** — unchanged from what F2 ratified — while the
bail-outs stay fully visible in their own section with their reasons.

The alternative was putting the rate in the header (`42 pomodoros · 3 abandoned`). Rejected: it makes
the first thing you see every time a measure of how often you gave up, which is a different document
from the one this is meant to be.

**One rule, one implementation.** `StatsQuery` is the only thing that counts, and both the stats
screen and the exporter call it. Two counters that can disagree is how a number stops being trusted —
and this is the number the whole app exists to produce.

---

## D21 — A completion records whether the task was recurring

**Ratified 2026-08-23 at the F6 gate, from evidence F3's device session produced.**

**Currently:** `CompletedTaskRecord` stores a Todoist id, a title snapshot and a timestamp.
**Proposed:** it also stores whether the task was **recurring** at the moment it was closed.

### Why, and how we know

Closing a recurring Todoist task does not finish it — it advances it to the next occurrence. F3's
device run showed this precisely: *"Budget with YNAB by 7:30 AM"* appeared in Todoist's activity log
as completed at 16:48 **and came back as an active task** in the refresh at 16:52.

So without this, F6's Completed section lists the same title on eight of fourteen days and cannot tell
you why. Finishing a chapter and ticking off a daily habit are not the same achievement, and a reader
should not have to infer which is which from how often a line repeats.

The alternative was guessing from repetition — anything appearing more than once is "a habit". That is
a heuristic standing in for a fact Todoist already knows, and it is wrong for a task genuinely done
twice and for a habit done once in a quiet fortnight.

### Why this does not breach D16

D16 forbids fields that exist **only to serve a feature that does not**. Apply its own test: *would I
write this the same way if bi-directional sync were never coming?* Yes — this is for the export, and
F6 is the next feature. Nothing about it anticipates sync, and it would be equally right if v1.5 never
happened.

The line D16 draws is between design and preparation, not between "now" and "later".

### What it is not

It is **not** a recurrence rule, a schedule, a due date, or anything that could reconstruct one. One
boolean, captured at the moment of completion, describing what was true then. `CompletedTaskRecord`
stays append-only and stays a record of something this app did — not a task model.

## D21b — A task completed during a sprint does not come back into it

**Ratified 2026-08-23, alongside D21.** The owner: *"Budgeting with YNAB, picking 1–3 MITs — these
are recurring habits that I mostly keep. For version 1.0, making sure these do not repeat in a
pomodoro sprint is fine."*

A different problem from D21, in a different feature, and easy to conflate with it.

**The scenario.** You complete "Budget with YNAB" from the end-of-block sheet. Todoist does not finish
it — it advances it to tomorrow, and it is active again immediately. The next cache refresh sees it as
an open task, and nothing stops it being picked, or reappearing, later in the same sprint. You are
offered work you have already done this afternoon.

**The rule:** a task completed during a sprint is not offered again until that sprint ends. It stays
out of the picker and out of the plan.

**Deliberately not "if it recurs".** The rule holds for any task, recurring or not, which means it
needs no recurrence knowledge and cannot be wrong about a task it guessed at. A non-recurring task
completed mid-sprint would vanish from Todoist's active list anyway, so the rule costs nothing there
and is simply always true.

**Scope of "the sprint".** From the first block of a sprint to the long break that ends it. Stopping
clears it, because stopping ends the sprint. Nothing persists across app launches — this is about one
afternoon, not a history, and `CompletedTaskRecord` already holds the history.

### Where D21 lands

**F6**, which needs it, and which will retrofit F3's completion path to capture it. A retrofit rather
than a new gate, in the shape F1b and F1c already established.

**D21b lands in F6 too**, though it touches the plan rather than the export — one gate, because the
two are answers to the same observation and splitting them across features would leave the smaller,
more useful one waiting behind the larger.

**Verify at build time:** confirm what Todoist API v1 actually returns for recurrence on
`GET /tasks` — the field is expected to hang off `due`, but F3's plan learned the hard way that the
live docs beat an assumption, and a boolean read from the wrong key is silently always false.


---

## Parked for v1.1 — a Todoist label to mark a habit

The owner's idea, and better than inferring: *"maybe this is a solution of 'tag an item as a habit' in
Todoist so ZenTomato knows it's a habit and expects a recurring pattern."*

Reading a label breaks no rule — it is a read, and labels come back with the task. It is also more
honest than either alternative: D21 asks Todoist whether a task *recurs*, which is a good proxy for a
habit and not the same thing, and repetition-counting is a worse proxy still. A label is the person
saying which is which.

Parked rather than built because it needs the label maintained in Todoist to be worth anything, and
because D21 answers the v1.0 question without any setup at all. Worth revisiting once a real fortnight
has been read: if the recurrence proxy turns out to mislabel things, this is the fix.

---

## D22 — A block records which project it was for, and the export labels it live

**Proposed 2026-08-24. Ratified by the owner 2026-08-24, to be built as F3b.**

### The defect this starts from

`SessionPlanStore.attachment(for:)` writes `projectID: nil` and `projectTitle: nil` for every planned
**task**. Only a block attached to a whole *project* records project identity at all. So on real data
F6's `## Projects` section — the one that answers *"where did the time go"* — collapses into a single
`No project` heading with every task beneath it.

F6's golden shows a healthy `**Thesis** — 7 pomodoros` only because `StatsPeriodFixture` hand-sets the
title. The suite already records the truth: `aTaskAttachedBlockAsTheAppActuallyWritesItToday` asserts
`period.projects.map(\.title) == [nil]`. The defect is in what F3 records, not in what F6 counts, and
`SPEC.md` F6 requires "counts per task, project, day".

### Two parts, deliberately separable

**Part 1 — the plumbing. No delta needed; this is a defect fix.** `attachment(for:)` resolves the
task's project from the Todoist mirror already on the device — `CachedTask.projectID` is non-optional,
`CachedProject` holds the name — and writes **both** `projectID` and `projectTitle` onto the block.
`PomodoroSession` already has both fields, so **there is no schema change**, `SessionPlanItem` gains
nothing, and D17's fence stands untouched.

**Part 2 — the labelling rule. This is the delta.** The export groups by `projectID` and labels each
group from the mirror's *current* name, falling back to the recorded snapshot when the id no longer
resolves.

This part contradicts a ratified F6 rule, which is why it is written down rather than smuggled in as a
bug fix. `F6.md` states that task and project names come from the snapshot on the row and are **never
resolved live** — that is why F2 and F3 store them. D22 narrows that rule to: *task* titles remain
snapshot-only; *project* labels are resolved live with the snapshot as fallback. Task titles are not
touched, because a task is a thing you finish and its title at the time is the honest record of what
you did.

### Why group by id rather than by name

A rename part-way through a fortnight splits one project into two headings whose totals each
under-report, in a document whose entire purpose is aggregation. Grouping by id merges them. This is
provable from the code and needs no argument about how often anyone renames anything.

### Why the snapshot is still written, and never rewritten

Verified against Todoist's own OpenAPI document: `DELETE /projects/{project_id}` — *"Deletes a project
and all of its sections and tasks."* The id then dangles for ever and no endpoint will return a name
for it again. Without a snapshot, every block in a deleted project degrades permanently to `No
project` — today's defect arriving later by a different door. Clockify demonstrably has this failure:
deleted-project entries survive in reports but lose their name.

Archiving is *not* that case: `GET /api/v1/projects/archived` exists, so an archived project stays
resolvable **provided the mirror refresh reads both endpoints**. Building only against `/projects`
would silently lose the name the moment somebody tidies up.

### What the evidence does and does not support

Two researchers examined this. What is **verified from primary sources**: the deletion cascade above;
`GET /tasks` returns `project_id` and no project name, so a join is mandatory for anybody; the
personal/workspace union type has no discriminator and must be decoded permissively; cursor
pagination, `limit` max 200; 1000 partial and 100 full syncs per 15 minutes, which makes refreshing
the mirror effectively free. Among real integrations, mirror-plus-foreign-key (Everhour, TimeCamp,
Sunsama, Akiflow) is the dominant pattern; Everhour states live-renaming as the goal — *"Everhour
reports will always show the freshest data."* Toggl and Clockify match by *name* at capture time and
have a documented history of silently failing to attribute.

What is **not supported**, and was withdrawn: the original argument for snapshotting was that people
would be upset when old history silently renamed itself. A search found nobody complaining of that.
Absence of complaint is weak evidence either way for a silent behaviour — so D22 rests on the deletion
cascade and on rename-splitting, both checkable, and not on any claim about how often people rename.

**Not tested by anyone.** `scripts/check-todoist-facts.sh` settles three claims against a real
account: whether an archived project resolves by id, whether incremental sync returns `is_deleted`
tombstones or reports removal by silence, and whether old all-numeric task ids still resolve. If
tombstones turn out not to be returned, the mirror needs a seen-this-pass sweep rather than a flag.
None of the three changes Part 1.

### Not in scope

No user-visible setting. No product found anywhere exposes this choice, and a setting is an admission
the decision was not made. No `(was: Old Name)` annotation in v0.1 — it was considered and is parked;
it is a second name on the page and wants a real fortnight's reading before it earns the room.

---

## D23 — The music picker gets a search field. No spec text changes.

**Proposed 2026-08-25 by the owner. Ratified by the owner 2026-08-25, to be built as F4e.**

**No spec text. No amendment owed; the backlog stays at zero.**

### Where this came from

`O17`, raised when the owner went looking for the Apple Music licensing note and
**scrolled for over two minutes** to reach the end of the picker. F4c moved that
note into Settings, which answered the licensing half. This is the other half:
the picker itself is unusable on a real library.

The agent filed `O17` saying a search field was "new functionality rather than a
rearrangement, so it wants a delta argued rather than assumed." The owner argued
it:

> The app is built to play playlists for concentration. If it takes multiple
> seconds to find a track, we're likely to get distracted. A search bar for music
> is a bare minimum here, which is the point of the limited feature set for v1.

### Why this delta proposes **no change to `SPEC.md`**

That argument is not a request to widen the spec — it is a reading of what the
spec already says, and on inspection the spec agrees.

`SPEC.md` line 25: *"User picks an existing playlist or song from their library."*
Line 41, F4: *"library playlist/song picker."* **The contract specifies that you
pick and from what. It says nothing about how the picker is navigated**, because
navigating a list is not a decision a contract needs to record.

So a search field is not a feature added beside the picker; it is the picker
meeting the requirement already written down. A picker that takes two minutes to
find a playlist has not satisfied *"user picks an existing playlist"* in any sense
the owner can use.

And the harm is specific rather than aesthetic. This app exists to protect
attention. **A two-minute hunt immediately before a focus block is a distraction
manufactured by the tool built to prevent it** — the same shape as the watch-tap
latency in `F7`, which inflated the distraction log it existed to keep.

This delta is therefore recorded for the file rather than to change the contract:
it exists because `O17` said one was owed, and the answer is that the scope was
never exceeded. **Spec text: none. No amendment owed, and the backlog stays at
zero.**

### What is being ratified, then

The classification, and one boundary that follows from it:

**Search filters what is already loaded. It does not query Apple Music.** The
picker holds the whole library in memory already and pages it into the list on
scroll — that paging is precisely why the scroll never ended. Filtering rows that
are already there needs no MusicKit request, no network, no model, and no cache.
A search that hits the service would be new machinery and is **not** in this.

**Nothing here searches the catalogue.** Only the user's own library, which is all
`SPEC.md` permits: *"an existing playlist or song from their library."*

### Rejected alternatives

**A–Z index rail.** Cheaper, but sorts one dimension of a problem that is not
alphabetical — people remember a word from the middle of a playlist name.

**Recently played at the top.** Solves the common case and abandons the rest, and
"recent" is state this app would have to keep. `D16` says no.

---

## D24 — The alarm sound can be chosen. `AppSettings` gains a seventh field.

**Proposed 2026-08-26. Ratified by the owner 2026-08-27, and `A9` applied to
`SPEC.md` the same day at the owner's explicit instruction**, so the
outstanding-amendment count never left zero.

**The agent made that edit, which `conventions.md` ordinarily forbids.** It was
transcription rather than authorship: the replacement text was written verbatim in
`A9` before the owner ratified it, and the owner directed the change. The rule
exists to stop the contract moving under the agent's hand unilaterally, and it did
not.

**The owner is sourcing the candidates.** The agent's job is the mechanism, the
fence, and the attribution — not the taste.

### Where this came from

The first real sprint on a shipped build. The owner:

> the default alarm sucks, and will be quite jarring to folks using an app with
> Zen in the name.

The naming argument is the strong one. This app makes exactly one sound, at the
one moment it speaks, and that sound is currently a klaxon chosen by iOS.

### What the framework allows, checked in the SDK

`AlarmKit` takes `ActivityKit.AlertConfiguration.AlertSound`, which has **exactly
two members**:

```swift
public static var `default`: AlertSound
public static func named(_ name: String) -> AlertSound
```

`.named(_:)` resolves to **a file in this app's bundle**. iOS's ringtone and
alert-tone library is not reachable from an app, so *"use the iOS sounds"* is not
available and a system-sound picker cannot be built.

The mechanism is already proven here: `Silence.caf` ships and works, and is what
the sound-off setting rests on.

### Spec text

**`SPEC.md` currently says**, in the settings row:

> Sound on/off.

**Proposed:**

> Sound on/off, and which sound. A short list of bundled alert sounds; the
> default remains the system alert.

### The fence this moves, and why it must move deliberately

`PolishFenceTests` pins `AppSettings` at **six fields**, and that bound was
mutation-tested with *an alarm-sound picker specifically* as the hypothetical
seventh. It was put there to stop a settings screen growing one reasonable-looking
field at a time. Moving it is one line in a diff the owner reads, which is the
whole design — but it is not a bound to nudge past.

### The part most likely to go wrong quietly: **licensing**

**Apple's system sounds cannot be extracted and redistributed.** They are not
licensed for it and lifting them from the OS is not an option.

**And "GPL-3.0 sounds" is the wrong search.** The GPL is a *software* licence.
Applied to audio it is legal but vanishingly rare, and looking for GPL-licensed
alert tones will return almost nothing. What is actually needed is audio whose
licence permits redistribution inside a GPL-3.0 repository:

- **CC0 / public domain** — the right default. No attribution burden, no
  compatibility question, nothing to get wrong later.
- **CC-BY** — workable, but every sound then owes an attribution line that has to
  ship with the app and survive every refactor.
- **Anything non-commercial or no-derivatives** — unusable. The repo is public and
  the App Store is a commercial channel.

Original sounds commissioned or made for the project are the other clean answer,
and sidestep the question entirely.

**This is `C10`'s business too**, since it is the first time this repository would
carry third-party creative work.

### Attribution is required, and it is enforceable

The owner's ruling, 2026-08-27: **every alert sound is attributed, with a link.**

That is stricter than the licences demand — CC0 requires no attribution at all —
and it is the right call regardless: the person who made the sound is credited
whether or not a licence compels it, and a link is what makes the credit checkable
rather than decorative.

**It is also the rare licensing obligation a test can hold.** Attribution rots the
usual way: a sound is swapped, a file is renamed, a refactor moves a list, and the
credit quietly stops matching the thing it credits. So:

- every bundled sound file has exactly one attribution entry
- every entry carries a **name** and a **URL**
- the counts match in both directions — a sound with no credit fails, and a credit
  with no sound fails

That last one matters more than it looks: a stale entry crediting a sound that was
removed is a false statement about someone's work.

**Where it is shown** is the About screen, which `C10` gates. Until that exists the
attribution still ships — a list nobody can reach is not attribution, so if About
is not ready, the sound picker carries it.

---

## D25 — Music can be switched on during a break

**Proposed 2026-08-26. Ratified by the owner 2026-08-27, and `A8` applied to
`SPEC.md` the same day at the owner's explicit instruction.**

The two-step dance this heading described — ratify, then paste, then stamp — was
collapsed into one commit by the owner directing the agent to make the edit. The
count never left zero, which was the point of the dance.

**Recorded because the agent editing `SPEC.md` is ordinarily forbidden.** It was
transcription, not authorship: `A8` held the replacement text verbatim before
ratification, and the owner gave the instruction. `conventions.md`'s rule guards
against the contract moving unilaterally; nothing here was unilateral.

### Where this came from

Reported as a regression, and it is not one — both halves of the behaviour date
from F4's first commit `e107dea` and have never changed. The owner, refining it
after a second sprint:

> no music during a break is ok, and changing music during a sprint is limited
> (turn off, fast forward), **I should be able to turn on music during a Short
> Break**

So the ask is narrow, and narrower than the original report: **not** automatic
resume, **not** full transport controls during a break. One control, re-enabled,
in one place.

### The current behaviour, and why tapping does nothing

`MusicRowModel` sets `isTogglable: false` the moment any block is running. The
switch is therefore *disabled* during a break rather than broken — which is why
tapping it produces no effect rather than a wrong one.

### Spec text

**`SPEC.md` currently says:**

> | Music during breaks | Pauses. Resumes at the next pomodoro. |

**Proposed:**

> | Music during breaks | Pauses, and can be switched back on by hand. Resumes by
> itself at the next pomodoro. |

### What stays fixed

The rest of `D19.3` and the row's design are untouched: no skip and no stop during
a break, because there is nothing to skip when nothing is playing, and the row's
height is still reserved so nothing moves at a block boundary.

**This delta owes an amendment, and that has a consequence.** The sentence above
is live spec text, so ratifying `D25` without applying the replacement the same
day turns `DeltaIntegrityTests` red — the outstanding-amendment baseline is
pinned at **zero**, and a red test blocks every merge under branch protection.
Ratify and amend together, or neither.

## D26 — A ringing alarm can be silenced from inside the app

**Proposed 2026-08-28. Ratified by the owner 2026-08-28**, and `A10` applied to
`SPEC.md` the same day at the owner's instruction — the `D24`/`A9` precedent, so
the outstanding-amendment count never leaves zero. Defect-adjacent, but it adds a
control, so it is a delta rather than a fix proceeding under `D22`.

**The owner answered the open question below: silence and advance, like Dismiss.**

**What was reported, and what it actually was.** The owner tried to stop a ringing
alarm in a short break and could not. The first reading was a Stop-button problem;
the owner corrected it:

> This wasn't a stop the timer bug. stop the alarm bug.

**The gap is certain and does not depend on reproducing anything.**
`cancelAlarm()` is reachable from two engine paths only — a *confirmed* Stop, and
one internal path — and **no view in this app observes `Alarm.State.alerting`**.
The only control that ends a ringing alarm is the Dismiss button on the alert iOS
draws. If that alert is missed, swiped, or never seen — the app was already in the
foreground, say — the sound has no off switch anywhere in ZenPom.

**The app's own Stop button is not that switch, and must not become it.** Stop
opens the reason sheet and ends the *sprint*; `SPEC.md` prices that exit
deliberately. Silencing an alarm is a different act with a different consequence,
and giving one button both meanings is how the `F2b` arc produced four fixes in a
row.

### Proposed spec text

Add to the *Alarm* row:

> While the alarm is ringing, the timer screen shows a single control that
> silences it. Silencing the alarm does not end the block, the break or the
> sprint.

**Answered 2026-08-28: silence and advance, like Dismiss.** The control is the
system alert's Dismiss button, drawn where the person is actually looking. Two
buttons that stop the same noise and then leave the app in two different states
would be worse than the one that is hard to find.

**What that means precisely**, because "like Dismiss" has to name a path rather
than a feeling: it runs the same route `DismissBlockIntent` runs. The block is
recorded as **completed**, not abandoned; the reflection prompt appears if the
block earned one; and the next block auto-starts if auto-start is on and stays
queued if it is not. It is not `stop(reason:)` and it never asks why.

**Currently:** *Block ends fire through AlarmKit, so the alert sounds through
silent mode and through an active Focus.*

## D27 — Settings are read-only while a block is running

**Proposed 2026-08-28 at the owner's direction. Ratified by the owner
2026-08-28**, `A11` applied the same day.

**Currently:** *Work length, short break, long break, pomodoros-per-sprint, sound
on/off, which alert sound, auto-start next block on/off. Nothing else.*

> I was able to change the sounds from small bell to struck bell in a sprint. both
> sound good --- but i shouldn't be able to do that.

**The engine was correct.** Settings are frozen into `TimerSettingsSnapshot` at
block start and nowhere else, so the change landed on the *next* block — which is
exactly what the screen already promises: *"A block is running. Changes take
effect when it ends, not now."*

**So this changes ratified behaviour rather than fixing a defect**, and the owner
chose the wider of the two options: **lock the whole screen, not just the sound
row.** One rule beats a screen where one row behaves differently from the four
above it for a reason nobody can see.

### Proposed spec text

Add to the *Timer customization* row:

> While a block is running these are read-only. The screen says so.

**What stays editable, and why it is not an exception.** Todoist sign-in and the
music selection are not timer settings — they are not in `AppSettings`, are not
snapshotted, and `SPEC.md` gives music its own row saying it may be toggled during
a sprint. `D27` covers the customization row only.

**The running-block note changes wording** from *"Changes take effect when it ends,
not now"* to something that says the rows are locked. The old sentence would be a
lie about a screen nobody can edit.

## D28 — The alert sound can be previewed from Settings

**Proposed 2026-08-28 at the owner's direction. Ratified by the owner
2026-08-28**, `A12` applied the same day.

**Currently:** *Work length, short break, long break, pomodoros-per-sprint, sound
on/off, which alert sound, auto-start next block on/off. Nothing else.*

`F2c.md` ruled a preview out, and the reason it gave still stands:

> playing an alarm inside Settings is a new audio path, `AlarmKit` does not offer
> it, and `AVAudioPlayer` for it would be a second sound system.

**The owner has now hit the gap that reason costs**: three sounds in a picker, and
no way to hear one without running a block to its end. Choosing between sounds you
cannot hear is not a choice.

### What it actually costs, stated before it is agreed to

**A second audio system, and that is the whole price.** `MusicCoordinator` owns
audio in this app today. A preview means `AVAudioPlayer` or `AVAudioEngine`
playing a bundled file, which brings:

- **An `AVAudioSession` category decision.** Preview must not stop the person's
  music, and must not be silenced by the ringer switch — an alert preview that is
  inaudible on a silent phone teaches the wrong thing about a sound that *will*
  be audible when it matters.
- **Interaction with a running block.** `D27` would make the picker read-only
  during a block, which removes this case entirely — the two deltas are cleaner
  together than either is alone.
- **Interaction with music.** Previewing while a playlist plays must duck or
  ignore, and either is a decision rather than a default.
- **A stop rule.** A preview that outlives the screen it was started from is a
  sound with no off switch, which is `D26`'s defect arriving by a second door.

### Proposed spec text

Add to the *Timer customization* row:

> Each alert sound can be played once from the settings screen before it is
> chosen.

**Scope note.** Preview plays the bundled file. It cannot preview `Default`, which
is iOS's own alert sound and is not a file this app holds — that row previews
nothing and the screen has to say so rather than appear broken.

## D29 — A locked phone is somebody being there

**Proposed 2026-08-28. Ratified by the owner 2026-08-28 — *"d29 the small one is
ratified"*** — and `A13` applied to `SPEC.md` the same day, on the `D24`/`A9`
precedent, so the amendment ratchet never leaves zero.

**The small version, explicitly.** The prompt is offered on reconciliation when
the wake was prompt. Nothing is persisted and no schema changes.

**A correction to this delta's own scope, 2026-08-28.** The paragraph here first
said a prompt "does not survive the app being *terminated* rather than
suspended". **That is not what the code does, and this branch's own test
disproves it**: `LockedPhoneReflectionTests` builds a *fresh* `TimerEngine` on a
fresh `ModelContext` — a relaunch — and the prompt is offered. It works because
`TimerEngine.init` calls `rehydrateDistractions()`, rebuilding the taps from the
store, and `synchronize()` then publishes from the rebuilt list. The taps were
always persisted; the offer is derived from them rather than held in memory.

The case that genuinely is not covered is narrower: **termination after the block
has already been reconciled and the offer published**. Then the block is finished
in the store, `synchronize()` has nothing left to reconcile, and the prompt is
gone.

Recorded as a correction rather than an edit, because a ratified delta making a
false statement about its own scope is the same failure this branch has now
written five times.

**What was reported**, running `O29` on build `202608281343`:

> with the screen locked, all fired except the sheet. ther were 3 external
> breaks and i was unable to capture it.

**This was not a bug in the mechanical sense. It was a decision, and the decision
was wrong about the owner.** `TimerEngine.synchronize()` ended a block that
finished while the app was away and passed `mayPromptForReflection: false`, with
this reasoning (past tense throughout: the delta is built):

> Still no reflection prompt, whatever the gap: the taps are recorded and stay
> recorded, and what is refused is a sheet nobody was there to fill in.

**Nobody was there is the assumption, and a locked phone is the counter-example.**
The ordinary way to run a pomodoro is to put the phone face down or in a pocket
and work. The alarm fires, the person picks it up — they were present for the
whole block, they were interrupted three times, and the app has their three taps
and never asks about them. `SPEC.md` says the app *"prompts for one sentence per
tap"*, and in the most common way of using it, it does not.

**The taps are not lost.** They are recorded and appear in the export and the
stats. What is lost is the sentence, which is the part the log exists for.

### What the code already knows

`synchronize()` computes `wakeWasPrompt` — whether the gap since the block ended is
inside the block's own length — and already uses it to decide auto-start. That is
the same question this needs: *did somebody come back to this promptly, or did the
phone sit overnight?* A fourteen-hour gap is nobody being there; two minutes is
somebody picking up a ringing phone.

### Proposed spec text

**Currently:** *At the end of that pomodoro the app prompts for one sentence per
tap (skippable).*

Replace with:

> At the end of that pomodoro the app prompts for one sentence per tap
> (skippable). If the phone was locked or the app was away, the prompt waits and
> appears when it is next opened — unless so long has passed that nobody could
> still be in that block, in which case the taps stay recorded and the prompt is
> dropped.

### The part that needs deciding, not assuming

**~~`pendingReflection` is in memory only. If the app was terminated rather than
suspended, there is nothing to wait.~~** **Struck 2026-08-28 — this was wrong**,
and it is the sentence the correction at the top of this delta is about. The taps
are persisted; `TimerEngine.init` rehydrates them and `synchronize()` derives the
offer from the rebuilt list, so a relaunch does not lose it. Left visible rather
than deleted, because it is what the owner was told when they ratified.

**Two versions of this delta were possible and the owner picked:**

- **The small one — chosen.** Offer the prompt on reconciliation when
  `wakeWasPrompt`. Nothing persisted, no schema change.
- **The larger one — not taken.** Persist the *published offer* so it survives a
  relaunch that happens after the block was already reconciled. Costs a migration,
  and `O2` has only just been answered once.

**What the small version does not cover** is stated in the correction above, and
it is narrower than this section first claimed: the offer survives a relaunch,
because the taps are persisted and the offer is derived from them. What is lost is
a termination *after* the block has already been reconciled and the offer
published.

## D30 — A watch-face complication

**Proposed 2026-08-28. Ratified by the owner 2026-09-24.** Requested by the owner:

> also, make sure zenpom can be installed as a complication on a ultra watch face

**RATIFIED AS WRITTEN, which means the complication below and not more than it.** The proposed spec
text at the end of this row says *"It starts nothing and captures nothing"*, and that sentence is the
ratified one. The owner asked in the same breath for a complication *"that lets the watch app fire
off all the same controls as the iOS app"*; that is a different and much larger change, it
contradicts ratified `D2` in three places, and it is carried separately as `D46` rather than folded
in here. Ratifying a row silently wider than its own text is how a scope fence stops meaning
anything.

**It cannot be made sure of, because it does not exist and the contract forbids
it.** Stating that plainly rather than quietly building it:

- **`SPEC.md` line 58 excludes it by name**, in the *Out of scope* list: *"widgets
  beyond the Lock Screen Live Activity"*.
- **`F7.md` declined it on purpose**, citing that line: *"No complication and no
  watch-face widget… and `D2` does not change that."* The same list warns that
  *"scope gravity is strongest here — a watch app invites a complication, a start
  button, a task picker"*.
- **Nothing in the tree builds one.** The only `WidgetKit` code is
  `ZenTomatoActivity`, an `ActivityConfiguration` — a Live Activity, embedded in
  the iOS app. A complication is a separate watchOS widget extension with
  `.accessoryCircular`, `.accessoryCorner`, `.accessoryRectangular` and
  `.accessoryInline` families. That target does not exist.

So this is a build, not a check.

### What it would actually cost

**A new target**, embedded in the watch app, with its own Info.plist,
provisioning and bundle id — and `project.yml` records **three separate silent
install failures** on the watch already: a missing embed, missing provisioning,
and an asset catalogue the target could not see. None of the three failed the
build; each shipped an app that looked installed and was wrong.

**A timeline**, not a live view. A complication is refreshed by WidgetKit on a
budget, not driven by the app. Drawing a countdown means supplying a
`TimelineEntry` per minute, or using a text style that counts down on its own —
the second is right, and it is the same `Text(_:style:)` the watch app already
uses.

**A data path that does not exist yet.** `WatchLink` carries taps *to* the phone.
A complication needs the block's kind and end time on the watch, in a place a
widget extension can read — an App Group, which nothing in this project uses.

**Four families, drawn four ways.** The Ultra's faces take corner and circular
complications the other watches do not, so "works on an Ultra face" is a
per-family design question, not one layout.

### Proposed spec text

**Currently:** *…widgets beyond the Lock Screen Live Activity…*

Replace with:

> …widgets beyond the Lock Screen Live Activity and a watch-face complication
> showing the running block…

And add to `F7`:

> A complication on the watch face shows the current block and its remaining
> time, and opens the app when tapped. It starts nothing and captures nothing.

### The recommendation, which is not to do it now

**The hard stop is September 13, 2026 — sixteen days.** Outstanding right now are
two unrun device checks (`O29`'s second half, `O30`), one proposed delta the owner
has not ruled on (`D29`, which is a lost reflection prompt in the ordinary
locked-phone case), and a branch carrying two features that has needed three
adversarial passes.

**`D29` is worth more than this.** It is the distraction log — the stated point of
the app — failing in the most common way of using it. A complication is a
convenience on a surface the spec has excluded from the start.

If the owner ratifies this anyway, it should be its own feature after the current
branch merges, and it should not be squeezed in beside `D29`.
## D31 — C22 is struck; the licence question was answered on 2026-08-27

**Proposed 2026-09-09. Ratified by the owner 2026-09-09.**

**Currently**, `docs/specs/zenpom-v1.5.md` lists `C22` — *"which licence the binaries carry"* — as
item 2 of v1.5, and states that `F11`, the About screen, is blocked on it.

**Both claims are false, and were false before the spec was written.**

`C18` settled the licence on 2026-08-27 and shipped it: **one licence, GPL-3.0-or-later**, plus a
non-enforcement pledge in `LICENSE-EXCEPTION.md` covering the one known conflict with the App Store
terms. There is no second licence and no unanswered question about what the binaries carry.

**The text is already inside the app.** `ZenTomato/App/AppLicence.swift` holds the GPL notice and the
App Store pledge as compile-time constants — deliberately constants rather than bundled files, so a
missing notice fails to compile instead of surprising somebody at runtime — and `LicenceFenceTests`
asserts the words are really there. The GPL requires the notice to travel *inside the binary*; that
requirement is met and tested.

**How the error got in.** `docs/plans/parked.md` records the About screen as *"blocked, and only partly
on effort … `C10` ruled dual licensing but has not yet settled which licence the binaries carry."*
That was true when written and was superseded the same week by `C18`. The v1.5 spec inherited the
sentence without checking it against the tree.

**This is the failure the immutable-spec rule exists to catch**, arriving from an unusual direction: not
a spec edited to match reality, but a spec that recorded a blocker which reality had already removed. A
claim was carried forward because it was written down, which is the thing `conventions.md` says
promotion is not.

**Therefore:**

1. **`C22` is struck.** It is not work, it is not a chore, and it has no consumer because it has no
   content. The v1.5 order becomes eleven items, not twelve.
2. **`F11` is unblocked.** What remains of the About screen is a surface that displays two constants
   that already exist and passes tests that already run, plus the bundled alert-sound attribution the
   owner ruled is required regardless of what the licences demand.
3. **`F11` keeps its place in the cheapest-first order** rather than moving up. It was ordered on its
   own size, not on `C22`'s position, and removing a blocker does not make a screen smaller.

**One documentation defect found alongside, not fixed here.** `docs/chores/C18.md`'s banner says *"no
`AppLicence` type exists in the app."* It does. The banner was written the day the MIT design was
superseded and was never revised when the type landed. Filed rather than fixed, because it is a
correction to a shipped chore's record and belongs with `O35`'s documentation list.

## D32 — A shape is stored, in one file, outside SwiftData

**Proposed 2026-09-09. Ratified by the owner 2026-09-09.**

**THE OUTSIDE-SYSTEM CLAIM IS NOW CONFIRMED BY SOMETHING THAT RAN — 2026-09-25.** This row rests on
*"`UserDefaults` survives an app update"*, and `docs/conventions.md` requires the confirming command
and its output on the row, with the evidence being the observable end state rather than the
documented behaviour. It was ratified without that, and `F8`'s fourth `BLOCKING` note has said so
since 2026-09-22. The check has now been run on the owner's own hardware:

```
Before:  Spare minutes = More rest        (default is Balanced)
         End with a long break = OFF      (default is ON)
         budget = 15                      (view state, never stored)

Installed build 202609251013 OVER the existing app — not a fresh install.

After:   Spare minutes = More rest        ← survived
         End with a long break = OFF      ← survived
         budget = 60                      ← reset, and correctly so
```

**Both stored fields survived and neither could have appeared by accident**: each was set to the
opposite of its default, so a wiped store would have shown Balanced and ON. The budget returning to
60 is not a partial wipe — `budgetMinutes` is `@State` on the sheet and was never written.

**So the store survives an update, and the alternative this row refused stays refused.** `TimerState`
columns would have meant a SwiftData migration over the store holding the distraction log. Owed by `F8-T2`, which cannot land until this is ratified or refused.

**Currently**, `SPEC.md`'s locked decisions say *"Data: Local only (SwiftData). Todoist token in
Keychain. No analytics, no accounts, no server."* Two stores are named and no third is.
`PolishFenceTests.noNewPersistentSurface` enforces that.

**The problem this answers.** `F8-T4` requires a shape to survive a block being abandoned and
relaunched, and to outlive the app being killed. Nothing in the ratified plan said where it lives —
the cross-plan review found it unowned with `F8` second in the build order.

**Proposed:** a shape is persisted as one small `Codable` value in `UserDefaults`, in exactly one
shipped file, and `noNewPersistentSurface` is amended to admit that file by name and nothing else.

**Why not the two obvious alternatives.** Both were refused for reasons that are about *this*
milestone rather than taste:

- **An eighth `AppSettings` column** contradicts Ruling B inside the same feature. Ruling B's whole
  protection is that running a shape never writes `AppSettings`; putting the running shape *in*
  `AppSettings` makes that fence carve out the one column it exists to watch. A fence with an
  exception for the thing it guards is not a fence. It also collides with `F12`, which moves the
  same property count from 7 to 8 for the theme — whichever lands first consumes the other's
  evidence.
- **A thirteenth `@Model`** destroys `F16`'s named mutation, which *is* the 12→13 move.

**The trade being bought.** A third store is a real cost and this delta is where it is paid rather
than discovered. The argument for paying it: a shape is one sprint's worth of intent, not history.
The history is already written block by block on the finished-block rows, and `SessionPlan`'s own doc
comment makes this exact argument for the neighbouring case — a stored thing that outlives its
session becomes a second, competing account of the same day.

**If refused:** `F8` pays a `TimerState` migration instead, and `F12` and `F16` must re-derive the
counts their mutations depend on.

## D33 — v1.5 admits two more units, and the order is restated

**Proposed 2026-09-09. Ratified by the owner 2026-09-09.** Owed because `docs/specs/zenpom-v1.5.md` is a ratified baseline and its
order table names eleven units.

**Currently**, that table reads: `C21`, `F8`, `F12`, `F13`, `F11`, `F14`, `F10`, `F9`, `F15`, `F16`,
`F17` — ten features and one chore.

**The problem this answers.** Two units were added at the owner's direction on 2026-09-09 and
neither is in the table. **No plan proposed this delta**: `F17` raised it and punted to `F18`'s gate,
`F18` ruled *"delta owed: none"*, and `F19` owes one for its undo only. The single change that is
unambiguously a change to a ratified baseline had no owner, which is why it is written here.

**Proposed:** the milestone becomes **thirteen units**, and the order becomes

> `C21` · `F8` · `F12` · `F13` · **`F19` search** · `F11` · `F14` · `F10` · **`F18`** · `F9` ·
> **`F19` undo** · `F15` · `F16` · `F17`

**`F18` — a watch-side App Intent.** It earns v1.5 on its own terms rather than as preparation:
`F17`'s complication cannot start a block without it, because a widget extension is a third process
and cannot drive the watch app's `WCSession`. `CLAUDE.md` forbids preparing for work outside the
milestone and `D16`'s test is whether it would be written the same way if the parked feature were
never coming. It would. That v2.0 inherits it is a consequence of building it properly, not a reason.

**`F19` — Todoist searched cleanly, and undoable.** Split, because its halves have different costs:
the search half owes nothing and ships early; the undo half owes its own delta and waits on `O12`'s
live-token run, which is what makes that delta ratifiable at all.

**Nothing already ordered moves relative to anything else.** Search is pulled forward because it is
the only piece in the batch that ships without ratifying anything, and the pacing constraint on this
project is review capacity rather than build time. `F18` sits after `F10` so that one seam is built,
then exercised by the cheap door before the expensive one — and its spike lands *before* `F17` is
scheduled, so a "no" there reshapes `F17-T5` at planning time rather than mid-build.

## D34 — The shape store speaks to a medium, to buy sync-readiness now

**Proposed 2026-09-10. Ratified by the owner 2026-09-10**, who directed it and chose this framing
over the alternative described below.

**Currently**, `PolishFenceTests.noNewProtocol` pins the protocol count at ten, and its doc comment
says why: *"The ten that exist are all seams for testing… Each was written because a test had to hand
the app a stand-in. An eleventh arriving during a polish pass would almost certainly be 'extracted
for testability' and mean 'made swappable for the sync engine' — which is the drift this fence exists
to catch, in its most plausible disguise."*

**This delta is that eleventh, and it is the disguised case with the disguise removed.**

**The honest reason.** No test needs a stand-in. `ShapeStore` is testable against a disposable
`UserDefaults` suite and most of its tests still run that way. The protocol exists because the owner
chose to buy **sync-readiness for v2.0 now** rather than refactor later. `CLAUDE.md` says of anything
outside the milestone: *do not build it, stub it, or prepare for it*, and `D16`'s test asks whether
this would be written the same way if the parked feature were never coming. **It would not.** That is
a rule the owner is entitled to override, and this row is the override, on the record.

**The alternative that was refused**, so it is not re-proposed: framing it as the eleventh testability
protocol. It reads as conventional and it is the exact wording the fence names. A future reader
finding an unused testability wrapper would be right to delete it; a future reader finding *this*
knows it is load-bearing for sync.

**What was built, and why the medium rather than the store.** `KeyValueMedium` — three operations,
`data(forKey:)`, `write(_:forKey:)`, `removeValue(forKey:)`. Abstracting `ShapeStore` itself would
have meant a second whole implementation for iCloud, duplicating the codec and the cursor.
Abstracting the **substrate** leaves `ShapeStore` as the single place that knows what a stored shape
is, and `NSUbiquitousKeyValueStore` — whose API is nearly identical to `UserDefaults` but which is
**not** a `UserDefaults`, and so cannot be passed where one is expected — conforms with the same
three-line shim.

**Deliberately minimal**: no generic `Any?` accessor. A wider protocol becomes the app's general
storage abstraction by gravity, which is a different decision nobody has made.

**The evidence this delta owes, and it is one test.** A protocol nothing but the original
implementation has ever been driven through is a claim, not an abstraction — every other shape-store
test would still pass with `UserDefaults` welded in. `InMemoryMedium` is a conformer sharing no code
with `UserDefaults`, and `theStoreWorksThroughAMediumThatIsNotUserDefaults` drives the whole round
trip through it. **If that test is deleted, this delta has no evidence left.**

**`noNewProtocol` moves from 10 to 11**, and no further. `NSUbiquitousKeyValueStore` is not added
here — conforming it would be building v2.0, which is the thing this delta is careful to admit it is
only *preparing* for.

## D35 — v1.5 ends at TestFlight, and the September 13 date is formally dead

**Proposed 2026-09-11. Ratified by the owner 2026-09-11**, in their own words: *"The end condition is
v1.5. We stop when v1.5 is released, approved, and sent via test flight."*

**This supersedes the stop condition in `docs/specs/zenpom-v1.5.md`**, which is a ratified baseline
and is therefore not edited — this row is the change, per `conventions.md`: *"a change to scope, order
or the stop condition is a `D<n>`."*

**Currently:** line 5 — `**Hard stop:** the day work resumes or **September 13, 2026**, whichever is
first. Unmerged work returns to backlog, no forensics.`
**Proposed:** `**Ends when:** v1.5 is released, approved, and sent via TestFlight (D35). Unmerged work
returns to backlog, no forensics.`

**The quoting style is load-bearing and was got wrong once here.** This block was first written as a
triple-backtick fenced code block, and `DeltaIntegrityTests.everyRatifiedSpecAmendmentIsApplied`
**passed** — because `fragments(of:)` reads single-backtick inline spans and `"quoted"` text and never
looks inside a fence. The amendment was genuinely outstanding and the instrument reported a clean
backlog, which its own baseline file calls *"the worst failure available to a test whose whole job is
to count what is outstanding."* That file already warns about this class in another form — `D18`'s full
stop against a semicolon. **A second way to be invisible is now on the record: the wrong kind of
backtick.**

### The two things it settles

**1. The stop condition.**

| | Was (`zenpom-v1.5.md`, ratified 2026-09-09) | Now |
|---|---|---|
| Condition | four consecutive fortnightly Rhodia reviews driven from zenpom's own export | **v1.5 released, approved, and sent via TestFlight** |
| Shape | a usage condition — roughly two months of real use | **a shipping event** |

**2. September 13, 2026 is dead, explicitly.** `SPEC.md:5` still reads *"Hard stop: the day work
resumes or September 13, 2026, whichever is first."* That date was anchored to an exam that was
cancelled. `zenpom-v1.5.md` replaced it with a condition but **no delta ever struck the v0.1 line**,
so for two days the two documents disagreed with nothing resolving them — and `CLAUDE.md`'s
tiebreaker says v0.1 wins until a `D<n>` says otherwise, which made the dead date authoritative by
default. **This is that `D<n>`.** Spec text is owed: `SPEC.md:5`.

### What it costs, recorded because the old condition was chosen on purpose

**The four-review condition was feature-independent, and this one is not.** Its own spec says it was
written that way because an earlier draft tied the stop to `F8` shipping, *"which made the milestone
hostage to its largest feature."* A TestFlight condition is hostage to the release pipeline instead —
`C9`'s runbook, `C26`'s App Store Connect record, and the portal work in `O40` all now sit between
v1.5 and its end.

**And it un-absorbs `O1`.** `zenpom-v1.5.md` states that the first of the four reviews *is* `O1` —
v0.1's outstanding *Done when* for `F6` — and calls the fact that **the log has never once been read
for its purpose** the single most important fact about this project's state. The old condition could
not be met without fixing that. **This one can.** `O1` therefore stops being structurally guaranteed
and reverts to an ordinary open P0 that can be shipped past.

**That is a consequence, not an objection.** The owner is entitled to choose a shipping gate over a
usage gate, and shipping to TestFlight is what puts the app in a position to generate the four
reviews at all. It is recorded here so that the next reader knows `O1` lost its guarantee by a
decision rather than by drift.

### Therefore

- **v1.5 ends when v1.5 is released, approved, and sent via TestFlight.**
- `SPEC.md:5`'s hard stop is struck. Amendment owed.
- `zenpom-v1.5.md`'s *"The hard stop"* section is superseded by this row and is not edited.
- `O1` is no longer absorbed by the stop condition and stands on its own as an open P0.

## D36 — Agent findings get a register of their own

**Proposed 2026-09-22. Ratified by the owner 2026-09-22.** Owed because `docs/conventions.md` Axis 2
defines no register for a finding only the agent can close, and eighteen such findings already exist.

**The problem this answers.** `docs/reviews/OPEN.md`'s *Needs the agent* table holds eighteen `A` rows,
`A1`–`A18` at lines 172–189, six of them open — `A1`, `A8`, `A14`, `A16`, `A17`, `A18`.
`docs/plans/00-register.md` holds none of them, and `docs/conventions.md` Axis 2 names only `D`, `RR`,
`O`, `H`, `M`, `FR`/`NFR`. So `docs/plans/00-status.md` — the one generated page that answers *what is
outstanding* — reports the open register rows while six agent-owned code findings are invisible to it.
A finding nothing counts is a finding that closes by being forgotten.

**Therefore:**

1. **A `## Agent items (A)` section is opened in `docs/plans/00-register.md`**, and **all eighteen rows
   are carried across, the twelve closed ones included.** The closed rows carry the reasoning for how
   each closed, which is the part worth keeping; a register of open rows only is a to-do list.
2. **The two alternatives are named so they are not re-proposed.** *Reclassifying the six open rows as
   defects or chores* destroys the twelve closed ones, which have no defect or chore to belong to.
   *Folding `A` into `O`* conflates the one thing `O` means — only the owner can close it — with its
   exact opposite.
3. **This is flagged upstream as a candidate promotion to `docs/conventions.md`.** In the owner's
   words, *"the conventions have no home for agent-owned findings"* is a drift mechanism other projects
   will hit, and `conventions.md` says a local rule true of every project is promoted visibly rather
   than paraphrased twelve times. **Flagged, not made:** the vendored copy is never edited here (`D24`).

**The backfill itself is `C33` and is not done by `C31`.** This row is the ruling; the rows are the work.

## D37 — The register's decisions are generated, not maintained

**Proposed 2026-09-22. Ratified by the owner 2026-09-22.** Owed because two documents each hold part of
the authoritative answer to *how many decisions are there*, and they disagree on a CI-enforced page.

**The problem this answers.** This file defined 37 deltas when the ruling was taken, and 43 with this
batch in it. `docs/plans/00-register.md`'s
`## Decisions (D)` table contains exactly one row, `D30`, so `docs/plans/00-status.md` prints
`Decisions (D) | 1`. Neither source is wrong about itself and neither is complete, which is the second
intake path `conventions.md` forbids — *"a second document is a second intake path"* — already
producing a wrong number on a page a CI check keeps current.

**Therefore:** the `## Decisions (D)` section is **generated from `docs/plans/00-deltas.md` by
`scripts/gen_status.py`.** It is neither hand-maintained nor retired. The owner's principle, in effect:
**nothing is maintained twice.**

**The alternative that was refused**, so it is not re-proposed: retiring the section and pointing the
reader at `00-deltas.md`. It removes the disagreement by removing one of the two numbers, and it also
removes decisions from the single page `conventions.md` says should give the state of the project in
one read. The owner did not take it: a register that omits the largest register in the project is not
a register.

**Implementation is `C34`.** This row is the ruling.

## D38 — The missing registers open now

**Proposed 2026-09-22. Ratified by the owner 2026-09-22.** Owed because `conventions.md` Axis 2 names
five registers and this project keeps two.

**The problem this answers.** None of `## Mutations (M)`, `## Hooks (H)` or `## Risks (RR)` exists,
while **mutation IDs are in use across the plans in two incompatible spellings** — 23 distinct bare
`M<n>` tokens (`M1`–`M20`, `M22`, `M23`, `M34`) and 52 distinct feature-scoped ones (`F8-M1` …
`F19-M4`). **Both numbers were re-derived over this tree before this row was written, and the commands
are recorded here because a figure nobody ran is the thing this ruling exists to stop:**
`grep -rhoE 'F[0-9]+[a-z]*-M[0-9]+' . | sort -u | wc -l` returns 52 — F8 10, F10 5, F14 10, F15 6,
F16 4, F17 9, F18 4, F19 4 — and `grep -rhoE '(^|[^A-Za-z0-9_-])M[0-9]+' docs | grep -oE 'M[0-9]+' | sort -u | wc -l` returns 23.
`docs/handoffs/blockersfor1_5.md` states 52 in the sentence this ruling was drafted from, and it agrees
with the tree; **52 is inherited only because it was reproduced, not because the handoff said it.**
**The same handoff sentence also claims fifteen enforcement mechanisms, and that figure is NOT
inherited:** no command in this repository has been shown to reproduce fifteen, so this row does not
restate it. **Establishing the mechanism count is the first work of the backfill**, alongside
reconciling the two mutation spellings. The sharpest evidence is inside the test file written to stop
exactly this: `ZenTomatoTests/DeltaIntegrityTests.swift` carries the doc comment
``/// `everyRatifiedSpecAmendmentIsApplied` — H2.`` — **cited by that string rather than by a line
number, because that file is mutable and this row is not.**
**A shipped production test cites a register row that exists in no register.** That is the `D14`
failure — a citation with nothing behind it — reproduced one register over, by the file that exists to
catch it.

**Therefore:** `## Mutations (M)` and `## Hooks (H)` **open now, with full backfill** — every mutation
ID in use and every mechanism that actually enforces something, each traced *spec invariant →
mechanism → owning task*. `## Risks (RR)` opens with seed rows; it has no backlog to recover, so seeds
are honest where a backfill would be invention.

**The backfill is `C33`.** This row is the ruling. An empty or half-filled section opened before the
backfill would put the generated page's word behind work nobody has done, which is the failure
`00-status.md` was built to stop.

## D39 — F8 is halted at T3 and re-gated

**Proposed 2026-09-22. Ratified by the owner 2026-09-22.** Owed because it changes the scope and the
gate state of a feature already building, and `conventions.md` says a change of scope is a `D<n>`.

**The problem this answers.** `F8`'s ruled algorithm does not produce the thing `F8` was gated to
build. The trigger is the **last of the five `BLOCKING` notes** in `docs/plans/F8.md` — the one
beginning *"the second case in that list is the owner's stated example"* — against the owner's own
worked example, quoted verbatim from that file's *Paraphrasing it back* section. **Cited by anchor,
not by line:** this row is immutable and `F8.md` is not, so a line number written here would be wrong
the next time that file is edited, which is exactly what happened while this row was being drafted.

> *"say I have 2 hours to work on something. I want to break it up into 3 sprints over 120 minutes,
> with a good focus block and a minimum 5 minute break and a 10 minute long break."*

**What was built instead, for that same input: one sprint of four poms with a seventeen-minute long
break.** Not three sprints, and not a ten-minute long break. Those seventeen minutes are what `O37`
currently asks the owner to go and confirm on a phone.

**Therefore:**

1. **`T1`, `T2` and `T3` stay merged and stay usable.** They are not reverted; the shape store, the
   medium and the screen are real work that a corrected algorithm still needs.
2. **`T4`, `T5` and `T6` stop.**
3. **`F8`'s algorithm returns to a fresh gate**, and **all five unresolved `BLOCKING` notes in
   `docs/plans/F8.md` are answered first.** They are greppable — each begins `**BLOCKING —` — and
   `F8.md`'s own header names their line numbers.
4. **`O37` is held.** It asks the owner to confirm figures no document justifies. A device check whose
   expected values are in dispute cannot pass or fail; it can only ratify an accident.

**This is not the recommendation it was given.** `docs/handoffs/blockersfor1_5.md` listed this as
option *"C · Halt `F8`"* and recommended **against** it, preferring A. The owner ruled otherwise. Said
plainly here rather than quietly presented as the recommendation, because a register that launders a
ruling into advice loses the only thing it records.

## D40 — D33 is applied, and CLAUDE.md stops enumerating the order

**Proposed 2026-09-22. Ratified by the owner 2026-09-22.** Owed because applying it edits a ratified
baseline, which is the owner's to authorise and no one else's.

**The problem this answers.** `D33` was ratified 2026-09-09 and **never applied**. For thirteen days
`docs/specs/zenpom-v1.5.md` — a ratified baseline — stated a superseded scope of eleven units, and
`CLAUDE.md`, the project's own non-negotiables file, enumerated the same eleven on line 10. **Nothing
could have caught it:** the amendment ratchet reads `docs/specs/SPEC.md` and only `SPEC.md`, so a
delta amending the v1.5 spec has no instrument at all. That hole is `D41`.

**Therefore:**

1. **`D33`'s replacement text is written into `docs/specs/zenpom-v1.5.md`** — the unit count, the
   amendment trail, and the order table, which becomes **fourteen positions over thirteen units**
   because `F19` occupies two, its halves shipping apart.
2. **`CLAUDE.md` stops enumerating the v1.5 order** and points at the spec instead, per `C27`'s own
   principle that a standing document holds no milestone-scoped fact. A list copied into a second
   document is a second thing to keep true, and this is what it cost.

**Currently:** `CLAUDE.md:10` — *"The live milestone is **v1.5**, whose list and order are in
`docs/specs/zenpom-v1.5.md`: `C21`, `F8`, `F12`, `F13`, `F11`, `F14`, `F10`, `F9`, `F15`, `F16`,
`F17`."*
**Proposed:** *"The live milestone is **v1.5**. Its list and order live in
`docs/specs/zenpom-v1.5.md` and are not repeated here — a standing document holds no milestone-scoped
fact (`C27`)."*

**One gap, seen and left rather than missed.** `D33` says `F19`'s undo half *"owes its own delta"*,
which arguably makes a fourth row in `zenpom-v1.5.md`'s *Deltas this milestone owes* table. `D33`
proposes no replacement text for that table and the delta has no number, so the table is not touched;
the order table's `**yes — unnumbered**` cell carries the fact until there is a number to carry it.

**The replacement text for `docs/specs/zenpom-v1.5.md` is `D33`'s and is not restated here** — `D33`
is ratified and immutable and already holds it, and a second copy would be a second source.

## D41 — The amendment ratchet learns both spellings, and gains a second baseline

**Proposed 2026-09-22. Ratified by the owner 2026-09-22.** Owed because the instrument that is supposed
to make an unapplied amendment impossible missed one for thirteen days.

**The problem this answers**, in three holes, each with its evidence:

1. **Punctuation.** `ZenTomatoTests/DeltaIntegrityTests.swift:299` matches the literal string
   `**Currently:**`, colon inside the bold. Four deltas — `D31`, `D32`, `D33`, `D34` — write
   `**Currently**,` with the comma outside, and are invisible to it. **The precision matters:** a
   reviewer reported this as *"every delta since 2026-09-09"*. It is not. `D35` uses the colon form and
   **is** seen. It is four. An overstated finding gets refuted and takes the real one down with it.
2. **One baseline is unguarded.** `everyRatifiedSpecAmendmentIsApplied` reads **only**
   `docs/specs/SPEC.md`. `docs/specs/zenpom-v1.5.md` is an equally ratified baseline with no amendment
   ledger, no baseline file and no ratchet — and `D33` amends it. Nothing would ever have gone red.
3. **The count is unasserted.** This file's index sentence said *"36 deltas"* above 37 headings;
   `theIndexListsEveryDelta` asserts membership and never the count. This is the identical hole `O35`
   recorded against the old *"24 deltas"* claim, reopened at a new number.

**Therefore:**

1. **The detector is taught both spellings** rather than four ratified deltas being edited.
   `conventions.md` says a ratified decision is never edited, only superseded, so **normalising
   `D31`–`D34`'s text was refused.** The instrument bends to the record, not the record to the
   instrument.
2. **The ratchet is extended to cover `docs/specs/zenpom-v1.5.md`**, with its own baseline count.
3. **A count assertion is added for `docs/plans/00-deltas.md`**, so the index sentence cannot again
   state a number the table does not hold.

**Each new assertion is proven by being broken, and the failure is recorded** — *a ratchet nobody has
seen fail is not a ratchet.*

**Implementation is `C32`.** This row is the ruling.

## D42 — The register is authoritative and `OPEN.md` is a view

**Proposed 2026-09-24. Ratified by the owner 2026-09-24**, in the owner's own words, before the
work began:

> *"two files to maintain is exactly what I think we need to avoid. PR45 has been merged: STick
> with register and regenerate open.md."*

**WRITTEN AFTER THE WORK, AND THAT IS THE DEFECT THIS ROW FIXES.** `C37` was built on the
instruction above and never given a number. `docs/conventions.md` is explicit: *"An item with no
number has not been decided, however clearly it was said aloud"*, and *"Anything that changes
scope enters as a `D<N>`."* `D36` and `D37` cover the `A` register and the `D` table inside the
register; neither reaches this file. `C37`'s adversarial review found the gap, and it found it in
the artefact: `docs/reviews/OPEN.md` was printing *"SO: DO NOT GENERATE OPEN.md FROM THE
REGISTER"* inside a region generated from the register.

**The problem this answers.** `docs/conventions-local.md` defines `OPEN.md` as *"every
outstanding item from every review, in one table"*, and `docs/plans/00-register.md` holds the same
items. Two documents with one intake path each is the failure `docs/conventions.md` names:
*"a second document is a second intake path."* It was not theoretical — `O44` measured the cost.
16 of `OPEN.md`'s 35 `O` ids and 83 lines of prose existed nowhere else, including a paragraph
recording that the distraction tally over-reports for one block, which is a caveat on `O1`.

**Therefore:**

1. **`docs/plans/00-register.md` is authoritative for every register item.** An item is opened,
   updated and closed there.
2. **`docs/reviews/OPEN.md` is a view of it**, generated between marker pairs. Its prose outside
   the markers stays hand-maintained, because prose is not a row and a generator has no business
   writing it.
3. **The generation publishes a row-by-row diff, as a command with an exit code**, and any row
   present before and absent after is a defect. `scripts/open_backfill_diff.py`, in `make checks`,
   in CI, and in the pre-commit hook.
4. **`O44` is closed by this row**, not overruled by it. `O44` said *"do not generate OPEN.md from
   the register — the decision is the owner's."* It was right on both counts: the prerequisite it
   named (the register must first be complete) was met by `C33` and `C34`, and the decision was
   the owner's and has now been made.

**This supersedes nothing.** `O44`'s prohibition was an owner item, not a ratified decision, which
is exactly why it needed one.

**Implementation is `C37`.** This row is the ruling.

## D43 — The shape screen lets you set the number of pomodoros

**Proposed 2026-09-24. Ratified by the owner 2026-09-24**, with the hard question answered in the
same breath: *"it is ratified. if both are stated and it cannot be honored, refuse and name the
floor. if users don't like this, we should gather feedback on it and see how we can change it."*

**THE RULING, and it is the whole design.** When a count and a total are both stated and both cannot
be honoured, the screen **refuses and names the floor it hit**. It does not quietly reduce the count,
which is today's behaviour and which overrides what the reader just typed; and it does not shorten
below the floor. A control that silently ignores its own input is worse than no control.

**And the owner named the review condition rather than leaving it implicit:** if refusing turns out
to annoy people in use, that is feedback to gather and act on, not a decision to re-litigate now.
Recorded because *"we will see how it feels"* is the kind of intention that evaporates unless it is
written where the next reader finds it.

**Still not built.** `F8` is halted at `T3` by `D39` and owes a re-gate; this is item 1 of that pack,
now with its central question already answered.

Raised by the owner after using the build:

> *"when in the 'fit a sprint' screen, a user should also be allowed to change the number of
> pomodoros."*

**Why this is a delta and not a defect.** `F8`'s ruled design takes exactly one input — the total
time — and derives every part from it, targeting `pomodorosPerSprint` from `AppSettings` and flexing
the pom *length* to fit. Adding a second input changes the solver, so it is scope, not a fix.
`F8` is halted at `T3` by `D39` and owes a re-gate; **this belongs in that gate rather than ahead of
it**, which is why nothing has been built.

**The evidence that the ruled design lost something the owner asked for.** `docs/plans/F8.md` quotes
the requirement that produced the feature:

> *"say I have 2 hours to work on something. I want to break it up into **3 sprints** over 120
> minutes, with a good focus block and a minimum 5 minute break and a 10 minute long break."*

**The owner named a count in the sentence the feature was built from**, and the design takes the count
from settings instead — four, not three. The plan's own paraphrase says *"you rarely have 'four
pomodoros'"*, and then targets four. So this is not a new want; it is a want that was in the original
sentence and did not survive the solver.

**What it would change.** Two numbers are known and one is derived, instead of one known and two
derived:

| | today | proposed |
|---|---|---|
| input | total minutes | total minutes **and** pom count |
| derived | pom count (from settings), pom length, break lengths | pom length, break lengths |
| when it will not fit | reduce the count, and `pomodorosPerSprint` with it | **refuse, and say which floor was hit** |

**The hard question the gate has to answer**, because it is the whole of the design: when both are
stated and they cannot both be honoured — three poms in 20 minutes is below the 10-minute floor —
does the app reduce the count (today's behaviour, which silently overrides what you just typed),
shorten below the floor, or refuse and say why? **A control that silently ignores its own input is
worse than no control**, so the answer is probably *refuse and name the floor*, but it is the owner's
and it interacts with `Ruling E` on where a shape is stored.

**Second question, smaller:** does setting the count here change `pomodorosPerSprint` in settings, or
only this sprint? The ruled design changes the setting when it reduces the count, which is a durable
edit made by a transient screen.

**Not ratified, and nothing is built.** It is item 1 of `F8`'s re-gate pack.

-----
September 24, 2026

#AI/Claude

## D44 — v1.5's amendment ledger moves inside the baseline

**Proposed 2026-09-24. Ratified by the owner 2026-09-24**, in their own words: *"add the amendment ledger of
1.5 to the baseline. That should solve `O45`."*

**This is the decision `O45` was opened to get, and it could not be made by the agent.**
`docs/specs/zenpom-v1.5.md` is a ratified baseline, and `docs/conventions.md` is explicit that *"the
agent never edits the contract it is held to."* `C32` therefore put v1.5's ledger and its outstanding
count in two files *beside* the spec — `V15-AMENDMENTS-APPLIED.md` and `V15-AMENDMENT-BASELINE.txt`
— and recorded the asymmetry as an open question rather than resolving it: `SPEC.md` carries its
`## Amendments applied` list inline **because the owner edits `SPEC.md`**.

**Therefore:**

1. **`docs/specs/zenpom-v1.5.md` gains a `## Amendments applied` section**, in the same shape and
   the same words as `SPEC.md`'s: the ids on one line, and one sentence naming the files that hold
   the outstanding count and the replacement text.
2. **`AmendmentRatchetTests.watchedBaselines` points its `appliedList` at the spec itself**, so v1.5
   and `SPEC.md` are declared identically. The asymmetry the ratchet had to carry is gone.
3. **`V15-AMENDMENTS-APPLIED.md` keeps the evidence and stops being the list.** Its per-amendment
   record — what text changed, and where — is worth keeping and does not belong in a baseline. Its
   `## Amendments applied` heading is renamed so that nothing can read a second list: `C32-M6` is
   the mutation for a parser that found a *mention* of that heading instead of the heading, and two
   live lists would be that defect with the safety catch removed.

**The agent applied the edit rather than handing it back.** The owner ruled on 2026-09-11 — *"why am
I re-editing? this feels like an extra step"* — when the same situation arose for `SPEC.md` under
`D40`; the waiver was recorded in `65240a7` and this follows it. **The rule that the agent does not
edit a baseline is intact**: what makes an edit legitimate is a ratified decision, not whose hands
are on the keyboard, and this row is that decision.

**What this does not change.** The outstanding count still lives in
`docs/specs/V15-AMENDMENT-BASELINE.txt`, pinned, and `everyRatifiedV15AmendmentIsApplied` still
fails if it grows. `D33` still does not go red for the reason `O46` records, and moving the list
does not touch that.

-----
September 24, 2026

#AI/Claude

## D45 — A silent alarm and a haptic on the watch when the phone's sound is off

**Proposed 2026-09-24. NOT RATIFIED.** Raised by the owner from `O33`'s device check, test four:

> *"Watch on ZenPom focus. Sounds are off on the phone. Result: No alarm on the watch goes off. I
> think it should be a silent alarm, and a buzzing to let the user know the pom is done and the cycle
> is either on a break or a long break."*

**This is a new want, not the defect `O33` recorded, and separating them is the point.** `O33` was
*"the watch makes a noise when the phone is told not to"*, and tests four and five show that no
longer happens: sound off is honoured on the wrist. The feature closed correctly. **What the owner
found is that the correct behaviour is not the wanted behaviour** — silence is honest but it also
means a block ends with no signal at all on the wrist, which is the case the watch app exists for.

**The distinction the delta has to hold.** *Sound off* is a statement about **noise**, not about
notification. A haptic is not a sound, and the phone's sound setting arguably says nothing about it.
That reading is not obvious enough to act on without a ruling — a reasonable person can hold that
"silence the alarm" means "do not interrupt me by any channel", and the whole reason `O33` was filed
is that the app had been noisier than it was told to be.

**Open questions for the gate, and the first is the feature:**

1. **Does the haptic fire when the phone's sound is off, or always?** If always, this is not really
   about the sound setting at all; it is the wrist signal the watch app should have had from the
   start, and the sound setting only governs the noise on top of it.
2. **Does it respect the watch's own Focus and silent modes?** Test one shows those are honoured
   today and the owner called that *"working as intended"*, so a haptic that ignores theatre mode
   would undo a result already accepted.
3. **Does it distinguish a short break from a long one?** The owner's sentence asks for the reader to
   know *"the cycle is either on a break or a long break"*, which is two signals, not one.

**Nothing is built.** `F7` shipped and this changes its behaviour on the wrist.

-----
September 24, 2026

#AI/Claude

## D46 — The watch fires the same controls as the phone

**Proposed 2026-09-24. NOT RATIFIED — it contradicts ratified `D2` and needs to be decided against
it rather than beside it.** Requested by the owner while ratifying `D30`:

> *"it needs to have a watch face complication that lets the watch app fire off all the same controls
> as the iOS app."*

**This is separated from `D30` deliberately.** `D30`'s own ratified spec text says the complication
*"starts nothing and captures nothing."* Reading this sentence into `D30` would have ratified a row
much wider than the text it carries, which is how a scope fence stops meaning anything.

### What it contradicts, by name

**`D2`, ratified 2026-08-21**, defines the watch in one sentence and rules three things out
explicitly:

> The phone is the source of truth and runs the only timer engine. The watch displays the running
> block, the block kind, and the attached task, and puts the I and E distraction buttons on the wrist.
> **The watch never runs a timer of its own, never controls music, never picks a task**, and never
> edits a distraction note. … Everything else stays on the phone.

**And `docs/specs/zenpom-v1.5.md` puts this on the v2.0 list by name:** *"A more independent watch
app — Contradicts ratified `D2`. `F14` delivers the useful half without reopening it."*

So the request is already answered by the contract, in the negative, twice — which is exactly why it
needs a decision rather than an implementation.

### What is already coming, and may be what was actually wanted

Three ratified items already move controls to the wrist without reopening `D2`:

| | | |
|---|---|---|
| `F14` | *The watch can launch a pom* | v1.5 item 7 |
| `F18` | *A watch-side App Intent* | v1.5 item 9 |
| `F17` | the complication, which **opens the app** when tapped | v1.5 item 14 |

**`F17`'s plan already says the complication taps through to `F14`'s button**: *"a tap would invoke
an App Intent `F14` already defines."* So *start a pom from the wrist* is coming, and the gap between
that and this request is **music control and task picking** — the two things `D2` names.

### The question the owner has to answer

**Is this "let me start and stop a sprint from my wrist" — already planned — or "let me run the whole
app from my wrist", which is the v2.0 item?** They are very different in size and only the second
needs this delta.

If it is the second, three things follow and none is small: `D2` is superseded rather than edited (a
ratified decision is never edited); the watch gains a task picker and music control, which is the
*"scope gravity"* `F7.md` warns about in as many words — *"a watch app invites a complication, a start
button, a task picker"*; and **a complication is the wrong surface for it regardless.** A watch-face
complication is a glance with at most a small interactive area; it cannot host the phone's controls,
so this would be a watch *app* change with the complication merely launching it.

### The recommendation

**Take the first reading, and build nothing new.** `F14` and `F18` already deliver starting a pom
from the wrist, `F17` taps through to them, and that is the useful half the v1.5 spec says it is. If
after using `F14` the wrist still feels short of controls, that is feedback with a real build behind
it — which is a much better position to widen `D2` from than this one.

**Nothing is built, and `F17` is unblocked either way**: `D30` is ratified and `F17` can be gated on
its own terms.

-----
September 24, 2026

#AI/Claude

## D47 — ~~The shape store is a single `Codable` value in `UserDefaults`~~

**REJECTED 2026-09-24, SAME DAY, AS A DUPLICATE OF `D32`.** It is kept here struck through rather
than deleted, because `docs/conventions.md` says a rejected decision stays in the register so it is
not re-proposed — and this one would be, by anybody reading `F8`.

**`D32`, ratified 2026-09-09, already decided exactly this**: *"a shape is persisted as one small
`Codable` value in `UserDefaults`, in exactly one shipped file, and `noNewPersistentSurface` is
amended to admit that file by name and nothing else."* The fence already names
`ShapeStore.swift`, and `ShapeStore.swift` already ships.

**Why it was written anyway, recorded because the cause is reusable.** `F8.md`'s `Ruling E` says *"the
shape-store delta, by name and not by number, **because it is not ratified**"*, and its first open
question asks the owner to choose `UserDefaults` or a `TimerState` migration. Both sentences were true
when written on 2026-09-09 and stopped being true later that same day. **The plan was never updated,
and the agent asked the owner to decide something already decided, then wrote a delta for it.**
Nothing checks that a plan's prose still matches the register — `F8.md` is corrected, and `A22`
records the class.

**The original text follows, struck, for the record.**

~~**Proposed 2026-09-24. NOT YET RATIFIED — and the reason is a convention, not a hesitation.**~~ The
owner chose it: *"let's do user default."* `F8`'s `Ruling E` had already recommended it and the owner
had already asked for *"the most lightweight storage method Swift allows … I would prefer to not have
a db on this unless we reach the point where we have to."*

**What holds ratification is one unrun command.** This delta rests on *"`UserDefaults` survives an app
update"*, which is a claim about a system outside this repository. `docs/conventions.md`: where a
decision asserts that, the confirming command and its output go on the row **before** ratification,
and the evidence is the observable end state rather than the documented behaviour. `F8`'s fourth
`BLOCKING` note has said so since 2026-09-22.

**It matters more under the lifetime ruled on 2026-09-24**, not less: a shape now lasts until a new
shape replaces it, so a shape genuinely is expected to cross an update.

**The check, and it fits in one sitting — but it has to be designed or it proves nothing.** The shape
screen opens on sixty minutes, so **a stored shape of sixty is indistinguishable from a wiped store**:
both put sixty on the screen after the update. The check must store a shape that is *not* the default.

1. Set the budget to **90 or 120**, and change the preset as well.
2. **Install the next build over the top** — the update path, not a fresh install.
3. Open *Fit a sprint* and report the number it opens on.

**90 means the store survived and this delta can be ratified. 60 means it did not**, and the answer is
`TimerState` and the migration below.

**Currently:** *Data | Local only (SwiftData)*

Replace with:

> Data | Local only. SwiftData for everything durable; one `Codable` value in `UserDefaults` for the
> running shape, written by one type.

### What it costs, stated rather than implied

**It trips a fence, and that is the fence working.** `ZenTomatoTests/PolishFenceTests.swift:120`
asserts `countAcrossApp("UserDefaults") == 0` across every line of shipped Swift. That test's own doc
comment says what to do here: *"If a measurement genuinely demands a cache, this test failing is the
correct outcome: it stops the pass and moves the argument to a delta, where it belongs."* This is that
delta. The fence is amended to allow exactly one file, not deleted.

### Why not `TimerState`, the runner-up

`Ruling E` argues it at length and one reason outweighs the rest for the owner's own data: **columns
on `TimerState` mean a SwiftData migration over the store holding the distraction log.** That is the
same store `C26` refuses to risk for a rename, and `O1` — *one real day's export, read beside the
Rhodia* — has never been run against it. A migration there is not free and it is not reversible.

Two further reasons, from the plan: a shape is a **variable-length list of blocks**, which a
flat-column row cannot hold without becoming an encoded blob inside a row whose own doc argues for
*"six plain numbers"*; and `TimerState` pins its own fence number, `timerStateColumnCount = 17`, so it
is not cheaper on that axis either.

**So the trade is: amend a fence, or migrate the crown jewels.** The owner chose the fence.

-----
September 24, 2026

#AI/Claude

## D48 — The garden accumulates, and nothing gamified may be lost

**Proposed 2026-09-09 as *the garden delta*. Ratified by the owner 2026-09-24**, together with the
ruling that settles which of two garden specifications is being built: *"go with F16's form."*

**Currently:** *…themes · streaks, badges, or any gamification layered on top of Todoist's own.*

Replace with:

> …themes · streaks, badges, goals, records, targets, comparisons, or any gamification layered on
> top of Todoist's own — **with one exception, ratified as `D48`: a display of finished work that
> only ever accumulates.** It may grow when a pom is finished. It may not shrink, decay, reset,
> break, or read differently because of *when* the poms happened, and it may not be shown per day.
> The exception is enforced by a test, not by this sentence.

**Note that the list gets longer, not shorter.** *Goals, records, targets, comparisons* are added in
the same breath as the exception, because the exception is narrow and the clause around it should
name the devices it is narrow against.

### The argument: the clause was written against a quantity a person can lose

Every device on that list — a streak, an unearned badge, a goal, a personal best — shares one
property: **its value depends on what you do next.** That is the whole of its motivating force and
the whole of its harm. A quantity that can fall is a quantity worth protecting, and the two cheapest
ways to protect it are both attacks on the log: *don't tap the distraction button*, and *don't open
the app on a bad day*. The distraction log is the point of this application, so a mechanism that
makes under-reporting rational is not a decoration — it is a hole in the product.

**An accumulate-only garden has no such quantity.** Nothing a bad day can take off it. Three weeks
away leaves it exactly as it was, and opening it after three weeks says nothing about the gap,
because the garden does not know there was one. Tapping Internal eleven times in one pom changes it
by nothing, because it is a function of finished poms and of nothing else. **There is no behaviour a
person could adopt to protect it except doing more work.**

**So the honest form of the clause is not *"no gamification"* — it is *no quantity that can be
lost*.** That is mechanical, it can be written down, and unlike the word *gamification* — which
somebody will argue about in six months — it can be enforced by a program. `F16-T2` is that fence.

### The specification this refuses, which is the owner's own

`docs/ZenTomato redesign scope.zip` specifies a garden in detail and **this delta forbids four of its
parts**: a *"Last 14 days bed"* of per-day cells, a *"wilted stem"* on a zero day, a *"Milestone
banner"* announcing a crossing, and a per-day *"tomatoes today"* header. The handoff carries its own
guardrails under a heading reading *"spec, not suggestion"*, and the second of them states the
disagreement outright — *"no chain number; **continuity is visible in the bed itself**."*

**It treats the visible bed as the safeguard; this delta treats it as the mechanism.** A grid of days
*is* an unbroken chain, and its gaps are what a reader counts. Likewise *"wilt, never reset"* tests
whether a **number** goes down, where this delta tests whether **anything can be taken away** — and a
drooping leaf where yesterday had a tomato takes something away without moving a number.

**Ruled 2026-09-24: this delta's form wins, and the handoff's garden is not built.** Recorded rather
than smoothed over, because the owner commissioned that design and a future reader will find it in
the tree and wonder why the app does not match it.

### What this deliberately does not license

- **A per-day grid, calendar or heat map.** Refused explicitly; it is the likeliest reappearance.
- **Decay, wilting, or anything reading as neglect** — a streak with the sign flipped.
- **Thresholds phrased as achievements.** Bands may exist, because 1,044 tomatoes cannot be drawn
  individually; ratified 2026-09-24 as **unnamed, unannounced, with no visible next threshold** —
  growth you notice rather than growth that tells you.
- **Anything grown by a distraction tap.** Ratified 2026-09-24: a tally that can be inflated is as
  broken as one that can be suppressed.

-----
September 24, 2026

#AI/Claude

---

## D49 — The shape's position gets one hour, not thirty-six

**Proposed 2026-09-26. Ratified by the owner the same day**, in the same breath — two days after the
ruling it supersedes, and before any build carrying the thirty-six hours reached the phone.

> *"I think the 36 hours is too long. I think we should change the time to 1 hour."*

**Currently** (`D32`, ratified 2026-09-24): *"only the defitinon. a grace period of 36 hours."*

Replace the number only:

> The shape's **definition** lasts until a new shape replaces it. The **position in it** is dropped
> after **one hour** in which the cursor has not moved, and the cycle's pomodoro tally is dropped with
> it.

Everything else `D32` decided stands: the shape itself survives finishing, stopping and silence, and
only a replacement discards it.

### What this withdraws, deliberately

`D32`'s thirty-six was sized for one case and said so: *stopping at six in the evening and coming back
after nine the next morning is under a day of clock time and over a day of calendar.* **One hour does
not survive a night, and is not meant to.** That case is now withdrawn rather than overlooked.

**And it withdraws more than the night.** Any gap longer than an hour restarts the sprint — a long
meeting, a lunch, a school run. The owner comes back to the shape they fitted, at its first block,
with the tally at zero. That is the same end state a deliberate Stop produces, and the argument for it
is that after an hour away *"I was in the middle of a sprint"* has stopped being true of the person
even though it is still true of the database.

**The consequence was named before the change was made**, not discovered on the device, and the owner
ruled with it in front of them.

### Why the old argument is kept rather than deleted

`StoredRun.grace`'s doc comment still carries `D32`'s reasoning in full. It was not wrong; it answered
a different question — *how long is a sprint recoverable* rather than *how long is a sprint still
yours*. A ratified decision is superseded and never edited (`conventions.md`), and the same courtesy
is owed to the argument that justified it: a reader who finds only the new number cannot tell whether
the old one was a mistake or a different judgement. It was a different judgement.

### One thing this makes likelier rather than less

**An ordinary sprint now outlives its own grace.** A two-hour shaped sprint is longer than an hour, so
the grace expires *during* it. Nothing breaks — the grace is measured from the last cursor move, not
from the fitting, and every block boundary re-stamps it — but that property has gone from a nicety to
load-bearing. `F8-M15` is the mutation that holds it, and `advancingAStaleShapeMovesItOnAndMakesThePositionFreshAgain`
is the test; both predate this delta and both now guard the common case instead of a rare one.

**The clock-skew bound matters more too.** A position stamped while the device clock is a minute ahead
is a likelier accident against an hour than against a day and a half; `isFresh(at:)` rejects a future
stamp, which it did not until the 2026-09-26 review.

---

## D50 — A push reminder about the work in progress · **v2.0, parked**

**Proposed 2026-09-26. Ratified by the owner 2026-09-27 as v2.0 — SO IT IS PARKED, NOT NEXT.** A
ratified decision carrying a future milestone *is* the parked backlog (`conventions.md`); there is no
`parked.md` and nothing here is built.

> *"a push reminder about the work if the user turns on pushes."* — 2026-09-26
>
> *"push is 2.0; reminder on returning to the sprint before the internal timer runs out. push
> notification for a reminder log is auto logged as an external interruption, as 'paused sprint.' if
> the permission is off, just auto log the distraction."* — 2026-09-27

### What the owner ruled, and it answers three of the five open questions

| Question this delta asked | Ruled |
|---|---|
| Is a new permission surface polish or platform? | **Platform. v2.0.** |
| Which of four readings of *"a reminder about the work"*? | **The abandoned sprint** — *"returning to the sprint before the internal timer runs out"*. Not the running block, not the fitted-but-unstarted shape, and **not** the daily nudge, which would have hit `D48`'s fence. |
| What does it do to the distraction log? | **It writes to it.** The reminder is auto-logged as an **external** interruption with the reason *"paused sprint"*. |
| What happens when the permission is refused? | **The distraction is logged anyway.** The notification is the part that needs permission; the record is not. |

`D45`'s adjacency stands as the fifth: both are notification-shaped and should be ruled together
before either is built.

### TWO THINGS THAT NEED THE OWNER AGAIN BEFORE THIS IS BUILDABLE, AND BOTH ARE ABOUT THE LOG

**1 · This would be the first row in the distraction log that nobody tapped.** Every row today is a
deliberate press — that is what makes the log mean something, and `O1` is *one real day's export read
beside the Rhodia*. A row the app wrote about itself is a different kind of fact from a row the person
wrote about their attention, and an export that mixes them without saying which is which changes what
`O1` can conclude. Options, not a recommendation: a distinct kind; a flag on the row; or the owner
ruling that it reads identically and that is fine. **The no-capture rule is not in the way** — that
rule forbids the app accepting a new *task*, not a new distraction — so this is a question about
meaning, not permission.

**2 · If the record does not need permission, the record is not v2.0 and the notification is.** The
ruling splits the feature cleanly in half: *auto-log a paused sprint as an external interruption* needs
no notification surface, no new permission and no platform — it is a thing the timer already knows at
the moment it knows it. That half would be v1.5-shaped. **It is left parked with the rest deliberately
rather than split on the agent's initiative**, because splitting a ratified v2.0 item and shipping half
of it now is a scope decision, and scope is the owner's. If the owner wants the logging half in v1.5 it
needs its own `D<n>` and its own place in the order.

### Still to decide, carried forward

What the copy says · whether the reminder repeats or fires once · how long *"before the internal timer
runs out"* is measured from, and against which clock · whether one reminder can produce more than one
logged interruption · `SettingsBounds` and `AppSettings`' eighth column.

**`CLAUDE.md` is why this stopped at a proposal rather than shipping beside the one-line change it arrived with:**
*"Do not build, stub, or 'prepare for' what is not on the list. If it seems necessary, write `Proposed
spec delta:` in the plan summary and stop."* A notification is not on v1.5's ratified list, and the
one-hour grace it was asked for alongside is — which is exactly the situation that rule exists for: a
small ruling and a new feature in one sentence, where doing both quietly is how a milestone grows.

### What had to be decided before it could be built — kept, because three of these are now answered above

1. **Is it v1.5 or v2.0?** The fence is architectural: *v1.5 is polish, v2.0 is platform; anything
   adding a platform or a provider is v2.0.* A local notification is arguably neither — the app already
   asks iOS for alarm authorisation through AlarmKit — but a **new notification surface with its own
   permission prompt, its own settings row and its own copy** is closer to a platform than to polish.
   This is the owner's call and it is the first one.
2. **What does it say, and when?** *"A reminder about the work"* has at least four readings: the block
   that is running; the sprint you abandoned mid-way; the shape you fitted and never started; and a
   daily nudge to work at all. The fourth is a habit mechanism and would run straight into `D48`'s
   gamification fence, which forbids *"streaks, badges, goals, records, targets, comparisons."* The
   other three are not.
3. **What does it do to the distraction log, which is the point of the app?** A notification that
   pulls somebody back into the app mid-block is itself a distraction, and the app has no way to record
   one it caused. `SPEC.md`'s vision sentence is the test here, and it is the kind of question only the
   owner can answer.
4. **It needs an authorisation path, and one already exists for something else.** The app asks for
   alarm permission and *refuses to run without it* — deliberately, with a blocking explainer and
   **no quieter fallback**. A second permission that is optional would be the first optional
   permission in the app, so "if the user turns on pushes" needs a decision about what the app does
   when they do not: nothing, or nag.
5. **`D45` is already open and adjacent.** The watch haptic is proposed and unratified. Two
   notification-shaped deltas in flight at once should be ruled on together or one will contradict the
   other.

### What it would touch

A settings row and its copy · a permission request and its refused state · a scheduler, which is a
second thing in the app that talks to iOS about future events · a decision about whether the reminder
survives the app being killed · `SettingsBounds`, `AppSettings` (an eighth column — see `F8.md`'s note
that the header still says *"EXACTLY SIX PROPERTIES"*) · and the `O1` export, if a caused distraction
is to be recorded.

**Nothing above is written. No file was created, no column added, no stub left behind.** This entry is
the whole of the work done on it.

---

## D51 — The export leaves as text *and* as a file, so a notes app can take it as a note

**Proposed and Ratified by the owner 2026-09-27 as v1.5** — *"text and file."* Raised by the owner from
the `O52` device run:

> *"export to bear: it looks ok — but putting it in bear attaches as a file. i'd prefer it went to
> bear or notes app straight as a note."*

**Currently** — and this is a *documented decision*, not an oversight. `StatsExportFile.swift:14`:

> *"`ShareLink` will happily share a `String`, and what arrives in Files when it does is
> `Untitled.txt`. The document **is** this feature — `F6` exists to produce the page a fortnightly
> review is read from — so it leaves the app as `ZenTomato-2026-08-08-to-2026-08-21.md`: sortable,
> self-describing, and still meaningful sitting in a folder a month later."*

Every word of that is true and it is the reason Bear receives an attachment: a file is what was
offered, so a file is what Bear filed.

### The proposal: offer both representations, not one instead of the other

`ShareLink` takes a `Transferable`, and a `Transferable` may carry **more than one** representation.
The proposal is one type offering a `FileRepresentation` **and** a plain-text representation, so the
destination picks:

| Destination | What it takes today | What it would take |
|---|---|---|
| Files, iCloud Drive | `ZenTomato-…-to-….md` | unchanged — the named file |
| **Bear, Notes** | an attached `.md` file | **the Markdown as the note's body** |
| Mail, Messages | an attachment | the text inline, or the file — the app's choice |

**Nothing is taken away, which is why this shape rather than the obvious one.** Replacing the file
with a string would trade one complaint for the one the existing comment already anticipated and
rejected — `Untitled.txt` in Files, a fortnight of review notes with no name on it. Offering both is
the only version that does not overturn a decision that was right.

### What has to be decided

1. ~~**Is this v1.5 or v2.0?**~~ **RULED v1.5.** It touches no platform and adds no provider — it
   changes what an existing share sheet offers about an artefact the app already produces. The v2.0
   form, which puts the note *into* a named app with a tag and a folder, is `D53`.
2. **Does the plain-text form carry the title line?** The file's name carries the date range today. A
   note pasted into Bear has no filename, so either the first line of the document does that work — it
   already opens `# ZenTomato — 2026-08-10` — or the range is lost on that path. Recommendation: the
   document is unchanged and its own heading is the answer, which it already is.
3. **Does the heading say `ZenTomato` or `ZenPom`?** Already open as an observation from `F8-T5`: the
   page's heading says one and its footer says the other. A note filed in Bear makes that more visible
   than a file did, because the heading becomes the note's title.

### What is explicitly NOT part of this delta

**Bear's own URL scheme.** `bear://x-callback-url/create` would put the note in Bear directly with a
tag and no share sheet. That is a **provider**, and `CLAUDE.md`'s fence is architectural: *anything
adding a platform or a provider is v2.0*. It would also tie a v1.5 surface to one third-party app when
the same one-line change serves Bear, Notes, Drafts, Obsidian and Mail at once. If the owner wants Bear
specifically, that is a different delta and a v2.0 one.

**A retrofit of `F6`**, whose export shipped in v1.0. It needs no new plan file: the delta names the
change, the shape is one `Transferable` with two representations, and the mutation that proves it is a
build offering only the file — which is today's behaviour and therefore already known to be reachable.

---

## D52 — The tomato fills in as the sprint progresses, replacing the FOCUS glyph

**Proposed and Ratified by the owner 2026-09-27**, with the baseline waiver in the same breath:

> *"I want that tomato in v1.5."* · *"The tomato is authorized and ready to go add it to v1.5."*

**IT WAS HELD AT `proposed` FOR FOUR HOURS, AND THAT IS WORTH KEEPING ON THE RECORD.** The owner ruled
the scope first; ratifying it on that alone turned `AmendmentRatchetTests` red, because a new v1.5 unit
owes an edit to `docs/specs/zenpom-v1.5.md` and that file is a ratified baseline. The check's own words
are *"the agent may not fix a red ratchet, and that is why it exists"* — the agent cannot edit a
baseline, and raising the tolerated count would have defeated the instrument rather than satisfied it.
So the delta sat at `proposed` until the authorising sentence arrived, exactly as `C31` waited for
`D40`. **Applied the same day it was authorised**; the evidence is in
`docs/specs/V15-AMENDMENTS-APPLIED.md` and the ratchet is back at zero.

Previously pinned by the owner on 2026-09-25 (*"let's put a pin in that"*) and un-pinned now that the
Dynamic Island has been seen working on the device — and now that *banana mode*, a Reddit-app Live
Activity that had been taking the Island slot, is switched off:

> *"Also, I see the coffee cup. I want that tomato in v1.5."* · *"the tomato fills in as the sprint
> progresses, replacing the coffee cup."*

**What it changes, and what it does not.** The Live Activity's presentations draw a **tomato that fills
as the sprint progresses** — a picture of the sprint's completion, not of the block's countdown, and not
a second timer.

**CORRECTED 2026-09-27 BY `F2f`'s PLAN, BEFORE ANY CODE: THE COFFEE CUP IS THE *BREAK* SYMBOL AND WAS
NEVER ON A FOCUS BLOCK.** `BlockLiveActivity.swift:315` is
`Image(systemName: kind == .work ? "timer" : "cup.and.saucer")`. The owner saw the cup because they were
looking at a break, and this delta's own title said *"replacing the coffee cup"*. What the tomato replaces
is **`"timer"`, the focus glyph**; the owner's second sentence — *"you can have the cup on the break"* —
is consistent with that and the break path does not change at all. Built from the title alone, the first
commit would have replaced the break symbol and shipped a tomato where the rest is and a timer where the
work is, inverted, with a green suite.

**No `SPEC.md` wording is replaced.** That file forbids *"widgets beyond the Lock Screen Live
Activity"*, and this is **inside** that Live Activity rather than beyond it: the presentation shipped
in v1.0, was verified on device 2026-08-23, and already draws something. What this owes is a position
in v1.5's order, which is a different baseline and a different authorisation.

### Why this is v1.5 and not v2.0

The fence is architectural: *anything adding a platform or a provider is v2.0.* This adds neither. The
Live Activity shipped in v1.0, its Dynamic Island presentation was verified on device on 2026-08-23,
and all four presentations — expanded, compact leading, compact trailing, minimal — already exist and
already render. **This is a drawing change inside a shipped surface**, which is what v1.5 is for.

### `D48`'s fence is the thing to be careful about, and this passes it

`D48` forbids *"streaks, badges, goals, records, targets, comparisons, or any gamification"*, with one
ratified exception: a display of finished work that **only ever accumulates**. A filling tomato is not
that exception — it is bounded by the sprint and resets when the sprint ends — so it must be justified
separately, and it can be: **`D48`'s harm is a quantity a person can lose.** A tomato that fills
across a sprint and empties at the next one records nothing, remembers nothing, and cannot be
protected by under-reporting a distraction. There is no quantity to defend, so the mechanism `D48`
exists to prevent is absent. It is a progress indicator, which the countdown already is.

### ~~ADDING THIS TO v1.5's ORDER EDITS A RATIFIED BASELINE~~ — AUTHORISED AND APPLIED 2026-09-27

`docs/specs/zenpom-v1.5.md` states *fourteen positions over thirteen units*. A new unit means the unit
count and the order table both move, in a file `CLAUDE.md` calls a baseline that is never edited. The
precedent is `D40`, which authorised `D33`'s edit explicitly and whose commit recorded the waiver
rather than doing it quietly. **The same waiver was needed here and the owner gave it**: the order table
now carries `| 15 | F2f | … | S | yes — D52 |` and the sentence below it reads *"Fifteen positions over
fourteen units"*. The rule stands — nothing here licenses the next baseline edit.

### Ruled at the gate, 2026-09-27

> *"fills by finished pomadoro -- you can have the cup on the break."*

1. **What fills: the count of FINISHED POMODOROS.** Not elapsed time. Four poms fill in four steps, and
   each step lands at a boundary the log already records. **This is the answer that makes the feature
   cheap and honest:** elapsed time would have been a second countdown — the expanded presentation
   already provides one — and it would have drawn progress during a break, when no work is happening.
2. **A break keeps the coffee cup.** So the two states stay distinguishable at a glance, which is the
   whole job of a compact presentation: it is the one thing a person reads without unlocking.
3. **A shaped sprint of three poms fills in thirds**, and this follows from ruling 1 rather than needing
   its own. The denominator is `pomodorosPerSprint` as frozen on the timer row — the same number the
   sprint dots and the Lock Screen already read, which `F8` confirmed correct on device. **A tomato that
   computed its own denominator from settings would disagree with the dots beside it whenever a shape
   reduced the count**, and that is the trap `F8-T4` already names for this exact surface.

### Still open, and small enough to settle in the plan rather than at a gate

4. **The minimal presentation** is a single tiny glyph with no room for detail. Whether the tomato
   appears there at all, and what "a quarter full" means at that size, is a drawing question for
   `F2f`'s plan.
5. **Whether the Lock Screen presentation changes too**, or whether this is Island-only. The owner's
   sentences are about the Island; the Lock Screen is where they actually watched a countdown work.

**It is `F2f`, a retrofit of `F2`**, because the Live Activity shipped there — `SPEC.md:39`, *"A Live
Activity on the Lock Screen and in the Dynamic Island is required, not optional."* Changing what its
compact presentation draws is a second pass on something shipped, not a new feature, and
`conventions.md` is explicit that a retrofit's letter is an identifier and not an index: `F2b`–`F2e`
are taken, so this is `F2f`.

**Nothing is built.** `docs/plans/F2f.md` comes next and the owner's yes on it comes before code.

---

## D53 — Notes apps are tied in directly, at v2.0

**Proposed 2026-09-27. Ratified by the owner the same day as v2.0 — so it is parked.**

> *"Tie bear and other notes apps for 2.0."*

The v2.0 form of the export's destination: the app puts the page **into** a notes app rather than
handing it to a share sheet — Bear's `bear://x-callback-url/create`, Apple Notes, and whatever else
earns a place — with the tag, title and folder decided rather than left to the receiving app.

**This is a provider, and that is precisely why it is v2.0.** `CLAUDE.md`'s fence: *anything adding a
platform or a provider is v2.0.* It also adds a second outbound integration to an app whose standing
rule is *"no network calls except Todoist and MusicKit"* — a URL scheme is not a network call, but a
list of one-app integrations is the kind of surface that rule exists to keep closed.

**It does not make `D51` unnecessary — it makes it optional.** `D51` — *"text and file"*, ratified by
the owner 2026-09-27 — offers the Markdown as **text as well as a file** so Bear, Notes, Drafts,
Obsidian and Mail can each take it as a note body today, with no integration, no provider and no
per-app code. This delta is the version that decides the tag, the title and the folder rather than
leaving them to the receiving app.

**Nothing is built.**

---

## D54 — A plan can be reordered

**Proposed 2026-09-27. NOT RATIFIED, NOT BUILT.** Raised by the owner from the `O52` device run:

> *"I do think we need more testing on task/project selection, as I want to ensure that a user can pick a
> task or seris of tasks and reorder them."*

**Currently:** nothing in v1.5's ratified order covers it, and the code says so in two places.
`SessionPlan:40` — *"Stepping over an item moves this number and does nothing else — the item is not
removed, not marked, and **not reordered**."* `SessionPlanItem:81` — *"Entries are only ever created
together, when a plan is built, and are **never edited afterwards**."*

> A plan's items may be **reordered by the person who built it**. The order is a property of the list and
> is written to `SessionPlanItem.position` only; it is never sent to Todoist, and no new column is added
> to carry it.

### Half of what was asked for is already built, which is why this delta is small

**Picking a series of tasks works today** — `PlanBuilderView:170` holds an *array* of selections and
hands the lot to `replacePlan(with:)`. **And the order is already stored** — `SessionPlanItem.position`,
whose own comment says *"an order has to be written down somewhere, and with no links between rows this
is the only place it can go."*

So this delta adds no column, no model and no concept. It licenses two things: a gesture, and a `move`
method on a store that currently has `replacePlan`, `stepOver`, `remove` and `clear` and no fifth.

### Why it does not breach the rule the item model is written to defend

`SessionPlanItem`'s header is the most forcefully written comment in this codebase and it is aimed
squarely here: *"An ordered list of tasks is one field away from being the local copy of Todoist this app
is forbidden to keep, and the way it happens is never a bad decision — it is four good ones."*

**The distinction that lets this through is in the comment two lines above `position`:** it *"is a
property of the list, not of the thing in Todoist — it says nothing whatsoever about the task, and
Todoist neither knows nor cares about it."* Editing a fact about the **list** is not a step toward a copy
of Todoist. Editing a fact about the **task** — done, due, urgent, tagged — is, and this delta licenses
none of it. The mechanical fence, `planItemHasFourStoredProperties`, is untouched because no column is
added.

**What the delta does owe is a correction**: two comments stop being true when this ships, and they are
corrected with the argument rather than quietly deleted. That is `F20-T4`.

### THE ORDER NEVER REACHES TODOIST

`CLAUDE.md`, non-negotiable: *"The only write to Todoist is complete task. Never call create, update, or
comment endpoints."* The obvious next thought — *"it should reorder them in Todoist too"* — is forbidden
rather than merely unplanned, and a pre-commit hook greps for those endpoints. Stated in the delta so it
is refused before it is built, not after.

### What has to be decided before it can be built

1. **WHEN can it be reordered?** Three answers and they are three different features: while building the
   plan only (**S**); any time the timer is idle, including between blocks (**M**); or any time at all
   (**L**, and `docs/plans/F20.md` argues against it — the attachment is frozen onto the timer row when a
   block begins, so dragging during a block would appear to work and change nothing in front of you).
   **The plan recommends the first**, because it is the request as stated and because `SessionPlan`'s own
   header says planning is a separate act from starting.
2. **A position in v1.5's order**, which edits a ratified baseline and needs the owner's explicit waiver —
   the same sentence `D52` needed. **`AmendmentRatchetTests` goes red the moment this is marked ratified
   without it, and the agent may not fix a red ratchet.** The plan proposes position 16, last.
3. **Does swipe-to-delete come with it?** `SessionPlanStore.remove(_:)` exists and no view calls it. One
   line, not in the request, asked rather than assumed.

**Nothing is built.** `docs/plans/F20.md` is written and waiting for the owner's yes.
---

## D55 — The Island tomato fills by elapsed time over the block, per the design handoff

**Proposed and Ratified by the owner 2026-09-27.** **Supersedes `D52`'s fill rule and nothing else.**

> *"go with the handoff, but keep the coffee icon from today's conversation."*

**Currently** — `D52`, ratified earlier the same day: the tomato *"fills as the sprint progresses"*, by
**finished pomodoros**, with the gate ruling *"fills by finished pomadoro."*

Replace the fill rule with the handoff's:

> The Island tomato's red fill **rises from the base as the block elapses**, derived purely from the
> block's start and end instants — `design_handoff_v1.5_upgrade/README.md`: *"circle outline r9
> (`#948F84` 1.2px), red `#E06A50` fill rising from the base as the block elapses (rect clipped to the
> circle, scaleY = progress, origin bottom), leaf crown `#8AA163` on top drawn over the fill. 24×26
> viewBox as drawn; render at glyph size."*
>
> **A break keeps the coffee cup.** Unchanged, and now ruled twice.

### What changed and why the earlier ruling is kept rather than deleted

`D52` was ruled before the owner pointed at the design handoff, which the agent had not opened. The
handoff specifies this feature by name and specifies it differently — *elapsed time over the block*
rather than *finished pomodoros over the sprint*. Told of the conflict, the owner chose the handoff.

**`D52`'s ruling was not wrong; it answered the question in front of it.** It is superseded rather than
struck, because a reader who finds only this entry cannot tell a mistake from a change of mind, and it
was a change of mind made on better information.

**One thing `D52` decided survives untouched and is now doubly ruled:** the cup stays on breaks. The
handoff agrees — it replaces *"the compact-leading / minimal `timer` glyph"*, which is the focus glyph —
and the owner said so again in the same sentence that chose the handoff.

### IT OWES A SPIKE BEFORE IT OWES CODE, AND THAT IS `conventions.md`, NOT CAUTION

> *A decision about what another system can do is not ratifiable until something has run.*

**The handoff's fill is a claim about what a Live Activity can do**, and the agent's own analysis of it
has already been wrong once in twenty-four hours — first asserting that no self-driving mechanism exists
(false; `ProgressView(timerInterval:)` is one), then narrowing to the claim that no self-driving
mechanism exists *for a custom-shaped fill*, which is better reasoned and still unrun.

What is established: `Text(timerInterval:)` and `ProgressView(timerInterval:)` self-drive with no
pushes; a custom `ProgressViewStyle` reads `fractionCompleted` as `nil` for a timer-interval progress
view, so it cannot clip a shape to the fraction; and a widget's own views are rendered to a snapshot
rather than animated. **What is not established is whether the handoff's picture can be got anyway** —
the candidate construction is a *system* progress view rotated a quarter turn and clipped to the tomato's
body, which would make the system's own self-driving bar into a rising fill without the extension ever
computing a fraction.

**That is a thing to try, not to argue about**, and this delta is ratified on the *appearance* the owner
wants while the mechanism is explicitly unsettled. If the spike fails, the owner chooses between a fill
that steps at boundaries (which is `D52`'s version, already known to work) and something else. **The
delta does not license guessing**, and `F2f-T1` is the spike.

### Not in scope

The Lock Screen card, which the handoff leaves structurally unchanged · the sprint count, which the Lock
Screen already prints as *"2 OF 4"* · any `.update()` call, which the handoff forbids as plainly as `F2`
does — *"behavior unchanged (no `.update()` anywhere)"*.

---

## D56 — One set of block lengths: fitting writes the settings, and editing a setting wins back

**Proposed and Ratified by the owner 2026-09-28** — *"d56 is ratified"* — and **applied the same day**:
`F8b` takes position 16 of sixteen in `docs/specs/zenpom-v1.5.md`.

**IT WAS HELD AT `proposed` UNTIL THAT SENTENCE ARRIVED**, for the reason `D52` was held the day before:
ratifying it opens an unapplied amendment to a ratified baseline the agent may not edit, and
`AmendmentRatchetTests`' own comment is *"the agent may not fix a red ratchet, and that is why it
exists."* The instrument made the gap visible; it did not close it, and it was not supposed to.

Ruled after a sprint ran one pomodoro while the screen said four and Settings said six.

> *"1. live until replaced. 2. selecting fit the sprint should replace settings. clicking on settings
> and changing a setting should default to settings. 3. save to settings saves all the settings."*
> *"The sheet opens on a stored shape. and a use this shape button."*

**SUPERSEDES `F8`'s RULING B**, which said running a shape leaves `AppSettings` untouched and that
settings are written by the explicit *Save to settings* control and by nothing else.

### What was actually wrong, because the ruling is a response to a defect and not a preference

The owner's phone was running **one-pomodoro sprints**. Three numbers that should have agreed did not:
Settings said **6** pomodoros, the *Fit a sprint* sheet said **4**, and the timer ran **1**.

The one was right, in the sense that the app was honouring a fifteen-minute shape fitted days earlier —
which `D32` and `D49` say lives until replaced, correctly. What made it invisible was the rest:

- **The sheet opens on a sixty-minute budget and computes a fresh shape**, so it displayed a shape that
  was not the stored one and said nothing about the difference.
- **Fitting happened on a control *moving*, never on the sheet opening** — built that way deliberately,
  so that looking at the screen could not overwrite yesterday's shape. The cost was that *opening the
  sheet and pressing Save changed nothing at all*, which is what the owner did.
- **`Save to settings` writes three block lengths and not the pomodoro count**, so the one control that
  looks like it should reconcile the two could not.

**The agent flagged the display inconsistency in `docs/plans/F8.md` and under-rated it as cosmetic.** It
is not cosmetic: it runs a sprint nobody asked for, on a surface too coarse to show it — the sprint
indicator draws one hairline per pomodoro, so a one-pomodoro sprint is a straight line indistinguishable
from a divider.

### The ruling, in four parts

> **1 · A fitted shape replaces the settings.** *Fit a sprint* writes the block lengths **and the
> pomodoro count** into `AppSettings`. It is not a parallel authority; it is the calculator that sets
> them.
>
> **2 · Editing a setting wins back.** Changing any block length or the pomodoro count in Settings
> discards the stored run, and the app runs on settings from the next block. A settings edit is a
> statement that plain settings behaviour is wanted.
>
> **3 · `Save to settings` saves all the settings**, including `pomodorosPerSprint` — not the three
> block lengths only.
>
> **4 · The sheet opens on the stored shape**, not on a sixty-minute default, and a shape is committed
> by an explicit **Use this shape** button. Moving a control previews; it does not write.

### What this simplifies, and the one case it does not

**It removes the two-accounts problem at its source.** There is one set of block lengths, and whoever
wrote last owns them. The shape store stops being a second opinion about what a sprint is.

**The run does not disappear, and here is the case that keeps it.** An absorption preset can produce a
shape whose pomodoros are **not all the same length** — `ShapeScreenModel.pomodorosDiffer` exists for
exactly this, and `saveDetail` already warns *"this shape's pomodoros aren't all the same length; the
first one's length is what's written."* Settings hold one focus length and cannot express that, so a
shape with uneven blocks still needs its stored sequence. **Part 1 writes what settings can hold; the
run carries what they cannot.**

### What it reverses, said plainly rather than left for a reader to notice

- **`F8`'s Ruling B** — settings were deliberately read-only to the shape. Reversed.
- **The sixty-minute opening**, which the owner confirmed on the device on 2026-09-25 (*"Budget starts
  with 60… I think this is good"*). Part 4 reverses it, on better information: it was good until it was
  showing a different shape from the one that was running.
- **The implicit write on a control change**, introduced by `F8-T4` under note 1's ruling *"idle should
  update when the sprint is fitted."* Note 1's requirement survives — the idle timer must update the
  moment a shape is committed — but the trigger becomes the button rather than the picker.
  `ShapeScreenCopy.saveHint`'s promise, *"leaving this screen without pressing it changes nothing"*,
  becomes true of the whole screen instead of one control.

### ~~It owes a position in v1.5's order~~ — AUTHORISED AND APPLIED 2026-09-28

`F8` shipped `T1`–`T5`; this changes how a shipped feature behaves, which `conventions.md` calls a
retrofit rather than a new feature. **Adding it to `docs/specs/zenpom-v1.5.md`'s order edited a ratified
baseline and needed the owner's explicit waiver**, the way `D52` needed and got one. It arrived — *"d56
is ratified"* — and the order now carries `| 16 | F8b | … | M | yes — D56 |`. The rule stands; nothing
here licenses the next baseline edit.

### `D43` is not part of this and is already ratified

*"You can't change the pomodoro count on the screen — you have to go into settings. I think that needs
to be fixed."* That is **`D43`, ratified 2026-09-24 and never built** — the screen lets you set the
count, and refuses with a named floor when a count and a budget cannot both be honoured. It is unbuilt
work rather than a new decision, and it belongs in the same retrofit as this.

---

## D57 — The tomato fills by finished pomodoro after all, and the handoff's look is the target

**Proposed and Ratified by the owner 2026-09-29.** **Supersedes `D55`'s fill rule and restores `D52`'s.**
The appearance `D55` was ratified for is unchanged and is now stated more broadly.

> *"d52 original is the one i want."* · *"Stick with the originals designed in Claude Design — that is
> what I want the system to look like by the end of the 1.5 sprint."*

### The fill returns to `D52`: finished pomodoros, stepping at boundaries

`D55` chose the handoff's *"red fill rising from the base as the block elapses"*. **`F2f-T1` then ran it
and found that construction is the one thing that does not work** — a system progress view rotated,
scaled and clipped to the tomato's body drew nothing, while the same view left alone renders perfectly.
So the owner has returned to the rule they gave first.

**`D52` is restored rather than re-proposed.** Its text stands as written: the tomato fills **by finished
pomodoro**, in steps, and the cup stays on breaks. `D55` is superseded and kept, because it was not a
mistake — it was the right reading of a design document the agent had failed to open, and the thing that
overturned it was evidence rather than argument.

### WHAT THE RESEARCH SAYS, AND IT MAKES THE RULING THE EASY ONE

Apple's own `DynamicIsland` and Live Activities pages are JavaScript-rendered and return nothing to a
fetcher; the figures below come from secondary sources and are marked as such rather than presented as
Apple's words.

| Fact | Consequence here |
|---|---|
| Each compact region is roughly **60 × 36 points** — *"barely enough for an icon and a short label"* | A 26-point tomato fits with room. The fill must read at that size or not be drawn. |
| The **minimal** presentation appears only when more than one Live Activity is live | It is the *common* case on this owner's phone, not an edge — a Reddit activity took the slot for two days |
| The expanded view appears on long-press **and automatically for a couple of seconds after an update** | A boundary already produces that moment. The tomato's step lands exactly when the Island shows itself. |
| **"iOS animates content-state transitions itself; you cannot drive keyframes, and elaborate animations are dropped"** | **This is the sentence that settles it.** A smooth elapsed-time fill is an elaborate animation and was always going to be dropped. A stepped fill is a content-state transition, which iOS animates *for free*. |
| A Live Activity supports a tap and, since iOS 17, App Intent buttons — no drags, scrolling or swipes | Nothing here wants one; recorded so nobody proposes a control |

**So `D52`'s rule is not a compromise forced by a failed experiment.** It is the form that matches how
the platform actually updates a Live Activity: the fill changes when the content state changes, and the
content state changes at a block boundary, which is the only moment the app has anything new to say.

### The handoff's look is the target for the whole milestone

> *"Stick with the originals designed in Claude Design — that is what I want the system to look like by
> the end of the 1.5 sprint."*

`design_handoff_v1.5_upgrade/` is the visual target for v1.5: the tomato's geometry and colours, the
seven theme tables behind the existing `ColorRole`, the Ensō block style, and the Settings restructure.
Where the prototype and the repo's conventions differ, the handoff itself already defers — *"the repo's
conventions win"* — and that stands.

**ONE CONFLICT IS NAMED RATHER THAN SILENTLY RESOLVED, BECAUSE IT IS WITH A RATIFIED DELTA.** The
handoff's **garden** specifies a 14-day bed, a per-day count, and a **wilted stem on a zero day**. `D48`
forbids every one of those by name — *"it may not shrink, decay, reset, break, or read differently
because of when the poms happened, and it may not be shown per day"* — and the owner already chose
between them on 2026-09-24: *"go with F16's form."*

**This delta does not reopen that.** *The handoff's look* means its visual language — shapes, colour,
type, spacing. It does not mean its behavioural specifications where a later ratified delta has replaced
them. `F16`'s garden remains `F16`'s, drawn in the handoff's tomato.

### What it changes in the plan

`F2f-T1` is answered and `T3` builds the stepped fill, which needs **no self-driving view at all** — the
fraction is `completedInSprint / pomodorosPerSprint`, both already on the activity's attributes, both
already proven correct by `F8-T4` and by the owner's sprint indicator on the device. `F2f-M4`, written to
demonstrate that a computed fraction goes stale, is **withdrawn**: under a stepped rule a fraction that
holds between boundaries is correct rather than defective.

---

## D58 — Themes: a fixed, audited set, chosen in Settings

**Proposed 2026-09-30. Ratified by the owner 2026-10-02** — *"58 was ratified"* — as written,
with both riders below. Built under `F12` on the owner's instruction the same day —
*"let's build out the theme picker"* — and the PR asks for the word. This is the delta `F12`'s plan
called *the theme delta* and left unnumbered so the owner would allocate it; `F16` and `F17` no longer
contest the number.

> *"Tomato colors shouldn't ignore themes — the themes selected are based on real tomato colors; not
> just red."* — the owner, 2026-09-30

**Currently, `SPEC.md` line 58 (out of scope):** *…widgets beyond the Lock Screen Live Activity and a
watch-face complication showing the running block · themes · streaks, badges…*

**Proposed:** *…widgets beyond the Lock Screen Live Activity and a watch-face complication showing the
running block · user-authored or downloadable themes, and any colour the user picks by hand ·
streaks, badges…*

**And a new row in *Locked decisions*, after `Timer customization`:**

> | Theme | A fixed set of built-in themes — Auto, Sage, Ripen, Teal, Plum, Matcha, Ink — chosen in Settings
> and stored as the eighth `AppSettings` field. Each defines every colour role in **both** light and
> dark; light and dark still follow the phone, and a theme is not an appearance. Auto chooses by the
> clock and the season. The Lock Screen and the Dynamic Island follow the theme, the tomato included.
> No theme is constructed from data at runtime and no colour is chosen by hand. Every theme is held to
> the same contrast floors as the default: 4.5:1 for text, 3:1 for a control's boundary. Nothing else. |

**And a row in `definitions.md`:** **Theme** — a complete set of colours behind the roles the app
already names. Every theme defines both appearances; light and dark remain the phone's choice.

**A baseline correction rides with it.** `zenpom-v1.5.md` says the design system has *"42 semantic
colour roles"*. It had twenty when that was written and has twenty-three since `F2f`. `F12`'s cost
estimate rested on the figure, so the correction is owed here rather than made as a typo fix.

**What it moves, on the record.** `PolishFenceTests.noNewStoredShape`: `AppSettings` 7 → 8 fields.
`nothingFromTheParkedList` and `StatsFenceTests`' `\bTheme\b` keep guarding what stays refused — a
theme built from data — rather than being deleted because they fired. The `@Model` count stays 12 and
the `ColorRole` count stays 23: a theme is a new table behind the roles, not a new role.

**The two values that were adjusted, and why that is not fitting to the test.** Ripen's dark accent
measured 4.49:1 and Matcha's light subtle text 4.46:1. Each moved one step, once — the rule `F12`'s plan
proposed (*"adjusted once, then refused"*). Full measurements are in `docs/plans/F12.md`.

**Two things to ratify with it, both found by `F12`'s adversarial review and not settled by the owner:**

1. **A theme picked mid-block reaches the Lock Screen and the Island at the next block.** The handoff
   says *"applies instantly."* It cannot: AlarmKit's metadata is fixed once handed over, and this
   project pushes no updates to a Live Activity. The app itself repaints at once.
2. **An install that predates themes is on Auto**, the handoff's default — so the owner's phone turns
   Ripen in September daylight and Ink after 9pm without having chosen either. The alternative is
   Sage, one line.

**What ratifying the other way costs.** Refusing it refuses `F12`: the branch does not merge and the
seam stays unused.

