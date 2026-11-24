# Tracing

> GintasVas modified this file from Microsoft's Playwright CLI skill. See [LICENSE](../LICENSE).

A trace captures actions, DOM snapshots, screenshots, network activity, console
messages, and timing. Start it before the behavior under investigation and stop
it immediately afterward.

```bash
export PLAYWRIGHT_MCP_OUTPUT_DIR=.tmp/playwright-cli/<task>
sh "$PWCLI" -s=<task> open https://example.test
sh "$PWCLI" -s=<task> tracing-start
sh "$PWCLI" -s=<task> click \
  "getByRole('button', { name: 'Save' })"
sh "$PWCLI" -s=<task> tracing-stop
sh "$PWCLI" -s=<task> close
```

Trace output belongs under `.tmp/playwright-cli/<task>/`. It can contain
authentication tokens, request and response bodies, source, and user data.
Never commit or upload an exploratory trace.

Choose the smallest useful artifact:

- Snapshot or screenshot for one state.
- Trace for action-by-action DOM, network, console, and timing diagnosis.
- Video for a human-readable continuous flow.

For final local trace evidence, seeded authentication, or PR capture, use the
repository runner from `capture-local-ui`. Delete the exploratory trace when
the task is complete.
