#!/usr/bin/env bash
set -uo pipefail

SKILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${SKILL_ROOT}/tests/structural-common.sh" "$SKILL_ROOT" pr P2 \
  expected_outcome 'ACCEPTED_EXCEPTION FINDING QUESTION' '## Structural results'
LOCAL_PREPARE="${SKILL_ROOT}/scripts/prepare-local-spec-input.mjs"
CLEANUP="${SKILL_ROOT}/scripts/cleanup-review-input.mjs"
ORCHESTRATOR="${SKILL_ROOT}/SKILL.md"
WORKER="${SKILL_ROOT}/agents/spec-reviewer.md"
WORKFLOW="${SKILL_ROOT}/workflow.md"

check "change-level and naming results use existing repository files" \
  python3 - "${RUNNER}" "${temp_dir}/anchors" <<'PY'
import importlib.util
import sys
from pathlib import Path

module_path, root = sys.argv[1], Path(sys.argv[2])
spec = importlib.util.spec_from_file_location("audit_structure", module_path)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
profile = module.configure_profile("pr")

change = root / "openspec" / "changes" / "no-config"
change.mkdir(parents=True)
(change / "proposal.md").write_text("# Proposal\n")
(change / "Bad-Name.md").write_text("# Bad\n")
(root / "scripts").mkdir()
(root / "scripts" / "validate_naming.sh").write_text(
    "for path in \"$@\"; do case \"$path\" in *Bad-Name*) "
    "echo \"ERROR: Invalid markdown naming in '$path': use snake_case\" >&2;; esac; done\n"
    "exit 1\n"
)

findings, coverage = [], []
module.check_change_structure(profile, change, root, findings)
module.check_naming(
    profile, sorted(change.iterdir()), root, findings, coverage,
    root / "scripts" / "validate_naming.sh",
)
paths = {item["rule_id"]: item["path"] for item in findings}
if paths.get("S002") != "openspec/changes/no-config/proposal.md":
    raise SystemExit(f"S002 must anchor on the proposal: {paths}")
if paths.get("S013") != "openspec/changes/no-config/Bad-Name.md":
    raise SystemExit(f"S013 must name the offending file: {paths}")
if profile.issue_path(root, "spec", "demo", "file") != "openspec/specs/demo/spec.md":
    raise SystemExit("spec-level OpenSpec errors must point at the main spec")
PY
has() {
  grep -Fq -- "$1" "$2"
}

lacks() {
  ! grep -Fq -- "$1" "$2"
}

check "skill pins OpenSpec version" has '@fission-ai/openspec@1.6.0' "${ORCHESTRATOR}"
check "skill does not invoke latest OpenSpec" \
  bash -c "! grep -Eq 'npx .*@latest' \"${ORCHESTRATOR}\""
check "skill hard-excludes explicit non-goals" \
  has 'Exclude explicit non-goals from findings, questions, and' "${SKILL_ROOT}/REFERENCE.md"
check "skill links bundled reference files" \
  bash -c "grep -Fq '[\`LANES.md\`](LANES.md)' \"${ORCHESTRATOR}\" && grep -Fq '[\`REFERENCE.md\`](REFERENCE.md)' \"${ORCHESTRATOR}\""
check "reference defines coverage passes" \
  grep -Eq '^## Coverage passes' "${SKILL_ROOT}/REFERENCE.md"
check "every coverage pass belongs to one lane" \
  python3 - "${SKILL_ROOT}/COMMON_REFERENCE.md" "${LANES}" <<'PY'
import re
import sys

reference, lanes = (open(path, encoding="utf-8").read() for path in sys.argv[1:])
section = reference.split("## Coverage passes", 1)[1].split("\n## ", 1)[0]
passes = re.findall(r"^### (.+)$", section, re.M)
assigned = re.findall(r"`([^`]+)`", "".join(re.findall(r"^Coverage passes: (.+)$", lanes, re.M)))
if sorted(passes) != sorted(assigned):
    raise SystemExit(f"passes {sorted(passes)} != lane assignments {sorted(assigned)}")
PY
check "reference orders findings by severity" \
  has '1. Findings, structural and behavioral together: P0, P1, P2' "${SKILL_ROOT}/REFERENCE.md"
check "undefined concepts are P0" \
  grep -Eq '[|] Q002 Undefined term +[|] P0 ' "${SKILL_ROOT}/CHECKLIST.md"
check "missing fact context is P0" \
  grep -Eq '[|] Q014 Undefined fact contract +[|] P0 ' "${SKILL_ROOT}/CHECKLIST.md"
check "spec docs drop legacy severity names" \
  bash -c "grep -rEq 'Blocker|Major|Minor|REVIEW_QUESTION' \"${SKILL_ROOT}\"/*.md \"${SKILL_ROOT}/agents\"; test \$? -eq 1"

check "skill requires explicit invocation" has 'disable-model-invocation: true' "${ORCHESTRATOR}"
HOSTS="${SKILL_ROOT}/hosts"
check "skill reads its host file before tools" \
  has 'Before running commands, read only the matching host guide:' "${WORKFLOW}"
for host in pi cursor-desktop cursor-cli codex other; do
  check "skill links the ${host} host file" \
    bash -c "test -f '${HOSTS}/${host}.md' && grep -Fq '](hosts/${host}.md)' '${WORKFLOW}'"
done
check "skill supports repeated models" has 'Repeat `--model`' "${WORKFLOW}"
check "skill echoes selected slugs" has 'Selected: <exact slug>.' "${WORKFLOW}"
check "skill stays host-neutral" \
  bash -c "! grep -Fq AskQuestion '${ORCHESTRATOR}'"
check "skill supports Pi" has '/skill:spec-audit-pr' "${ORCHESTRATOR}"
check "skill loads the spec-reviewer contract" \
  has '<this-skill-dir>/agents/spec-reviewer.md' "${ORCHESTRATOR}"
check "skill tracks reviewer jobs" \
  has 'Keep one private job per selected model in selection order.' "${WORKFLOW}"
check "skill pins reviewer model in prompt" has 'Reviewer model: <exact slug>' "${WORKFLOW}"
check "skill keeps the parent out of review" has 'The parent does not review.' "${WORKFLOW}"
check "skill synthesizes without new findings" \
  has 'Synthesize without discovering new findings.' "${WORKFLOW}"
check "skill asks which findings to post" \
  has 'Reply "post all", "post findings", "post 1,3", or "post none".' "${ORCHESTRATOR}"
check "skill passes model attribution" \
  has '"selectedModels": ["<exact slug>", "<exact slug>"]' "${WORKFLOW}"
check "skill verifies PR input before posting" \
  has 'prepare-pr-review-input.mjs verify' "${WORKFLOW}"
check "skill posts through validated script" has 'post-inline-pr-comments.mjs' "${WORKFLOW}"
check "skill lets the user exclude review questions" \
  has '`post findings` excludes' "${ORCHESTRATOR}"
check "skill keeps coverage notes in chat" has 'unnumbered in chat.' "${ORCHESTRATOR}"
check "skill verifies before presenting" has '(workflow.md#verify-and-report)' "${ORCHESTRATOR}"
check "skill cleans review input" has 'cleanup-review-input.mjs' "${WORKFLOW}"

check "reviewer is read-only" has 'readonly: true' "${WORKER}"
check "reviewer uses review-pr heading format" \
  has '**[P1] - Q013 Invariant gap - confidence 90:**' "${WORKER}"
check "reviewer reports only confident findings" has 'confidence >= 75' "${WORKER}"
check "reviewer runs every lane" has 'Run Lane A, then B, then C' "${WORKER}"
check "reviewer applies the evidence gate" has 'evidence gate and falsification pass' "${WORKER}"
check "reviewer leaves structural rules to the parent" \
  has 'The parent owns structural results (S001 through S902).' "${WORKER}"
check "reviewer does not receive structural reports" lacks 'audit_structure.py' "${WORKER}"
check "reviewer anchors to changed lines" has 'RIGHT side, and full changed line from the anchor file or line map.' "${WORKER}"
check "reviewer comments are postable" has 'and body postable.' "${WORKER}"
check "reviewer checks every requirement" \
  has 'Return `No findings.` only after checking all requirements and resolving' "${WORKER}"
check "reviewer performs the audit directly" \
  has 'Do not invoke a review skill or delegate any part.' "${WORKER}"

check "reviewer headings match posting validator" \
  node --input-type=module -e "
import { readFileSync } from 'node:fs';
import { INLINE_COMMENT_HEADING } from '${SKILL_ROOT}/scripts/lib/review-automation.mjs';
const worker = readFileSync('${WORKER}', 'utf8');
const headings = worker.match(/^\*\*\[[^\]\n]+\] - .+:\*\*$/gm) ?? [];
if (headings.length < 2) process.exit(1);
for (const heading of headings) {
  if (!INLINE_COMMENT_HEADING.test(heading + '\n\nBody')) process.exit(1);
}
"

python3 "${RUNNER}" --profile pr --root "${INVALID_ROOT}" --change bad-change \
  --openspec-json "${INVALID_ROOT}/openspec.json" > "${temp_dir}/structure-invalid.json"
cat > "${temp_dir}/line-map.json" <<'JSON'
{"locations": [
  {"path": "openspec/changes/bad-change/specs/example/spec.md", "side": "RIGHT", "line": 9, "anchor": "### Requirement: Broken Behavior"},
  {"path": "openspec/changes/bad-change/specs/example/spec.md", "side": "RIGHT", "line": 2, "anchor": "## ADDED Requirements"}
]}
JSON
node "${SKILL_ROOT}/scripts/structural-findings.mjs" --line-map "${temp_dir}/line-map.json" \
  "${temp_dir}/structure-invalid.json" > "${temp_dir}/structural-pr.json"
node "${SKILL_ROOT}/scripts/structural-findings.mjs" \
  "${temp_dir}/structure-invalid.json" > "${temp_dir}/structural-local.json"
check "structural findings are postable and attributed to the validator" \
  node --input-type=module - "${temp_dir}/structural-pr.json" "${temp_dir}/structural-local.json" <<EOF
import { readFileSync } from 'node:fs';
import { INLINE_COMMENT_HEADING, findingDigest } from '${SKILL_ROOT}/scripts/lib/review-automation.mjs';
const [pr, local] = process.argv.slice(2).map((path) => JSON.parse(readFileSync(path, 'utf8')));
const byRule = Object.fromEntries(pr.findings.map((finding) => [finding.ruleId, finding]));
const fail = (message) => { console.error(message); process.exit(1); };
const missingLink = local.findings.find((finding) => finding.ruleId === 'S010');
if (!missingLink?.evidencePaths.includes('openspec/changes/bad-change/missing.md')) {
  fail('broken links must carry the target as evidence for context verification');
}
if (byRule.S004?.line !== 9) fail('S004 must anchor on its requirement heading');
if (byRule.S003?.line !== 2) fail('S003 must fall back to the first changed line');
if (byRule.S001?.path !== 'openspec/changes/bad-change/specs/example/spec.md' || !byRule.S001.line) {
  fail('OpenSpec errors must anchor on the repository path of the delta spec');
}
if (!pr.notes.some((note) => note.rule_id === 'S002' && note.kind === 'outside the patch')) {
  fail('results in unchanged files must become notes');
}
const severities = pr.findings.map((finding) => finding.severity);
if (severities.join() !== [...severities].sort().join()) fail('findings must be ordered by severity');
for (const finding of [...pr.findings, ...local.findings]) {
  if (finding.tool !== 'audit_structure.py' || finding.modelSlugs) fail('findings must name the validator');
  if (!finding.evidencePaths?.includes(finding.path)) fail('findings must carry their evidence paths');
  if (!INLINE_COMMENT_HEADING.test(finding.body)) fail('finding body must pass the posting validator');
  if (finding.id !== 'SA-' + finding.ruleId + '-' + findingDigest(finding.findingKey)) {
    fail('report IDs and posting digests must agree');
  }
}
if (local.findings.some((finding) => finding.anchor !== 'none')) fail('local findings have no anchor');
EOF

printf '{"files": ["openspec/changes/bad-change/specs/example/spec.md"]}\n' > "${temp_dir}/targets.json"
node "${SKILL_ROOT}/scripts/structural-findings.mjs" --manifest "${temp_dir}/targets.json" \
  "${temp_dir}/structure-invalid.json" > "${temp_dir}/structural-targets.json"
check "local structural findings stay within the audit targets" \
  node --input-type=module - "${temp_dir}/structural-targets.json" <<'EOF'
import { readFileSync } from 'node:fs';
const report = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const fail = (message) => { console.error(message); process.exit(1); };
for (const ruleId of ['S001', 'S004']) {
  if (!report.findings.some((finding) => finding.ruleId === ruleId)) fail(`${ruleId} target findings must remain`);
}
if (report.findings.some((finding) => finding.path !== 'openspec/changes/bad-change/specs/example/spec.md')) {
  fail('findings outside the targets must not be posted');
}
if (!report.notes.some((note) => note.rule_id === 'S002' && note.kind === 'outside the audit targets')) {
  fail('results outside the targets must become notes');
}
EOF
check "structural findings reject both a line map and a manifest" \
  bash -c "! node '${SKILL_ROOT}/scripts/structural-findings.mjs' --line-map '${temp_dir}/line-map.json' \
    --manifest '${temp_dir}/targets.json' '${temp_dir}/structure-invalid.json' > /dev/null 2>&1"
check "skill separates audit targets from context" has 'Use `contextFiles` as authority.' "${ORCHESTRATOR}"
check "large PRs bundle non-OpenSpec hunks as context" \
  has 'Put other hunks in a bundle named `context` for conformance' "${ORCHESTRATOR}"
check "default scope audits what differs from the base branch" \
  has 'prepare-local-spec-input.mjs changed' "${ORCHESTRATOR}"
check "local audits select one prepare command" \
  has 'For a local audit, run the command for the selected scope:' "${ORCHESTRATOR}"
check "PR preparation has its own scope" \
  has 'prepare-pr-review-input.mjs prepare "<PR>"' "${WORKFLOW}"
check "reviewer treats context main specs as authority only" \
  has 'Use `contextFiles`, context hunks, and unchanged main specs only' "${WORKER}"
check "conformance runs only for main spec targets" \
  has 'Run conformance only on named main spec' "${WORKER}"

local_repo="${temp_dir}/local-repo"
mkdir -p \
  "${local_repo}/openspec/changes/example-change/specs/example" \
  "${local_repo}/openspec/changes/archive/old-change" \
  "${local_repo}/openspec/specs/example"
(
  set -e
  cd "${local_repo}"
  git init --quiet
  git config user.email test@example.com
  git config user.name Test
  printf 'schema: spec-driven\n' > openspec/changes/example-change/.openspec.yaml
  printf '# Example\n' > openspec/changes/example-change/specs/example/spec.md
  printf '# Old\n' > openspec/changes/archive/old-change/proposal.md
  printf '# Main\n' > openspec/specs/example/spec.md
  mkdir -p openspec/specs/other
  printf '# Other\n' > openspec/specs/other/spec.md
  git add openspec
  git commit --quiet -m initial
  git branch -M main
  node "${LOCAL_PREPARE}" all > "${temp_dir}/local-all.out"
  node "${LOCAL_PREPARE}" change example-change > "${temp_dir}/local-change.out"
  # errexit ignores negated commands.
  ! node "${LOCAL_PREPARE}" change missing-change > /dev/null 2>&1 || exit 1
  ! node "${LOCAL_PREPARE}" changed --base main > /dev/null 2> "${temp_dir}/local-unchanged.err" || exit 1
  ! node "${LOCAL_PREPARE}" changed --base > /dev/null 2>&1 || exit 1
  git switch --quiet -c feature
  mkdir -p openspec/changes/new-change/specs/example
  printf '# New\n' > openspec/changes/new-change/specs/example/spec.md
  node "${LOCAL_PREPARE}" changed --base main > "${temp_dir}/local-changed.out"
  printf '# Other edited\n' > openspec/specs/other/spec.md
  node "${LOCAL_PREPARE}" changed --base main > "${temp_dir}/local-changed-spec.out"
) || fail=1

local_value() {
  awk -F= -v key="$1" '$1 == key { print $2 }' "$2"
}

all_manifest="$(local_value manifest "${temp_dir}/local-all.out")"
change_manifest="$(local_value manifest "${temp_dir}/local-change.out")"
check "local all scope includes active changes and main specs" \
  bash -c "grep -Fq 'openspec/changes/example-change/specs/example/spec.md' '${all_manifest}' && grep -Fq 'openspec/specs/example/spec.md' '${all_manifest}'"
check "local all scope skips archived changes" lacks 'openspec/changes/archive' "${all_manifest}"
manifest_value() {
  node -e "const value = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))[process.argv[2]]; console.log(JSON.stringify(value))" "$1" "$2"
}
check "local change scope excludes main specs from its targets" \
  test "$(manifest_value "${change_manifest}" files)" = \
    '["openspec/changes/example-change/.openspec.yaml","openspec/changes/example-change/specs/example/spec.md"]'
check "local input reports a digest" \
  test -n "$(local_value inputDigest "${temp_dir}/local-change.out")"
changed_manifest="$(local_value manifest "${temp_dir}/local-changed.out")"
changed_spec_manifest="$(local_value manifest "${temp_dir}/local-changed-spec.out")"
check "default scope reports when nothing differs from the base" \
  has 'No active change or main spec differs from main.' "${temp_dir}/local-unchanged.err"
check "default scope targets only changes that differ from the base" \
  test "$(manifest_value "${changed_manifest}" changes)" = '["new-change"]'
check "default scope has no main spec targets without a direct edit" \
  test "$(manifest_value "${changed_manifest}" domains)" = '[]'
check "default scope reads touched main specs as context" \
  test "$(manifest_value "${changed_manifest}" contextFiles)" = '["openspec/specs/example/spec.md"]'
check "a directly edited main spec becomes a target" \
  test "$(manifest_value "${changed_spec_manifest}" domains)" = '["other"]'
check "context digest changes the input digest" \
  test "$(local_value inputDigest "${temp_dir}/local-changed.out")" != \
    "$(local_value inputDigest "${temp_dir}/local-changed-spec.out")"
check "all scope targets main specs instead of reading them as context" \
  test "$(manifest_value "${all_manifest}" contextFiles)" = '[]'
check "change scope reads touched main specs as context" \
  test "$(manifest_value "${change_manifest}" contextFiles)" = '["openspec/specs/example/spec.md"]'
for output in local-all.out local-change.out local-changed.out local-changed-spec.out; do
  directory="$(local_value directory "${temp_dir}/${output}")"
  check "cleanup removes ${output} directory" \
    bash -c "node '${CLEANUP}' '${directory}' > /dev/null && test ! -e '${directory}'"
done

check "shared profiles preserve reports and coverage exit statuses" \
  python3 "${SKILL_ROOT}/tests/test-structure-profiles.py"

exit "${fail}"
