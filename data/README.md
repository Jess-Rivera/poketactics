# data (the game's data pack, generated: do not edit by hand)

Built by `python tools/export_pack.py` from source/pokeapi/csv at pokeapi commit
db06b37dca1b33c82edad3fe73ca7e909845e548. Plan: docs/discussion-outputs/data-pack-plan.md.
Check that it is current: `python tools/export_pack.py --check` (also run by tools\run-tests.cmd).

## Counts

| File | Entries |
|---|---|
| units.json | 1082 (1025 species defaults, alola 18, galar 19, hisui 16, paldea 4) |
| moves.json | 919 (Shadow moves left out) |
| abilities.json | 314 (main series) |
| types.json | 18 |

| Learnset game | Units |
|---|---|
| scarlet-violet | 776 |
| sword-shield | 155 |
| brilliant-diamond-shining-pearl | 140 |
| ultra-sun-ultra-moon | 9 |
| lets-go-pikachu-lets-go-eevee | 2 |

Learnset entries: 64959. Transformations: gigantamax 32, mega 93, primal 2.
Moves whose effect is pokeapi's newest English in-game description (no effect text upstream): 93.

## Units of measure

- height_decimetres, weight_hectograms: as pokeapi stores them.
- gender_rate: chance of female in eighths; -1 means genderless.
- types.json `against`: damage multiplier of the attacking type (the entry) on each defending type.
- A learnset entry's level is present only for level-up moves; 0 means learned on evolution.

## Left out on purpose

Transformations whose base form is an excluded variant (data-pack-plan.md decision 2):

- magearna-original-mega (base magearna-original)
- meowstic-female-mega (base meowstic-female)
- tatsugiri-droopy-mega (base tatsugiri-droopy)
- tatsugiri-stretchy-mega (base tatsugiri-stretchy)
- toxtricity-low-key-gmax (base toxtricity-low-key)
- urshifu-rapid-strike-gmax (base urshifu-rapid-strike)

Evolutions whose target is an excluded variant (2026-11-15-variant-scope):

- burmy into wormadam-sandy
- burmy into wormadam-trash
- dunsparce into dudunsparce-three-segment
- espurr into meowstic-female
- kubfu into urshifu-rapid-strike
- lechonk into oinkologne-female
- rockruff into lycanroc-midnight
- tandemaus into maushold-family-of-three
- toxel into toxtricity-low-key
