---
name: use-computer
description: >-
  Use the user's computer: desktop apps (Teams, Cursor, Figma, Slack) and
  Chrome tabs (Jira, AWS, localhost). Use for "use my Teams", "open in my
  browser", or any app or link to read or act on. Overrides the Codex in-app
  browser skill.
disable-model-invocation: true
---

# Use computer

Prefer a connected MCP or CLI when it covers the job: Atlassian MCP for Jira,
Figma MCP for nodes (`node-id=1-2` is `1:2`), `gh` for GitHub. Use the app or
browser when the user names it, or for Figma comments and visual checks.

Control by harness:

- Codex: Computer Use via the Node REPL `js` tool. `cua.getState()` lists
  apps and tabs. Apps: `cua.getApp("Microsoft Teams")`, `cua.getApp("Cursor")`.
  Chrome: `cua.getTab({ url }, { browser })`, `cua.createBrowserTab("chrome", url)`.
  Then `getAXState()`, `getScreenshot()`, `click(i)`, `typeText()`, `pressKey()`.
  Always use `"chrome"`, also for localhost. Never use `"iab"` (in-app
  browser) unless the user asks for it.
- Claude Code: Claude in Chrome (`/chrome`) for web apps, including Teams on
  `teams.microsoft.com`. No desktop apps.
- Cursor: no desktop or Chrome control. Use MCPs; Playwright MCP is signed out.

If nothing works, say what is missing. Do not guess screen contents.

Rules:

- Read-only unless the task asks for that exact write. Never press Send in
  chat apps unless told.
- Never enter credentials or approve MFA or consent screens.
- Leave the user's windows and tabs in place. Open links in new tabs; close
  only yours.
- Re-read state before each click. Slice large AX trees.
- For Jira tickets, open every linked Figma frame.
