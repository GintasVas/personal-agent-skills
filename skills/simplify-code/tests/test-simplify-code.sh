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

LENSES="$SKILL_DIR/simplification-lenses.md"
for text in 'name: simplify-code' 'disable-model-invocation: true' '/skill:simplify-code' \
  '<this-skill-dir>/agents/code-simplifier.md' '[simplification-lenses.md](simplification-lenses.md), including Common.' \
  'whole-file manifest for the selected scope.' 'digest differs.' \
  'Reply "post all", "post 1,3", or "post none".'; do
  grep -Fq "$text" "$ORCHESTRATOR"
done
for text in '| Bundled PR | Detached head `source` and review index with `headRefOid` |' \
  '| Small PR | Detached head `source`, patch, line map, and manifest with `headRefOid` |' \
  '| Current changes | Caller repo root, patch, and patch digest |' \
  '| Paths | Caller repo root, whole-file manifest, and input digest |' \
  'Return an input error if required input or any materialized bundle is missing.' \
  'Read every supplied hunk or whole-file snapshot for paths scope.' \
  'Reconcile interactions across units.' 'Verify absence in the code root.' \
  'Complete the result only after checking all units and resolving candidates.' \
  'cohesive state machines.' 'Check interchangeability' 'likely variation' \
  'A second caller or planned feature is optional.' 'Use the lower score. Report only findings with confidence >= 75.' \
  'Rank by the size, reach, and recurrence of the gain.' '| `Delete` | Remove in-scope code the refactor makes obsolete. |' \
  'Exclude bugs, security and performance defects, test gaps, product logic,' \
  '**[P1] - Extract - confidence 92:**' 'anchor file or line map.' 'Unrelated discovered issue.'; do
  grep -Fq "$text" "$WORKER"
done
grep -Fq 'focused hooks for reusable reactive work.' "$LENSES"
grep -Fq 'distinct semantic or behavioral' "$LENSES"
diff -u <(grep '^## ' "$SKILL_DIR/workflow.md") <(grep '^## ' "$ORCHESTRATOR")
grep -Fq "'--diff-algorithm=myers'" "$LOCAL_PREPARE"
grep -Fq "'--no-indent-heuristic'" "$LOCAL_PREPARE"
grep -Fq "'--unified=3'" "$LOCAL_PREPARE"
grep -Fq '...REVIEW_DIFF_ARGS' "$LOCAL_PREPARE"
grep -Fq "'--no-textconv'" "${SKILL_DIR}/scripts/lib/review-automation.mjs"
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
