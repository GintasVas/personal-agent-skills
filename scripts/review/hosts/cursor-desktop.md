# Cursor desktop GUI

"Reviewer" is the worker of the skill that sent you here, and "code root" is the pinned root it
names.

## Model selection

Use the exact slugs available to the native model-pinned subagent mechanism. When no `--model` is
given, invoke `AskQuestion` with the exact available slugs and wait for the answer before preparing
input. If a selected slug is unavailable to the native subagent, invoke `AskQuestion` again with
the supported slugs.

## Launch reviewers

Use native `generalPurpose` when it can pin the exact model. Stop if exact
selection is unavailable. Give it the pinned code root and say "Read
`<absolute prompt path>` and follow it exactly."
Use read-only mode. If the host can grant a single-file write exception, direct
the worker to put its final JSON in the exact numbered result file.

Otherwise prefer native final-message capture. For a known transcript from
this subagent, use:

```bash
node <this-skill-dir>/scripts/review-results.mjs capture "$REVIEW_DIR/manifest.json" \
  "<subagent JSONL>" "$REVIEW_DIR/reviewer-1.result" "<exact slug>"
```

If capture fails, save the worker's complete final message verbatim. Launch
concurrently where supported. Do not invoke Cursor CLI from the desktop GUI.
