# Damage and hit: mainline formula; hit decided by accuracy, reach and environment

Date: 2026-11-15. Owner: Jess. Canonical: docs/discussion-outputs/development-plan.md

- Damage uses the mainline damage formula, in the one stats module (CLAUDE.md "Coding conventions").
- Whether a move hits depends only on its accuracy and on reach and environment (range, line, height, terrain).
- No damage roll: the 85 to 100 percent spread is left out. A move that hits does flat formula damage.
- Only two things are random: the accuracy check (a 100 percent move always hits) and critical hits.

Updated by 2026-11-16-height-and-sight and 2026-11-16-facing-arcs.
