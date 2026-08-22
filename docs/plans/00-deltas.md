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

## D6 — Secrets live in `.env`; `Secrets.xcconfig` becomes a generated artifact

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

**Note on what this does and does not protect.** `.env` keeps the secret out of *git*. It does not keep
the Todoist client secret out of the *built app* — you ratified that trade in the auth decision, and it
is acceptable only because this build is never distributed. If ZenTomato is ever shipped to anyone
else, the client secret must move behind a token-exchange service and this note becomes a blocker.

---

## Chore status (recorded 2026-08-21)

- **C1** (repo, LICENSE, branch protection) — **done**
- **C2** (minimum iOS, developer account, App ID with MusicKit) — **done**; answer is iOS 26 / watchOS 26, see D1
- **C3** (Todoist OAuth app registered, credentials placed) — **done**; credentials in `.env`, see D6
- **C4** (install builds on the iPhone) — deferred to beta. **This gates the device checks in F2, F3, F4, and F7.**
- **C5** (fixed afternoon PR-review slot) — deferred to beta

C4 being deferred means F2, F3, F4, and F7 can each be built and unit-tested to completion but **cannot
close their gate**, because every one of their *Done when* clauses is a device check. Those features
will queue in a `verified-pending-device` state until C4 lands. Front-loading C4 is the single highest-
leverage thing you can do for the September 13 stop; leaving it to beta means discovering four features'
worth of device-only bugs in one sitting.

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
