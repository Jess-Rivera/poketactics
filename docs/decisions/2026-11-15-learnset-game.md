# Learnset game per unit

Date: 2026-11-15. Owner: Jess. Canonical: docs/discussion-outputs/pokeapi-primer.md

- Each unit's learnset comes from one game: Scarlet/Violet if it has level-up data there, otherwise the newest
  earlier game with level-up data. Legends Arceus is skipped (its mastery system differs). Champions is skipped
  (no levels), and games with no move data are ignored.
- Measured on the fork's pokeapi copy: Scarlet/Violet 777, Sword/Shield 156, BD/SP 140, USUM 10, Let's Go 2;
  every unit gets a level-up learnset. Recount on the pinned commit (#2): Scarlet/Violet 776,
  Sword/Shield 155, BD/SP 140, USUM 9, Let's Go 2, none missing.
- All moves a unit learns in that game (every method) come from that same game.
