# STATE (current handoff)

Updated 2026-11-15.

## Where we are
- Repo bootstrapped: CLAUDE.md, CONTEXT.md, the git guard hook, and two skills (grilling, writing-check).
- Board "PokeTactics" (user project 3) chosen; design in 2026-11-15-project-board. Board set up and
  verified (columns, Waiting on, repo link); labels created, triage skill adapted.
- Engine decided: Godot 4 (2026-11-15-engine-godot-4). No game code yet.
- pokeapi raw CSVs (187 files, 41 MB) in source/pokeapi/csv/, byte-exact at db06b37dca, fetched by
  tools/fetch-pokeapi.js. Data rulings so far: see DECISIONS.md (units, variants, learnsets, methods, source).
- SpriteCollab sprites in assets/pokemon/ (2,151 sets incl. shinies, 96,189 files, about 600 MB), byte-exact at
  2f5d22b505, by tools/fetch-spritecollab.js; artists in assets/pokemon/CREDITS.md. 265 wanted sets have no sprite.
- Godot 4.6.2 (Compatibility, 640x360 integer scaling); isometric view, 4-way rotation, 3D blocks + 2D sprites.

## Next
Going step by step (Jess, 2026-11-15). Done: pokeapi and sprites fetched. Next: Godot project at the repo root
with a greybox rotating test map (plan first), then the JSON pack export and the offline wiki. Primers in
docs/discussion-outputs/ (pokeapi, godot, sprites).

## Open decisions
| Decision | Blocks | Note |
|---|---|---|
| Block art source and style | Map look | Greybox first proposed; godot-primer.md |
| Special0 to Special26 animations | Animation set | Jess looks at them in a viewer |
| Portraits; fallback for the 265 sets without sprites | Sprites | sprites-primer.md questions 3 and 4 |
| Godot folder layout, test tool | Godot setup | godot-primer.md questions 3 and 4 |
| Can the work machine (Amazon Quick) run the engine? | Work-side testing | Check before committing to an engine |

## Tracking
Board: https://github.com/users/Jess-Rivera/projects/3 (PokeTactics). No issues yet.
