# Move recipe structure (#27)

Date: 2026-11-17. Owner: Jess. Canonical: docs/discussion-outputs/ecs-vs-effect-pipeline.md

- Recipe = basics (type, class, accuracy, SR cost) + shape + components. Power lives in the damage component.
- Shape: square(len, wid) or circle(r, angle); single is a 1x1 square, a cone a circle under 360. Range is a span
  on the shape (self 0, melee 1, ranged 1..N); every move aims at a tile. Anchor: centered or forward.
- Component: effect + timing (on use, on hit, every round for t rounds) + touches (units, tiles) + who (all, foes,
  allies, self; all excludes the user) + optional chance + optional own shape. One hit per unit per component.
- Upgrades: build-time edits to the recipe, resolve-time modifiers on numbers. Every source (status, ability,
  item, upgrade, later tiles) brings its own filtered modifiers; close-range half damage becomes one.
- Rolls: accuracy once per unit; on-hit components only on hit units; each chance alone. Tile effects ignore misses.
- Units: base stats plus attached things. [Open]: 0.75x multi-target, weather (#20), stacking and caps.
  Updates 2026-11-16-move-shapes-and-range (no self/other/point) and 2026-11-17-move-recipes.
