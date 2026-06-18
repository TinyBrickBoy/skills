# Kotlin Idioms: The Essential Patterns

This file covers the language features that most distinguish idiomatic Kotlin from
Java. Apply these every time you write or review Kotlin code.

## Table of contents
- Data classes
- Sealed types and exhaustive `when`
- Null safety
- Extension functions
- Scope functions
- Value classes
- Properties vs fields
- Destructuring
- Standard-library collections
- String templates and multi-line strings
- `object` declarations vs companion objects

---

## Data classes

Use `data class` for any type whose identity is its value — DTOs, event payloads,
config models, API responses.

```kotlin
// GOOD — canonical constructor, equals/hashCode/toString/copy for free
data class Customer(val name: String, val email: Email)

// Enforce invariants with init
data class Range(val low: Int, val high: Int) {
    init { require(low <= high) { "low > high: $low > $high" } }
}

// Use copy() for "update one field"
val updated = customer.copy(email = Email("new@example.com"))
```

**Rules:**
- All properties should be `val`. A `data class` with `var` properties is a
  mutable bag that loses most of the value of using `data class`.
- Do not extend data classes; use sealed hierarchies instead.
- Do not use `data class` for JPA/Hibernate entities (they need a no-arg
  constructor and mutable identity); use a plain `class` there.

---

## Sealed types and exhaustive `when`

`sealed class` / `sealed interface` restricts the subtype set to the same file,
enabling exhaustive `when` branches that the compiler verifies.

```kotlin
sealed interface PaymentResult
data class Success(val transactionId: String) : PaymentResult
data class Failure(val reason: String)        : PaymentResult
data object Pending                           : PaymentResult

fun handle(result: PaymentResult): String = when (result) {
    is Success -> "Paid: ${result.transactionId}"
    is Failure -> "Failed: ${result.reason}"
    Pending    -> "Awaiting confirmation"
    // no else needed — compiler verifies exhaustiveness
}
```

Adding a new subtype to the sealed hierarchy turns every non-exhaustive `when` into
a compile error. **Never add `else` on a `when` over a sealed type or enum** —
it defeats this safety net.

---

## Null safety

Kotlin's type system distinguishes `T` (never null) from `T?` (maybe null). Lean
on this instead of defensive null-checks everywhere.

```kotlin
// Safe call — returns null if customer is null, instead of NPE
val email: String? = customer?.email

// Elvis — provide a default or early return
val name = customer?.name ?: return

// let — run a block only when non-null
customer?.let { sendWelcomeEmail(it) }

// requireNotNull / checkNotNull — assert non-null with a meaningful message
val cfg = requireNotNull(System.getenv("API_KEY")) { "API_KEY env var missing" }
```

**The `!!` rule:** every `!!` is a deferred crash. Valid uses are extremely rare
(e.g., a lateinit property that a framework guarantees is set, or legacy Java
interop where you've already verified non-nullness nearby). In new code, redesign
the API to not need it.

**Contracts:** if a helper checks non-null and you want the smart-cast to flow
through, use `contract { returns() implies (param != null) }` — but do this only
in library code where it buys real ergonomics.

---

## Extension functions

Add behaviour to existing types without inheritance or utility classes.

```kotlin
// GOOD — reads as natural English
fun String.isValidEmail(): Boolean = matches(Regex("^[^@]+@[^@]+\\.[^@]+$"))
fun List<Int>.median(): Double { ... }

// BAD — Java-style utility class
object StringUtils {
    fun isValidEmail(s: String): Boolean { ... }
}
```

**Rules:**
- Group extensions in a file named after the type: `StringExtensions.kt`.
- Keep extension functions pure (no side effects on external state) where possible.
- Do not use extensions to work around proper design; they're not a substitute for
  real polymorphism.
- Extension functions on nullable receivers (`fun String?.orEmpty()`) are powerful
  for handling null transparently but use sparingly.

---

## Scope functions

Each communicates a different intent. Using the wrong one misleads the reader.

| Function | Receiver | Returns        | Typical use |
|----------|----------|----------------|-------------|
| `let`    | `it`     | lambda result  | transform a nullable value, or scope a temp variable |
| `run`    | `this`   | lambda result  | initialise a value with multiple lines |
| `with`   | `this`   | lambda result  | operate on a known non-null object, no extension syntax |
| `apply`  | `this`   | receiver       | configure/build the receiver, return it |
| `also`   | `it`     | receiver       | side effect (logging, debugging) without disrupting the chain |

```kotlin
// apply — builder pattern
val request = HttpRequest().apply {
    method = "POST"
    url = endpoint
    headers["Content-Type"] = "application/json"
}

// let — nullable transform
val length = input?.let { it.trim().length } ?: 0

// also — tap for side-effect
return result.also { logger.info("Processed: $it") }

// run — multi-step initialisation
val config = run {
    val raw = loadProperties()
    Config(host = raw["host"]!!, port = raw["port"]?.toInt() ?: 8080)
}
```

**Avoid nesting scope functions more than two levels deep.** Extract to named
functions instead; readability collapses fast.

---

## Value classes

Wrap primitives in zero-overhead named types to prevent argument-swap bugs and
express domain concepts.

```kotlin
@JvmInline value class UserId(val value: Long)
@JvmInline value class Email(val value: String) {
    init { require(value.contains('@')) { "Invalid email: $value" } }
}

fun findUser(id: UserId): User? { ... }
// findUser(Email("x@y.z")) — compile error, not a runtime surprise
```

Use value classes for IDs, monetary amounts, units (metres, seconds), and any
primitive that carries domain meaning.

---

## Properties vs fields

Kotlin properties are first-class. No explicit getters/setters for simple cases.

```kotlin
// GOOD — backing field is implicit
class Circle(val radius: Double) {
    val area: Double get() = Math.PI * radius * radius
}

// BAD — Java-style manual getters
class Circle {
    private var _radius: Double = 0.0
    fun getRadius(): Double = _radius
    fun setRadius(v: Double) { _radius = v }
}
```

Custom getters are fine. Custom setters are a smell — prefer immutability. If you
need `lateinit`, ensure it's initialised before first use (prefer `by lazy` for
thread-safe lazy init instead).

```kotlin
// by lazy — thread-safe, computed once
val heavyResource: Resource by lazy { loadResource() }
```

---

## Destructuring

Use component functions or `Pair`/`Triple` sparingly; data classes are clearer.

```kotlin
data class Point(val x: Int, val y: Int)
val (x, y) = point           // destructuring declaration

for ((key, value) in map) {  // destructuring in loops
    println("$key -> $value")
}

// Lambda destructuring
pairs.map { (first, second) -> first + second }
```

Avoid `Pair` and `Triple` in public APIs; return a named data class instead.

---

## Standard-library collections

Prefer the functional collection API over manual loops.

```kotlin
// Transforming
val names = users.map { it.name }
val active = users.filter { it.isActive }
val grouped = users.groupBy { it.department }
val byId = users.associateBy { it.id }

// Reducing
val total = orders.sumOf { it.amount }
val first = users.firstOrNull { it.isAdmin }
val all = users.all { it.isVerified }

// Chaining — readable pipeline
val topEmails = users
    .filter { it.isActive }
    .sortedByDescending { it.score }
    .take(10)
    .map { it.email }
```

**Rules:**
- Prefer `firstOrNull` / `lastOrNull` over `first` / `last` unless you are certain
  the collection is non-empty; `first()` throws on empty.
- Prefer `mapNotNull` over `map + filterNotNull`.
- Use `buildList { }` / `buildMap { }` instead of creating a mutable collection,
  adding to it, and then returning it.
- Sequences (`asSequence()`) for long pipelines over large collections to avoid
  creating intermediate lists; keep them lazy until a terminal operation.

---

## String templates and multi-line strings

```kotlin
val msg = "Hello, $name! You have ${messages.size} messages."

val json = """
    {
      "id": $id,
      "name": "$name"
    }
""".trimIndent()
```

Prefer string templates over string concatenation. Use `trimIndent()` or
`trimMargin()` on multi-line strings to strip indentation.

---

## `object` declarations vs companion objects

`object` creates a singleton — use it for stateless utilities, constants, and
anonymous interface implementations.

```kotlin
// GOOD — stateless singleton for constants/utilities
object Defaults {
    const val TIMEOUT_MS = 5_000L
    const val MAX_RETRIES = 3
}

// GOOD — anonymous implementation
val comparator = object : Comparator<User> {
    override fun compare(a: User, b: User) = a.name.compareTo(b.name)
}
// or just use a lambda: compareBy { it.name }
```

`companion object` is the Kotlin replacement for Java `static` members.

```kotlin
class User private constructor(val id: UserId, val name: String) {
    companion object {
        fun of(id: Long, name: String) = User(UserId(id), name)
    }
}
```

**Rules:**
- Never store mutable state in an `object` or `companion object`. It becomes
  global mutable state and makes testing impossible.
- Prefer `companion object` factory methods over constructors when you need named
  construction or validation.
