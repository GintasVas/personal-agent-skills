# Running and debugging Playwright tests

> GintasVas modified this file from Microsoft's Playwright CLI skill. See [LICENSE](../LICENSE).

Use the repository's documented Playwright test command for final tests and
evidence. Do not use an ad hoc command.

For an interactive diagnosis, start the repository test command with the
official Playwright `--debug=cli` option only when that target supports
forwarding the flag. Set `PLAYWRIGHT_HTML_OPEN=never`, run it in the background,
and wait for `Debugging Instructions` and a generated `tw-*` session name.

```bash
PLAYWRIGHT_HTML_OPEN=never <repository-test-command> --debug=cli
```

Attach with the pinned CLI:

```bash
sh "$PWCLI" attach tw-abcdef
```

The test pauses at the start. Step or resume until the likely failure point,
then inspect the snapshot, console, and requests. Each CLI action prints
corresponding Playwright TypeScript; keep only stable semantic locators and
assertions in any requested test fix.

Stop the background test process when diagnosis is complete. Rerun the normal
repository target for final verification and evidence.
