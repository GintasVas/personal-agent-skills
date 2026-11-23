#!/usr/bin/env bash
set -uo pipefail

SKILL_ROOT="$1"
AUDIT_PROFILE="$2"
LINK_SEVERITY="$3"
SEMANTIC_FIELD="$4"
SEMANTIC_VALUES="$5"
LANE_SPLIT="$6"
RUNNER="${SKILL_ROOT}/scripts/audit_structure.py"
VALID_ROOT="${SKILL_ROOT}/tests/fixtures/valid"
INVALID_ROOT="${SKILL_ROOT}/tests/fixtures/invalid"
HISTORY="${SKILL_ROOT}/tests/fixtures/finding-history.json"
SEMANTIC_CASES="${SKILL_ROOT}/tests/fixtures/semantic-cases.json"
LANES="${SKILL_ROOT}/LANES.md"
CHECKLIST="${SKILL_ROOT}/CHECKLIST.md"

temp_dir="$(mktemp -d)"
trap 'rm -rf "${temp_dir}"' EXIT
cp -RL "${SKILL_ROOT}/tests/fixtures" "${temp_dir}/fixtures"
VALID_ROOT="${temp_dir}/fixtures/valid"
INVALID_ROOT="${temp_dir}/fixtures/invalid"

fail=0

check() {
  local description="$1"
  shift
  if "$@"; then
    printf 'PASS: %s\n' "${description}"
  else
    printf 'FAIL: %s\n' "${description}" >&2
    fail=1
  fi
}

run_valid() {
  local output="$1"
  python3 "${RUNNER}" --profile "${AUDIT_PROFILE}" --house-style \
    --root "${VALID_ROOT}" \
    --change example-change \
    --openspec-json "${VALID_ROOT}/openspec.json" >"${output}"
}

run_invalid() {
  local output="$1"
  python3 "${RUNNER}" --profile "${AUDIT_PROFILE}" --house-style \
    --root "${INVALID_ROOT}" \
    --change bad-change \
    --openspec-json "${INVALID_ROOT}/openspec.json" >"${output}"
  [[ "$?" -eq 1 ]]
}

check "first valid fixture run succeeds" run_valid "${temp_dir}/valid-one.json"
check "second valid fixture run succeeds" run_valid "${temp_dir}/valid-two.json"
check "repeated output is byte-identical" \
  diff -u "${temp_dir}/valid-one.json" "${temp_dir}/valid-two.json"
check "valid output matches golden JSON" \
  python3 - "${VALID_ROOT}/expected.json" "${temp_dir}/valid-one.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as expected_file:
    expected = json.load(expected_file)
with open(sys.argv[2], encoding="utf-8") as actual_file:
    actual = json.load(actual_file)
if actual != expected:
    raise SystemExit("valid output differs from golden JSON")
PY
check "invalid fixture reports verified failures" run_invalid "${temp_dir}/invalid.json"

check "invalid fixture covers expected structural rules" \
  python3 - "${temp_dir}/invalid.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as input_file:
    report = json.load(input_file)

actual = {
    item["rule_id"]
    for item in report["results"]
    if item["verdict"] == "VERIFIED"
}
expected = {"S001", "S002", "S003", "S004", "S006", "S007", "S008", "S010"}
missing = expected - actual
if missing:
    raise SystemExit(f"missing rules: {sorted(missing)}")
PY

check "broken local links are ${LINK_SEVERITY} hygiene" \
  python3 - "${temp_dir}/invalid.json" "${LINK_SEVERITY}" "${AUDIT_PROFILE}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as input_file:
    report = json.load(input_file)

links = [item for item in report["results"] if item["rule_id"] == "S010"]
if not links or any(item.get("severity") != sys.argv[2] for item in links):
    raise SystemExit(f"S010 must be reported as {sys.argv[2]}")
if sys.argv[3] == "pr":
    severities = {item.get("severity") for item in report["results"] if item["verdict"] == "VERIFIED"}
    if not severities <= {"P0", "P1", "P2"}:
        raise SystemExit(f"structural severities must be P0-P2: {sorted(severities)}")
PY

check "finding history fingerprints distinguish root causes" \
  python3 - "${RUNNER}" "${HISTORY}" "${AUDIT_PROFILE}" <<'PY'
import importlib.util
import json
import sys

module_path, history_path, profile_name = sys.argv[1:]
spec = importlib.util.spec_from_file_location("audit_structure", module_path)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
profile = module.configure_profile(profile_name)

with open(history_path, encoding="utf-8") as input_file:
    history = json.load(input_file)

records = history["resolved"] + history["introduced"]
identifiers = {
    module.finding_id(
        profile,
        item["rule_id"],
        item["path"],
        item["requirement"],
    )
    for item in records
}
if len(identifiers) != len(records):
    raise SystemExit("history records collided")

vacuous = history["resolved"][0]
leakage = history["introduced"][0]
if vacuous["requirement"] != leakage["requirement"]:
    raise SystemExit("fixture no longer compares the same requirement")
PY

check "semantic fixtures use evidence outcomes" \
  python3 - "${SEMANTIC_CASES}" "${LANES}" "${CHECKLIST}" \
    "${SEMANTIC_FIELD}" "${SEMANTIC_VALUES}" "${LANE_SPLIT}" <<'PY'
import json
import re
import sys

semantic_path, lanes_path, checklist_path, field, values, lane_split = sys.argv[1:]

with open(semantic_path, encoding="utf-8") as input_file:
    cases = json.load(input_file)["cases"]

verdict_cases = [item for item in cases if field in item]
expected = set(values.split())
actual = {item[field] for item in verdict_cases}
if actual != expected:
    raise SystemExit(f"unexpected verdict coverage: {sorted(actual)}")
if any(not item["authoritative_evidence"] for item in cases):
    raise SystemExit("semantic fixture lacks authoritative evidence")
excluded = [item for item in cases if item.get("expected_action") == "EXCLUDE"]
if not excluded or any(field in item for item in excluded):
    raise SystemExit("explicit non-goals must be excluded without a verdict")
if not any(item["rule_id"] == "Q013" for item in verdict_cases):
    raise SystemExit("semantic fixtures lack invariant-gap coverage")
actual_rules = {item["rule_id"] for item in verdict_cases}

with open(checklist_path, encoding="utf-8") as input_file:
    expected_quality = set(
        re.findall(r"^\| (Q\d{3}) ", input_file.read(), flags=re.MULTILINE)
    )
if not expected_quality:
    raise SystemExit("checklist defines no quality rules")
unknown_fixture_rules = {
    rule
    for rule in actual_rules
    if rule.startswith("Q") and rule not in expected_quality
}
if unknown_fixture_rules:
    raise SystemExit(
        f"semantic fixtures reference unknown quality rules: {sorted(unknown_fixture_rules)}"
    )

with open(lanes_path, encoding="utf-8") as input_file:
    lane_rules_text = input_file.read().split(lane_split, maxsplit=1)[0]
lane_ids = re.findall(r"^## Lane ([A-Z]):", lane_rules_text, flags=re.MULTILINE)
if lane_ids != ["A", "B", "C"]:
    raise SystemExit(f"expected exactly lanes A, B, C; got {lane_ids}")
assigned = re.findall(r"`(Q\d{3})`", lane_rules_text)
if set(assigned) != expected_quality:
    missing = expected_quality - set(assigned)
    extra = set(assigned) - expected_quality
    raise SystemExit(
        f"lane quality-rule coverage mismatch: missing={sorted(missing)} extra={sorted(extra)}"
    )
duplicates = sorted({rule for rule in assigned if assigned.count(rule) > 1})
if duplicates:
    raise SystemExit(f"quality rules assigned to multiple lanes: {duplicates}")
PY
