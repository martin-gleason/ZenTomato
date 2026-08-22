# ZenTomato

A Pomodoro timer for iPhone, built around three ideas:

- **Todoist is the only place tasks live.** ZenTomato reads your projects, sections and tasks and lets you attach one to a work block. The single thing it ever writes back is *"this task is done"*. It cannot create a task, edit one, or comment on one. A check runs on every commit that keeps this honest: it finds every Todoist address anywhere in the app's code and fails unless that address appears on a short, committed list. Adding to the list is a visible, reviewed change rather than something that happens by accident. (To be precise about what that check does and does not yet do: it enforces *which addresses* the app may contact, not *what it does* at each one — reading a task and creating a task share the same address. Closing that last gap is a written precondition on the Todoist feature, which has not been built.)
- **Apple Music is the sound.** You pick a playlist or a song you already own. It loops while you work and pauses while you rest.
- **The distraction log is the point.** While a block is running, two buttons record an interruption as it happens — *internal* (your own head) or *external* (someone else). At the end of the block the app asks for one sentence about each, which you can skip. The tally is what you read back later.

**This repository is at the very beginning of that.** What exists today is the skeleton: an app that launches, opens its on-device database, and shows a single screen with `25:00` on it and a Start button that is switched off. None of the three ideas above are built yet. Each one is a separate, agreed piece of work with its own plan in `docs/plans/`.

## Licence

GPL-3.0-or-later. The full text is in [`LICENSE`](LICENSE). In short: you may use, study, change and share this software, and anything you distribute that is built from it must be shared on the same terms.

## What you need

| | |
|---|---|
| A Mac running macOS 26 | |
| Xcode 26.6 or newer | Apple's development app, free from the Mac App Store |
| XcodeGen | `brew install xcodegen` — explained below |
| An iPhone simulator running iOS 26 | Installed through Xcode |

Two more tools are used by the checks. They are optional on your own machine — the checks will tell you clearly that they were skipped rather than pretending to pass — but they always run on the build server:

```
brew install swiftlint gitleaks
```

## Setting it up the first time

```bash
git clone <this repository>
cd ZenTomato

cp .env.example .env      # nothing to fill in yet — see below
make hooks                # switch on the checks that run before each commit
make generate             # build the Xcode project file
```

You do **not** need to fill anything into `.env` to build and run what exists today. Copying the template unchanged is enough: nothing in the app reads a credential yet, because the Todoist feature has not been built. When it is, the three Todoist keys become required and the build will stop and name whichever one is blank.

Then either open `ZenTomato.xcodeproj` in Xcode and press Run, or stay in the terminal:

```bash
make build                # compile the app
make test                 # compile it and run the automated checks
make lint                 # check the code style
```

### About `.env`

`.env` holds the credentials the app will eventually need to talk to Todoist. **It is never committed**, and a scan runs before every commit to make sure it never accidentally is. `.env.example` *is* committed: it lists which keys exist, with every value left empty, so the repository documents what is needed without ever holding a real one.

None of the keys are required today, and that is deliberate rather than lax. Nothing in this repository reads a Todoist credential — the feature that will does not exist. A skeleton that refuses to compile without a credential it never opens would mean nobody could build it, and the build server could never report green, which is the one thing this piece of work has to prove.

`make secrets` turns `.env` into a settings file Xcode can read. `make generate` and `make build` do this for you, so you rarely need to run it yourself.

### About `make hooks`

`make hooks` points Git at the checks in `.githooks/`. It is a single line, and you can run it by hand instead if you prefer:

```bash
git config core.hooksPath .githooks
```

This is the one manual step, and it is manual because Git deliberately refuses to run scripts from a repository you just cloned without being asked. Until you run it, nothing checks your commits locally — the build server still checks them, but you find out later rather than sooner. You only ever do this once per clone.

The checks are: the code style passes, no credential is about to be committed, and no forbidden Todoist request has appeared anywhere in the app's source. The test suite deliberately does **not** run here — it takes minutes, and a check that slow gets skipped within a day, taking the other three with it. Tests are the build server's job.

If a check stops you, the message says which one and what to do. Bypassing them with `git commit --no-verify` is possible but pointless: the build server runs the same three checks and will not let the change merge.

### Why there is no Xcode project file in the repository

The `.xcodeproj` you open in Xcode is **generated**, by `make generate`, from a plain text file called `project.yml`. The project file itself is deliberately not committed.

Two reasons, both practical. First, an Xcode project file is thousands of lines of machine-written bookkeeping; nobody can review a change to it, so committing it means every change to the app's structure arrives invisibly. `project.yml` is about a hundred readable lines, and a change to it is legible in a pull request. Second, the build server regenerates the project from `project.yml` on every run — which proves that file actually works, where committing a project file would prove nothing about it.

The cost is the one line above: run `make generate` after cloning, and again after adding or removing a file.

## Repository layout

```
ZenTomato/          the app's source code
  App/              what runs at launch, and where the database is opened
  Models/           what the app stores
  Views/            the screens
  DesignSystem/     the colours, spacing, corner radii and type sizes
  Resources/        the app icon
ZenTomatoTests/     automated checks
scripts/            the checks that run before a commit and on the build server
docs/
  specs/            what is being built, and why — the contract
  plans/            how and when, one file per piece of work
  reviews/          the record of each piece of work being picked apart
project.yml         the readable definition of the Xcode project
Makefile            every command above
```

## The design system

Colours, spacing and type sizes are not written into the screens. They live in `ZenTomato/DesignSystem/` in two layers: a set of raw colour ramps, and a set of *roles* built on top of them — "the page", "the ink on a button", "the boundary of a control". Screens may only name a role.

That indirection is what makes light and dark mode work without a single `if dark` anywhere in the app, and it is what makes the accessibility measurements checkable. The automated checks confirm that every text colour the design system audits clears the required legibility ratio against the page and against a raised card, in both light and dark, and that no colour role can be added without being measured.

One pairing is deliberately exempt, and it is named in the tests rather than quietly dropped: the label on a switched-off control, which measures 4.13:1 in light against the 4.5:1 the standard asks for. The standard exempts controls that are switched off, and the disabled Start button on the timer screen is exactly that case. The outline that draws that button is held to a separate 3:1 floor and clears it in both appearances — which matters, because the outline is the only thing that makes a switched-off button visible at all.

If a colour is changed and something becomes hard to read, the checks fail before anyone sees it.

There is no theme picker, and there will not be one. Light and dark follow the phone's own setting.

## Contributing

This is a personal project on a fixed timetable, developed by one person reviewing one agent's pull requests. Every change goes through a pull request, the automated checks have to pass, and every piece of work is picked apart by a hostile second read before it merges. `docs/specs/SPEC.md` is the contract and is not edited casually; if something is not in it, it is not built.
