# Cursor desktop GUI

"Reviewer" is the worker of the skill that sent you here, and "code root" is the pinned root it
names.

## Model selection

Use the exact slugs available to the native model-pinned subagent mechanism. When no `--model` is
given, invoke `AskQuestion` with the exact available slugs and wait for the answer before preparing
input. If a selected slug is unavailable to the native subagent, invoke `AskQuestion` again with
the supported slugs.

## Launch reviewers

Use native read-only delegation with the exact model and pinned code root.
Pass the complete numbered prompt, or its absolute path if the worker can read
it. Save the complete final message as the numbered result. Launch concurrently
when supported. Use the desktop subagent for all launches.
