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
selection is unavailable. Give it the rendered prompt and pinned code root.
Use read-only mode where available and enforce the worker's read-only contract
in the prompt. Save its full final message as the result. Launch concurrently
where supported. Do not invoke Cursor CLI from the desktop GUI.
