# Walk cost with elevation (#13)

Date: 2026-11-17. Owner: Jess. Canonical: docs/discussion-outputs/battle-design.md

- A walk splits into segments, each rounded up on its own: a flat run costs round up(tiles / 2), climbing costs
  1 SR per level (like difficult terrain), dropping costs round up(levels / 2) (like walking down the face).
- A run of stairs (several drops or several climbs in a row) is one segment, not one per step.
- Jess's worked rows (flat, up, down, flat, SR): 2,0,1,1 is 3; 3,0,1,1 is 4; 2,1,0,1 is 3; 4,4,0,2 is 7; 4,0,4,2 is 5.
- One move action costs at most 12 SR; the picker shows each cell's cost. Climb 1 and drop 2 per step still apply.
- Fall damage is deferred (#19). Updates 2026-11-16-movement-cost.
