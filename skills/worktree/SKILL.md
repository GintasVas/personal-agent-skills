---
name: worktree
description: Create an isolated Git worktree from origin/main without switching the current checkout. Use when the user asks for a worktree or an isolated checkout.
argument-hint: '<slug> [--fix|--chore|--feature]'
---

# Worktree

Create a branch from the current repository's `origin/main` and open it in
a separate worktree. Preserve the original checkout and its local edits.

```text
/worktree auth
/worktree auth --fix
/worktree page-layout --chore
```

Use a lowercase kebab-case slug. The default branch prefix is `feature/`.
Use `fix/` or `chore/` when requested. Accept either a positional slug or
`--name <slug>`. If the request names a different base, use the host's Git
worktree tools with that base and verify the resulting branch.

## Create the worktree

Record the original checkout path, branch, and HEAD. Confirm that the new
branch does not exist. If it does, report the conflict and use the existing
worktree only when the user requested it.

- **Codex desktop.** When the managed worktree tool is available, fetch
  `origin main`. Call `mcp__codex_app__create_worktree` once with
  `allowAsync: true`, `name: <slug>`, and `ref: "origin/main"`.
  If it returns an operation ID, wait for the final path with
  `mcp__codex_app__get_worktree_creation_status`. If registration fails
  after creation, attach the existing path with
  `mcp__codex_app__attach_worktree`. Create the requested branch in the
  new worktree with `git switch -c <prefix>/<slug>`.
- **Shell fallback.** Substitute the absolute path to this skill directory
  and run the bundled script from the original repository.

  ```bash
  bash "<this-skill-dir>/scripts/worktree.sh" [--fix|--chore|--feature] <slug>
  ```

  The script fetches `origin main` and prints the new sibling worktree path.
  In Cursor, move the session to that path with `move_agent_to_root` if
  available. Otherwise, set the working directory of subsequent commands
  to the new path.

## Verify and prepare

Check the new worktree path, branch, and HEAD. Check that the original
checkout still has its original branch and HEAD. Prove write access to the
new worktree before making task edits.

If the task requires project setup, read the target repository's onboarding
instructions and use its documented setup command from the new worktree.
Report any setup failure with the path and failed command. Keep the worktree
so the setup can be retried. Continue task work only in the new worktree.
