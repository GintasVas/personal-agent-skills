# Spec Audit Reference

Read [COMMON_REFERENCE.md](COMMON_REFERENCE.md) alongside this file for authority order,
behavioral review, coverage-pass definitions, applicability, and conformance roots.

## Evidence gate

Require one applicable rule with a definite trigger. Quote the requirement or code
that creates an observable contradiction or missing outcome in the delivered scope.
Record every authoritative path searched for counter-evidence.

Check inherited rules even when a link is broken. Verify sibling ownership and
resolve source conflicts before reporting a finding. Try to disprove each
candidate in a second pass. Ask a question only for unresolved ambiguity that
affects behavior. Exclude explicit non-goals from findings, questions, and
accepted exceptions. Apply Q015 or T003 to a target rule that contradicts the
declared scope.

## Coverage passes

Each lane in [LANES.md](LANES.md) names the passes it runs. Run a pass inside its lane, only when
the target delivers what the pass inspects.

Use the [shared coverage-pass definitions](COMMON_REFERENCE.md#coverage-passes).

## Stable identity

Use repository-relative paths. The finding key is:

```text
<rule_id>:<path>:<requirement_name>
```

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
3. Coverage notes: `NOT_VERIFIED` checks by check name, then `ACCEPTED_EXCEPTION` items and
   structural results outside the patch by rule ID and path

The worst issue is the first finding; say whether it is structural or behavioral. When only
structural findings exist, state that no behavioral issue was found. Never present a broken but
readily inferable local link as an implementation blocker.
