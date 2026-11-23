# Cursor Agent CLI

`<skill>` is the directory of the skill that sent you here. "Reviewer" is that skill's worker, and
"code root" is the pinned root it names.

## Model selection

Use exact slugs from `cursor-agent --list-models` and exclude `auto`, which does not identify the
model that ran. When no `--model` is given, ask in chat for comma-separated exact slugs and wait
for the answer before preparing input.

## Preflight a pull request source

For a pull request, before materializing review bundles, preflight workspace trust for the
detached `source`:

```bash
cursor-agent --workspace "$source" --list-models
```

If Cursor asks to trust the detached source, ask the user to approve it interactively, then retry
the preflight. Never add `--trust` automatically.

## Launch reviewers

After any preflight succeeds, run each job with Cursor Ask mode against the code root. Write the
complete prompt for each model to its own numbered file under `REVIEW_DIR`, then run:

```bash
node <this-skill-dir>/scripts/cursor-run-reviewer.mjs \
  "<exact Cursor slug>" "$REVIEW_DIR/reviewer-1.prompt" \
  "$REVIEW_DIR/reviewer-1.result" "<code root>"
```

The runner checks model availability, launches a separate model-pinned reviewer, and prints its
`reviewerId`, model, and result path only on success.
