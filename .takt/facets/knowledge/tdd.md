# TDD Workflow

## Red Phase
1. Write a failing test that defines the expected behavior
2. Run the test to confirm it fails
3. Ensure the test failure message is clear
4. Completion gate: the added test(s) FAIL

## Green Phase
1. Write the minimum implementation to pass the test
2. Run the test to confirm it passes
3. Do not add features beyond what the test requires
4. Completion gate: all tests PASS

## Refactor Phase
1. Improve code structure while keeping all tests green
2. Apply KISS and functional programming principles
3. Remove duplication only when abstraction is beneficial
4. Completion gate: all tests PASS (unchanged)
