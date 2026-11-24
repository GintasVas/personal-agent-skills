# Simplification lenses

Use applicable lenses to spot candidates. Apply the
[worker's evidence rules](agents/code-simplifier.md#review) before reporting.

## Common

- **Feature Envy.** Logic depends mainly on data another module owns.
- **Data Clumps.** The same fields travel together because they represent one
  concept.
- **Message Chains.** A caller navigates another module's internal objects.
- **Mixed Responsibilities.** UI rendering or reactive coordination mixes
  with independent policy, computation, platform mechanics, or workflows.
  A handler mixes orchestration, policy, and integration. Consider plain
  functions for pure work and focused hooks for reusable reactive work.
- **Dependency Direction.** A narrow input or port can free domain policy from
  framework or infrastructure details. Use adapters for browser APIs.
- **Interface Segregation.** An interface forces unrelated implementations
  or fakes to adopt one method.

## User interface

- **Redundant State.** State is stored even though it can derive from existing
  state.
- **Unnecessary Resource.** A direct value can replace a managed resource
  without changing its behavior.
- **Unnecessary Component Split.** Moving JSX, callbacks, or small helpers
  only shortens a file. Extract a child for a distinct semantic or behavioral
  boundary.

## Service and API

- **Existing Shared Helper.** Validation, error mapping, retries, timeouts, or
  pagination repeat near an established helper.

## Data model

- **Multiple Sources of Truth.** Schema and code both own a rule, canonical
  value, or ordering. Check whether each layer has a distinct purpose.
- **Redundant Data.** A field or table duplicates data that an existing relation
  or state already represents.

## Infrastructure and pipelines

- **Duplicated Configuration.** Environments repeat resources, settings, or
  pipeline steps. Check identifiers, ports, timeouts, flags, and image tags.
- **Duplicated Lifecycle Rules.** Resources repeat equivalent lifecycle or
  retention rules that can be shared.

## Shared library

- **Consumer-Specific Shared Code.** A shared prop, export, dependency, or
  branch exists for one caller. Check where that behavior belongs.
- **Inconsistent Patterns.** Equivalent consumers express the same operation
  in competing ways.
- **Redundant Indirection.** An obsolete wrapper or conversion can become
  direct.
