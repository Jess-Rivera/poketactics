# Development plan [Approved]

Date: 2026-11-15. Where we are: Godot project with a greybox rotating test map (#1), full data pack in data/ (#2).
No game rules exist yet. Each slice below still gets its own opening (goal, done-when, end-goal test) before build.

## Roadmap (revised 2026-11-16 after the top-level design grilling, see game-design.md)

```mermaid
flowchart TD
    M0["M0 Foundation<br/>Godot primer, offline wiki (done)"] --> M1
    M1["M1 First playable battle<br/>6 a side on one large map, rout ends it"] --> M1b
    M1b["M1b Hotseat versus<br/>free pick 6 at a set level"] --> M2
    M2["M2 Battle depth<br/>strike rank clock, facing, height, push,<br/>environment and terrain, objectives, boss AI"] --> M2b
    M2b["M2b Mainline systems<br/>status, stat stages, immunities,<br/>weather, abilities, held items"] --> M3
    M3["M3 Run layer (Kanto)<br/>run map and nodes, catching by talk, shops,<br/>Silver and PokeCoins, recovery, checkpoints, home menu"] --> M4
    M4["M4 Content and look<br/>Kanto gyms and maps, block art, walkable home town, UI, audio"] --> M5
    M5["M5 First build<br/>export, credits, Jess plays a full Kanto run"]
```

| Milestone | Done when | Rough size |
|---|---|---|
| M0 Foundation | Done (#1 to #4) | |
| M1 First playable battle | Jess plays a 6 a side battle on a large test map with real pack units and wins or loses; battles also run headless in tests | 4 to 5 slices left |
| M1b Hotseat versus | Two players free-pick 6 units each at one level and play a battle on one machine | 1 to 2 slices |
| M2 Battle depth | Strike rank clock, facing, height and line of sight, push, environment, terrain-type bonuses, objectives and a boss AI that feels human (battle-design.md) | 8 to 10 slices |
| M2b Mainline systems | Every portable mainline battle system works on the grid (2026-11-16-mainline-systems-m2b) | Open, sized at its opening |
| M3 Run layer | A Kanto run on a branching map with every node type, catching by talk, shops, both currencies, recovery and checkpoint saves | 6 to 9 slices |
| M4 Content and look | Kanto's 8 gyms, Elite Four and legendary fights; chosen block art; walkable home town; menus and sound | Open-ended |
| M5 First build | An exported build with CREDITS that Jess plays through a full Kanto run | 1 to 2 slices |

Sub-grillings gate milestones: battle mechanics (done, battle-design.md); boss AI and the environment rule table before their M2 slices; run map, catching and economy before M3; home and
meta before the home menu; endgame after M5.

## M1 slices (the part worth planning now)

Revised 2026-11-16: battles are 6 a side (2026-11-16-party-and-battles); slice 5a (#9) waits for the battle
mechanics sub-grilling, which settles strike rank (#13) first because a move's SR cost is a schema axis.

```mermaid
flowchart LR
    S1[1 Pack loader<br/>rules/] --> S2[2 Units from the pack<br/>on the map]
    S2 --> S3[3 Select and move<br/>range with height]
    S3 --> S4[4 Turn order]
    S4 --> S5A[5a Move translation<br/>schema] --> S5[5 Use a move<br/>range, damage, KO]
    S5 --> S6[6 Enemy turn<br/>simple AI]
    S6 --> S7[7 Win, lose, restart]
```

| # | Slice | Rules side (headless, tested) | View side (Jess feel-tests) |
|---|---|---|---|
| 1 | Pack loader | Load data/ into unit, move and type definitions; stat formula in one stats module | none |
| 2 | Units from the pack | A battle unit built from a pack unit at a level | Real sprites (Vulpix, Alolan Vulpix) placed on the map |
| 3 | Select and move | Reachable tiles from movement and height | Cursor, highlight, walk animation, camera pan and zoom |
| 4 | Turn order | Who acts next, from Speed | Turn order strip |
| 5a | Move translation schema | Grid axes for moves; defaults from pokeapi target and damage class; overrides for the M1 moves | none |
| 5 | Use a move | Range, area, line of sight and height per move; accuracy; damage; faint | Target highlight, attack and hurt animations, HP bars |
| 6 | Enemy turn | Enemies pick a move and target | Enemy acts with a short pause |
| 7 | Win, lose, restart | Battle end conditions | End screen |

## Decisions that gate M1

| # | Question | Answer (Jess, 2026-11-15) | Ruling |
|---|---|---|---|
| 1 | Battle scale | Big: up to about 20 by 20; 4 units a side in M1 | 2026-11-15-battle-scale |
| 2 | Turn structure | One unit at a time in Speed order (Option 2) | 2026-11-15-turn-structure |
| 3 | Damage | Mainline formula, no damage roll; only accuracy and crits are random; reach and environment also decide a hit | 2026-11-15-damage-and-hit |
| 4 | Moves on the grid | Derived defaults plus overrides, through a translation schema like the fork's | 2026-11-15-move-grid-translation |
| 5, 6, 7 | Moves, stats, PP | 4 moves from the level-up learnset; mainline stat formula; no PP in M1 | 2026-11-15-unit-stats-and-moves |
| 8 | Movement | Fixed 4 tiles; climb 1 up, drop 2 down | 2026-11-15-movement-range |

What the answers change in M1:
- 20 by 20 does not fit one 640x360 screen, so slice 3 adds camera pan and zoom, and the test map grows.
- The translation schema is its own slice before "use a move" (new slice 5a): design the axes for a turn-based grid
  from Jess's fork docs (MOVE-AXIS-SCHEMA.md), then the defaults and the M1 move overrides.
- "Reach and environment" means slice 5 needs line of sight and height rules for hitting, not only range.

### Turn structure: the two options (Option 2 chosen)

```mermaid
flowchart LR
    subgraph O1["Option 1: plan, then resolve"]
        A1[Enemies show their move and target] --> B1[Player orders every unit] --> C1[All units act in Speed order]
    end
    subgraph O2["Option 2: one unit at a time"]
        A2[Fastest unit acts] --> B2[Next fastest acts] --> C2[...]
    end
```

| | Option 1: plan, then resolve | Option 2: one unit at a time by Speed |
|---|---|---|
| Feel | Into the Breach style puzzle: read the threat, answer it | FFT and Triangle Strategy: react each turn |
| What the player sees | Enemy intents for the whole round | The current board and the turn order |
| Hard rules it needs | What happens when an order goes stale: a faster unit moved the target, fainted the actor, or blocked the tile (fizzle, retarget, or act on the tile) | None new |
| Speed matters by | Who resolves first inside the round | How often and when you act |
| Enemy AI | Must commit before seeing your orders, so telegraphs are honest | Plans one unit at a time |
| Build cost | Higher: order queue, intent display, stale-order rules | Lower |

Questions Option 1 must answer before it can be built: when an enemy's target moves, does its attack follow the
unit or hit the tile; does a player see enemy intents that resolve after their own units; do enemies telegraph
movement too, or only the move.

Recommendation: decide now, because the turn loop shapes slices 4 to 6. If Option 1 is the game's signature, build it
from M1; the rules side (one action resolved on the grid) is the same either way, so only the round loop and UI
differ.

## Not decided here (later milestones)
- M2 signature mechanics: enemy intent telegraphs, push and collision, height and facing bonuses, status in turns.
- M3 run shape: battle chain or branching map, recruiting by catch or by reward, permadeath, which learn methods
  are used (2026-11-15-learn-methods).
- M4 block art source and style, portraits (open in STATE).

## Tracking
Once Jess approves, the M0 and M1 slices become issues (a batch of about nine, drafted for Jess's OK first) and a
milestone per M on the board.
