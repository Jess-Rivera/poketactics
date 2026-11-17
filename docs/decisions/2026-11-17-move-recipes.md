# Moves as recipes, upgrades as filter plus change

Date: 2026-11-17. Owner: Jess. Canonical: docs/discussion-outputs/ecs-vs-effect-pipeline.md

- No ECS framework. A move name maps to a recipe of parts (shape, range, cost, payload parts) in data; the rules
  build the move from its recipe, and each kind of part has one handler (no growing if/else chain).
- Upgrades are a filter (which moves) plus a change (what to edit); they never edit base data. An effective recipe
  is built per use from the base recipe plus active upgrades.
- Upgrades belong to one Pokemon. Enemies and bosses use the same system.
- Upgrades cover moves first; unit upgrades (stats, size, movement) use the same system, lighter.
- Changes apply in a fixed order by kind, never by pick order. Stacking and caps: [Open], later.
- Built as its own slice.
