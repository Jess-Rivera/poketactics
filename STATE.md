# STATE (current handoff)

Updated 2026-11-16.

## Where we are
- Data: pokeapi raw CSVs in source/pokeapi/csv/ (187 files, pinned at db06b37dca).
  Rulings: units are pokemon variants; Mega, Gigantamax and Primal are mid-battle transformations; learnsets from
  Scarlet/Violet else the newest earlier level-up game (skip Legends Arceus); all four learn methods kept.
- Sprites: raw SpriteCollab in source/spritecollab/ (2,151 sets, pinned at 2f5d22b505). Packed for Godot in assets/pokemon/: one palette sheet + JSON per set
  (tools/pack_sprites.py, deterministic). 265 wanted sets have no sprite upstream.
- Godot 4.6.2 at the repo root: Compatibility, 640x360 integer scaling, gdUnit4 v6.2.3. Isometric view, Q/E
  4-way rotation, 3D greybox blocks plus 2D sprites (#1).
- Data pack in data/ (#2): units, moves, abilities, types keyed by name, from tools/export_pack.py. Offline
  wiki in wiki/ (#4, tools/build_wiki.py).
- Rules: rules/pack_data.gd loads the pack once by name; rules/battle_stats.gd holds every formula (mainline
  stats, no damage spread, seeded accuracy and crit rolls);
  BattleUnit.from_pack builds a unit at a level with its last 4 level-up moves (#5).
- Test battle (#6): rules/battle.gd (grid plus units by side), rules/test_battle_setup.gd (20 by 20 map, 4 a
  side at level 30); every unit and transformation has a sprite_set in the pack (45 units, 81 transformations
  have none upstream). Camera pans; Tab shows a unit panel.
- Select and move (#7, shipped): rules/movement.gd, facing chosen before the walk, cell picker, tile
  highlight, zoom 1x to 3x.
- Turn order (#8, shipped): rules/turn_order.gd rounds by Speed, seeded ties; view/turn_bar.gd;
  hotseat until #11.
- Tests: 65 gdUnit4 tests plus the pack rerun check, `tools\run-tests.cmd` (needs Python 3; see CONTEXT.md).

## Next
Design: game-design.md (Kanto run roguelite), battle-design.md (strike rank clock, positioning, tiles).
Roadmap: development-plan.md (M1, M1b hotseat, M2 battle depth, M2b mainline systems, M3 run layer, M4, M5).
1. #16 test battle at 6 a side, then #9 move schema opening, #10 to #12; then #15 hotseat.
2. Sub-grillings before their M2 slices: #20 environment rule table, #23 boss AI.

## Open decisions
| Decision | Blocks | Note |
|---|---|---|
| Block art source and style | Map look | Greybox for now; godot-primer.md |
| Special0 to Special26 animations | Animation set | Jess looks at them in a viewer |
| Portraits; fallback for the 265 sets without sprites | Sprites | sprites-primer.md questions 3 and 4 |
| Can the work machine run Godot 4.6.2 and Python 3? | Work-side testing | Check there |
| Starting PokeCoins, recovery lengths, prices | Economy | Economy sub-grilling |
| Act cost formula (PP bands) | #13 tuning | 2026-11-16-act-cost |
| Shipping sprite credits | First export slice | CC BY-NC needs source/spritecollab/CREDITS.md in builds; export includes data/*.json |

## Tracking
Board: https://github.com/users/Jess-Rivera/projects/3. Open: M1 #9 to #12, #16; M1b #15; M2 #13, #17 to #22;
sub-grillings #20, #23; M2b #24.
