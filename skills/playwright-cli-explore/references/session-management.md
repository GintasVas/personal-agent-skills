# Browser session management

Use one semantic named session for the task and pass `-s=<task>` to every
session-scoped command. Global `list`, `close-all`, and `kill-all` omit it.
Each session has independent cookies, local and session storage, IndexedDB,
cache, history, and tabs. Do not mix authenticated and unrelated exploration
in one session.

```bash
export PLAYWRIGHT_MCP_OUTPUT_DIR=.tmp/playwright-cli/<task>
bunx @playwright/cli@0.1.18 -s=<task> open <url>
bunx @playwright/cli@0.1.18 -s=<task> snapshot
bunx @playwright/cli@0.1.18 list
bunx @playwright/cli@0.1.18 -s=<task> close
```

Use `close-all` only when every listed session belongs to the current task.
Use `kill-all` only for stale or unresponsive CLI browser processes.

```bash
bunx @playwright/cli@0.1.18 close-all
bunx @playwright/cli@0.1.18 kill-all
```

Browser profiles are in memory by default. If persistence is explicitly
required, keep the profile under `.tmp/`:

```bash
bunx @playwright/cli@0.1.18 -s=<task> open <url> \
  --profile=.tmp/playwright-cli/<task>/profile
bunx @playwright/cli@0.1.18 -s=<task> delete-data
```

`attach` connects to an existing browser or a `--debug=cli` test session.
Use `detach` for attached sessions so the external browser remains open; use
`close` for sessions created by `open`.

```bash
bunx @playwright/cli@0.1.18 -s=<task> attach --cdp=http://localhost:9222
bunx @playwright/cli@0.1.18 -s=<task> detach
```

Do not attach to an unrelated browser profile or authenticated session without
explicit approval.
