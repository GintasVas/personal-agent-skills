---
name: browser-use
description: >-
  Use the user's signed-in Chrome tabs and desktop apps (Jira, Figma, Teams,
  AWS, Cursor). Use for "use my browser tab", "open in my browser", or a SaaS
  link to read or act on. Not for localhost.
---

# Browser use

Prefer a connected MCP or CLI when it covers the job: Atlassian MCP for Jira,
Figma MCP for nodes (`node-id=1-2` is `1:2`), `gh` for GitHub. Use the browser
when the user names it, or for Figma comments and visual checks.

Desktop control:

- Codex: Computer Use via the Node REPL `js` tool. `cua.getState()` lists
  tabs and apps; `cua.getTab({ url }, { browser })`,
  `cua.createBrowserTab("chrome", url)`, `cua.getApp("Cursor")`. Then
  `getAXState()`, `getScreenshot()`, `click(i)`, `typeText()`, `pressKey()`.
- Claude Code: Claude in Chrome (`/chrome`).
- Cursor: none. Use MCPs; Playwright MCP is signed out.

If nothing works, say what is missing. Do not guess page contents.

Rules:

- Read-only unless the task asks for that exact write. Never press Send in
  chat apps unless told.
- Never enter credentials or approve MFA or consent screens.
- Leave the user's tab in place. Open links in new tabs; close only yours.
- Re-read state before each click. Slice large AX trees.
- For Jira tickets, open every linked Figma frame.
