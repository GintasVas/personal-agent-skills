---
name: spin-up-web
description: >-
  Start a web container for the current project worktree against the main
  checkout's Docker stack. Use for "spin up web", "web against main stack", or
  a local UI to test or capture from a worktree.
disable-model-invocation: true
---

# Spin up web

Run from a project worktree, never the main checkout.

1. Reuse this worktree's container if it runs:
   `docker ps -a --filter "label=com.example.local-dev.web-only.root=$PWD" --format '{{.Names}} {{.Status}} {{.Ports}}'`.
   Remove it with `docker rm -f -v <name>` if it exited.
2. No `node_modules`: `bun run local:prepare-worktree`.
3. `bun run local:web:against-main`. Missing `bun`: prepend
   `export PATH="/opt/homebrew/bin:$HOME/.bun/bin:$PATH";`.
4. Report the URL, the seeded admin login, and the cleanup
   command it prints.

Rules:

- Never start another backend stack (`local:up`, `docker compose up`) or touch
  main-stack services. If the script says the main stack is down, relay its
  `FIX` line and wait for the user.
- UI only. Say so if the change touches `apps/mms` or `apps/bff`.
- If the user wants to test, stop after step 4. No checks until asked.
- Capture evidence with `bun run local:capture -- --url <url> ...`.
- Remove containers you started for your own verification when done.
