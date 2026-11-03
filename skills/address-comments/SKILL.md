---
name: address-comments
description: Addresses open pull-request comments when invoked.
disable-model-invocation: true
---

Address PR's open comments in the same checkout if valid. Respond and resolve all after pushing.

Use `gh` only, never a GitHub connector or MCP:

- Threads: `gh api graphql` on `pullRequest.reviewThreads`
  (`id isResolved path line comments{databaseId body author{login}}`).
- Reply: `gh api repos/{owner}/{repo}/pulls/<N>/comments/<databaseId>/replies -f body=...`.
- Resolve: `gh api graphql` mutation `resolveReviewThread(input:{threadId})`.
