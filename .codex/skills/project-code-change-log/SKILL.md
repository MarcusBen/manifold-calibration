---
name: project-code-change-log
description: "Project-specific code modification logging workflow for this manifold calibration repository. Use when the user says 修改代码, 改代码, 修改完代码记日志, 记录变更, 跑 case, 运行实验, 把图片放进 log, or asks to change MATLAB code and keep traceable docs/results; after code changes, generate one pending local short hash for the current version, use it consistently in docs/research-log.md and case result folders, store referenced images in docs/assets, and leave final replacement with the real Git commit hash to project-github-sync."
---

# Project Code Change Log

## Purpose

Use this skill whenever code or experiment behavior changes in this repository. Every change should leave a trace in `docs/research-log.md`, and every run should have a unique result directory so older outputs remain reproducible.

## Required Project Conventions

- Main log: `docs/research-log.md`
- Optional read-only reference: `docs/comments.md`
- Documentation images: `docs/assets/`
- Run outputs before upload: `results/<case-name>/<YYYYMMDD-HHMMSS>-<pending-local-hash>/`
- Run outputs after upload finalization: `results/<case-name>/<YYYYMMDD-HHMMSS>-<git-code-commit-hash>/`

Generate one pending local hash after code edits are complete and before writing logs or running cases. Use the same pending local hash everywhere for that code-change batch. `project-github-sync` later replaces that exact pending local hash with the real Git code/results commit hash.

In short: project-github-sync later replaces the pending local hash; this skill only creates and uses it consistently.

## Hash Trace Policy

Use one pending local hash consistently across logs and case results for a given code-change batch.

- After code edits are complete, generate a pending local hash with `.codex/skills/project-code-change-log/scripts/new_local_hash.py`.
- Use the generated value, such as `local-a1b2c3d4`, in the log title, log metadata, result directory names, and `RUN_NOTES.md`.
- Do not use `git rev-parse --short HEAD` as the primary version id during an uncommitted code-change batch; it points to the previous commit, not the just-edited code.
- Record the current `HEAD` short hash separately as the base commit when useful.
- If code changes are uncommitted, explicitly record `git status --short` in both the log entry and `RUN_NOTES.md`.
- Let `project-github-sync` replace the exact pending local hash with the real Git code/results commit hash after commit.
- Treat `docs/comments.md` as read-only reference material. It may inform the motivation for a change, but this skill must not create, edit, summarize, or reorganize `docs/comments.md`.

Generate the pending local hash with:

```bash
py -X utf8 .codex/skills/project-code-change-log/scripts/new_local_hash.py
```

If `py` is unavailable, use any equivalent command that creates a unique lowercase value matching `local-[0-9a-f]{8}`.

## Before Editing Code

1. Inspect `git status --short`.
2. Identify existing user changes and avoid overwriting them.
3. Read the relevant code, config, and current `docs/research-log.md` entry.
4. If the requested change explicitly relates to review feedback or prior comments, read `docs/comments.md` only as reference.
5. After the code edits are complete, generate one pending local hash and keep it unchanged for the rest of this task.

## Result Directory Rule

Before running any case or experiment, create or configure a fresh output path:

```text
results/<case-name>/<YYYYMMDD-HHMMSS>-<pending-local-hash>/
```

Examples:

```text
results/case09_two_source_resolution/20260418-091530-local-a1b2c3d4/
results/case01_problem_validation/20260418-101245-local-a1b2c3d4/
```

Never reuse an existing run directory, even for the same case and same parameters. Do not overwrite historical `.mat`, `.png`, `.csv`, or summary files.

When the run uses uncommitted changes, add a short provenance file in the run directory, for example `RUN_NOTES.md`, containing:

- timestamp
- pending local hash
- base `HEAD` short hash
- `git status --short`
- command or case that was run
- important config overrides

## Research Log Update

After changing code, update `docs/research-log.md` in UTF-8. Add a new dated entry near the latest section unless the user requests another location.

Each entry should include:

- pending local hash in the title or first metadata lines
- base `HEAD` short hash when the worktree is uncommitted
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

- Version hash: `local-a1b2c3d4`
- Base HEAD: `abc1234`
- Worktree state: clean / uncommitted code changes
- Change:
- Affected cases:
- Validation:
- Result path:
- Remaining risk:
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
- Do not create, edit, summarize, or reorganize `docs/comments.md`; code-change runs update `docs/research-log.md` and run metadata only.
- Do not use comments written for a different commit hash as current-version evaluation.
- Do not generate a new pending local hash for each case in the same code-change batch; reuse the same one.
- Mention any test or run that could not be completed.

## Completion Checklist

Before finishing a code-change task using this skill, confirm:

- Code/config changes are complete.
- Each executed case wrote to a unique run directory under `results/`.
- Any documentation image was copied to `docs/assets/` and referenced from there.
- `docs/research-log.md` records the pending local hash, base HEAD, change, validation, result path, and remaining risk.
- `git status --short` has been checked and unrelated user changes are preserved.
