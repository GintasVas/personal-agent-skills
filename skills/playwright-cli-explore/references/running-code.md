# Running custom Playwright code

`run-code` executes trusted JavaScript with the current Playwright `page`.
Treat it as arbitrary code execution. Prefer built-in CLI commands, and use
`run-code` only when a workflow needs Playwright APIs the CLI does not expose.

## Syntax

Use an inline function for one short operation:

```bash
bunx @playwright/cli@0.1.18 -s=<task> run-code \
  "async page => await page.title()"
```

Put multi-step code under `.tmp/playwright-cli/<task>/`:

```javascript
async (page) => {
  const saveButton = page.getByRole('button', { name: 'Save' });
  await saveButton.click();
  await page.getByText('Saved').waitFor();
  return page.url();
};
```

```bash
bunx @playwright/cli@0.1.18 -s=<task> run-code \
  --filename=.tmp/playwright-cli/<task>/save-flow.js
```

## Common APIs

- Geolocation: grant `geolocation` on `page.context()`, then call
  `page.context().setGeolocation({ latitude, longitude })`.
- Permissions: call `page.context().grantPermissions([...], { origin })` and
  grant only the permissions required by the scenario.
- Media: call `page.emulateMedia({ colorScheme: 'dark' })`,
  `page.emulateMedia({ reducedMotion: 'reduce' })`, or
  `page.emulateMedia({ media: 'print' })`.
- Waiting: prefer a locator's `waitFor()` or a specific
  `page.waitForFunction()` condition. Use `page.waitForTimeout()` only when a
  deliberate visible pause is part of an exploratory recording.
- Frames: use `page.frameLocator(selector)` for iframe content; inspect
  `page.frames()` only when frame discovery is necessary.
- Downloads: create `page.waitForEvent('download')` before the action, then
  save the result under `.tmp/playwright-cli/<task>/`.
- Clipboard: grant only `clipboard-read` or `clipboard-write` as needed, then
  use `navigator.clipboard` through `page.evaluate()`.
- Page information: use `page.title()`, `page.url()`, `page.content()`,
  `page.viewportSize()`, or a focused `page.evaluate()`.

Return only the small value needed for diagnosis. Wrap expected failures in
`try`/`catch` and return a concise result rather than dumping page content.
Never read secrets, use unapproved credentials, or write outside `.tmp/`.
