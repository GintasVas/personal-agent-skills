---
name: cursor-review
description: >-
  Run the user's usual PR review in the Cursor app with Claude Opus 5.5 High,
  /review-pr plus /simplify-code, post all, then address-comments. Use for "my
  usual reviews flow" or "open Cursor and review this PR".
---

# Cursor review

The flow, done in the Cursor app:

1. New agent thread in the project repo, model Claude Opus 5.5 High.
   Send `/review-pr <PR URL> --model claude-opus-5-5-high`.
2. Open a side chat, model Opus 5.5 High.
   Send `/simplify-code <PR URL> --model claude-opus-5-5-high`.
3. Queue `post all` in both chats. If a model form appears, pick Opus 5.5 High.
4. When both have posted, run `address-comments` in the PR's checkout.
5. Merge only if asked, via `babysit-pr`.

"Just post, no fixing" stops after step 3.

From Codex, drive Cursor with Computer Use (`cua.getApp("Cursor")`, see
`browser-use`). Confirm the model label in each chat before sending. Poll
about once a minute with a one-line status. Large PRs take 10 to 20 minutes.

Without desktop control (Cursor's own agent, plain Claude Code), print the
commands from steps 1 to 3 for the user to paste and stop.

Done when both passes ran on Opus 5.5 High and every finding is posted, or
the pass reported none.
