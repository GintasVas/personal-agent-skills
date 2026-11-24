# Codex

"Reviewer" is the worker of the skill that sent you here, and "code root" is
the pinned root it names.

## Select model and reasoning effort together

Use the exact model slugs and supported reasoning efforts exposed by the native
subagent tool. Do not invent model slugs with effort suffixes.

On Codex, accept `--reasoning-effort <level>` with `--model`. The effort
applies to every selected model. Validate each combination before preparing
input. If either setting is missing, ask one question for complete
model-and-effort pairs, restricted by any setting the user already supplied.
Show options such as `gpt-6.1-sol / high` and `gpt-6.1-sol / xhigh` only
when those combinations are supported. Use a multi-select question when
available; otherwise ask in chat for comma-separated pairs. Wait for the
answer before inspecting scope, Git, or PR metadata.

Require one explicit effort per selected model. Remove duplicate identical
pairs. If the same model has different efforts, ask which effort to use for
that model, because finding attribution identifies reviewers by model.
For an unavailable model or effort, show the supported choices and ask for a
corrected selection. Never silently default or substitute either setting.

After selection, begin the next message with
`Selected: <exact slug>, reasoning effort: <exact effort>.` for each selected
pair in order. This replaces the skill's model-only confirmation on Codex.

## Launch reviewers

Add `reasoningEffort` to each internal reviewer-job row and include
`Reviewer reasoning effort: <exact effort>` in its prompt context file.
Check both settings against the selection before accepting
results. Keep the exact model slug in `selectedModels` and `modelSlugs`;
report the selected efforts in the review summary.

Use the native model-pinned subagent tool, passing the selected values as
`model` and `reasoning_effort` with `fork_turns: "none"`. Full-history
forks inherit settings and cannot accept these overrides. Supply the full
rendered prompt because the child does not inherit chat history.
Launch one reviewer per selected pair. If the tool cannot pin both settings,
stop and explain the limitation. A prompt requesting deeper thought does not
set reasoning effort.
