---
name: cursor-review
description: >-
  Run the user's usual PR review with Claude Opus 5.5 High: review-pr plus
  simplify-code, post all, then address-comments. Use for "my usual review
  flow" or "review this PR in Cursor".
disable-model-invocation: true
---

# Cursor review

In a Cursor agent, run the whole flow yourself in this thread:

1. Read `review-pr` and `simplify-code` from the repo's `.agents/skills/`. Run
   both on the PR with `--model claude-opus-5-5-high`, following their Cursor
   desktop host branch. Launch both skills' reviewer subagents in one
   parallel batch. Do not wrap the skills in subagents.
2. Treat both "post" prompts as answered `post all`. Post each skill's
   findings when its reviewers finish.
3. Run `address-comments` in the PR's checkout.
4. Merge only if asked, via `babysit-pr`.

"Just post, no fixing" stops after step 2. Large PRs take 10 to 20 minutes.

From Codex, open a new Cursor agent thread in the project repo with Computer Use
(`cua.getApp("Cursor")`, see `browser-use`), pick Claude Opus 5.5 High, and
send `/cursor-review <PR URL>`. Do not use `cursor-agent -p`; the review
skills need interactive workspace trust there.

Done when both passes ran on Opus 5.5 High and every finding is posted, or
the pass reported none.
