# Stack notes

The rules in `SKILL.md` are stack-independent. This table maps their vocabulary onto common ecosystems. Project conventions win where they differ.

| Concept | .NET | JS / TS | Python | JVM | Go |
|---|---|---|---|---|---|
| Parameterized test | xUnit `[Theory]` + `[InlineData]`, NUnit `[TestCase]` | `test.each` | `pytest.mark.parametrize` | JUnit 5 `@ParameterizedTest` | table-driven `t.Run` |
| Property-based test | FsCheck | fast-check | Hypothesis | jqwik | `testing/quick`, rapid |
| Stub / mock library | Moq, NSubstitute | Jest / Vitest mocks, sinon | `unittest.mock`, pytest-mock | Mockito | hand-written fakes, gomock |
| Verify one mock | `mock.Verify(...)`, `Received()` | `expect(fn).toHaveBeenCalledWith(...)` | `mock.assert_called_once_with(...)` | `verify(mock).call(...)` | assert on the fake's recorded calls |
| Constraint-enforcing test store | SQLite in-memory or a container; not EF `UseInMemoryDatabase` | SQLite or a container; not a plain object map | SQLite or a container | H2 in compatible mode, or Testcontainers | SQLite or a container |
| Fixed clock | inject `TimeProvider` | fake timers, injected clock | `freezegun`, injected clock | injected `Clock` | injected `func() time.Time` |
| Assert an error | `act.Should().Throw<T>()`, `Assert.Throws<T>` | `expect(fn).toThrow(Type)` | `pytest.raises(Type)` | `assertThrows(Type.class, ...)` | `errors.Is` / `errors.As` |
| Access internals for tests | `InternalsVisibleTo`, never widening visibility | export from an internal module | test the public function | package-private + same package | same package `_test.go` |

Naming idioms: `Method_Scenario_Expected` in .NET and JVM, `describe`/`it("...")` sentences in JS/TS, `test_method_scenario_expected` in Python, `TestMethod_Scenario` with subtests in Go. Each one must carry the unit of work, the scenario, and the expected exit point.
