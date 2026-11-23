# Simplification lenses

Each lens identifies a concrete simplification candidate in a matching changed
bundle. It is not a requirement to extract or inject a new abstraction. Apply
the constraint, gain, and behavior-preservation requirements in `SKILL.md`.

## User interface

- State is stored even though it can derive from existing state.
- A component or hook mixes rendering or reactive coordination with independent
  policy, reusable computation, or platform mechanics.
- Data representation conversion creates a value with a lifetime that must be
  managed.
- A shared-component prop serves one caller instead of a semantic boundary.
- A child component exists only to shorten its parent.

## Service and API

- Validation, error mapping, retries, timeouts, or pagination repeats near an
  established helper.
- A handler mixes orchestration, domain policy, and external integration.
- An interface forces unrelated implementations or fakes to adopt one method.

## Data model

- Canonical values or ordering duplicate schema and code.
- Schema and application code each claim to enforce the same rule.
- A field or table duplicates data that an existing relation or state already
  represents.

## Infrastructure and pipelines

- Resources, configuration, or pipeline steps repeat across environments.
- Identifiers, ports, timeouts, flags, or image tags must stay synchronized in
  more than one place.
- An added resource leaves sibling lifecycle or retention behavior unmodeled.

## Shared library

- An export, dependency, or consumer-specific branch exists for one consumer.
- Equivalent consumers express the same operation in competing ways.
- A wrapper or conversion became obsolete and can become direct.
