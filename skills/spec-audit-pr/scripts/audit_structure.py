#!/usr/bin/env python3
"""Deterministic structural audit for OpenSpec artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable, NamedTuple

OPENSPEC_PACKAGE = "@fission-ai/openspec@1.6.0"
DELTA_HEADERS = {
    "## ADDED Requirements",
    "## MODIFIED Requirements",
    "## REMOVED Requirements",
    "## RENAMED Requirements",
}
STEP_KEYWORDS = {"GIVEN", "WHEN", "THEN", "AND"}
RULE_PRIORITY = {
    "S001": 0,
    "S002": 0,
    "S003": 0,
    "S004": 0,
    "S005": 1,
    "S006": 1,
    "S007": 1,
    "S008": 2,
    "S009": 1,
    "S010": 2,
    "S011": 1,
    "S012": 2,
    "S013": 2,
}
SUPPRESSIONS = {
    "must contain SHALL or MUST": "S900",
    "must include at least one scenario": "S901",
    "Spec must have a Purpose section": "S902",
}


def normalize(value: str) -> str:
    return " ".join(value.strip().split()).lower()


def local_fingerprint(rule_id: str, path: str, requirement: str) -> str:
    return f"{rule_id}:{normalize(path)}:{normalize(requirement)}"


def pr_fingerprint(rule_id: str, path: str, requirement: str) -> str:
    return normalize(f"{rule_id}:{path}:{requirement}")


class AuditProfile(NamedTuple):
    severities: tuple[str, str, str]
    verdicts: tuple[str, ...]
    fingerprint: Callable[[str, str, str], str]
    change_anchor: Callable[[Path, Path], str]
    issue_path: Callable[[Path, str, str, str], str]
    naming_errors: Callable[[list[str], list[str]], dict[str, list[str]]]


def configure_profile(profile: str) -> AuditProfile:
    if profile == "local":
        return AuditProfile(
            ("Blocker", "Major", "Minor"),
            ("VERIFIED", "REVIEW_QUESTION", "NOT_VERIFIED", "ACCEPTED_EXCEPTION"),
            local_fingerprint,
            relative,
            local_issue_path,
            local_naming_errors,
        )
    if profile == "pr":
        return AuditProfile(
            ("P0", "P1", "P2"),
            ("VERIFIED", "NOT_VERIFIED", "ACCEPTED_EXCEPTION"),
            pr_fingerprint,
            pr_change_anchor,
            pr_issue_path,
            pr_naming_errors,
        )
    raise ValueError(f"Unknown structural audit profile: {profile}")


def finding_id(profile: AuditProfile, rule_id: str, path: str, requirement: str) -> str:
    fingerprint = profile.fingerprint(rule_id, path, requirement)
    digest = hashlib.sha256(fingerprint.encode("utf-8")).hexdigest()[:12]
    return f"SA-{rule_id}-{digest}"


def record(
    profile: AuditProfile,
    rule_id: str,
    verdict: str,
    path: str,
    requirement: str,
    message: str,
    evidence: list[str],
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "evidence": evidence,
        "id": finding_id(profile, rule_id, path, requirement),
        "message": message,
        "path": path,
        "requirement": requirement,
        "rule_id": rule_id,
        "verdict": verdict,
    }
    if verdict == "VERIFIED":
        result["severity"] = profile.severities[RULE_PRIORITY[rule_id]]
    return result


def run(command: list[str], root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )


def relative(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def pr_change_anchor(change_directory: Path, root: Path) -> str:
    proposal = change_directory / "proposal.md"
    if proposal.is_file():
        return relative(proposal, root)
    existing = sorted(path for path in change_directory.rglob("*") if path.is_file())
    return relative(existing[0] if existing else change_directory, root)


def local_issue_path(root: Path, item_type: str, item_id: str, issue_path: str) -> str:
    return f"{item_type}/{item_id}/{issue_path}"


def pr_issue_path(root: Path, item_type: str, item_id: str, issue_path: str) -> str:
    if item_type == "spec":
        return f"openspec/specs/{item_id}/spec.md"
    change_directory = root / "openspec" / "changes" / item_id
    if issue_path == "file":
        return pr_change_anchor(change_directory, root)
    return f"openspec/changes/{item_id}/specs/{issue_path}"


def local_naming_errors(paths: list[str], errors: list[str]) -> dict[str, list[str]]:
    return {"audited manifest": errors}


def pr_naming_errors(paths: list[str], errors: list[str]) -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = {}
    for line in errors:
        path = next(
            (path for path in paths if f"'{path}'" in line or f" {path} " in line),
            "audited manifest",
        )
        grouped.setdefault(path, []).append(line)
    return grouped or {"audited manifest": []}


def git_snapshot(root: Path) -> dict[str, Any]:
    branch = run(["git", "branch", "--show-current"], root).stdout.strip()
    commit = run(["git", "rev-parse", "HEAD"], root).stdout.strip()
    dirty = bool(run(["git", "status", "--porcelain"], root).stdout.strip())
    return {"branch": branch, "commit": commit, "dirty": dirty}


def active_change_directories(root: Path) -> list[Path]:
    changes_root = root / "openspec" / "changes"
    if not changes_root.is_dir():
        return []
    return sorted(
        path
        for path in changes_root.iterdir()
        if path.is_dir() and path.name != "archive"
    )


def target_files(root: Path, change: str | None) -> tuple[list[Path], list[Path]]:
    if change:
        change_root = root / "openspec" / "changes" / change
        return (
            sorted(path for path in change_root.rglob("*") if path.is_file()),
            [change_root],
        )

    change_directories = active_change_directories(root)
    files: set[Path] = set()
    for change_directory in change_directories:
        files.update(path for path in change_directory.rglob("*") if path.is_file())
    specs_root = root / "openspec" / "specs"
    if specs_root.is_dir():
        files.update(specs_root.glob("*/spec.md"))
    return sorted(files), change_directories


def add_coverage(
    coverage: list[dict[str, str]],
    check: str,
    status: str,
    detail: str = "",
) -> None:
    coverage.append({"check": check, "detail": detail, "status": status})


def check_change_structure(
    profile: AuditProfile,
    change_directory: Path,
    root: Path,
    findings: list[dict[str, Any]],
    supported_schemas: tuple[str, ...] = ("spec-driven",),
    house_style: bool = False,
) -> None:
    change_path = relative(change_directory, root)
    config = change_directory / ".openspec.yaml"
    if not config.is_file():
        findings.append(
            record(profile,
                "S002",
                "VERIFIED",
                profile.change_anchor(change_directory, root),
                "change configuration",
                "Active change is missing .openspec.yaml.",
                [f"{change_path}/.openspec.yaml does not exist"],
            )
        )
    elif not re.search(
        rf"(?m)^schema:\s*(?:{'|'.join(map(re.escape, supported_schemas))})\s*$",
        config.read_text(),
    ):
        findings.append(
            record(profile,
                "S002",
                "VERIFIED",
                relative(config, root),
                "change configuration",
                "Change does not declare a supported schema.",
                [
                    "Expected "
                    + " or ".join(f"schema: {name}" for name in supported_schemas)
                ],
            )
        )

    proposal = change_directory / "proposal.md"
    spec_root = change_directory / "specs"
    capabilities = (
        sorted(path.name for path in spec_root.iterdir() if path.is_dir())
        if spec_root.is_dir()
        else []
    )
    if proposal.is_file():
        proposal_text = proposal.read_text()
        capability_section = re.search(
            r"(?ms)^## Capabilities\s*$([\s\S]*?)(?=^## |\Z)",
            proposal_text,
        )
        named_capabilities: list[str] = []
        if capability_section:
            named_capabilities = sorted(
                set(
                    re.findall(
                        r"(?m)^-\s+`([^`]+)`\s*:",
                        capability_section.group(1),
                    )
                )
            )
            for subsection in re.finditer(
                r"(?ms)^### (New|Modified|Removed) Capabilities\s*$"
                r"([\s\S]*?)(?=^### |^## |\Z)",
                capability_section.group(1),
            ):
                body = subsection.group(2).strip()
                if house_style and (not body or ("- " not in body and "(none)" not in body.lower())):
                    findings.append(
                        record(profile,
                            "S008",
                            "VERIFIED",
                            relative(proposal, root),
                            f"{subsection.group(1)} Capabilities",
                            "Empty capability subsection must state (none).",
                            [body or "<empty>"],
                        )
                    )
        if (capability_section or house_style) and named_capabilities != capabilities:
            findings.append(
                record(profile,
                    "S007",
                    "VERIFIED",
                    relative(proposal, root),
                    "Capabilities",
                    "Proposal capability names do not match delta spec folders.",
                    [
                        f"proposal={named_capabilities}",
                        f"spec_folders={capabilities}",
                    ],
                )
            )

    source = change_directory / "source.md"
    if house_style and source.is_file():
        source_text = source.read_text()
        prompt = re.search(
            r"(?ms)^## Initial Prompt\s*$([\s\S]*?)(?=^## |\Z)",
            source_text,
        )
        required = [
            ("# Source", re.search(r"(?m)^# Source\s*$", source_text)),
            ("## Initial Prompt", prompt),
            (
                "## Reference Documents",
                re.search(r"(?m)^## Reference Documents\s*$", source_text),
            ),
        ]
        missing = [heading for heading, match in required if not match]
        if prompt and not prompt.group(1).strip():
            missing.append("non-empty Initial Prompt")
        if missing:
            findings.append(
                record(profile,
                    "S009",
                    "VERIFIED",
                    relative(source, root),
                    "source structure",
                    "source.md is missing required content.",
                    missing,
                )
            )


def requirement_blocks(text: str) -> list[tuple[str, str, str]]:
    matches = list(re.finditer(r"(?m)^### Requirement:\s*(.+?)\s*$", text))
    blocks: list[tuple[str, str, str]] = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        prefix = text[: match.start()]
        delta_headers = [
            header
            for header in DELTA_HEADERS
            if prefix.rfind(header) >= 0
        ]
        current_header = ""
        if delta_headers:
            current_header = max(delta_headers, key=prefix.rfind)
        blocks.append((match.group(1).strip(), text[match.end() : end], current_header))
    return blocks


def check_spec_structure(
    profile: AuditProfile,
    spec: Path,
    root: Path,
    findings: list[dict[str, Any]],
    house_style: bool,
) -> None:
    text = spec.read_text()
    path = relative(spec, root)
    is_delta = "/openspec/changes/" in f"/{path}"
    if is_delta:
        present_headers = {
            line.strip()
            for line in text.splitlines()
            if line.startswith("## ") and line.endswith(" Requirements")
        }
        if not present_headers or not present_headers.issubset(DELTA_HEADERS):
            findings.append(
                record(profile,
                    "S003",
                    "VERIFIED",
                    path,
                    "delta markers",
                    "Delta spec has missing or unsupported requirement markers.",
                    [f"headers={sorted(present_headers)}"],
                )
            )

    for requirement, body, delta_header in requirement_blocks(text):
        scenarios = list(
            re.finditer(r"(?m)^#### Scenario:\s*(.+?)\s*$", body)
        )
        plain_sections = list(
            re.finditer(r"(?m)^#### (?!Scenario:)(.+?)\s*$", body)
        )
        has_table = bool(re.search(r"(?m)^\|.+\|\s*$", body))
        is_removal_or_rename = delta_header in {
            "## REMOVED Requirements",
            "## RENAMED Requirements",
        }
        requires_scenario = house_style or not is_removal_or_rename
        allows_table = house_style and plain_sections and has_table
        if requires_scenario and not scenarios and not allows_table:
            findings.append(
                record(profile,
                    "S004",
                    "VERIFIED",
                    path,
                    requirement,
                    "Requirement has no scenario or reference-data table section."
                    if house_style else "Requirement has no scenario.",
                    [f"### Requirement: {requirement}"],
                )
            )

        for index, scenario in enumerate(scenarios):
            scenario_end = (
                scenarios[index + 1].start()
                if index + 1 < len(scenarios)
                else len(body)
            )
            scenario_body = body[scenario.end() : scenario_end]
            for step in re.finditer(r"(?m)^-\s+\*\*([A-Z]+)\*\*", scenario_body):
                if step.group(1) not in STEP_KEYWORDS:
                    findings.append(
                        record(profile,
                            "S005",
                            "VERIFIED",
                            path,
                            requirement,
                            "Scenario uses an unrecognized step keyword.",
                            [
                                f"Scenario: {scenario.group(1).strip()}",
                                step.group(0),
                            ],
                        )
                    )

        if house_style and is_removal_or_rename and not re.search(r"(?m)^\*\*Reason\*\*:", body):
            findings.append(
                record(profile,
                    "S006",
                    "VERIFIED",
                    path,
                    requirement,
                    "Removed or renamed requirement is missing **Reason**:.",
                    [delta_header],
                )
            )


def check_links(
    profile: AuditProfile,
    file_path: Path,
    root: Path,
    findings: list[dict[str, Any]],
) -> None:
    if file_path.suffix.lower() not in {".md", ".markdown"}:
        return
    text = file_path.read_text()
    for match in re.finditer(r"(?<!!)\[[^\]]+\]\(([^)]+)\)", text):
        raw_target = match.group(1).strip().split()[0].strip("<>")
        if (
            not raw_target
            or raw_target.startswith(("#", "http://", "https://", "mailto:"))
        ):
            continue
        target_without_anchor = raw_target.split("#", 1)[0]
        if not target_without_anchor:
            continue
        if target_without_anchor.startswith("/"):
            target = root / target_without_anchor.lstrip("/")
        else:
            target = file_path.parent / target_without_anchor
        if not target.exists():
            findings.append(
                record(profile,
                    "S010",
                    "VERIFIED",
                    relative(file_path, root),
                    "local link",
                    "Local Markdown link target does not exist.",
                    [raw_target],
                )
            )


def check_ascii(
    profile: AuditProfile,
    files: list[Path],
    root: Path,
    findings: list[dict[str, Any]],
) -> None:
    for file_path in files:
        if file_path.suffix.lower() not in {
            ".md",
            ".markdown",
            ".yaml",
            ".yml",
            ".json",
            ".mmd",
        }:
            continue
        try:
            file_path.read_bytes().decode("ascii")
        except UnicodeDecodeError:
            findings.append(
                record(profile,
                    "S012",
                    "VERIFIED",
                    relative(file_path, root),
                    "ASCII text",
                    "Audited text contains non-ASCII characters.",
                    ["ASCII decoding failed"],
                )
            )


def check_naming(
    profile: AuditProfile,
    files: list[Path],
    root: Path,
    findings: list[dict[str, Any]],
    coverage: list[dict[str, str]],
    validator: Path | None,
) -> None:
    if validator is None:
        add_coverage(coverage, "repository naming", "NOT_APPLICABLE")
        return
    if not validator.is_file():
        add_coverage(coverage, "repository naming", "NOT_VERIFIED", str(validator))
        return
    paths = [relative(path, root) for path in files]
    result = run(["bash", str(validator), *paths], root)
    if result.returncode == 0:
        add_coverage(coverage, "repository naming", "COMPLETE")
        return
    errors = [line for line in result.stderr.splitlines() if line.startswith("ERROR:")]
    for path, path_errors in profile.naming_errors(paths, errors).items():
        findings.append(
            record(profile,
                "S013",
                "VERIFIED",
                path,
                "repository naming",
                "Repository naming validator failed.",
                path_errors,
            )
        )
    add_coverage(coverage, "repository naming", "COMPLETE")


def parse_json_output(stdout: str) -> dict[str, Any]:
    start = stdout.find("{")
    if start < 0:
        raise ValueError("OpenSpec produced no JSON object")
    return json.loads(stdout[start:])


def run_openspec(
    profile: AuditProfile,
    root: Path,
    change: str | None,
    supplied_json: Path | None,
    findings: list[dict[str, Any]],
    exceptions: list[dict[str, Any]],
    coverage: list[dict[str, str]],
    house_style: bool,
) -> None:
    if supplied_json:
        try:
            payload = json.loads(supplied_json.read_text())
        except (OSError, json.JSONDecodeError) as error:
            add_coverage(coverage, "OpenSpec CLI", "NOT_VERIFIED", str(error))
            return
    else:
        target = (
            ["validate", change, "--type", "change", "--json"]
            if change
            else ["validate", "--all", "--json"]
        )
        result = run(
            ["npx", "--yes", OPENSPEC_PACKAGE, *target],
            root,
        )
        try:
            payload = parse_json_output(result.stdout)
        except (ValueError, json.JSONDecodeError) as error:
            detail = result.stderr.strip() or str(error)
            add_coverage(coverage, "OpenSpec CLI", "NOT_VERIFIED", detail)
            return

    for item in payload.get("items", []):
        item_id = str(item.get("id", "unknown"))
        item_type = str(item.get("type", "artifact"))
        for issue in item.get("issues", []):
            if issue.get("level") != "ERROR":
                continue
            message = str(issue.get("message", "Unknown OpenSpec error"))
            path = profile.issue_path(
                root, item_type, item_id, str(issue.get("path", "file"))
            )
            suppression_rule = next(
                (
                    rule_id
                    for fragment, rule_id in SUPPRESSIONS.items()
                    if fragment in message
                ),
                None,
            )
            if house_style and suppression_rule:
                exceptions.append(
                    record(profile,
                        suppression_rule,
                        "ACCEPTED_EXCEPTION",
                        path,
                        item_id,
                        message,
                        ["Repository house-style suppression"],
                    )
                )
            else:
                findings.append(
                    record(profile,
                        "S001",
                        "VERIFIED",
                        path,
                        item_id,
                        message,
                        ["Pinned OpenSpec 1.6.0 ERROR"],
                    )
                )
    add_coverage(coverage, "OpenSpec CLI", "COMPLETE", OPENSPEC_PACKAGE)


def sort_records(profile: AuditProfile, records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    unique = {item["id"]: item for item in records}
    severity_order = {label: index for index, label in enumerate(profile.severities)}
    verdict_order = {verdict: index for index, verdict in enumerate(profile.verdicts)}
    return sorted(
        unique.values(),
        key=lambda item: (
            verdict_order[item["verdict"]],
            severity_order.get(item.get("severity", ""), 99),
            item["rule_id"],
            item["path"],
            item["requirement"],
        ),
    )


def build_report(arguments: argparse.Namespace) -> dict[str, Any]:
    profile = configure_profile(arguments.profile)
    root = Path(arguments.root).resolve()
    files, change_directories = target_files(root, arguments.change)
    findings: list[dict[str, Any]] = []
    exceptions: list[dict[str, Any]] = []
    coverage: list[dict[str, str]] = []

    if arguments.change and not change_directories[0].is_dir():
        findings.append(
            record(profile,
                "S011",
                "VERIFIED",
                f"openspec/changes/{arguments.change}",
                "target change",
                "Requested change directory does not exist.",
                [arguments.change],
            )
        )
        change_directories = []

    for change_directory in change_directories:
        check_change_structure(
            profile, change_directory, root, findings,
            ("spec-driven", *arguments.schema), arguments.house_style,
        )
        if not (change_directory / ".openspec.yaml").is_file():
            path = profile.change_anchor(change_directory, root)
            if not any(
                item["rule_id"] == "S002" and item["path"] == path
                for item in findings
            ):
                findings.append(
                    record(profile,
                        "S011",
                        "VERIFIED",
                        path,
                        "active change inventory",
                        "Active change directory is not registered.",
                        ["Missing .openspec.yaml"],
                    )
                )

    for file_path in files:
        if file_path.name == "spec.md":
            check_spec_structure(profile, file_path, root, findings, arguments.house_style)
        check_links(profile, file_path, root, findings)
    if arguments.house_style:
        check_ascii(profile, files, root, findings)
        add_coverage(coverage, "ASCII", "COMPLETE")
    check_naming(profile, files, root, findings, coverage, arguments.naming_validator)

    supplied_json = (
        Path(arguments.openspec_json).resolve()
        if arguments.openspec_json
        else None
    )
    run_openspec(
        profile,
        root,
        arguments.change,
        supplied_json,
        findings,
        exceptions,
        coverage,
        arguments.house_style,
    )

    findings = sort_records(profile, findings)
    exceptions = sort_records(profile, exceptions)
    coverage = sorted(coverage, key=lambda item: item["check"])
    coverage_status = (
        "PARTIAL"
        if any(item["status"] == "NOT_VERIFIED" for item in coverage)
        else "COMPLETE"
    )
    snapshot = git_snapshot(root) if (root / ".git").exists() else {
        "branch": "",
        "commit": "",
        "dirty": False,
    }
    return {
        "coverage": {"checks": coverage, "status": coverage_status},
        "manifest": [relative(path, root) for path in files],
        "openspec_package": OPENSPEC_PACKAGE,
        "results": findings + exceptions,
        "scope": {
            "change": arguments.change,
            "mode": "change" if arguments.change else "all",
        },
        "snapshot": snapshot,
        "summary": {
            "accepted_exceptions": len(exceptions),
            "verified": len(findings),
        },
    }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=("local", "pr"), default="local")
    parser.add_argument("--root", default=".")
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--all", action="store_true")
    scope.add_argument("--change")
    parser.add_argument("--schema", action="append", default=[], help="Also allow this schema name.")
    parser.add_argument("--house-style", action="store_true", help="Enable the optional house-style rules.")
    parser.add_argument(
        "--naming-validator",
        type=lambda path: Path(path).resolve(),
        help="Run an explicitly selected trusted shell validator against audited paths.",
    )
    parser.add_argument(
        "--openspec-json",
        help="Use captured OpenSpec JSON instead of invoking npx.",
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    report = build_report(arguments)
    json.dump(report, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    if report["summary"]["verified"]:
        return 1
    if report["coverage"]["status"] == "PARTIAL":
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
