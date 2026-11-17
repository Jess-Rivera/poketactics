# data (the game's data pack, generated: do not edit by hand)

Built by `python tools/export_pack.py` from source/pokeapi/csv at pokeapi commit
db06b37dca1b33c82edad3fe73ca7e909845e548. Plan: docs/discussion-outputs/data-pack-plan.md.
Check that it is current: `python tools/export_pack.py --check` (also run by tools\run-tests.cmd).

## Counts

| File | Entries |
|---|---|
| units.json | 1082 (1025 species defaults, alola 18, galar 19, hisui 16, paldea 4) |
| moves.json | 919 (Shadow moves left out; 45 with a recipe) |
| abilities.json | 314 (main series) |
| types.json | 18 |
| shapes.json | footprint table, radius 1 to 50, spread in 15 degree steps |

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
- size_band: 0 (smallest) to 4, from one size score (log height and weight) ranked over default species in
  shares of 10/20/40/20/10%; the base strike rank before the Speed nudge (2026-11-17-size-bands).
- gender_rate: chance of female in eighths; -1 means genderless.
- types.json `against`: damage multiplier of the attacking type (the entry) on each defending type.
- A learnset entry's level is present only for level-up moves; 0 means learned on evolution.
- A move's `contact` is pokeapi's contact flag. Its `recipe` (null for moves no slice fields yet) is described
  in tools/move_grid.py; ranges are grid steps, sr_cost is strike rank (placeholder bands); tags are the
  move's pokeapi flags plus arcing.
- shapes.json: every tile around an origin for a shape aimed east, with the smallest circle radius and cone
  spread that cover it (a tile is in when its centre lies within radius + 0.5).

## Units and transformations without a sprite set

Matched by SpriteCollab form name (source/spritecollab/tracker.json); none upstream, or a form not fetched.
The fallback is an open decision (STATE.md).

- abomasnow-mega
- absol-mega-z
- aggron-mega
- amoonguss
- ampharos-mega
- appletun-gmax
- audino-mega
- barbaracle-mega
- baxcalibur-mega
- beedrill-mega
- blastoise-gmax
- blastoise-mega
- blaziken-mega
- blitzle
- bouffalant
- brambleghast
- brute-bonnet
- butterfree-gmax
- carkol
- carracosta
- centiskorch-gmax
- chandelure-mega
- charizard-mega-y
- chesnaught-mega
- chien-pao
- cinderace-gmax
- clefable-mega
- coalossal
- coalossal-gmax
- copperajah-gmax
- corviknight-gmax
- crabominable-mega
- crustle
- delphox-mega
- dragonite-mega
- drednaw-gmax
- duraludon-gmax
- eevee-gmax
- emboar-mega
- espathra
- falinks
- falinks-mega
- feraligatr-mega
- flamigo
- flapple-gmax
- frillish-male
- froslass-mega
- garbodor-gmax
- garchomp-mega
- garchomp-mega-z
- gengar-gmax
- gimmighoul
- glimmora-mega
- golisopod-mega
- golurk-mega
- greninja-mega
- grimmsnarl-gmax
- gumshoos
- gyarados-mega
- hatterene-gmax
- heatran-mega
- heracross-mega
- inteleon-gmax
- iron-boulder
- iron-crown
- iron-jugulis
- kingler-gmax
- klawf
- lapras-gmax
- lucario-mega-z
- mabosstiff
- machamp-gmax
- magearna-mega
- malamar-mega
- maschiff
- meganium-mega
- melmetal-gmax
- meowstic-male-mega
- meowth-gmax
- metagross-mega
- mewtwo-mega-x
- miraidon
- mr-rime
- okidogi
- oranguru
- orbeetle-gmax
- pidgeot-mega
- pikachu-gmax
- pinsir-mega
- pyroar-male
- pyroar-mega
- rabsca
- raichu-mega-x
- raichu-mega-y
- rillaboom-gmax
- salamence-mega
- sandaconda-gmax
- scizor-mega
- scolipede-mega
- scovillain-mega
- shelmet
- shiinotic
- shroodle
- simipour
- simisear
- snorlax-gmax
- squawkabilly-green-plumage
- staraptor-mega
- starmie-mega
- stunfisk-galar
- swampert-mega
- tauros-paldea-aqua-breed
- tauros-paldea-blaze-breed
- throh
- tirtouga
- toedscruel
- toxtricity-amped-gmax
- tranquill
- trumbeak
- urshifu-single-strike-gmax
- venusaur-gmax
- venusaur-mega
- victreebel-mega
- wo-chien
- zarude
- zebstrika

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
