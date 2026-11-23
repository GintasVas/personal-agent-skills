# Pi

`<skill>` is the directory of the skill that sent you here. "Reviewer" is that skill's worker, and
"code root" is the pinned root it names.

This file applies whenever Pi runs the skill, including through the Cursor SDK extension, where
Cursor tools and `CURSOR_*` variables are also present. Use the shell tool the session exposes for
the commands below.

## Model selection

Pi has no skill-level model picker, and `PI_PROVIDER` and `PI_MODEL` may be unset. Do not use the
session's own model for reviewer selection.

If the user omits `--model`, select Cursor Agent model `claude-opus-5-5-high`.
A selector without a slash is a Cursor slug. Require an exact match in
`cursor-agent --list-models` and exclude `auto`.
A selector with a slash is a Pi `provider/id[:thinking]` selector. Require
a match in `pi --no-approve --no-extensions --no-mcp --no-skills --list-models`
and success from `pi auth check --model provider/id`.
The Pi runner cannot use extension-backed models, including Cursor SDK
models. Select the matching Cursor slug for those models.
If model verification fails, stop before preparing input. Show available selectors.

## Verify Cursor model availability

When any selected model is a Cursor slug, verify availability from the
detached source before building bundles:

```bash
cursor-agent --workspace "$source" --list-models
```

Model listing does not verify workspace trust. The launch can require trust
for both `source` and `REVIEW_DIR`. If Cursor prompts, obtain interactive
approval for each path in the prompt, then retry. Never add `--trust` automatically.
If availability verification fails, stop before building bundles.

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

Each runner verifies model availability, launches a separate model-pinned reviewer, and prints its
`reviewerId`, model, and result path only on success. Pi may run jobs serially.
