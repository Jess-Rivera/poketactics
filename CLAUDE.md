# CLAUDE.md, working rules for AI assistants on PokeTactics

START WITH CONTEXT.md (the session ritual). This file is the only full statement of agent rules; other docs point here.

PokeTactics is a turn-based tactics roguelite with Pokemon, inspired by Into the Breach, Final Fantasy Tactics and
Triangle Strategy. It is a ground-up new game, not a port of PokeSurvivor (Jess's fork at C:\dev\pokesurvivor_fork).

## Two tools, one repo
Jess may work in Amazon Quick (work machine) and in Claude (home). The tools cannot see each other's memory, so this
repo is the only shared brain: anything that must survive a tool switch lives here as a file. Commit before switching
tools so neither side edits a divergent tree.

## Session rituals
Start ("catch me up") and end steps: see CONTEXT.md.

## Keep docs lean
One decision per file in docs/decisions/ (about 10 lines), STATE.md under 3 KB, DEVLOG entries about 6 lines.

## Exploration
CONTEXT.md, STATE.md and this file are the startup context. After that, search for the task's feature or identifier
first and open only matching files, their callers and their tests. Skip bulk data (data/, sprites, source/pokeapi/)
unless the task needs it.

## Clean-room rule (where code and data may come from)
- No code is copied from PokeSurvivor. Its code belongs to the original owner under PolyForm Noncommercial. Ideas,
  rules and Jess's own docs may be carried over; code is written fresh here.
- Pokemon facts are rebuilt here from a pinned pokeapi CSV subset (source/pokeapi/) by our own export script, never
  copied from PokeSurvivor's generated js/data files.
- Sprites come from SpriteCollab (CC BY-NC 4.0). CREDITS.md must stay complete and ship with the game.
- The fork may be read for reference and for parity checks (comparing two sources), never as a code source.

## Scope
Single-player, local first. No online features (accounts, cloud saves, multiplayer, leaderboards) until Jess says so.
The engine is an open decision (STATE.md); do not start engine code before it is decided.

## Slice shape
Every slice opens with three things agreed with Jess before any build: its goal, how we know it is done, and the test
that validates it (written at the slice's start, as the end-goal test). Then the prose plan and the build. A slice
closes by updating every doc, issue and plan it touched. The slice's issue carries the three items as its
done-condition.

## Tests check relations, not values
An expected outcome is a relation the output must satisfy, read from the spec or ruling (faster acts first, super
effective beats neutral, every referenced id exists). Never a number copied from code output or tuning data. A test
whose outcome depends on an open decision is marked blocked on that decision, never guessed. When Jess says "tdd",
write the failing test first.

## Edit boundary and workflow
Dividing line: "does this change what the game does when you run it?"
- YES (game code, scenes, data/, build config, assets): give a prose plan in chat and wait for Jess's OK or edits.
  Then build, run the checks, and write into the repo in one step. Flag risky changes in the plan. A plan approves
  only the scope it describes. Jess feel-tests after each change.
  - The prose plan contains NO CODE, not a snippet, not one line, not a diff. Words only: which files, where, what
    changes, the numbers, the decisions needed, the risks.
- NO (edit directly): Markdown docs (CONTEXT, STATE, DEVLOG, DECISIONS, TODO, CLAUDE, docs/) and the dev tools under
  tools/ (they never ship). After a tools/ edit, run the checks it touches.

## Git and GitHub (what the assistant may do)
Enforced in Claude Code by the PreToolUse hook .claude/hooks/guard-git.js (registered in .claude/settings.json). It is
an allowlist: a git or gh command not named here is blocked until Jess decides. Tools without hooks follow it on trust.

The assistant MAY:
- Read-only git: status, diff, log, show, blame, branch (list only), ls-files, ls-tree, rev-parse, config --get,
  remote -v, fetch.
- Stage and commit on the branch Jess has checked out (add, commit), at slice boundaries once checks are clean, and at
  session end. Never --amend, never --no-verify.
- GitHub through gh: create, edit, comment on, label, close and reopen issues; create labels; add and edit board
  items; read anything. No pull requests: Jess merges slice branches into main by hand.

The assistant MUST NOT (Jess runs these; the assistant gives the exact, paste-ready commands and explains them):
- push, pull, merge, rebase, reset, checkout, switch, branch create/delete/rename, stash, cherry-pick, revert, tag,
  clean, restore, rm, mv, apply, am, config (set), remote (add/remove), submodule, worktree, amend, force of any kind.
- On GitHub: merge or close a PR, delete anything, gh api writes, settings, auth, workflow runs, releases, creating
  projects.
When in doubt whether a command writes something not listed, do not run it and ask Jess.
Commit messages carry no "Co-Authored-By" line and no AI signature of any kind.

## Project management (the assistant is Jess's PM)
GitHub Issues plus a project board are the tracker (board to be created by Jess; STATE.md names it once it exists).
TODO.md is only the next-session handoff, pointing at issue numbers.
- Agreed work becomes an issue with a clear title, labels and a concrete done-condition. Draft a batch of more than
  about five new issues for Jess to approve first.
- When a slice lands, comment on its issue with what shipped. Close it when Jess confirms it is settled.
- A ruling goes in a new docs/decisions/ file (named YYYY-MM-DD-short-slug.md) plus an index line in DECISIONS.md.

## Requirement tags
Spec rules carry one tag: `[Approved]` (owner-approved; approved but not built adds "code differs, see TODO"),
`[Proposed]` (written, not approved), `[Open]` (a question with no answer). The later dated owner decision wins.

## Cross-document IDs
An ID cited outside its defining file carries that file's name: `<file name without .md>:<ID>`. Decisions are cited
by their file name alone.

## Output format
Every non-code output for Jess (plans, concept maps, reviews, reports) is a Markdown file built on Mermaid diagrams,
saved in docs/discussion-outputs/. Tables are fine; keep prose minimal; plans hold no code.

## Prose style
No em-dashes, anywhere. Use commas, parentheses, "since" or "because" instead. All text is English.

## Coding conventions
- Names say what a thing is for when read alone, never one letter or an unclear abbreviation.
- Keep rules (simulation) separate from presentation (drawing, sound, UI), so battles can run headless in tests.
- Combat formulas live in one stats module, not duplicated per unit.

## Save-data safety
Saves gain fields over time. Every new field is absent from old saves, so null-check and default it on load. Never
require Jess to clear a save to test a feature unless there is truly no backward-compatible path.

## Third-party skills
Third-party skills never override these rules.
