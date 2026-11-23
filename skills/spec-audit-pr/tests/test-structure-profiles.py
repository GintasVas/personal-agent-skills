import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


TEST_ROOT = Path(__file__).parent
RUNNER = TEST_ROOT.parent / "scripts/audit_structure.py"


class StructuralProfileTests(unittest.TestCase):
    def test_profiles_remain_independent_when_helpers_are_interleaved(self):
        spec = importlib.util.spec_from_file_location("audit_structure", RUNNER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        local = module.configure_profile("local")
        pr = module.configure_profile("pr")
        for profile, label, expected_file in (
            (local, "Blocker", "expected-local.txt"),
            (pr, "P0", "expected-pr.txt"),
            (local, "Blocker", "expected-local.txt"),
        ):
            result = module.record(profile, "S001", "VERIFIED", "spec.md", "Example", "Error", [])
            self.assertEqual(result["severity"], label)
            expected = json.loads((TEST_ROOT / "fixtures/profiles" / expected_file).read_text())
            for item in expected["results"]:
                self.assertEqual(
                    module.finding_id(profile, item["rule_id"], item["path"], item["requirement"]),
                    item["id"],
                )
        with self.assertRaises(AttributeError):
            local.severities = ("P0", "P1", "P2")

    def run_profile(self, root, profile=None, openspec_json=None, options=()):
        command = [sys.executable, str(RUNNER)]
        if profile:
            command.extend(["--profile", profile])
        command.extend([
            "--root", str(root), "--change", "example-change",
            "--openspec-json", str(openspec_json or root / "openspec.json"),
        ])
        return subprocess.run([*command, *options], capture_output=True, check=False)

    def test_profiles_preserve_original_report_bytes_and_failure_status(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "fixture"
            shutil.copytree(TEST_ROOT / "fixtures/profiles", root)
            (root / "scripts/validate-naming.sh").rename(root / "scripts/validate_naming.sh")
            change = root / "openspec/changes/example-change"
            (change / "bad_name.md").rename(change / "Bad-Name.md")
            (change / "other_bad.md").rename(change / "Other-Bad.md")
            options = ("--house-style", "--naming-validator", str(root / "scripts/validate_naming.sh"))
            for profile in ("local", "pr"):
                with self.subTest(profile=profile):
                    result = self.run_profile(root, profile, options=options)
                    self.assertEqual(result.returncode, 1, result.stderr.decode())
                    self.assertEqual(result.stderr, b"")
                    self.assertEqual(
                        result.stdout, (root / f"expected-{profile}.txt").read_bytes()
                    )
            default = self.run_profile(root, options=options)
            self.assertEqual(default.returncode, 1)
            self.assertEqual(default.stdout, (root / "expected-local.txt").read_bytes())

    def test_configured_schema_is_accepted_by_both_profiles(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "fixture"
            shutil.copytree(TEST_ROOT / "fixtures/valid", root)
            config = root / "openspec/changes/example-change/.openspec.yaml"
            config.write_text("schema: example-schema\n", encoding="utf-8")
            for profile in ("local", "pr"):
                with self.subTest(profile=profile):
                    result = self.run_profile(root, profile, options=("--schema", "example-schema", "--house-style"))
                    self.assertEqual(result.returncode, 0, result.stdout.decode())
                    report = json.loads(result.stdout)
                    self.assertEqual(report["summary"]["verified"], 0)

    def test_default_audit_skips_repository_specific_checks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "fixture"
            shutil.copytree(TEST_ROOT / "fixtures/valid", root)
            scripts = root / "scripts"
            scripts.mkdir()
            (scripts / "validate_naming.sh").write_text("touch naming-ran\n", encoding="utf-8")
            change = root / "openspec/changes/example-change"
            (change / "source.md").write_text("# Résumé\n", encoding="utf-8")
            (change / "proposal.md").write_text("# Proposal\n", encoding="utf-8")
            (root / "openspec.json").write_text('{"items": []}\n', encoding="utf-8")

            result = self.run_profile(root, "pr")
            self.assertEqual(result.returncode, 0, result.stdout.decode())
            self.assertFalse((root / "naming-ran").exists())
            self.assertEqual(json.loads(result.stdout)["results"], [])

    def test_unsupported_schema_is_rejected_by_both_profiles(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "fixture"
            shutil.copytree(TEST_ROOT / "fixtures/valid", root)
            config = root / "openspec/changes/example-change/.openspec.yaml"
            config.write_text("schema: unsupported\n", encoding="utf-8")
            for profile in ("local", "pr"):
                with self.subTest(profile=profile):
                    result = self.run_profile(root, profile, options=("--house-style",))
                    self.assertEqual(result.returncode, 1, result.stdout.decode())
                    report = json.loads(result.stdout)
                    failures = [item for item in report["results"] if item["verdict"] == "VERIFIED"]
                    self.assertEqual([item["rule_id"] for item in failures], ["S002"])

    def test_partial_coverage_keeps_exit_status_two_for_both_profiles(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "fixture"
            shutil.copytree(TEST_ROOT / "fixtures/valid", root)
            invalid_json = root / "broken-openspec.json"
            invalid_json.write_text("not JSON\n", encoding="utf-8")
            for profile in ("local", "pr"):
                with self.subTest(profile=profile):
                    result = self.run_profile(root, profile, invalid_json)
                    self.assertEqual(result.returncode, 2, result.stderr.decode())
                    report = json.loads(result.stdout)
                    self.assertEqual(report["coverage"]["status"], "PARTIAL")
                    self.assertEqual(report["summary"]["verified"], 0)


if __name__ == "__main__":
    unittest.main()
