# CONTEXT, start here (session ritual for all AI tools)

All agent rules live in CLAUDE.md. This file is the ritual and the pointers.

## Session start
1. Read this file and STATE.md (the short current handoff). Nothing else is required.
2. Say where we left off and the top open items ("catch me up" means exactly this).
3. Read TODO.md, then pull live state read-only: `gh issue list --state open --json number,title,labels,updatedAt`
   (and the board once STATE.md names one). The board wins over any file. Report in about 10 lines: suggested for
   today, what is owed by Jess (feel tests, open decisions and what they block), and any drift between STATE, TODO
   and GitHub.
4. Tell Jess how to bring this machine up to date (Jess runs these): `git status` (must be clean),
   `git fetch origin`, then `git pull --ff-only` on the current branch. If ff-only fails, stop and say so.

## Session end
1. Rewrite STATE.md (under 3 KB, replace, do not append) and the TODO.md handoff (issue numbers).
2. Append a short DEVLOG.md entry (about 6 lines). A new ruling is a new docs/decisions/ file plus a DECISIONS.md line.
3. Commit, and remind Jess to push.

## Where things live
- Rules: CLAUDE.md. Current handoff: STATE.md. Next session: TODO.md. Rulings: DECISIONS.md and docs/decisions/.
- Plans and concept maps: docs/discussion-outputs/.
- The remote is https://github.com/Jess-Rivera/poketactics.git.
- Reference only (never a code source, see CLAUDE.md "Clean-room rule"): C:\dev\pokesurvivor_fork.
