# Alert sound candidates

For `D24`. **The owner sources; the agent verifies the licence and builds the
mechanism.** Nothing here is bundled yet.

Every entry records what the attribution fence will assert: a name, an author, a
source URL and a licence. `D24`'s ruling is that **every sound is attributed with
a link**, which is stricter than CC0 requires and applies regardless of licence.

## Verified

| Sound | Author | Licence | Source |
|---|---|---|---|
| small bell_2.wav | 15HVojta_Michael | **CC0** | https://freesound.org/people/15HVojta_Michael/sounds/462044/ |
| Bell0005.WAV | fmiramar_ | **CC0** | https://freesound.org/people/fmiramar_/sounds/397349/ |

**Both licences were read off the pages rather than assumed**, which is the check
that matters: Freesound hosts CC0, CC-BY **and CC-BY-NC** side by side, and a
non-commercial sound is unusable here — the App Store is a commercial channel,
whatever the app costs. CC0 also means neither is a `C10` problem: no GPL-licensed
asset enters a differently-licensed binary.

## One thing to check before either is bundled

**`Bell0005.WAV` is 41.7 seconds long.**

iOS caps custom notification sounds at **30 seconds** — `UNNotificationSound`'s
documented limit, and `AlarmKit` takes its sound as
`ActivityKit.AlertConfiguration.AlertSound.named(_:)`, which resolves a bundle
file the same way. **Whether the same 30-second cap applies to an AlarmKit alert
is not something to assume** — three framework assumptions have already been wrong
this week — but a file that long is a problem either way:

- if the cap applies, it is silently rejected or truncated
- if it does not, it is an alarm that runs for forty seconds

An alert sound wants to be **one to five seconds**. `small bell_2.wav` at 5.08s is
already the right shape; the other wants trimming to its first strike, which is
also the part that sounds like a bell rather than a decay.

Both are `.wav`. iOS wants CAF, AIFF or WAV, so no conversion is strictly needed —
though `afconvert` to CAF is what `Silence.caf` already does and keeps the bundle
consistent.

## Still wanted

`D24` is a *picker*, so one sound is not a feature. Two bells are two variations
of one idea; a third and fourth that are **different in kind** — something soft and
wooden, something like a chime or a singing bowl — would give the setting a reason
to exist.
