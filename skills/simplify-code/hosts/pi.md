# Pi

`<skill>` is the directory of the skill that sent you here. "Reviewer" is that skill's worker, and
"code root" is the pinned root it names.

This file applies whenever Pi runs the skill, including through the Cursor SDK extension, where
Cursor tools and `CURSOR_*` variables are also present. Use the shell tool the session exposes for
the commands below.

## Model selection

Pi has no skill-level model picker, and `PI_PROVIDER` and `PI_MODEL` may be unset. Do not use the
session's own model for reviewer selection.

When no `--model` is given, select Cursor Agent model `claude-opus-5-5-high`. An explicit selector
without a `/` is a Cursor slug; accept it only if `cursor-agent --list-models` lists it exactly and it is not `auto`. A
selector with a `/` is a Pi `provider/id[:thinking]` selector; accept it only if
`pi --no-approve --no-extensions --no-mcp --no-skills --list-models` lists it and
`pi auth check --model provider/id` succeeds. Extension-backed Pi models, including Cursor SDK
models, are not available to the Pi runner; select the matching Cursor slug instead. If any check
fails, stop before preparing input and show the available selectors.

## Preflight a pull request source

When any selected model is a Cursor slug, after prepare reports `source` and before materializing
review bundles, check workspace trust:

```bash
cursor-agent --workspace "$source" --list-models
```

If Cursor asks to trust the detached source, ask the user to approve it interactively, then retry.
Never add `--trust` automatically. If the preflight fails, stop before materializing bundles.

## Launch reviewers

Run every reviewer through the pinned CLI runner for its selector, never through a subagent that
cannot pin the requested model. Write the complete prompt for each model to its own numbered file
under `REVIEW_DIR`, then run the Cursor runner for a Cursor slug (Ask mode):

```bash
node <this-skill-dir>/scripts/cursor-run-reviewer.mjs \
  "<exact Cursor slug>" "$REVIEW_DIR/reviewer-1.prompt" \
  "$REVIEW_DIR/reviewer-1.result" "<code root>"
```

or the Pi runner for a Pi selector:

```bash
node <this-skill-dir>/scripts/pi-run-reviewer.mjs \
  "<exact provider/id[:thinking]>" "$REVIEW_DIR/reviewer-1.prompt" \
  "$REVIEW_DIR/reviewer-1.result" "<code root>"
```

Each runner checks model availability, launches a separate model-pinned reviewer, and prints its
`reviewerId`, model, and result path only on success. Pi may run jobs serially.
