#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PREPARE="${SKILL_DIR}/scripts/prepare-pr-review-input.mjs"
POST="${SKILL_DIR}/scripts/post-inline-pr-comments.mjs"
BUILD="${SKILL_DIR}/scripts/build-review-bundles.mjs"
VERIFY="${SKILL_DIR}/scripts/verify-review-bundles.mjs"
CLEANUP="${SKILL_DIR}/scripts/cleanup-review-input.mjs"
NODE_FIXTURES="${SCRIPT_DIR}/review-pr.test.mjs"
SIMPLIFY="${SKILL_DIR}/../simplify-code/SKILL.md"
REVIEW="${SKILL_DIR}/SKILL.md"
REVIEWER="${SKILL_DIR}/agents/code-reviewer.md"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAKE_BIN="${TMP}/bin"
GH_CALLS="${TMP}/gh-calls"
GIT_CALLS="${TMP}/git-calls"
mkdir -p "$FAKE_BIN"

cat > "${FAKE_BIN}/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$GH_CALLS"

if [[ "${1:-}" == "pr" && "${2:-}" == "view" ]]; then
  cat "$GH_PR_JSON"
  if [[ -f "$GH_PR_NEXT_JSON" ]]; then
    mv "$GH_PR_NEXT_JSON" "$GH_PR_JSON"
  fi
  exit 0
fi

if [[ "${1:-}" == "pr" && "${2:-}" == "diff" ]]; then
  echo 'remote PR diff unavailable' >&2
  exit 1
fi

if [[ "${1:-}" == "api" && "${2:-}" == "--paginate" ]]; then
  if [[ -f "${POSTED_COMMENT}" && "${3:-}" == repos/*/pulls/*/comments ]]; then
    jq -c '{body, html_url:"https://github.com/example-org/example/pull/42#discussion_r1"}' "${POSTED_COMMENT}"
  fi
  exit 0
fi

if [[ "${1:-}" == "api" ]]; then
  payload="$(cat)"
  if [[ -n "${FAKE_FAIL_POST_PATH:-}" && "$(jq -r .path <<< "$payload")" == "$FAKE_FAIL_POST_PATH" ]]; then
    echo 'injected posting failure' >&2
    exit 1
  fi
  printf '%s\n' "$payload" > "${POSTED_COMMENT}"
  printf '%s\n' '{"html_url":"https://github.com/example-org/example/pull/42#discussion_r1"}'
  exit 0
fi

echo "Unexpected gh invocation: $*" >&2
exit 1
EOF
chmod +x "${FAKE_BIN}/gh"

cat > "${FAKE_BIN}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$GIT_CALLS"

arguments=("$@")
if [[ "${arguments[0]:-}" == "-C" ]]; then
  arguments=("${arguments[@]:2}")
fi
if [[ "${arguments[0]:-}" == "-c" ]]; then
  arguments=("${arguments[@]:2}")
fi

if [[ "${arguments[0]:-}" == "fetch" ]]; then
  exit 0
fi

if [[ "${arguments[0]:-}" == "diff" && " ${arguments[*]} " == *" --name-only "* ]]; then
  if [[ " ${arguments[*]} " == *"..."* ]]; then
    printf '%s\0' src/example.ts docs/example.md
    for ((index=1; index<=${FAKE_EXTRA_FILES:-0}; index++)); do
      printf 'extra/file-%d.md\0' "$index"
    done
  else
    printf '%b' "${FAKE_CONTEXT_CHANGES:-}" | tr '\n' '\0'
  fi
  exit 0
fi

if [[ "${arguments[0]:-}" == "diff" ]]; then
  printf '%b' "${FAKE_PATCH_PREFIX:-}"
  cat <<'PATCH'
diff --git a/src/example.ts b/src/example.ts
index 1111111..2222222 100644
--- a/src/example.ts
+++ b/src/example.ts
@@ -1,3 +1,3 @@
 export const before = true;
--- removed marker
++++ added marker
 export const unchanged = true;
diff --git a/docs/example.md b/docs/example.md
index 3333333..4444444 100644
--- a/docs/example.md
+++ b/docs/example.md
@@ -1 +1 @@
-before
+after
PATCH
  for ((index=1; index<=${FAKE_EXTRA_FILES:-0}; index++)); do
    path="extra/file-$index.md"
    printf 'diff --git a/%s b/%s\n--- a/%s\n+++ b/%s\n@@ -1 +1 @@\n-before\n+after\n' "$path" "$path" "$path" "$path"
  done
  exit 0
fi

if [[ "${arguments[0]:-}" == "rev-parse" &&
  "${arguments[1]:-}" == "refs/agent-review-input/"*"head^{commit}" ]]; then
  printf '%s\n' "${FAKE_HEAD_OID:-0123456789abcdef}"
  exit 0
fi

if [[ "${arguments[0]:-}" == "rev-parse" &&
  "${arguments[1]:-}" == "refs/agent-review-input/"*"base^{commit}" ]]; then
  printf '%s\n' 'base0123456789'
  exit 0
fi

if [[ "${arguments[0]:-}" == "worktree" && "${arguments[1]:-}" == "add" ]]; then
  worktree_path="${arguments[$((${#arguments[@]} - 2))]}"
  mkdir -p "$worktree_path"
  printf '%s\n' "$worktree_path" >> "$FAKE_WORKTREES"
  exit 0
fi

if [[ "${arguments[0]:-}" == "worktree" && "${arguments[1]:-}" == "list" ]]; then
  while IFS= read -r worktree_path; do
    [[ -n "$worktree_path" ]] && printf 'worktree %s\n' "$worktree_path"
  done < "$FAKE_WORKTREES"
  exit 0
fi

if [[ "${arguments[0]:-}" == "worktree" && "${arguments[1]:-}" == "remove" ]]; then
  worktree_path="${arguments[$((${#arguments[@]} - 1))]}"
  rm -rf "$worktree_path"
  temporary_worktrees="${FAKE_WORKTREES}.next"
  : > "$temporary_worktrees"
  while IFS= read -r existing_path; do
    [[ "$existing_path" != "$worktree_path" ]] && printf '%s\n' "$existing_path" >> "$temporary_worktrees"
  done < "$FAKE_WORKTREES"
  mv "$temporary_worktrees" "$FAKE_WORKTREES"
  exit 0
fi

if [[ "${arguments[0]:-}" == "update-ref" || "${arguments[0]:-}" == "worktree" ]]; then
  exit 0
fi

exec "$REAL_GIT" "$@"
EOF
chmod +x "${FAKE_BIN}/git"

export GH_CALLS
export GIT_CALLS
export GH_PR_JSON="${TMP}/pull-request.json"
export GH_PR_NEXT_JSON="${TMP}/next-pull-request.json"
export FAKE_WORKTREES="${TMP}/worktrees"
export POSTED_COMMENT="${TMP}/posted-comment.json"
export REAL_GIT
write_pull_request() {
  cat > "$GH_PR_JSON" <<JSON
{"number":42,"baseRefName":"${3:-feature/parent}","baseRefOid":"$1","headRefName":"feature/child","headRefOid":"${2:-0123456789abcdef}","url":"https://github.com/example-org/example/pull/42"}
JSON
}

write_pull_request base0123456789
: > "$FAKE_WORKTREES"
REAL_GIT="$(command -v git)"
export PATH="${FAKE_BIN}:${PATH}"

expect_failure() {
  local expected_error="$1"
  shift

  if "$@" > "${TMP}/failure.out" 2> "${TMP}/failure.err"; then
    echo "expected command failure: $*" >&2
    exit 1
  fi

  grep -Fq "$expected_error" "${TMP}/failure.err"
}

node --test "$NODE_FIXTURES"

node "$PREPARE" prepare 42 > "${TMP}/prepare.out"
REVIEW_DIRECTORY="$(awk -F= '/^directory=/{ print $2 }' "${TMP}/prepare.out")"
grep -Fq "directory=${REVIEW_DIRECTORY}" "${TMP}/prepare.out"
grep -Fq 'baseRefName=feature/parent' "${TMP}/prepare.out"
grep -Fq 'baseRefOid=base0123456789' "${TMP}/prepare.out"
grep -Fq 'headRefName=feature/child' "${TMP}/prepare.out"
grep -Fq 'headRefOid=0123456789abcdef' "${TMP}/prepare.out"
grep -Fq "source=${REVIEW_DIRECTORY}/source" "${TMP}/prepare.out"
grep -Fq "temporaryRef=refs/agent-review-input/$(basename "${REVIEW_DIRECTORY}")/head" "${TMP}/prepare.out"
grep -Fq "fetch --no-tags https://github.com/example-org/example.git refs/pull/42/head:refs/agent-review-input/$(basename "${REVIEW_DIRECTORY}")/head refs/heads/feature/parent:refs/agent-review-input/$(basename "${REVIEW_DIRECTORY}")/base" "${GIT_CALLS}"
if grep -Fq 'pr diff' "${GH_CALLS}"; then
  echo "prepare must not call gh pr diff" >&2
  exit 1
fi
grep -Fq 'files=2' "${TMP}/prepare.out"
grep -Fq 'additions=2' "${TMP}/prepare.out"
grep -Fq 'deletions=2' "${TMP}/prepare.out"
grep -Fq 'reviewableHunks=2' "${TMP}/prepare.out"
grep -Fq '"path": "src/example.ts"' "${REVIEW_DIRECTORY}/manifest.json"
grep -Fq '"additions": 1' "${REVIEW_DIRECTORY}/manifest.json"
grep -Fq '"deletions": 1' "${REVIEW_DIRECTORY}/manifest.json"
grep -Fq '"bundleCandidate": "src"' "${REVIEW_DIRECTORY}/manifest.json"
grep -Fq '"id": "src/example.ts#1"' "${REVIEW_DIRECTORY}/manifest.json"
grep -Fq '"schemaVersion": 3' "${REVIEW_DIRECTORY}/manifest.json"
grep -Fq '"name": "feature/parent"' "${REVIEW_DIRECTORY}/manifest.json"
grep -Fq '"oid": "base0123456789"' "${REVIEW_DIRECTORY}/manifest.json"
grep -Fq "\"worktreePath\": \"${REVIEW_DIRECTORY}/source\"" "${REVIEW_DIRECTORY}/manifest.json"
grep -Fq "\"temporaryBaseRef\": \"refs/agent-review-input/$(basename "${REVIEW_DIRECTORY}")/base\"" "${REVIEW_DIRECTORY}/manifest.json"
grep -Fq '"repositoryUrl": "https://github.com/example-org/example.git"' "${REVIEW_DIRECTORY}/manifest.json"
test -d "${REVIEW_DIRECTORY}/source"
grep -Fq '"lineMapPath":' "${REVIEW_DIRECTORY}/manifest.json"
grep -Fq '"anchor": "+++ added marker"' "${REVIEW_DIRECTORY}/line-map.json"
grep -Fq '"line": 2' "${REVIEW_DIRECTORY}/line-map.json"
grep -Fq '"name": "src"' "${REVIEW_DIRECTORY}/review-bundles.json"
grep -Fq '"name": "docs"' "${REVIEW_DIRECTORY}/review-bundles.json"
grep -Fq 'docs/example.md#1' "${REVIEW_DIRECTORY}/review-bundles.json"

node "$PREPARE" verify 42 "${REVIEW_DIRECTORY}/manifest.json" \
  > "${TMP}/verify.out"
grep -Fq 'verified=' "${TMP}/verify.out"
grep -Fq 'baseRefOid=base0123456789' "${TMP}/verify.out"
if grep -Fq 'pinnedHeadRefOid=' "${TMP}/verify.out"; then
  echo "verify must not report drift when the head is unchanged" >&2
  exit 1
fi
grep -Fq "update-ref -d refs/agent-review-input/$(basename "${REVIEW_DIRECTORY}")/verify-head" "${GIT_CALLS}"
grep -Fq "update-ref -d refs/agent-review-input/$(basename "${REVIEW_DIRECTORY}")/verify-base" "${GIT_CALLS}"

write_pull_request stale-github-base
node "$PREPARE" verify 42 "${REVIEW_DIRECTORY}/manifest.json" \
  > "${TMP}/stale-base-verify.out"
grep -Fq 'baseRefOid=base0123456789' "${TMP}/stale-base-verify.out"

write_pull_request base0123456789 0123456789abcdef feature/other
expect_failure 'no longer matches the pinned review input' \
  node "$PREPARE" verify 42 "${REVIEW_DIRECTORY}/manifest.json"
write_pull_request base0123456789

FAKE_PATCH_PREFIX='diff --git a/src/new.ts b/src/new.ts\n' \
  expect_failure 'no longer matches the pinned review input' \
  node "$PREPARE" verify 42 "${REVIEW_DIRECTORY}/manifest.json"
FAKE_PATCH_PREFIX='diff --git a/src/new.ts b/src/new.ts\n' \
  expect_failure 'parsed patch file list does not match' node "$PREPARE" prepare 42

write_pull_request base0123456789 fedcba9876543210
FAKE_HEAD_OID=fedcba9876543210 \
  FAKE_CONTEXT_CHANGES='src/example.ts\ndocs/context.md\n' \
  node "$PREPARE" verify 42 "${REVIEW_DIRECTORY}/manifest.json" \
  > "${TMP}/drift-verify.out"
grep -Fq 'headRefOid=fedcba9876543210' "${TMP}/drift-verify.out"
grep -Fq 'pinnedHeadRefOid=0123456789abcdef' "${TMP}/drift-verify.out"
grep -Fq 'contextChanges=1' "${TMP}/drift-verify.out"
grep -Fxq 'docs/context.md' "${REVIEW_DIRECTORY}/context-changes.txt"
write_pull_request base0123456789

write_pull_request stale-github-base
node "$PREPARE" prepare 42 > "${TMP}/stale-base-prepare.out"
grep -Fq 'baseRefOid=base0123456789' "${TMP}/stale-base-prepare.out"
STALE_BASE_DIRECTORY="$(awk -F= '/^directory=/{ print $2 }' "${TMP}/stale-base-prepare.out")"
grep -Fq '"oid": "base0123456789"' "${STALE_BASE_DIRECTORY}/manifest.json"
node "$CLEANUP" "${STALE_BASE_DIRECTORY}" > /dev/null
write_pull_request base0123456789

cat > "$GH_PR_NEXT_JSON" <<'JSON'
{"number":42,"baseRefName":"feature/parent","baseRefOid":"changed-base","headRefName":"feature/child","headRefOid":"0123456789abcdef","url":"https://github.com/example-org/example/pull/42"}
JSON
WORKTREES_BEFORE="$(cat "$FAKE_WORKTREES")"
expect_failure 'changed while fetching its diff' node "$PREPARE" prepare 42
if [[ "$(cat "$FAKE_WORKTREES")" != "$WORKTREES_BEFORE" ]]; then
  echo "prepare must remove its worktree when the PR changes" >&2
  exit 1
fi
write_pull_request base0123456789

cat > "${TMP}/bundles.json" <<'JSON'
{"bundles":[{"name":"example","hunkIds":["src/example.ts#1","docs/example.md#1"]}]}
JSON

node "$BUILD" "${REVIEW_DIRECTORY}/manifest.json" "${TMP}/bundles.json" > "${TMP}/build.out"
MATERIALIZED_BUNDLES="${TMP}/materialized-review-bundles.json"
REVIEW_INDEX="${TMP}/review-index.json"
grep -Fq "materialized=${MATERIALIZED_BUNDLES}" "${TMP}/build.out"
grep -Fq "index=${REVIEW_INDEX}" "${TMP}/build.out"
grep -Fq '"anchorsPath":' "${MATERIALIZED_BUNDLES}"
grep -Fq '"source":' "${REVIEW_INDEX}"
grep -Fq '"anchorsPath":' "${REVIEW_INDEX}"
node "$VERIFY" "${REVIEW_DIRECTORY}/manifest.json" "$MATERIALIZED_BUNDLES" > "${TMP}/bundles.out"
grep -Fq 'verified 2 reviewable hunks across 1 materialized bundles' "${TMP}/bundles.out"
grep -Fq 'diff --git a/src/example.ts b/src/example.ts' "${TMP}/bundles/01-example.diff"
grep -Fq 'diff --git a/docs/example.md b/docs/example.md' "${TMP}/bundles/01-example.diff"
printf '' > "${TMP}/bundles/01-example.diff"
expect_failure 'does not match the pinned review input' \
  node "$VERIFY" "${REVIEW_DIRECTORY}/manifest.json" "$MATERIALIZED_BUNDLES"

printf '%s\n' '{"bundles":[]}' > "${TMP}/missing-bundles.json"
expect_failure 'missing: src/example.ts#1, docs/example.md#1' \
  node "$BUILD" "${REVIEW_DIRECTORY}/manifest.json" "${TMP}/missing-bundles.json"

cat > "${TMP}/duplicate-bundles.json" <<'JSON'
{"bundles":[{"name":"one","hunkIds":["src/example.ts#1"]},{"name":"two","hunkIds":["src/example.ts#1"]}]}
JSON
expect_failure 'duplicated: src/example.ts#1' \
  node "$BUILD" "${REVIEW_DIRECTORY}/manifest.json" "${TMP}/duplicate-bundles.json"

ISOLATED_SKILL="${TMP}/isolated/.agents/skills/review-pr"
mkdir -p "$(dirname "$ISOLATED_SKILL")"
cp -RL "$SKILL_DIR" "$ISOLATED_SKILL"
node "${ISOLATED_SKILL}/scripts/prepare-pr-review-input.mjs" prepare 42 > "${TMP}/isolated-prepare.out"
ISOLATED_DIRECTORY="$(awk -F= '/^directory=/{ print $2 }' "${TMP}/isolated-prepare.out")"
grep -Fq 'headRefOid=0123456789abcdef' "${TMP}/isolated-prepare.out"
test -f "${ISOLATED_DIRECTORY}/manifest.json"

cat > "${TMP}/comments.json" <<'JSON'
{
  "selectedModels": ["claude-opus-5-5-high", "grok-4.7-high"],
  "comments": [
    {
      "path": "src/example.ts",
      "line": 3,
      "side": "RIGHT",
      "anchor": "export const unchanged = true;",
      "body": "**[P1] - Correctness - confidence 85:**\n\nKeep this finding inline.",
      "modelSlugs": ["grok-4.7-high", "claude-opus-5-5-high"]
    }
  ]
}
JSON

node "$POST" 42 0123456789abcdef "${REVIEW_DIRECTORY}/manifest.json" - < "${TMP}/comments.json" \
  > "${TMP}/post.out"
grep -Fq '#discussion_r1' "${TMP}/post.out"
grep -Fq 'Found by: `claude-opus-5-5-high`, `grok-4.7-high`' "${POSTED_COMMENT}"
grep -Fq '"commit_id":"0123456789abcdef"' "${POSTED_COMMENT}"
grep -Fq '"line":3' "${POSTED_COMMENT}"
grep -Fq '"side":"RIGHT"' "${POSTED_COMMENT}"
grep -Fq 'repos/example-org/example/pulls/42/comments' "${GH_CALLS}"
if grep -Fq '/reviews' "${GH_CALLS}"; then
  echo "expected standalone inline comments without a GitHub review" >&2
  exit 1
fi

cat > "${TMP}/legacy-comments.json" <<'JSON'
{
  "selectedModels": ["claude-opus-5-5-high"],
  "comments": [
    {
      "path": "src/example.ts",
      "line": 3,
      "side": "RIGHT",
      "anchor": "export const unchanged = true;",
      "body": "**[P1, confidence 85]:**\n\nKeep this finding inline.",
      "modelSlugs": ["claude-opus-5-5-high"]
    }
  ]
}
JSON
expect_failure 'must start with bold severity and confidence' \
  node "$POST" 42 0123456789abcdef "${REVIEW_DIRECTORY}/manifest.json" "${TMP}/legacy-comments.json"
expect_failure 'Do not post stale findings' node "$POST" 42 changed-sha "${REVIEW_DIRECTORY}/manifest.json" "${TMP}/comments.json"

node "$POST" 42 0123456789abcdef "${REVIEW_DIRECTORY}/manifest.json" "${TMP}/comments.json" \
  > "${TMP}/retry.out"
grep -Fq 'alreadyPosted=https://github.com/example-org/example/pull/42#discussion_r1' "${TMP}/retry.out"
jq '.comments[0].body += " First partial finding." |
  .comments += [.comments[0] + {path:"docs/example.md",line:1,anchor:"after"}]' \
  "${TMP}/comments.json" > "${TMP}/partial-comments.json"
FAKE_FAIL_POST_PATH=docs/example.md expect_failure 'injected posting failure' \
  node "$POST" 42 0123456789abcdef "${REVIEW_DIRECTORY}/manifest.json" "${TMP}/partial-comments.json"
grep -Fq '"path":"src/example.ts"' "${POSTED_COMMENT}"
node "$POST" 42 0123456789abcdef "${REVIEW_DIRECTORY}/manifest.json" "${TMP}/partial-comments.json" \
  > "${TMP}/partial-retry.out"
grep -Fq 'alreadyPosted=https://github.com/example-org/example/pull/42#discussion_r1' "${TMP}/partial-retry.out"
grep -Fq '"path":"docs/example.md"' "${POSTED_COMMENT}"
FAKE_PATCH_PREFIX='diff --git a/src/new.ts b/src/new.ts\n' \
  expect_failure 'no longer matches the pinned review input' \
  node "$POST" 42 0123456789abcdef "${REVIEW_DIRECTORY}/manifest.json" "${TMP}/comments.json"

write_pull_request base0123456789 fedcba9876543210
jq '.comments[0].evidencePaths = ["docs/context.md"]' "${TMP}/comments.json" > "${TMP}/context-comment.json"
FAKE_HEAD_OID=fedcba9876543210 FAKE_CONTEXT_CHANGES='docs/context.md\n' \
  expect_failure 'Review context changed' \
  node "$POST" 42 fedcba9876543210 "${REVIEW_DIRECTORY}/manifest.json" "${TMP}/context-comment.json"
write_pull_request base0123456789

FAKE_EXTRA_FILES=310 node "$PREPARE" prepare 42 > "${TMP}/large-prepare.out"
grep -Fxq 'files=312' "${TMP}/large-prepare.out"
LARGE_DIRECTORY="$(awk -F= '/^directory=/{ print $2 }' "${TMP}/large-prepare.out")"
jq '.comments[0] += {path:"extra/file-310.md",line:1,anchor:"after"}' "${TMP}/comments.json" > "${TMP}/large-comment.json"
FAKE_EXTRA_FILES=310 node "$POST" 42 0123456789abcdef "${LARGE_DIRECTORY}/manifest.json" "${TMP}/large-comment.json" \
  > "${TMP}/large-post.out"
grep -Fq '"path":"extra/file-310.md"' "${POSTED_COMMENT}"
node "$CLEANUP" "${LARGE_DIRECTORY}" >/dev/null
if grep -Fq 'pr diff' "$GH_CALLS"; then
  echo "posting must use the pinned Git diff" >&2
  exit 1
fi

node "$CLEANUP" "${REVIEW_DIRECTORY}" > "${TMP}/cleanup.out"
grep -Fq "cleaned=${REVIEW_DIRECTORY}" "${TMP}/cleanup.out"
test ! -e "${REVIEW_DIRECTORY}"
grep -Fq "worktree remove --force ${REVIEW_DIRECTORY}/source" "${GIT_CALLS}"
grep -Fq -- '-c core.hooksPath=/dev/null worktree add --detach' "${GIT_CALLS}"
grep -Fq "update-ref -d refs/agent-review-input/$(basename "${REVIEW_DIRECTORY}")/head" "${GIT_CALLS}"
node "$CLEANUP" "${REVIEW_DIRECTORY}" > "${TMP}/repeat-cleanup.out"
grep -Fq "cleaned=${REVIEW_DIRECTORY}" "${TMP}/repeat-cleanup.out"
node "${ISOLATED_SKILL}/scripts/cleanup-review-input.mjs" "${ISOLATED_DIRECTORY}" \
  > "${TMP}/isolated-cleanup.out"
test ! -e "${ISOLATED_DIRECTORY}"
UNMARKED_DIRECTORY="$(dirname "$REVIEW_DIRECTORY")/unmarked-$(basename "$TMP")"
mkdir "$UNMARKED_DIRECTORY"
expect_failure 'not a marked review input directory' node "$CLEANUP" "$UNMARKED_DIRECTORY"
rmdir "$UNMARKED_DIRECTORY"

REVIEW_ROOT="$(dirname "$REVIEW_DIRECTORY")"
STALE_DIRECTORY="${REVIEW_ROOT}/review-stale-$(basename "$TMP")"
FRESH_DIRECTORY="${REVIEW_ROOT}/review-fresh-$(basename "$TMP")"
UNMARKED_STALE_DIRECTORY="${REVIEW_ROOT}/review-unmarked-$(basename "$TMP")"
mkdir "$STALE_DIRECTORY" "$FRESH_DIRECTORY" "$UNMARKED_STALE_DIRECTORY"
printf 'agent-review-input\n' > "${STALE_DIRECTORY}/.agent-review-input"
printf 'agent-review-input\n' > "${FRESH_DIRECTORY}/.agent-review-input"
touch -t 202001010000 "${STALE_DIRECTORY}/.agent-review-input"
node "$CLEANUP" --stale > "${TMP}/stale-cleanup.out"
grep -Fq "cleaned=${STALE_DIRECTORY}" "${TMP}/stale-cleanup.out"
test ! -e "$STALE_DIRECTORY"
test -d "$FRESH_DIRECTORY"
test -d "$UNMARKED_STALE_DIRECTORY"
rm -rf "$FRESH_DIRECTORY" "$UNMARKED_STALE_DIRECTORY"

for skill in "$SIMPLIFY" "$REVIEW"; do
  grep -Fq 'prepare-pr-review-input.mjs prepare' "$skill"
  grep -Fq 'prepare-pr-review-input.mjs verify' "$skill"
  grep -Fq 'build-review-bundles.mjs' "$skill"
  grep -Fq 'post-inline-pr-comments.mjs' "$skill"
  grep -Fq 'cleanup-review-input.mjs' "$skill"
  grep -Fq 'standard input' "$skill"
  grep -Fq 'verifies and posts the full batch' "$skill"
  grep -Fq 'Bundle a new shared module with only the changed' "$skill"
  grep -Fq 'bounded' "$skill"
done

grep -Fq 'approved inline findings' "$REVIEW"
grep -Fq '"anchor": "<full changed line>"' "$REVIEW"
grep -Fq 'Return `headRefOid` with the results.' "$REVIEWER"
grep -Fq 'source style, and missing lockfiles.' "$REVIEWER"
grep -Fq '**[P1] - Correctness - confidence 92:**' "$REVIEWER"
grep -Fq 'must be postable without changes' "$REVIEWER"
grep -Fq 'Keep source line numbers out of bodies.' "$REVIEWER"
grep -Fq 'Use detached head `source` as the only code root.' "$REVIEWER"
grep -Fq 'Bundles use `review-index.json` and each bundle' "$REVIEWER"
grep -Fq 'A diff alone cannot prove that a helper, export, or pattern is missing.' "$REVIEWER"
grep -Fq 'Copy the full changed line from the matching anchor' "$REVIEWER"
grep -Fq 'Return an input error if any materialized bundle is missing.' "$REVIEWER"
grep -Fq 'Read every supplied hunk once.' "$REVIEWER"
grep -Fq 'Small PRs use the complete `patch.diff` and `line-map.json`.' "$REVIEWER"
grep -Fq 'After reading all hunks' "$REVIEWER"
grep -Fq 'reconcile interactions across' "$REVIEWER"
grep -Fq 'Trace changed public interfaces and data flow' "$REVIEWER"
grep -Fq 'Record an internal disposition for every changed reviewable hunk' "$REVIEWER"
grep -Fq 'trace execution and the external state that the invoked code uses.' "$REVIEWER"
grep -Fq 'Return `No findings.` only after resolving all hunk' "$REVIEWER"
grep -Fq 'Selected: <exact slug>.' "$REVIEW"
grep -Fq 'Run the bundled scripts at the steps below.' "$REVIEW"
grep -Fq 'Do not inspect script source.' "$REVIEW"
grep -Fq 'If prepare fails or does not report `directory`, report the failure and stop.' "$REVIEW"
grep -Fq 'Do not construct substitute patches, manifests, line maps, or bundles.' "$REVIEW"
grep -Fq 'For bundled PRs, pass `review-index.json` and `source`.' "$REVIEW"
grep -Fq '`patch.diff`, `line-map.json`, `manifest.json`, and `source`.' "$REVIEW"
grep -Fq 'The parent does not read the global line map.' "$REVIEW"
grep -Fq 'Give all verified bundles to every model.' "$REVIEW"
grep -Fq '"path": "<path>"' "$REVIEW"
grep -Fq 'with the absolute path to this skill directory' "$REVIEW"
grep -Fq '<this-skill-dir>/agents/code-reviewer.md' "$REVIEW"
grep -Fq 'Put its contract and' "$REVIEW"
grep -Fq '/skill:review-pr' "$REVIEW"
for host in pi cursor-desktop cursor-cli codex other; do
  test -f "${SKILL_DIR}/hosts/${host}.md"
  grep -Fq "](hosts/${host}.md)" "$REVIEW"
done
grep -Fq 'Before any other tool call, read only the host file' "$REVIEW"
if grep -Fq 'Use the Cursor runner below when a subagent' "$REVIEW"; then
  echo "expected desktop Cursor to use native delegation" >&2
  exit 1
fi
grep -Fq 'Pass the prompt directly without' "$REVIEW"
grep -Fq '{ model: "<exact slug>", reviewerId: "pending", status: "planned" }' "$REVIEW"
grep -Fq 'Reviewer model: <exact slug>' "$REVIEW"
grep -Fq 'Keep one private job per selected model, in selection order:' "$REVIEW"
grep -Fq 'Keep counts and the job list out of successful output.' "$REVIEW"
grep -Fq 'Stop synthesis if a launch or result fails or is missing.' "$REVIEW"
grep -Fq 'present the review as complete.' "$REVIEW"
if grep -Fq 'Expected <N> reviewers; launched <N>: <exact slugs>.' "$REVIEW"; then
  echo "expected launch counts only for failed reviewer launches" >&2
  exit 1
fi
grep -Fq 'Synthesize without discovering new findings.' "$REVIEW"
grep -Fq 'Merge same-anchor reports only when they identify the same mechanism.' "$REVIEW"
grep -Fq '"selectedModels": ["<exact slug>", "<exact slug>"]' "$REVIEW"
grep -Fq '"modelSlugs": ["<exact slug>"]' "$REVIEW"
grep -Fq 'adds the footer in `selectedModels` order.' "$REVIEW"
grep -Fq 'withModelAttribution' "$POST"
grep -Fq 'Never post' "$REVIEW"
if grep -Fq 'AskQuestion' "$REVIEW"; then
  echo "expected review-pr to delegate model selection to its host guidance" >&2
  exit 1
fi
if grep -Fq '[P1, confidence 85]:' "$REVIEW"; then
  echo "expected review-pr posting instructions to use the validated format" >&2
  exit 1
fi
if grep -Fq 'Recommended' "$SIMPLIFY"; then
  echo "expected simplify-code model labels to use exact slugs" >&2
  exit 1
fi
if grep -Fq 'subagent_type: code-reviewer' "$REVIEW"; then
  echo "expected review-pr to use its bundled agent instructions" >&2
  exit 1
fi
