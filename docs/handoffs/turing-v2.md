# Turing v2 — a handoff about how the work goes wrong

**For:** any session working this corpus under `docs/conventions.md`.
**From:** the ZenPom session of 2026-09-15, which lost roughly half its length to backtracking and
wrote this instead of pretending it hadn't.
**Status:** durable process context. **Not** a spec, **not** a plan, **not** a register. Where this
and the repo disagree, the repo wins.

**What it is for.** `conventions.md` says what the process *is*. The registers say what was *decided*.
Neither records **how a session actually fails**, so every session rediscovers the same failures at
its own expense. This file is the record of the failure modes themselves — each one written the day it
happened, with what it cost and the check that would have caught it.

**The standing rule it exists to serve:** *Turing learns by promotion, not by memory.* A session
retains nothing once it ends. A failure not written down is a failure the next session will repeat.

---

## How to use this file

Read it at session start, after the repo state and before the first edit. Add to it when a session
backtracks. **A backtrack is the trigger** — not a bug, not a failed test, but the moment work already
done has to be undone. That is the observable, and it is cheap to notice.

Each entry: what happened · what it cost · the check that catches it. **No entry without a check** —
an entry that only says "be careful" is a wish, and the corpus already knows that wishes do not hold.

---

## 1 · Read the repository before believing the repository's own description of itself

**What happened.** The session opened by reading `CLAUDE.md` and the newest handoff, and announced that
the project had no scope fence and had blown a hard stop two days earlier. Both statements were wrong.
`docs/specs/zenpom-v1.5.md` — ratified six days before, naming eleven units, replacing the date with a
condition — was sitting unread in `docs/specs/`.

**Why it was not obviously wrong.** `CLAUDE.md` is the file loaded into every session automatically. It
said *"Scope is `SPEC.md` F1–F6 and nothing else"* and *"Hard stop September 13, 2026."* It had been
superseded and nobody had updated it. **An auto-loaded stale file outranks an accurate file nobody
opens.**

**What it cost.** An opening message that told the owner their project was out of control, and a
correction two turns later.

**The check.** At session start, `ls docs/specs/` and read **every** file in it before making any claim
about scope, stop conditions or what is in flight. The directory is the authority; `CLAUDE.md` is a
pointer, and pointers go stale. Where a project's own documents disagree, **say they disagree** rather
than believing the one that loaded itself.

---

## 2 · Look for existing work before doing the work

**What happened.** Asked to update `CLAUDE.md` to match v1.5, the session hand-wrote a full rewrite,
allocated chore ID `C27` for it, and added a register row. **All of that already existed**: branch
`C27/standing-docs-after-the-rescope`, three commits, a 277-line `docs/chores/C27.md`, and **PR 41,
open for four days.** The ID was allocated twice.

**Worse than duplicated — wrong.** The hand-written version encoded the stop condition as *"four
consecutive fortnightly Rhodia reviews"*, which `D35` had superseded two days earlier with *"released,
approved, and sent via TestFlight."* The duplicate would have put a dead stop condition into the file
every session reads. The real branch had it right.

**What it cost.** A full document written and reverted, an ID collision, and the loss of a 277-line
chore rationale that would have been silently superseded.

**The check.** Before writing anything with an ID in it, and before starting any named unit of work:

```
git branch -a          # is someone already on this?
gh pr list --state all # has this already been argued?
git log --all --oneline --grep '<ID>'
```

**Three commands, ten seconds.** This is the cheapest check in the file and it prevented nothing
because it was not run.

---

## 3 · An ID may not be cited before the thing it names exists

**What happened.** Twice in one session, from opposite directions.

The owner added a `D35` row to `00-deltas.md`'s index on the feature branch. The `## D35` section lives
on a *different* branch. `DeltaIntegrityTests.everyCitedDeltaIsDefined()` went red.

Then the agent, correcting a plan header and a register row, cited `D35` as the superseding decision —
on the same branch, for the same reason. Red again, same test, and the failure text named all three
citing files.

**What it cost.** Two red suites, roughly twenty minutes of build time, and one green branch turned red.

**The check.** `DeltaIntegrityTests` already catches it — the lesson is not to add a check but to
**believe the one that exists.** Operationally: a decision's *definition* and every *citation* of it
travel in the same change, or the definition lands first and the citations rebase onto it. When a
document on branch A needs to cite something defined on branch B, **branch B merges first**. That is
not tidiness; it is enforced by a test that will not let it be otherwise.

---

## 4 · A rule that says "only the owner may do this" still has an owner who can say "do it"

**What happened.** `D35`'s one-line amendment to `SPEC.md` was blocked on the owner, because five
separate documents say the agent never edits `SPEC.md` — `CLAUDE.md`, `zenpom-v1.5.md`,
`conventions.md`, `AMENDMENTS-TO-APPLY.md`, and the failing test's own doc comment. The agent reported
the blocker and stopped.

The owner then made the edit — **in the wrong two files**, because the instruction named the outcome
rather than the exact file and line, and the nearest plausible files were the ones already being
discussed. The test stayed red. When told it was still red, the owner said *"revert d35 and fix it"*,
and the agent **still** hedged, offering to prepare a patch for the owner to apply. The owner's reply:
*"why am I re-editing? this feels like an extra step."*

**The disagreement, stated properly.** `conventions.md` already has the rule for this —
*"when a rule and the need disagree, name the disagreement and ask."* The session named it and asked,
which was right. **What was wrong was asking twice.** An instruction to fix a thing is an answer, and
treating it as insufficient because five documents disagree makes the owner argue with their own repo.

**The distinction that resolves it.** *Deciding* what the contract says is the owner's, always. *Transcribing*
an already-ratified decision whose replacement text is pre-written verbatim is not a contract decision.
The prohibition exists so the agent cannot change scope unilaterally — not so a two-line paste needs
two rounds of approval.

**The check.** When a prohibition blocks a mechanical step: name it once, state what you would do, and
**act on the owner's answer the first time.** Record the exception in the commit message — quoting the
ratification and the instruction — so the record shows a deliberate waiver rather than a rule quietly
eroding. A rule that erodes silently and a rule the owner suspends on the record need opposite fixes,
and only the second one leaves evidence.

---

## 5 · A wrapper's exit code is not the build's exit code

**What happened.** A backgrounded `make test` reported *"completed (exit code 0)"*. The session read
that as a pass and said so. The actual tail of the output was `make: *** [test] Error 65`, with one
failing test. The `0` was the harness wrapper exiting cleanly, not the build succeeding.

**What it cost.** One incorrect statement to the owner, self-corrected a minute later. Cheap this time
because the claim was checked. It would not have been cheap if the next step had been a merge.

**The check.** **Never report a test result from an exit code.** Read the run's own summary line —
`Test run with N tests … failed after …`, `Failing tests:`, `** TEST FAILED **`, `make: *** Error` — and
quote the counts. `conventions.md` already requires the output in the PR rather than an assertion; this
is the same rule applied to the session's own reading. A count is evidence. A zero is a wrapper.

---

## 6 · A generated file that no generator generates

**What happened.** `docs/plans/00-status.md` opens with
`<!-- GENERATED by scripts/gen_status.py — do not edit by hand. -->` and names a CI check.
**`scripts/gen_status.py` has never existed** — not in the working tree, not in 350 commits, not in any
branch — and nothing in `.github/`, `scripts/` or `.githooks/` references it or the file it claims to
produce.

So the project's single status artifact is hand-written prose wearing a generated file's header. That
is why it reported `F8` as *"plan written, awaiting the gate. No code has been written"* for six days
after six `F8` commits reached `main`: nothing was ever going to correct it, and its header told every
reader not to.

**What it cost.** A status page that misreported the project's most active feature, believed by every
session that read it.

**The check.** A file claiming to be generated must name the command that generates it, and **that
command must run.** This is `conventions.md`'s *"a hook that has never failed is a hook nobody knows
works"* applied to documents: a header asserting automation is a claim, and an unrun claim is decoration.
Tracked as `O42`; the two honest fixes are *write the generator* or *strip the header*, and choosing
between them is the owner's.

---

## 7 · Two places to look is one place too many

**What happened.** Outstanding items live in both `docs/plans/00-register.md` and
`docs/reviews/OPEN.md`, and they disagree.

**CORRECTED 2026-09-16.** This entry first said *"the register runs to `O40`; `OPEN.md` stops at
`O35`; they drifted five items apart."* **That was wrong, and it was wrong in the direction that makes
the problem look small.** `C29` measured it: 16 of `OPEN.md`'s 35 `O` ids are absent from the register
entirely, plus 83 lines of prose it has no column for — and two adversarial reviews then found the
register is also missing 36 of 37 decisions, six chores, and the `M`, `H` and `RR` registers whole.
The drift is four-dimensional, not five items. See `docs/handoffs/blockersfor1_5.md`.

**Left in place rather than deleted, because the correction is the lesson.** This paragraph was
written confidently, from one `sort | tail` of each file, and it is the first thing a resuming session
reads. It then survived two more sessions. A handoff is an artifact that makes claims, and it is worth
exactly as much as the mechanism that would catch it being wrong — which for this file is nothing.

**The irony, recorded because it is instructive.** `OPEN.md` was *created* to solve exactly this: six
review logs with a *Still open* section each, and no way to answer "what is outstanding" without
reading all six. The aggregate was the right idea and it became a seventh place to look, because
nothing generates it from the register.

**The check.** `conventions.md` is explicit — one intake path. An aggregate view is legitimate **only
if it is generated**; maintained by hand it is a second source of truth, and second sources of truth
drift by construction, not by carelessness. Tracked as `O44`.

---

## 8 · Fixing a defect that cannot happen yet, in the wrong task

**What happened.** The working tree held a guard added to `openShape()` against a shape being saved
over a sprint in flight. The harm was real *in principle* and unreachable *in fact*: the function that
would start a shaped sprint has no callers, because the task that adds them is unbuilt. Meanwhile the
guard installed a real lockout for the moment that task lands — a visible, enabled, VoiceOver-labelled
button that silently does nothing, with no way to clear the state.

Its test asserted that a specific line of source text appears in a file. It stays green if the line
moves below the statement it guards, or is pasted into any other function.

**The check.** Two questions before any defensive change:

1. **What is the executable trigger, from real inputs, today?** If the answer is "once feature X
   lands", the change belongs to feature X — with X's other half, which here was the stale-state
   discard that makes the guard survivable.
2. **Would this test fail if the code were wrong?** A test that greps source text answers "is this
   string present", which is not the question. Put the predicate on a seam that can be called.

---

## The shape of all eight

Seven of these are one failure wearing different clothes: **a document, an ID, a header or an exit code
was believed because it was in front of the reader, and nothing had ever tested whether it was true.**
A stale `CLAUDE.md`, a duplicate `C27`, a generated file with no generator, an aggregate nobody
generates, a wrapper's zero, a grep pretending to be a test.

`conventions.md` already names the principle — *a test that has never been shown to fail is not
evidence* — and this session shows it is not only about tests. **It is about every artifact that makes
a claim.** The register, the status page, the plan header, the handoff you are reading: each asserts
something, and each is worth exactly as much as the mechanism that would catch it being wrong.

The eighth — the one about the owner and the rule — is the opposite failure and worth keeping separate:
**a check applied where no check was needed**, costing the owner two round trips on a two-line paste.
Rigor pointed at the wrong target is not free either.

-----
September 15, 2026

#AI/Claude
