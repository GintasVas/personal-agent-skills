# Spec review passes

Run the lanes in order against the same pinned input. Each lane uses its
[checklist rules](CHECKLIST.md) and
[coverage passes](REFERENCE.md#coverage-passes). Use each rule's evidence
sources when its trigger applies.

## Lane A: Concepts, facts, and architecture

Rules: `Q002`, `Q011`, `Q012`, `Q014`, `Q018`, `Q019`, `Q023`, `Q024`.

Coverage passes: `Concept traceability`, `Dependency readiness`, `Selection and history`.

## Lane B: Behavioral testability, scope, and readability

Rules: `Q001`, `Q003`, `Q004`, `Q005`, `Q006`, `Q010`, `Q013`, `Q015`, `Q020`, `Q021`, `Q022`,
`Q025`.

Coverage passes: `Operation boundaries`, `Normativity and readability`, `Composite values`.

## Lane C: Security, writes, delivery, and conformance

Rules: `Q007`, `Q008`, `Q009`, `Q016`, `Q017`, `T001`, `T002`, `T003`, `T004`, `T005`,
and `C001` through `C006`.

Coverage passes: `Write safety`, `Verification plan`, `Open-decision consistency`.

For Q009, distinguish authentication from authorization. Check fail-closed
behavior using the applicable security rules.

## Structural results

The parent runs the validator for S001 through S013 and S900 through S902
and presents its results. Workers review behavioral rules only.
