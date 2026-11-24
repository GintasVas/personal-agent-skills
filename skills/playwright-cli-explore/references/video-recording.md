# Video recording

> GintasVas modified this file from Microsoft's Playwright CLI skill. See [LICENSE](../LICENSE).

Exploratory recording produces WebM video. Keep it under `.tmp/`; use
`capture-local-ui` and the repository runner for a final recording or PR
evidence. Video recording requires Playwright's FFmpeg binary. If it is
missing, follow the project's provisioning instructions before recording.

```bash
export PLAYWRIGHT_MCP_OUTPUT_DIR=.tmp/playwright-cli/<task>
sh "$PWCLI" -s=<task> open https://example.test
sh "$PWCLI" -s=<task> video-start "$PLAYWRIGHT_MCP_OUTPUT_DIR/flow.webm"
sh "$PWCLI" -s=<task> video-chapter "Starting flow" \
  --description="Opening the target state" --duration=1500
sh "$PWCLI" -s=<task> video-show-actions \
  --duration=600 --position=top-right
sh "$PWCLI" -s=<task> click \
  "getByRole('button', { name: 'Continue' })"
sh "$PWCLI" -s=<task> video-hide-actions
sh "$PWCLI" -s=<task> video-stop
sh "$PWCLI" -s=<task> close
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
