# STATE (current handoff)

Updated 2026-11-17.

## Where we are
- Data: pokeapi raw CSVs in source/pokeapi/csv/ (187 files, pinned at db06b37dca).
- Sprites: raw SpriteCollab in source/spritecollab/ (2,151 sets, pinned at 2f5d22b505), packed in assets/pokemon/.
- Godot 4.6.2 at the repo root: Compatibility, 640x360 integer scaling, gdUnit4 v6.2.3. Isometric view, Q/E
  4-way rotation, 3D greybox blocks plus 2D sprites (#1).
- Data pack in data/ (#2): units, moves, abilities, types keyed by name, from tools/export_pack.py; units carry
  size_band (#13). Offline wiki in wiki/ (#4).
- Rules: pack_data.gd, battle_stats.gd (every formula, base SR), battle.gd, movement.gd (walk cost by segment,
  12 SR cap), move_recipe.gd, move_area.gd, hit_modifiers.gd, move_use.gd, move_effects.gd, turn_ai.gd, test_battle_setup.gd.
- M1 done (#5 to #12, #16), M1b hotseat done (#15). #9 closed with 45 roster moves; the rest is #26.
- M2 started on slice/m2-build. Strike rank clock shipped (#13): base SR 0 to 4 from size plus a Speed nudge;
  a turn is one walk, move or Wait; 12 SR rounds with upkeep; forecast bar with landing ghost.
- Move recipes (#27, closed, feel test passed): moves are recipes (basics, square or circle shape, components) run
  by one loop with a handler per effect; nothing plays differently. Upgrades (#28) moved to M3 (2026-11-17-upgrades-to-m3).
- Facing and height (#17, closed, feel test passed): hit modifier list (close range, facing arc, height) in
  hit_modifiers.gd; ranged reach changes with height by floor(sqrt); aim labels and inspect arc tint.
- Tests: 129 gdUnit4 tests plus the pack and portrait checks, `tools\run-tests.cmd` (see CONTEXT.md).

## Next
Design: game-design.md, battle-design.md. Roadmap: development-plan.md (M2, M2b, M3 to M5).
1. Next M2 slice: #18 line of sight (opens with move tags) or #19 push. #20, #23 sub-grillings first
   for #21, #22 and the boss AI.
2. #26 (Kanto move grid), #25 (show the AI's choice) when convenient.

## Open decisions
| Decision | Blocks | Note |
|---|---|---|
| Block art source and style | Map look | Greybox for now; godot-primer.md |
| Special0 to Special26 animations | Animation set | Jess looks at them in a viewer |
| Fallback for the 265 sets without sprites; Mega Charizard Y portrait shows Charizard | Sprites | sprites-primer.md q4 |
| Can the work machine run Godot 4.6.2 and Python 3? | Work-side testing | Check there |
| Starting PokeCoins, recovery lengths, prices | Economy | Economy sub-grilling |
| Act cost formula (PP bands); sr_cost 3 to 6 placeholders | Tuning | 2026-11-16-act-cost |
| Shipping sprite credits | First export slice | CC BY-NC needs source/spritecollab/CREDITS.md in builds; export includes data/*.json |

## Tracking
Board: https://github.com/users/Jess-Rivera/projects/3. Open: UI #25; data #26; M2 #18 to #22;
sub-grillings #20, #23; M2b #24; M3 #28.
