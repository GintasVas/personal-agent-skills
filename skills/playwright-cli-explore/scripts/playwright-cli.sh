#!/bin/sh

version=0.1.25
if [ "${1-}" = --skill-url ]; then
    printf 'https://github.com/microsoft/playwright-cli/tree/v%s/skills/playwright-cli\n' "$version"
    exit 0
fi
package="@playwright/cli@$version"

if command -v npx >/dev/null 2>&1; then
    exec npx --yes "$package" "$@"
elif command -v pnpm >/dev/null 2>&1; then
    exec pnpm --silent dlx "$package" "$@"
elif command -v bunx >/dev/null 2>&1; then
    exec bunx --package "$package" playwright-cli "$@"
fi

printf '%s\n' 'Playwright CLI requires a package runner on PATH (npx, pnpm, or bunx).' >&2
exit 127
