---
name: ux-tldr
description: >-
  Write a plain-language TLDR for UX and QA of what Gintas changed in the app
  UI today, from his merged and open PRs, and copy it to the clipboard as a
  Teams-formatted message. Use when the user asks for a UX TLDR, what changed
  in the app today, what UX or QA should expect, what to share with UX, or a
  UI-wise summary of the day.
disable-model-invocation: true
---

# UX TLDR

Summarize the day's user-visible app changes for UX designers and QA. Product
language, not dev language.

## Gather

Use the session date and local timezone for "today" unless the user names
another day.

1. Pick the repo: the one the user names, else the current checkout's
   (`gh repo view --json nameWithOwner -q .nameWithOwner`). Ask if neither.
2. List PRs:

```bash
gh pr list --repo <owner/repo> --author @me --state all \
  --search "updated:>=YYYY-MM-DD" --limit 100 \
  --json number,title,state,isDraft,createdAt,mergedAt,url
```

3. Keep PRs merged today, plus open PRs created or pushed to today. Drop
   PRs that were only touched today (comments, rebases of old work) unless
   the user asks for them.
4. Pull bodies and files in one call, written to a file you read in parts:

```bash
for n in <numbers>; do echo "=== #$n"; gh pr view "$n" --repo <owner/repo> \
  --json title,state,body,files --jq '.title, .state, .body, (.files|map(.path)|join("\n"))'; done
```

5. Classify each PR. UI-facing means it changes what someone sees or does in
   the web app, Keycloak screens, or emails. Docs, CI, agent skills, test
   tooling, and dependency bumps are not UI-facing.

## Write

Two groups:

- **Live in the app today**: merged today.
- **Still in review, not live yet**: open PRs. Omit this group when the user
  says so.

Each bullet: bold area name, then what a user will notice, with the PR link on
the area name or `#number`. Add the QA risk or what to check when it is not
obvious, for example "Main QA risk: valid events hidden by filtering."

Rules:

- Name the screen and the visible behavior. "Back button now says Back to
  Schedule and returns to that exact page", not "history-based back labels".
- Group related PRs into one bullet (a feature and its follow-up fix).
- Use nested bullets only when one area has several separate changes.
- Leave out non-UI PRs. Add one closing line only when a non-UI change
  raises regression risk, for example a MUI upgrade that warrants a broad
  visual smoke test.
- No greeting, no em dashes, ASCII apostrophes, no internal jargon (component
  names, library names, ticket keys) unless UX already uses the term.

## Deliver

Teams drops markdown styling and links when pasted. Put rich HTML on the
clipboard:

1. Build HTML with `<p><b>...</b></p>` group headings and `<ul><li>` bullets.
   Links as `<a href="<pr-url>">#2547</a>`, with each PR's `url`.
   Escape `&`, `<`, `>` in text.
2. Pipe it to the script in this skill's `scripts/` directory:

```bash
python3 <this-skill-dir>/scripts/copy-teams-html.py <<'HTML'
<html><body>
<p><b>What changed in the app today</b></p>
<ul>
<li><b>Schedule filters</b> (<a href="<pr-url>">#2547</a>): ...</li>
</ul>
</body></html>
HTML
```

3. Reply in chat with the same message in markdown so the user can review it,
   then one line: `Copied. Paste in Teams with Cmd+V.`

If the user asks for exact test steps instead of a TLDR, turn each UI PR's
test plan into concrete steps per screen (URL, action, expected result).
