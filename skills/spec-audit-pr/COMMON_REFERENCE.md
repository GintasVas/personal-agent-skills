# Shared spec audit reference

## Authority order

Use the narrowest applicable authoritative source. When sources conflict, report the conflict
instead of silently choosing.

1. Project documentation, naming, database, and repository standards
2. Cross-domain behavioral rules
3. `openspec/specs/<domain>/spec.md` for shipped domain behavior
4. Domain schema and data model
5. Data dictionaries for field meaning and sample data
6. Domain glossaries for vocabulary
7. Flow documents for actor journeys and step order
8. Product requirements for initiative scope
9. Active change source, proposal, delta spec, and design for proposed behavior
10. Explicitly linked open prerequisite PRs for proposed concepts not yet on the target base
11. `openspec/changes/archive/` for historical provenance only, never live authority

An open PR does not become shipped authority. Record its number, head SHA, base, and whether the
target explicitly depends on it. If the open PR defines a concept differently, report the conflict.
A concept defined only by an open PR satisfies prerequisite traceability only when the target links
that PR explicitly, uses the same meaning, and does not present the concept as already shipped.

## Behavioral review

Start by writing a compact contract inventory:

- delivered operations and actors
- inputs and preconditions
- state transitions and externally observable outputs
- rejections and unchanged-state guarantees
- invariants that must always hold
- explicit non-goals and sibling-owned behavior

Compare requirements and scenarios against each other before checking implementation. Look for
contradictory values, states, ownership, ordering, and cardinality. Then apply only the relevant
scenario obligations:

| Operation shape              | Applicable scenario obligations                                                                                          |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Fixed reference data or seed | exact values, cardinality, materialization timing, repeat seed/reconciliation                                            |
| Create or update             | valid save, realistic invalid input, boundaries, no-op, stale version, uniqueness/conflict, unchanged state on rejection |
| Read one                     | found, absent, actor/scope when authorization is delivered                                                               |
| List or search               | results, empty state, pagination/filter boundaries when present                                                          |
| Delete or deactivate         | existing, already absent/inactive, dependent data, unchanged state on rejection                                          |
| External dependency          | unavailable, timeout, invalid response, retry/partial completion                                                         |
| Shared or repeatable write   | duplicate request, retry/replay, concurrent update, ordering, idempotency                                                |
| Composite value              | whole value absent, partial value, complete value, clearing, conditional child requirements                              |

This matrix is not a request for every scenario in every spec. An obligation applies only when the
target delivers that operation shape. Do not infer edit validation from seeded constants, API
errors from an internal repository, or authorization from a slice that explicitly excludes its
user-facing surface.

For each stated invariant, test whether every allowed path preserves it. Examples include exactly
one row, no duplicate enrollment, capacity never exceeded, ownership never crossing organization,
and totals remaining conserved. A happy-path scenario that creates one valid result does not prove
an always-true invariant.

## Coverage passes

### Concept traceability

Inventory every capitalized domain noun, status, role, identifier, account type, displayed label,
and other concept introduced or made behavior-controlling by the target. For each concept, record:

- exact definition and allowed values
- owning context
- lifecycle and invariants
- current-main source path, target definition, or explicitly linked open prerequisite PR
- whether the dependency is shipped or only proposed
- every conflicting meaning found in sibling changes or open PRs

A Figma label, Jira phrase, archived document, or repeated undefined use is not a definition. A
target may define a new concept itself, but it must define enough meaning for requirements and
scenarios to be testable. If no definition exists in the target, current repository, or a linked
open prerequisite PR, apply Q002. If a linked open PR is the only definition, require an explicit
dependency and do not describe the concept as already implemented.

For each identifier, additionally record:

- internal key versus human-readable business number versus external/legacy identifier
- format and generation point
- uniqueness scope
- whether transfer, conversion, or migration may change it
- compatibility mapping and retirement plan for legacy values

Apply Q018 when any of those properties control search, display, linking, or persistence but remain
undefined.

For each status or state, list every same-named vocabulary in owning contexts. Distinguish billing
lifecycle, membership tier, account state, eligibility, and access outcome. Apply Q019 when one
generic term controls behavior across meanings without an authoritative mapping.

### Operation boundaries

For every read and display, ask whether the requirement also infers or performs an action:

- Does opening a profile imply check-in, entry attempt, attendance, billing, or another write?
- Is actor or session context being used as the target club, account, or resource without saying so?
- Does the view recompute an outcome owned by another capability instead of consuming it?
- Is an audit read event incorrectly described as mutation of the viewed aggregate?

Apply Q020 when the operation boundary changes observable behavior or side effects.

### Normativity and readability

Inspect every `MAY`, `MUST NOT`, TBD, optional field, and scenario notation:

- Do allowed alternatives produce incompatible product behavior?
- Is a planned sibling feature being permanently prohibited?
- Is the negative rule protecting a named security, privacy, safety, unchanged-state, or domain
  invariant?
- Does a positive scenario already prove the same result?
- Are unrelated absent features being enumerated without bound?
- Do single-letter placeholders hide which facts differ or who owns them?
- Would concrete business values expose ambiguity that the symbols conceal?

Apply Q021 to materially incompatible optional outcomes, Q022 to unbounded/redundant negative
specification, and Q025 to opaque scenario notation. Use Q015 instead when the prohibition
conflicts with explicit sibling ownership.

### Write safety

For every create, update, delete, deactivate, or multi-context write, ask:

- Who is authorized, and what does rejection reveal?
- What inputs are invalid or conflicting?
- What is a no-op, and does it write audit history?
- How is a lost-response retry identified?
- What happens when the same key carries different input?
- What happens when two actors edit the same starting version?
- Is stale state rejected instead of silently overwritten?
- Which side effects must succeed together?
- How does retry resume after one side effect succeeds and another fails?
- What remains unchanged after every rejection and failure?

Do not treat retry idempotency as concurrency coverage. A duplicate request and two different edits
racing from the same starting version are separate cases.

### Composite values

For every address, date range, contact object, money breakdown, or other grouped value, ask:

- May the whole value be absent?
- If one child is present, which other children become required?
- Is a partially populated value valid?
- How is an existing value cleared?
- Does blank mean missing, unchanged, or explicitly cleared?
- Are normalization and validation applied before comparing for no-op?
- Does an open decision conflict with a rule that already accepts one answer?

### Verification plan

Map every implementation task group to applicable verification:

- pure domain rules have unit tests
- persistence and concurrency have integration tests
- API contracts have route or integration tests
- UI states, validation, and accessibility have component or browser tests
- external dependencies cover unavailable, invalid, and partial-success behavior

Apply Q017 when tasks add production behavior without matching behavior tests.

### Dependency readiness

For every required store, read model, event, account mode, external service, and sibling capability:

- Is it shipped on the target base?
- If proposed, is its open PR explicitly linked as a prerequisite with a pinned head/base?
- Does the target claim independent implementation readiness?
- Can the target ship truthfully with the dependency absent?
- Is fallback or placeholder data being presented as authoritative business data?

Apply Q023 when required behavior has neither a shipped dependency nor an explicit proposed
prerequisite.

### Selection and history

For every fact with potentially several records or dates, ask:

- current, active, latest, earliest, original, or effective on which date?
- scheduled end or actual end?
- current owner or original owner?
- contact email or login email?
- one record, the latest record, or all records?
- what appears when no record qualifies or the source cannot resolve one?

Apply Q024 when different reasonable selections produce different displayed or persisted behavior.

### Open-decision consistency

Inventory every `TBD`, open decision, unresolved owner, and deferred mapping. Search requirements,
design decisions, and tasks for behavior that already assumes one answer. Apply Q016 when the same
change both requires the behavior and says its controlling decision is unresolved.

## Applicability matrix

- Schema requirement: additionally inspect the domain data model, data dictionary, migrations, models,
  and schema contract test.
- API requirement: additionally inspect routes, handlers, DTOs, error mapping, and tests.
- UI requirement: additionally inspect web routes, screens, form state, API client, and E2E tests.
- Authorization requirement: additionally inspect authorization spec, middleware/policy, actor
  scope, and error rules.
- External dependency requirement: additionally inspect design and the sibling change named as
  owner.

Do not scan unrelated domains merely to increase coverage.

## Conformance roots

Use the repository's directory map and entry points to locate the modules
that own the target behavior. Include shared modules only when the
implementation depends on them.

For C001, record each searched root and search term. For C006 deep conformance, start from
externally reachable routes/events, not arbitrary files.
