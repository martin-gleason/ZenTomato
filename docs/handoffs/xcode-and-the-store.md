# Making a change here, in Xcode, and at the App Store

**Written 2026-09-24, for `C26` and everything after it.** Three surfaces, three different owners,
and one rule that decides almost everything.

---

## The rule, before anything else

> **`ZenTomato.xcodeproj` is generated and git-ignored. Xcode must never be used to change a build
> setting, a capability, a target, a file membership, or a name.**

`make generate` rebuilds the project from `project.yml` with XcodeGen, and it runs as a dependency of
`make test`, `make device`, `make check-release` and `make ci`. **Anything changed through Xcode's
inspector survives until the next of those, and then vanishes** — silently, with no diff, because the
file is not in git.

That is the whole drift risk. It is not a style preference: a setting changed in Xcode is a setting
that will be lost, and the loss looks like the change never worked.

**So Xcode is for building, running, archiving, and reading. `project.yml` is for deciding.**

---

## The three surfaces

| Surface | Lives in | Who can change it | Survives `make generate`? |
|---|---|---|---|
| **Code, build settings, capabilities, names** | `project.yml`, `Config/*.xcconfig`, source | **Claude Code, here** | yes — it is the source |
| **Signing certificates, provisioning, archive, upload** | Xcode + the developer portal | **Xcode / the owner** | n/a — not in the project file |
| **The store listing: app name, description, screenshots, privacy answers** | App Store Connect | **the owner only** | n/a — not in this repository |

**Two things that look like they belong in the middle column and do not.** `DEVELOPMENT_TEAM` lives
in `Config/Secrets.xcconfig` (git-ignored, already set). Provisioning is handled by
`-allowProvisioningUpdates` in `scripts/install-device.sh`, so Xcode creates profiles without anybody
visiting the portal — **except for capabilities**, which is why `O40` (the App Group) is an owner item.

---

## The change in hand: `C26`

**The App Store rejected *ZenTomato*.** The established facts, from `docs/chores/C26.md` and re-read
from the built artefact on 2026-09-24:

```
$ /usr/libexec/PlistBuddy -c 'Print :CFBundleName'        .../ZenTomato.app/Info.plist
ZenTomato                 ← the problem
$ /usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' .../ZenTomato.app/Info.plist
ZenPom                    ← already right, since C9b
$ /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier'  .../ZenTomato.app/Info.plist
com.martingleason.ZenTomato   ← DO NOT TOUCH
```

**Read out of the artefact, not out of `project.yml`.** The source says `$(PRODUCT_NAME)`; only the
built plist says what that expands to.

### The one thing that must not happen, in either tool

> **Do not change `PRODUCT_BUNDLE_IDENTIFIER`.**

A bundle identifier is an identity, not a name. Changing it means a new App ID, a TestFlight lineage
starting from zero, and — the one that matters — **a new container on the device, which orphans the
SwiftData store holding the distraction log.** `O1` is *one real day's export, read beside the
Rhodia*; it is the first of the four reviews the v1.5 spec ends on, and **it has never been run.**
Changing the identifier destroys the data `O1` needs before `O1` has happened.

`com.martingleason.ZenTomato` shipping an app called ZenPom is ordinary and thousands of apps do it.

**This is the single most likely drift.** Xcode offers to rename a project, and its rename touches
the identifier. Do not accept it.

### What the change actually costs, which is more than one line

`PRODUCT_NAME: ZenPom` renames the bundle on disk from `ZenTomato.app` to `ZenPom.app`. Three scripts
named that file literally:

- `scripts/install-device.sh` — would have failed with *"the build succeeded but produced no .app
  bundle"*, the exact misleading message `C38` was fixed to stop printing
- `scripts/check-musickit-entitlement.sh`
- `scripts/check-watch-provisioning.sh`

**All three now discover the bundle instead of naming it** (done 2026-09-24, this commit). That was a
prerequisite, not a tidy-up: it is what makes the rename a one-line change.

---

## The plan, in the order that wastes least

| # | Step | Owner | Blocked on |
|---|---|---|---|
| 1 | Scripts stop hardcoding the bundle name | agent | **done** |
| 2 | **Read the rejection and say what it named** | **owner** | nothing — this gates everything |
| 3 | `PRODUCT_NAME: ZenPom` in `project.yml`, app target only | agent | step 2 |
| 4 | Verify `CFBundleName` **out of the rebuilt artefact** | agent | step 3 |
| 5 | Update the App Store Connect record | owner | step 2 |
| 6 | Archive and upload | Xcode / owner | steps 3–5 |

**Step 2 gates the rest and cannot be guessed.** Each possible answer points somewhere different:

- *"the app name in App Store Connect"* → step 5 only; the binary is fine.
- *"the binary's name / CFBundleName"* → steps 3 and 4.
- *"the bundle identifier"* → **a different chore with a data migration in it, and it owes a delta.**
  Nothing above applies.
- *"the icon / screenshots / metadata"* → none of this; a new chore.

Doing step 3 before step 2 is cheap and probably right, but it is still a guess, and `C26` says in as
many words that a find-and-replace is the wrong response to a rejection nobody has read.

---

## Handoff to Claude in Xcode

**Your job is to build, archive, upload and report. You do not decide anything about names.**

### Never do these

1. **Never change a setting in the Project or Target inspector.** It is regenerated from
   `project.yml` and your change will disappear. If a setting is wrong, say so and stop — the change
   is made here, in `project.yml`.
2. **Never accept Xcode's offer to rename the project or a target.**
3. **Never change the bundle identifier**, for any reason, including to make a signing error go away.
   If signing fails, report the exact error. See the box above for what it would destroy.
4. **Never add or remove files through Xcode.** File membership comes from `project.yml`'s source
   globs; a file added in Xcode is not in the project after the next `make generate`.
5. **Never commit `ZenTomato.xcodeproj`.** It is git-ignored deliberately.

### Do these

**Before anything, regenerate so you are looking at the real project:**

```
cd /Users/marty/Local_Dev_Projects/ZenTomato
make generate
```

**To confirm what the binary is actually called** — the question `C26` turns on. Read the artefact,
never `project.yml`:

```
make check-release
/usr/libexec/PlistBuddy -c 'Print :CFBundleName' \
  DerivedData/Build/Products/Release-iphoneos/*.app/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' \
  DerivedData/Build/Products/Release-iphoneos/*.app/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
  DerivedData/Build/Products/Release-iphoneos/*.app/Info.plist
```

**The glob is deliberate.** After step 3 the bundle is `ZenPom.app`; before it, `ZenTomato.app`.
Writing either name is how this breaks.

**To install on the phone** — use the script, not Xcode's Run button, because the script picks the
physical device and explains every failure:

```
./scripts/install-device.sh
```

**To archive for the store:**

```
xcodebuild -project ZenTomato.xcodeproj -scheme ZenTomato \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/ZenPom.xcarchive archive -allowProvisioningUpdates
```

Then upload through Xcode's Organizer, **or** report the archive path back here and let the owner do
it. Uploading is the owner's call: it is outward-facing and cannot be undone.

### Report back with

- The three plist values, pasted, from the rebuilt Release artefact.
- Any signing or provisioning error, **verbatim** — not summarised, and not worked around.
- The archive path, if you made one.
- **Anything you were tempted to change in the inspector**, and what it was. That is the highest-value
  thing you can tell us, because it names a setting that belongs in `project.yml` and is not there.

---

## What this repository already enforces, so you need not check it by hand

`make checks` runs ten gates including `swiftlint --strict`, the Todoist endpoint allowlist, a secret
scan, the register validator, and 47 script tests. `make ci` adds the 660-test suite and the Release
build. **A change that passes `make ci` has not broken anything these gates cover** — and the gates
cover the naming surfaces badly, which is why `C26-T4` proposes an assertion that reads `CFBundleName`
out of the artefact.

-----
September 24, 2026

#AI/Claude
