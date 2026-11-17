---
name: coding-principles
description: Coding principles (YAGNI, KISS, DRY, separation of concerns, SOLID, Law of Demeter, small cleanups, conventions) mapped to this repo. Apply every time you write a change plan for game code or tools, and every time you write approved code, before handing either to Jess. Also use when Jess says "good coding practices", "reuse where you can" or "only build what is needed".
---

<!-- Adapted from JordanCoin/codingskills (MIT license): kiss, dry, yagni, solid, separation-of-concerns,
law-of-demeter, boy-scout-rule and convention-over-configuration, folded into one file and rewritten in our own
words. First written for PokeSurvivor on 2026-11-13; rewritten for PokeTactics (Godot 4.6.2, GDScript, rules/ and
view/ split, data pack in data/) on 2026-11-17. Changes: tied to this repo's rules modules, data pack and decisions;
the boy-scout rule is limited by the plan-approves-its-scope rule; a plan check and a code check are added.
Source: https://github.com/JordanCoin/codingskills -->

# Coding principles

Jess wants these applied without being asked. They shape the plan first (what to build, what to reuse) and the code
second. CLAUDE.md wins wherever this file differs.

## The order when principles pull against each other
1. Correct and safe first. Save-field defaults (CLAUDE.md "Save-data safety"), determinism (seeded randomness only
   through the RandomNumberGenerator passed in, so battles replay and lockstep stays possible), checks at the data
   boundary and the test suite are correctness, never "complexity" to cut.
2. Then KISS: the version a reader follows in 30 seconds.
3. Then YAGNI: only what this slice needs.
4. Then DRY: one home for each rule, but only once the pattern is real.
When unsure between two of them, pick the one with fewer moving parts and say why in the plan.

## YAGNI: build only what is needed
- Solve the slice in front of you. One use case gets code for one use case.
- No setting, parameter, flag or option that nothing reads yet. A parameter only ever passed its default goes.
- No registry, plugin hook, base class or "generic" layer for one user. Extension points need two real users today.
- Cheap flexibility is fine (a lookup table or a data field instead of a chain of ifs costs nothing). Costly
  speculation is not.
- Deferred work (a later slice, M2 mechanics, the multiplayer horizon) gets a one-line note and an issue draft, never
  stub code.
- Every plan says what it deliberately does not build.

## KISS: keep it simple to read
- Write for the reader. A few clear lines beat a clever one-liner.
- At most three levels of nesting. Flatten with early returns and guard clauses.
- One function, one job. If its description needs "and", split it.
- No clever tricks: no bit hacks, chained ternaries or string parsing where plain code reads better.
- Explicit over implicit. No magic numbers in logic: a rule number is a named const at the top of the module that
  owns it (as BattleStats.CLOSE_RANGE_FACTOR); a per-move or per-species value lives in data/ or authored/.
- Names say what the thing is for on their own (CLAUDE.md "Coding conventions"). No one-letter names in new or
  touched code, loop counters included.

## DRY: one home for each piece of knowledge
- Reuse before writing. Search for an existing helper first and name it in the plan. The usual homes:
  - rules/battle_stats.gd: every combat formula (stats, damage, accuracy, crit, close-range factor).
  - rules/pack_data.gd: the data pack, loaded once, looked up by name.
  - rules/movement.gd: reachable cells and paths, step legality, facing after a walk.
  - rules/move_area.gd: move reach, target cells, footprints, units hit, grid distance.
  - rules/move_use.gd: one use of a move and its outcomes.
  - rules/turn_order.gd: the strike rank clock, whose turn it is, one action per turn (walk, move or Wait),
    end of turn, upkeep, forecast.
  - rules/facing.gd, rules/battle.gd, rules/battle_grid.gd, rules/battle_unit.gd: directions, the board, cells,
    units.
  - view/: the existing node patterns next to the change (tile_highlight, cell_picker, move_menu, turn_bar).
- DRY is about knowledge, not look-alike code. Two blocks that look the same but mean different things stay apart.
- Extract on the third real repeat, not the first. A wrong shared helper is worse than two copies.
- A helper that needs several boolean flags to serve every caller means the copies were simpler. Keep the copies.
- Data over branching: behaviour that varies by move, species or encounter belongs in data/ (exported by
  tools/export_pack.py), authored/ overrides or a move-schema field (2026-11-16-move-shapes-and-range), not in
  checks on names inside code.
- One source of truth for rules: the design docs (docs/discussion-outputs/battle-design.md, game-design.md) and
  the rulings in docs/decisions/. Code follows them; it does not restate them in a second place.

## Separation of concerns
- Keep each layer to its job (2026-11-15-godot-layout-and-tests): rules/ is simulation with no nodes and no
  drawing, and runs headless; view/ draws and takes input; data/ is generated, never hand-edited. A file in rules/
  that refers to view/ is a bug.
- An AI or other decision maker reads the board and returns a choice; it changes the board only through the same
  calls the player uses (TurnOrder.move_unit, use_move, end_turn).
- Validate at the boundary (the pack export and its --check, PackData on load, save load). Inside, trust the shape
  and do not re-check it.
- A coordinating function stays thin: it calls the steps, it does not also hold their logic.
- Do not over-layer. A short function does not need three layers.

## SOLID
- Single responsibility: a module or function has one reason to change. A file holding two unrelated jobs is a
  split candidate; say so in the plan. Length alone is not a reason to split.
- Open to extension through data: a new move, unit or encounter is a new entry in a table, not a new branch in code.
- Substitutable: anything that stands in for the player's input (AI, hotseat, a test) drives the same TurnOrder
  calls, so the rules never know who is choosing.
- Small surfaces: a module exposes what its callers use, nothing more. Helpers only the module uses start with _.
- Depend on what you are given: pure rules take what they need as arguments (a static func where no state is kept),
  so tests can build a small board and hand-derive outcomes.
- These are heuristics. A tiny script or a dev tool does not need them.

## Law of Demeter: talk to neighbors
- Do not reach through several objects to get one value across a module boundary. Ask the owner for it, or pass the
  value in.
- A function takes the fields it needs, not the whole object, when the object is from another module.
- Plain data (a pack Dictionary, a move's grid entry, an Outcome) is exempt: reading its fields is what it is for.
- Inside one tightly coupled module, a direct chain is often clearer. Apply it at module boundaries.

## Small cleanups (limited by the plan's scope)
- In the lines a change already touches: fix a misleading name, remove dead code you have proven dead, add a missing
  save-field default. List these in the plan as "touched-code cleanups" so the approval covers them.
- Anything bigger (more than about 20 lines, or a second module) is its own issue draft, never folded in.
- Do not "fix" what you do not understand. What looks dead may be a fallback; check callers, tests and the rulings
  first.

## Conventions
- Follow the patterns already in the file: class_name and extends at the top, a ## doc comment naming the issue and
  ruling it implements, consts next, then inner classes, vars and funcs; typed variables and return types;
  RefCounted for rules objects.
- Tests are gdUnit4 suites in tests/ named test_<slice>.gd; they check relations, not values (CLAUDE.md). Run them
  with tools\run-tests.cmd.
- Python tools in tools/ follow the style already there; after changing export_pack.py, run its --check.
- All text in English, no em-dashes (CLAUDE.md "Prose style"). Lines within 120 columns.

## The plan check (before a plan goes to Jess)
For each part of the plan, state:
- Reuses: the existing modules, data and patterns it builds on.
- New: each new file, function, const or data field, and why nothing existing fits.
- Not built: what it deliberately leaves out (YAGNI), with the issue draft for anything deferred.
- Where it lives: rules/, view/, data/ or tools/, and why that is the owner.
- Size: which files grow, and any file that takes on a second, unrelated job.
- Touched-code cleanups, if any.
A new default or rule that changes game behaviour is a standalone decision for Jess, never a line inside a part.
The plan itself holds no code (CLAUDE.md "Edit boundary and workflow").

## The code check (before reporting a change written)
- Nothing was added that the approved plan did not name (no extra settings, helpers or options).
- Every new helper has a real caller; nothing duplicates an existing helper.
- Nothing in rules/ refers to view/ or to nodes; randomness only comes from the generator passed in.
- No new magic numbers in logic; nesting at most three; each new function has one job and a descriptive name.
- No name checks bolted into a shared path; varying behaviour lives in data where a table exists.
- Save fields null-checked and defaulted; lines within 120 columns; tools\run-tests.cmd passes.
- If the code had to differ from the plan, stop and say how before going further.
