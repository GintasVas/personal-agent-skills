---
name: review-pr
description: Review a GitHub PR with model-pinned reviewers. Show findings in chat and post only on request.
disable-model-invocation: true
---

# Review PR

Run `/review-pr <PR> [--model <slug>]`. In Pi, use `/skill:review-pr`
with `[--model <cursor-slug|provider/id[:thinking]>]`. Ask for a PR number
or GitHub pull URL if absent.

## Select models

Follow [Select models](workflow.md#select-models).

## Prepare input

Follow [Prepare input](workflow.md#prepare-input) for the PR.

## Scope large reviews

Above 10 changed files or 500 changed lines, use bounded bundles. Keep
related high-risk changes together, including public interfaces, auth,
persistence, migrations, external I/O, concurrency, deployment configuration,
and errors. Group low-risk hunks by directory. Include only the changed
importers needed to understand a new shared module. Follow
[Scope large reviews](workflow.md#scope-large-reviews).

## Run reviewers

Render `<this-skill-dir>/agents/code-reviewer.md`. The renderer includes all of
[shaping-lenses.md](shaping-lenses.md), including Common.

Identify changed specs from the manifest and repo conventions. Skip test
files. Pass the repo-relative spec paths and require the requirements pass,
including for spec-only PRs. Pass any originating spec by path. Save available
originating issue text in `REVIEW_DIR` and pass its absolute path.

Follow [Run reviewers](workflow.md#run-reviewers).

## Verify and report

Follow [Verify and report](workflow.md#verify-and-report). On
`descriptionChanged=true`, recheck description notes on fresh input.
Merge reports only when location and mechanism match. Enforce the worker's maintainability gate
without turning rejected findings into alternatives.

Separate requirements findings and say what conformance could not be verified.
Use one numbered list across both groups, in P0 to P2 order within each.
List design alternatives separately.

## Post approved findings

If approval is pending, ask `Reply "post all", "post 1,3", or "post none".`
Exclude design alternatives and description notes. Follow
[Post approved findings](workflow.md#post-approved-findings).

## Cleanup

Follow [Cleanup](workflow.md#cleanup).
