---
name: sync-deliverables
description: Reconciles a product slice across Jira, OpenSpec, pull requests, code, tests, API readiness, and Figma references. Use when the user says sync deliverables, reconcile delivery status, check what is shipped or missing, prepare next frontend work, or asks to align Jira and OpenSpec with implementation.
disable-model-invocation: true
---

# Sync deliverables

Build evidence-backed delivery status for one product slice. Read first. Write
only after the user explicitly asks to apply the proposed sync.

## Scope

Use an explicitly supplied Jira issue, PR, OpenSpec change, branch, or product
area. Infer scope from the current branch only when unambiguous. Ask one focused
question when multiple scopes fit.

## Gather

Load the repository task-routing guidance. Then search, in parallel:

1. OpenSpec change artifacts: `proposal.md`, `tasks.md`, delta specs, and
   `source.md`.
2. Canonical OpenSpec domain spec, flows, and relevant backlog entries.
3. Jira parent, subtasks, linked issues, current status, and acceptance criteria.
4. Related open and merged PRs, current branch commits, production code, API
   contracts, generated clients, and tests.
5. Figma reference only when the slice has one.

Use repository-local skills for Jira, OpenSpec, PRs, testing, and Figma. Do not
duplicate their workflows.

## Classify each deliverable

- **Shipped**: implementation and relevant verification exist. Record PR or
  commit evidence.
- **In flight**: scoped work exists but is unmerged, incomplete, or awaiting a
  dependency.
- **Missing**: requirement has no implementation path, test, task, or required
  dependency.
- **Stale tracking**: Jira, OpenSpec markers, PR description, or backlog
  conflicts with evidence.
- **Blocked**: name the concrete owner, dependency, or unresolved product
  decision.

Code alone does not prove shipped. Do not mark work done because an adjacent
feature exists.

## Report

Start with the current delivery state. Then list each mismatch with:

- Deliverable and current owner
- Evidence paths, issue IDs, PRs, or test names
- Classification
- Smallest proposed Jira or OpenSpec edit

State which frontend work is ready now and which work is blocked by API,
contract, Figma, or product decisions.

## Apply sync

Only after explicit confirmation:

1. Re-check live Jira and branch state.
2. Search for duplicates before creating an issue or subtask.
3. Follow the repository Jira workflow for issue type, parent, description,
   links, and assignee.
4. Update task markers only when evidence proves completion.
5. Never rewrite a spec to fit implementation without calling out the mismatch
   and receiving approval.
6. Preserve unrelated Jira and OpenSpec content.

Report every edit with its evidence and link.
