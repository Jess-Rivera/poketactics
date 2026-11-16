# Move shapes, targets and range

Date: 2026-11-16. Owner: Jess. Canonical: docs/discussion-outputs/move-schema-opening.md (#9)

- Shapes: single target, line, cone, circle. Targets: self, other, point on field. Pairs: single {self, other,
  point}, line {self, point} (line {point} also takes a direction, for walls), cone {self}, circle {self, other, point}.
- Circle: a tile is in if its centre lies within radius r + 0.5 of the origin's centre. Cone: same distance test,
  plus the tile's angle from the aim direction is within half the spread angle.
- Aim is one of 4 directions. Default cone: 60 degree spread, length 3. Circle {self} leaves out the user; a
  radius 1 circle is the full 3x3 block. Single {other} may target an ally. Weather moves are single {self}.
- Footprints are computed at export as a table over radius and spread (players will upgrade both), so the game
  never does trigonometry.
- An area hits every unit inside it, friend or foe. pokeapi's target only picks the default shape.
- Range: melee (contact) 1; ranged 2 or more (2 to 4 in #9), with 0.5x damage at range 1, for damage only.
  Range is counted in grid steps, height ignored until #17.
- Entries are built at export from derived defaults plus overrides; #9 covers only the 45 roster moves.
