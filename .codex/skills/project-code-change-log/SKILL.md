---
name: project-code-change-log
description: "Project-specific code modification logging workflow for this manifold calibration repository. Use when the user says 修改代码, 改代码, 修改完代码记日志, 记录变更, 跑 case, 运行实验, 把图片放进 log, or asks to change MATLAB code and keep traceable docs/results; after code changes, update docs/research-log.md with the local research hash, store referenced images in docs/assets, and put every run under a unique results case folder named with timestamp plus git short hash."
---

# Project Code Change Log

## Purpose

Use this skill whenever code or experiment behavior changes in this repository. Every change should leave a trace in `docs/research-log.md`, and every run should have a unique result directory so older outputs remain reproducible.

## Required Project Conventions

- Main log: `docs/research-log.md`
- Review/comment source: `docs/comments.md`
- Documentation images: `docs/assets/`
- Run outputs: `results/<case-name>/<YYYYMMDD-HHMMSS>-<git-short-hash>/`

Use the current `HEAD` short hash for `<git-short-hash>`. If the worktree has uncommitted changes, still use the current `HEAD` hash and write a small run note in the result directory stating that the run used an uncommitted worktree.

## Hash Trace Policy

Use one local/research hash consistently across logs and case results for a given code state.

- Record `git rev-parse --short HEAD` in every new log entry that describes code behavior or run results.
- Use the same short hash in the result run directory name.
- If code changes are uncommitted, use the current `HEAD` hash as the base hash and explicitly record `git status --short` in both the log entry and `RUN_NOTES.md`.
- Do not pretend an uncommitted run corresponds exactly to a clean commit; call it `HEAD plus uncommitted changes`.
- Let `project-github-sync` map this local/research hash to the later published GitHub hash in `README.md` when upload creates a new commit.
- When `docs/comments.md` is later written for a reviewed GitHub commit hash, only combine it with log conclusions if that hash matches the relevant local/research or published hash mapping in `README.md`.

## Before Editing Code

1. Inspect `git status --short`.
2. Identify existing user changes and avoid overwriting them.
3. Read the relevant code, config, and current `docs/research-log.md` entry.
4. If a requested change relates to an existing review point, also read `docs/comments.md`.

## Result Directory Rule

Before running any case or experiment, create or configure a fresh output path:

```text
results/<case-name>/<YYYYMMDD-HHMMSS>-<git-short-hash>/
```

Examples:

```text
results/case09_two_source_resolution/20260418-091530-a1b2c3d/
results/case01_problem_validation/20260418-101245-a1b2c3d/
```

Never reuse an existing run directory, even for the same case and same parameters. Do not overwrite historical `.mat`, `.png`, `.csv`, or summary files.

When the run uses uncommitted changes, add a short provenance file in the run directory, for example `RUN_NOTES.md`, containing:

- timestamp
- `HEAD` short hash
- `git status --short`
- command or case that was run
- important config overrides

## Research Log Update

After changing code, update `docs/research-log.md` in UTF-8. Add a new dated entry near the latest section unless the user requests another location.

Each entry should include:

- local/research hash
- why the change was made
- what files or behavior changed
- which case(s) are affected
- what validation or run was performed
- where the result directory is
- what remains uncertain or risky
- whether the result is smoke/proof-of-trend or final benchmark

Keep the tone factual. Do not upgrade tentative evidence into a final conclusion.

Recommended entry skeleton:

```markdown
### YYYY-MM-DD: short change title

- Local/research hash: `abc1234`
- Worktree state: clean / HEAD plus uncommitted changes
- Change:
- Affected cases:
- Validation:
- Result path:
- Remaining risk:
- Comment/review status: no matching reviewed hash yet / comments for `abc1234` reviewed this version
```

## Image Handling

If the log mentions or embeds an image:

1. Store the image under `docs/assets/`.
2. Use a descriptive lowercase filename with hyphens, including the case or topic when possible.
3. Reference it from Markdown with a relative path from `docs/research-log.md`:

```markdown
![case09 smoke result](assets/case09-two-source-resolution-smoke.png)
```

Do not place documentation images in the repository root. Do not reference images directly from `results/` in long-lived docs, because run folders may be reorganized or ignored later.

## Safety Rules

- Treat Markdown and Chinese text as UTF-8.
- Do not delete, revert, or rewrite user changes unless explicitly requested.
- Do not run formatters or code generators that rewrite unrelated files.
- Do not move historical results into the new structure unless the user explicitly asks.
- Do not write final-paper claims from smoke tests.
- Do not use comments written for a different commit hash as current-version evaluation.
- Mention any test or run that could not be completed.

## Completion Checklist

Before finishing a code-change task using this skill, confirm:

- Code/config changes are complete.
- Each executed case wrote to a unique run directory under `results/`.
- Any documentation image was copied to `docs/assets/` and referenced from there.
- `docs/research-log.md` records the local/research hash, change, validation, result path, and remaining risk.
- `git status --short` has been checked and unrelated user changes are preserved.
