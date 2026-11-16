# Game design (top level)

Date: 2026-11-16. Source: top-level grilling with Jess. Rulings: the 2026-11-16 files in DECISIONS.md.
Sub-levels are grilled just in time, before the slices that need them (see "Design tree").

## Pitch [Approved]
Strategy RPGs (FFT, Fire Emblem, Ogre Tactics, Triangle Strategy) plus Pokemon, inside a run-based roguelite
(Into the Breach, Slay the Spire). You are a trainer taking a team through a region's 8 gyms and the Elite Four
for a chance to catch that region's legendary.

## Pillars [Approved] (equal weight)
| Pillar | The moment it aims for |
|---|---|
| Tactics rewarded | "That was sick, I didn't think I was going to make it!" |
| Boss AI | Bosses feel like an intelligent human opponent |
| Environment | Element combos on tiles (lightning on water, burning trees) and terrain-type bonuses |

## Save to home to run
```mermaid
flowchart TD
    NEW["New save<br/>pick a region's starter, get all 3<br/>12 Pokeballs, some PokeCoins"] --> HOME
    HOME["Home (menu now, walkable town in M4)<br/>spend PokeCoins, manage boxes"] --> PREP
    PREP["Run prep<br/>pick 6, pack Pokeballs<br/>warn if boxes are full"] --> MAP
    MAP["Run Map (branching)"] --> NODE{Node}
    NODE -->|regular / elite| BATTLE[Battle, 6 against a varying count]
    NODE -->|shop| SHOP["Shop (Silver)<br/>machine, tutor, egg moves; items"]
    NODE -->|heal| HEAL["Heal node<br/>heal, revive, swap with boxes"]
    NODE -->|checkpoint| SAVE[Save and quit allowed]
    BATTLE -->|won, wild| TALK["Talk to one defeated wild Pokemon<br/>nature decides answers"] --> MAP
    BATTLE -->|won| MAP
    BATTLE -->|whole team fainted| END
    SHOP --> MAP
    HEAL --> MAP
    SAVE --> MAP
    MAP -->|gym beaten| GYM[Gym checkpoint, save allowed] --> MAP
    MAP -->|8 gyms, Elite Four beaten| LEG[Fight ONE legendary, chance to catch] --> END
    END["Run ends: back home<br/>PokeCoins by progress<br/>still-fainted Pokemon are Recovering"] --> HOME
```

## What persists
| Thing | Scope | Notes |
|---|---|---|
| Pokemon, EXP, levels, evolutions | Persistent | Levels gate which shop moves appear |
| PokeCoins | Persistent | End-of-run reward; spent at home |
| Pokeballs found | Persistent | 12 at a new save |
| Recovering status | Persistent | Only if still fainted at run end; depth sets length; items shorten it |
| Silver | One run | Shops and healing |
| Badges and map progress | One run | A wipe restarts the region at gym 1 |
| Save | One slot | Written only at gym checkpoints and checkpoint nodes |

## Rules at a glance
| Topic | Ruling | Tag |
|---|---|---|
| Run | One region: 8 gyms, Elite Four, one legendary; about 6 hours or more | [Approved] |
| Difficulty | Fixed enemy levels (gym 1 about 6 up to legendaries 80+); over-levelling allowed | [Approved] |
| Over-levelling risk | Later runs may trivialise early gyms; difficulty modifiers are a candidate fix | [Proposed] |
| Party | Carry 6, field 6; swap with boxes at heal nodes; catches go to boxes | [Approved] |
| Enemy counts | Vary by node; bosses full teams; wild 2 to 4, trainer and elite 3 to 6 | [Approved], counts [Proposed] |
| Battle end | Rout in M1; objectives later | [Approved] |
| Catching | Talk after battle, wild only, one offer per battle, ball adds odds | [Approved] |
| Moves | Level-up automatic; shops sell machine, tutor, egg moves gated by level | [Approved] |
| Turn limit on strong moves | No PP; strike rank (RuneQuest style) | [Approved] |
| Multiplayer | Horizon; hotseat versus in M1b with free pick at a set level | [Approved] |
| First build | Kanto only | [Approved] |
| Endgame | Legendary picks, shiny tiers, Arceus, Descendant Mutation, The Climb | [Proposed], parked |
| Starting PokeCoins, recovery lengths, prices | Economy sub-grilling | [Open] |

## Design tree (sub-grillings, just in time)
```mermaid
flowchart TD
    TOP["Top level (this file)"] --> B["1 Battle mechanics<br/>strike rank, environment and terrain,<br/>objectives, boss AI, move schema axes"]
    TOP --> R["2 Run map and nodes<br/>map shape, node mix, rewards"]
    TOP --> C["3 Catching dialogue<br/>natures, questions, odds, balls"]
    TOP --> E["4 Economy and shops<br/>Silver, PokeCoins, prices, recovery"]
    TOP --> H["5 Home and meta progression"]
    TOP --> X["6 Endgame (parked)"]
    B --> I9["#9 move translation schema"]
    B --> I13["#13 strike rank"]
    B --> M2[M2 battle depth]
    R --> M3[M3 run layer]
    C --> M3
    E --> M3
    H --> M3
```
Order: 1 next (it gates #9), then 2 to 4 before M3, 5 before the home menu, 6 after the first build.
