---
name: capture-local-ui
description: Capture final screenshots, traces, or recordings with the target repo's local UI runner.
---

# Capture local UI

Use the repo's documented runner for final evidence. Use
[Playwright CLI exploration](../playwright-cli-explore/SKILL.md) for inspection.
Keep temporary scenarios and media under the repo's ignored output directory,
such as `.tmp/`. Do not commit them.

## Prepare the runtime

Read the repo's local development and capture instructions. Use the documented
browser provisioning. Check service readiness before starting anything. Reuse
a healthy local stack without restarting, rebuilding, or resetting it.
If none is available, use the documented startup and
wait for readiness. For cloud or worktree tasks, use the repo's runtime policy.

Record the runtime URL. Open the exact route under review. Use the runner's
seeded authentication for protected routes. Use only seeded local data.
If the repo has no documented runner or seeded auth for a protected route,
report the missing prerequisite. Do not invent credentials or a login flow.

## Debug and capture

1. Write a temporary scenario with semantic locators. Exercise the real path.
2. Capture a screenshot and local trace. If a wrapper loses quotes in a URL
   with query parameters, invoke the runner directly with the URL in quotes.
3. Inspect the screenshot. Read the trace only when the screenshot is
   insufficient. Correct the cause and repeat. Keep traces local because
   they can contain tokens, requests, and source.
4. Record the successful scenario and take a final screenshot. Use the
   runner's interactive mode for a human walkthrough if supported. Retain
   enough delay to make each action visible.
5. Apply [recording readiness and quality](references/recording-quality.md).
   Report the exact runtime URL and the evidence paths.

## Publish evidence

Attach only a successful PNG or WebM from the local runner. If the runner
writes a manifest, check that it lists the file. Follow the repo's PR template
and documented upload method. If upload fails, ask the user to drag the same
file into the PR body. Do not use a Gist or publish any trace.

When `AMP_ORB=1`, skip the native upload. Use `amp.public_artifact_url` for
the approved PNG or WebM and the video preview. Anyone with the link can
access it until someone runs `amp files delete <url>`. Embed PNGs as images. For video,
publish a preview GIF and link the full WebM. For example:

```bash
ffmpeg -y -t 12 -i recording.webm \
  -an -vf "fps=8,scale=960:-2:flags=lanczos" -loop 0 recording-preview.gif
```

Put each embed in its own unindented block. Check that the media appears in the
PR before deleting the local capture.
