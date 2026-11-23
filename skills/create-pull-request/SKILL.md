---
name: create-pull-request
description: Open a GitHub PR with the target repo's template, verification results, and evidence.
---

# Create a pull request

## Prepare

Review the aggregate diff against the base branch. Read individual commits as
needed. Keep unrelated edits out of the PR. Read the repo's PR template and
contribution rules. Run `gh label list` before selecting labels.

Use the repo's title convention. If it uses semantic titles, use
`<type>(<scope>): <description>` plus any required issue or work item ID.
Use each real ID once. If a work tracker requires an ID in the branch, title,
and body, use its exact ID and follow its documented scope and dependencies.

## Write the body

Fill every template section. Pass the filled template with `--body-file`.
If the repo has no template, include Summary, Technical details, and Test plan.

- **Summary.** Use one to three short, active bullets. State the change and its
  effect on users or the system. Link the issue or spec when available.
  Put implementation details below the summary.
- **Technical details.** Include relevant tradeoffs and migration notes.
  If the repo requires model attribution, give the exact IDs of models that
  wrote or changed code. Exclude reviewers. If an ID is missing, ask the
  author and wait for it before creating the PR.
  Use `Code model: N/A` only when no model changed code.
- **Test plan.** Name each test. Mark it `[x]` only after it runs.
  Use `[ ]` for pending tests.
- **Merge risk.** If the template asks, state the blast radius and whether
  reversal is cheap. For an expensive reversal, explain why and what can break.
- **Frontend evidence.** If the template requires it, follow
  [capture-local-ui](../capture-local-ui/SKILL.md) before creating the PR.
  Use the template's localhost route and port when specified.

## Publish

Use the repo's label rules. If it has none, prefer an existing label that
matches the change, such as `bug`, `enhancement`, `specs`, `documentation`,
`config`, or `chore`. Skip labels if none fits.
Do not create labels or use status or triage labels for classification.

Push the branch with an upstream. Use `gh pr create` with the intended base,
head, title, body file, and labels. If the repo assigns PRs to their creator,
pass `--assignee @me`. To set labels or the assignee on an existing PR, use
`gh pr edit`.

After creating the PR or editing its body, read it with `gh pr view`. Verify
the base, head, body, labels, and assignee. If the template sets a localhost
port, verify every localhost URL. Correct any mismatch and return the PR URL.
