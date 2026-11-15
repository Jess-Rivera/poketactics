# STATE (current handoff)

Updated 2026-11-15.

## Where we are
- Repo bootstrapped: CLAUDE.md, CONTEXT.md, the git guard hook, and two skills (grilling, writing-check).
- Board "PokeTactics" (user project 3) chosen; design in 2026-11-15-project-board. Board set up and
  verified (columns, Waiting on, repo link); labels created, triage skill adapted.
- Engine decided: Godot 4 (2026-11-15-engine-godot-4). No game code yet.
- pokeapi raw CSVs (187 files, 41 MB) in source/pokeapi/csv/, byte-exact at db06b37dca, fetched by
  tools/fetch-pokeapi.js. Data rulings so far: see DECISIONS.md (units, variants, learnsets, methods, source).

## Next
Going step by step (Jess, 2026-11-15): pokeapi understood and fetched; next Godot set up at the repo root, then
sprites, then the export to a JSON pack and the offline wiki. Primer: docs/discussion-outputs/pokeapi-primer.md.

## Open decisions
| Decision | Blocks | Note |
|---|---|---|
| Sprite source and animation set, Godot layout | Sprites, Godot setup | Listed with recommendations in the data transfer plan |
| Can the work machine (Amazon Quick) run the engine? | Work-side testing | Check before committing to an engine |

## Tracking
Board: https://github.com/users/Jess-Rivera/projects/3 (PokeTactics). No issues yet.
