---
name: babysit-pr
description: >-
  Watch a PR until required checks pass, fix what breaks, then squash-merge.
  Use for "merge when green", "babysit PR", or "merge when checks pass".
disable-model-invocation: true
---

# Babysit PR

Each pass, refresh state; never act on a stale head SHA:
`gh pr view <N> --json state,isDraft,headRefOid,mergeable,mergeStateStatus,reviewDecision`.

Fix blockers in this order, in the PR's own checkout (`git worktree list`):

1. Conflicts: merge `origin/main`, resolve, push. Ask if intents conflict.
2. Unresolved review threads: apply `address-comments`.
3. Failed required check: read `gh run view <run> --job <job> --log-failed`,
   fix the cause, push. Rerun once with `gh run rerun <run> --failed` only for
   infra flakes.
4. `BEHIND`: `gh pr update-branch <N>`.
5. Pending: `gh pr checks <N> --required --watch --interval 30`.

Merge when required checks pass, no threads are open, it is not a draft, and
review is not blocking:
`gh pr merge <N> --squash --match-head-commit <headRefOid>`.
Never use `--auto` or `--admin`. If approval is missing, tell the user.

Confirm with `gh pr view <N> --json state,mergedAt,mergeCommit` and report
the merge commit. For several PRs, merge in the given order and recheck each
after the previous one lands.
