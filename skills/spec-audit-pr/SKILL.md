---
name: spec-audit-pr
description: Audits OpenSpec changes and main specs, locally or in a GitHub pull request, with deterministic structural checks and one or more model-pinned spec-reviewers. Shows findings in chat and posts only if the user asks. Use when checking spec validity, quality, traceability, or implementation drift, or when asked to run /spec-audit-pr.
argument-hint: '[<PR number|URL>|<change-slug>|<domain>|all] [--model <slug>]'
disable-model-invocation: true
---

# Spec audit

Audit only by default. Do not edit specs or code or post pull request comments
unless the user explicitly asks after seeing the findings.

## Model selection

Accepted forms:

- `/spec-audit-pr` opens the model chooser, then audits the active changes and
  main specs that differ from the base branch.
- `/spec-audit-pr <change-slug>` or `/spec-audit-pr <domain>` opens the model
  chooser, then audits that active change or main spec domain.
- `/spec-audit-pr all` opens the model chooser, then audits every active change
  and every main spec.
- `/spec-audit-pr <PR>` opens the model chooser, then audits the OpenSpec files
  that PR changes.
- `--model <slug>` uses that exact slug. Repeat `--model` to run several
  spec-reviewers.
- In Pi, invoke `/skill:spec-audit-pr [<PR>|<change-slug>|<domain>|all] [--model <cursor-slug|provider/id[:thinking]>]`.

Before any other tool call, read only the host file that matches where you
run. Follow it for model selection and for launching spec-reviewers:

- Pi (`PI_CODING_AGENT=true` or a system prompt saying you run inside pi),
  even when the Cursor SDK also identifies the host as Cursor:
  [`hosts/pi.md`](hosts/pi.md)
- Cursor desktop GUI: [`hosts/cursor-desktop.md`](hosts/cursor-desktop.md)
- Cursor Agent CLI: [`hosts/cursor-cli.md`](hosts/cursor-cli.md)
- Codex: [`hosts/codex.md`](hosts/codex.md), selecting model and reasoning effort together.
- Amp: no host file. The only available model is the one this thread runs on (`agentMode` from `amp.get_thread_status`). Do not ask for one. Launch one spec-reviewer with the `Task` tool.
- any other host: [`hosts/other.md`](hosts/other.md)

Treat slugs as opaque strings. Match them exactly against the host's available
model list. Never normalize, invent, or substitute a slug. If any selected slug
is unavailable, do not launch a spec-reviewer. Show the unavailable slug and
exact available slugs, then ask for a corrected selection. Remove exact
duplicates while preserving selection order.

After the card response, start the next chat message with
`Selected: <exact slug>.` once for each selected slug in selection order. Use
only those exact slugs in later chat text.

After model selection, read the installed `asd-ste100` skill, or `unslop` if
only that is available. Apply it to findings and comments. Replace
`<this-skill-dir>` with the absolute path to this skill.

## Scope

Each audit separates targets from context. Targets get findings. Context is
read as authority and gets none.

With no scope argument, the targets are the active changes and main spec
domains whose files differ from the merge base with the base branch, including
uncommitted and untracked files. `all` targets every active change and every
main spec. A positional PR number or GitHub pull URL selects a PR and audits it
without checking it out. An existing `openspec/changes/<slug>/` selects that
change; an existing `openspec/specs/<domain>/` selects that domain. `all` is a
keyword, never a slug. Reject an argument that is none of these.

For a change target, the main specs of the domains its delta specs touch are
context. Spec-reviewers read them to judge the deltas, but do not report
issues in them or run conformance against them. A main spec is a target only
for `all`, for `<domain>`, when the branch or PR edits it directly, or when the
user asks for it.

Traceability runs only for a targeted change with `source.md` or when the user
requests it. Conformance runs only for main spec targets, never active-change
deltas or context. Reverse conformance (code with no backing spec) runs only
when the user requests deep conformance.

Explicit proposal/design non-goals are hard scope exclusions. Do not ask the
target to implement them or search for evidence to pull them back into scope.
If the target itself adds a normative requirement about excluded or
sibling-owned behavior, audit only that contradiction under Q015 or T003.

## Pin the audit input

Run each documented script at its workflow step.

For the default scope, `all`, a change, or a domain, run one of:

```bash
node <this-skill-dir>/scripts/prepare-local-spec-input.mjs changed
node <this-skill-dir>/scripts/prepare-local-spec-input.mjs all
node <this-skill-dir>/scripts/prepare-local-spec-input.mjs change <slug>
node <this-skill-dir>/scripts/prepare-local-spec-input.mjs domain <name>
```

`changed` compares against `origin/HEAD`, falling back to `origin/main`. Pass
`changed --base <ref>` only when the user names another base. If nothing
differs, it fails and names the base; report that and suggest `all`, a change
slug, or a domain.

Use its reported `directory` as `REVIEW_DIR` and its `root` as `code_root`.
Its `changes` and `domains` are the targets; the manifest's `contextFiles` are
context. Retain the reported `inputDigest`, which covers both. After the audit,
rerun the same command, compare digests, and clean up the second directory. If
the digests differ, warn that the findings may be stale.

For a pull request, require a number or GitHub pull URL. Do not check it out.

```bash
node <this-skill-dir>/scripts/prepare-pr-review-input.mjs prepare "<PR>" \
  --group-root openspec/changes --group-root openspec/specs
```

Use its reported `directory` as `REVIEW_DIR` and its `source` as `code_root`.
Read `changedPaths` for scope and use `mergeBaseOid` as the diff base.
If prepare fails or does not report `directory`, report the failure and stop.
Do not construct substitute patches, manifests, line maps, or bundles. If the
PR changes no files under `openspec/`, say so, clean up, and stop.

For PRs, `source` is a detached head worktree, including stack parents. The
patch is the declared base-to-head delta. Use `source`, not the caller checkout
or default ref, for bounded reads.

Before materializing review bundles, run any `source` preflight your host file
requires.

## Scope large reviews

For a PR with more than 10 changed spec files or 500 changed lines, group the
reviewable OpenSpec hunk IDs into self-contained bundles: one per active change
and one per main spec domain. Do not send the full patch to every worker. Put
every reviewable hunk outside `openspec/` in one bundle named `context`; the
bundle validator requires every reviewable hunk in exactly one bundle.
Spec-reviewers read the `context` bundle as conformance context, not targets.

Every selected model gets all materialized bundles and reviews them serially.
Never partition bundles by model, change, domain, or lane.

Start with `$REVIEW_DIR/review-bundles.json`. The group roots keep each change
and each main spec domain together. Move non-OpenSpec hunks to `context`.
Keep bundles bounded. Materialize the bundle files,
then verify their contents before launching workers:

```bash
node <this-skill-dir>/scripts/build-review-bundles.mjs \
  "$REVIEW_DIR/manifest.json" "$REVIEW_DIR/review-bundles.json"

node <this-skill-dir>/scripts/verify-review-bundles.mjs \
  "$REVIEW_DIR/manifest.json" "$REVIEW_DIR/materialized-review-bundles.json"
```

The build command writes `$REVIEW_DIR/review-index.json`. Pass that compact
index to every spec-reviewer; per-bundle anchor files replace worker reads of
the global line map.

## Run the structural pass

Run the bundled validator once against `code_root`, using `--change` for each
target change and `--all` when any main spec is a target:

```bash
python3 <this-skill-dir>/scripts/audit_structure.py --profile pr \
  --root "$code_root" --change <slug> > "$REVIEW_DIR/structure-<slug>.json"
python3 <this-skill-dir>/scripts/audit_structure.py --profile pr \
  --root "$code_root" --all > "$REVIEW_DIR/structure-all.json"
```

The shared validator uses `--profile pr` for P0/P1/P2 findings and repository
file anchors. It emits normalized JSON and invokes pinned `@fission-ai/openspec@1.6.0`. Do
not substitute `@latest`. Exit 1 means it found structural failures and exit 2
means partial coverage; both still write a valid report. Known upstream and
house-style mismatches are `ACCEPTED_EXCEPTION`, not errors. Preserve a failed
check as `NOT_VERIFIED`; never claim it passed.

Convert the reports into postable findings. For a PR, pass
`--line-map "$REVIEW_DIR/line-map.json"`; for local scope, pass
`--manifest "$REVIEW_DIR/manifest.json"`:

```bash
node <this-skill-dir>/scripts/structural-findings.mjs \
  --line-map "$REVIEW_DIR/line-map.json" "$REVIEW_DIR"/structure-*.json \
  > "$REVIEW_DIR/structural-findings.json"
```

Its `findings` are complete comment entries attributed to `audit_structure.py`.
Present and post them as written. Its `notes` feed the coverage notes,
including verified results outside the patch or audit targets. Spec-reviewers
do not receive the structural reports.

## Run the audit

The parent does not review. Before launching, create and maintain a
spec-reviewer job list in selection order. This is internal orchestration
state; do not print it in chat. It has exactly one row per selected model:

```text
{ model: "<exact slug>", reviewerId: "pending", status: "planned" }
```

Read `<this-skill-dir>/agents/spec-reviewer.md` directly, then run
each job using its instructions in the prompt. Target that job's exact model
slug and include `Reviewer model: <exact slug>` in every prompt. Include the
spec-reviewer contract, the selected writing skill's instructions, absolute input paths, the
absolute `code_root`, and the absolute paths of
[`REFERENCE.md`](REFERENCE.md), [`CHECKLIST.md`](CHECKLIST.md), and
[`LANES.md`](LANES.md). State whether traceability and deep conformance apply,
and name the main spec targets that get conformance, or say there are none.

Launch each job as your host file describes, with its exact slug, its complete
prompt, and `code_root` as the code root. Use distinct numbered prompt and
result files for each model. Read each result before synthesis. If any job
fails or returns no result, report the failure; do not attribute findings to
that model or present an incomplete audit. This direct prompt handoff does not
invoke `/spec-audit-pr`.
When a launch returns, replace that row's `reviewerId` with the returned
reviewer-session ID, whether it came from Pi, Cursor Agent CLI, or the native
subagent, and set `status` to `launched`.

After all launch calls return, compare the job list to the selected models
before accepting spec-reviewer results. Every selected model must have exactly
one launched spec-reviewer. Do not include the job list or launch counts in
successful audit output. If a launch is missing, failed, or cannot be
attributed to a selected model, report the expected and launched counts and do
not synthesize or present findings as complete.

For bundled PRs, pass `review-index.json` and `source`. For small PRs, pass
`patch.diff`, `line-map.json`, `manifest.json`, and `source`. Give workers the
input paths, not line-map contents. The parent does not read the global line
map. For local scope, pass the spec manifest and `code_root`.

## Verify, present, and post

For a pull request, verify before presenting:

```bash
node <this-skill-dir>/scripts/prepare-pr-review-input.mjs verify "<PR>" "$REVIEW_DIR/manifest.json"
```

Verification fails when the base-to-head patch changed. Then warn that the
findings are stale and do not post them. When only the head moved, such as a
base merge that left the patch unchanged, verification succeeds, prints the
new `headRefOid`, and lists changed files outside the patch in
`contextChangesPath`. Mark any finding or question whose searched sources
appear in that list as stale. Post with the `headRefOid` that verification
printed.

Say which models ran. Synthesize without discovering new findings. Same-anchor
reports are candidates for corroboration; merge only when they share a rule ID,
path, and requirement and clearly identify the same root cause. Show the
canonical postable comment with supporting model attribution, retain original
wording in chat, and keep ambiguous reports separate. Order the report as
[`REFERENCE.md`](REFERENCE.md) `Stable report order` describes: numbered
structural and reviewer findings together by severity P0 through P2, then
review questions, then unverified candidates with changed-line anchors.
Keep unanchored candidates in chat. Coverage notes stay in chat. End with
the audited SHA, coverage, and the worst finding.

For local scope, findings stay in chat. For a pull request, end the turn with
the numbered report and ask:
`Reply "post all", "post findings", "post 1,3", or "post none".`

Pass the selected models and approved entries as one JSON object:

```text
{
  "selectedModels": ["<exact slug>", "<exact slug>"],
  "comments": [
    {
      "body": "<canonical finding body>",
      "modelSlugs": ["<exact slug>"],
      "findingKey": "<rule ID>:<path>:<requirement name>",
      "path": "<path>",
      "line": 1,
      "side": "RIGHT",
      "anchor": "<full changed line>"
    },
    {
      "body": "<canonical finding body>",
      "modelSlugs": ["<exact slug>"],
      "findingKey": "<rule ID>:<path>:<requirement name>",
      "path": "<path>",
      "anchor": "none"
    }
  ]
}
```

`modelSlugs` must contain only spec-reviewer jobs that reported that finding.
Copy each approved entry from `structural-findings.json` `findings` unchanged;
its `tool` field replaces `modelSlugs`. Build every reviewer `findingKey` from
the rule ID, path, and requirement name the spec-reviewer returned. Do not
include a `Found by` footer in `body`. The posting command rejects invalid
attribution, appends the deterministic `Found by` footer ordered by
`selectedModels`, and embeds a hidden marker derived from `findingKey`. A
review question body starts with its
`**[Question] - <rule ID and name> - confidence <N>:**` heading, followed by
`Question:` and `Why it matters:`. Searched sources stay in chat.
When verification reports context changes, include the authoritative paths
for each approved reviewer entry in `evidencePaths`.

Post only after explicit approval. Pass the JSON object on standard input:

```bash
node <this-skill-dir>/scripts/post-inline-pr-comments.mjs "<PR>" "<headRefOid>" "$REVIEW_DIR/manifest.json" -
```

The command confirms the head, validates the full batch, and posts inline
comments in one GitHub review. It prints each comment URL. For duplicates it
prints `alreadyPosted=<url>`.

`post all` includes every numbered entry. `post findings` excludes review questions.
It also excludes unverified candidates. `post 1,3` selects from
the same numbered list. A finding or question without a changed anchor uses
`"anchor": "none"` and posts as one general PR comment that names its file.
Start an unrelated finding's body, after the heading, with
`Unrelated discovered issue.` The spec-reviewers do not post.

## Cleanup

Keep the reported temporary directory while showing findings and waiting for
the user's posting decision. After posting, declining to post, rejecting stale
findings, or finishing a local audit, remove it:

```bash
node <this-skill-dir>/scripts/cleanup-review-input.mjs "<reported-directory>"
```

Each prepare removes marked review inputs older than 24 hours. To remove them
now, run `cleanup-review-input.mjs --stale`.
