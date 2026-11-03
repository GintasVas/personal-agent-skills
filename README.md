# Personal agent skills

Source of truth for Gintautas's personal skills in Cursor, Codex, and Claude Code.

```bash
scripts/install.sh            # link skills/* into every harness
scripts/install.sh --dry-run  # show what would change
scripts/install.sh --check    # exit 1 on drift
```

Each skill is symlinked into `~/.agents/skills` (Codex, Cursor), `~/.claude/skills`
(Claude Code), and the Cursor user store. Copies of the same name in
`~/.codex/skills` and `~/.cursor/skills` move to
`~/.local/state/personal-agent-skills/backups/`. Edits apply at once through the
links. The `post-merge` hook reruns the installer after `git pull`, so new or
deleted skills link and unlink on their own.

To add a skill, create `skills/<name>/SKILL.md` and run `scripts/install.sh`.
Keep skills harness-neutral; reference bundled files as `<this-skill-dir>/...`.
