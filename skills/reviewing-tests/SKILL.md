---
name: reviewing-tests
description: Use when reviewing test quality in a PR or codebase audit — applies a critical reviewer mindset to catch anti-patterns, false confidence, and the cognitive biases that cause reviewers to accept bad tests. The inverse of writing-effective-tests.
---

# Reviewing Tests

## Overview

**The Reviewer's Job:** Prove the test suite is wrong. Not check that it passes — assume it passes. Your job is to find the gap between what the tests *claim* to verify and what they *actually* verify.

**The Inverter Principle:** For every claim ("tests tenant isolation", "tests auth", "verifies persistence"), invert it:
- "Does it really test isolation, or just that tenant A sees its own data?"
- "Does it really test auth, or is security disabled in the test config?"
- "Does it really verify persistence, or just verify a mock was called?"

If the inverted question has no test that would catch it, the claim is false confidence.

---

## Project-Specific Patterns

Before reviewing tests, check if the current project has additional test conventions:
- `docs/development/TEST_PATTERNS.md` — project-specific test rules, DB constraints, data setup patterns
- `.claude/skills/` in the project root — project-level skills that supplement this one
- `CLAUDE.md` — may contain test-related instructions

Use project-specific patterns as additional review criteria. Flag violations of project patterns at the same severity as general anti-patterns.

**Conflict resolution:** If a project pattern contradicts this skill, flag it: "Note: project pattern X conflicts with general review rule Y. Applying project pattern. Should these be aligned?" This prevents silent drift between global and project conventions.

## Biases to Suppress Before You Start

### 1. Green Bar Bias
"All tests pass, so the suite is good."

Passing tests prove the paths exercised work. They say nothing about paths not exercised. Look for **missing tests**, not passing ones.

### 2. Coverage Number Bias
"95% coverage means we're safe."

Coverage measures lines executed, not behaviors verified. A test that calls a function and asserts nothing is 100% coverage, 0% value. Ask: are the assertions meaningful, not whether the line was hit?

### 3. Volume Bias
"5,000 tests — this codebase is well-tested."

5,000 tests that verify mock wiring are worse than 50 integration tests that verify behavior. Count **behaviors tested**, not test methods.

### 4. Test Name Trust
"The test is called `testTenantIsolation`, so isolation is tested."

Read the assertions. Names lie. A `TenantIsolationIntegrationTest` that never queries as a second tenant proves nothing about isolation.

### 5. Mock Confidence Bias
"All dependencies are mocked, so this is isolated and reliable."

Over-mocking tests implementation, not behavior. The more mocks, the less the test proves. Many mocks = high probability of false confidence.

### 6. Security Config Blindness
"Every test has `@WithMockUser`, so auth is tested."

If `TestSecurityConfig` permits all requests unconditionally, `@WithMockUser` is cosmetic decoration. Check the security config, not just annotations.

---

## Review Checklist

Work through these layers in order. Each layer has targeted questions. Flag every gap.

---

### Layer 0: Test Suite Structure

Before reading a single test, ask:

- What is the unit:integration:E2E ratio? Does it match the architecture?
  - API service / microservice → expect 20% unit, 70% integration, 10% E2E
  - Monolith with rich domain logic → expect 70% unit, 20% integration, 10% E2E
  - Heavy integration bias in an API-heavy codebase is a sign of over-mocking
- Are error paths tested at any layer? (401, 403, 404, 422, 500)
- Is there a regression test for every known production bug? (Check bug tracker → test files)
- Are there tests that document known gaps? (flip-assertion pattern)

---

### Layer 1: For Each Test File

Open each test file and ask before reading individual tests:

- **What does the test setup do?** Is there a `TestSecurityConfig`, a SQL seed file, or `@BeforeEach` that might silently invalidate all tests in this file?
- **What are the mocks?** List them. Too many mocks = red flag for testing implementation.
- **Is `Strictness.LENIENT` applied?** (Java: `@MockitoSettings(strictness = Strictness.LENIENT)`) If yes, treat every mock-heavy test as suspect.

---

### Layer 2: For Each Test

For every test method, ask:

1. **What is actually being asserted?** (Not what the test name says — read the assert lines.)
2. **What is NOT being tested that should be?** (The inverse scenario, the second tenant, the wrong role, the missing field.)
3. **Are stubs being verified?** `verify(stub).method(...)` = testing implementation, not behavior. Flag it.
4. **Is the mock boundary correct?** Managed dependencies (repositories, domain objects, your own classes) should NOT be mocked. External APIs, email, queues should be.
5. **Can I rename an internal method and have these tests still pass?** If yes, they're coupled to implementation. If the test would break on a rename that doesn't change behavior, it's wrong.

---

### Layer 3: Unit Tests

- Are repositories/DAOs mocked? They should not be for most service tests. Integration test instead.
- Is `verify(dao).save(...)` the **primary** assertion? Wrong — check the return value or DB state.
- Is there any assertion on the return value at all, or is the test entirely `verify()` calls?
- Are the tests output-based (preferred) or communication-based (verify-heavy)?

**Red flag:** A service test with 4+ mocks and all assertions are `verify()` calls. That test verifies mock wiring, not service behavior.

---

### Layer 4: Controller / API Tests

- **Check `TestSecurityConfig` first.** Does it permit all requests? If yes, auth annotations are invisible and every security test is a false positive.
- Are the following tested for each endpoint?
  - 401 (no auth / invalid token)
  - 403 (authenticated but wrong role)
  - 422 / 400 (invalid input)
  - 404 (resource not found)
  - Happy path
- Is `@WithMockUser` used alongside a permissive security config? If so, remove it mentally and ask: would the test still pass? If yes, `@WithMockUser` is cosmetic.
- Does the test verify HTTP concerns (status codes, headers, response shape) or is it testing business logic that belongs in a service test?

---

### Layer 5: Integration Tests

- Is the test database the **same engine as production**? SQLite ≠ PostgreSQL. SQLite silently differs on JSON, constraints, and types. Flag SQLite in a Postgres shop.
- For each test that claims to test tenant isolation:
  - Does it write data as Tenant A **and** query as Tenant B?
  - If it only reads its own data, it proves nothing about isolation.
- Is data setup using a SQL seed file AND `@BeforeEach`? Two mechanisms = silent collisions. Flag it.
- Are hardcoded IDs (`1`, `2`, `100`) in seed data or tests? They create invisible coupling between test files.
- Can tests run in any order? Is there shared mutable state between tests?
- Is `@Transactional` used on tests with `MockMvc`? (Java) That works. Is it used with `TestRestTemplate`? That does NOT work the same way — the transaction doesn't span both sides of the HTTP call.

---

### Layer 6: Security Tests (Standalone Check)

This gets its own layer because security failures are data-integrity and compliance failures.

1. Locate `TestSecurityConfig` (or equivalent). Read it fully. Does it have `anyRequest().permitAll()`? If yes, flag as Critical.
2. Find every `@PreAuthorize` / `@Secured` / permission annotation in production code.
3. For each one: is there a test that would fail if the annotation were deleted? If not, the annotation is unverified.
4. Find tests that assert 401. Do they actually disable auth headers, or do they rely on a config that bypasses auth?
5. Find tests that assert 403. Do they actually switch to an unauthorized role, or is this cosmetic with permissive config?

---

## The Inverter — Applied

Use this table during review. For each test claim, apply the inversion:

| Test Claims To... | The Inversion Question | What To Check |
|---|---|---|
| Test tenant isolation | "Does it query as a different tenant?" | Find the second-tenant query |
| Test authentication | "Is auth actually enforced in test config?" | Read `TestSecurityConfig` |
| Test authorization | "Would the test fail if the role annotation were removed?" | Delete annotation mentally, does a test catch it? |
| Verify persistence | "Does it check DB state or just verify a mock?" | Look for DB read after write |
| Test error handling | "Is the error path actually triggered?" | Trace the input that causes the error |
| Test validation | "Are invalid inputs tested?" | Find negative cases |

---

## Review Output Format

Categorize every finding before writing the review. Don't mix severities in prose.

### Critical
Security or data-integrity risk. Production data could be exposed or corrupted. The test suite provides false assurance against a real threat.

Examples:
- `TestSecurityConfig` disables all auth — every security test is a false positive
- Tenant isolation test never queries as a second tenant — RLS could be broken and undetected
- Test database is SQLite, production is PostgreSQL — constraint behavior differs

### High
False confidence. The test looks credible but proves nothing about the behavior it names. A real bug in this area would pass the test suite.

Examples:
- `verify(dao).save(any())` as primary assertion — tests mock wiring, not behavior
- `Strictness.LENIENT` applied globally — unused stubs hidden, tests drift from reality
- Test name says "integration" but all dependencies are mocked

### Medium
Anti-pattern that increases maintenance cost or reduces signal quality. Not immediately dangerous but degrades the suite over time.

Examples:
- Hardcoded IDs in test data — invisible coupling between tests
- Competing data setup (SQL seed + `@BeforeEach`) — unclear which record wins
- `@Transactional` with `TestRestTemplate` — incorrect assumption about transaction scope

### Low
Style, naming, or minor improvements. Does not affect correctness.

Examples:
- Test names describe methods rather than behaviors
- No comment explaining why a test documents a known gap
- Missing `arrange/act/assert` structure making tests hard to scan

---

## Anti-Pattern Reference

These patterns were identified in real code reviews. Each one passed CI with green bars.

---

### Fake Tenant Isolation

Test creates data as Tenant A, reads as Tenant A, asserts it's found. Never proves Tenant B cannot see it.

```java
// WRONG — always passes even if RLS is completely disabled
void tenantCanReadOwnData() {
    setTenantContext("tenant-a");
    repo.save(new Goal("target", "tenant-a"));
    assertThat(repo.findAll()).hasSize(1); // still querying as tenant-a
}

// RIGHT — proves cross-tenant invisibility
void tenantCannotReadAnotherTenantsData() {
    setTenantContext("tenant-a");
    repo.save(new Goal("target", "tenant-a"));
    setTenantContext("tenant-b");           // switch
    assertThat(repo.findAll()).isEmpty();   // cross-tenant check
}
```

**Severity: Critical**

---

### Security Config Bypass

`TestSecurityConfig` permits all requests. `@WithMockUser` is decoration.

```java
// WRONG — every @PreAuthorize annotation is now invisible to tests
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http.authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
    return http.build();
}

// RIGHT — keep real security config, drive roles explicitly
@Test
@WithMockUser(roles = "EMPLOYEE")
void employee_cannot_access_admin_endpoint() throws Exception {
    mockMvc.perform(get("/api/admin/users")).andExpect(status().isForbidden());
}

@Test
void unauthenticated_returns_401() throws Exception {
    mockMvc.perform(get("/api/goals")).andExpect(status().isUnauthorized());
}
```

**Severity: Critical**

---

### Verify-on-DAO (Testing Mock Wiring)

`verify(dao).save(any())` as the primary assertion tests implementation, not behavior. Breaks on any internal refactor.

```java
// WRONG — verifies wiring, not behavior
void createUser_callsDao() {
    userService.createUser(new UserRequest("alice@example.com"));
    verify(userDao).insert(any(User.class)); // breaks if impl switches to batchInsert()
}

// RIGHT — verify observable output or DB state
void createUser_persistsAndReturnsId() {
    UserResponse resp = userService.createUser(new UserRequest("alice@example.com"));
    assertThat(resp.getId()).isNotNull();
    assertThat(userRepository.findById(resp.getId())).isPresent();
}
```

**Severity: High**

---

### LENIENT Strictness Hiding Drift

`@MockitoSettings(strictness = Strictness.LENIENT)` suppresses "unnecessary stubbing" errors. Tests accumulate stubs for code paths never exercised.

```java
// WRONG — suppresses warnings globally, stubs drift silently
@MockitoSettings(strictness = Strictness.LENIENT)
class GoalServiceTest { ... }

// RIGHT — default STRICT_STUBS, use lenient() per-stub when genuinely needed
// No annotation. Unused stubs now fail loudly — remove or fix them.
```

**Severity: High**

---

### Competing Data Setup

SQL seed file AND `@BeforeEach` both insert the same rows with `ON CONFLICT DO NOTHING`. Silent collisions. Hardcoded IDs couple unrelated test files.

```java
// WRONG — two mechanisms, silent collision, hardcoded ID
// data.sql: INSERT INTO users (id, email) VALUES (1, 'alice@example.com') ON CONFLICT DO NOTHING;
@BeforeEach void setUp() {
    jdbcTemplate.update("INSERT INTO users (id, email) VALUES (1, 'alice@example.com') ON CONFLICT DO NOTHING");
}

// RIGHT — one mechanism, generated IDs
@BeforeEach void setUp() {
    testUser = userRepository.save(UserFactory.build()); // UUID, no hardcoded ID
}
```

**Severity: Medium**

---

### Anti-Pattern 6: @Transactional with Non-JPA Data Access (Deadlock)

Spring's `@Transactional` on tests holds one connection. Non-JPA libraries (JDBI, jOOQ, MyBatis, raw JDBC) acquire separate connections. Both lock the same tables → deadlock → pool exhaustion → cascading failures.

```java
// WRONG — deadlocks when data access uses separate connections
@Transactional
public class OrderIntegrationTest extends BaseIntegrationTest {
    @BeforeEach void setUp() {
        jdbi.useHandle(h -> h.execute("INSERT INTO orders ...")); // connection B
        // Spring holds connection A → deadlock
    }
}

// RIGHT — explicit cleanup, sequential execution
@Execution(ExecutionMode.SAME_THREAD)
public class OrderIntegrationTest extends BaseIntegrationTest {
    @BeforeEach void setUp() { /* insert test data */ }
    @AfterEach void cleanUp() { /* delete test data in FK-safe order */ }
}
```

**Review check:** If a `@SpringBootTest` class uses JDBI/jOOQ/raw JDBC (directly or through services) AND has `@Transactional`, flag as **Critical** — it will deadlock under load.

**Severity: Critical**

---

### Anti-Pattern 7: FK-Unsafe Cleanup Order

Test cleanup deletes parent rows before child rows, hitting RESTRICT constraints. The error appears in `@BeforeEach`/`@AfterEach`, not the test itself — maddening to debug.

```java
// WRONG — FK violation: orders reference customers
@AfterEach void cleanUp() {
    db.execute("DELETE FROM customers WHERE tenant_id = ?", TENANT_ID);
    // ERROR: violates RESTRICT setting of foreign key constraint
}

// RIGHT — children first, then parents
@AfterEach void cleanUp() {
    db.execute("DELETE FROM order_items WHERE tenant_id = ?", TENANT_ID);
    db.execute("DELETE FROM orders WHERE tenant_id = ?", TENANT_ID);
    db.execute("DELETE FROM customers WHERE tenant_id = ?", TENANT_ID);
}
```

**Review check:** In any `@AfterEach`/`@AfterAll` that does SQL DELETEs, verify the deletion order respects FK constraints.

**Severity: High**

---

### Anti-Pattern 8: Hardcoded Date Time Bombs

Tests use hardcoded dates (e.g., `2025-01-01`) that pass when written but fail months later when validation rejects past dates. Common in subscription systems, billing cycles, review periods.

```java
// WRONG — fails after 2025-01-01 passes
.startDate(LocalDate.of(2025, 1, 1))

// RIGHT — always relative to now
.startDate(LocalDate.now().plusMonths(1))
```

**Review check:** Grep for hardcoded year values in test date fields. If the service validates against `now()`, these are time bombs.

**Severity: High**

---

### Anti-Pattern 9: Sync Assert on Async Code

Test triggers an `@Async` / `CompletableFuture` / background job then immediately asserts. Passes when the machine is fast, fails on CI.

```java
// WRONG — race condition
client.post("/api/jobs/" + id + "/process");
assertEquals("COMPLETE", db.query("SELECT status FROM jobs WHERE id = ?", id));

// RIGHT — poll with bounded timeout
for (int i = 0; i < 20; i++) {
    String status = db.query("SELECT status FROM jobs WHERE id = ?", id);
    if ("COMPLETE".equals(status)) break;
    Thread.sleep(500);
}
assertEquals("COMPLETE", status);
```

**Review check:** If the code under test uses `@Async` or spawns threads, and the test asserts immediately with no wait/poll, flag as flaky.

**Severity: High**

---

### Anti-Pattern 10: Array Assertion on Paginated Response

API returns `{data: {content: [...], totalElements, page}}` but test asserts `$.data` as an array. Breaks silently when endpoint is updated from list to paginated.

```java
// WRONG
.andExpect(jsonPath("$.data").isArray())
.andExpect(jsonPath("$.data.length()").value(2));

// RIGHT
.andExpect(jsonPath("$.data.content").isArray())
.andExpect(jsonPath("$.data.totalElements").value(2));
```

**Review check:** For list endpoint tests, verify JSON path matches actual response shape (`Page<T>` wrapper vs raw list).

**Severity: Medium**

---

## Quick Reference Card

```
BIAS                    | COUNTER-QUESTION
----------------------- | ------------------------------------------
Green Bar               | What is NOT tested?
Coverage Number         | Are the assertions meaningful?
Volume                  | How many behaviors, not methods?
Test Name Trust         | Read the asserts — what do they actually check?
Mock Confidence         | What does this prove if the mock is removed?
Security Config         | Does TestSecurityConfig permit all? Check first.

LAYER                   | FIRST QUESTION
----------------------- | ------------------------------------------
Suite structure         | What's the unit:integration ratio?
Test file               | Is there a permissive security config or global LENIENT?
Each test               | What is actually asserted?
Unit tests              | Is verify() the primary assertion?
Controller tests        | Is auth disabled in test config?
Integration tests       | Is the second tenant ever queried?
Security tests          | Would the test fail if I deleted the annotation?

SEVERITY                | DEFINITION
----------------------- | ------------------------------------------
Critical                | Security/data-integrity risk, false assurance
High                    | False confidence — test looks good, proves nothing
Medium                  | Anti-pattern increasing maintenance cost
Low                     | Style, naming, minor
```
