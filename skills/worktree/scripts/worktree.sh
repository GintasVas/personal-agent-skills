#!/usr/bin/env bash
set -euo pipefail

# Usage: worktree.sh [--feature|--fix|--chore] [--name <slug>] [<slug>]
# Creates a sibling worktree from origin/main. Does not switch this checkout.

PREFIX="feature"
NAME=""

usage() {
  echo "Usage: $0 [--feature|--fix|--chore] [--name <slug>] [<slug>]" >&2
  echo "Examples:" >&2
  echo "  $0 auth              -> ../<repo>-feature-auth on feature/auth" >&2
  echo "  $0 auth --fix        -> ../<repo>-fix-auth on fix/auth" >&2
  echo "  $0 --name auth --chore -> ../<repo>-chore-auth on chore/auth" >&2
  exit "${1:-1}"
}

fail() {
  echo "ERROR: $1" >&2
  shift
  while [[ $# -gt 0 ]]; do
    echo "FIX: $1" >&2
    shift
  done
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature)
      PREFIX="feature"
      shift
      ;;
    --fix)
      PREFIX="fix"
      shift
      ;;
    --chore)
      PREFIX="chore"
      shift
      ;;
    --name)
      [[ $# -lt 2 ]] && usage
      NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage 0
      ;;
    -*)
      echo "Unknown flag: $1" >&2
      usage
      ;;
    *)
      if [[ -n "$NAME" ]]; then
        echo "ERROR: branch slug specified more than once." >&2
        usage
      fi
      NAME="$1"
      shift
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "ERROR: branch slug is required." >&2
  usage
fi

NAME_KEBAB=$(echo "$NAME" | \
  tr '[:upper:]' '[:lower:]' | \
  tr ' ' '-' | \
  tr '_' '-' | \
  sed 's/[^a-z0-9-]//g' | \
  sed 's/-\+/-/g' | \
  sed 's/^-//; s/-$//')

if [[ -z "$NAME_KEBAB" ]]; then
  fail "branch slug is empty after normalization." \
    "Pass a slug with letters or numbers, for example: auth"
fi

START_ROOT=$(git rev-parse --show-toplevel)
START_HEAD=$(git rev-parse HEAD)
START_BRANCH=$(git branch --show-current)

GIT_COMMON_DIR=$(git rev-parse --path-format=absolute --git-common-dir)
MAIN_CLONE=$(dirname "$GIT_COMMON_DIR")
REPO_NAME=$(basename "$MAIN_CLONE")
PARENT_DIR=$(dirname "$MAIN_CLONE")

NEW_BRANCH="${PREFIX}/${NAME_KEBAB}"
WORKTREE_PATH="${PARENT_DIR}/${REPO_NAME}-${PREFIX}-${NAME_KEBAB}"

if git show-ref --verify --quiet "refs/heads/${NEW_BRANCH}"; then
  fail "branch '${NEW_BRANCH}' already exists." \
    "Pick a new slug or attach that branch with: git worktree add ${WORKTREE_PATH} ${NEW_BRANCH}"
fi

if [[ -e "$WORKTREE_PATH" ]]; then
  fail "path already exists: ${WORKTREE_PATH}" \
    "Remove it or pick a new slug."
fi

echo "Fetching origin/main..."
git fetch --quiet origin main

echo "Adding worktree ${WORKTREE_PATH} on ${NEW_BRANCH} from origin/main..."
git -c core.hooksPath='' worktree add --quiet -b "$NEW_BRANCH" --no-track \
  "$WORKTREE_PATH" origin/main

END_ROOT=$(git rev-parse --show-toplevel)
END_HEAD=$(git rev-parse HEAD)
END_BRANCH=$(git branch --show-current)

if [[ "$END_ROOT" != "$START_ROOT" || "$END_HEAD" != "$START_HEAD" || "$END_BRANCH" != "$START_BRANCH" ]]; then
  fail "current checkout changed while adding the worktree." \
    "Inspect git status in ${START_ROOT} and restore the original branch."
fi

NEW_HEAD=$(git -C "$WORKTREE_PATH" rev-parse --short HEAD)

echo "Done."
echo "Branch: ${NEW_BRANCH}"
echo "Worktree: ${WORKTREE_PATH}"
echo "HEAD: ${NEW_HEAD}"
echo "Current checkout unchanged: ${START_ROOT} (${START_BRANCH})"
