---
name: project-github-sync
description: "Project-specific GitHub upload workflow for this manifold calibration repository. Use when the user says s上传, 上传, 上传到 GitHub, 同步到仓库, push, commit and push, or asks to publish this project; before pushing, update README.md by reading docs/comments.md and docs/research-log.md, compare reviewed commit hashes in comments with the current local or published version, explicitly mark hash mismatches as unevaluated current versions, protect existing local changes, then commit and push to origin/main by default."
---

# Project GitHub Sync

## Purpose

Use this skill to publish this repository to GitHub without losing the research context. The README is the public entry point, so it must be reconciled with both `docs/comments.md` and `docs/research-log.md` before any push.

## Required Inputs

Work from the repository root. Treat these files as required project sources:

- `README.md`
- `docs/comments.md`
- `docs/research-log.md`

Also inspect the current implementation and repository state:

- `git status --short`
- Relevant changed files from `git diff --stat` and targeted `git diff`
- Current branch and remote from `git branch --show-current` and `git remote -v`
- Local hash from `git rev-parse --short HEAD`
- Remote hash when available from `git ls-remote origin refs/heads/main`

## Hash Matching Policy

Use commit hashes to decide whether `docs/comments.md` can be treated as an evaluation of the current version.

- Treat each review/comment entry as applying only to the commit hash it names.
- Prefer a clear comment marker such as `Reviewed commit: abc1234` or a heading such as `## Review for commit abc1234`.
- Before using comments as evidence, compare the latest reviewed commit hash in `docs/comments.md` with the current version hash.
- If the hashes differ, write in `README.md` that the current version has no matching review yet. Do not merge the old comments into the current conclusion.
- If the hashes match, reconcile `docs/comments.md` with `docs/research-log.md` and the current code, then explicitly list any conflicts.
- If comments have no identifiable reviewed hash, treat them as general background only and mark the current version as not hash-reviewed.

Distinguish two hashes when needed:

- Local/research hash: the `HEAD` short hash used by logs, case runs, and result folders before upload.
- Published hash: the commit hash produced by the upload commit and pushed to GitHub.

If those differ, record both in `README.md`. It is acceptable for `docs/research-log.md` and case results to share the local/research hash while the README maps that hash to the published GitHub hash.

## Workflow

1. Read the three project documents before editing anything.
2. Determine the local/research hash and the latest reviewed hash from `docs/comments.md`.
3. Compare hashes before comparing claims:
   - If the latest reviewed hash does not match the current local/research hash or intended published hash, mark the current version as not yet reviewed.
   - If the latest reviewed hash matches, compare `docs/comments.md`, `docs/research-log.md`, and the current code/config state.
4. Update `README.md` first:
   - Refresh the latest summary.
   - Keep the current repository status accurate.
   - Record the local/research hash, intended or actual published hash, and latest reviewed comments hash.
   - Add or update a reminder section when `comments`, `research-log`, or code disagree.
   - Add a visible reminder when comments are for an older hash and the current version has not been evaluated.
   - Do not smooth over disagreements into a false consensus.
5. Run `git status --short` again and identify exactly which files belong to the upload.
6. Stage only the intended project files. Do not stage unrelated user changes unless the upload explicitly includes them.
7. Commit with a message that reflects the actual scope, such as README/docs/code/results updates.
8. Push to `origin main` by default unless the user explicitly requests another branch.
9. After a successful commit/push, if the published hash changed, update or confirm the README version map if the task includes a second documentation commit; otherwise report the pushed hash so the user can review that exact version and write hash-matched comments.

## README Rules

When updating `README.md`, write concise project-facing text:

- State what is confirmed by code and results.
- State what is only suggested by comments or a smoke run.
- State whether comments match the current hash.
- Keep a short version map when local/research and published hashes differ.
- State unresolved inconsistencies under a visible reminder heading.
- Never describe a smoke/proof-of-trend run as a final benchmark.
- Keep links to `docs/research-log.md` and `docs/comments.md`.

Recommended README shape:

```markdown
## Version Trace

- Local/research hash: `abc1234`
- Published GitHub hash: `def5678`
- Latest reviewed comments hash: `abc1234`
- Review status: comments match the research hash but not the latest README-only publish commit.
```

If a claim appears in `docs/comments.md` but is not confirmed by `docs/research-log.md` or current code, preserve it as a reminder, for example:

```markdown
## Reminder: docs, comments, and code are not fully aligned

- `comments` mentions ..., but the current code/log only confirms ...
```

## Safety Rules

- Treat Markdown and Chinese text as UTF-8.
- Do not overwrite, delete, or revert existing user changes.
- Do not run destructive git commands such as `git reset --hard` or `git checkout --`.
- Do not commit generated caches or temporary smoke folders unless the user explicitly wants them published.
- If the worktree contains unrelated changes, leave them unstaged and mention them.
- If push fails because the remote has advanced, stop and report the pull/rebase choice instead of forcing.
- Do not treat comments for one hash as a review of another hash.
- If the current version has no matching reviewed hash, say that plainly in README and in the final response.

## Default Git Commands

Use these defaults only after README reconciliation is complete:

```bash
git status --short
git add README.md docs/research-log.md docs/comments.md <intended-code-or-result-files>
git commit -m "update project documentation and results"
git push origin main
```

Adjust the staged paths and commit message to match the actual change set.
