# F4d — the music row speaks Todoist's language

**Retrofit on F4c**, which shipped this morning. Two words, one sentence, two
tests. Found by the owner on the device inside a minute of opening the screen.

## What was wrong

**1. The row said `Ready`.** Todoist's row, four lines below it, says `Connected`
/ `Not connected`.

F4c's entire argument was consistency — *Settings already holds Todoist's state,
so music belongs beside it, in the same place and the same shape*. And then it
described the same kind of thing in a different dialect. The argument was made
and then not carried into the words, which is the part a person actually reads.

Nobody invented `Ready` for a reason. It was invented because the vocabulary that
already existed four lines away was not looked up.

**2. There was no way to undo it.** The owner went looking for how to disconnect
Apple Music and found nothing.

The app knew the answer the whole time. `deniedFooter` names *Settings ›
Privacy & Security › Media & Apple Music* — so somebody who had **refused**
permission was told where to change their mind, and somebody who had **agreed**
was told nothing at all. That is exactly backwards: the second is the one looking
for a way out.

Todoist's section has a way out on it, a sign-out button. This one had none.

## What was built

- `.ready` → **`Connected`**, `.notAsked` → **`Not connected`**. Todoist's words.
- `readyFooter` gains the sentence naming where the permission is taken back —
  the same path `deniedFooter` already names, so the app cannot end up giving two
  different directions to one switch.

**No button, and deliberately no button.** MusicKit permission cannot be revoked
from inside an app; iOS owns that switch. A deep link would be new machinery for
something the platform already does, and the honest equivalent of Todoist's
sign-out is naming the place. A sentence is the whole fix.

## Bounds

`AppSettings` still six. No token, model, protocol, `UserDefaults` key, or new
control. `PolishFence` unchanged and passing.

## Verification

```
check-lint.sh: swiftlint 0.65.1 --strict
check-lint.sh: OK — no lint violations.
run-script-tests.sh: 9 passed, 0 failed
✔ Test run with 470 tests in 70 suites passed after 3.794 seconds.
```

468 before, 470 after. Three mutations, each caught and restored:

| Mutation | Test that caught it |
|---|---|
| M13 · `.ready` reverts to the invented `Ready` | `theVocabularyIsTodoistS` |
| M14 · Todoist renamed to `Signed in`, music left behind | `theVocabularyIsTodoistS` |
| M15 · The way out removed from the connected footer | `aConnectedServiceSaysHowToDisconnect` |

**M14 is the one worth keeping.** `theVocabularyIsTodoistS` reads Todoist's words
out of `SettingsView.swift` rather than hard-coding them, so the two rows cannot
drift apart later either — rename one and the test fails until the other follows.
A test that hard-coded `"Connected"` would have passed M14 while the screen once
again spoke two dialects.

## Device check

Open Settings → Music. The row should read **Connected**, matching Todoist's four
lines below, and the text underneath should say where to take the permission back.
