# STATE (current handoff)

Updated 2026-11-16.

## Where we are
- Data: pokeapi raw CSVs in source/pokeapi/csv/ (187 files, pinned at db06b37dca).
- Sprites: raw SpriteCollab in source/spritecollab/ (2,151 sets, pinned at 2f5d22b505), packed in assets/pokemon/. 265 wanted sets have no sprite upstream.
- Godot 4.6.2 at the repo root: Compatibility, 640x360 integer scaling, gdUnit4 v6.2.3. Isometric view, Q/E
  4-way rotation, 3D greybox blocks plus 2D sprites (#1).
- Data pack in data/ (#2): units, moves, abilities, types keyed by name, from tools/export_pack.py. Offline
  wiki in wiki/ (#4, tools/build_wiki.py).
- Rules: rules/pack_data.gd loads the pack once by name; rules/battle_stats.gd holds every formula (mainline
  stats, no damage spread, seeded accuracy and crit rolls);
  BattleUnit.from_pack builds a unit at a level with its last 4 level-up moves (#5).
- Test battle (#6): rules/battle.gd (grid plus units by side), rules/test_battle_setup.gd (20 by 20 map, level 30);
  camera pans; Tab shows a unit panel.
- Select and move (#7, shipped): rules/movement.gd, facing chosen before the walk, cell picker, tile
  highlight, zoom 1x to 3x.
- Turn order (#8, shipped): rules/turn_order.gd rounds by Speed, seeded ties; view/turn_bar.gd;
  hotseat until #11.
- 6 a side (#16, shipped): wild, trainer, boss enemy counts (F1 to F3); portraits in assets/portraits/, shown
  in the turn bar.
- Move schema (#9, built): grid entry for the 45 roster moves in data/moves.json, overrides in authored/,
  footprints in data/shapes.json, rules/move_area.gd gives tiles hit.
- Use a move (#10, built): rules/move_use.gd, keys 1 to 4, area preview, HP bars, faint.
- Tests: 91 gdUnit4 tests plus the pack and portrait rerun checks, `tools\run-tests.cmd` (needs Python 3; see CONTEXT.md).

## Next
Design: game-design.md (Kanto run roguelite), battle-design.md (strike rank clock, positioning, tiles).
Roadmap: development-plan.md (M1, M1b hotseat, M2 battle depth, M2b mainline systems, M3 run layer, M4, M5).
1. #10 built: Jess feel-tests it, and closes #9.
2. Then #11, #12, then #15 hotseat. Sub-grillings #20, #23 before M2.

## Open decisions
| Decision | Blocks | Note |
|---|---|---|
| Block art source and style | Map look | Greybox for now; godot-primer.md |
| Special0 to Special26 animations | Animation set | Jess looks at them in a viewer |
| Fallback for the 265 sets without sprites; Mega Charizard Y portrait shows Charizard | Sprites | sprites-primer.md q4 |
| Can the work machine run Godot 4.6.2 and Python 3? | Work-side testing | Check there |
| Starting PokeCoins, recovery lengths, prices | Economy | Economy sub-grilling |
| Act cost formula (PP bands) | #13 tuning | 2026-11-16-act-cost |
| Shipping sprite credits | First export slice | CC BY-NC needs source/spritecollab/CREDITS.md in builds; export includes data/*.json |

## Tracking
Board: https://github.com/users/Jess-Rivera/projects/3. Open: M1 #9 to #12; M1b #15; M2 #13, #17 to #22;
sub-grillings #20, #23; M2b #24.
