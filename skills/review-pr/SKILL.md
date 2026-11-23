---
name: review-pr
description: Review a GitHub PR with model-pinned reviewers. Show findings in chat and post only on request.
disable-model-invocation: true
---

# Review PR

Run `/review-pr <PR> [--model <slug>]` or, in Pi,
`/skill:review-pr <PR> [--model <cursor-slug|provider/id[:thinking]>]`.
Require a PR number or GitHub pull URL. If absent, ask for it.

## Select models

Before any other tool call, read only the host file for model selection and launch:

- Pi ([hosts/pi.md](hosts/pi.md)) if `PI_CODING_AGENT=true` or the system prompt names Pi. This takes precedence over Cursor SDK detection.
- [Cursor desktop](hosts/cursor-desktop.md) or [Cursor Agent CLI](hosts/cursor-cli.md).
- [Codex](hosts/codex.md). Select the model and reasoning effort together.
- Amp. Use this thread's `agentMode` from `amp.get_thread_status`. Launch one worker with `Task`. Skip the chooser.
- [Other hosts](hosts/other.md).

Without `--model`, use the chooser where supported. With `--model <slug>`, use
that exact slug. Repeat `--model` for multiple workers. Remove exact duplicates
in selection order. Match slugs against the host's available list. If any is
unavailable, stop before launch. Show the unavailable slug and exact available
slugs. Ask for a new selection. Never normalize, invent, or substitute slugs.

After a chooser response, put this first in the next chat message:
`Selected: <exact slug>.` for each selection, in order. Use those exact names
in later chat. Apply the target repo's writing rules when available. Use plain
technical English for chat, findings, and comments.

## Prepare the review

Run the bundled scripts at the steps below. Replace `<this-skill-dir>`
with the absolute path to this skill directory. Do not inspect script source.

```bash
node <this-skill-dir>/scripts/prepare-pr-review-input.mjs prepare "<PR>"
```

Use the reported `directory` as `REVIEW_DIR`. Use the detached head worktree
`source` for all PR context, including stack parents. The patch covers the
declared base-to-head delta. Run any host-required `source` preflight before
building bundles.

If prepare fails or does not report `directory`, report the failure and stop.
Do not construct substitute patches, manifests, line maps, or bundles.

## Scope large reviews

Above 10 changed files or 500 changed lines, give workers bounded bundles
instead of the full patch. Include changed public interfaces, authentication,
authorization, persistence, migrations, external I/O, concurrency, deployment
configuration, and error handling. Group low-risk hunks by directory. Keep
generated files, lockfiles, and snapshots in the manifest. Bundle each
reviewable hunk exactly once. Bundle a new shared module with only the changed
importers needed to understand it.

Use `$REVIEW_DIR/review-bundles.json`. It groups reviewable hunks by
`bundleCandidate`. Change only `hunkIds` to group related files.

```bash
node <this-skill-dir>/scripts/build-review-bundles.mjs \
  "$REVIEW_DIR/manifest.json" "$REVIEW_DIR/review-bundles.json"
node <this-skill-dir>/scripts/verify-review-bundles.mjs \
  "$REVIEW_DIR/manifest.json" "$REVIEW_DIR/materialized-review-bundles.json"
```

Verify bundles before launch. Give all verified bundles to every model.
Each model reviews them in order. Use the generated `review-index.json` and
per-bundle anchors. The parent does not read the global line map.

## Run reviewers

Classify the changes as UI, service and API, data model, infrastructure and
pipelines, or shared library. Copy only the matching sections of
[shaping-lenses.md](shaping-lenses.md) into each worker prompt. Use lenses to identify
candidates. Repository standards and established patterns
take precedence.

Keep one private job per selected model, in selection order:

```text
{ model: "<exact slug>", reviewerId: "pending", status: "planned" }
```

Read `<this-skill-dir>/agents/code-reviewer.md`. Put its contract and
`Reviewer model: <exact slug>` in the prompt. Include applicable writing rules,
absolute input paths, and absolute `source`. Use separate numbered prompt and
result files for each model. Launch by the host instructions with the exact
model slug and `source` as its code root. Launch concurrently where supported.
Pi may run reviewers in sequence. Pass the prompt directly without
invoking `/review-pr`.

Record the returned runner session or native subagent ID in `reviewerId`.
Set status to `launched`. Before accepting results, match the job list to
the selection. Require one launched reviewer per selected model. If a launch
is missing, fails, or cannot be attributed, report expected and launched
counts. Keep counts and the job list out of successful output. Read every
result before synthesis. Stop synthesis if a launch or result fails or is missing.
Report the failure.
Do not attribute findings to that model or present the review as complete.

For bundled PRs, pass `review-index.json` and `source`. For small PRs, pass
`patch.diff`, `line-map.json`, `manifest.json`, and `source`. Pass paths only.

## Verify and report

```bash
node <this-skill-dir>/scripts/prepare-pr-review-input.mjs verify "<PR>" "$REVIEW_DIR/manifest.json"
```

Verify before presentation. If verification fails, warn that the patch changed
and the findings are stale. Do not post. If the head moved and the patch stayed
the same, verification returns a new `headRefOid` and `contextChangesPath`.
Mark findings stale when they rely on traced code in that list.
Use the verified `headRefOid` to post.

Name the exact models that ran. Synthesize without discovering new findings.
Merge same-anchor reports only when they identify the same mechanism. Show the canonical
postable comment and supporting models. Keep original wording in chat and
keep ambiguous reports separate.

A maintainability finding needs a changed anchor, concrete cost, bounded
correction, and support from a repo standard or established pattern.
Otherwise, offer a design alternative only if it names the constraint,
alternative, cost, and rejected simpler variant.

Number postable findings in P0 to P2 order. List alternatives separately.
Never post design alternatives. Ask:
`Reply "post all", "post 1,3", or "post none".`

## Post approved findings

Post only if this turn asks to.

```bash
node <this-skill-dir>/scripts/post-inline-pr-comments.mjs "<PR>" "<headRefOid>" -
```

Pass the selected models and approved inline findings as one JSON object on
standard input.

```json
{
  "selectedModels": ["<exact slug>", "<exact slug>"],
  "comments": [{
    "body": "<canonical finding body>",
    "modelSlugs": ["<exact slug>"],
    "path": "<path>",
    "line": 1,
    "side": "RIGHT",
    "anchor": "<full changed line>"
  }]
}
```

List only the jobs that reported each finding in `modelSlugs`. Omit
the `Found by` footer from `body`. The script verifies model metadata
and adds the footer in `selectedModels` order.
The script verifies and posts the full batch. It prints one URL per inline
comment.

`post all` includes approved `Unrelated discovered issue` findings.
`post 1,3` selects from the same list for inline and unrelated findings.
Verify the current `headRefOid` before posting an unrelated finding as one
standalone PR comment. Its first line is `[Unrelated discovered issue] [P1, confidence 85]`.

## Cleanup

Keep the reported directory while you show findings and wait for a posting
decision. Remove it after posting, declining, or rejecting stale findings.

```bash
node <this-skill-dir>/scripts/cleanup-review-input.mjs "<reported-directory>"
```

Prepare prunes marked inputs older than 24 hours. To prune now, run
`cleanup-review-input.mjs --stale`.
