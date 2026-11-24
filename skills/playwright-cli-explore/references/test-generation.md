# Test generation

> GintasVas modified this file from Microsoft's Playwright CLI skill. See [LICENSE](../LICENSE).

Use a plan, generate, and heal loop. CLI actions print equivalent Playwright
TypeScript, but the printed code is a draft: replace transient snapshot refs
with semantic locators and add explicit assertions.

## Explore

```bash
export PLAYWRIGHT_MCP_OUTPUT_DIR=.tmp/playwright-cli/<task>
sh "$PWCLI" -s=<task> open https://example.test
sh "$PWCLI" -s=<task> snapshot --depth=4
sh "$PWCLI" -s=<task> find "Submit"
sh "$PWCLI" -s=<task> --raw generate-locator e5
```

The locator priority is role and accessible name, label, visible text, and then
test id when the product intentionally provides one. CSS selectors and snapshot
refs are last-resort exploratory targets.

Use focused reads to learn assertion values:

```bash
sh "$PWCLI" -s=<task> --raw eval \
  "element => element.textContent" \
  "getByRole('status')"
sh "$PWCLI" -s=<task> --raw snapshot \
  "getByRole('main')"
```

## Plan

Before generating tests:

1. Confirm the repository's Playwright workspace, target, and seed test.
2. Run the repository test target in `--debug=cli` mode only if it supports
   forwarding that option.
3. Explore the real flow and record a temporary plan under
   `.tmp/playwright-cli/<task>/`.
4. Describe application context, grouped scenarios, expected results, and the
   minimum setup each scenario requires.

Do not create a test file unless the user requested test changes.

## Generate

Generate one scenario at a time. Follow the planned path with CLI actions and
copy the printed TypeScript into the requested test only after replacing refs
with stable locators. Add assertions manually; an interaction sequence without
an observable expectation is not a test.

Run the narrow repository test target after each scenario, then the applicable
full target. The repository runner, not the exploratory CLI session, owns final
test evidence.

## Heal

1. Reproduce one failing scenario with the normal repository target.
2. Start that scenario in `--debug=cli` mode and attach to its generated `tw-*`
   session.
3. Inspect the current snapshot, console, and requests.
4. Decide whether the defect is in the application, locator, setup, or
   assertion. Make the smallest requested fix.
5. Rerun the narrow scenario, then the applicable full target.

Do not weaken assertions merely to make a failure pass. If repeated attempts
do not reveal a stable product behavior, stop and report the unresolved
ambiguity.
