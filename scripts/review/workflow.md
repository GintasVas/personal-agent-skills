# Shared review workflow

The parent runs these steps in the order in the skill. Replace
`<this-skill-dir>` with the absolute path to that skill. Run its bundled
scripts as shown. Do not inspect script source.

## Select models

Before preparing review input, read only the matching host guide:

- [Pi](hosts/pi.md) when `PI_CODING_AGENT=true` or the system prompt names Pi. This takes precedence over Cursor SDK detection.
- [Cursor desktop](hosts/cursor-desktop.md) or [Cursor Agent CLI](hosts/cursor-cli.md).
- [Codex](hosts/codex.md).
- Amp. Use this thread's `agentMode` from `amp.get_thread_status`. Launch one worker with `Task`. Skip the chooser.
- [Other hosts](hosts/other.md).

Use the host chooser when supported and no model is given. Repeat `--model`
for multiple workers. Deduplicate exact selections in order. Verify the exact
selectors using the host guide. If one is unavailable, show it and the
available choices, then ask again before launch. Never substitute a model.

After a chooser response, start the next chat message with
`Selected: <exact slug>.` for each model in order, or the host's equivalent.
Use these names in chat. Follow the target repo's writing rules and use plain
technical English.

## Prepare input

For a PR, run:

```bash
node <this-skill-dir>/scripts/prepare-pr-review-input.mjs prepare "<PR>"
```

For all scopes, set `REVIEW_DIR` from the reported `directory`. If preparation
fails or omits the directory, report the failure and stop. Use the generated
input for scope and anchors. For PRs, use the detached head worktree `source` as
`code_root`, including for stack context. Run the host's required preflight
there before building bundles. For local scopes, use the reported repo root.

For a PR, use `changedPathsPreview` and the full `changedPaths` file to
determine scope. `mergeBaseOid` is the diff base and `baseRefOid` is the base
branch tip. Use the saved `description` and `linkedIssues` files.

## Scope large reviews

Use prepare's file and line totals. A repo can group related paths in
`.review-groups.json` with `{"groups":{"feature":["api/contract.yml","src/feature/"]}}`.
A trailing slash matches a directory. Refine `hunkIds` in the generated
`review-bundles.json`. Assign every reviewable unit exactly once.

```bash
node <this-skill-dir>/scripts/build-review-bundles.mjs \
  "$REVIEW_DIR/manifest.json" "$REVIEW_DIR/review-bundles.json"
node <this-skill-dir>/scripts/verify-review-bundles.mjs \
  "$REVIEW_DIR/manifest.json" "$REVIEW_DIR/materialized-review-bundles.json"
```

Launch only after verification succeeds. Give every model all verified bundles
in order. Pass the generated `review-index.json`; workers use the per-bundle
anchors. The parent does not read the global line map.

## Run reviewers

Use the scope and repo routing once to select required standards. If any apply,
write their repo-relative paths as a JSON array in `REVIEW_DIR/required-standards.json`.
Append a context file path only for settings or writing rules the worker lacks.
Pass untrusted text by path.

```bash
node <this-skill-dir>/scripts/render-reviewer-prompt.mjs \
  "$REVIEW_DIR" 1 "<exact slug>" "<worker.md>"
```

Build each prompt before launch.
For each model, record its numbered prompt, final result, and runner or
subagent ID. Use the host guide. Give the exact model the prompt by file
path when supported. Launch concurrently where supported. Save the full
final result directly when possible, then verify:

```bash
node <this-skill-dir>/scripts/review-results.mjs verify \
  "$REVIEW_DIR/manifest.json" "$REVIEW_DIR/reviewer-1.result" "<exact slug>"
```

Read every verified result before synthesis. Retry incomplete output once when
the host can resume the worker. If any launch or result remains incomplete,
report the failure and expected and launched counts. Stop synthesis.
The parent does not review.

## Verify and report

For a PR, verify before presenting:

```bash
node <this-skill-dir>/scripts/prepare-pr-review-input.mjs verify "<PR>" "$REVIEW_DIR/manifest.json"
```

If verification fails, report the actual reason. Treat the results as
unverified and do not post. If the patch changed, mark the results stale.
When verification returns `contextChangesPath`, mark results stale if their
`evidencePaths` or required standards intersect that list. If the list has
entries and a result lacks evidence paths, recheck it on fresh input. Post only
verified entries using the verified `headRefOid`.

Name the exact models that ran. Use the canonical heading and body. Show
supporting models and differing priorities or confidence in chat. Keep
ambiguous matches separate. Synthesize without discovering new findings.
Show at most three unverified candidates after deduplication, separate from
confirmed findings. Candidates without changed-line anchors stay in chat.
Keep rejection notes within the review.

## Post approved findings

Post only what the user explicitly approved. For local reviews, report in chat.

```bash
node <this-skill-dir>/scripts/review-results.mjs approve "$REVIEW_DIR/manifest.json" \
  "$REVIEW_DIR/approved-selection.json" > "$REVIEW_DIR/approved-comments.json" &&
node <this-skill-dir>/scripts/post-inline-pr-comments.mjs "<PR>" "<headRefOid>" \
  "$REVIEW_DIR/manifest.json" "$REVIEW_DIR/approved-comments.json"
```

List the approved entries by source result file and one-based index:

```json
{
  "selectedModels": ["<exact slug>", "<exact slug>"],
  "entries": [{
    "result": "reviewer-1.result",
    "number": 1,
    "modelSlugs": ["<reporting model slug>"]
  }]
}
```

Number all postable entries in one list. Post approved unverified candidates
individually on their changed lines. Reuse the approved payload on retry.
Report posted URLs, `alreadyPosted=<url>`, and any failure.

## Cleanup

Keep `REVIEW_DIR` while awaiting a posting decision. Remove it after posting,
declining, rejecting stale results, or completing a local review. For local
digest verification, also remove the temporary directory from the recheck.

```bash
node <this-skill-dir>/scripts/cleanup-review-input.mjs "<reported-directory>"
```
