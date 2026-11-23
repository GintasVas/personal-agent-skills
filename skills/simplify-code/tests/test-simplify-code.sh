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
grep -Fq 'decompose overloaded code units' "$ORCHESTRATOR"
grep -Fq '<this-skill-dir>/agents/code-simplifier.md' "$ORCHESTRATOR"
grep -Fq 'Repeat `--model` to run several' "$ORCHESTRATOR"
grep -Fq 'Treat skill scripts as command entrypoints.' "$ORCHESTRATOR"
grep -Fq 'Do not read or inspect their source.' "$ORCHESTRATOR"
grep -Fq 'detached head worktree' "$ORCHESTRATOR"
grep -Fq 'For bundled PRs, pass `review-index.json` and `source`.' "$ORCHESTRATOR"
grep -Fq '`patch.diff`, `line-map.json`, `manifest.json`, and `source`.' "$ORCHESTRATOR"
grep -Fq 'input paths, not line-map contents. The parent does not read the global line' "$ORCHESTRATOR"
grep -Fq 'run each job using its instructions in the prompt' "$ORCHESTRATOR"
grep -Fq '## Scope large reviews' "$ORCHESTRATOR"
grep -Fq 'For a review with more than 10 changed files or 500 changed lines' "$ORCHESTRATOR"
grep -Fq 'not send the full patch to every worker.' "$ORCHESTRATOR"
grep -Fq 'Bundle every hunk the manifest marks' "$ORCHESTRATOR"
grep -Fq 'new shared module with only the changed importers' "$ORCHESTRATOR"
grep -Fq 'Keep bundles bounded.' "$ORCHESTRATOR"
grep -Fq 'build-review-bundles.mjs' "$ORCHESTRATOR"
grep -Fq 'Every selected model gets all' "$ORCHESTRATOR"
grep -Fq 'Synthesize without discovering new findings.' "$ORCHESTRATOR"
grep -Fq 'canonical postable' "$ORCHESTRATOR"
grep -Fq '"selectedModels": ["<exact slug>", "<exact slug>"]' "$ORCHESTRATOR"
grep -Fq '"modelSlugs": ["<exact slug>"]' "$ORCHESTRATOR"
grep -Fq 'not include a `Found by` footer' "$ORCHESTRATOR"
grep -Fq '<this-skill-dir>/agents/code-simplifier.md' "$ORCHESTRATOR"
grep -Fq 'using its instructions in the prompt' "$ORCHESTRATOR"
grep -Fq 'direct prompt handoff does not invoke' "$ORCHESTRATOR"
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
grep -Fq 'This is internal orchestration state;' "$ORCHESTRATOR"
grep -Fq 'do not print it in chat.' "$ORCHESTRATOR"
grep -Fq 'Do not include the job list or launch counts in successful' "$ORCHESTRATOR"
grep -Fq 'do not synthesize' "$ORCHESTRATOR"
grep -Fq 'findings as complete.' "$ORCHESTRATOR"
if grep -Fq 'Expected <N> reviewers; launched <N>: <exact slugs>.' "$ORCHESTRATOR"; then
  echo "expected launch counts only for failed simplifier launches" >&2
  exit 1
fi
if grep -Fq 'AskQuestion' "$ORCHESTRATOR"; then
  echo "expected simplify-code to delegate model selection to its host guidance" >&2
  exit 1
fi
grep -Fq 'Selected: <exact slug>.' "$ORCHESTRATOR"
grep -Fq 'triage every changed' "$WORKER"
grep -Fq 'compact PR review index and detached head `source`' "$WORKER"
grep -Fq '`source` is the only code root' "$WORKER"
grep -Fq 'Do not infer a helper' "$WORKER"
grep -Fq 'bundle anchor file' "$WORKER"
grep -Fq "manifest's every materialized bundle is" "$WORKER"
grep -Fq 'For bundled review, read every supplied bundle.' "$WORKER"
grep -Fq 'For current changes or a' "$WORKER"
grep -Fq 'For path scope, read the whole-file' "$WORKER"
grep -Fq 'After every supplied hunk has been read' "$WORKER"
grep -Fq 'reconcile interactions across' "$WORKER"
grep -Fq 'Record an internal disposition for every changed unit' "$WORKER"
grep -Fq '10. Resolve every candidate before returning. Record why each `no finding` unit' "$WORKER"
grep -Fq 'If no worthwhile simplifications exist, return `No findings.` only after every' "$WORKER"
grep -Fq 'behavior-preserving simplification' "$WORKER"
grep -Fq 'repository-wide pattern without a candidate.' "$WORKER"
grep -Fq 'Do not perform a broad repository search' "$WORKER"
grep -Fq 'boundary adaptation and composition' "$WORKER"
grep -Fq 'File length and member count alone are not evidence.' "$WORKER"
grep -Fq 'Keep entrypoints and adapters focused' "$WORKER"
grep -Fq '## Frontend responsibility overload' "$WORKER"
grep -Fq 'should own reactive coordination for one concern.' "$WORKER"
grep -Fq 'Do not move JSX, callbacks, or small helpers merely to shorten a' "$WORKER"
grep -Fq 'Do not split' "$WORKER"
grep -Fq 'owned responsibilities, extraction targets, and dependency' "$WORKER"
grep -Fq 'SOLID' "$WORKER"
grep -Fq 'A second caller or concrete planned feature is not required.' "$WORKER"
grep -Fq 'when behavior is likely to vary by caller at a stable boundary' "$WORKER"
grep -Fq 'likely future variation and how the seam keeps that change local' "$WORKER"
grep -Fq 'confidence >= 75' "$WORKER"
grep -Fq '`**[P0]:**` repository-wide or architectural gain' "$WORKER"
grep -Fq '`Decompose`, `Extract`, `Standardize`, `Inject`, `Simplify`, or `Delete`' "$WORKER"
grep -Fq 'Do not report bugs, security issues, performance defects, test gaps, or' "$WORKER"
grep -Fq 'Reply "post all", "post 1,3", or "post none".' "$ORCHESTRATOR"
grep -Fq '**[P1] - Extract - confidence 92:**' "$WORKER"
grep -Fq 'must be postable without changes' "$WORKER"
grep -Fq 'likely variation and evidence for it' "$WORKER"
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
  node "$LOCAL_PREPARE" changes > "${TMP}/changes.out"
)

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
grep -Fq 'diff --git a/src/first.ts b/src/first.ts' "${FILE_DIRECTORY}/bundles/01-src.diff"
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
node "$CLEANUP" "$CHANGES_DIRECTORY" > "${TMP}/cleanup.out"
grep -Fq "cleaned=${CHANGES_DIRECTORY}" "${TMP}/cleanup.out"
test ! -e "$CHANGES_DIRECTORY"
