---
name: cursor-review
description: >-
  Run the user's usual PR review with Claude Opus 5.5 High: review-pr plus
  simplify-code, post all, then address-comments. Use for "my usual review
  flow" or "review this PR in Cursor".
disable-model-invocation: true
---

# Cursor review

In a Cursor agent, with this thread on Claude Opus 5.5 High:

1. Side chat: fork this thread with `Task` (`resume: "self"`,
   `run_in_background: true`, description `Simplify code`). Prompt: run
   `/simplify-code <PR URL> --model claude-opus-5-5-high`, then `post all`.
2. Main thread: run `/review-pr <PR URL> --model claude-opus-5-5-high`, then
   `post all`. Both skills are in the repo's `.agents/skills/` and launch
   their own Opus reviewers.
3. After both have posted, run `address-comments` in the PR's checkout.
4. Merge only if asked, via `babysit-pr`.

"Just post, no fixing" stops after step 2 and the side chat's posting.
Large PRs take 10 to 20 minutes.

From Codex, Cursor reviews and Codex fixes. Drive the Cursor app with
Computer Use (`cua.getApp("Cursor")`, see `use-computer`). Do not use
`cursor-agent -p`; the review skills need interactive workspace trust there.

1. Push local work first so Cursor reviews the published head.
2. Open two Cursor chats, or reuse this PR's `[Reviewing]` chats. Set each
   chat's workspace to the PR's worktree and its model picker to Claude Opus
   5.5 High; the picker can reset to Auto.
3. Send exactly `/review-pr <PR URL> --model claude-opus-5-5-high` in one
   chat and `/simplify-code <PR URL> --model claude-opus-5-5-high` in the
   other. Add nothing else; the skills handle scope, head, and titles.
4. Read each chat's findings and validate them here. Reply in that chat with
   `Post all`, `Post 1,3`, or `Post none` (for example, already fixed here).
5. Run `address-comments` here. Push.
6. Merge only if asked, via `babysit-pr`.

Poll about once a minute with a one-line status.

Done when both passes ran on Opus 5.5 High and every finding is posted, or
the pass reported none.
