# Spec Audit Reference

Read [COMMON_REFERENCE.md](COMMON_REFERENCE.md) alongside this file for authority order,
behavioral review, coverage-pass definitions, applicability, and conformance roots.

## Evidence gate

A semantic candidate is a finding only when all applicable statements are true:

1. The behavior is delivered by this target and is not an explicit non-goal.
2. It has one checklist rule ID and a deterministic applicability trigger.
3. It quotes the requirement or code that creates the issue.
4. It names the observable contradiction or missing outcome.
5. It lists every authoritative path searched for counter-evidence.
6. Any inherited rule is checked for applicability; a broken link alone does not erase clear
   inheritance.
7. Sibling ownership is checked and no conflict between authorities remains
   unresolved. A contradiction within the target or between the target and
   its applicable authority can itself be a finding.
8. A second falsification pass tries to disprove the candidate.

For a failed gate that leaves a plausible ambiguity, apply the reviewer's
confidence rules for questions and unverified candidates. Discard candidates
that ask the target to deliver an explicit non-goal.

## Coverage passes

Each lane in [LANES.md](LANES.md) names the passes it runs. Run a pass inside its lane, only when
the target delivers what the pass inspects.

Use the [shared coverage-pass definitions](COMMON_REFERENCE.md#coverage-passes).

## Stable identity

Use repository-relative paths. The finding key is:

```text
<rule_id>:<path>:<requirement_name>
```

Its digest is the first 12 hex characters of SHA-256 over the key after trimming, collapsing
whitespace to single spaces, and lowercasing. Structural reports show it as `SA-<rule_id>-<digest>`.
The posting script computes the same digest from each comment's `findingKey`, embeds it as a
hidden marker, and skips findings whose marker is already on the PR.

Do not include line numbers, prose wording, severity, timestamps, branch names, or commit SHA in
the key. Those can change without changing the underlying issue.

## Applicability matrix

- Change-only audit: `.openspec.yaml`, source, proposal, design, delta specs, linked main specs,
  linked general rules, linked domain/context docs, linked flows, and linked explorations. Linked
  main specs are context: authority for the deltas, never audit targets.
- Main-spec audit: target spec, general rules, domain/context docs, data model/dictionary when
  referenced, flows, and implementation roots. Only `all`, a named domain, a direct edit, or a
  user request makes a main spec a target.

Use the [shared applicability and conformance guidance](COMMON_REFERENCE.md#applicability-matrix)
for schema, API, UI, authorization, and external-dependency requirements.

## Review passes

The spec-reviewer works through the lanes in [LANES.md](LANES.md) in order. A prior report or
baseline cannot suppress a current failure. An accepted exception must cite current proposal,
design, or standards text.

## Stable report order

1. Findings, structural and behavioral together: P0, P1, P2; then rule ID, path, requirement
2. Review questions by rule ID, path, requirement
3. Unverified candidates by rule ID, path, requirement
4. Coverage notes: `NOT_VERIFIED` checks by check name, then `ACCEPTED_EXCEPTION` items and
   structural results outside the patch by rule ID and path

The worst issue is the first finding; say whether it is structural or behavioral. When only
structural findings exist, state that no behavioral issue was found. Never present a broken but
readily inferable local link as an implementation blocker.
