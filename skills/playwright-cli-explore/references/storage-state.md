# Storage state

> GintasVas modified this file from Microsoft's Playwright CLI skill. See [LICENSE](../LICENSE).

Storage state can contain authentication cookies and application data. Keep it
only under `.tmp/playwright-cli/<task>/`, never commit it, and delete it when
the task ends. Do not invent credentials or create authentication state by
guessing a login flow. Use `capture-local-ui` for seeded local authentication.

## Save and load

```bash
sh "$PWCLI" -s=<task> state-save \
  .tmp/playwright-cli/<task>/state.json

sh "$PWCLI" -s=<task> state-load \
  .tmp/playwright-cli/<task>/approved-state.json
sh "$PWCLI" -s=<task> reload
```

The state file contains cookies and origin-scoped browser storage. Treat its
contents as sensitive even when the current flow appears anonymous.

## Cookies

```bash
sh "$PWCLI" -s=<task> cookie-list
sh "$PWCLI" -s=<task> cookie-list --domain=example.test
sh "$PWCLI" -s=<task> cookie-get preference
sh "$PWCLI" -s=<task> cookie-set preference compact \
  --domain=example.test --path=/ --secure --sameSite=Lax
sh "$PWCLI" -s=<task> cookie-delete preference
sh "$PWCLI" -s=<task> cookie-clear
```

Cookie options include domain, path, expiry, `httpOnly`, `secure`, and
`sameSite`. Use only values approved for the scenario.

## Local and session storage

```bash
sh "$PWCLI" -s=<task> localstorage-list
sh "$PWCLI" -s=<task> localstorage-get theme
sh "$PWCLI" -s=<task> localstorage-set theme dark
sh "$PWCLI" -s=<task> localstorage-delete theme
sh "$PWCLI" -s=<task> localstorage-clear

sh "$PWCLI" -s=<task> sessionstorage-list
sh "$PWCLI" -s=<task> sessionstorage-get step
sh "$PWCLI" -s=<task> sessionstorage-set step 3
sh "$PWCLI" -s=<task> sessionstorage-delete step
sh "$PWCLI" -s=<task> sessionstorage-clear
```

For multiple operations or IndexedDB inspection, use a trusted `run-code`
script from `.tmp/`. Scope it to the current origin and return only the names
or values needed for diagnosis.
