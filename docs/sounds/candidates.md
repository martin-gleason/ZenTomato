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

## What shipped, and exactly how it was made

**Built 2026-08-28.** Both files were already in the tree — untracked, at the
repository root, downloaded 2026-08-27 09:09. An earlier draft of `O23` said the
agent could not fetch them and the owner would have to; that was written after a
`curl` returned Freesound's login page, and it was wrong about the tree. The
adversarial reviewer found the files sitting there.

The raw downloads now live in `docs/sounds/sources/`, which is git-ignored: 17 MB
of WAV produced 690 KB of CAF, and the CAF is what ships. These two commands are
what makes that reproducible without carrying the sources.

**`SmallBell.caf`** — 462044, 15HVojta_Michael, CC0. 5.08 s, already the right
shape, so nothing is cut. Lifted 8.8 dB because the source peaks at −9.8 dBFS and
an alarm wants to be heard, and faded over the last 0.4 s so the file ends rather
than stops.

```
ffmpeg -i 462044__15hvojta_michael__small-bell_2.wav \
  -af "volume=8.8dB,afade=t=out:st=4.68:d=0.4" -ac 1 -ar 44100 -c:a pcm_s16le SmallBell.wav
afconvert -f caff -d LEI16@44100 SmallBell.wav ZenTomato/Resources/SmallBell.caf
```

**`StruckBell.caf`** — 397349, fmiramar_, CC0. **The trim this document asked
for.** The source is 41.7 s of repeated strikes; measured with `astats` at 0.5 s
resolution, the first strike begins at 1.10 s and the second lands at 3.75 s. The
cut is 1.05 → 3.70 with a 0.5 s fade, so the file ends on the first strike's decay
and never on the next hit. 2.65 s.

```
ffmpeg -ss 1.05 -t 2.65 -i 397349__fmiramar__bell0005.wav \
  -af "volume=10.0dB,afade=t=out:st=2.15:d=0.5" -ac 1 -ar 44100 -c:a pcm_s16le StruckBell.wav
afconvert -f caff -d LEI16@44100 StruckBell.wav ZenTomato/Resources/StruckBell.caf
```

Both are mono 44.1 kHz Int16 CAF, matching `Silence.caf`'s family, both peak at
about −2 dBFS so neither is louder than the other, and both are far inside the
30-second cap this document worried about.

**Trimming and normalising make these derivative works, which CC0 permits without
condition.** The credits in `AlertSound` name the original authors and link to the
original sounds regardless — `D24`'s ruling is stricter than the licence, and a
derivative is still somebody's bell.

**Still wanted, unchanged:** a third sound *different in kind* — something wooden,
a chime, a singing bowl. Two bells are two variations of one idea. That is the
owner's choice, not the agent's.
