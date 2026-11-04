---
name: council
description: Three subagents score any artifact from fixed angles. Use for hillclimbing.
disable-model-invocation: true
---

# Council

Spawn three read-only subagents in parallel with this harness's subagent tool,
one per angle:

- **Outcome:** does it achieve the stated goal for its audience?
- **Craft:** is it simple, clear, and consistent with its surroundings?
- **Skeptic:** where does it fail, mislead, or break?

Give each the same goal, artifact, and this scale. Reuse both unchanged across
rounds.

- 10: nothing to change.
- 8: minor polish only.
- 6: works, with a clear weakness.
- 4: a major problem.
- 2: misses the goal.

Each returns a score, each deduction with its points and cited evidence, and
the top 3 changes ranked by points recovered.

Reply with a score table, deductions two or more members share, and the one
change to make next. On later rounds, add a column per round.
