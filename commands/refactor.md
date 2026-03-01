---
description: "AI-powered code refactoring: extract functions, decompose modules, rename symbols, fix code smells, enforce patterns. Usage: /refactor <file-or-module> [--type=extract|decompose|rename|cleanup] [--yes]"
---

# AI-Powered Code Refactoring

Refactor target: **$ARGUMENTS**

Parse $ARGUMENTS to extract:
- **target**: file path or directory path (required)
- **--type**: refactoring focus — `extract`, `decompose`, `rename`, `cleanup`, or `all` (default: `all`)
- **--yes**: skip confirmation prompt and apply all recommended refactorings automatically
- **--dry-run**: analyze and plan only, do not apply any changes
- **--aggressive**: lower thresholds (functions >30 lines, files >300 lines, nesting >3)
- **--conservative**: raise thresholds (functions >80 lines, files >800 lines, nesting >5)

If no target is provided, default to the current working directory.

---

## Step 0: Pre-Flight Validation

Before doing anything, validate the environment:

```bash
# Verify target exists
ls -la $TARGET 2>/dev/null || echo "ERROR: Target not found"

# Detect project language(s)
# Python: look for .py files, pyproject.toml, requirements.txt
# TypeScript: look for .ts/.tsx files, tsconfig.json, package.json
# JavaScript: look for .js/.jsx files, package.json
# Go: look for .go files, go.mod
# Rust: look for .rs files, Cargo.toml

# Check for git — we need it for safe rollback
git status 2>/dev/null || echo "WARNING: Not a git repo — no rollback safety net"

# Stash any uncommitted changes if present (safety)
git stash list 2>/dev/null
```

Detect the project language and testing framework:
- **Python**: pytest, unittest, ruff, mypy
- **TypeScript/JavaScript**: jest, vitest, mocha, eslint, tsc
- **Go**: go test, golangci-lint
- **Rust**: cargo test, cargo clippy

Store the detected language and toolchain for later steps.

---

## Step 1: Analyze Target Code

### 1a: File Discovery

If the target is a single file, analyze that file. If it is a directory, discover all source files:

```bash
# For Python projects
find $TARGET -name "*.py" -not -path "*/__pycache__/*" -not -path "*/.venv/*" -not -path "*/node_modules/*"

# For TypeScript projects
find $TARGET -name "*.ts" -o -name "*.tsx" | grep -v node_modules | grep -v dist | grep -v .next

# For Go projects
find $TARGET -name "*.go" -not -path "*/vendor/*"
```

### 1b: Code Metrics Calculation

For EACH file in scope, calculate these metrics:

**Lines of Code (LOC)**
- Total lines
- Code lines (excluding blanks and comments)
- Comment lines
- Blank lines

**Function/Method Analysis**
- Count of functions/methods
- Length of each function (lines)
- List of functions exceeding threshold (default: 50 lines)
- Average function length

**Cyclomatic Complexity**
- Count conditional branches: `if`, `elif`, `else`, `for`, `while`, `try`, `except`, `case`, `&&`, `||`, ternary
- Calculate per-function complexity
- Flag functions with complexity > 10

**Nesting Depth**
- Track indentation levels within each function
- Flag blocks nested deeper than 4 levels (default threshold)
- Record maximum nesting depth and location

**Class Analysis (OOP languages)**
- Number of methods per class
- Number of instance variables
- Flag god classes (>10 methods or >15 instance variables)
- Inheritance depth

**Import/Dependency Analysis**
- Count imports per file
- Identify circular imports
- Find unused imports
- Map dependency graph between modules

**Duplication Detection**
- Use Grep to find repeated code blocks (>5 identical consecutive lines)
- Calculate duplication percentage
- Identify the source and copy locations

### 1c: Code Smell Detection

Scan for these specific code smells and anti-patterns:

**Size Smells**
- Large File: file exceeds 500 lines (configurable)
- Long Function: function exceeds 50 lines (configurable)
- Long Parameter List: function has more than 5 parameters
- God Class: class with too many responsibilities

**Complexity Smells**
- Deep Nesting: code nested more than 4 levels deep
- Complex Conditional: if/elif chain with more than 4 branches
- Complex Boolean: expression with more than 3 boolean operators
- Switch on Type: isinstance/typeof chains that should be polymorphism

**Naming Smells**
- Single-letter variables (outside of loops/comprehensions): `x`, `a`, `tmp`
- Inconsistent naming conventions (mixed snake_case and camelCase)
- Overly abbreviated names: `mgr`, `ctx`, `impl`, `proc`
- Names that do not communicate intent: `data`, `result`, `info`, `temp`, `stuff`
- Boolean variables not prefixed with is/has/can/should (Python convention)

**Structural Smells**
- Dead Code: functions never called, unreachable code after return/raise
- Unused Imports: imported modules not referenced anywhere in the file
- Unused Variables: assigned but never read
- Duplicate Code: identical or near-identical blocks appearing multiple times
- Feature Envy: function that uses more methods/data from another class than its own
- Middle Man: class that only delegates to another class
- Data Clump: same group of variables passed together repeatedly

**Logic Smells**
- Unnecessary else after return/raise/continue/break
- Double negation: `not not_empty`, `!(!valid)`
- Redundant condition: condition always true/false based on prior checks
- Empty except/catch blocks (swallowing errors)
- Bare except/catch (catching all exceptions without specificity)
- Magic numbers: numeric literals without named constants
- Hardcoded strings: URLs, file paths, messages inline instead of constants

**Python-Specific Smells**
- Using `type()` instead of `isinstance()`
- Mutable default arguments: `def foo(items=[])`
- Global variable mutations
- Using `import *` (wildcard imports)
- Not using context managers for resources (files, connections)
- String concatenation in loops (instead of join)
- Manual iteration with index instead of enumerate

**TypeScript/JavaScript-Specific Smells**
- Using `any` type (TypeScript)
- Using `var` instead of `let`/`const`
- Missing `await` on async calls
- Callback hell (deeply nested callbacks instead of async/await)
- Using `==` instead of `===`
- Console.log left in production code
- Inconsistent export style (default vs named)

**Alpha AI Architecture Smells**
- api/ layer containing business logic (should be thin controllers)
- services/ layer making direct DB queries (should use repositories)
- repositories/ layer importing from services (wrong direction)
- Cross-layer imports violating: api/ -> services/ -> repositories/ -> models/
- JWT tokens stored in localStorage/sessionStorage (must be HTTP-Only cookies)
- Direct OpenAI/Anthropic SDK usage (should use LiteLLM gateway)

---

## Step 2: Detect Refactoring Opportunities

Based on the analysis from Step 1, categorize all findings into actionable refactoring opportunities.

### Extract Refactorings (--type=extract)

**Extract Function**
- Identify: A contiguous block of code within a function that performs a single cohesive operation
- Criteria: Block is >10 lines, has a clear single purpose, uses few variables from surrounding scope
- Action: Move block into a new function, pass needed variables as parameters, return results
- Example detection pattern: Long functions with comment headers like "# Step 1: Validate input" indicating logical sections

**Extract Class**
- Identify: Groups of related methods and data that form a cohesive unit within a larger class
- Criteria: Subset of methods/fields that are always used together, independent of other class members
- Action: Create new class with the related members, delegate from original class

**Extract Variable**
- Identify: Complex expressions used multiple times or expression too complex to understand at a glance
- Criteria: Expression appears 2+ times, or expression has 3+ operations
- Action: Assign to a well-named variable, replace all occurrences

**Extract Constant**
- Identify: Magic numbers, hardcoded strings, repeated literal values
- Criteria: Numeric literal (not 0 or 1) used in logic, string literal used as key/URL/path
- Action: Create named constant at module/class level, replace all occurrences
- Naming: ALL_CAPS_SNAKE_CASE for Python, UPPER_CASE for TypeScript constants

**Extract Interface/Protocol**
- Identify: Concrete class used as a dependency in multiple places
- Criteria: Class is imported by 3+ other modules, could be replaced with abstraction
- Action: Create Protocol (Python) or Interface (TypeScript), update type hints/annotations

### Decompose Refactorings (--type=decompose)

**Decompose Module**
- Identify: Files exceeding 500 lines with multiple distinct responsibilities
- Criteria: File contains classes/functions that can be grouped into 2+ cohesive submodules
- Action: Split file into focused modules, create `__init__.py` or `index.ts` to maintain public API
- Strategy:
  1. Group related functions/classes by shared data or purpose
  2. Create new files named after the responsibility (e.g., `validators.py`, `serializers.py`)
  3. Move code into new files
  4. Update `__init__.py`/`index.ts` to re-export everything (preserves backward compatibility)
  5. Update all imports throughout the codebase

**Decompose Function**
- Identify: Functions exceeding 50 lines with multiple logical sections
- Criteria: Function has distinct phases (validate, transform, persist), has multiple comment blocks
- Action: Extract each phase into a helper function, main function becomes orchestrator
- Rule: Each extracted helper should be <30 lines and have a single responsibility

**Decompose Conditional**
- Identify: Complex if/elif/else chains or switch/case with >4 branches
- Criteria: Each branch performs a similar operation but with different parameters
- Action: Replace with strategy pattern (dict mapping), lookup table, or polymorphism
- Python example: Replace `if/elif` chain with `handlers = {"case1": fn1, "case2": fn2}; handlers[key]()`
- TypeScript example: Replace switch with `Record<string, () => void>` lookup

**Decompose Class**
- Identify: God classes with >10 methods or >15 instance variables
- Criteria: Methods cluster into 2+ groups that operate on different subsets of instance variables
- Action: Extract responsibility into separate classes, use composition in original class

### Structural Refactorings (--type=rename or general)

**Move Function**
- Identify: Function defined in module A but primarily operates on data from module B
- Criteria: Function imports 3+ things from another module, or is only called from one other module
- Action: Move function to the module where it logically belongs, update all imports
- Alpha AI rule: Respect layer segregation — api/ -> services/ -> repositories/ -> models/

**Rename Symbol**
- Identify: Variables, functions, classes, or methods with unclear or misleading names
- Criteria: Single-letter names, abbreviations, names that do not describe purpose or behavior
- Action: Rename to descriptive name, update ALL references across the codebase
- Conventions:
  - Python: snake_case for functions/variables, PascalCase for classes, ALL_CAPS for constants
  - TypeScript: camelCase for functions/variables, PascalCase for classes/interfaces/types
  - Booleans: prefix with is/has/can/should/will (e.g., `is_valid`, `hasPermission`)
  - Functions: use verb+noun pattern (e.g., `calculate_total`, `fetchUserData`)

**Replace Inheritance with Composition**
- Identify: Class hierarchy where child class only uses a fraction of parent class functionality
- Criteria: Child overrides most parent methods, or inherits methods it never uses
- Action: Remove inheritance, inject parent as dependency, delegate specific methods

**Introduce Interface/Protocol**
- Identify: Concrete class dependency that makes testing difficult
- Criteria: Class is instantiated directly in other classes (tight coupling)
- Action: Extract Protocol/Interface, inject dependency, enable mocking in tests

**Flatten Nesting**
- Identify: Code blocks nested >4 levels deep
- Criteria: Multiple levels of if/for/while/try nesting
- Action: Use early returns (guard clauses), extract inner blocks to functions, invert conditions

### Cleanup Refactorings (--type=cleanup)

**Remove Dead Code**
- Identify: Functions never called, imports never used, unreachable code after return/raise/break
- Action: Delete the dead code entirely
- Verification: Grep across entire codebase to confirm no references exist before deletion
- Caution: Check for dynamic references (getattr, reflection, string-based imports) before removing

**Simplify Logic**
- Unnecessary else after return: `if cond: return X; else: return Y` -> `if cond: return X; return Y`
- Double negation: `not not_empty` -> `is_empty` / `empty`
- Redundant conditions: `if x > 0: if x > 5:` -> `if x > 5:`
- Boolean comparison: `if flag == True:` -> `if flag:`
- Ternary simplification: `x if x else default` -> `x or default`
- Unnecessary pass: Remove `pass` from non-empty blocks
- Simplify comprehensions: Replace verbose loops with list/dict comprehensions where readable

**Fix Naming Conventions**
- Python: Enforce snake_case for functions/variables, PascalCase for classes
- TypeScript: Enforce camelCase for functions/variables, PascalCase for classes/interfaces
- Go: Enforce exported (PascalCase) vs unexported (camelCase) naming
- Check consistency within each file and across the module

**Remove Duplication (DRY)**
- Identify: Identical or near-identical code blocks (>5 lines matching at >80% similarity)
- Action: Extract common code into shared utility function
- Strategy: Parameterize differences, create generic function that handles all cases
- Location: Place shared utilities in a `utils/` or `common/` module

**Clean Up Imports**
- Remove unused imports
- Sort imports (stdlib -> third-party -> local for Python; external -> internal for TS)
- Group related imports
- Remove wildcard imports (`from module import *`)

**Remove Commented-Out Code**
- Identify: Large blocks of commented-out code (>5 consecutive commented lines that look like code)
- Action: Delete them — version control has the history
- Preserve: Comment blocks that explain WHY something is done (documentation comments)

---

## Step 3: Present Refactoring Plan

Compile all findings from Steps 1-2 into a structured refactoring plan.

### Metrics Summary Table

```markdown
# Refactoring Plan: [target path]
**Generated**: [date]
**Language**: [detected language]
**Files Analyzed**: [count]

## Code Metrics (Before Refactoring)

| Metric                    | Value     | Threshold   | Status |
|---------------------------|-----------|-------------|--------|
| Total Lines of Code       | [n]       | —           | —      |
| Files in Scope            | [n]       | —           | —      |
| Largest File (LOC)        | [n] lines | < 500/file  | OK/WARN |
| Max Function Length        | [n] lines | < 50 lines  | OK/WARN |
| Avg Function Length        | [n] lines | < 25 lines  | OK/WARN |
| Max Nesting Depth          | [n]       | < 4 levels  | OK/WARN |
| Max Cyclomatic Complexity  | [n]       | < 10/func   | OK/WARN |
| Unused Imports             | [n]       | 0           | OK/WARN |
| Dead Functions             | [n]       | 0           | OK/WARN |
| Code Duplication           | [n]%      | < 5%        | OK/WARN |
| Magic Numbers              | [n]       | 0           | OK/WARN |
| God Classes                | [n]       | 0           | OK/WARN |
| Long Parameter Lists       | [n]       | 0           | OK/WARN |
| Layer Violations           | [n]       | 0           | OK/WARN |
```

### Code Smells Summary

```markdown
## Code Smells Detected

| Severity | Category    | Count | Description                          |
|----------|-------------|-------|--------------------------------------|
| HIGH     | Size        | [n]   | Large files, long functions           |
| HIGH     | Complexity  | [n]   | Deep nesting, complex conditionals    |
| MEDIUM   | Naming      | [n]   | Unclear names, convention violations  |
| MEDIUM   | Structure   | [n]   | Dead code, duplication, feature envy  |
| LOW      | Logic       | [n]   | Simplifiable patterns, redundancy     |
| LOW      | Style       | [n]   | Import ordering, commented-out code   |
```

### Proposed Refactorings List

```markdown
## Proposed Refactorings

### HIGH Priority
| #  | Type          | Description                                      | Location        | Risk   | Benefit                |
|----|---------------|--------------------------------------------------|-----------------|--------|------------------------|
| 1  | [type]        | [what will be done]                              | [file:line]     | Low    | [readability/etc]      |
| 2  | [type]        | [what will be done]                              | [file:line]     | Medium | [maintainability/etc]  |

### MEDIUM Priority
| #  | Type          | Description                                      | Location        | Risk   | Benefit                |
|----|---------------|--------------------------------------------------|-----------------|--------|------------------------|
| 3  | [type]        | [what will be done]                              | [file:line]     | Low    | [readability/etc]      |

### LOW Priority
| #  | Type          | Description                                      | Location        | Risk   | Benefit                |
|----|---------------|--------------------------------------------------|-----------------|--------|------------------------|
| 4  | [type]        | [what will be done]                              | [file:line]     | Low    | [style/consistency]    |
```

For each refactoring, include:
- **Type**: Extract Function, Decompose Module, Rename Symbol, Remove Dead Code, etc.
- **Description**: Specific action to be taken (e.g., "Extract validation logic from `process_order()` into `validate_order_input()`")
- **Location**: Exact file path and line range
- **Risk**: Low (safe rename/cleanup), Medium (structural change), High (cross-module move)
- **Benefit**: Which quality attribute improves (readability, maintainability, testability, performance)

### User Confirmation

If `--yes` flag is NOT present:
- Display the complete refactoring plan
- Ask: "Which refactorings should I apply? Enter numbers (e.g., 1,2,5-8), 'all', or 'none':"
- Wait for user response
- Proceed only with confirmed refactorings

If `--yes` flag IS present:
- Apply all proposed refactorings in priority order
- Skip confirmation prompt

If `--dry-run` flag is present:
- Display the plan
- Stop here — do not proceed to Step 4

---

## Step 4: Execute Refactorings

### Execution Strategy

Apply refactorings ONE AT A TIME in this order:
1. **Cleanup** first (remove dead code, unused imports — reduces noise for other refactorings)
2. **Rename** second (fix naming before extracting, so new functions get good names)
3. **Extract** third (pull out functions/classes/variables)
4. **Decompose** last (split files — most invasive, do after all internal improvements)

### For Each Approved Refactoring:

#### Phase A: Prepare
1. Record the current state of affected files (for rollback reference)
2. Identify all files that will need import/reference updates

#### Phase B: Execute
Apply the code change using Read and Write tools:

**For Extract Function:**
```
1. Read the target function
2. Identify the code block to extract
3. Determine parameters needed (variables from outer scope used in the block)
4. Determine return values (variables modified in the block and used after it)
5. Create the new function with proper signature, docstring, and type hints
6. Replace the original block with a call to the new function
7. Add import if the new function is in a different file
```

**For Decompose Module:**
```
1. Read the entire file
2. Group functions/classes by responsibility
3. Create new files for each responsibility group
4. Move code to new files with proper imports
5. Create/update __init__.py or index.ts with re-exports
6. Use Grep to find ALL files importing from the original module
7. Update every import statement across the codebase
```

**For Rename Symbol:**
```
1. Use Grep to find ALL occurrences of the symbol across the entire codebase
2. Verify each occurrence is actually the target symbol (not a substring match)
3. Replace in the definition file first
4. Replace in all importing/referencing files
5. Update docstrings and comments that reference the old name
6. Update test files that reference the old name
```

**For Remove Dead Code:**
```
1. Use Grep to confirm the symbol has zero references in the codebase
2. Check for dynamic references: getattr(), importlib, string-based lookups
3. Check for framework magic: decorators like @app.route, @pytest.fixture
4. Only delete if truly unreferenced
5. Remove associated imports that become unused after deletion
```

**For Simplify Logic:**
```
1. Read the code block
2. Apply the simplification transformation
3. Verify the logic is semantically equivalent
4. Write the simplified version
```

**For Fix Naming:**
```
1. Identify all names violating convention in the file
2. For each name, use Grep to find all references
3. Generate the correct name following conventions
4. Replace ALL occurrences (definition + references + imports + tests)
```

#### Phase C: Update References
After each code change:
1. Use Grep to find ALL files that import from or reference modified modules
2. Update import paths if files were moved or renamed
3. Update function call signatures if parameters changed
4. Update type hints if types were renamed or moved

#### Phase D: Verify
After each individual refactoring:

```bash
# Run project tests
# Python
pytest --tb=short -q 2>&1 || python -m pytest --tb=short -q 2>&1

# TypeScript/JavaScript
npm test 2>&1 || npx jest --passWithNoTests 2>&1 || npx vitest run 2>&1

# Go
go test ./... 2>&1

# Rust
cargo test 2>&1
```

```bash
# Run linter
# Python
ruff check . 2>&1 || flake8 . 2>&1

# TypeScript
npx tsc --noEmit 2>&1 || npx eslint . 2>&1

# Go
golangci-lint run 2>&1

# Rust
cargo clippy 2>&1
```

**If tests fail after a refactoring:**
1. Analyze the failure — is it a genuine bug introduced, or a test that needs updating?
2. If test import/reference needs updating: fix the test import, re-run
3. If the refactoring genuinely broke behavior: REVERT that specific refactoring entirely
4. Report the failure and move on to the next refactoring
5. NEVER change test assertions or test logic to make tests pass — refactoring is behavior-preserving

**If linter reports new errors:**
1. Fix linting issues (missing imports, formatting, unused variables from the refactoring)
2. Re-run linter to confirm clean
3. If linter issues cannot be resolved without changing behavior, revert the refactoring

#### Phase E: Record
After successful verification:
- Log the refactoring as applied
- Record before/after metrics for the affected code
- Note any test updates that were needed

---

## Step 5: Post-Refactoring Verification

After ALL approved refactorings are applied:

### 5a: Full Test Suite

```bash
# Run complete test suite (not just affected tests)
# Python
pytest -v 2>&1 || python -m pytest -v 2>&1

# TypeScript/JavaScript
npm test 2>&1

# Go
go test ./... -v 2>&1
```

### 5b: Full Lint Check

```bash
# Python
ruff check . 2>&1 && mypy . 2>&1

# TypeScript
npx tsc --noEmit 2>&1 && npx eslint . 2>&1

# Go
golangci-lint run ./... 2>&1

# Rust
cargo clippy -- -D warnings 2>&1
```

### 5c: Recalculate Metrics

Re-run the same metrics from Step 1 on the refactored code:
- Lines of Code per file
- Max function length
- Max nesting depth
- Cyclomatic complexity
- Code duplication percentage
- Unused imports count
- Dead code count

### 5d: Import Integrity Check

```bash
# Verify no broken imports — Python
python -c "import [module]" 2>&1 || echo "BROKEN IMPORT"

# Verify no broken imports — TypeScript
npx tsc --noEmit 2>&1

# Check for circular imports — Python
# Use a targeted grep to look for cross-references between the split modules
```

### 5e: Alpha AI Architecture Compliance

If this is an Alpha AI project (detected by presence of standard directory structure):
- Verify layer segregation is maintained: api/ -> services/ -> repositories/ -> models/
- Verify no new cross-layer imports were introduced
- Verify auth patterns still use HTTP-Only cookies (not localStorage)
- Verify no direct LLM SDK usage was introduced (use LiteLLM gateway)

---

## Step 6: Output Summary

### Success Report

```
+==============================================================+
|  REFACTORING COMPLETE: [target]                              |
+==============================================================+
|  Refactorings Applied: [count] / [total proposed]            |
|  +-- Extract: [n]                                            |
|  +-- Decompose: [n]                                          |
|  +-- Rename: [n]                                             |
|  +-- Cleanup: [n]                                            |
|  +-- Structural: [n]                                         |
|                                                              |
|  Refactorings Skipped: [count]                               |
|  +-- User declined: [n]                                      |
|  +-- Failed (reverted): [n]                                  |
|                                                              |
|  Metrics Improvement:                                        |
|  +-- LOC: [before] -> [after] ([delta])                      |
|  +-- Largest File: [before] -> [after] lines                 |
|  +-- Max Function Length: [before] -> [after] lines          |
|  +-- Max Nesting Depth: [before] -> [after] levels           |
|  +-- Cyclomatic Complexity: [before] -> [after]              |
|  +-- Duplication: [before]% -> [after]%                      |
|  +-- Unused Imports: [before] -> [after]                     |
|  +-- Dead Functions: [before] -> [after]                     |
|  +-- Code Smells: [before] -> [after]                        |
|                                                              |
|  Tests: All [n] passing                                      |
|  Linter: Clean (0 errors, 0 warnings)                       |
+==============================================================+
```

### Detailed Change Log

```markdown
## Changes Applied

### 1. [Refactoring Type]: [Description]
- **File**: [file path]
- **Lines**: [before range] -> [after range]
- **What changed**: [specific description]
- **Why**: [code smell or metric it addressed]

### 2. [Refactoring Type]: [Description]
...
```

### Failed Refactorings (if any)

```markdown
## Failed Refactorings (Reverted)

### 1. [Refactoring Type]: [Description]
- **File**: [file path]
- **Reason**: [why it failed — test failure details, import error, etc.]
- **Recommendation**: [manual steps the developer could take instead]
```

### Recommendations for Future Work

```markdown
## Recommendations

### Manual Refactorings Needed
These require human judgment and cannot be safely automated:
1. [description] — [file:line] — [why it needs human review]

### Architectural Improvements
These are larger structural changes beyond single-file refactoring:
1. [description] — [affected modules] — [estimated effort]

### Next Steps
- Run `/gen-tests [file]` to add tests for newly extracted functions
- Run `/code-review --staged` to verify refactoring quality
- Run `/health-check` to see overall project improvement
```

---

## Safety Rules (MUST FOLLOW)

These rules are non-negotiable and override all other instructions:

1. **NEVER change behavior.** Refactoring MUST be behavior-preserving. If a change alters any observable output, return value, side effect, or error behavior — it is NOT refactoring, it is a bug. Revert immediately.

2. **One refactoring at a time.** Apply a single refactoring, verify tests pass, then proceed to the next. NEVER batch multiple refactorings before testing.

3. **Update ALL references.** When moving or renaming code, use Grep to find EVERY reference across the ENTIRE codebase. Missing an import update will break the build.

4. **Preserve test logic.** Update test imports and references as needed, but NEVER modify test assertions, expected values, or test logic. Tests are the contract that proves behavior is preserved.

5. **Follow project patterns.** Match the existing code style, naming conventions, import patterns, and directory structure. Do not impose a new style during refactoring.

6. **Alpha AI layer rules.** If the project follows Alpha AI architecture, enforce: api/ -> services/ -> repositories/ -> models/. NEVER introduce a cross-layer import violation during refactoring.

7. **Respect scope.** Only refactor code specified in $ARGUMENTS. Do not refactor unrelated files unless they need import updates due to a move/rename.

8. **Git safety.** Never force-push, never amend commits, never run destructive git commands. If something goes wrong, the developer should be able to `git diff` to see exactly what changed.

9. **No new dependencies.** Refactoring should not require adding new packages or libraries. If a refactoring pattern requires a new dependency, flag it as a recommendation instead of applying it.

10. **Preserve public API.** If refactoring a library or module with external consumers, the public API (exported functions, class methods, type signatures) must remain unchanged. Use re-exports to maintain backward compatibility when splitting modules.

---

## Language-Specific Refactoring Patterns

### Python

**Standard transformations:**
- `for i in range(len(items)):` -> `for i, item in enumerate(items):`
- `if x == None:` -> `if x is None:`
- `dict.has_key(k)` -> `k in dict`
- Manual file open/close -> `with open(path) as f:`
- String concatenation in loop -> `"".join(parts)`
- `lambda x: func(x)` -> `func` (unnecessary lambda)
- Nested dict access -> `dict.get(key, default)`
- `try/except: pass` -> At minimum, log the exception

**Import organization (isort compatible):**
```python
# 1. Standard library
import os
import sys

# 2. Third-party packages
import fastapi
import sqlalchemy

# 3. Local application
from app.services import user_service
from app.repositories import user_repo
```

### TypeScript

**Standard transformations:**
- `var` -> `const` or `let`
- `function(x) { return x * 2 }` -> `(x) => x * 2`
- `promise.then().catch()` chains -> `async/await`
- `x === undefined || x === null` -> `x == null` (intentional loose equality)
- Nested ternaries -> if/else or switch
- Object spread for immutable updates: `{...obj, key: newValue}`
- Index-based array iteration -> `for...of` or array methods

**Import organization:**
```typescript
// 1. External packages
import React from 'react';
import { useQuery } from '@tanstack/react-query';

// 2. Internal modules (absolute paths)
import { UserService } from '@/services/user.service';
import { Button } from '@/components/ui/Button';

// 3. Relative imports
import { formatDate } from './utils';
import type { UserProps } from './types';
```

### Go

**Standard transformations:**
- Named return values for clarity in complex functions
- Error wrapping: `fmt.Errorf("context: %w", err)` instead of raw return
- Table-driven tests for repetitive test cases
- Interface segregation: small, focused interfaces
- Avoid init() functions when possible

---

## Edge Cases and Special Handling

**Circular Dependencies:**
If refactoring reveals circular imports, flag them as a separate HIGH priority issue. Breaking circular dependencies requires careful analysis and often involves introducing an interface/protocol layer.

**Dynamic References:**
Before removing "dead" code, check for:
- `getattr(obj, "method_name")` (Python)
- `obj[methodName]()` (JavaScript/TypeScript)
- Decorator registrations (`@app.route`, `@pytest.fixture`, `@celery.task`)
- Framework auto-discovery (Django admin, FastAPI dependency injection)
- Reflection usage

**Generated Code:**
Skip refactoring for:
- Auto-generated files (migrations, protobuf output, swagger codegen)
- Minified/bundled files
- Vendor/third-party code
- Lock files (package-lock.json, poetry.lock)

**Test Files:**
When refactoring test files specifically:
- Preserve test isolation
- Do not merge test functions (each test should test one thing)
- Extract test fixtures/factories, but keep test assertions inline
- Follow the Arrange-Act-Assert pattern

**Configuration Files:**
Do not refactor:
- `.env` files
- `docker-compose.yml`
- CI/CD configuration (`.github/workflows/`)
- Package manager configs (`package.json` dependencies, `pyproject.toml` dependencies)
