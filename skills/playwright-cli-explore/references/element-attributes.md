# Inspecting element attributes

Snapshots expose accessible structure, not every DOM attribute. Use `eval` for
an `id`, class, `data-*` value, ARIA attribute, or computed style that is not
visible. Prefer a semantic locator; use a snapshot ref only within the current
exploratory loop.

```bash
bunx @playwright/cli@0.1.18 -s=<task> eval \
  "element => element.getAttribute('data-testid')" \
  "getByRole('button', { name: 'Save' })"

bunx @playwright/cli@0.1.18 -s=<task> eval \
  "element => element.getAttribute('aria-label')" \
  "getByRole('button', { name: 'Save' })"

bunx @playwright/cli@0.1.18 -s=<task> eval \
  "element => getComputedStyle(element).display" \
  "getByRole('button', { name: 'Save' })"
```

For a small machine-readable value, place `--raw` before the command:

```bash
bunx @playwright/cli@0.1.18 -s=<task> --raw eval \
  "element => element.id" \
  "getByRole('button', { name: 'Save' })"
```

Keep evaluation read-only unless the task explicitly requires page mutation.
Do not extract secrets, tokens, or unrelated user data.
