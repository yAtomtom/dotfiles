# Design Policy

## DDD (Domain-Driven Design)
- Identify the core domain and invest development effort there
- Isolate logic per bounded context
- Verify alignment with existing bounded contexts before proposing changes

## Design by Contract (DbC)
- Define preconditions, postconditions, and invariants (class invariants, loop invariants)
- Make contracts explicit in design and implementation

## Purpose-Driven Programming
- Purpose (desired state), target (spec/constraints), and means (code) must be 1:1:1
- Never determine means before purpose is decided
- Each purpose maps to exactly one means

## Interface and Implementation Separation
- Interfaces must be separated from implementation
- Interfaces accept only the arguments they genuinely need
- Logging/notification timestamps and user info are absorbed by upper layers

## Encapsulation and Separation of Concerns
- Encapsulation means bundling data with its operating logic, not defining getters/setters
- Use encapsulation and separation of concerns as the criteria for modularity decisions

## Immutable Design
- Complete Constructor: all instance variables initialized at creation, no subsequent mutation
- Objects whose values are determined at creation (results, outputs, diffs, config schemas) enforce immutability via language mechanisms
