# Move upgrades belong to M3, not M2 (#28)

Date: 2026-11-17. Owner: Jess. Canonical: docs/discussion-outputs/development-plan.md

- M2 is battle depth (facing, height, sight, push, environment, objectives, boss AI); upgrades are a run-layer
  reward bought or earned in M3, so #28 moves to M3 and is built alongside shops.
- No M2 slice needs upgrades: push is a new recipe component; whether bosses use upgrades is for #23.
- The move parity fixture (tests/fixtures/move_parity.json) is deleted by the next slice that changes recipes,
  not held until #28.
