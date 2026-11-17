# Size bands for base strike rank (#13)

Date: 2026-11-17. Owner: Jess. Canonical: docs/discussion-outputs/strike-rank-size-bands.md (Option 3)

- Size score: the average of the z scores of log height and log weight over the 1,025 default species.
- Ranked into shares 10 / 20 / 40 / 20 / 10%, smallest first, giving base SR 0, 1, 2, 3, 4. The export script
  computes the cutoffs from the pack. Alternate forms use their own height and weight against those cutoffs.
- Speed nudge: base Speed 100 or more is -1, 40 or less is +1; the result is clamped to 0 to 4.
- Updates 2026-11-16-strike-rank-clock: the range is 0 to 4 (was [Proposed] about 1 to 4), and one combined score
  replaces separate height and weight bands.
