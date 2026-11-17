# Line of sight: how it applies (#18)

Date: 2026-11-17. Owner: Jess. Canonical: docs/discussion-outputs/line-of-sight-opening.md

- Tags: all 21 pokeapi move flags plus arcing, a plain list in recipe basics replacing the arcing field. Arcing comes
  from the ballistics flag plus overrides (for example Rock Slide, Rock Throw).
- Sight line: tile centre to tile centre; every tile crossed counts; an exact corner blocks only if both tiles beside
  it block. Tile height only (unit size never counts). Free aim at any cell is later (#29).
- Walls (tiles taller than both ends) block every ranged move and shelter tiles behind them inside an area.
- A ranged move centred on its aimed cell, without arcing, is a projectile: it stops at the first unit on its line
  (allies too) and lands there; a blast bursts centred there. Status moves too.
- Beams, cones and other shapes running from the user hit every unit in their area; units never shelter each other.
- Blocked cells: dim grey tint, not pickable, "No line of sight" on hover.
