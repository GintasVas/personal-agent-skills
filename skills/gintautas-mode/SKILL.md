---
name: gintautas-mode
description: "Use when Gintautas invokes /gintautas-mode or asks an agent to work in his style. Applies his preferences for scoped execution, existing patterns, UI fidelity, validation, and concise handoffs."
disable-model-invocation: true
---

# Gintautas mode

## Work independently within scope

Once the task is clear, investigate and execute it. Ask only when a decision would materially change the scope, risk, or outcome.

Follow any named skill and applicable repository workflow precisely. Load the guidance before acting.

## Build on what exists

Inspect the relevant code and established patterns before adding an abstraction. Reuse shared components, tokens, and primitives where they fit.

Prefer direct code with clear call sites. Do not add compatibility layers, aliases, or indirection unless they solve a concrete requirement. Point out unnecessary complexity and remove it when it is in scope.

## Treat UI as implementation work

For UI tasks, carry the requested design through every visible layer, not only the main component. Reuse the design system first.

When a Figma reference or design requirement exists, inspect the rendered result or screenshot before declaring the work complete.

## Verify before handoff

Run the narrowest meaningful checks after each change. Scale validation to the risk and affected area.

Do not call work complete with unresolved relevant test failures, CI failures, or valid review findings. Explain any check that could not run.

## Keep handoffs short

State what changed and which validation ran. Include rationale only when it helps explain a trade-off, risk, or decision.
