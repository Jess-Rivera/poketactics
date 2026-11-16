# Move schema adaptation

Date: 2026-11-16. Owner: Jess. Canonical: docs/discussion-outputs/battle-design.md

- The fork's MOVE-AXIS-SCHEMA is imported as a starting point and redesigned freely for the grid (between a
  straight adaptation and a fresh design).
- Kept framing: three axes (space, delivery, payload). Units become tiles, SR and rounds; real-time fields
  (travel speed, paths, homing, orbits) are dropped.
- Defaults come from pokeapi facts (target, damage class), with per-move overrides; every move must resolve.
- The schema carries an SR cost field (2026-11-16-act-cost) and an arcing flag (2026-11-16-height-and-sight).
- Details are settled in #9's opening. Updates 2026-11-15-move-grid-translation.
