---
name: cursor-review
description: >-
  Run the user's usual PR review with Claude Opus 5.5 High: review-pr plus
  simplify-code, post all, then address-comments. Use for "my usual review
  flow" or "review this PR in Cursor".
disable-model-invocation: true
---

# Cursor review

Usage: `/cursor-review <PR URL> [--N]`. Use the current PR when omitted.
`--N` is a positive integer threshold, such as `--10`. Without it, run once.

Prefer Cursor CLI. Find `cursor-agent` on PATH or in `~/.local/bin`; check
`status` and `--list-models`. Use exactly `claude-opus-5-5-high`, never Auto
or a substitute. If signed out, use `NO_OPEN_BROWSER=1 cursor-agent login`
and share its authorization link. CLI login is separate from desktop login.

Read the repo's `review-pr` and `simplify-code` skills and their Cursor CLI
host guidance. Follow their preparation, trust, runner, verification, and
posting steps. Launch their model-pinned CLI workers in Ask mode, in parallel.
The parent handles posting and fixes. Never bypass workspace trust with
`--trust` or permissions with `--force`.

Each round:

1. Push the intended changes. Run `review-pr` and `simplify-code`, both with
   `--model claude-opus-5-5-high`, against the same published PR head.
2. Wait for both to finish. Verify their inputs and use each skill's
   `post all` option.
   Count distinct findings across both results, counting duplicates once.
3. Run `address-comments` in the PR checkout, verify fixes, and push.
4. If `--N` was supplied and this round's combined count is at least N,
   repeat both reviews on the updated head with the same threshold.
   Stop below N or after three rounds total, including the first.

"Just post, no fixing" stops after posting one round, even with `--N`.
If a pass fails or a finding needs a user decision, report the blocker;
do not count an incomplete round as clean. Report each round's count and
remaining findings, including any left at the cap. Merge only if asked,
via `babysit-pr`.

Use the desktop app only when CLI is unavailable or blocked and the app is
usable. Follow `use-computer`, select Claude Opus 5.5 High, and send exactly
`/review-pr <PR URL> --model claude-opus-5-5-high`. Send `/side` in that chat,
then `/simplify-code <PR URL> --model claude-opus-5-5-high` in the side chat.
Reply `Post all` to each result. Apply the same rounds above.
