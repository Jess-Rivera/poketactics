# Facing and height: how they apply (#17)

Date: 2026-11-17. Owner: Jess. Canonical: docs/discussion-outputs/battle-design.md

- Facing and height are resolve-time modifiers in one small list per hit (with close range); all factors are
  multiplied, then rounded once. Numbers stay [Proposed] placeholders: front 1.0x, side 1.3x, back 2.0x; height
  1.1x per level down, 0.9x per level up, capped at 2 levels.
- Height damage factor applies to every formula-damage move. Fixed damage and faint moves get no facing or height.
- Range from height, symmetric: change = sign(D) x floor(c x sqrt(|D|)), c = 1.0, D = user height minus aimed cell
  height. Ranged moves only (max range 2 or more; melee is range 1); reach never drops below the move's min range.
  Applies to every ranged move, direct and arcing (2026-11-17-height-range-all-ranged).
- Measured from the user's cell, except an area bigger than one tile centred away from the user: from the blast
  centre (height included). A unit on the centre tile falls back to the direction from the user.
- Tags (a plain list in recipe basics, seeded from pokeapi move flags, arcing folded in) open #18.
