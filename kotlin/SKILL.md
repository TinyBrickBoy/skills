---
name: kotlin
description: Write clean, idiomatic, modern Kotlin and avoid Java-isms and "AI slop" patterns. Use this skill whenever writing, reviewing, refactoring, or generating ANY Kotlin code — including classes, coroutines, data models, extensions, or tests — even if the user does not explicitly say "clean code". Triggers: any .kt or .kts file, mentions of Kotlin, KMP (Kotlin Multiplatform), coroutines, Ktor, Exposed, Compose (non-Android), "refactor this Kotlin", "review my Kotlin", or requests for production-quality Kotlin.
---

# Clean Kotlin

This skill captures the patterns that separate idiomatic, professional Kotlin
from Java code mechanically translated to `.kt` files. The goal is code that is
safe by construction, concise without being cryptic, and obvious to the next reader.

Target **Kotlin 2.x** by default. Lean on the type system — especially nullability
and sealed types — to make illegal states unrepresentable instead of validating
them at runtime.

## How to use this skill

1. Before writing Kotlin, scan the **anti-pattern checklist** below.
2. For deeper guidance on a specific area, read the matching reference file:
   - `references/idioms.md` — data classes, sealed types, extension functions,
     scope functions, value classes, `when` expressions, destructuring, standard-
     library collections.
   - `references/anti-patterns.md` — the full catalogue of Java-isms and Kotlin-
     specific smells with good-vs-bad pairs (`!!`, mutable state, `object` god
     singletons, misused scope functions, and more).
   - `references/coroutines.md` — `suspend` functions, structured concurrency,
     `Flow`, `Channel`, `CoroutineScope` design, cancellation, and error handling.
   - `references/testing-and-tooling.md` — Kotest, MockK, the Gradle Kotlin DSL,
     `ktlint`, and the static-analysis stack.
3. Prefer the patterns in those files over inventing your own. When in doubt, copy
   the style of the surrounding code.

## The core rules (apply these every time)

**Use `val` by default; reach for `var` only when mutation is essential.**
Immutable bindings eliminate entire categories of bugs and make code trivially
thread-safe. The same applies to collections: prefer `List` / `Map` / `Set` (read-
only views) and only escalate to `MutableList` / etc. when you genuinely need
mutation at that call site.

**Model data with the right shape.**
Use `data class` for value objects and DTOs — you get `equals`, `hashCode`,
`toString`, and `copy` for free. Use `sealed class` / `sealed interface` + `when`
for closed type hierarchies so the compiler forces exhaustive handling when you add
a new case. Do NOT add an `else` branch to a `when` over a sealed type; it defeats
compile-time safety.

**Embrace null safety — never escape it with `!!`.**
If you feel the urge to write `!!`, stop: redesign the API so the value is never
null at that point, use `?.let { }`, `?: return`, or `requireNotNull`. The `!!`
operator is a runtime crash waiting to happen and almost always signals a design
problem. `Optional` from Java is never needed in Kotlin; use nullable types directly.

**Use extension functions to add behaviour without inheritance.**
Put utility methods on the type they operate on as extensions rather than in
`Utils` / `Helper` classes. Keep extensions in a file named after the type they
extend (`StringExtensions.kt`, etc.) so they are discoverable.

**Pick the right scope function.**
`apply` configures the receiver and returns it. `also` performs a side effect and
returns the receiver. `let` transforms the receiver to a new value. `run` runs a
block on the receiver and returns the block result. `with` is like `run` without an
extension. Using the wrong one misleads the reader — each communicates intent.

**Prefer coroutines over raw threads.**
All async/concurrent work should use `suspend` functions and coroutines. Never
create raw `Thread` objects or call `Thread.sleep`. Structure coroutines with
explicit `CoroutineScope`, and cancel scopes when the lifecycle ends.

**Inject dependencies through the constructor.**
No `companion object` singletons that hold mutable state. No `object` used as a
god service. Dependency injection through constructor parameters keeps code testable
and the graph explicit.

**Model domain concepts with value classes.**
A raw `String` for an email address or a raw `Long` for a user ID lets you swap
arguments by accident. Wrap them in `@JvmInline value class` to get zero-overhead
type safety.

**Write expressive, not clever, lambdas.**
Prefer named parameters over positional `it` chains. If a lambda is longer than two
lines, extract it to a named function. Avoid deeply nested `let`/`run` chains that
read like a puzzle.

## Quick anti-pattern checklist

Before finishing any Kotlin, confirm none of these are present:

- [ ] `!!` (non-null assertion) used anywhere other than test setup or framework interop
- [ ] `var` where `val` would work
- [ ] `MutableList` / `MutableMap` returned from a public API
- [ ] A data class with mutable fields (`var` properties)
- [ ] `else` on a `when` expression over a sealed type or enum
- [ ] Raw `Thread`, `Thread.sleep`, or `synchronized` in new code
- [ ] A coroutine launched without a named `CoroutineScope` (unstructured `GlobalScope`)
- [ ] An empty or swallowed `catch` block
- [ ] A `Utils` / `Helper` object full of static-style methods instead of extensions
- [ ] `companion object` holding mutable shared state
- [ ] Nested `let`/`run` chains deeper than two levels
- [ ] A Java-style POJO with manual getters/setters (use properties or data class)

If any box is checked, fix it before declaring the code done.
