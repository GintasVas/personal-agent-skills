# Cursor Agent CLI

`<skill>` is the directory of the skill that sent you here. "Reviewer" is that skill's worker, and
"code root" is the pinned root it names.

## Model selection

Use exact slugs from `cursor-agent --list-models`. Exclude `auto`, which does
not identify the model that ran. If the user omits `--model`, ask for
comma-separated exact slugs. Wait before preparing input.

## Verify model availability

For a PR, verify availability from the detached source before building bundles:

```bash
cursor-agent --workspace "$source" --list-models
```

Model listing does not verify workspace trust. The launch can require trust
for both `source` and `REVIEW_DIR`. If Cursor prompts, obtain interactive
approval for each displayed path, then retry. Never add `--trust` automatically.

## Launch reviewers

After you verify availability, run each job with Cursor Ask mode against the code root. Write the
complete prompt for each model to its own numbered file under `REVIEW_DIR`, then run:

```bash
node <this-skill-dir>/scripts/cursor-run-reviewer.mjs \
  "<exact Cursor slug>" "$REVIEW_DIR/reviewer-1.prompt" \
  "$REVIEW_DIR/reviewer-1.result" "<code root>"
```

The runner verifies model availability, launches a separate model-pinned reviewer, and prints its
`reviewerId`, model, and result path only on success.
