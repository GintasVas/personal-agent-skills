# Other hosts

"Reviewer" is the worker of the skill that sent you here, and "code root" is the pinned root it
names.

## Model selection

When no `--model` argument is present, ask which reviewer models to use before preparing review input.
Use the host's model picker with one option per exact available model slug and allow multiple
selections when available. Otherwise, ask in chat for comma-separated exact slugs. Wait for the
answer before reading files, inspecting Git, fetching PR metadata, or validating the scope.

## Launch reviewers

Use the host's reviewer or subagent mechanism only when it can target the exact model, and give it
the complete prompt with the code root as its only code root. Without model-pinned delegation,
stop rather than claim a reviewer ran with a model the host cannot select.
