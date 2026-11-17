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

## 2026-11-15, turn order by Speed (#8)
- Talked through a RuneQuest strike rank clock (Speed and size set SR, actions cost SR, replacing PP); parked as
  #13 with notes in docs/discussion-outputs/strike-rank-turns.md. M1 keeps plain Speed rounds.
- rules/turn_order.gd: rounds fastest first, ties drawn once from the battle seed, forecast, move once per turn,
  end-turn facing. view/turn_bar.gd: slanted bar on the right edge, active entry larger at the bottom.
- Hotseat until #11; other units inspect only (orange range). 9 new relation tests, 65 in all.
- Jess feel-tested the turn flow and the bar and closed #8.

## 2026-11-16, top-level design grilling
- Stepped back before #9 to design the game top-down. Two rounds settled the pitch, three equal pillars, a Kanto
  region run on a branching map (8 gyms, Elite Four, one legendary), fixed enemy levels, carry and field 6,
  catching by talk, level-up moves automatic with shops selling the rest, Silver and PokeCoins, recovery, saves.
- 13 rulings, docs/discussion-outputs/game-design.md, revised roadmap (M1b hotseat versus). CLAUDE.md scope now
  names multiplayer as the horizon. New issues #14 (battle sub-grilling), #15 (hotseat), #16 (6 a side).

## 2026-11-16, battle mechanics sub-grilling (#14)
- Strike rank settled: size-dominant base SR, a turn is a move or an act, next turn at now + cost + base, 12 SR
  rounds with an upkeep step, movement 1 SR per 2 flat tiles plus elevation and terrain costs, act cost from PP.
- Positioning: Jess's facing grid (2:1 rule), height range and damage, line of sight with arcing moves, push by
  size band with collision; no lock-down yet. Environment: tile material plus state, intuitive rules in upkeep,
  1.2x terrain-type bonus. Objectives pool; boss AI is GOAP plus utility (Jess's own fork code may be used).
- Mainline systems all in a new M2b. 12 rulings, battle-design.md; #13 became a slice, #9 unblocked, #17 to #24.

## 2026-11-16, 6 a side with portraits (#16, built)
- Test battle: 6 player units against wild 2 to 4, trainer 3 to 6 or boss 6 enemies, seeded; keys 1 to 3.
- Portraits: fetch-spritecollab.js gained a portrait pass (32,946 files, hash-checked, credits); Jess chose one
  sheet per emotion and colour over one per species, so tools/pack_portraits.py writes 80 sheets sharing one cell
  index. Turn bar shows Normal portraits through view/portrait_loader.gd (per-battle atlas left for later).
- 6 relation tests, 71 in all; portrait rerun check in run-tests. Not feel-tested yet.

## 2026-11-16, #16 closed, #9 opening drafted
- Jess feel-tested 6 a side with portraits: passed. #16 closed, board card Shipped.
- #9 opening drafted in move-schema-opening.md: the fork's three axes adapted to tiles, default rules from
  pokeapi target, damage class and the contact flag (to be exported), 8 relation tests, the 45 roster moves to
  review, and six questions (Q1 to Q6) for Jess.

## 2026-11-16, #9 move translation schema (built)
- Every M1 roster move (45) has a grid entry in data/moves.json (shape, target, range, SR cost, tile element,
  payload), derived from pokeapi with hand-written overrides in the new authored/ folder; contact on all 919.
- data/shapes.json holds circle and cone footprints; rules/move_area.gd returns tiles and units hit.
- 8 relation tests, 79 in all, pass. Wiki move pages show the grid entry. Jess approved the review table.
- Follow-up: Flamethrower as a line or cone (later move review). Relation 10 (0.5x at range 1) moved to #10.

## 2026-11-16, #10 use a move (built)
- Opening agreed (12 relations); ruling 2026-11-16-use-a-move-m1 (empty targets allowed, damage only in M1).
- rules/move_use.gd: reach, footprint, per-unit accuracy and crit, damage (0.5x at range 1), Night Shade's level
  damage, Self-Destruct; TurnOrder allows one move and one act per turn; fainted units free their cells.
- View: move menu (keys 1 to 4), target and area tint, Attack and Hurt on the hit frame, floating numbers, HP bars,
  fade on faint. Encounter restart moved to F1 to F3. 91 tests pass. Awaiting Jess's feel test.

## 2026-11-16, #10 closed
- Jess feel-tested use a move: passed. #10 closed, board card Shipped. #9 left for Jess to close.
- Open: whether fixed damage (Night Shade) should skip the 0.5x at range 1. Next: #11 opening.

## 2026-11-17, #11 enemy turn (built)
- Primer docs/discussion-outputs/enemy-ai-primer.md; opening and plan enemy-turn-opening.md; ruling
  2026-11-17-enemy-ai-m1 (one-turn scorer, knockouts first, avoid allies, move then act, enemy side always AI).
- rules/turn_ai.gd scores every stand cell, move and target with no rolls; approach by path when nothing is in reach.
- Shared helpers: BattleStats.hit_chance, MoveUse.hit_damage, has_effect, deals_damage (behaviour unchanged).
- View: enemy turns play out (think 0.4 s, walk, area preview 0.5 s, strike); F1 to F3 work at any time.
- coding-principles skill rewritten for this repo. 6 new tests, 97 in all, pass. Awaiting Jess's feel test.

## 2026-11-17, #11 closed
- Jess feel-tested the enemy turn: passed. #11 closed, board card Shipped.
- Follow-up #25: the player gets no clue what the AI chose (move name, target). Next: #12 opening.

## 2026-11-17, #12 win, lose, restart (built)
- Opening and plan win-lose-opening.md; ruling 2026-11-17-battle-end-m1 (rout ends at once; a double wipe goes to
  the side that used the move, so a last Self-Destruct wins).
- Battle holds the winning side; TurnOrder.use_move settles a rout and gives no active unit once it is over.
- TurnAi adds a win bonus for an option that knocks out every standing foe. view/end_screen.gd: Victory or Defeat,
  rounds, units left, Same battle (seed kept) and New battle. 6 new tests, 103 in all. Awaiting Jess's full battle.

## 2026-11-17, #12 closed, M1 done
- Jess played a full battle: end screen and restart feel great. #12 closed, board card Shipped. M1 is done.
- Next: #15 hotseat versus (M1b) opening.

## 2026-11-17, #15 hotseat versus (built)
- Opening and plan hotseat-opening.md; ruling 2026-11-17-hotseat-m1b; #26 filed to widen the pool to Kanto.
- TestBattleSetup: hotseat pool, team checks (species once), build from two teams, AI sides per play mode.
- New start menu (main scene) and blind pick screen; end screen gains Menu; labels and title come from the map.
- Handover: banner plus the camera turning to the incoming player's home view (CameraRig.turn_to_view_step).
- 6 new tests, 109 in all, pass; headless smoke runs of the menu, pick screen and a hotseat handover.

## 2026-11-17, #15 closed, M1b done
- Jess played hotseat: passed. #15 closed, board card Shipped. M1b is done.
- Speed ties (Charmander and Alolan Vulpix at 65) interleave by the seeded tiebreak, as designed (#8).
