# Cursor desktop GUI

"Reviewer" is the worker of the skill that sent you here, and "code root" is the pinned root it
names.

## Model selection

Use the exact slugs available to the native model-pinned subagent mechanism. When no `--model` is
given, invoke `AskQuestion` with the exact available slugs and wait for the answer before preparing
input. If a selected slug is unavailable to the native subagent, invoke `AskQuestion` again with
the supported slugs.

## Launch reviewers

Run each job through the native model-pinned subagent mechanism. Give it the complete prompt and
require it to use the code root as its only code root. Launch jobs concurrently when the mechanism
supports it. Do not invoke `cursor-agent` or `cursor-run-reviewer.mjs` from the desktop GUI.
