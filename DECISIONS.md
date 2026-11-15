# DECISIONS (index)

One file per ruling in docs/decisions/. Each file's `Canonical:` line names the spec that holds the rule.

- [2026-11-15-new-repo-ground-up-tactics](docs/decisions/2026-11-15-new-repo-ground-up-tactics.md): PokeTactics is a new ground-up repo; only raw data and Jess's rules carry over
- [2026-11-15-project-board](docs/decisions/2026-11-15-project-board.md): Board "PokeTactics" (project 3), PokeSwarm columns, state on the board only, Waiting on field
- [2026-11-15-engine-godot-4](docs/decisions/2026-11-15-engine-godot-4.md): The engine is Godot 4
- [2026-11-15-unit-is-pokemon-variant](docs/decisions/2026-11-15-unit-is-pokemon-variant.md): A unit is a pokemon variant (Alolan Vulpix is its own unit), as in mainline
- [2026-11-15-variant-scope](docs/decisions/2026-11-15-variant-scope.md): Units are default pokemon plus Mega, Gigantamax, Primal and regional forms; other variants left out
- [2026-11-15-mega-gmax-transform](docs/decisions/2026-11-15-mega-gmax-transform.md): Mega, Gigantamax and Primal are mid-battle transformations of a base unit, not units
- [2026-11-15-offline-wiki](docs/decisions/2026-11-15-offline-wiki.md): Static HTML wiki built from the pack, pages committed
- [2026-11-15-learnset-game](docs/decisions/2026-11-15-learnset-game.md): Learnsets come from Scarlet/Violet, else the newest earlier game with level-up data, skipping Legends Arceus
- [2026-11-15-learn-methods](docs/decisions/2026-11-15-learn-methods.md): Pack keeps level-up, machine, egg and tutor moves; gameplay use decided at design
- [2026-11-15-pokeapi-source](docs/decisions/2026-11-15-pokeapi-source.md): Raw pokeapi CSVs copied into source/pokeapi, frozen at db06b37dca, with a provenance note
- [2026-11-15-renderer-compatibility](docs/decisions/2026-11-15-renderer-compatibility.md): Godot uses the Compatibility renderer
- [2026-11-15-base-resolution](docs/decisions/2026-11-15-base-resolution.md): Base resolution 640x360 with integer scaling
- [2026-11-15-sprite-sources](docs/decisions/2026-11-15-sprite-sources.md): Pokemon sprites from SpriteCollab (pinned); RawAsset later for tiles, items, effects
- [2026-11-15-animation-set](docs/decisions/2026-11-15-animation-set.md): Core 11 animations plus tactics extras where present; flavor left out; Specials pending a look
- [2026-11-15-isometric-rotating-view](docs/decisions/2026-11-15-isometric-rotating-view.md): Isometric battle view, rotatable in four 90 degree steps
- [2026-11-15-godot-layout-and-tests](docs/decisions/2026-11-15-godot-layout-and-tests.md): Folders by role (rules, view, tests, data, assets); gdUnit4 for tests
- [2026-11-15-data-pack-shape](docs/decisions/2026-11-15-data-pack-shape.md): Data pack is four JSON files keyed by name; excluded-base transformations and Shadow moves left out
- [2026-11-15-battle-scale](docs/decisions/2026-11-15-battle-scale.md): Battle maps up to about 20 by 20
- [2026-11-15-damage-and-hit](docs/decisions/2026-11-15-damage-and-hit.md): Mainline damage formula; hit from accuracy, reach and environment
- [2026-11-15-move-grid-translation](docs/decisions/2026-11-15-move-grid-translation.md): Move grid behaviour from a translation schema (defaults plus overrides)
- [2026-11-15-unit-stats-and-moves](docs/decisions/2026-11-15-unit-stats-and-moves.md): Mainline stat formula, 4 moves per unit, no PP in M1
- [2026-11-15-movement-range](docs/decisions/2026-11-15-movement-range.md): Every unit moves a fixed 4 tiles for now
- [2026-11-15-turn-structure](docs/decisions/2026-11-15-turn-structure.md): Units act one at a time in Speed order
- [2026-11-15-move-and-facing](docs/decisions/2026-11-15-move-and-facing.md): Choose facing before the walk; pass allies, enemies block; zoom 1x to 3x
