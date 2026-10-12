---
name: unit-tests
description: Write, review and prune unit tests that catch real bugs, and stop agent test bloat. Built on Osherove's The Art of Unit Testing - a test exercises one unit of work through its public entry point and checks one exit point (return value, state change, third-party call); every test names the bug it catches; at most one mock per test, stubs are never verified; constructor guards, getter/setter, pass-through, framework-restating and coverage-only tests are never written; every touched test file is pruned. Language and framework agnostic. Use when writing, extending, reviewing, pruning or auditing unit tests, after implementing a feature or fix, or when a coverage report flags gaps.
---

# Unit Tests

Agents over-produce tests: asked to "add tests", they write every test they can think of, and most catch nothing. A suite padded this way is slower, breaks on every refactor, and hides the few tests that matter. Every rule below exists to keep the suite small and sharp. Source: Osherove, *The Art of Unit Testing*.

If the project has its own test conventions (a skill, a CONTRIBUTING section, a style guide), they win on stack details: framework, assertion library, file layout. This skill decides **which tests are worth writing**. Per-stack mappings are in `references/stack-notes.md`.

## 1. The model

A **unit of work** runs from a public **entry point** to one observable **exit point**. It may span several classes or functions; it is not "one method". There are three exit points:

| Exit point | Assert with | Example |
|---|---|---|
| Return value or thrown error | the value, or the error type | `approve(order)` returns a rejection |
| Observable state change | a read through the public API or the store | the persisted status after `approve(order)` |
| Call to a third party the code does not control | ONE mock verification | the email was sent; the event was published |

Prefer return value, then state; use a mock only when the outgoing call IS the result. One exit point per test: if you would still care about the second assertion after the first fails, it is two tests. Several assertions on fields of one outcome are one test.

## 2. Value gate: every test names its bug

Before writing a test, state the realistic bug that makes it fail and that no existing test catches. No answer, no test.

**Write tests for:** business rules and calculations, state transitions, permission and ownership refusals, validation rules with domain meaning (cross-field, conditional), query filtering and scoping, regressions for real bugs, risky edges (empty, duplicate, rounding, locale and collation, concurrency).

**Never write:**
- constructor tests (null guards, "does not throw", "is not null"): constructors hold no logic
- getters/setters, defaults, equality or `toString` of plain data types; enum members or constants (unless a persisted value is pinned on purpose)
- "the container resolves it" / "it is registered" tests, and logic-free config binding
- tautologies: a stub returns X, the code returns X, no logic between
- pass-through handlers ("service called, 200 returned") and per-endpoint error-to-status mapping; test the shared mapper once
- single-field validation rules one field or boundary at a time (`name_at_256_passes` + `name_at_257_fails`); keep ONE wiring test per validator (a fully invalid input yields the expected field errors)
- framework or library behavior (the ORM saves, the router binds, the validation library validates); reflection that an annotation exists with no security reason
- "not null"-only or "does not throw"-only tests; duplicates of another test's scenario
- any test whose only purpose is executing an uncovered line

**Coverage is a pointer, not a target.** An uncovered line is a question: does a bug there matter? Answer with a behavior test or "plumbing, no test". Never gate a build on a coverage percentage per function; that gate is what produces the never-write list. To find a genuinely missing test, comment out a production line; if nothing goes red, one is missing.

## 3. Mocks and stubs

- **Stub**: feeds input to the code under test and is never asserted on, so it cannot fail the test. **Mock**: the one fake the test asserts against.
- **At most one mock per test, any number of stubs.** Two mocks means two exit points, two tests. Name them `stubRepo`, `mockMailer`.
- **Never verify a stub.** Asserting the login failed and then verifying the user store was queried is the canonical over-specification.
- Over-specification shows as: internal-state asserts, several mocks, verified stubs, exact text or order where "contains" would do. Symptom: the test breaks on a refactor that kept behavior. More than ~5% of a project's tests using mocks (not stubs) is a warning sign.
- Keep fakes loose; set up only what the scenario needs and match irrelevant arguments with "any".
- Fake only what crosses a boundary (network, clock, queue, external service). Use the real thing for side-effect-free collaborators (value objects, validators, mappers). Needing many setups on one dependency for one test signals a too-wide interface in production code; report it.

## 4. Trustworthy, maintainable, readable

**Trustworthy.**
- No logic in tests (`if`, loops, `switch`, `try/catch`); hardcode expected values, never recompute them with the production formula.
- See every new test fail once: break the production line, watch it go red, restore it. Tests for guards, markers or lint rules state that negative check in the PR.
- A baseline test pinning behavior known to change carries a comment naming what flips it. Without one it is a deletion candidate.
- A *registered* or *declared* assertion is paired with a test proving the mechanism *acts* at a realistic call site, since registration-only suites have shipped mechanisms that never fired.

**Maintainable.**
- Test through the public API, never private functions or internal state.
- Build the code under test and its data through factory helpers with defaults, so a constructor change is a one-line fix. Look for existing helpers before writing one; extract an arrange block on its third copy. Arrange fakes in the test or a helper it calls, not a shared setup.
- Never re-implement a production query in a test to check results; read the state back directly.
- Assert the error code or type, not message text, unless the exact text is the requirement.
- Each test runs alone and in any order: no shared mutable state, no test calling another.

**Readable.**
- Use Arrange / Act / Assert with blank lines between sections. Have exactly one Act, and capture its result in a variable before asserting.
- Name magic values (`OTHER_TENANT_ID = 99`).
- Assertion messages, when used, say why ("start date has not arrived"), never repeat the assertion.
- Name tests `UnitOfWork_Scenario_ExpectedBehavior`, or the equivalent in the stack's idiom. If you cannot name it, it tests too much.

## 5. Pre-flight

1. Read the unit of work: every branch, early return, and the exit point it ends in.
2. Read the test project setup and 2-3 existing test files; reuse their helpers and conventions.
3. Grade the test file you are about to touch (§7).

## 6. Test hygiene

- **Persistence**: a test about constraints (not-null, foreign key, unique) runs against an engine that enforces them. An in-memory fake store that enforces none lets a suite pass on data the real schema rejects.
- **Determinism**: use fixed dates and ids; no randomness or wall-clock time in asserted data. For "before/after now", capture both bounds and assert the range. Never sleep; await or poll with a timeout.
- **Parameterize**: a family differing by one input is one parameterized test. Property-based tests only for a genuine invariant of pure logic (money math, parsers, range arithmetic), never to restate a validation cap.
- **Levels**: integration tests (real database, network, containers) live apart from unit tests and are marked, so the unit suite stays a fast, always-green zone. A skipped test never runs in CI and counts for nothing.

## 7. Prune on touch

Grade every test file you edit with `references/grading.md`, in the same change. Delete its DELETE-grade tests and fix its REWRITE-grade ones. The PR carries one line per file: `order_service_test: 14 -> 6 (5 ctor guards, 3 pass-through)`. Standalone prune requests follow the procedure in the same reference.

## 8. Review checklist

Blocking:
- [ ] Each test names its bug; none hits the Never-write list (§2).
- [ ] One exit point per test; at most one mock; no verified stub; no internal-state asserts (§1, §3).
- [ ] No logic in tests; expected values hardcoded; each new test seen failing once (§4).
- [ ] No real network or external service in a unit test; constraint tests run on an enforcing engine (§6).
- [ ] Determinism rules hold (§6).
- [ ] Touched test files pruned, with counts in the PR (§7).
- [ ] A changed business behavior has a test; uncovered plumbing with a stated "no test" reason is fine.
- [ ] The build passes and every test, new and existing, is green.

Non-blocking (warn): AAA layout, naming, helper reuse, parameterization over copy-paste.
