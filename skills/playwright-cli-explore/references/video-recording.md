# Video recording

Exploratory recording produces WebM video. Keep it under `.tmp/`; use
`capture-local-ui` and the repository runner for a final recording or PR
evidence.

```bash
export PLAYWRIGHT_MCP_OUTPUT_DIR=.tmp/playwright-cli/<task>
bunx @playwright/cli@0.1.18 -s=<task> open https://example.test
bunx @playwright/cli@0.1.18 -s=<task> video-start flow.webm
bunx @playwright/cli@0.1.18 -s=<task> video-chapter "Starting flow" \
  --description="Opening the target state" --duration=1500
bunx @playwright/cli@0.1.18 -s=<task> video-show-actions \
  --duration=600 --position=top-right
bunx @playwright/cli@0.1.18 -s=<task> click \
  "getByRole('button', { name: 'Continue' })"
bunx @playwright/cli@0.1.18 -s=<task> video-hide-actions
bunx @playwright/cli@0.1.18 -s=<task> video-stop
bunx @playwright/cli@0.1.18 -s=<task> close
```

Before `video-start`, wait for a route-specific visible control or heading and
any loading state to finish. Start on the loaded page and call `video-stop`
before closing the tab or session. Context-level `recordVideo` starts with a
new page and includes its initial blank and loading frames; use the CLI's
explicit start and stop commands for exploratory clips.

Play the clip or inspect frames from its opening, actions, and ending before
sharing it. If it contains blank frames, separate initial setup from the
recorded flow and check readiness after navigation. Use `capture-local-ui` for
final PR evidence.

Use descriptive chapter titles and show action callouts only when they help a
reviewer follow the flow. For a polished exploratory sequence, put trusted
Playwright code in `.tmp/playwright-cli/<task>/` and execute it with
`run-code --filename`; use semantic locators and only deliberate short pauses.

Video is larger than a trace or screenshot and hides DOM and network details.
Record only the relevant path, avoid sensitive data, and delete the file after
use. Never commit exploratory media.
