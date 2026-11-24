# Review shaping lenses

Use each lens to identify a candidate. Apply the
[worker's evidence rules](agents/code-reviewer.md#review) before reporting.

## Common

- **Primitive Obsession.** A changed path uses raw values and accepts an
  invalid domain value.
- **Shotgun Surgery.** A policy change updates one copy of a rule and leaves
  another path on the old rule.

## User interface

- **Fetching and Rendering.** A component both fetches data and renders it.
- **Repeated UI Rules.** Display-value conversion, validation, or permission
  logic repeats a shared rule.
- **Prop for One Caller.** A shared-component prop exists to serve one caller.
- **Redundant State.** State is stored even though existing state can derive it.
- **Unnecessary Component Split.** A child component exists only to shorten a
  file.
- **Bypassed Adapter.** Platform APIs bypass an existing adapter.
- **Resource Lifetime.** Representation conversion creates a resource whose
  lifetime needs manual management.

## Service and API

- **Repeated Handler Rules.** Policy or validation repeats across handlers.
- **Mixed Handler Responsibilities.** A handler combines orchestration, domain
  rules, and external calls.
- **Interface Segregation.** An interface grows a method unrelated
  implementations and fakes must absorb.
- **Inconsistent Endpoints.** Error mapping, logging, retrying, timeouts, or
  pagination diverge from sibling endpoints.
- **Retry Idempotency.** A retry repeats a write or other effect that must
  happen once.
- **N+1 Queries.** A loop runs a query or read port call once per item (N+1)
  where one set-based call would do.

## Data model

- **Redundant Data.** A column, enum, or lookup table restates data stored
  elsewhere.
- **Duplicated Domain Values.** Canonical identifiers or ordered domain values
  duplicate schema and code.
- **Nullable State.** A nullable field stands in for a missing relation or state.
- **Migration Safety.** A migration cannot safely rerun or ignores existing rows.
- **Rolling Deployment Compatibility.** Old or new code fails against the
  schema during a rolling deploy.
- **Redundant Index.** An index duplicates the prefix of an existing index.
- **Multiple Sources of Truth.** A rule has two sources of truth in schema and
  application code.

## Infrastructure and pipelines

- **Per-Environment Duplication.** Resources or steps are copied per environment
  instead of using an existing variable or module.
- **Duplicated Configuration.** Identifiers, regions, sizes, accounts, image
  tags, ports, timeouts, or flags are duplicated across configuration.
- **Missing Lifecycle Policy.** A resource lacks the lifecycle, teardown, or
  retention policy of siblings.

## Shared library

- **Export for One Consumer.** An export exists to serve one consumer.
- **Consumer Logic in Shared Code.** Consumer-specific behavior leaks into a
  shared package.
- **Breaking Signature Change.** A breaking signature change forces unrelated
  callers or implementations to change.
- **Redundant Dependency.** A dependency duplicates functionality the package
  already provides.
