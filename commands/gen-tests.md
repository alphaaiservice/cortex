---
description: "Auto-generate comprehensive tests for a file or module. Usage: /gen-tests <file-path> or /gen-tests --all-untested"
---

# Automated Test Generation

Generate comprehensive tests for: **$ARGUMENTS**

## Step 1: Analyze Target

1. Read the target file(s) specified in $ARGUMENTS
2. If `--all-untested`, find all source files without corresponding test files
3. Identify the testing framework already in use (Jest, Vitest, Pytest, JUnit, Go testing)
4. Understand existing test patterns in the project

## Step 2: Analyze Functions/Methods

For each function/method/class in the target:
- Identify input parameters and their types
- Map all code paths (branches, loops, early returns)
- Identify external dependencies to mock
- Determine expected outputs for each path
- Find edge cases (null, empty, boundary values, overflow)

## Step 3: Generate Test File

Create test file following project conventions:

### Test Structure
```
describe('[ModuleName]', () => {
  describe('[functionName]', () => {
    // Happy path tests
    it('should [expected behavior] when [condition]', () => {})

    // Edge cases
    it('should handle empty input', () => {})
    it('should handle null/undefined', () => {})

    // Error cases
    it('should throw [ErrorType] when [condition]', () => {})

    // Boundary tests
    it('should handle maximum/minimum values', () => {})
  })
})
```

### Test Categories to Generate
1. **Happy path** — Normal expected usage (at least 2 tests per function)
2. **Edge cases** — Empty, null, undefined, zero, max values
3. **Error handling** — Invalid inputs, network failures, timeouts
4. **Integration** — How the module interacts with dependencies
5. **Regression** — Tests for any known bugs or tricky logic

## Step 4: Mock Strategy

- Use existing mock patterns from the project
- Mock external APIs, databases, and file system
- Create fixture files if needed
- Use factory patterns for test data

## Step 5: Verify Tests

```bash
# Run the generated tests
npm test -- --testPathPattern=[test-file] 2>&1 || pytest [test-file] -v 2>&1
```

Fix any failing tests. Ensure all tests pass before finishing.

## Step 6: Coverage Report

```bash
# Check coverage for the target file
npm test -- --coverage --collectCoverageFrom='[source-file]' 2>&1 || \
pytest --cov=[module] --cov-report=term-missing [test-file] 2>&1
```

Report:
- Line coverage percentage
- Uncovered lines/branches
- Suggestions for additional tests if coverage < 80%

## Output

1. Test file(s) created and passing
2. Coverage summary
3. List of any complex logic that needs manual test verification
