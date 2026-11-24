#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SKILL_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
ORCHESTRATOR="${SKILL_DIR}/SKILL.md"
WORKER="${SKILL_DIR}/agents/code-simplifier.md"
LOCAL_PREPARE="${SKILL_DIR}/scripts/prepare-local-simplify-input.mjs"
BUILD="${SKILL_DIR}/scripts/build-review-bundles.mjs"
VERIFY="${SKILL_DIR}/scripts/verify-review-bundles.mjs"
CLEANUP="${SKILL_DIR}/scripts/cleanup-review-input.mjs"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

test -f "$ORCHESTRATOR"
test -f "$WORKER"
test -f "$LOCAL_PREPARE"
test -f "$BUILD"
test -f "$VERIFY"
test -f "$CLEANUP"
test ! -f "${SKILL_DIR}/../code-simplifier/SKILL.md"

grep -Fq 'name: simplify-code' "$ORCHESTRATOR"
grep -Fq 'disable-model-invocation: true' "$ORCHESTRATOR"
grep -Fq '/simplify-code' "$ORCHESTRATOR"
grep -Fq 'mixed responsibilities, extension seams, duplication, and inconsistent patterns' "$ORCHESTRATOR"
grep -Fq '<this-skill-dir>/agents/code-simplifier.md' "$ORCHESTRATOR"
grep -Fq 'Repeat `--model` for multiple workers.' "$ORCHESTRATOR"
grep -Fq 'Run the bundled scripts at the steps below.' "$ORCHESTRATOR"
grep -Fq 'Do not inspect script source.' "$ORCHESTRATOR"
grep -Fq 'detached head worktree' "$ORCHESTRATOR"
grep -Fq 'For bundled PRs, pass `review-index.json` and `source`.' "$ORCHESTRATOR"
grep -Fq '`patch.diff`, `line-map.json`, `manifest.json`, and `source`.' "$ORCHESTRATOR"
grep -Fq 'The parent does not read the global line map.' "$ORCHESTRATOR"
grep -Fq '## Scope large reviews' "$ORCHESTRATOR"
grep -Fq 'For a review with more than 10 changed files or 500 changed lines' "$ORCHESTRATOR"
grep -Fq 'bundles instead of the full patch.' "$ORCHESTRATOR"
grep -Fq 'reviewable hunk.' "$ORCHESTRATOR"
grep -Fq 'new shared module with only the changed importers' "$ORCHESTRATOR"
grep -Fq 'use bounded' "$ORCHESTRATOR"
grep -Fq 'build-review-bundles.mjs' "$ORCHESTRATOR"
grep -Fq 'Give all verified bundles to every model.' "$ORCHESTRATOR"
grep -Fq 'Synthesize without discovering new findings.' "$ORCHESTRATOR"
grep -Fq "Use the canonical finding's original wording and heading." "$ORCHESTRATOR"
grep -Fq '"selectedModels": ["<exact slug>", "<exact slug>"]' "$ORCHESTRATOR"
grep -Fq '"modelSlugs": ["<exact slug>"]' "$ORCHESTRATOR"
grep -Fq 'the `Found by` footer from `body`.' "$ORCHESTRATOR"
grep -Fq '<this-skill-dir>/agents/code-simplifier.md' "$ORCHESTRATOR"
grep -Fq 'Put its contract and' "$ORCHESTRATOR"
grep -Fq 'Copy all sections of [simplification-lenses.md]' "$ORCHESTRATOR"
grep -Fq 'Pass the prompt directly without' "$ORCHESTRATOR"
grep -Fq '/skill:simplify-code' "$ORCHESTRATOR"
grep -Fq 'Before any other tool call, read only the host file' "$ORCHESTRATOR"
for host in pi cursor-desktop cursor-cli codex other; do
  test -f "${SKILL_DIR}/hosts/${host}.md"
  grep -Fq "](hosts/${host}.md)" "$ORCHESTRATOR"
done
if grep -Fq 'Use the Cursor runner below when a subagent' "$ORCHESTRATOR"; then
  echo "expected desktop Cursor to use native delegation" >&2
  exit 1
fi
grep -Fq 'with the absolute path to this skill directory' "$ORCHESTRATOR"
grep -Fq '{ model: "<exact slug>", reviewerId: "pending", status: "planned" }' "$ORCHESTRATOR"
grep -Fq 'Reviewer model: <exact slug>' "$ORCHESTRATOR"
grep -Fq 'Keep one private job per selected model, in selection order:' "$ORCHESTRATOR"
grep -Fq 'Keep counts and the job list out of successful output.' "$ORCHESTRATOR"
grep -Fq 'Stop synthesis if a launch or result fails or is missing.' "$ORCHESTRATOR"
grep -Fq 'present the review as complete.' "$ORCHESTRATOR"
if grep -Fq 'Expected <N> reviewers; launched <N>: <exact slugs>.' "$ORCHESTRATOR"; then
  echo "expected launch counts only for failed simplifier launches" >&2
  exit 1
fi
if grep -Fq 'AskQuestion' "$ORCHESTRATOR"; then
  echo "expected simplify-code to delegate model selection to its host guidance" >&2
  exit 1
fi
grep -Fq 'Selected: <exact slug>.' "$ORCHESTRATOR"
grep -Fq 'Use each hunk or whole file as a' "$WORKER"
grep -Fq '| Bundled PR | Detached head `source` and review index with `headRefOid` |' "$WORKER"
grep -Fq '| Small PR | Detached head `source`, patch, line map, and manifest with `headRefOid` |' "$WORKER"
grep -Fq 'Use `source` as the only PR code root.' "$WORKER"
grep -Fq 'A diff alone cannot prove that a helper, export,' "$WORKER"
grep -Fq 'anchor file or line map.' "$WORKER"
grep -Fq 'Return an input error if anything the selected scope requires is missing.' "$WORKER"
grep -Fq 'Read all supplied hunks. For paths scope, read each whole-file snapshot' "$WORKER"
grep -Fq '| Current changes | Caller repo root, patch, and patch digest |' "$WORKER"
grep -Fq '| Paths | Caller repo root, whole-file manifest, and input digest |' "$WORKER"
grep -Fq 'Reconcile interactions across units.' "$WORKER"
grep -Fq 'Record `finding`, `no finding`, or `candidate under verification`' "$WORKER"
grep -Fq 'privately for each unit.' "$WORKER"
grep -Fq 'Record why each `no finding` unit has no worthwhile simplification.' "$WORKER"
grep -Fq 'Return `No findings.` only after resolving every' "$WORKER"
grep -Fq 'behavior-preserving simplification' "$WORKER"
grep -Fq 'Avoid broad searches.' "$WORKER"
grep -Fq 'Classify boundary adaptation and composition' "$WORKER"
grep -Fq 'Length and member count alone are insufficient.' "$WORKER"
grep -Fq 'Keep entrypoints and adapters focused' "$WORKER"
grep -Fq '### Frontend' "$WORKER"
grep -Fq "hook's reactive coordination within one concern." "$WORKER"
grep -Fq 'move JSX, callbacks, or small helpers just to shorten a file.' "$WORKER"
grep -Fq 'Preserve cohesive state machines.' "$WORKER"
grep -Fq 'owned responsibilities, extraction targets, and dependency' "$WORKER"
grep -Fq 'SOLID' "$WORKER"
grep -Fq 'A second caller or planned feature is optional.' "$WORKER"
grep -Fq 'Policy likely to vary at a stable boundary.' "$WORKER"
grep -Fq 'Explain how the seam keeps change local.' "$WORKER"
grep -Fq 'confidence >= 75' "$WORKER"
grep -Fq 'P0 removes a recurring architectural or repository-wide barrier.' "$WORKER"
grep -Fq '| `Delete` | In-scope code that a proposed simplification makes obsolete. |' "$WORKER"
grep -Fq 'Exclude bugs, security issues, performance defects,' "$WORKER"
grep -Fq 'Reply "post all", "post 1,3", or "post none".' "$ORCHESTRATOR"
grep -Fq '**[P1] - Extract - confidence 92:**' "$WORKER"
grep -Fq 'postable without changes.' "$WORKER"
grep -Fq 'likely variation and evidence from changed code' "$WORKER"
grep -Fq 'For local review, run one command.' "$ORCHESTRATOR"
grep -Fq 'For a PR, prepare the pinned input.' "$ORCHESTRATOR"
grep -Fq 'For a PR, verify the pinned input before presenting.' "$ORCHESTRATOR"
grep -Fq "'--diff-algorithm=myers'" "$LOCAL_PREPARE"
grep -Fq "'--no-indent-heuristic'" "$LOCAL_PREPARE"
grep -Fq "'--unified=3'" "$LOCAL_PREPARE"
grep -Fq "'--no-textconv'" "$LOCAL_PREPARE"
if grep -Fq '[P1, confidence 85]:' "$ORCHESTRATOR"; then
  echo "expected simplify-code posting instructions to use the validated format" >&2
  exit 1
fi
if grep -Fq 'Recommended' "$ORCHESTRATOR"; then
  echo "expected simplify-code model labels to use exact slugs" >&2
  exit 1
fi
if grep -Fq "host's native \`code-simplifier\` type" "$ORCHESTRATOR"; then
  echo "expected simplify-code to use its bundled agent instructions" >&2
  exit 1
fi

LOCAL_REPO="${TMP}/local-repo"
mkdir -p "${LOCAL_REPO}/src/nested"
(
  cd "$LOCAL_REPO"
  git init --quiet
  git config user.email test@example.com
  git config user.name Test
  printf 'export const one = true;\nexport const two = true;\nexport const three = true;\nexport const first = true;\nexport const five = true;\nexport const six = true;\nexport const seven = true;\n' > src/first.ts
  printf 'export const second = true;\n' > src/nested/second.ts
  printf 'before\n' > 'src/café.md'
  printf 'original file\n' > src/kind
  git add src
  git commit --quiet -m initial

  node "$LOCAL_PREPARE" paths src/first.ts > "${TMP}/file-path.out"
  node "$LOCAL_PREPARE" paths src > "${TMP}/directory-path.out"
  git config diff.mnemonicPrefix true
  git config diff.noprefix true
  git config diff.algorithm histogram
  git config diff.context 0
  git config diff.indentHeuristic true
  printf 'export const one = true;\nexport const two = true;\nexport const three = true;\nexport const first = false;\nexport const five = true;\nexport const six = true;\nexport const seven = true;\n' > src/first.ts
  printf 'export const third = true;\n' > src/third.ts
  printf 'after\n' > 'src/café.md'
  printf 'new file\n' > 'src/review notes.md'
  unlink src/kind
  ln -s first.ts src/kind
  node "$LOCAL_PREPARE" changes > "${TMP}/changes.out"
  node "$LOCAL_PREPARE" changes > "${TMP}/repeat-changes.out"
)

grep '^patchDigest=' "${TMP}/changes.out" > "${TMP}/changes.digest"
grep '^patchDigest=' "${TMP}/repeat-changes.out" > "${TMP}/repeat-changes.digest"
cmp "${TMP}/changes.digest" "${TMP}/repeat-changes.digest"

FILE_MANIFEST="$(awk -F= '/^manifest=/{ print $2 }' "${TMP}/file-path.out")"
FILE_DIRECTORY="$(awk -F= '/^directory=/{ print $2 }' "${TMP}/file-path.out")"
FILE_BUNDLES="$(awk -F= '/^bundles=/{ print $2 }' "${TMP}/file-path.out")"
DIRECTORY_MANIFEST="$(awk -F= '/^manifest=/{ print $2 }' "${TMP}/directory-path.out")"
grep -Fq '"scope": "paths"' "$FILE_MANIFEST"
grep -Fq '"path": "src/first.ts"' "$FILE_MANIFEST"
if grep -Fq '"path": "src/nested/second.ts"' "$FILE_MANIFEST"; then
  echo "expected file path scope to exclude sibling files" >&2
  exit 1
fi
grep -Fq '"path": "src/first.ts"' "$DIRECTORY_MANIFEST"
grep -Fq '"path": "src/nested/second.ts"' "$DIRECTORY_MANIFEST"
node "$BUILD" "$FILE_MANIFEST" "$FILE_BUNDLES" > "${TMP}/path-build.out"
FILE_MATERIALIZED="${FILE_DIRECTORY}/materialized-review-bundles.json"
node "$VERIFY" "$FILE_MANIFEST" "$FILE_MATERIALIZED" > "${TMP}/path-verify.out"
grep -Fq '+++ "b/src/first.ts"' "${FILE_DIRECTORY}/bundles/01-src.diff"
grep -Fq 'export const one = true;' "${FILE_DIRECTORY}/bundles/01-src.diff"

CHANGES_PATCH="$(awk -F= '/^patch=/{ print $2 }' "${TMP}/changes.out")"
CHANGES_MANIFEST="$(awk -F= '/^manifest=/{ print $2 }' "${TMP}/changes.out")"
CHANGES_DIRECTORY="$(awk -F= '/^directory=/{ print $2 }' "${TMP}/changes.out")"
grep -Fq 'diff --git a/src/first.ts b/src/first.ts' "$CHANGES_PATCH"
grep -Fq 'diff --git a/src/third.ts b/src/third.ts' "$CHANGES_PATCH"
grep -Fq '@@ -1,7 +1,7 @@' "$CHANGES_PATCH"
grep -Fq '"path": "src/first.ts"' "$CHANGES_MANIFEST"
grep -Fq '"path": "src/third.ts"' "$CHANGES_MANIFEST"
grep -Fq '"id": "src/first.ts#1"' "$CHANGES_MANIFEST"
jq -e '([.files[] | select(.path == "src/café.md") | .hunks | length] == [1]) and
  ([.files[] | select(.path == "src/review notes.md") | .hunks | length] == [1]) and
  ([.files[] | select(.path == "src/kind") | .hunks[].id] == ["src/kind#1","src/kind#2"])' \
  "$CHANGES_MANIFEST" > /dev/null
node "$BUILD" "$CHANGES_MANIFEST" "${CHANGES_DIRECTORY}/review-bundles.json" > /dev/null
node "$VERIFY" "$CHANGES_MANIFEST" "${CHANGES_DIRECTORY}/materialized-review-bundles.json" > /dev/null
if grep -Fq '"path": ".tmp/review-' "$CHANGES_MANIFEST"; then
  echo "local review picked up its own artifacts" >&2
  exit 1
fi
node "$CLEANUP" "$CHANGES_DIRECTORY" > "${TMP}/cleanup.out"
grep -Fq "cleaned=${CHANGES_DIRECTORY}" "${TMP}/cleanup.out"
test ! -e "$CHANGES_DIRECTORY"
