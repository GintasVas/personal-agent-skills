# Request mocking

Routes can block, fulfill, or modify requests within the named browser session.
Use the narrowest URL pattern that covers the scenario.

```bash
# Return an error for images.
bunx @playwright/cli@0.1.18 -s=<task> route "**/*.jpg" --status=404

# Fulfill an API response.
bunx @playwright/cli@0.1.18 -s=<task> route "**/api/users" \
  --body='[{"id":1,"name":"Example"}]' \
  --content-type=application/json

# Add a response header or remove sensitive request headers.
bunx @playwright/cli@0.1.18 -s=<task> route "**/api/status" \
  --body='{"ok":true}' --header="X-Scenario: unavailable"
bunx @playwright/cli@0.1.18 -s=<task> route "**/*" \
  --remove-header=cookie,authorization

# Inspect and remove routes.
bunx @playwright/cli@0.1.18 -s=<task> route-list
bunx @playwright/cli@0.1.18 -s=<task> unroute "**/*.jpg"
bunx @playwright/cli@0.1.18 -s=<task> unroute
```

Patterns use Playwright glob matching:

```text
**/api/users
**/api/*/details
**/*.{png,jpg,jpeg}
**/search?q=*
```

For conditional responses, request-body inspection, response modification,
delays, or failures, put trusted Playwright code under
`.tmp/playwright-cli/<task>/` and run it:

```javascript
async (page) => {
  await page.route('**/api/status', async (route) => {
    const response = await route.fetch();
    const json = await response.json();
    await route.fulfill({ response, json: { ...json, available: false } });
  });
};
```

```bash
bunx @playwright/cli@0.1.18 -s=<task> run-code \
  --filename=.tmp/playwright-cli/<task>/mock-status.js
```

Use `route.abort('timedout')` or another documented Playwright abort code to
simulate network failure. Remove all routes after the scenario so a later step
cannot inherit hidden mocks.
