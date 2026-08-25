# F4c — the music state, in the place people look for it

**Retrofit on F4.** One screen change, one shared function, seven tests. No new
setting, no new type, no schema change, no new dependency.

## What happened

The owner went looking for whether ZenTomato could see their Apple Music
subscription. The four sentences that answer that question already existed and
were already correct — `MusicCopy.deniedFooter`, `restrictedFooter`,
`noSubscriptionFooter`, `couldNotBeCheckedFooter` — and every one of them was
already covered by a test.

They were drawn as a **footer beneath the library list**. On an account with a
few hundred playlists that is more than two minutes of scrolling. The owner
reached them by scrolling to the end deliberately, which is not a thing anyone
does twice.

> *"i scrolled for over 2 minutes to reach the end of the music screen to find
> the licensing/apple music issue. it took for EVER."*

**Copy nobody can reach is copy that does not exist.** The suite did not notice,
because every assertion tested the string and none tested the route to it. That
is the generalisable finding here, and it is what the new tests are shaped
around.

## What was built

**Settings gains a "Music" section**, immediately above Todoist:

- a trailing value answering the question first — *Ready*, *Not set up*,
  *Permission off*, *Restricted*, *No subscription*, *Couldn't be checked*
- the explanatory sentence underneath, in `MusicCopy`'s existing words

**The picker now calls the same function.** The obvious implementation was to
copy four strings across, which works on the day and drifts by the third edit —
somebody improves the subscription sentence on one screen and the app starts
contradicting itself about a fact. `MusicCopy.settingsFooter(for:)` is the single
source and both screens call it. A source-reading test keeps it that way, because
two identical copies of a string pass every behavioural test there is, right up
until they diverge.

## Why this is F4c and not preparation for v1.5

The owner's note: *"eventually, we'll allow spotify — that's a v1.5 issue, but
let's follow best practices."*

The best practice adopted is **the section, not an abstraction**. There is no
provider protocol, no `MusicService` enum, no second implementation waiting
behind a flag. The justification stands entirely on what already exists:
**Settings already holds Todoist's service state**, and this app's two services
should be legible in the same place and the same shape rather than each hiding
somewhere different.

Run `D16`'s test — *would I write this the same way if Spotify were never
coming?* — and the answer is yes, unchanged, because the reason is consistency
with Todoist. When v1.5 arrives it will find a section to add a row to, which is
a consequence of having done this right rather than the reason for doing it.

## Bounds held

- `AppSettings` stays at **six fields**. Nothing here is a setting; it is a
  report. A test asserts the section contains no `Toggle`, `Stepper`, `Picker`,
  `TextField`, `Button` or binding.
- The music **switch** stays on the timer screen, where `D19` puts the decision —
  before a sprint, not inside one.
- No token, model, protocol or `UserDefaults` key added; `PolishFence` unchanged
  and passing.
- Never amber, never a warning triangle. The music row's existing rule: this app
  being unable to play music is not a fault, and the timer is unaffected.

## Not in this change

**Search in the music picker.** The other half of the owner's note. That is new
functionality rather than a rearrangement of what exists, so it wants a spec
delta argued rather than assumed. Recorded as `O17`.

## Also fixed after adversarial review

### Second pass

- **The middle link of the wiring had no test at all.** `TimerView` →
  `SettingsView` → `SettingsForm`, with preview defaults on the last of the
  three, so the middle could be cut and everything stayed green.
- **`settingsShowsTheState` was blind to indentation**, so a section wrapped in a
  conditional passed as rendered. The realistic regression is not `if false` but
  a later tidy such as `if musicAvailability != .notAsked { music }`, which hides
  the row from exactly the person who needs it.
- **`settingsAsksAgainWhenItOpens` was a whole-file substring search** — the same
  defect the first review blocked on, reintroduced in the commit that fixed it.
  Comments are stripped now, and the refresh's position is checked.
- **The `.task` moved from the section to the form.** A `Form` is a `List`, so
  section lifetime is cell lifetime; the old comment claimed a scoping it did not
  have. This matches the picker's precedent.
- **The row said "Status" under a header saying "Apple Music"**, which was
  neither Todoist's shape nor what this plan claimed. It also left VoiceOver
  announcing "Status, Not set up" without naming the service.

### First pass

- The section had been inserted **inside Todoist's doc comment**, leaving a false
  description on the new code and none on the old. Same again in `MusicRowModel`.
- **Settings never asked again**, so it could report a state stale since launch —
  while `OPEN.md` advertises it as the faster way to answer `O14`. It now
  refreshes on appear, as the picker already did.
- **Header said "Music", row said "Apple Music"** — a category over a service,
  which was the one shape in the diff that read provider-shaped. Both now name
  the service, as Todoist's section does.
- `.notAsked` **shared `.ready`'s sentence**, so "Not set up" sat above a
  description of music playing. It has its own words now.

## Verification

```
check-lint.sh: swiftlint 0.65.1 --strict
check-lint.sh: OK — no lint violations.
run-script-tests.sh: 9 passed, 0 failed
✔ Test run with 468 tests in 70 suites passed after 4.739 seconds.
```

459 tests before, 468 after. **Mutation-verified twelve ways.** Each named test was
made to fail by breaking exactly the thing it claims to protect, then restored:

| Mutation | Test that caught it |
|---|---|
| M1 · Settings presented with `.notAsked` instead of the live value | `settingsIsGivenTheRealState` |
| M2 · The picker reaches past the shared function to its own constants | `thePickerAndSettingsCannotDisagree` |
| M3 · Two states given the same word | `theSixStatusesAreDistinct` |
| M4 · A status reading `Error!` | `nothingHereSoundsLikeAnError` |
| M5 · The section removed from the `Form` body, leaving it orphaned | `settingsShowsTheState` |
| M6 · Music placed below Todoist instead of above | `settingsShowsTheState` |
| M7 · The refresh removed from the section | `settingsAsksAgainWhenItOpens` |
| M8 · Settings handed the do-nothing preview refresh | `settingsAsksAgainWhenItOpens` |
| M9 · `.notAsked` reverted to the "ready" sentence | `theSixStatusesAreDistinct` |
| M10 · The middle link dropped — `SettingsView` stops passing either value on | `theMiddleLinkIsWired` |
| M11 · The section rendered conditionally, `if musicAvailability != .notAsked` | `settingsShowsTheState` |
| M12 · The refresh demoted to a comment | `settingsAsksAgainWhenItOpens` |

**M10, M11 and M12 are the second review's, and all three passed before it ran.**
The reviewer deleted two lines from `SettingsView`'s construction of the form and
watched 467 tests pass with the row reporting "Not set up" forever — the wiring is
three links long and both tests either side checked only the `TimerView` end.

**M5 was the reviewer's mutation, not the author's.** The first version of
`settingsShowsTheState` searched the whole file for a substring and would have
stayed green with the section unreachable — the exact defect this feature exists
to fix, reproduced inside the fix. See `docs/reviews/F4c.md`.
- **Device check outstanding:** open Settings on hardware and read the Music row.
  This is the same question as `O14` and closes with it.
