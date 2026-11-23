# Review shaping lenses

Use each lens to identify a candidate. Apply the evidence requirements in
`SKILL.md` before reporting.

## Common

- **Primitive Obsession.** A changed path uses raw values and accepts an
  invalid domain value.
- **Shotgun Surgery.** A policy change updates one copy of a rule and leaves
  another path on the old rule.

## User interface

- A component both fetches data and renders it.
- Display-value conversion, validation, or permission logic repeats a shared rule.
- A shared-component prop exists to serve one caller.
- State is stored even though existing state can derive it.
- A child component exists only to shorten a file.
- Platform APIs bypass an existing adapter.
- Representation conversion creates a resource whose lifetime needs manual
  management.

## Service and API

- Policy or validation repeats across handlers.
- A handler combines orchestration, domain rules, and external calls.
- An interface grows a method unrelated implementations and fakes must absorb.
- Error mapping, logging, retrying, timeouts, or pagination diverge from
  sibling endpoints.
- A loop runs a query or read port call once per item (N+1) where one
  set-based call would do.

## Data model

- A column, enum, or lookup table restates data stored elsewhere.
- Canonical identifiers or ordered domain values duplicate schema and code.
- A nullable field stands in for a missing relation or state.
- A migration cannot safely rerun or ignores existing rows.
- An index duplicates the prefix of an existing index.
- A rule has two sources of truth in schema and application code.

## Infrastructure and pipelines

- Resources or steps are copied per environment instead of using an existing
  variable or module.
- Identifiers, regions, sizes, accounts, image tags, ports, timeouts, or flags
  are duplicated across configuration.
- A resource lacks the lifecycle, teardown, or retention policy of siblings.

## Shared library

- An export exists to serve one consumer.
- Consumer-specific behavior leaks into a shared package.
- A breaking signature change forces unrelated callers or implementations to
  change.
- A dependency duplicates functionality the package already provides.
