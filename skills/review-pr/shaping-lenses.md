# Review shaping lenses

Use applicable lenses to spot candidates. Apply the
[worker's evidence rules](agents/code-reviewer.md#review) before reporting.

## Common

- **Primitive Obsession.** A changed path uses raw values and accepts an
  invalid domain value.
- **Repeated Rules.** Copies of a rule in UI or handlers can drift. Check
  display conversions, validation, permissions, and partial policy updates
  (Shotgun Surgery).
- **Mixed Responsibilities.** UI fetches and renders, or handlers mix
  orchestration, policy, and external calls. Look for independent changes
  that the same code must absorb.
- **Public Contract Changes.** A changed signature or behavior breaks callers
  or implementations. Check promises about errors and idempotency.
- **Dependency Direction.** Platform calls bypass an existing adapter, or
  changes to framework or infrastructure details force edits to domain policy.
- **Interface Segregation.** An interface grows a method unrelated
  implementations and fakes must absorb.

## User interface

- **Redundant State.** State is stored even though existing state can derive it.
- **Unnecessary Component Split.** A child component exists only to shorten a
  file.
- **Resource Lifetime.** Representation conversion creates a resource whose
  lifetime needs manual management.

## Service and API

- **Inconsistent Endpoints.** Error mapping, logging, retrying, timeouts, or
  pagination diverge from sibling endpoints.
- **Retry Idempotency.** A retry repeats a write or other effect that must
  happen once.
- **N+1 Queries.** A loop runs a query or read port call per item where one
  set-based call would do.

## Data model

- **Redundant Data.** A column, enum, or lookup table restates data stored
  elsewhere.
- **Multiple Sources of Truth.** Schema and code both own a rule, canonical
  identifier, or ordering. Check whether each layer has a distinct purpose.
- **Nullable State.** A nullable field stands in for a missing relation or state.
- **Migration Safety.** A migration cannot safely rerun or ignores existing rows.
- **Rolling Deployment Compatibility.** Old or new code fails against the
  schema during a rolling deploy.
- **Redundant Index.** An index duplicates the prefix of an existing index.

## Infrastructure and pipelines

- **Duplicated Configuration.** Environments copy resources or steps instead
  of using an existing variable or module. Check repeated identifiers, regions,
  sizes, accounts, image tags, ports, timeouts, and flags.
- **Missing Lifecycle Policy.** A resource lacks the lifecycle, teardown, or
  retention policy of siblings.

## Shared library

- **Consumer-Specific Shared Code.** A shared prop or export exists for one
  caller, or a shared package owns consumer-specific behavior. Check where
  that behavior belongs.
- **Redundant Dependency.** A dependency duplicates functionality the package
  already provides.
