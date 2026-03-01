---
description: "Scan codebase for technical debt: code smells, TODO/FIXME, outdated patterns, test gaps, dependency issues. Generates TECH_DEBT.md with prioritized action plan. Usage: /tech-debt [--fix-quick-wins]"
---

# Technical Debt Tracker & Manager

You are a senior software engineer performing a comprehensive technical debt audit of this codebase. Your goal is to identify, quantify, categorize, and prioritize all forms of technical debt, then produce an actionable remediation plan.

**Arguments**: $ARGUMENTS

Parse flags from arguments:
- `--fix-quick-wins` = Automatically fix simple issues (unused imports, bare exceptions, trailing whitespace, missing __init__.py)
- No flags = Scan only, generate report without modifying code

---

## Step 0: Project Discovery

Before scanning, understand the project structure and tech stack.

```bash
echo "=== Project Root ==="
pwd

echo "=== Languages Detected ==="
find . -maxdepth 4 -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.rb" -o -name "*.php" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/venv/*" -not -path "*/__pycache__/*" -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/.next/*" 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn

echo "=== Package Managers ==="
ls -la package.json yarn.lock package-lock.json pnpm-lock.yaml requirements.txt Pipfile pyproject.toml go.mod Cargo.toml Gemfile setup.py setup.cfg 2>/dev/null

echo "=== Total Source Files ==="
find . -maxdepth 6 -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/venv/*" -not -path "*/__pycache__/*" -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/.next/*" 2>/dev/null | wc -l

echo "=== Total Lines of Code (approximate) ==="
find . -maxdepth 6 -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/venv/*" -not -path "*/__pycache__/*" -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/.next/*" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1

echo "=== Test Directories ==="
find . -maxdepth 4 -type d -name "tests" -o -name "test" -o -name "__tests__" -o -name "spec" 2>/dev/null | grep -v node_modules | grep -v .git

echo "=== Config Files ==="
ls -la .eslintrc* .prettierrc* pyproject.toml tox.ini .flake8 .pylintrc ruff.toml .mypy.ini mypy.ini tsconfig.json jest.config* vitest.config* pytest.ini setup.cfg .editorconfig 2>/dev/null

echo "=== Git History Stats ==="
git log --oneline --since="6 months ago" 2>/dev/null | wc -l
git shortlog -sn --since="6 months ago" 2>/dev/null | head -10
```

Determine the primary language(s) and framework(s). This determines which scans are applicable. Store the project metadata for the report header.

Initialize a debt tracker. Track every finding as:
```
{category: "code_quality|architecture|testing|dependencies|documentation", severity: "critical|high|medium|low", title: "...", file: "...", line: N, description: "...", effort: "quick_win|medium|large|ongoing", estimated_time: "..."}
```

---

## Step 1: Scan for Code Smells

Use Agent tool (mode = "bypassPermissions") to run the following sub-scans in parallel for maximum speed.

### 1A: TODO / FIXME / HACK / XXX Comments

Search for debt markers left by developers. These are explicit acknowledgments of technical debt.

Use Grep for each pattern (exclude node_modules, .git, venv, __pycache__, dist, build, .next):

```
Pattern: (?i)\b(TODO|FIXME|HACK|XXX|WORKAROUND|KLUDGE|TEMP|TEMPORARY)\b
```

For each match found:
- Record the file, line number, and the full comment text
- Categorize by type:
  - **TODO** = planned improvement, not yet done
  - **FIXME** = known bug or broken behavior
  - **HACK/WORKAROUND/KLUDGE** = intentional shortcut, needs proper solution
  - **XXX** = dangerous or tricky code needing attention
  - **TEMP/TEMPORARY** = code that should have been removed
- Assign severity:
  - FIXME = **high** (known bugs)
  - HACK/WORKAROUND/KLUDGE = **high** (fragile code)
  - XXX = **high** (dangerous code)
  - TEMP/TEMPORARY = **medium** (cleanup needed)
  - TODO = **low** (planned work)
- Count totals by type and by file (which files have the most debt markers?)

### 1B: Long Functions (>50 lines)

Detect functions and methods that exceed 50 lines. Long functions violate the Single Responsibility Principle and are harder to test, understand, and maintain.

**Python detection:**
Use Bash to run a script that finds long functions:
```bash
find . -name "*.py" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/venv/*" -not -path "*/__pycache__/*" -not -path "*/migrations/*" 2>/dev/null | while read file; do
    awk '/^[[:space:]]*(def |async def )/{name=$0; start=NR} /^[[:space:]]*(def |async def |class )/{if(start && NR>start){len=NR-start; if(len>50) print FILENAME":"start": "name" ("len" lines)"}}' "$file" 2>/dev/null
done
```

**JavaScript/TypeScript detection:**
```bash
find . -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" | grep -v node_modules | grep -v .git | grep -v dist | grep -v build | while read file; do
    awk '/^[[:space:]]*(export )?(async )?(function |const \w+ = |let \w+ = ).*[({]/{name=$0; start=NR} /^[[:space:]]*\}/{if(start){len=NR-start; if(len>50) print FILENAME":"start": "name" ("len" lines)"; start=0}}' "$file" 2>/dev/null
done
```

- Severity: **medium** for 50-100 lines, **high** for >100 lines
- Effort: medium (refactor into smaller functions)

### 1C: Large Files (>500 lines)

Files that are too large indicate missing abstractions or god modules.

```bash
find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/venv/*" -not -path "*/__pycache__/*" -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/.next/*" -not -path "*/migrations/*" 2>/dev/null | while read file; do
    lines=$(wc -l < "$file" 2>/dev/null)
    if [ "$lines" -gt 500 ]; then
        echo "$file: $lines lines"
    fi
done | sort -t: -k2 -rn
```

- Severity: **medium** for 500-1000 lines, **high** for >1000 lines
- Effort: large (split into modules)

### 1D: Deep Nesting (>4 levels)

Deeply nested code is hard to read and indicates missing early returns or abstraction.

Use Grep to find indicators of deep nesting:

**Python:**
```
Pattern: ^(\s{16,}|\t{4,})(if |for |while |try:|except|with )
```

**JavaScript/TypeScript:**
```
Pattern: ^(\s{16,}|\t{4,})(if |for |while |try |catch|switch)
```

Read the context around each match to confirm genuine deep nesting (not just long strings or data).

- Severity: **medium**
- Effort: medium (refactor with early returns, extract functions)

### 1E: Duplicate Code Detection

Search for patterns that suggest copy-paste programming.

Strategy:
1. Use Grep to find identical or near-identical blocks. Look for functions with similar names:
```
Pattern: def (get|create|update|delete)_\w+
```
2. Check if multiple files have structurally identical functions (same parameter patterns, same logic flow)
3. Look for repeated boilerplate patterns:
```
Pattern: try:\s*\n\s*.*\s*\n\s*except
```
4. Identify repeated error handling blocks, repeated validation logic, repeated query patterns

- Severity: **medium** (maintainability risk)
- Effort: medium (extract shared utilities)

### 1F: Dead Code Detection

Search for code that is defined but never used.

**Unused imports (Python):**
```bash
# Find files with potential unused imports
find . -name "*.py" -not -path "*/venv/*" -not -path "*/__pycache__/*" -not -path "*/.git/*" 2>/dev/null | while read file; do
    python3 -c "
import ast, sys
try:
    with open('$file') as f:
        tree = ast.parse(f.read())
    imports = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                imports.append(alias.asname or alias.name.split('.')[0])
        elif isinstance(node, ast.ImportFrom):
            for alias in node.names:
                if alias.name != '*':
                    imports.append(alias.asname or alias.name)
    with open('$file') as f:
        content = f.read()
    for imp in imports:
        # Count occurrences beyond the import line itself
        count = content.count(imp)
        if count <= 1 and imp not in ('__all__', '__version__', 'annotations'):
            print(f'$file: possibly unused import: {imp}')
except: pass
" 2>/dev/null
done
```

**Unused imports (JavaScript/TypeScript):**
Use Grep to find imports, then check if the imported name appears elsewhere in the file.

**Unreachable code:**
```
Pattern: (?m)^\s*return\s+.*\n\s+\S
```
(Code after a return statement at the same indentation level)

**Commented-out code blocks (>3 consecutive commented lines):**
```
Pattern: (?m)(^\s*#(?!!).*\n){4,}
```
(Python: 4+ consecutive comment lines that look like disabled code)

```
Pattern: (?m)(^\s*//.*\n){4,}
```
(JS/TS: 4+ consecutive single-line comments)

- Severity: **low** for unused imports, **medium** for large commented-out blocks
- Effort: quick_win for unused imports, medium for commented-out code review

### 1G: Magic Numbers and Hardcoded Values

Search for hardcoded numeric values that should be named constants.

```
Pattern: (?<![.\w])\b((?!0\b|1\b|2\b|100\b)\d{2,})\b(?![\w.])
```

Focus specifically on:
- Hardcoded port numbers: `Pattern: (?i)port\s*[:=]\s*\d{4,5}`
- Hardcoded timeouts: `Pattern: (?i)(timeout|sleep|delay|interval)\s*[:=(\s]\s*\d+`
- Hardcoded limits: `Pattern: (?i)(limit|max|min|size|count|threshold)\s*[:=]\s*\d+`
- Hardcoded URLs: `Pattern: (https?://(?!localhost|127\.0\.0\.1|example\.com|schema))[^\s'\"]+`
- Hardcoded credentials: `Pattern: (?i)(user|username|login)\s*[:=]\s*['\"][^'\"]+['\"]`

Exclude test files, migration files, and configuration files from this check.

- Severity: **low** for most, **high** for hardcoded URLs or credentials
- Effort: quick_win (extract to constants or config)

### 1H: Type Checking and Linter Suppressions

These indicate places where developers gave up on type safety or code quality.

**Python type:ignore:**
```
Pattern: #\s*type:\s*ignore
```

**Python noqa:**
```
Pattern: #\s*noqa
```

**TypeScript @ts-ignore / @ts-expect-error / @ts-nocheck:**
```
Pattern: @ts-(ignore|expect-error|nocheck)
```

**ESLint disable:**
```
Pattern: eslint-disable
```

**Any suppression with no explanation (no comment after the directive):**
```
Pattern: #\s*type:\s*ignore\s*$
Pattern: #\s*noqa\s*$
Pattern: //\s*@ts-ignore\s*$
Pattern: //\s*eslint-disable.*$
```

Count totals and list the top offending files.

- Severity: **low** for individual suppressions, **medium** if a file has >5 suppressions
- Effort: medium (fix underlying type/lint issues)

### 1I: Broad Exception Handling

Catching overly broad exceptions hides bugs and makes debugging difficult.

**Python bare except:**
```
Pattern: except\s*:
```

**Python broad Exception:**
```
Pattern: except\s+(Exception|BaseException)\s*(:|\s+as)
```

**JavaScript/TypeScript empty catch:**
```
Pattern: catch\s*\(\s*\w*\s*\)\s*\{\s*\}
```

**JavaScript catch without specific error handling:**
```
Pattern: catch\s*\(.*\)\s*\{[\s\n]*\}
```

Read context around each match to determine if the broad catch is justified (e.g., top-level error handler) or lazy (suppressing errors silently).

- Severity: **high** for bare `except:` or empty catch blocks
- Severity: **medium** for `except Exception:` without logging
- Effort: quick_win (add specific exception types)

### 1J: Print Statement Debugging

Search for debug print statements left in production code (exclude test files).

**Python:**
```
Pattern: ^\s*print\(
```

**JavaScript/TypeScript:**
```
Pattern: ^\s*console\.(log|debug|info|warn|error)\(
```

Exclude test files, scripts, CLI tools, and logging configuration files.

- Severity: **low** for console.log/print, **high** if printing sensitive data
- Effort: quick_win (remove or replace with proper logging)

---

## Step 2: Scan for Architecture Violations

Use Agent tool (mode = "bypassPermissions") to run the following sub-scans in parallel.

### 2A: Layer Violations

Check for improper cross-layer imports that break separation of concerns.

**Standard layer hierarchy:** `api/ -> services/ -> repositories/ -> models/`

Use Grep to detect violations:

```
# API layer importing from repositories (should go through services)
Pattern: from\s+.*repositories import|from\s+.*\.repos\.|import\s+.*repository
File scope: */api/*.py, */routes/*.py, */routers/*.py, */views/*.py, */controllers/*.py

# Services importing from API layer (reverse dependency)
Pattern: from\s+.*api import|from\s+.*\.routes\.|from\s+.*\.routers\.|from\s+.*views import
File scope: */services/*.py, */service/*.py

# Direct DB queries in API/route handlers
Pattern: (\.query\(|\.execute\(|\.filter\(|\.find\(|\.aggregate\(|session\.(add|delete|commit|flush))
File scope: */api/*.py, */routes/*.py, */routers/*.py, */views/*.py, */controllers/*.py
```

- Severity: **high** (architecture erosion)
- Effort: medium to large (refactor import chains)

### 2B: Circular Import Detection

Look for potential circular imports by analyzing import graphs.

```bash
# Python: Find files that import each other
find . -name "*.py" -not -path "*/venv/*" -not -path "*/__pycache__/*" -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null | while read file; do
    grep -oP "from\s+\K[\w.]+" "$file" 2>/dev/null | while read module; do
        # Convert module path to file path and check reverse import
        echo "$file imports $module"
    done
done | sort
```

Also check for runtime import workarounds that indicate circular import problems:
```
Pattern: (?i)# (avoid|prevent|fix|workaround).*circular
Pattern: importlib\.import_module\(
Pattern: TYPE_CHECKING
```

Usage of `if TYPE_CHECKING:` is acceptable but frequent use may indicate architectural issues.

- Severity: **high** for confirmed circular imports
- Severity: **low** for TYPE_CHECKING usage (acceptable pattern but worth noting)
- Effort: large (may require architectural refactoring)

### 2C: God Objects

Classes that do too much violate the Single Responsibility Principle.

```bash
# Find classes with many methods (>10)
find . -name "*.py" -not -path "*/venv/*" -not -path "*/__pycache__/*" -not -path "*/.git/*" 2>/dev/null | while read file; do
    python3 -c "
import ast
try:
    with open('$file') as f:
        tree = ast.parse(f.read())
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            methods = [n for n in node.body if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))]
            attrs = [n for n in node.body if isinstance(n, ast.Assign)]
            if len(methods) > 10 or len(attrs) > 20:
                print(f'$file: class {node.name} has {len(methods)} methods and {len(attrs)} class-level attributes')
except: pass
" 2>/dev/null
done
```

- Severity: **medium** for 10-15 methods, **high** for >15 methods
- Effort: large (decompose into smaller classes)

### 2D: Spaghetti Dependencies

Modules with too many imports indicate poor cohesion and tight coupling.

```bash
# Find files with >10 local imports (excluding stdlib and third-party)
find . -name "*.py" -not -path "*/venv/*" -not -path "*/__pycache__/*" -not -path "*/.git/*" -not -path "*/migrations/*" 2>/dev/null | while read file; do
    count=$(grep -cE "^(from|import)\s+" "$file" 2>/dev/null)
    if [ "$count" -gt 10 ]; then
        echo "$file: $count imports"
    fi
done | sort -t: -k2 -rn | head -20
```

- Severity: **medium** for 10-20 imports, **high** for >20 imports
- Effort: large (refactoring needed to reduce coupling)

### 2E: Missing Abstractions — Business Logic in API Routes

API route handlers should be thin controllers that delegate to services. Detect business logic leaking into routes.

Indicators of business logic in route handlers:
```
# Complex conditionals in routes
Pattern: (if|elif|else|for|while).*:
File scope: */api/*.py, */routes/*.py, */routers/*.py

# Database operations in routes
Pattern: (\.query|\.filter|\.execute|session\.|db\.|collection\.)
File scope: */api/*.py, */routes/*.py, */routers/*.py

# Email sending in routes
Pattern: (send_mail|send_email|smtp|email\.send)
File scope: */api/*.py, */routes/*.py, */routers/*.py

# External API calls in routes
Pattern: (requests\.(get|post)|httpx\.|aiohttp\.|fetch\()
File scope: */api/*.py, */routes/*.py, */routers/*.py
```

Read the matched files and assess whether route handlers are doing more than:
1. Parse request
2. Call service
3. Return response

- Severity: **medium** (maintainability and testability)
- Effort: medium (extract to service layer)

---

## Step 3: Scan for Testing Gaps

Use Agent tool (mode = "bypassPermissions") to run the following sub-scans in parallel.

### 3A: Missing Test Files

For every source module, check if a corresponding test file exists.

```bash
echo "=== Source files without tests ==="
find . -name "*.py" -not -name "test_*" -not -name "*_test.py" -not -name "conftest.py" -not -path "*/tests/*" -not -path "*/test/*" -not -path "*/venv/*" -not -path "*/__pycache__/*" -not -path "*/.git/*" -not -path "*/migrations/*" -not -path "*/__init__.py" -not -path "*/alembic/*" 2>/dev/null | while read file; do
    base=$(basename "$file" .py)
    dir=$(dirname "$file")
    # Check for test_<name>.py or <name>_test.py in common test locations
    found=false
    for test_dir in "$dir" "$dir/tests" "$dir/../tests" "$dir/../../tests" "tests" "test"; do
        if [ -f "$test_dir/test_$base.py" ] || [ -f "$test_dir/${base}_test.py" ]; then
            found=true
            break
        fi
    done
    if [ "$found" = false ]; then
        echo "NO TEST: $file"
    fi
done
```

Similarly for JavaScript/TypeScript:
```bash
find . -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" | grep -v node_modules | grep -v .git | grep -v dist | grep -v build | grep -v ".test." | grep -v ".spec." | grep -v "__tests__" | grep -v ".d.ts" | while read file; do
    base=$(basename "$file" | sed 's/\.[^.]*$//')
    dir=$(dirname "$file")
    found=false
    for test_pattern in "$dir/$base.test.*" "$dir/$base.spec.*" "$dir/__tests__/$base.*" "$dir/../__tests__/$base.*"; do
        if ls $test_pattern 2>/dev/null | head -1 | grep -q .; then
            found=true
            break
        fi
    done
    if [ "$found" = false ]; then
        echo "NO TEST: $file"
    fi
done
```

Count the ratio: files with tests / total source files = test coverage breadth.

- Severity: **high** for critical paths without tests (auth, payments, core business logic)
- Severity: **medium** for utility/helper modules without tests
- Severity: **low** for configuration files without tests
- Effort: medium to large (writing comprehensive tests)

### 3B: Test Quality Issues

Search for patterns that indicate low-quality tests.

**Flaky test indicators:**
```
Pattern: time\.sleep\(
Pattern: import\s+time.*\n.*sleep
Pattern: asyncio\.sleep\(
Pattern: setTimeout\(
Pattern: waitFor\(.*timeout
```

**Missing assertions (test functions without assert/expect):**
```bash
# Python: test functions without assert
find . -name "test_*.py" -o -name "*_test.py" | grep -v node_modules | grep -v venv 2>/dev/null | while read file; do
    python3 -c "
import ast
try:
    with open('$file') as f:
        tree = ast.parse(f.read())
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith('test_'):
            source = ast.dump(node)
            if 'assert' not in source.lower() and 'raise' not in source.lower() and 'mock' not in source.lower():
                print(f'$file:{node.lineno}: {node.name} has no assertions')
except: pass
" 2>/dev/null
done
```

**Tests creating data manually instead of using fixtures/factories:**
```
Pattern: (?i)(User|Account|Order|Product|Item)\(\s*\w+=
File scope: */tests/*.py, */test_*.py
```

**Overly mocked tests (>5 mocks in a single test):**
```
Pattern: @patch|mock\.patch|Mock\(|MagicMock\(|mocker\.patch
```
Count per test function. If >5 mocks, the test may be testing mocks rather than code.

- Severity: **medium** for flaky indicators, **high** for tests without assertions
- Effort: medium (improve test quality)

### 3C: Test Configuration Issues

```bash
# Check for test configuration
echo "=== Test Configuration ==="
cat pytest.ini pyproject.toml setup.cfg 2>/dev/null | grep -A5 "\[tool\.pytest\]\|\[pytest\]\|pytest"
cat jest.config.* vitest.config.* 2>/dev/null

# Check for coverage configuration
echo "=== Coverage Configuration ==="
cat .coveragerc pyproject.toml setup.cfg 2>/dev/null | grep -A10 "\[coverage\]\|\[tool\.coverage\]"

# Check if coverage is run in CI
cat .github/workflows/*.yml .gitlab-ci.yml Jenkinsfile Makefile 2>/dev/null | grep -i "coverage\|pytest.*cov\|jest.*coverage"
```

- Severity: **medium** if no test configuration found
- Severity: **low** if no coverage tracking
- Effort: quick_win (add configuration files)

---

## Step 4: Scan for Dependency Issues

Use Agent tool (mode = "bypassPermissions") to run the following sub-scans in parallel.

### 4A: Outdated Packages

**Python:**
```bash
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Pipfile" ]; then
    echo "=== Python Outdated Packages ==="
    pip list --outdated --format=json 2>/dev/null | python3 -c "
import json, sys
try:
    pkgs = json.load(sys.stdin)
    for pkg in sorted(pkgs, key=lambda x: x['name']):
        current = pkg['version']
        latest = pkg['latest_version']
        # Determine if major version behind
        cur_major = current.split('.')[0]
        lat_major = latest.split('.')[0]
        severity = 'MAJOR' if cur_major != lat_major else 'MINOR'
        print(f'{pkg[\"name\"]}: {current} -> {latest} [{severity}]')
except: pass
" 2>/dev/null
fi
```

**Node.js:**
```bash
if [ -f "package.json" ]; then
    echo "=== Node.js Outdated Packages ==="
    npm outdated --json 2>/dev/null | python3 -c "
import json, sys
try:
    pkgs = json.load(sys.stdin)
    for name, info in sorted(pkgs.items()):
        current = info.get('current', 'N/A')
        latest = info.get('latest', 'N/A')
        wanted = info.get('wanted', 'N/A')
        print(f'{name}: {current} -> {latest} (wanted: {wanted})')
except: pass
" 2>/dev/null
fi
```

- Severity: **high** for major version updates behind, **medium** for minor, **low** for patch
- Effort: medium (test after updating)

### 4B: Security Vulnerabilities

**Python:**
```bash
if command -v pip-audit &>/dev/null; then
    pip-audit --format json 2>&1 | head -100
elif command -v safety &>/dev/null; then
    safety check 2>&1 | head -50
else
    echo "INFO: Neither pip-audit nor safety installed. Install with: pip install pip-audit"
fi
```

**Node.js:**
```bash
if [ -f "package-lock.json" ]; then
    npm audit --json 2>&1 | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    vulns = data.get('vulnerabilities', {})
    for name, info in vulns.items():
        severity = info.get('severity', 'unknown')
        via = info.get('via', [])
        print(f'{name}: {severity} severity')
except: pass
" 2>/dev/null | head -30
fi
```

- Severity: **critical** for known CVEs with exploits, **high** for high-severity CVEs
- Effort: quick_win to medium (update packages, test for breaking changes)

### 4C: Unused Dependencies

**Python:**
```bash
if [ -f "requirements.txt" ]; then
    echo "=== Potentially Unused Python Dependencies ==="
    while IFS= read -r line; do
        pkg=$(echo "$line" | sed 's/[><=!~].*//' | sed 's/\[.*//' | tr '[:upper:]' '[:lower:]' | tr '-' '_' | xargs)
        if [ -n "$pkg" ] && [[ ! "$pkg" =~ ^# ]]; then
            # Search for import of this package
            count=$(grep -rl "import $pkg\|from $pkg" --include="*.py" . 2>/dev/null | grep -v venv | grep -v .git | grep -v __pycache__ | wc -l)
            if [ "$count" -eq 0 ]; then
                echo "POSSIBLY UNUSED: $pkg (not found in any import)"
            fi
        fi
    done < requirements.txt
fi
```

**Node.js:**
```bash
if [ -f "package.json" ]; then
    echo "=== Potentially Unused Node.js Dependencies ==="
    node -e "
    const pkg = require('./package.json');
    const deps = Object.keys(pkg.dependencies || {});
    const fs = require('fs');
    const { execSync } = require('child_process');
    deps.forEach(dep => {
        try {
            const result = execSync('grep -rl \"' + dep + '\" --include=\"*.js\" --include=\"*.ts\" --include=\"*.tsx\" --include=\"*.jsx\" . 2>/dev/null | grep -v node_modules | grep -v package | head -1', { encoding: 'utf8' });
            if (!result.trim()) {
                console.log('POSSIBLY UNUSED: ' + dep);
            }
        } catch(e) {
            console.log('POSSIBLY UNUSED: ' + dep);
        }
    });
    " 2>/dev/null
fi
```

- Severity: **low** (bloat, slower installs, larger attack surface)
- Effort: quick_win (remove after verifying)

### 4D: Missing Lock File / Unpinned Dependencies

```bash
echo "=== Dependency Pinning Audit ==="

# Python: Check for unpinned versions
if [ -f "requirements.txt" ]; then
    echo "--- Unpinned Python Dependencies ---"
    grep -vE "^#|^$|==|~=|>=.*,<=|>=.*,<" requirements.txt 2>/dev/null | head -20

    # Check for lock file
    if [ ! -f "requirements.lock" ] && [ ! -f "poetry.lock" ] && [ ! -f "Pipfile.lock" ]; then
        echo "WARNING: No Python lock file found (requirements.lock / poetry.lock / Pipfile.lock)"
    fi
fi

# Node.js: Check for lock file
if [ -f "package.json" ]; then
    if [ ! -f "package-lock.json" ] && [ ! -f "yarn.lock" ] && [ ! -f "pnpm-lock.yaml" ]; then
        echo "WARNING: No Node.js lock file found"
    fi
fi
```

- Severity: **high** for missing lock file, **medium** for unpinned versions
- Effort: quick_win (pin versions, generate lock file)

---

## Step 5: Scan for Documentation Gaps

Use Agent tool (mode = "bypassPermissions") to run the following sub-scans in parallel.

### 5A: Missing Docstrings

**Python:**
```bash
find . -name "*.py" -not -path "*/venv/*" -not -path "*/__pycache__/*" -not -path "*/.git/*" -not -path "*/migrations/*" -not -name "__init__.py" 2>/dev/null | while read file; do
    python3 -c "
import ast
try:
    with open('$file') as f:
        tree = ast.parse(f.read())
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            if not isinstance(node, ast.ClassDef) and node.name.startswith('_') and not node.name.startswith('__'):
                continue  # Skip private functions
            docstring = ast.get_docstring(node)
            if not docstring:
                kind = 'class' if isinstance(node, ast.ClassDef) else 'function'
                print(f'$file:{node.lineno}: {kind} {node.name} missing docstring')
except: pass
" 2>/dev/null
done | head -50
```

**JavaScript/TypeScript (JSDoc):**
Check for exported functions without JSDoc comments:
```
Pattern: ^export\s+(async\s+)?function\s+\w+
```
Then check if the line above contains `/**` (JSDoc opening).

- Severity: **low** for utility functions, **medium** for public API functions/classes
- Effort: medium (write meaningful docstrings)

### 5B: Missing README Sections

```bash
if [ -f "README.md" ]; then
    echo "=== README.md Sections Present ==="
    grep "^##\?" README.md 2>/dev/null

    echo "=== Checking for essential sections ==="
    for section in "Install" "Setup" "Usage" "API" "Contributing" "License" "Environment" "Deploy"; do
        if grep -qi "$section" README.md 2>/dev/null; then
            echo "PRESENT: $section"
        else
            echo "MISSING: $section"
        fi
    done
else
    echo "WARNING: No README.md found"
fi
```

- Severity: **medium** for missing README, **low** for missing sections
- Effort: medium (write documentation)

### 5C: Missing API Documentation

Check if API endpoints have descriptions and examples.

**FastAPI/Flask:**
```
# Routes without docstrings or description parameter
Pattern: @(app|router)\.(get|post|put|delete|patch)\(
```

Read matched files and check if the route function has:
- A docstring (used by Swagger/OpenAPI)
- Response model definition
- Request body documentation
- Example values

**Express/Next.js:**
Check for JSDoc on API route handlers.

- Severity: **medium** for public API endpoints without documentation
- Effort: medium (add OpenAPI annotations)

### 5D: Stale Comments

Look for comments that reference old patterns, deleted variables, or outdated information.

```
Pattern: (?i)# (deprecated|old|legacy|remove|unused|no longer|was |used to |previously)
Pattern: (?i)// (deprecated|old|legacy|remove|unused|no longer|was |used to |previously)
```

- Severity: **low** (misleading information)
- Effort: quick_win (update or remove)

---

## Step 6: Calculate Tech Debt Score

After all scans are complete, calculate the Tech Debt Score.

### Scoring Methodology

For each category, calculate a score from 0 to 100 where 100 means zero debt.

**Code Quality Score (Weight: 30%)**
```
base = 100
deduct 2 points per TODO/FIXME/HACK comment (max -30)
deduct 3 points per function >50 lines (max -20)
deduct 3 points per file >500 lines (max -15)
deduct 2 points per deep nesting instance (max -10)
deduct 1 point per dead code instance (max -10)
deduct 1 point per magic number instance (max -5)
deduct 1 point per type suppression (max -5)
deduct 3 points per bare except (max -10)
deduct 1 point per debug print (max -5)
score = max(0, base - total_deductions)
```

**Architecture Score (Weight: 25%)**
```
base = 100
deduct 10 points per layer violation (max -40)
deduct 15 points per circular import (max -30)
deduct 5 points per god object (max -20)
deduct 2 points per spaghetti dependency file (max -10)
deduct 5 points per business logic in route (max -20)
score = max(0, base - total_deductions)
```

**Testing Score (Weight: 20%)**
```
base = 100
# Test coverage breadth: files with tests / total source files
coverage_ratio = files_with_tests / total_source_files
deduct (1 - coverage_ratio) * 50 points for missing tests
deduct 3 points per flaky test indicator (max -15)
deduct 5 points per test without assertions (max -15)
deduct 5 points if no test configuration (max -5)
deduct 5 points if no coverage tracking (max -5)
score = max(0, base - total_deductions)
```

**Dependencies Score (Weight: 15%)**
```
base = 100
deduct 5 points per major-version-behind package (max -30)
deduct 10 points per known security vulnerability (max -40)
deduct 2 points per unused dependency (max -10)
deduct 15 points if no lock file
deduct 2 points per unpinned dependency (max -10)
score = max(0, base - total_deductions)
```

**Documentation Score (Weight: 10%)**
```
base = 100
# Docstring coverage: functions with docstrings / total public functions
docstring_ratio = functions_with_docstrings / total_public_functions
deduct (1 - docstring_ratio) * 40 points for missing docstrings
deduct 15 points if no README
deduct 5 points per missing essential README section (max -20)
deduct 5 points per undocumented API endpoint (max -20)
deduct 1 point per stale comment (max -5)
score = max(0, base - total_deductions)
```

**Overall Score:**
```
overall = (code_quality * 0.30) + (architecture * 0.25) + (testing * 0.20) + (dependencies * 0.15) + (documentation * 0.10)
```

### Score Interpretation

| Range | Rating | Meaning |
|-------|--------|---------|
| 90-100 | Excellent | Minimal debt, well-maintained codebase |
| 70-89 | Good | Manageable debt, some areas need attention |
| 50-69 | Fair | Significant debt, needs dedicated remediation sprint |
| 30-49 | Poor | Heavy debt, impacting velocity and reliability |
| 0-29 | Critical | Urgent remediation needed, debt is a blocker |

---

## Step 7: Prioritize Actions

Classify each debt item into effort tiers with estimated time.

### Quick Win (< 30 minutes, low risk)

These can be fixed immediately with minimal risk of breaking changes:
- Remove unused imports
- Remove dead code (unused variables, commented-out blocks)
- Fix bare exception handlers (add specific exception types)
- Remove trailing whitespace
- Add missing `__init__.py` files
- Remove debug print statements
- Fix import sorting
- Update stale comments
- Pin dependency versions
- Add missing type hints on simple functions

### Medium Effort (1-4 hours)

These require careful implementation and testing:
- Refactor long functions (>50 lines) into smaller functions
- Add missing test files for critical paths
- Fix layer violations (move code to correct layer)
- Add docstrings to public API functions
- Replace magic numbers with named constants
- Fix flaky tests (remove sleeps, use proper async patterns)
- Update outdated dependencies (minor versions)
- Add proper error handling (replace broad catches)
- Add missing README sections

### Large Effort (1+ days)

These are significant refactoring tasks:
- Split god objects into focused classes
- Break up large files into modules
- Resolve circular dependencies
- Major version dependency upgrades
- Add comprehensive test suites for untested modules
- Restructure architecture (fix layer violations at scale)
- Migrate deprecated patterns to modern alternatives
- Add API documentation (OpenAPI/Swagger)

### Ongoing (continuous)

These are habits and processes, not one-time fixes:
- Keep dependencies updated (monthly review)
- Maintain test coverage (enforce in CI)
- Write docstrings for new code (enforce in code review)
- Remove TODOs as they are addressed
- Monitor for new security vulnerabilities
- Refactor as part of feature work (boy scout rule)

---

## Step 8: Auto-Fix Quick Wins (only if --fix-quick-wins)

If `--fix-quick-wins` is in $ARGUMENTS, automatically fix the following safe changes.

**IMPORTANT:** Before making any change, read the file first. Only make changes that are safe and will not break functionality. Create a summary of all changes made.

### 8A: Remove Unused Imports (Python)

For each file with detected unused imports:
1. Read the full file
2. Identify the unused import lines
3. Remove them using Edit tool
4. Verify the file still parses correctly:
```bash
python3 -c "import ast; ast.parse(open('FILE').read())" 2>&1
```

### 8B: Fix Bare Exception Handlers

Replace bare `except:` with `except Exception:` and add a logging statement.

Before:
```python
try:
    something()
except:
    pass
```

After:
```python
try:
    something()
except Exception as e:
    logger.error(f"Unexpected error: {e}")
```

### 8C: Remove Trailing Whitespace

```bash
find . -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.tsx" | grep -v node_modules | grep -v .git | grep -v venv | while read file; do
    sed -i '' 's/[[:space:]]*$//' "$file" 2>/dev/null
done
```

### 8D: Add Missing __init__.py Files

```bash
find . -type d -name "*.py" -prune -o -type d -print | grep -v node_modules | grep -v .git | grep -v venv | grep -v __pycache__ | while read dir; do
    if ls "$dir"/*.py 2>/dev/null | head -1 | grep -q .; then
        if [ ! -f "$dir/__init__.py" ]; then
            echo "Adding __init__.py to $dir"
            touch "$dir/__init__.py"
        fi
    fi
done
```

### 8E: Remove Debug Print Statements

For each file with debug print statements (non-test files):
1. Read the file
2. Remove lines that are just `print(...)` or `console.log(...)` for debugging
3. Only remove prints that look like debug output (not user-facing messages)

### 8F: Sort Imports (Python)

If `isort` or `ruff` is available:
```bash
if command -v ruff &>/dev/null; then
    ruff check --select I --fix .
elif command -v isort &>/dev/null; then
    isort .
fi
```

### Auto-Fix Summary

After all fixes, generate a summary table:
```markdown
## Auto-Fix Summary
| Fix | Files Changed | Changes Made | Status |
|-----|--------------|-------------|--------|
| Removed unused imports | [n] | [n] imports removed | Applied |
| Fixed bare exceptions | [n] | [n] handlers fixed | Applied |
| Removed trailing whitespace | [n] | [n] lines cleaned | Applied |
| Added __init__.py files | [n] | [n] files created | Applied |
| Removed debug prints | [n] | [n] prints removed | Applied |
| Sorted imports | [n] | [n] files sorted | Applied |
```

---

## Step 9: Generate TECH_DEBT.md

Compile all findings into a comprehensive report. Use Write tool to create `TECH_DEBT.md` in the project root.

```markdown
# Technical Debt Report

**Date**: [today's date]
**Project**: [project name]
**Auditor**: Claude Tech Debt Scanner (Cortex)
**Total Source Files**: [n]
**Total Lines of Code**: [n]
**Tech Debt Score**: [X]/100 — [Rating]

---

## Executive Summary

[2-4 sentences summarizing the overall state of technical debt. Mention the total number of issues found, the most concerning areas, and the estimated effort to address critical items.]

---

## Tech Debt Score

| Category | Weight | Issues Found | Score | Rating |
|----------|--------|-------------|-------|--------|
| Code Quality | 30% | [n] | [x]/100 | [rating] |
| Architecture | 25% | [n] | [x]/100 | [rating] |
| Testing | 20% | [n] | [x]/100 | [rating] |
| Dependencies | 15% | [n] | [x]/100 | [rating] |
| Documentation | 10% | [n] | [x]/100 | [rating] |
| **OVERALL** | **100%** | **[total]** | **[x]/100** | **[rating]** |

### Score Interpretation
- 90-100: Excellent — minimal debt
- 70-89: Good — manageable debt
- 50-69: Fair — needs attention
- 30-49: Poor — significant debt
- 0-29: Critical — urgent remediation needed

---

## Detailed Findings

### 1. Code Quality Issues

#### 1.1 TODO/FIXME/HACK Comments ([n] found)

| Type | Count | Top Files |
|------|-------|-----------|
| TODO | [n] | [file1], [file2] |
| FIXME | [n] | [file1], [file2] |
| HACK | [n] | [file1], [file2] |
| XXX | [n] | [file1], [file2] |
| TEMP | [n] | [file1], [file2] |

<details>
<summary>Full list ([n] items)</summary>

| File | Line | Type | Comment |
|------|------|------|---------|
| [file] | [line] | [type] | [comment text] |
...

</details>

#### 1.2 Long Functions ([n] found)

| File | Function | Lines | Severity |
|------|----------|-------|----------|
| [file] | [function_name] | [n] | [high/medium] |
...

#### 1.3 Large Files ([n] found)

| File | Lines | Severity |
|------|-------|----------|
| [file] | [n] | [high/medium] |
...

#### 1.4 Deep Nesting ([n] found)

| File | Line | Depth | Context |
|------|------|-------|---------|
| [file] | [line] | [n] | [surrounding code] |
...

#### 1.5 Dead Code ([n] found)

| Type | File | Item | Severity |
|------|------|------|----------|
| Unused import | [file] | [import] | low |
| Commented-out code | [file] | [lines] | medium |
| Unreachable code | [file] | [line] | medium |
...

#### 1.6 Magic Numbers ([n] found)

| File | Line | Value | Context |
|------|------|-------|---------|
| [file] | [line] | [value] | [surrounding code] |
...

#### 1.7 Type/Lint Suppressions ([n] found)

| File | Count | Types |
|------|-------|-------|
| [file] | [n] | [type:ignore, noqa, etc.] |
...

#### 1.8 Broad Exception Handling ([n] found)

| File | Line | Pattern | Severity |
|------|------|---------|----------|
| [file] | [line] | [bare except / except Exception] | [high/medium] |
...

#### 1.9 Debug Print Statements ([n] found)

| File | Count |
|------|-------|
| [file] | [n] |
...

---

### 2. Architecture Issues

#### 2.1 Layer Violations ([n] found)

| File | Violation | Description |
|------|-----------|-------------|
| [file] | [api -> repo] | [description] |
...

#### 2.2 Circular Imports ([n] found)

| Module A | Module B | Evidence |
|----------|----------|----------|
| [module] | [module] | [import chain] |
...

#### 2.3 God Objects ([n] found)

| File | Class | Methods | Attributes |
|------|-------|---------|------------|
| [file] | [class] | [n] | [n] |
...

#### 2.4 Spaghetti Dependencies ([n] found)

| File | Import Count |
|------|-------------|
| [file] | [n] |
...

#### 2.5 Business Logic in Routes ([n] found)

| File | Route | Violation |
|------|-------|-----------|
| [file] | [endpoint] | [description] |
...

---

### 3. Testing Gaps

#### 3.1 Missing Test Files ([n] found)

| Source File | Expected Test File | Priority |
|------------|-------------------|----------|
| [file] | [test_file] | [high/medium/low] |
...

**Test Coverage Breadth**: [n]% ([files_with_tests]/[total_files] files have tests)

#### 3.2 Test Quality Issues ([n] found)

| File | Issue | Description |
|------|-------|-------------|
| [file] | [flaky/no-assertions/etc] | [description] |
...

#### 3.3 Test Configuration

| Item | Status |
|------|--------|
| Test framework configured | [yes/no] |
| Coverage tracking enabled | [yes/no] |
| Coverage in CI pipeline | [yes/no] |
| Minimum coverage threshold | [n%/not set] |

---

### 4. Dependency Issues

#### 4.1 Outdated Packages ([n] found)

| Package | Current | Latest | Versions Behind | Severity |
|---------|---------|--------|----------------|----------|
| [pkg] | [ver] | [ver] | [major/minor/patch] | [high/medium/low] |
...

#### 4.2 Security Vulnerabilities ([n] found)

| Package | CVE | Severity | Fix Available |
|---------|-----|----------|--------------|
| [pkg] | [CVE-XXXX-XXXX] | [critical/high/medium] | [yes/no] |
...

#### 4.3 Unused Dependencies ([n] found)

| Package | Type | Recommendation |
|---------|------|---------------|
| [pkg] | [dependency/devDependency] | Remove |
...

#### 4.4 Dependency Pinning

| Item | Status |
|------|--------|
| Lock file present | [yes/no] |
| All versions pinned | [yes/no] |
| Unpinned dependencies | [n] |

---

### 5. Documentation Gaps

#### 5.1 Missing Docstrings ([n] found)

| File | Item | Type |
|------|------|------|
| [file] | [function/class name] | [function/class] |
...

**Docstring Coverage**: [n]% ([with_docstrings]/[total_public] public items have docstrings)

#### 5.2 README Assessment

| Section | Status |
|---------|--------|
| Installation | [present/missing] |
| Setup/Configuration | [present/missing] |
| Usage/Examples | [present/missing] |
| API Reference | [present/missing] |
| Contributing Guide | [present/missing] |
| License | [present/missing] |
| Environment Variables | [present/missing] |
| Deployment | [present/missing] |

#### 5.3 API Documentation ([n] undocumented endpoints)

| File | Endpoint | Method | Has Docs |
|------|----------|--------|----------|
| [file] | [path] | [GET/POST/etc] | [yes/no] |
...

#### 5.4 Stale Comments ([n] found)

| File | Line | Comment |
|------|------|---------|
| [file] | [line] | [comment text] |
...

---

## Prioritized Action Plan

### Quick Wins (< 30 min each, low risk) — [n] items

| # | Action | File(s) | Estimated Time | Impact |
|---|--------|---------|---------------|--------|
| 1 | [action] | [file(s)] | [time] | [impact] |
...

**Total Quick Win Time**: ~[n] hours
**Recommended**: Run `/tech-debt --fix-quick-wins` to auto-fix these.

### Medium Effort (1-4 hours each) — [n] items

| # | Action | File(s) | Estimated Time | Impact |
|---|--------|---------|---------------|--------|
| 1 | [action] | [file(s)] | [time] | [impact] |
...

**Total Medium Effort Time**: ~[n] hours

### Large Effort (1+ days each) — [n] items

| # | Action | File(s) | Estimated Time | Impact |
|---|--------|---------|---------------|--------|
| 1 | [action] | [file(s)] | [time] | [impact] |
...

**Total Large Effort Time**: ~[n] days

### Ongoing (continuous) — [n] items

| # | Practice | Current Status | Target |
|---|----------|---------------|--------|
| 1 | [practice] | [current] | [target] |
...

---

## Debt Reduction Roadmap

### Sprint 1 (This Week): Quick Wins
- [ ] Fix all quick wins (auto-fix available)
- [ ] Remove unused imports and dead code
- [ ] Fix bare exception handlers
- [ ] Remove debug print statements
- [ ] Pin dependency versions
- **Expected Score Improvement**: +[n] points

### Sprint 2 (Next 2 Weeks): Critical Paths
- [ ] Add tests for critical business logic
- [ ] Fix layer violations
- [ ] Update outdated dependencies with security issues
- [ ] Add docstrings to public API
- **Expected Score Improvement**: +[n] points

### Sprint 3 (Next Month): Architecture
- [ ] Refactor god objects
- [ ] Break up large files
- [ ] Resolve circular dependencies
- [ ] Improve test quality
- **Expected Score Improvement**: +[n] points

### Sprint 4+ (Ongoing): Maintenance
- [ ] Monthly dependency updates
- [ ] Enforce test coverage in CI (minimum [n]%)
- [ ] Code review checklist includes debt checks
- [ ] Quarterly debt re-assessment with `/tech-debt`

---

## Recommendations

### Process Improvements
- [ ] Add pre-commit hooks to catch TODO/FIXME accumulation
- [ ] Set up automated dependency update PRs (Dependabot/Renovate)
- [ ] Enforce minimum test coverage in CI pipeline
- [ ] Add linting rules to prevent new debt patterns
- [ ] Schedule monthly tech debt review sessions

### Tooling Recommendations
- [ ] Configure ruff/eslint with strict rules
- [ ] Set up mypy/TypeScript strict mode
- [ ] Add coverage reporting to CI (Codecov/Coveralls)
- [ ] Install pre-commit for automated code quality checks
- [ ] Use SonarQube/CodeClimate for continuous debt tracking

### Team Practices
- [ ] Adopt the "boy scout rule" — leave code cleaner than you found it
- [ ] Allocate 20% of sprint capacity to debt reduction
- [ ] Include debt impact in code review criteria
- [ ] Track debt score over time (run `/tech-debt` monthly)
- [ ] Celebrate debt reduction milestones

---

*Generated by `/tech-debt` command — Cortex*
*Re-run periodically to track debt trends over time.*
```

---

## Step 10: Output Summary

After generating the report, display a final summary to the user.

```
+============================================================+
|                  TECH DEBT SCAN COMPLETE                     |
+============================================================+
| Debt Score: [X]/100 — [Rating]                              |
|                                                             |
| Category Breakdown:                                         |
|   Code Quality:   [x]/100  ([n] issues)                    |
|   Architecture:   [x]/100  ([n] issues)                    |
|   Testing:        [x]/100  ([n] issues)                    |
|   Dependencies:   [x]/100  ([n] issues)                    |
|   Documentation:  [x]/100  ([n] issues)                    |
|                                                             |
| Total Issues Found: [N]                                     |
|   Quick Wins:     [n] (auto-fixable)                       |
|   Medium Effort:  [n]                                       |
|   Large Effort:   [n]                                       |
|   Ongoing:        [n]                                       |
|                                                             |
| Top 5 Actions:                                              |
|   1. [highest priority action]                              |
|   2. [second priority action]                               |
|   3. [third priority action]                                |
|   4. [fourth priority action]                               |
|   5. [fifth priority action]                                |
|                                                             |
| Report saved: TECH_DEBT.md                                  |
+============================================================+
```

If the score is below 50 (Poor or Critical):
```
!! WARNING: Technical debt is critically high.
!! Developer velocity and code reliability are likely impacted.
!! Recommend dedicating a full sprint to debt reduction.
!! Start with: /tech-debt --fix-quick-wins
```

If the score is 50-69 (Fair):
```
Technical debt is moderate. Schedule regular debt reduction.
Quick wins can improve the score by [estimated] points.
Run: /tech-debt --fix-quick-wins
```

If the score is 70-89 (Good):
```
Technical debt is manageable. Keep up good practices.
Address medium-effort items during regular development.
```

If the score is 90-100 (Excellent):
```
Excellent codebase health! Minimal technical debt detected.
Continue monitoring with periodic /tech-debt scans.
```

If `--fix-quick-wins` was applied, also show:
```
+------------------------------------------------------------+
|                  AUTO-FIX RESULTS                           |
+------------------------------------------------------------+
| Files Modified:    [n]                                      |
| Issues Fixed:      [n]                                      |
| Score Improvement: [old] -> [new] (+[delta] points)        |
|                                                             |
| Changes:                                                    |
|   Unused imports removed:     [n]                          |
|   Bare exceptions fixed:      [n]                          |
|   Trailing whitespace cleaned:[n]                          |
|   Missing __init__.py added:  [n]                          |
|   Debug prints removed:       [n]                          |
|   Imports sorted:             [n]                          |
|                                                             |
| Review changes with: git diff                               |
| Commit with: /ship                                          |
+------------------------------------------------------------+
```
