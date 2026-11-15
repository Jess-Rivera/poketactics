# DEVLOG

## 2026-11-15, bootstrap
- Repo set up from the PokeSurvivor fork session: trimmed CLAUDE.md, CONTEXT, STATE, TODO, DECISIONS, git guard hook, grilling and writing-check skills.
- Decided: new ground-up repo, clean-room rule (no fork code). Engine still open.
- Next: agree the data transfer slice (docs/discussion-outputs/data-transfer-plan.md).

## 2026-11-15, data, sprites, Godot setup (#1)
- Board set up; ten rulings recorded (units, variants, learnsets, methods, pokeapi pin, wiki, engine, renderer,
  resolution, isometric rotating view, layout and gdUnit4, sprite sources, animation set).
- Fetched pokeapi CSVs and SpriteCollab sprites byte-exact at pinned commits; .gitattributes keeps them exact.
- #1 shipped: greybox isometric map, Q/E rotation, Charmander facing right in all views, 17 tests.
- Editor was slow with 188k sprite files; packed to one palette sheet + JSON per set, editor open 20 s to 4 s.
- Next: pokeapi JSON pack and offline wiki.

## 2026-11-15, data pack (#2)
- Opening agreed (two slices, pack first; gdUnit4 reads the JSON, no loader; four files keyed by name).
- Built tools/export_pack.py: 1,082 units, 919 moves, 314 abilities, 18 types in data/; rerun check in run-tests.cmd.
- Recounts on the pin: Mega 97, Gigantamax 34, Alola 18; 6 excluded-base transformations left out.
- Caught: a "shadow-" name filter dropped Shadow Ball; now filtered by id. Planted pack breaks all fail the tests.
- Parity with the fork: 0 differences over 966 species. Next: Jess's spot check, then the wiki slice.

## 2026-11-15, development plan, offline wiki (#4)
- Development plan approved (M0 to M5); rulings: 20 by 20 maps, 4 a side, Speed-order turns, mainline stats and
  damage with no roll, 4 moves, no PP, move 4 (climb 1, drop 2), move translation schema. Issues #3 to #12.
- #3 Godot primer closed as not needed.
- #4 built: tools/build_wiki.py writes 2,334 static pages to wiki/ (search, tabs, sortable tables), about 30 MB.

## 2026-11-15, pack loader and stats module (#5)
- rules/pack_data.gd (pack loaded once, by name, loud on a missing name), rules/battle_stats.gd (all formulas),
  BattleUnit.from_pack (stats, HP, types, abilities, last 4 level-up moves at a level).
- 14 new relation tests, 41 in all. Planted bugs (no same-type bonus, always hit, first 4 moves, HP formula)
  each failed a test.

## 2026-11-15, units on a large test map (#6)
- Kept SpriteCollab tracker.json (fetch --tracker-only) so the export matches units to sprite sets by form name;
  45 units and 81 transformations have no sprite upstream (listed in data/README).
- rules/battle.gd and a 20 by 20 test battle, 4 a side at level 30; camera pan; temporary Tab unit panel.
- 6 new relation tests, 47 in all. Godot would not pass Battle.Side as Side, so side parameters are ints.

## 2026-11-15, select and move (#7)
- rules/movement.gd: reachable cells and shortest paths (4 steps, climb 1, drop 2, pass allies, enemies block);
  Battle.move_unit to a chosen facing. Jess added a facing choice between picking the tile and the walk.
- view/cell_picker.gd picks by ray against cell columns (the map mesh has no collision); tile highlight, Walk
  with a hop on height changes, zoom 1x to 3x on wheel and + / -.
- 9 new relation tests, 56 in all. Jess feel-tested it and closed #7.
