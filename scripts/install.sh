#!/usr/bin/env bash
# Symlink every skills/<name> into each harness. Usage: install.sh [--check|--dry-run] [--quiet]
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO/skills"
BACKUP="$HOME/.local/state/personal-agent-skills/backups/$(date +%Y%m%dT%H%M%S)"
MODE=install QUIET=0
for arg in "$@"; do
  case "$arg" in
    --check) MODE=check ;;
    --dry-run) MODE=dry ;;
    --quiet) QUIET=1 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

# ~/.agents/skills: Codex and Cursor. ~/.claude/skills: Claude Code and Cursor.
# The Cursor user store shadows both in Cursor, so it gets a link too.
LINK_DIRS=("$HOME/.agents/skills" "$HOME/.claude/skills")
store="${PERSONAL_SKILLS_CURSOR_STORE:-}"
if [[ -z "$store" ]]; then
  for d in "$HOME/Library/Application Support/Cursor/AgentStores/cursor_agent_stores"/t*-u*/files; do
    [[ -d "$d" ]] && store="$d"
  done
fi
[[ -n "$store" ]] && LINK_DIRS+=("$store/skills")
# Older copies here would duplicate or shadow the repo version.
LEGACY_DIRS=("$HOME/.codex/skills" "$HOME/.cursor/skills")

drift=0
say() { [[ $QUIET == 1 ]] || echo "$@"; }
act() {
  drift=1
  say "$1"
  [[ $MODE == install ]] && eval "$2"
  return 0
}
backup_cmd() { printf 'mkdir -p %q && mv %q %q' "$BACKUP/$2" "$1" "$BACKUP/$2/"; }

for skill in "$SRC"/*/; do
  skill="${skill%/}" name="$(basename "$skill")"
  [[ -f "$skill/SKILL.md" ]] || continue
  for dir in "${LINK_DIRS[@]}"; do
    dest="$dir/$name" label="$(echo "$dir" | tr '/ ' '__')"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$skill" ]]; then continue; fi
    if [[ -L "$dest" ]]; then
      act "relink $dest" "rm $(printf %q "$dest")"
    elif [[ -e "$dest" ]]; then
      act "back up $dest" "$(backup_cmd "$dest" "$label")"
    fi
    act "link $dest -> $skill" "mkdir -p $(printf %q "$dir") && ln -s $(printf %q "$skill") $(printf %q "$dest")"
  done
  for dir in "${LEGACY_DIRS[@]}"; do
    dest="$dir/$name"
    [[ -e "$dest" || -L "$dest" ]] || continue
    act "back up legacy $dest" "$(backup_cmd "$dest" "$(echo "$dir" | tr '/ ' '__')")"
  done
done

# Remove links to skills that were renamed or deleted.
for dir in "${LINK_DIRS[@]}"; do
  for link in "$dir"/*; do
    [[ -L "$link" ]] || continue
    target="$(readlink "$link")"
    [[ "$target" == "$SRC/"* && ! -d "$target" ]] && act "prune $link" "rm $(printf %q "$link")"
  done
done

if [[ "$(git -C "$REPO" config core.hooksPath || true)" != .githooks ]]; then
  act "set core.hooksPath=.githooks" "git -C $(printf %q "$REPO") config core.hooksPath .githooks"
fi

if [[ $MODE == check && $drift == 1 ]]; then exit 1; fi
[[ $drift == 1 ]] || say "all skills linked"
[[ $MODE == install && -d "$BACKUP" ]] && say "backups: $BACKUP"
exit 0
