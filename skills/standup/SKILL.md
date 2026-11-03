---
name: standup
description: >-
  Compose a brief yesterday/today standup as a Microsoft Teams chat message
  from git, PRs, worktrees, and other agents' work. Use when the user asks
  for a standup, standup message, Teams standup, or daily status.
---

# Standup

Compose Gintas's standup. Brief. Product-facing. No greeting.

## Ask first (hard stop)

On the first turn of a standup request, do **only** this. Do not gather. Do not
run `gh`, `git`, SearchConversations, transcript reads, or any other tools.
Do not compose output. End the turn after asking.

Call `AskQuestion` (tool name exactly `AskQuestion`) with:

```json
{
  "title": "Blockers",
  "questions": [
    {
      "id": "blockers",
      "prompt": "Any blockers?",
      "options": [{ "id": "none", "label": "None" }],
      "allow_multiple": false
    }
  ]
}
```

`None` is the default choice. Do not invent other options. The host may add
`Other` for free text.

If `AskQuestion` is not in this session's tool list, ask in chat: **Any
blockers?** Still do not gather until they reply.

After they answer, put the reply on the Blockers line (`none` if they pick
`None` or say none). Do not invent blockers. Then gather and compose.

## Output

Teams does not turn pasted markdown into links. Put **rich HTML** on the
clipboard so Cmd+V in Teams keeps `#910` as the clickable link.

1. Compose the three sections.
2. Wrap PR numbers as `<a href="<pr-url>">#910</a>`.
   Escape `&`, `<`, `>` in the rest of the text.
3. Pipe this HTML to the copy script (path relative to this skill):

```bash
python3 <this-skill-dir>/scripts/copy-teams-html.py <<'HTML'
<html><body>
<p><b>Yesterday:</b> ... <a href="<pr-url>">#910</a>...</p>
<p><b>Today:</b> ...</p>
<p><b>Blockers:</b> ...</p>
</body></html>
HTML
```

4. Chat reply is only:

```
Copied. Paste in Teams with Cmd+V.
```

Do not print the standup body in chat. Copying from the agent chat strips the links.

A paste like `prev: … next: … blockers: none` is **format only**. Never copy
someone else's content.

## Gather (do not skip)

Only after blockers are answered. Use `today` from the session date. Yesterday
is the prior calendar day.

1. **Shipped:** `gh pr list --author @me --state merged` for yesterday and
   today. Also `git log --author` for the same windows.
2. **In progress:** current branch + dirty files; `git worktree list`; other
   checkouts' `git status` / `git log origin/main..HEAD`.
3. **Other agents:** SearchConversations and recent agent transcripts. Work
   on another agent's branch still counts as the user's work.

Open PRs belong in **today** if they were created or actively updated today.
Merged yesterday stays in **yesterday**, even if the work started earlier.
Merged today goes in **today**, not yesterday.

Mark in-progress with no PR as `(no PR yet)`. Do not hide it in a "next"
bucket. Do not fold unshipped work into yesterday.

## What to include

Worth sharing: product/UI work, bugfixes, specs tied to shipped PRs,
substantial in-progress (shared components, design-system work).

Skip unless it *is* the day's work: personal agent rules, agent skills,
unslop, Jira housekeeping, test-loop speedups, worktree plumbing.

If several items compete, keep the 2–4 a teammate would care about.

## Wording

- Name the actual change. Not "landed special-hours" when the PR was "one-off
  class validation during special hours."
- PR links live on the number only: `#919` is the `<a>` text.
- One or two sentences per section. No bullets unless the day was huge.
- No "Hi", no "prev/next", no "tomorrow".
- ASCII apostrophes only.
- Attribute only this user's work. Do not credit other authors' PRs.
