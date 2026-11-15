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
