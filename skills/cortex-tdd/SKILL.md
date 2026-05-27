---
name: cortex-tdd
description: "MUST USE before writing implementation code for any feature, bug fix, or behavior change. Enforces test-first discipline (red → green → refactor) using the project's language-specific test framework (pytest + pytest-asyncio for Python/FastAPI, Jest + supertest for NestJS, JUnit 5 + Mockito + MockMvc for Spring Boot). Integrates with the Cortex testing skill and the auto-build Phase 11. Skipping this leads to code without tests, regressions on every refactor, and inability to confidently /ship."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with cortex plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "1.0"
---

# Cortex TDD — Test-First Discipline, Language-Aware

The Cortex testing skill enforces test PYRAMID and quality. This skill enforces test TIMING — write tests BEFORE implementation, not after. The two skills are complementary: this one decides WHEN to write tests; the testing skill decides HOW.

TDD is non-negotiable for any code that will end up in `/ship`. The exception is documented at the bottom of this skill.

---

## When to use this skill

Always fire when the user asks you to:
- Implement a new feature (new function, new endpoint, new service method, new component)
- Fix a bug (the bug becomes the failing test)
- Change a behavior (the change becomes the test diff)
- Refactor risky code (the existing tests are the safety net; if they don't exist, write them first)

Skip ONLY for:
- Documentation edits
- README / CHANGELOG updates
- Comment-only changes
- Pure formatter runs (ruff format, prettier --write)
- Genuine exploratory spikes that will be deleted before commit (mark them with `// EXPLORATORY — to delete` and DELETE them)

---

## The Cortex Red-Green-Refactor Loop

### Step 1 — Detect the language (use Step 0a from alpha-architecture)

The test commands and framework depend on the project's backend language. Detect first:

| Language | Test framework | Test runner command | Coverage tool |
|----------|---------------|---------------------|---------------|
| Python / FastAPI | `pytest` + `pytest-asyncio` + `httpx` | `pytest tests/ -v` | `pytest --cov=app --cov-report=term-missing` |
| Node.js / NestJS | `jest` + `supertest` | `pnpm test` | `pnpm test -- --coverage` |
| Java / Spring Boot | JUnit 5 + Mockito + MockMvc | `./gradlew test` | `./gradlew jacocoTestReport` |
| Next.js frontend | Vitest + React Testing Library | `pnpm test` | `pnpm test -- --coverage` |
| Playwright E2E | Playwright | `pnpm playwright test` | n/a |
| React Native | Jest + React Native Testing Library | `pnpm test` | `pnpm test -- --coverage` |

Load the appropriate `CODE_PATTERNS_<LANG>.md` from `skills/alpha-architecture/references/` for the test patterns matching the detected language.

### Step 2 — Write the failing test (RED)

Write ONE test that captures the new behavior or the bug. It MUST fail when run — that's the proof the test is actually testing the right thing.

Per-language scaffolding:

**Python / FastAPI** — `tests/test_<module>.py`:
```python
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_<behavior_name>(client: AsyncClient):
    """Given <context>, when <action>, then <expected_outcome>."""
    # Arrange
    ...
    # Act
    response = await client.post("/api/v1/...", json={...})
    # Assert
    assert response.status_code == 200
    assert response.json() == {...}
```

**NestJS** — `<module>.spec.ts`:
```typescript
describe('<Service or Controller>', () => {
  it('should <behavior> when <condition>', async () => {
    // Arrange
    const mock = ...
    // Act
    const result = await service.method(...)
    // Assert
    expect(result).toEqual(...)
  });
});
```

**Spring Boot** — `<Class>Test.java`:
```java
@SpringBootTest
class FooServiceTest {
  @Test
  void should<Behavior>When<Condition>() {
    // Arrange
    // Act
    // Assert
    assertThat(actual).isEqualTo(expected);
  }
}
```

Run the test. It MUST fail with a meaningful error ("function not found", "wrong status code", "expected X got Y"). If it fails with a parse error or compilation error, the test is wrong, not the implementation.

### Step 3 — Implement the minimum to make it pass (GREEN)

Write the LEAST amount of code that makes the test pass. Don't gold-plate. Don't add error handling for cases the test doesn't cover. Don't refactor adjacent code. Just go GREEN.

Run the test. It MUST pass now. Also run the full test suite — your change must not break existing tests.

### Step 4 — Refactor with confidence (REFACTOR)

Now that the test is green, clean up:
- Extract helper functions
- Apply the project's layer segregation rules (no api/ → repositories/ direct imports)
- Apply naming conventions from the language profile
- Remove duplication

Run tests after every refactor step. If tests turn red, undo the refactor — the test is your safety net.

### Step 5 — Add more tests for edge cases

The first test covered the happy path. Add tests for:
- Failure cases (invalid input, missing fields, auth failures)
- Boundary conditions (empty list, single item, max size)
- Concurrent access (if relevant)
- Permission boundaries (if RBAC is enabled)

Repeat red → green → refactor for each.

---

## Cortex-specific TDD patterns

### Pattern: Layer-specific tests

Cortex enforces strict layer segregation. Each layer gets its own test type:

| Layer | Test type | Mock |
|-------|-----------|------|
| `api/` controllers | Integration test via TestClient/supertest/MockMvc | Mock the service layer |
| `services/` business logic | Unit test | Mock the repository layer |
| `repositories/` data access | Integration test against test DB | No mocks — hit real DB |
| `models/` domain entities | Unit test (validation, methods only) | None |
| `tasks/` Celery/BullMQ | Unit test the task function + integration test the queue | Mock external I/O |

Don't write an "end-to-end test of /api/v1/users" when what you actually need is a unit test of `UserService.create()`. Match the test scope to the layer.

### Pattern: TDD for `/retrofit`

When using `/retrofit` to add a feature to an existing app, write the test BEFORE running `/retrofit`. The test becomes the acceptance criterion: retrofit is done when the test passes.

### Pattern: TDD for `/refactor`

Before any refactor, audit existing test coverage of the target code. If coverage is below 80%, WRITE TESTS FIRST to lock down current behavior. Then refactor. Then verify tests still pass.

### Pattern: TDD with the Cortex personas

When delegating to a Cortex persona (Priya for services, Marcus for APIs, etc.), the delegation prompt MUST include the failing test as input. The persona's job is to make it green. This makes the success criterion machine-checkable, not opinion-based.

---

## The exception: when NOT to TDD

There is exactly one case where TDD is correctly skipped:
- **A genuine exploratory spike** — you don't yet know what the right interface looks like, and you need to prototype to find out. In this case:
  1. Mark the spike clearly: a top-of-file comment `// EXPLORATORY SPIKE — to delete before commit`
  2. Branch name MUST start with `spike/`
  3. **DELETE the spike code before merging**. Then write the real implementation with TDD.
  4. The final commit on the branch must contain ONLY the TDD'd code, not the spike.

Anything other than a true spike — TDD applies. "I'm in a hurry" is not an exception.

---

## Anti-patterns

- ❌ **Writing tests AFTER implementation.** This is "regression coverage", not TDD. Useful but doesn't catch design flaws; the implementation drives the test, which gives a false sense of safety.
- ❌ **Tests that test the implementation, not the behavior.** `expect(spy).toHaveBeenCalledWith(...)` is fragile and refactor-hostile. Test outputs and observable side effects, not internal calls.
- ❌ **One giant test for everything.** A test that asserts 12 things fails 12 ways. Each test = one behavior.
- ❌ **Skipping refactor because tests are green.** The refactor step is where the code becomes maintainable. Green-without-refactor produces working garbage.
- ❌ **Mocking your own code's layer dependencies.** Mock external I/O (DB, HTTP, queues). Don't mock your own services — that's a code smell screaming for better layer boundaries.
- ❌ **Calling spike code "TDD" because you "tested it manually".** Manual testing is not TDD. Write the test.
- ❌ **Disabling/skipping failing tests** to ship faster. A skipped test is worse than no test — it's documented broken code.

---

## Integration with downstream Cortex commands

- `/gen-tests` — generates tests from existing code (the OPPOSITE of TDD). Use only for legacy untested code you didn't write.
- `/code-review` — fails on insufficient coverage. TDD'd code passes by default.
- `/ship` — runs full test suite. If TDD was followed, this is a formality.
- `/health-check` — flags test files with `.skip` or `.only` left in.
- `/auto-build` Phase 11 — runs TDD per-feature for everything in the FEATURE_PROFILE.
- `cortex-verification` skill — uses test results as evidence. Without tests, verification can't claim "done".
