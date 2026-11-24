---
name: simplify-code
description: Review local changes, paths, or a PR for behavior-preserving simplifications, mixed responsibilities, extension seams, duplication, and inconsistent patterns.
argument-hint: '[<PR number|URL>|<path>...] [--model <slug>]'
disable-model-invocation: true
---

# Simplify code

Run `/simplify-code [<PR>|<path>...] [--model <slug>]`. In Pi, use
`/skill:simplify-code` with `[--model <cursor-slug|provider/id[:thinking]>]`.
Edit or post only on explicit request after showing findings.

## Select models

Follow [Select models](workflow.md#select-models).

## Prepare input

A PR number or GitHub pull URL selects a PR without checkout. Follow
[Prepare input](workflow.md#prepare-input). For local reviews, run one command:

```bash
node <this-skill-dir>/scripts/prepare-local-simplify-input.mjs changes
node <this-skill-dir>/scripts/prepare-local-simplify-input.mjs paths <path>...
```

Use `changes` with no scope to review staged, unstaged, and untracked changes.
Use `paths` for existing repo-relative files or directories. Reject invalid
scopes and mixed PR and path arguments. Retain the reported digest.

## Scope large reviews

Above 10 changed files or 500 changed lines, use bounded bundles. For paths,
count selected files and snapshot lines. Give public
interfaces, shared utilities, boundary adapters, stateful workflows, persistence,
and framework integration their own bundles. Group local implementation by
directory. Include only the changed importers needed to understand a new shared
module. Follow [Scope large reviews](workflow.md#scope-large-reviews).

## Run reviewers

Render `<this-skill-dir>/agents/code-simplifier.md`. The renderer includes all
of [simplification-lenses.md](simplification-lenses.md), including Common.

The renderer supplies the local digest and the bundle index, changes patch,
or whole-file manifest for the selected scope. Follow
[Run reviewers](workflow.md#run-reviewers).

## Verify and report

For local reviews, repeat preparation and warn of possible staleness if the
digest differs. Follow [Verify and report](workflow.md#verify-and-report).

Merge only reports with the same location, constraint, and simplification.
Number in-scope findings in P0 to P2 order.

## Post approved findings

For a PR, if approval is pending, ask
`Reply "post all", "post 1,3", or "post none".`
Follow [Post approved findings](workflow.md#post-approved-findings).

## Cleanup

Follow [Cleanup](workflow.md#cleanup).
