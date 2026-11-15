---
name: triage
description: Move PokeTactics GitHub issues through the board's Status columns (Triage, Blocked, Accepted, In Progress, Needs Playtest, Shipped), set type and area labels and Waiting on, verify, grill if needed, and write agent briefs when asked.
disable-model-invocation: true
---

<!-- Adapted from mattpocock/skills (landing-skills/triage, the untouched original). Changes: board and labels mapped
to this repo, state kept on the board instead of status labels, PR handling and the setup-skill dependency removed,
domain-modeling step removed, out-of-scope moved to docs/out-of-scope/, disclaimer dropped. Hook and permission
rules: CLAUDE.md "Git and GitHub". Board design: 2026-11-15-project-board. -->

# Triage

Move issues on the GitHub tracker (Jess-Rivera/poketactics, board "PokeTactics" = project 3) through a small state
machine. Jess is the maintainer and, for now, the only reporter.

Triage comments carry no AI disclaimer. Follow CLAUDE.md prose style (no em-dashes) in everything posted.

## Reference docs

- [AGENT-BRIEF.md](AGENT-BRIEF.md): how to write a brief, only when asked (see "Agent briefs")
- [OUT-OF-SCOPE.md](OUT-OF-SCOPE.md): how docs/out-of-scope/ works

## Where state lives

State lives only in the board's **Status** field. There are no status labels, so labels and board cannot disagree.

| Board Status | Meaning |
|---|---|
| Triage | New, not yet evaluated by Jess (also: real but deferred, with a comment saying so) |
| Blocked | Waiting on a named decision or issue |
| Accepted | Slice opening agreed (goal, done-condition, end-goal test in the body). Still needs a prose plan and Jess's OK before game code |
| In Progress | Being built |
| Needs Playtest | Checks clean, Jess feel-tests |
| Shipped | Jess confirmed, issue closed. Only Jess decides this |

Board field **Waiting on** (Jess or Assistant) says who acts next. Set it on every move. Session start reads
"Waiting on = Jess" as the list of what Jess owes.

Labels: exactly one **type** (`slice`, `decision`, `bug`, `chore`, `documentation`) and at least one **area**
(`area:data`, `area:combat`, `area:ui`, `area:tooling`; create a new `area:` label when a real area appears).
`wontfix` marks a rejection and the issue is closed.

Transitions: a new issue sits in Triage until Jess evaluates it, then goes to Accepted, Blocked, or is closed as
wontfix. Blocked returns to Accepted (or Triage) when the blocker clears. Needs Playtest goes back to In Progress if
the feel test fails. Jess can override at any time; flag unusual transitions and ask.

## Invocation

Jess invokes `/triage` and describes what they want in natural language, for example "what needs my attention",
"let's look at #42", "move #42 to accepted", "what's accepted".

## Show what needs attention

Read the board (`gh project item-list 3 --owner Jess-Rivera --format json --limit 200`) and present four buckets,
oldest first, with counts and a one-line summary per item:

1. **Not on the board**: open issues missing a card (add them in Triage).
2. **Triage**: evaluation pending.
3. **Waiting on Jess**: decisions and feel tests Jess owes.
4. **Blocked where every blocker is closed or decided**: probably stale. Read the body and links for the blockers and
   check each one.

Let Jess pick. The "catch me up" briefing in CONTEXT.md runs these same buckets read-only, so keep the two in step.

## Triage a specific issue

1. **Gather context.** Read the whole issue (body, comments, labels, dates). Parse prior triage notes so resolved
   questions are not re-asked. Explore following CLAUDE.md "Exploration". Run two checks and report where you looked:
   (a) **redundancy**: search code, docs and DECISIONS.md for an existing implementation or ruling by concept, not
   just the request's wording; if found, it is an already-implemented wontfix; (b) **prior rejection**: read
   docs/out-of-scope/*.md (if the folder exists) and surface any match.
2. **Recommend.** Give the type, area and Status recommendation with reasoning, plus a short summary of what exists.
   Check scope: an online feature (accounts, cloud saves, multiplayer, leaderboards) stays in Triage as deferred,
   never wontfix (CLAUDE.md "Scope"). Wait for Jess's direction.
3. **Verify the claim.** For a bug, try to reproduce it before any grilling, headless where feasible. Report
   confirmed (with the code path), failed, or insufficient detail. If it can only be confirmed by feel, say so and
   ask Jess; do not guess.
4. **Grill (if needed).** If the request needs fleshing out, invoke the `grilling` skill and work it into shape a
   round at a time. A slice is not Accepted until its body holds the goal, done-condition and end-goal test.
5. **Apply the outcome** with the `gh` commands the hook allows:
   - Accepted: set Status and Waiting on. Post a brief only if asked.
   - Blocked: name the blocker issue or decision in a comment, set Status and Waiting on.
   - Deferred: leave in Triage with a one-line reason comment.
   - Wontfix: only after Jess says so. Apply `wontfix` and close, with the comment depending on why:
     - **Already implemented**: point to where it lives; do not write to docs/out-of-scope/.
     - **Rejected bug**: a polite explanation, then close.
     - **Rejected slice or design idea**: write to docs/out-of-scope/, link it in a comment, then close.

Board commands: `gh project item-list 3 --owner Jess-Rivera --format json --limit 200` finds a card's id (add a
missing one with `gh project item-add 3 --owner Jess-Rivera --url <issue url>`); `gh project field-list 3 --owner
Jess-Rivera --format json` gives the Status and Waiting on field ids and option ids; then `gh project item-edit --id
<item> --project-id <project id> --field-id <field> --single-select-option-id <option>`.

## Quick state override

If Jess says "move #42 to accepted", trust them and apply it directly. Confirm what you are about to do (labels,
Status, Waiting on, comment, close), then act. Skip grilling. Only ask about a brief if Jess has not said.

## Agent briefs

A brief is a comment that turns an issue into a hand-off contract. Write one only when Jess asks, or when the issue is
going to a different tool or session (Amazon Quick versus Claude, or a background run). Format and rules:
AGENT-BRIEF.md.

## Open-question notes template

```markdown
## Triage Notes

**What we've established so far:**

- point 1

**What we still need to decide:**

- question 1
```

Capture everything resolved during grilling under "established so far" so the work is not lost. Questions must be
specific and actionable.

## Resuming a previous session

If prior triage notes exist on the issue, read them and present an updated picture before continuing. Do not re-ask
resolved questions.
