# Spec Audit Rules

Every reported item uses one rule ID below. Its severity is the finding's `P0`, `P1`, or `P2`
priority, and its rule ID and name are the finding category. A finding requires the evidence gate
in [REFERENCE.md](REFERENCE.md). If applicability or counter-evidence remains uncertain, report a
review question instead.

## Structural

These rules are deterministic and are implemented by `scripts/audit_structure.py`.

| Rule | Severity | Applicability                  | Verified failure                                                     |
| ---- | -------- | ------------------------------ | -------------------------------------------------------------------- |
| S001 | P0       | Every audited artifact         | Pinned OpenSpec reports an ERROR not covered by S900-S902            |
| S002 | P0       | Active change                  | Missing `.openspec.yaml` or unsupported schema declaration           |
| S003 | P0       | Delta spec                     | Missing or unsupported ADDED/MODIFIED/REMOVED/RENAMED marker         |
| S004 | P0       | Each requirement               | No `#### Scenario:` or reference-data `####` table section           |
| S005 | P1       | Scenario steps                 | A scenario bullet uses an unrecognized step keyword                  |
| S006 | P1       | REMOVED or RENAMED requirement | Missing `**Reason**:`                                                |
| S007 | P1       | Change proposal                | Capability names do not equal `specs/<capability>/` folders          |
| S008 | P2       | Capability subsection          | Empty subsection does not state `(none)`                             |
| S009 | P1       | Change with `source.md`        | Missing Source, Initial Prompt, reference section, or prompt content |
| S010 | P2       | Local Markdown link            | Target path does not exist                                           |
| S011 | P1       | Active changes inventory       | Orphan change directory is not registered by `.openspec.yaml`        |
| S012 | P2       | Audited text path              | Repository ASCII validator fails                                     |
| S013 | P2       | Audited path                   | Repository naming validator fails                                    |

### Optional house style

Use `--house-style` when the project requires S006, S008, S009, and S012.
This option also requires a proposal's capabilities list when delta folders
exist (S007) and accepts a reference-data table in place of a scenario (S004).
Use `--naming-validator` with a trusted script to enable S013.

With `--house-style`, apply these upstream exceptions.

| Rule | Verdict            | Upstream message                                                                            |
| ---- | ------------------ | ------------------------------------------------------------------------------------------- |
| S900 | ACCEPTED_EXCEPTION | Requirement must contain SHALL or MUST                                                      |
| S901 | ACCEPTED_EXCEPTION | Requirement must include at least one scenario when reference-data tables provide structure |
| S902 | ACCEPTED_EXCEPTION | Main spec lacks upstream `## Purpose` wrapper but follows the repository documentation map  |

MUST/SHALL presence or absence is accepted. Plain `####` reference-data headings backed by
tables are accepted. Never convert S900-S902 into an error.

## Quality

| Rule                                   | Severity | Applicability trigger                                                                                                                             | Required authoritative search                                                                         |
| -------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Q001 Ambiguous language                | P1       | Requirement uses an undefined qualifier such as fast, appropriate, as needed, etc., should probably, or handle gracefully                         | Requirement, linked general rule, domain doc                                                          |
| Q002 Undefined term                    | P0       | A domain or technical term is introduced or controls observable behavior without one consistent definition                                        | Target definitions, domain/context docs, data dictionary, main/open-PR concept inventory              |
| Q003 Subjective outcome                | P1       | Acceptance depends on user-friendly, reasonable, intuitive, or another unmeasurable judgment                                                      | Requirement and linked flow                                                                           |
| Q004 Non-testable behavior             | P1       | Requirement claims behavior with no observable input, state transition, output, or rejection                                                      | Requirement, scenarios, linked general rule                                                           |
| Q005 Missing rejection                 | P1       | Delivered operation accepts mutable external input with a realistic invalid or conflicting case                                                   | Requirement, sibling scenarios, general validation/error rules                                        |
| Q006 Boundary gap                      | P1       | In-scope numeric/date/range/pagination or nullable input has an identified boundary that changes behavior                                         | Requirement, inherited main requirement, general rules, data dictionary                               |
| Q007 Failure gap                       | P1       | Delivered operation depends on a named external or fallible dependency                                                                            | Requirement, design, sibling change owning the dependency                                             |
| Q008 Repeatability gap                 | P1       | Delivered write can be retried, reseeded, replayed, duplicated, concurrent, or ordered differently                                                | Requirement, idempotency/concurrency scenarios, design                                                |
| Q009 Security gap                      | P0       | Shipped operation handles authorization, tenant scope, secrets, PII, or cross-context identity                                                    | Main spec, authorization spec, proposal/design dependency, general error rules                        |
| Q010 Empty-state gap                   | P2       | List/create/update behavior can operate on zero records or empty selection                                                                        | Requirement, scenarios, data dictionary constraints                                                   |
| Q011 Implementation leakage            | P2       | Behavioral spec prescribes paths, types, providers, credential/storage keys, context wiring, pass-through strings, SQL, or migrations             | Documentation map and linked design                                                                   |
| Q012 Authority violation               | P1       | Active behavior cites archive as live authority or duplicates a general rule inconsistently                                                       | Documentation map, main spec, general rule                                                            |
| Q013 Invariant gap                     | P1       | Requirement claims uniqueness, cardinality, ownership, conservation, or another always-true business invariant                                    | Requirement, scenarios, design, schema/model constraints, implementation tests                        |
| Q014 Undefined fact contract           | P0       | A read, display, or write requires a fact whose owner, source, format, selection, null, or clear semantics affect behavior                        | Domain/context docs, data dictionary/model, create/update flow, linked sibling change, implementation |
| Q015 Scope prohibition conflict        | P1       | A normative prohibition makes declared non-goal or sibling-owned future behavior permanently invalid                                              | Source, proposal/design non-goals, requirement, sibling flow/change                                   |
| Q016 Unresolved decision contradiction | P1       | A requirement or task assumes one answer while the same change marks that meaning, owner, source, or rule unresolved                              | Source, proposal open decisions, design, delta spec, tasks                                            |
| Q017 Verification plan gap             | P1       | Active-change tasks add production behavior without applicable behavior-test tasks                                                                | Tasks, delivered operations, repository verification standard                                         |
| Q018 Identifier contract gap           | P1       | A displayed, accepted, or persisted identifier lacks source, format, generation, uniqueness, stability, or legacy semantics                       | Key types, data dictionary, schema/API contracts, migration strategy, linked prerequisite             |
| Q019 State conflation                  | P1       | One status or state term combines distinct lifecycle, billing, account, eligibility, or access meanings                                           | Owning contexts, value objects/enums, domain docs, sibling screens/flows                              |
| Q020 Operation conflation              | P1       | A read or display is treated as a state-changing action, or actor/session context substitutes for the action target                               | Requirement/flow, action-owning capability, side-effect contract, design                              |
| Q021 Optional normative behavior       | P1       | `MAY` or conditional wording permits incompatible outcomes for behavior the change claims to deliver                                              | Requirement, scenarios, source decision, proposal/design open decisions                               |
| Q022 Redundant negative specification  | P2       | Requirement enumerates unrelated absent behavior or restates a positive outcome without a durable safety/domain invariant                         | Requirement, positive scenarios, proposal/design scope, sibling ownership                             |
| Q023 Dependency readiness gap          | P1       | Required behavior depends on a store, read model, event, account mode, or sibling capability that is neither shipped nor an explicit prerequisite | Linked dependency, open PRs, implementation roots, proposal/design                                    |
| Q024 Selection/history ambiguity       | P1       | Multiple facts may qualify but the spec does not choose current/latest/original/scheduled/actual or define missing behavior                       | Data dictionary/model, lifecycle rules, read flow, scenarios                                          |
| Q025 Opaque scenario notation          | P2       | Symbolic placeholders or compressed notation hide business meaning or make acceptance criteria hard to distinguish                                | Scenario, definitions, linked flow, concrete domain examples                                          |

### Quality tie-breakers

- Apply the non-goal exclusion and Q015/T003 exception from the SKILL.md contract.
- Apply the complete open-PR authority and prerequisite rule from REFERENCE.md.
- Q002 and Q014 are P0 only after the evidence gate verifies that the undefined meaning or
  missing fact contract controls observable behavior and the authoritative search is closed. If a
  definition or owner may exist in an unavailable source, report a review question.
- Q021 does not reject every `MAY`. It applies when allowed alternatives produce materially
  different observable behavior and the target claims that behavior is delivered. Route behavior
  that is required while its controlling decision remains TBD to Q016 instead.
- Negative requirements are valid for durable security, privacy, safety, unchanged-state, and
  domain invariants. Q022 applies to unrelated absence lists and redundant negatives with no
  identified invariant; Q015 applies when the negative also conflicts with sibling ownership.
- Established domain abbreviations and short variables in formulas are not Q025. Apply it when a
  scenario forces readers to decode placeholders instead of showing the business distinction.
- A proposed dependency satisfies Q023 only when it is explicitly linked as a prerequisite and the
  target does not claim to be independently implementation-ready.
- Active deltas describe proposed behavior. Existing code mismatch is not conformance drift.
- A working link that explicitly inherits an applicable requirement satisfies absence checks.
  If applicability to the new operation is unclear, report a review question.
- Missing behavior is a finding only when the authoritative source set is closed and every
  path searched is listed. Otherwise report a review question.
- Do not demand rejection, boundary, authorization, empty-state, retry, or failure scenarios unless
  the delivered operation has the corresponding input, actor, state, write, or dependency.
- For fixed reference data, inspect exact values, cardinality, materialization timing, and repeat
  seeding. Do not invent user-input validation or API failures when no such surface is delivered.
- A requirement asserting "exactly one" is not satisfied by a convention that merely reads or
  writes one canonical identifier if additional records remain possible.
- Schema names needed to define observable data behavior are not automatically Q011. Exact
  migration numbers, source files, framework names, and storage expressions are.

## Conformance

Axis C applies only to main specs describing shipped behavior.

| Rule | Severity | Verified failure                                                                       |
| ---- | -------- | -------------------------------------------------------------------------------------- |
| C001 | P1       | Requirement has no implementation after all fixed code roots are searched              |
| C002 | P1       | Spec and code use different API method, path, request, response, or status             |
| C003 | P1       | Spec and implementation disagree on field type, nullability, cardinality, or ownership |
| C004 | P1       | Implemented sequence or branch contradicts a scenario or authoritative flow            |
| C005 | P2       | Spec and code use conflicting domain/event names that change meaning                   |
| C006 | P1       | Deep-conformance only: externally observable code behavior has no backing requirement  |

C001 requires both spec evidence and a complete search manifest. C006 never runs by default.
Internal helpers, migrations, and framework plumbing are not externally observable behavior.

## Traceability

Axis D applies only to a targeted change with `source.md`, or when explicitly requested.

| Rule | Severity | Verified failure                                                                |
| ---- | -------- | ------------------------------------------------------------------------------- |
| T001 | P1       | A discrete source ask has no proposal or delta requirement                      |
| T002 | P1       | A delta requirement has no source ask or listed reference                       |
| T003 | P1       | An explicit non-goal appears as an ADDED requirement                            |
| T004 | P2       | Source terminology is silently renamed without a documented refinement          |
| T005 | P2       | A high-impact change has no references and the source claims external authority |

T001-T005 require a numbered ask-to-requirement mapping. "Large", "high-risk", and
"pragmatically" are not applicability tests. T005 applies only when the source itself cites or
depends on external policy, regulation, contract, PRD, or architecture but provides no reference.
