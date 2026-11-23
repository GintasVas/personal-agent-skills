#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKTREE_SCRIPT="$SKILL_DIR/scripts/worktree.sh"
FIXTURE="$(mktemp -d)"
FIXTURE="$(cd "$FIXTURE" && pwd -P)"
trap 'rm -rf "$FIXTURE"' EXIT

git init --quiet --bare --initial-branch=main "$FIXTURE/origin.git"
git clone --quiet "$FIXTURE/origin.git" "$FIXTURE/project"
cd "$FIXTURE/project"
git config user.name "Test User"
git config user.email "test@example.com"
printf 'base\n' > README.md
git add README.md
git commit --quiet -m "Add base"
git push --quiet origin main
base_head="$(git rev-parse HEAD)"

git switch --quiet -c feature/in-progress
git commit --quiet --allow-empty -m "Work in progress"
original_head="$(git rev-parse HEAD)"
printf 'dirty\n' >> README.md
touch untracked.txt
original_status="$(git status --porcelain)"

worktree="$FIXTURE/project-chore-page-layout"
bash "$WORKTREE_SCRIPT" --chore --name "Page Layout" > "$FIXTURE/output"
grep -Fxq "Worktree: $worktree" "$FIXTURE/output"
test "$(git -C "$worktree" branch --show-current)" = "chore/page-layout"
test "$(git -C "$worktree" rev-parse HEAD)" = "$base_head"
test "$(cat "$worktree/README.md")" = "base"
test "$(git branch --show-current)" = "feature/in-progress"
test "$(git rev-parse HEAD)" = "$original_head"
test "$(git status --porcelain)" = "$original_status"

if bash "$WORKTREE_SCRIPT" --chore page-layout > "$FIXTURE/duplicate" 2>&1; then
  echo "Expected an existing branch to be rejected." >&2
  exit 1
fi
grep -Fq "branch 'chore/page-layout' already exists" "$FIXTURE/duplicate"
test "$(git -C "$worktree" rev-parse HEAD)" = "$base_head"
