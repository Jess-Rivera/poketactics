# Moves on the grid: a translation schema

Date: 2026-11-15. Owner: Jess. Canonical: docs/discussion-outputs/development-plan.md

- Each move's grid behaviour (range, area, shape, push and so on) comes from a translation schema: defaults derived
  from pokeapi facts (target, damage class), with per-move overrides, as the PokeSurvivor fork did.
- The idea and Jess's docs may be carried over (fork docs/MOVE-AXIS-SCHEMA.md); its code may not (Clean-room rule).
- The schema's axes for a turn-based grid are designed in their own slice.
