---
name: council
description: Three subagents score a design, UI, or implementation from different angles. Use for hillclimbing.
disable-model-invocation: true
---

# Council

Spawn three read-only subagents in parallel with this harness's subagent tool,
one per angle:

- **User:** does it feel good to use? Clarity, flow, polish.
- **Craft:** is it well made? Taste, simplicity, fit with the codebase or
  design system.
- **Skeptic:** what feels off or breaks? Weakest part, edge cases, risk.

Give each the goal and the artifact: diff, files, URL, or screenshots for UIs.
Ask for a gut score out of 10 and the top 3 changes that would raise it most.
Vibes over checklists.

Reply with a score table, shared themes, and the one change to make next. On
later rounds, add a column per round so the trend shows.
