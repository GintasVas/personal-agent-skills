---
name: review-pr
description: Review a GitHub pull request with one or more dedicated code-reviewers and deterministic model selection. Show findings in chat. Post only if the user asks.
disable-model-invocation: true
---

# Review PR

## Model selection

Accepted forms:

- `/review-pr <PR>` opens the model chooser on hosts that provide one.
- `/review-pr <PR> --model <slug>` uses that exact slug. Repeat `--model` to run several reviewers.
- In Pi, invoke `/skill:review-pr <PR> [--model <cursor-slug|provider/id[:thinking]>]`.

Before any other tool call, read only the host file that matches where you
run. Follow it for model selection and for launching reviewers:

- Pi (`PI_CODING_AGENT=true` or a system prompt saying you run inside pi),
  even when the Cursor SDK also identifies the host as Cursor:
  [`hosts/pi.md`](hosts/pi.md)
- Cursor desktop GUI: [`hosts/cursor-desktop.md`](hosts/cursor-desktop.md)
- Cursor Agent CLI: [`hosts/cursor-cli.md`](hosts/cursor-cli.md)
- Codex: [`hosts/codex.md`](hosts/codex.md), selecting model and reasoning effort together.
- Amp: no host file. The only available model is the one this thread runs on (`agentMode` from `amp.get_thread_status`). Do not ask for one. Launch one reviewer with the `Task` tool.
- any other host: [`hosts/other.md`](hosts/other.md)

Treat slugs as opaque strings. Match them exactly against this host's available model list. Never normalize a slug, choose a close name, invent a slug, or substitute another model. If any selected slug is unavailable, do not launch a reviewer. Show the unavailable slug and the exact available slugs, then ask for a corrected selection. Remove exact duplicates while preserving selection order.

After the card response, start the next chat message with
`Selected: <exact slug>.` once for each selected slug in selection order. Use
only those exact slugs in later chat text.

After model selection, read the installed `asd-ste100` skill, or `unslop` if
only that is available. Apply it to findings and comments. Replace
`<this-skill-dir>` with the absolute path to this skill.

The command must include a PR number or pull URL. If it does not, ask for one. Do not guess.

## Review

Finding body format: `**[P1] - Correctness - confidence 92:**`, a blank line,
then the comment.

### Scope large reviews before launching workers

Prepare the pinned review input:

```bash
node <this-skill-dir>/scripts/prepare-pr-review-input.mjs prepare "<PR>"
```

Use its reported `directory` as `REVIEW_DIR`. Read `changedPaths` for scope.
Use `mergeBaseOid` as the diff base.
Run each documented script at its workflow step.
If prepare fails or does not report `directory`, report the failure and stop.
Do not construct substitute patches, manifests, line maps, or bundles.

For PRs, `source` is a detached head worktree, including stack parents. The
patch is the declared base-to-head delta. Use `source`, not the caller checkout
or default ref, for bounded reads.

Before materializing review bundles, run any `source` preflight your host file
requires.

For PRs with more than 10 changed files or 500 changed lines, do not give every
worker the whole diff. Group the reviewable hunk IDs into self-contained review
bundles with enough local context to understand them. Always include changed
public interfaces, auth or authorization, persistence or migrations, external
I/O, concurrency, deployment configuration, and error-handling boundaries.
Group low-risk implementation hunks into a small bundle per directory. Treat
generated files, lockfiles, and snapshots as manifest entries. Bundle every
hunk the manifest marks `reviewable`.

The manifest must account for every changed hunk. Every selected model gets all
materialized bundles and reviews them serially. Never partition bundles by
model, directory, risk, or layer.

Start with `$REVIEW_DIR/review-bundles.json`, which assigns reviewable hunks by
`bundleCandidate`. Refine only its `hunkIds` arrays when related files need a
shared bundle. Bundle a new shared module with only the changed importers
needed to understand it. Keep bundles bounded. Materialize the bundle files,
then verify their contents before launching workers:

```bash
node <this-skill-dir>/scripts/build-review-bundles.mjs \
  "$REVIEW_DIR/manifest.json" "$REVIEW_DIR/review-bundles.json"

node <this-skill-dir>/scripts/verify-review-bundles.mjs \
  "$REVIEW_DIR/manifest.json" "$REVIEW_DIR/materialized-review-bundles.json"
```

The build command writes `$REVIEW_DIR/review-index.json`. Pass that compact
index to every reviewer; per-bundle anchor files replace worker reads of the
global line map.

Before launching, create and maintain a reviewer-job list in selection order.
This is internal orchestration state; do not print it in chat. It has exactly
one row per selected model:

```text
{ model: "<exact slug>", reviewerId: "pending", status: "planned" }
```

Launch one reviewer per job, targeting that job's exact model slug. Launch
multiple reviewers concurrently when the host supports it; Pi may run them
serially. In every reviewer prompt, include
`Reviewer model: <exact slug>`. When a launch returns, replace that row's
`reviewerId` with the returned reviewer-session ID (the runner's `reviewerId`
in Pi or Cursor Agent CLI, or the native subagent ID) and set `status` to
`launched`.

After all launch calls return, compare the job list to the selected models
before accepting reviewer results. Every selected model must have exactly one
launched reviewer. Do not include the job list or launch counts in successful
review output. If a launch is missing, failed, or cannot be attributed to a
selected model, report the expected and launched counts and do not synthesize
or present findings as complete.

Read `<this-skill-dir>/agents/code-reviewer.md` directly, then run
each job using its instructions in the prompt and its exact model slug. Include
the reviewer contract, matching lens sections, the selected writing skill's instructions, `Reviewer
model: <exact slug>`, absolute input paths, and the absolute `source` path. Set
`source` to the absolute source path reported by prepare.

Launch each job as your host file describes, with its exact slug, its complete
prompt, and `source` as the code root. Use distinct numbered prompt and result
files for each model. Read each result before synthesis. If any job fails or
returns no result, report the failure; do not attribute findings to that model
or present an incomplete review. This direct prompt handoff does not invoke
`/review-pr`. Say which exact model slugs ran.

For bundled PRs, pass `review-index.json` and `source`. For small PRs, pass
`patch.diff`, `line-map.json`, `manifest.json`, and `source`. Give workers the
input paths, not line-map contents. The parent does not read the global line
map. `source` is the only code root. Workers read extra context only from
`source`; an absent diff line does not prove a helper, export, or pattern is
missing. Read the target repository's applicable instructions and standards.
Review the supplied bundles. They may inspect a changed definition, one direct
caller or consumer, one relevant test or local analogue, and more only when a
concrete suspected defect requires it. Skip CI-caught issues, style not in the
standards, and missing lockfiles. An issue outside the diff is allowed only
when that bounded inspection directly reveals it. Label it `Unrelated
discovered issue` and do not search for more. Return comments only, plus
`headRefOid`, exact `path`, `line`, `side`, and `anchor` from the line map,
severity, bug kind, and confidence score on each finding. Finding bodies must
not cite source line numbers. Follow the reviewer contract for confidence and
unverified candidates. Do not post.

Identify changed specs from `changedPaths` and repo conventions. Pass their
paths to the worker and require the requirements pass, including for spec-only
PRs. Pass an originating spec or issue by path if available.

### Shape the review

Classify each assigned bundle as user interface, service and API, data model,
infrastructure and pipelines, or shared library. Read
[`shaping-lenses.md`](shaping-lenses.md) and copy only the matching sections
into every reviewer prompt. A lens is a symptom to investigate, not a finding
rule. Repository standards and established patterns win over a lens.

After validation, keep unverified candidates separate from findings and design
alternatives.
Maintainability finding requirements are a changed anchor, a concrete cost, a
bounded correction, and support from a repository standard or existing pattern.
Otherwise, present the observation as a design alternative only when it names
the constraint, an alternative, its cost, and the simpler variant that is
wrong. Offer these separately.

### Verify the input

After the review and before presenting findings as current, run:

```bash
node <this-skill-dir>/scripts/prepare-pr-review-input.mjs verify "<PR>" "$REVIEW_DIR/manifest.json"
```

If verification fails, the base-to-head patch changed. Warn that the findings
are stale and do not post them. When only the head moved, such as a base merge
that left the patch unchanged, verification succeeds, prints the new
`headRefOid`, and lists changed files outside the patch in
`contextChangesPath`. Mark any finding whose traced code appears in that list
as stale. Post with the `headRefOid` that verification printed.

### Synthesize findings

Synthesize without discovering new findings. Same-anchor reports are candidates
for corroboration; merge only when they clearly identify the same mechanism.
Show the canonical postable comment with supporting model attribution, retain
original wording in chat, and keep ambiguous reports separate. Number P0
through P2 findings, then unverified candidates with changed-line anchors.
Show requirements findings under their own heading with continuous numbering.
Keep unanchored candidates in chat and show design alternatives separately.
Ask: `Reply "post all", "post 1,3", or "post none".`

Pass the selected models and approved inline findings as one JSON object:

```text
{
  "selectedModels": ["<exact slug>", "<exact slug>"],
  "comments": [
    {
      "body": "<canonical finding body>",
      "findingKey": "<path>:<symbol or scope>:<mechanism>",
      "modelSlugs": ["<exact slug>"],
      "path": "<path>",
      "line": 1,
      "side": "RIGHT",
      "anchor": "<full changed line>"
    }
  ]
}
```

`modelSlugs` must contain only reviewer jobs that reported that finding. Do not
include a `Found by` footer in `body`. The posting command rejects invalid model
metadata and appends the deterministic attribution footer, ordered by
`selectedModels`. Use the same `findingKey` for the same location and mechanism.
When verification reports context changes, give each approved entry
`evidencePaths` for the repo files that support it.

Post only if this turn asks to. Pass the selected models and approved inline
findings as a JSON object on standard input:

```bash
node <this-skill-dir>/scripts/post-inline-pr-comments.mjs "<PR>" "<headRefOid>" "$REVIEW_DIR/manifest.json" -
```

The command validates the full batch and posts inline comments in one GitHub
review. It prints one URL per comment.

`post all` includes numbered unverified candidates and `Unrelated discovered
issue` findings. `post 1,3` selects from the same numbered list, whether a finding is
inline or unrelated. For each selected unrelated finding, post one general PR
comment whose first line is `[Unrelated discovered issue] [P1, confidence 85]`.
Post each as a PR conversation comment. Confirm the current `headRefOid`
first. The reviewers do not post.

`post all` includes design alternatives. Also accept `post alternatives` and
`post 1,3 and alternatives`. Recheck the PR before posting approved
alternatives as one conversation comment under `## Design alternatives`.

## Cleanup

Keep the review directory while showing findings and waiting for the user's
posting decision. After posting, declining to post, or rejecting stale
findings, remove the reported temporary directory:

```bash
node <this-skill-dir>/scripts/cleanup-review-input.mjs "<reported-directory>"
```

Each prepare removes marked review inputs older than 24 hours. To remove them
now, run `cleanup-review-input.mjs --stale`.
