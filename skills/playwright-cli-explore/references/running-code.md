# Running custom Playwright code

> GintasVas modified this file from Microsoft's Playwright CLI skill. See [LICENSE](../LICENSE).

`run-code` runs trusted JavaScript with the current Playwright `page`.
The runtime isolates the code from Node.js modules, `require`, and `process`.
Use `run-code` only for Playwright APIs that built-in commands cannot access.

## Syntax

Use an inline function for one short operation:

```bash
sh "$PWCLI" -s=<task> run-code \
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
sh "$PWCLI" -s=<task> run-code \
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
