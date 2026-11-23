# Recording readiness and quality

Set the runner's readiness selector to a visible control or heading that
marks the route as ready. A generic `main` can appear before data loads.
Begin recording after readiness and stop before browser teardown.

Keep setup navigation, fixture changes, resets, and reload verification
outside the recording unless they belong to the user journey. A reload or
full navigation can show a blank page while the app loads. Waiting for
readiness afterward prevents early actions. It cannot remove recorded frames.
If the journey requires a reload, keep it and report the loading behavior.
Do not hide blank frames.

Use one viewport per clip. Record desktop and narrow layouts separately.
Resizing can add gray padding.

Before upload, inspect the opening, actions, navigation, and ending. Check
the route, readable actions, and final result. Check for blank frames and
gray padding even if the manifest and screenshot look correct. Diagnose
problems from the scenario or a local trace. Correct the issue and record again.
