# Design Policy

## DDD
- Identify the core domain and invest effort there; isolate logic per bounded context
- Verify alignment with existing bounded contexts before changing

## Design by Contract
- Define pre/postconditions and invariants (class and loop)
- Make contracts explicit in design and code

## Purpose-Driven
- Purpose (desired state), target (spec/constraints), means (code) are 1:1:1
- Never decide means before purpose; one purpose, one means

## Interfaces
- Separate interfaces from implementation; take only needed arguments
- Upper layers absorb logging/notification time and user info

## Encapsulation
- Encapsulation bundles data with its logic, not getters/setters
- Judge modularity by encapsulation and separation of concerns

## Immutability
- Complete Constructor: all instance variables set at creation, never mutated
- Values fixed at creation (results, outputs, diffs, config) enforce immutability via language
