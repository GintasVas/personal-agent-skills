# Storage state

Storage state can contain authentication cookies and application data. Keep it
only under `.tmp/playwright-cli/<task>/`, never commit it, and delete it when
the task ends. Do not invent credentials or create authentication state by
guessing a login flow. Use `capture-local-ui` for seeded local authentication.

## Save and load

```bash
bunx @playwright/cli@0.1.18 -s=<task> state-save \
  .tmp/playwright-cli/<task>/state.json

bunx @playwright/cli@0.1.18 -s=<task> state-load \
  .tmp/playwright-cli/<task>/approved-state.json
bunx @playwright/cli@0.1.18 -s=<task> reload
```

The state file contains cookies and origin-scoped browser storage. Treat its
contents as sensitive even when the current flow appears anonymous.

## Cookies

```bash
bunx @playwright/cli@0.1.18 -s=<task> cookie-list
bunx @playwright/cli@0.1.18 -s=<task> cookie-list --domain=example.test
bunx @playwright/cli@0.1.18 -s=<task> cookie-get preference
bunx @playwright/cli@0.1.18 -s=<task> cookie-set preference compact \
  --domain=example.test --path=/ --secure --sameSite=Lax
bunx @playwright/cli@0.1.18 -s=<task> cookie-delete preference
bunx @playwright/cli@0.1.18 -s=<task> cookie-clear
```

Cookie options include domain, path, expiry, `httpOnly`, `secure`, and
`sameSite`. Use only values approved for the scenario.

## Local and session storage

```bash
bunx @playwright/cli@0.1.18 -s=<task> localstorage-list
bunx @playwright/cli@0.1.18 -s=<task> localstorage-get theme
bunx @playwright/cli@0.1.18 -s=<task> localstorage-set theme dark
bunx @playwright/cli@0.1.18 -s=<task> localstorage-delete theme
bunx @playwright/cli@0.1.18 -s=<task> localstorage-clear

bunx @playwright/cli@0.1.18 -s=<task> sessionstorage-list
bunx @playwright/cli@0.1.18 -s=<task> sessionstorage-get step
bunx @playwright/cli@0.1.18 -s=<task> sessionstorage-set step 3
bunx @playwright/cli@0.1.18 -s=<task> sessionstorage-delete step
bunx @playwright/cli@0.1.18 -s=<task> sessionstorage-clear
```

For multiple operations or IndexedDB inspection, use a trusted `run-code`
script from `.tmp/`. Scope it to the current origin and return only the names
or values needed for diagnosis.
