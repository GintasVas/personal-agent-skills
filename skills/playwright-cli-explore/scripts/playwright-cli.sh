#!/bin/sh

package=@playwright/cli@0.1.25

if command -v npx >/dev/null 2>&1; then
    exec npx --yes "$package" "$@"
elif command -v pnpm >/dev/null 2>&1; then
    exec pnpm --silent dlx "$package" "$@"
elif command -v bunx >/dev/null 2>&1; then
    exec bunx --package "$package" playwright-cli "$@"
fi

printf '%s\n' 'Playwright CLI requires a package runner on PATH (npx, pnpm, or bunx).' >&2
exit 127
