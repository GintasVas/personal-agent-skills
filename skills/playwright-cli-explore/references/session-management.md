# Browser session management

> GintasVas modified this file from Microsoft's Playwright CLI skill. See [LICENSE](../LICENSE).

Use one semantic named session for the task and pass `-s=<task>` to every
session-scoped command. Global `list`, `close-all`, and `kill-all` omit it.
Each session has independent cookies, local and session storage, IndexedDB,
cache, history, and tabs. Do not mix authenticated and unrelated exploration
in one session.

A headless session closes after one hour of inactivity by default. Run
`open` again if the session expires.

```bash
export PLAYWRIGHT_MCP_OUTPUT_DIR=.tmp/playwright-cli/<task>
sh "$PWCLI" -s=<task> open <url>
sh "$PWCLI" -s=<task> snapshot
sh "$PWCLI" list
sh "$PWCLI" -s=<task> close
```

Use `close-all` only when every listed session belongs to the current task.
Use `kill-all` only for stale or unresponsive CLI browser processes.

```bash
sh "$PWCLI" close-all
sh "$PWCLI" kill-all
```

Browser profiles are in memory by default. If persistence is explicitly
required, keep the profile under `.tmp/`:

```bash
sh "$PWCLI" -s=<task> open <url> \
  --profile=.tmp/playwright-cli/<task>/profile
sh "$PWCLI" -s=<task> delete-data
```

`attach` connects to an existing browser or a `--debug=cli` test session.
Use `detach` for attached sessions so the external browser remains open; use
`close` for sessions created by `open`.

```bash
sh "$PWCLI" -s=<task> attach --cdp=http://localhost:9222
sh "$PWCLI" -s=<task> detach
```

Do not attach to an unrelated browser profile or authenticated session without
explicit approval.
