# Environment model

Date: 2026-11-16. Owner: Jess. Canonical: docs/discussion-outputs/battle-design.md

- Interactions must make intuitive sense: fire spreads, water spreads, ice melts, electricity is limited by the
  material it is on. A rule system, not a list of every combination.
- Every tile has a material (grass, wood, water, stone, sand, metal, ice and so on) and a state (burning, wet,
  shocked, frozen and so on). A small rule table decides spread and fading, applied in the upkeep step.
- Every damaging move applies its type's element to the tiles it hits by default; the move schema can override.
- The rule table itself is designed in its own sub-grilling.
