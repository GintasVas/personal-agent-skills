# Simplification lenses

Use each lens to identify simplification candidates. Apply the
[worker's evidence rules](agents/code-simplifier.md#review) before reporting.

## Common

- **Feature Envy.** Logic depends mainly on data another module owns.
- **Data Clumps.** The same fields travel together because they represent one
  concept.
- **Message Chains.** A caller navigates another module's internal objects.

## User interface

- **Redundant State.** State is stored even though it can derive from existing
  state.
- **Mixed UI Responsibilities.** A component or hook mixes rendering or
  reactive coordination with independent policy, reusable computation, or
  platform mechanics.
- **Unnecessary Resource.** A direct value can replace a managed resource
  without changing its behavior.
- **Prop for One Caller.** A shared-component prop serves one caller instead of
  a semantic boundary.
- **Unnecessary Component Split.** A child component exists only to shorten its
  parent.

## Service and API

- **Existing Shared Helper.** Validation, error mapping, retries, timeouts, or
  pagination repeats near an established helper.
- **Mixed Handler Responsibilities.** A handler mixes orchestration, domain
  policy, and external integration.
- **Interface Segregation.** An interface forces unrelated implementations or
  fakes to adopt one method.

## Data model

- **Duplicated Domain Values.** Canonical values or ordering duplicate schema
  and code.
- **Multiple Sources of Truth.** Schema and application code each claim to
  enforce the same rule.
- **Redundant Data.** A field or table duplicates data that an existing relation
  or state already represents.

## Infrastructure and pipelines

- **Per-Environment Duplication.** Resources, configuration, or pipeline steps
  repeat across environments.
- **Duplicated Configuration.** Identifiers, ports, timeouts, flags, or image
  tags must stay synchronized in more than one place.
- **Duplicated Lifecycle Rules.** Resources repeat equivalent lifecycle or
  retention rules that can be shared.

## Shared library

- **Shared Code for One Consumer.** An export, dependency, or consumer-specific
  branch exists for one consumer.
- **Inconsistent Patterns.** Equivalent consumers express the same operation in
  competing ways.
- **Redundant Indirection.** A wrapper or conversion became obsolete and can
  become direct.
