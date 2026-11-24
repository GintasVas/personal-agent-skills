---
name: spec-audit-pr
description: Audit local or PR OpenSpec files for structure, behavior, traceability, and implementation drift. Post only on request.
argument-hint: '[<PR number|URL>|<change-slug>|<domain>|all] [--model <slug>]'
disable-model-invocation: true
---

# Spec audit

Run `/spec-audit-pr [<PR>|<change-slug>|<domain>|all] [--model <slug>]`.
In Pi, use `/skill:spec-audit-pr` with `[--model <cursor-slug|provider/id[:thinking]>]`.
Edit or post only on explicit request after showing findings.

## Select models

Follow [Select models](workflow.md#select-models).

## Prepare input

| Argument | Audit targets |
| --- | --- |
| None | Active changes and main specs that differ from the merge base, including uncommitted and untracked files |
| `all` | All active changes and main specs |
| PR number or GitHub pull URL | Changed files under `openspec/`, without checkout |
| Existing change slug or main spec domain | That change or domain |

Reserve `all` and reject other scopes. Follow [Prepare input](workflow.md#prepare-input).
For PRs, add `--group-root openspec/changes --group-root openspec/specs` to
the prepare command. If no files under `openspec/` changed, report that,
clean up, and stop.

For a local audit, run the command for the selected scope:

```bash
node <this-skill-dir>/scripts/prepare-local-spec-input.mjs changed
node <this-skill-dir>/scripts/prepare-local-spec-input.mjs all
node <this-skill-dir>/scripts/prepare-local-spec-input.mjs change <slug>
node <this-skill-dir>/scripts/prepare-local-spec-input.mjs domain <name>
```

`changed` uses `origin/HEAD` or falls back to `origin/main`. Add
`--base <ref>` only when the user names a base. If no targets differ,
report the base and suggest `all`, a change slug, or a domain.

Retain the reported `inputDigest`. Audit the reported changes and domains.
Use `contextFiles` as authority.

## Scope large reviews

Above 10 changed spec files or 500 changed lines, use bounded bundles.
Keep each change's proposal, design, tasks, and deltas together. Group main
specs by domain. Put other hunks in a bundle named `context` for conformance
context only. Follow [Scope large reviews](workflow.md#scope-large-reviews).

## Run reviewers

### Structural audit

Run the validator for each target change. Use `--all` when any main spec is a
target. The PR profile pins `@fission-ai/openspec@1.6.0`. Exit 1 means findings.
Exit 2 means partial coverage. Keep failed rules as `NOT_VERIFIED`.

```bash
python3 <this-skill-dir>/scripts/audit_structure.py --profile pr \
  --root "$code_root" --change <slug> > "$REVIEW_DIR/structure-<slug>.json"
python3 <this-skill-dir>/scripts/audit_structure.py --profile pr \
  --root "$code_root" --all > "$REVIEW_DIR/structure-all.json"
```

Repeat `--schema <name>` for additional documented schemas. Use
`--house-style` only for projects that adopt the [checklist](CHECKLIST.md).
Use `--naming-validator <absolute-path>` only with a trusted script outside
the PR checkout.

```bash
node <this-skill-dir>/scripts/structural-findings.mjs \
  --line-map "$REVIEW_DIR/line-map.json" "$REVIEW_DIR"/structure-*.json \
  > "$REVIEW_DIR/structural-findings.json"
```

For local scope, replace `--line-map` and its path with
`--manifest "$REVIEW_DIR/manifest.json"`. Keep structural reports out of
worker prompts.

### Behavioral audit

Pass `<this-skill-dir>/agents/spec-reviewer.md` as `<worker.md>` in the
shared prompt command. The script adds paths to the bundled
[`REFERENCE.md`](REFERENCE.md), [`CHECKLIST.md`](CHECKLIST.md), and
[`LANES.md`](LANES.md) paths.

Enable traceability for target changes with `source.md` or on request.
Name the main spec targets for conformance, or state there are none.
Enable reverse conformance only when the user requests deep conformance.
Follow [Run reviewers](workflow.md#run-reviewers).

## Verify and report

For local audits, repeat preparation and warn of possible staleness if the
digest differs. Follow [Verify and report](workflow.md#verify-and-report) for
findings and questions. Repeat the structural audit on fresh input if context
changes can affect the validator.

Merge same-anchor reports only when rule, path, requirement, and root cause
match. Present structural findings unchanged. Follow
[Stable report order](REFERENCE.md#stable-report-order). Number findings
together, then questions. Keep structural coverage and outside-target notes
unnumbered in chat. End with the audited SHA, coverage, and worst finding.

## Post approved findings

For a PR, if approval is pending, ask
`Reply "post all", "post findings", "post 1,3", or "post none".`
`post all` includes all numbered entries. `post findings` selects confirmed
findings only. Keep searched sources for questions in chat.

Select structural entries from `structural-findings.json` by index.
Follow [Post approved findings](workflow.md#post-approved-findings).

## Cleanup

Follow [Cleanup](workflow.md#cleanup). Preparation prunes marked inputs older
than 24 hours. To prune now, run `cleanup-review-input.mjs --stale`.
