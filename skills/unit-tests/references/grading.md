# Grading and pruning existing tests

Load when grading a test file you touch, reviewing tests, or pruning a project. The rules are in `SKILL.md` §1-§4; this file carries verdicts, typical shapes, and the procedure.

## Verdicts

| Verdict | Means |
|---|---|
| KEEP | Passes the value gate (SKILL §2). |
| REWRITE | Protects something real, written badly. Fix it in the same change. |
| DELETE | No engineering value. Remove it in the same change. |

## REWRITE

| Smell | Typical shape | Fix |
|---|---|---|
| Asserts through mock verification while the outcome is observable | `getManagers_ownOrg_readsThatOrg` checks only that the repo was called | Assert the return value or state |
| Verifies a stub, or more than one mock | Assert login failed, then also verify the user store was queried | Keep one mock; others become unasserted stubs |
| Vacuous: acts on a copy, so the input never changes | `members.toList().removeAt(0)` before calling the code | Mutate the real input; see it fail once |
| Swallows failures | Catches and ignores the exception; "all items match" over a possibly empty list | Assert the specific outcome; assert non-empty first |
| Copy-paste family differing by one input | `lessThan_*`, `greaterThan_*`, `compareTo_*` as separate tests | One parameterized test |
| Exact message or log text where the code or status matters | | Assert the error code or type, or "contains" |
| Logic in the test, or expected value computed with the production formula | | Straight-line test, hardcoded literal |
| Asserts generated SQL or query text the test engine cannot meaningfully check | | Move to an integration test, or delete |

## DELETE

| Pattern | Typical shape |
|---|---|
| Constructor null guard / does not throw / not null | `constructor_validArgs_doesNotThrow` |
| Plain data type get/set, defaults, equality | `money_sameValue_isEqual` where equality delegates to a number |
| Constants, counts, enum members | `tenantOwnedEntityCount_isSeventeen` |
| Container resolves / registered | `addServices_registersJobs` |
| Tautology: stub returns X, code returns X | `getAll_returnsSuppliers` with no filtering between |
| Pure delegation | `getCategories_delegatesToRepository` |
| Per-endpoint error-to-status mapping | `update_invalid_returns400` through a shared mapper |
| Single-field validation rule or plain cap boundary pair | `name_at256_passes` + `name_at257_fails` |
| Framework behavior | "the ORM reuses the connection" |
| "Not null"-only | empty store, asserts the result is not null |
| Reflection with no security reason | `idParameter_isTypedAsLong` |
| Baseline pinning a known gap with no "flips when" comment | `duplicateRoundNumber_currentlyAllowed` |
| Permanently skipped or "manual check" tests | |
| Duplicate of another test's scenario | |

Not DELETE: an architecture guard with a security reason (every tenant-owned entity carries the tenant filter; no route constraint truncates large ids), written once, with a negative check.

## Procedure

1. Grade every test in the file. Read the production unit of work when the name does not tell you the exit point.
2. Before deleting the only test that covers a production branch, ask whether that branch carries behavior. If it does, the verdict is REWRITE.
3. Apply: delete DELETE tests and any helpers or fixtures they leave unused; fix REWRITE tests.
4. Build and run the project's tests. All green.
5. PR description: one line per file, `order_service_test: 14 -> 6 (5 ctor guards, 3 pass-through)`.

Standalone prune of a large suite: one test project or module per PR, piloting the first before the rest. Grading a whole suite parallelizes well; give every grader this file as the shared rubric, spot-check their KEEP calls on controllers and validators, and tighten the rubric once if they are lenient.
