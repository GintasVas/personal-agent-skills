---
name: spec-audit-pr
description: Audit local or PR OpenSpec files for structure, behavior, traceability, and implementation drift. Post only on request.
argument-hint: '[<PR number|URL>|<change-slug>|<domain>|all] [--model <slug>]'
disable-model-invocation: true
---

# Spec audit

Run `/spec-audit-pr [<PR>|<change-slug>|<domain>|all] [--model <slug>]`.
In Pi, use `/skill:spec-audit-pr` with the same scope and
`[--model <cursor-slug|provider/id[:thinking]>]`.
Audit only by default. Edit or post only on explicit request after showing
findings.

## Select models

Before any other tool call, read only the host file for model selection and launch:

- Pi ([hosts/pi.md](hosts/pi.md)) if `PI_CODING_AGENT=true` or the system prompt names Pi. This takes precedence over Cursor SDK detection.
- [Cursor desktop](hosts/cursor-desktop.md) or [Cursor Agent CLI](hosts/cursor-cli.md).
- [Codex](hosts/codex.md). Select the model and reasoning effort together.
- Amp. Use this thread's `agentMode` from `amp.get_thread_status`. Launch one worker with `Task`. Skip the chooser.
- [Other hosts](hosts/other.md).

Without `--model`, use the chooser where supported. With `--model <slug>`, use
that exact slug. Repeat `--model` for multiple workers. Remove exact duplicates
in selection order. Match slugs against the host's available list. If any is
unavailable, stop before launch. Show the unavailable slug and exact available
slugs. Ask for a new selection. Never normalize, invent, or substitute slugs.

After a chooser response, put this first in the next chat message:
`Selected: <exact slug>.` for each selection, in order. Use those exact names
in later chat. Apply the target repo's writing rules when available. Use plain
technical English for chat, findings, and comments.

## Scope

| Argument | Audit targets |
| --- | --- |
| None | Active changes and main specs that differ from the merge base, including uncommitted and untracked files |
| `all` | All active changes and main specs |
| PR number or GitHub pull URL | Changed files under `openspec/`, without checkout |
| Existing change slug or main spec domain | That change or domain |

Reserve `all` as a keyword. Reject other arguments. For a change, touched
main specs are context. Audit a main spec only for `all`, a named domain,
a direct branch or PR edit, or a user request. Targets get findings.
Read context as authority.

Run traceability on targeted changes with `source.md` or when requested.
Run conformance only on main spec targets. Reverse conformance finds code
without a backing spec. Run it only when the user requests deep conformance.

Explicit proposal and design non-goals are hard scope exclusions. Do not
request implementation or search for evidence to include them. If a target
adds a normative rule about excluded or sibling-owned behavior, audit only
that contradiction under Q015 or T003.

## Pin the audit input

Run the bundled scripts at the steps below. Replace `<this-skill-dir>`
with the absolute path to this skill directory. Do not inspect script source.

For a local audit, run one command. Use `changed` with no scope. Use
`all`, `change <slug>`, or `domain <name>` for the matching scope.

```bash
node <this-skill-dir>/scripts/prepare-local-spec-input.mjs changed
node <this-skill-dir>/scripts/prepare-local-spec-input.mjs all
node <this-skill-dir>/scripts/prepare-local-spec-input.mjs change <slug>
node <this-skill-dir>/scripts/prepare-local-spec-input.mjs domain <name>
```

`changed` uses `origin/HEAD` or falls back to `origin/main`. Use
`changed --base <ref>` only when the user names a base. If nothing differs,
report the base and suggest `all`, a change slug, or a domain.

For local audits, set `REVIEW_DIR` from `directory` and `code_root` from
`root`. Target the reported `changes` and `domains`. Read manifest
`contextFiles` as authority. Keep `inputDigest`, which covers both.
After the audit, repeat the command and remove its second directory.
Warn of possible staleness if the digests differ.

For a PR, prepare the pinned input.

```bash
node <this-skill-dir>/scripts/prepare-pr-review-input.mjs prepare "<PR>"
```

Use the reported `directory` as `REVIEW_DIR`. Set `code_root` to the detached head worktree
`source` for all PR context, including stack parents. The patch covers the
declared base-to-head delta. Run any host-required `source` preflight before
building bundles.
If prepare fails or does not report `directory`, report the failure and stop.
Do not construct substitute patches, manifests, line maps, or bundles.
If the PR changes no files under `openspec/`, say so, clean up, and stop.

## Scope large reviews

Above 10 changed spec files or 500 changed lines, bundle reviewable hunks
instead of giving workers the full patch. Use one bundle per active change
or main spec domain. Keep a change's proposal, design, tasks, and deltas
together. Put all reviewable hunks outside `openspec/` in one bundle named
`context`. Use it only for conformance context. Keep bundles bounded.
Assign every reviewable hunk to exactly one bundle.

Use `$REVIEW_DIR/review-bundles.json`. It groups reviewable hunks by
`bundleCandidate`. Change only `hunkIds` to group related files.

```bash
node <this-skill-dir>/scripts/build-review-bundles.mjs \
  "$REVIEW_DIR/manifest.json" "$REVIEW_DIR/review-bundles.json"
node <this-skill-dir>/scripts/verify-review-bundles.mjs \
  "$REVIEW_DIR/manifest.json" "$REVIEW_DIR/materialized-review-bundles.json"
```

Verify bundles before launch. Give all verified bundles to every model.
Each model reviews them in order. Use the generated `review-index.json` and
per-bundle anchors. The parent does not read the global line map.

## Run the structural audit

Run the validator for each target change. Use `--all` when any main spec is a target.

```bash
python3 <this-skill-dir>/scripts/audit_structure.py --profile pr \
  --root "$code_root" --change <slug> > "$REVIEW_DIR/structure-<slug>.json"
python3 <this-skill-dir>/scripts/audit_structure.py --profile pr \
  --root "$code_root" --all > "$REVIEW_DIR/structure-all.json"
```

The PR profile emits normalized JSON with P0 to P2 and repository anchors.
It uses pinned `@fission-ai/openspec@1.6.0`. Do not substitute `@latest`.
Exit 1 means findings. Exit 2 means partial coverage. Both emit a report.
Preserve failed rules as `NOT_VERIFIED`.

Repeat `--schema <name>` for additional documented schemas. Use
`--house-style` only for projects that adopt the [checklist](CHECKLIST.md)
conventions and exceptions. For naming, use
`--naming-validator <absolute-path>` only with a trusted script outside
the PR checkout.

```bash
node <this-skill-dir>/scripts/structural-findings.mjs \
  --line-map "$REVIEW_DIR/line-map.json" "$REVIEW_DIR"/structure-*.json \
  > "$REVIEW_DIR/structural-findings.json"
```

For local scope, replace `--line-map "$REVIEW_DIR/line-map.json"` with
`--manifest "$REVIEW_DIR/manifest.json"`. Present `findings` unchanged.
They already credit `audit_structure.py`. Use `notes` for coverage and
verified results outside the patch or audit targets. Keep structural
reports out of reviewer prompts.

## Run reviewers

The parent does not review. For local scope, pass the spec manifest and
`code_root`. Pass absolute paths to
[`REFERENCE.md`](REFERENCE.md), [`CHECKLIST.md`](CHECKLIST.md), and
[`LANES.md`](LANES.md). State the traceability and deep conformance
settings. Name the main specs that get conformance, or state there are none.

Keep one private job per selected model, in selection order:

```text
{ model: "<exact slug>", reviewerId: "pending", status: "planned" }
```

Read `<this-skill-dir>/agents/spec-reviewer.md`. Put its contract and
`Reviewer model: <exact slug>` in the prompt. Include applicable writing rules,
absolute input paths, and absolute `code_root`. Use separate numbered prompt and
result files for each model. Launch by the host instructions with the exact
model slug and `code_root` as its code root. Pass the prompt directly without
invoking `/spec-audit-pr`.

Record the returned runner session or native subagent ID in `reviewerId`.
Set status to `launched`. Before accepting results, match the job list to
the selection. Require one launched reviewer per selected model. If a launch
is missing, fails, or cannot be attributed, report expected and launched
counts. Keep counts and the job list out of successful output. Read every
result before synthesis. Stop synthesis if a launch or result fails or is missing.
Report the failure.
Do not attribute findings to that model or present the review as complete.

For bundled PRs, pass `review-index.json` and `source`. For small PRs, pass
`patch.diff`, `line-map.json`, `manifest.json`, and `source`. Pass paths only.

## Verify, present, and post

For a PR:

```bash
node <this-skill-dir>/scripts/prepare-pr-review-input.mjs verify "<PR>" "$REVIEW_DIR/manifest.json"
```

Verify before presentation. If verification fails, warn that the patch changed
and the findings are stale. Do not post. If the head moved and the patch stayed
the same, verification returns a new `headRefOid` and `contextChangesPath`.
Mark any finding or question whose searched sources appear in that list as stale.
Use the verified `headRefOid` to post.

Name the exact models that ran. Synthesize without discovering new findings.
Merge same-anchor reports only when they share a rule ID, path, requirement, and root cause. Show the canonical
postable comment and supporting models. Keep original wording in chat and
keep ambiguous reports separate.

Follow [Stable report order](REFERENCE.md#stable-report-order). Number all
structural and reviewer findings together in P0 to P2 order. Continue
numbering review questions. Add unnumbered notes from
`structural-findings.json`. Coverage notes stay in chat. End with the audited
SHA, coverage, and worst finding.

For local scope, report in chat. For a PR, end the turn with the report and ask:
`Reply "post all", "post findings", "post 1,3", or "post none".`

Post only after explicit approval.

```bash
node <this-skill-dir>/scripts/post-inline-pr-comments.mjs "<PR>" "<headRefOid>" -
```

Pass one JSON object on standard input.

```json
{
  "selectedModels": ["<exact slug>", "<exact slug>"],
  "comments": [{
    "body": "<canonical finding body>",
    "modelSlugs": ["<exact slug>"],
    "findingKey": "<rule ID>:<path>:<requirement name>",
    "path": "<path>",
    "line": 1,
    "side": "RIGHT",
    "anchor": "<full changed line>"
  }]
}
```

Use only reporting reviewer jobs in `modelSlugs`. Build `findingKey` from
the returned rule ID, path, and requirement. Copy approved structural entries
unchanged. Their `tool` replaces `modelSlugs`. Omit the `Found by` footer.
The script rejects invalid attribution. It adds the footer in model selection
order and a hidden marker from `findingKey`.

Use `**[Question] - <rule ID and name> - confidence <N>:**` as the question
heading. Follow it with `Question:` and `Why it matters:`. Keep searched
sources in chat.
For an unanchored finding or question, use `"anchor": "none"`. Omit `line`
and `side`. The script posts one general PR comment and names the file.
Put `Unrelated discovered issue.` after the heading of an unrelated finding.
Post standalone comments. Reviewers never post.

`post all` covers every numbered finding and question, including unanchored
and approved unrelated entries. `post findings` excludes review questions.
`post 1,3` selects from that same list. The script verifies the head and full
batch. It returns one URL per comment.
Report `alreadyPosted=<url>` as already posted.

## Cleanup

Keep the reported directory while you show findings and wait for a posting
decision. Remove it after posting, declining, or rejecting stale findings, or finishing a local audit.

```bash
node <this-skill-dir>/scripts/cleanup-review-input.mjs "<reported-directory>"
```

Prepare prunes marked inputs older than 24 hours. To prune now, run
`cleanup-review-input.mjs --stale`.
