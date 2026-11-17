# Wait, and the shape of a turn (#13)

Date: 2026-11-17. Owner: Jess. Canonical: docs/discussion-outputs/battle-design.md

- A turn is strictly one of: a move (walk), an act (a move used, or a push later), or a Wait. Never two.
- Every turn ends with a free facing choice, Wait included.
- Wait: pick w from 1 to n, where n = 12 minus the current SR, and at least 1 (from SR 12, a Wait of 1 lands on
  SR 1 of the next round, after upkeep). The next turn is at now + w, with no base SR added.
- A waiter goes first on its SR regardless of Speed; among waiters, Speed then the seed. Priority moves (deferred)
  will beat a Wait.
- The AI does not choose to Wait in #13, except as a fallback: with no attack worth making and no closer cell, it
  waits 1 SR (a turn cannot end without an action). Updates 2026-11-16-use-a-move-m1 (one move and one act per turn).
