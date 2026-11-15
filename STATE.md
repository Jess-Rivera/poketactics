# STATE (current handoff)

Updated 2026-11-15.

## Where we are
- Board "PokeTactics" (user project 3) set up and verified; auto-add and close-to-Shipped work.
- Data: pokeapi raw CSVs in source/pokeapi/csv/ (187 files, byte-exact at db06b37dca, tools/fetch-pokeapi.js).
  Rulings: units are pokemon variants; Mega, Gigantamax and Primal are mid-battle transformations; learnsets from
  Scarlet/Violet else the newest earlier level-up game (skip Legends Arceus); all four learn methods kept.
- Sprites: raw SpriteCollab in source/spritecollab/ (2,151 sets incl. shinies, byte-exact at 2f5d22b505,
  tools/fetch-spritecollab.js). Packed for Godot in assets/pokemon/: one palette sheet + JSON per set
  (tools/pack_sprites.py, deterministic). 265 wanted sets have no sprite upstream.
- Godot 4.6.2 at the repo root: Compatibility, 640x360 integer scaling, folders rules/ view/ tests/, gdUnit4
  v6.2.3. Isometric view with Q/E 4-way rotation, 3D greybox blocks plus 2D sprites (issue #1, shipped).
- Tests: 17 gdUnit4 tests, `tools\run-tests.cmd` (see CONTEXT.md).

## Next
1. Jess squash-merges slice/godot-setup into main (commands given 2026-11-15).
2. pokeapi JSON pack export (data/) and the offline wiki: understand first, then a slice opening.

## Open decisions
| Decision | Blocks | Note |
|---|---|---|
| Block art source and style | Map look | Greybox for now; godot-primer.md |
| Special0 to Special26 animations | Animation set | Jess looks at them in a viewer |
| Portraits; fallback for the 265 sets without sprites | Sprites | sprites-primer.md questions 3 and 4 |
| Can the work machine run Godot 4.6.2? | Work-side testing | Check there |
| Shipping sprite credits | First export slice | CC BY-NC needs source/spritecollab/CREDITS.md in builds |

## Tracking
Board: https://github.com/users/Jess-Rivera/projects/3. Open issues: none.
