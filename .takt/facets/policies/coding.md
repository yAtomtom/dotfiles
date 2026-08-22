# Coding Policy

## KISS
- Question every technique; if it does not reduce bugs, drop it

## Functional
- Pure functions; take dynamic values (Time) as arguments, never hold them internally

## DRY
- Apply DRY only with proper abstraction; otherwise allow duplication
- Three similar lines beat a premature abstraction

## Raw Data Now
- Fallbacks are unnecessary and hide symptoms; never use them (`?? 'unknown'`) for required data
- Show raw data unformatted; fail fast, never hide data flow

## Comments
- State business context code cannot convey; nothing self-evident from naming/tests

## Command Execution Safety (Headless)
- No TTY and stdin is closed; every command must terminate on its own
- No watch mode, dev servers, REPLs, or prompts that wait for input
- Never pipe a command without guaranteed exit into `tail`/`head`/`less`; it hangs until EOF
- Prefer narrowly-scoped, short-lived commands

## Test Quality
- Never mock a test target's direct dependencies
- Mock only outside the test's focus; minimize mocking
