# Testing & Tooling

## Testing

### JUnit 5 (Jupiter) — the standard

```java
@Test
@DisplayName("withdraw reduces balance")
void withdrawReducesBalance() {
    // Arrange
    var account = new Account(100);
    // Act
    account.withdraw(30);
    // Assert
    assertThat(account.balance()).isEqualTo(70);
}
```

- Structure every test as **Arrange-Act-Assert** (a.k.a. Given-When-Then) — three
  short blocks. No loops or conditionals in tests.
- Name tests for behaviour, not method names. Use `@DisplayName` for readability.
- Use `@ParameterizedTest` with `@CsvSource`/`@MethodSource` for multiple inputs
  instead of copy-pasting tests.

### AssertJ for assertions

Fluent and readable: `assertThat(x).isEqualTo(...)`,
`assertThat(list).containsExactly(...)`,
`assertThat(obj).usingRecursiveComparison().isEqualTo(expected)`.

### Mockito — mock with discipline

- **Don't mock what you don't own** — never mock JDK/library types like `List` or
  `Map`. Mock your own service/repository interfaces.
- Don't mock infrastructure you should actually integration-test. A suite that
  mocks an HTTP client to always return 200 has high coverage and low confidence.
  Use **Testcontainers** / WireMock for real boundaries.
- Avoid `Thread.sleep` in async tests — use Awaitility.

### Coverage caveats

Coverage measures lines executed, not bugs caught. Don't chase 100%. For critical
logic, consider mutation testing (PIT). Property-based testing (jqwik) is valuable
for pure functions with input invariants.

## Static analysis & formatting (enforce mechanically)

Wire these into CI so quality is automatic, not argued about:

- **Spotless** + **google-java-format** — auto-formatting (`spotlessApply` /
  `spotlessCheck`). Removes all style debate.
- **Error Prone** (Google) — a javac plugin with 500+ bug-pattern checks at
  compile time.
- **NullAway** — Error-Prone-based null-safety analysis; catches NPEs at compile
  time.
- **JSpecify** — tool-independent nullness annotations (`@Nullable`, `@NonNull`,
  `@NullMarked`). Annotate packages `@NullMarked` and let tools find more bugs.
- **SpotBugs** (bytecode bug patterns), **PMD** (300+ rules), **Checkstyle**
  (style), **SonarQube** (broad analysis) as desired.

## Performance & benchmarking

- **Never hand-roll microbenchmarks.** The JVM applies warmup/JIT compilation,
  dead-code elimination, and deoptimization, so naive timing loops lie.
- Use **JMH** (Java Microbenchmark Harness). Consume results with `Blackhole` to
  defeat dead-code elimination, and let JMH handle warmup and forking.
- Profile before optimizing. Premature optimization is itself an anti-pattern —
  write clear code first, measure, then optimize the proven hot path.

## Exemplary repositories to learn from

When in doubt about idiomatic style, study these:
- **google/guava** — API design, immutable collections.
- **ben-manes/caffeine** — high-performance concurrent caching, clean builder API.
- **google/guice** — minimalist, type-safe DI; deliberate feature restraint.
- **junit-team/junit5** — modular architecture, single `Extension` API.
- **netty/netty** — performance-oriented design, single-thread-per-EventLoop.
- **quarkusio/quarkus**, **micronaut-core** — compile-time DI, minimal reflection.
