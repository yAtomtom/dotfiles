# Coding Policy

## KISS Principle
- Question the necessity of every technique before applying it
- If a technique does not reduce bugs, do not enforce it

## Functional Programming
- Methods should respect pure functions
- Dynamic values (Time, etc.) are received as arguments, not held internally

## DRY Principle with Abstraction
- Apply DRY only when proper abstraction is achievable
- If abstraction yields little benefit, allow duplication
- Three similar lines of code is better than a premature abstraction

## Error Detection (Raw Data Now)
- Fallbacks hide symptoms; they are unnecessary
- Display raw data without unnecessary formatting
- Never use fallback values (`?? 'unknown'`) for required data
- Fail fast on errors; do not hide data flow

## Comments
- Write concise business use-case context that code cannot convey
- Do not add comments for things self-evident from naming or tests

## Command Execution Safety (Headless)
- The shell has no TTY and stdin is closed; every command must terminate on its own
- Do not run watch mode, dev servers, REPLs, or interactive prompts that wait for input
- Do not pipe a command without a guaranteed exit into `tail`/`head`/`less`; the pipe stays silent until upstream EOF and can hang indefinitely
- Prefer narrowly-scoped, short-lived commands over broad ones

## Test Quality
- Test targets' direct dependencies are not mocked
- Mocks/stubs are used only for concerns outside the test's focus
- Mock only what is outside the test's direct concern; minimize mocking
