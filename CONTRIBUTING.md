# Contributing to ZenPom

**Read this before opening a pull request. There is one condition, and it is
unusual enough to be worth a page.**

> **DRAFT — the owner has not yet ratified these terms.** `O22` is the open
> decision. Everything below is the agent's proposal for what `C18` needs; it is
> not in force until the owner says so, and it is a legal instrument rather than a
> style guide.

## The condition

By opening a pull request you grant Martin Gleason a perpetual, irrevocable,
worldwide, royalty-free licence to use, modify and **relicense** your
contribution, including under licences other than the GPL.

You keep your copyright. You are granting a licence, not signing it away.

## Why, in plain terms

This project licenses two things two different ways:

- the **source**, here, under **GPL-3.0-or-later**
- **binaries** distributed by the copyright holder, under the **MIT License**

That is only possible while one person holds copyright in all of it. **The moment
a contribution is merged under the GPL alone, that contributor's copyright is in
the tree, and the binary can no longer be licensed under anything else without
their permission.**

This is not hypothetical. VLC was removed from the App Store in 2011 after a
developer who had written much of it — and who had contributed it under the GPL —
asked Apple to take it down. The removal was not Apple auditing licences. It was a
rights holder objecting, and being entitled to.

**So the terms are here in advance rather than raised after your work is done.**
Declining a pull request for licensing reasons once it exists is a worse
conversation for everyone than a paragraph read beforehand.

## If that is not acceptable

That is a legitimate position and the project would rather hear it early. The
source is GPL-3.0-or-later: fork it, change it, distribute it on those terms. You
need nobody's permission and you owe nobody a licence grant.

## Before you open one

- `make ci` passes — lint, the Todoist allowlist, the secret scan, the shell
  tests, the full test suite, and a warning-free Release build
- Commits follow `docs/conventions.md`
- If it changes behaviour the contract describes, it needs a delta in
  `docs/plans/00-deltas.md` first — see the gate in `conventions.md`
