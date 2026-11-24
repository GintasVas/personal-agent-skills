# Shared review workflow

The parent runs these steps in the order in the skill. Replace
`<this-skill-dir>` with the absolute path to that skill. Run its bundled
scripts as shown. Do not inspect script source.

## Select models

Before running commands, read only the matching host guide:

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

## Scope large reviews

Group related units by editing only `hunkIds` in the generated
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

Pass the worker contract, required lens or rule material, applicable writing
rules, absolute input paths and `code_root`, and `Reviewer model: <exact slug>`.
For a bundled PR, pass `review-index.json` and `source`. For a small PR, pass
`patch.diff`, `line-map.json`, `manifest.json`, and `source` by path.

Keep one private job per selected model in selection order. Use separate
numbered prompt and result files. Launch the prompt directly with the
host-selected model and code root. Launch concurrently where supported.
Record the runner session or subagent ID and result against each job.

Before synthesis, require one attributable launch and one complete result for
each selected model. If any launch or result fails or is missing, report the
failure and expected and launched counts. Stop synthesis. Show counts only
on failure. The parent does not review.

## Verify and report

For a PR, verify before presenting:

```bash
node <this-skill-dir>/scripts/prepare-pr-review-input.mjs verify "<PR>" "$REVIEW_DIR/manifest.json"
```

If verification fails, report the actual reason. Treat the results as
unverified and do not post. If the patch changed, mark the results stale.
When verification returns `contextChangesPath`, mark results stale if their
`evidencePaths` intersect that list. If the list has entries and a result lacks
evidence paths, recheck it on fresh input. Post only verified entries using the verified
`headRefOid`.

Name the exact models that ran. Use the canonical heading and body. Show
supporting models and differing priorities or confidence in chat. Keep
ambiguous matches separate. Synthesize without discovering new findings.

## Post approved findings

Post only what the user explicitly approved. For local reviews, report in chat.

```bash
node <this-skill-dir>/scripts/post-inline-pr-comments.mjs "<PR>" "<headRefOid>" "$REVIEW_DIR/manifest.json" -
```

Pass the approved comments as one JSON object on standard input:

```json
{
  "selectedModels": ["<exact slug>", "<exact slug>"],
  "comments": [{
    "body": "<canonical heading and body>",
    "findingKey": "<stable finding identity>",
    "modelSlugs": ["<reporting model slug>"],
    "evidencePaths": ["<repo-relative evidence path>"],
    "path": "<path>",
    "line": 1,
    "side": "RIGHT",
    "anchor": "<full changed line>"
  }]
}
```

For an unanchored entry, set `anchor: "none"` and omit `line` and `side`.
Use the same selection list for inline and unanchored entries. Pass the raw
body. The script adds attribution and markers. Reuse the approved payload
on retry. Report posted URLs, `alreadyPosted=<url>`, and any failure.

## Cleanup

Keep `REVIEW_DIR` while awaiting a posting decision. Remove it after posting,
declining, rejecting stale results, or completing a local review. For local
digest verification, also remove the temporary directory from the recheck.

```bash
node <this-skill-dir>/scripts/cleanup-review-input.mjs "<reported-directory>"
```
