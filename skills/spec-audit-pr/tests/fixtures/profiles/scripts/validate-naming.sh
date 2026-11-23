#!/usr/bin/env bash
for path in "$@"; do
  case "$path" in
    *Bad*.md) printf "ERROR: Invalid markdown naming in '%s': use snake_case\n" "$path" >&2 ;;
  esac
done
exit 1
