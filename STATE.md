# STATE (current handoff)

Updated 2026-11-15.

## Where we are
- Data: pokeapi raw CSVs in source/pokeapi/csv/ (187 files, byte-exact at db06b37dca, tools/fetch-pokeapi.js).
  Rulings: units are pokemon variants; Mega, Gigantamax and Primal are mid-battle transformations; learnsets from
  Scarlet/Violet else the newest earlier level-up game (skip Legends Arceus); all four learn methods kept.
- Sprites: raw SpriteCollab in source/spritecollab/ (2,151 sets incl. shinies, byte-exact at 2f5d22b505,
  tools/fetch-spritecollab.js). Packed for Godot in assets/pokemon/: one palette sheet + JSON per set
  (tools/pack_sprites.py, deterministic). 265 wanted sets have no sprite upstream.
- Godot 4.6.2 at the repo root: Compatibility, 640x360 integer scaling, gdUnit4 v6.2.3. Isometric view, Q/E
  4-way rotation, 3D greybox blocks plus 2D sprites (#1).
- Data pack in data/ (#2): units, moves, abilities, types keyed by name, from tools/export_pack.py. Offline
  wiki in wiki/ (#4, tools/build_wiki.py).
- Rules: rules/pack_data.gd loads the pack once by name; rules/battle_stats.gd holds every formula (mainline
  stats with IVs and EVs 0, damage with no spread, accuracy and Gen 6 crit rolls on a passed-in seed);
  BattleUnit.from_pack builds a unit at a level with its last 4 level-up moves (#5).
- Test battle (#6): rules/battle.gd (grid plus units by side), rules/test_battle_setup.gd (20 by 20 map, 4 a
  side at level 30); every unit and transformation has a sprite_set in the pack (45 units, 81 transformations
  have none upstream). Camera pans with WASD or arrows; Tab shows a temporary unit panel.
- Select and move (#7, awaiting feel test): rules/movement.gd, facing chosen before the walk, cell picker, tile
  highlight, zoom 1x to 3x.
- Tests: 56 gdUnit4 tests plus the pack rerun check, `tools\run-tests.cmd` (needs Python 3; see CONTEXT.md).

## Next
Plan: docs/discussion-outputs/development-plan.md (M0 foundation, M1 first playable battle, then M2 to M5).
Rulings: see DECISIONS.md (latest: 2026-11-15-move-and-facing).
1. Jess feel-tests #7 (selection, path, facing, walk on flat, climb and drop, zoom, four rotations).
2. Then #8 to #12 in order. #5 to #7 are on slice/m1-build.

## Open decisions
| Decision | Blocks | Note |
|---|---|---|
| Block art source and style | Map look | Greybox for now; godot-primer.md |
| Special0 to Special26 animations | Animation set | Jess looks at them in a viewer |
| Portraits; fallback for the 265 sets without sprites | Sprites | sprites-primer.md questions 3 and 4 |
| Can the work machine run Godot 4.6.2 and Python 3? | Work-side testing | Check there |
| Shipping sprite credits | First export slice | CC BY-NC needs source/spritecollab/CREDITS.md in builds; export must also include data/*.json |

## Tracking
Board: https://github.com/users/Jess-Rivera/projects/3. Open issues: #7 to #12 (M1).
