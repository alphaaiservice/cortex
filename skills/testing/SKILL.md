---
name: testing
description: "Auto-invoked when Claude works on testing tasks — test generation, coverage analysis, or test strategy. Provides test pyramid guidance, AAA structure patterns, naming conventions, mocking guidelines, and coverage targets (>80% overall, >95% critical paths, 100% new code)."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with alpha-forge plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "2.0"
---

# Testing Skill

Best practices for test generation and quality.

## Test Pyramid

```
     /  E2E  \        ← Few, slow, high confidence
    /----------\
   / Integration\     ← Moderate, medium speed
  /--------------\
 /   Unit Tests   \   ← Many, fast, focused
/==================\
```

## Unit Test Patterns

### Naming Convention
`should [expected behavior] when [condition]`

### Structure (AAA)
```
// Arrange — Set up test data and mocks
// Act — Execute the function under test
// Assert — Verify the result
```

### What to Test
- Happy path (normal inputs → expected outputs)
- Edge cases (empty, null, zero, max, min)
- Error paths (invalid inputs, failures)
- Boundary values
- State transitions

### Mocking Guidelines
- Mock external dependencies (APIs, databases, file system)
- Don't mock the thing you're testing
- Keep mocks simple and focused
- Prefer dependency injection for testability
- Reset mocks between tests

## Coverage Targets
- Overall: >80%
- Critical business logic: >95%
- New code: 100% (aim for)
- Utilities/helpers: >90%
