---
name: clean-java
description: Write clean, idiomatic, modern Java (21+) and avoid low-quality "AI slop" code. Use this skill whenever writing, reviewing, refactoring, or generating ANY Java code — including classes, services, data models, concurrency, error handling, or tests — even if the user does not explicitly say "clean code". Also use it for Minecraft plugins/mods (alongside the minecraft-paper-plugin or minecraft-mod skills), since those are Java too. Triggers: any .java file, mentions of Java, JVM, Maven/Gradle, JUnit, records, streams, "refactor this Java", "review my Java", or requests for production-quality Java.
---

# Clean Java

This skill encodes the patterns that separate professional, modern Java from the
generic boilerplate that code generators tend to produce. The goal is not
cleverness — it is code that is correct, immutable where possible, type-safe, and
obvious to the next reader.

Target **Java 21 LTS** by default. Use the type system to make illegal states
unrepresentable instead of validating them at runtime.

## How to use this skill

1. Before writing Java, scan the **anti-pattern checklist** below. Most quality
   problems are one of these in disguise.
2. For deeper guidance on a specific area, read the matching reference file:
   - `references/modern-java.md` — records, sealed types, pattern matching,
     virtual threads, switch expressions, `var`, sequenced collections.
   - `references/anti-patterns.md` — the full "AI slop" catalogue with
     good-vs-bad code pairs (god classes, anemic models, `null` returns,
     stringly-typed code, swallowed exceptions, stream misuse, and more).
   - `references/concurrency-and-errors.md` — `java.util.concurrent`, virtual
     threads, structured concurrency, exception design, `Optional` rules.
   - `references/testing-and-tooling.md` — JUnit 5, AssertJ, Mockito, JMH,
     and the static-analysis stack (Spotless, Error Prone, NullAway, JSpecify).
3. Prefer the patterns in those files over inventing your own. When in doubt,
   copy the style of the surrounding code.

## The core rules (apply these every time)

**Model data with the right shape.** Use `record` for immutable data carriers
(DTOs, value objects, event payloads). Use `enum` for closed sets of constants.
Use `sealed interface` + records for closed type hierarchies, then branch with an
exhaustive `switch` (no `default`) so the compiler forces you to handle new cases.

**Favour immutability.** Make fields `final`. Return unmodifiable or copied
collections. Immutable objects are automatically thread-safe and easier to reason
about. Reach for mutability only when you measure a need.

**Inject dependencies through the constructor.** Pass collaborators in as `final`
constructor parameters. Avoid static singletons (`Foo.getInstance()`) and field
injection — they hide dependencies and make the class hard to test.

**Never return `null` for "no result".** Return an empty collection, an empty
`Optional`, or throw. `Optional` is a *return type* only — never a field,
parameter, or `Optional<List<...>>`.

**Handle exceptions honestly.** Never write an empty `catch` or `catch (Exception
e)` that hides the cause. Catch the narrowest type you can act on, log or wrap with
the cause preserved, and never use exceptions for ordinary control flow. Use
try-with-resources for anything `Closeable`.

**Keep classes small and cohesive.** A class that does everything ("god class") or
a class that is only getters/setters with the logic elsewhere ("anemic model") are
both smells. Put behaviour next to the data it operates on.

**No magic values or stringly-typed code.** Name constants. Use enums and small
types instead of passing meaning around as raw `String`/`int`.

**Use streams for transformation, not side effects.** A stream pipeline should map
inputs to an output. Don't mutate external state inside `map`/`forEach`; if you're
fighting the pipeline, a plain loop is clearer.

**Let tooling enforce the rest.** Formatting, null-safety, and bug patterns should
be caught mechanically (see `references/testing-and-tooling.md`), not argued about.

## Quick anti-pattern checklist

Before finishing any Java, confirm none of these are present:

- [ ] An empty or `catch (Exception)` block that swallows errors
- [ ] A method returning `null` instead of empty collection / `Optional` / throw
- [ ] A `static` mutable field or a singleton holding state
- [ ] Magic numbers/strings that should be named constants or enums
- [ ] A data class that is only getters/setters (should be a `record`)
- [ ] A `switch` over a sealed/enum type with an unnecessary `default`
- [ ] Resource opened without try-with-resources
- [ ] Side effects inside a stream pipeline
- [ ] `var` hiding a non-obvious type, or used to look modern at the cost of clarity
- [ ] Mutable shared state accessed from multiple threads without protection

If any box is checked, fix it before declaring the code done.
