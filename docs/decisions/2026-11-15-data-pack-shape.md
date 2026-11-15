# Data pack shape: four files keyed by name; what is left out

Date: 2026-11-15. Owner: Jess. Canonical: docs/discussion-outputs/data-pack-plan.md (issue #2)

- data/ holds units.json, moves.json, abilities.json, types.json (built by tools/export_pack.py). Entries are keyed by
  pokeapi name (vulpix-alola, ember); the pokeapi number is kept as pokeapi_id.
- Transformations whose own base form is an excluded variant (6, for example female Meowstic Mega) are left out and
  listed in data/README.md. Evolutions into excluded variants are dropped the same way.
- Moves with no English effect text upstream (93) use pokeapi's newest English in-game description, marked so.
- All 919 mainline moves are in; the 18 Colosseum Shadow moves are not. Mega Stones wait for the transformation slice.
