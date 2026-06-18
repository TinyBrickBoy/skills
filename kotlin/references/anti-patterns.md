# Kotlin Anti-Patterns: Java-isms and Kotlin-Specific Smells

These are the mistakes that appear most often in AI-generated Kotlin and in Java
code mechanically ported to `.kt`. Each entry shows the bad pattern and its fix.

## Table of contents
- Java-style POJO with manual getters/setters
- Misusing `!!` (non-null assertion)
- `var` where `val` would work
- Mutable data classes
- `else` on a sealed/enum `when`
- `Utils` / `Helper` object anti-pattern
- Mutable companion-object state
- `GlobalScope` and unstructured concurrency
- Exception swallowing
- Primitive obsession (missing value classes)
- Deeply nested scope functions
- Returning nullable collections
- `lateinit` misuse
- Overloaded constructors instead of default parameters
- Checked-exception wrapping boilerplate

---

## Java-style POJO with manual getters/setters

```kotlin
// BAD — Java habit
class User {
    private var _name: String = ""
    fun getName(): String = _name
    fun setName(v: String) { _name = v }
}

// GOOD — use a property (or data class for value types)
class User(var name: String)  // mutable property, if mutation is truly needed
data class UserDto(val name: String)  // immutable value object
```

Kotlin properties are already public with a generated getter by default. There is
no reason to write explicit `getX()` / `setX()` methods in Kotlin code.

---

## Misusing `!!` (non-null assertion)

```kotlin
// BAD — runtime crash if null
val length = input!!.length

// GOOD — safe call with default
val length = input?.length ?: 0

// GOOD — early return
fun process(input: String?) {
    val value = input ?: return
    // value is smart-cast to String here
}

// GOOD — fail fast with a meaningful message
val apiKey = requireNotNull(System.getenv("API_KEY")) { "API_KEY is required" }
```

`!!` is almost always a sign of a design problem. It can be justified for:
- A `lateinit var` that a framework guarantees is initialised before use.
- A tiny, isolated interop shim where a Java API returns null but the contract
  documents it never does, and you've verified it in context.

In production logic, it should never appear.

---

## `var` where `val` would work

```kotlin
// BAD
var result = ""
if (condition) result = "yes" else result = "no"

// GOOD
val result = if (condition) "yes" else "no"

// BAD
var items = mutableListOf<Item>()
items = items.filter { it.isActive }.toMutableList()

// GOOD
val items = rawItems.filter { it.isActive }
```

`var` signals mutation. If a reader sees `var`, they expect the value to change
multiple times. Reserve it for genuine mutable state.

---

## Mutable data classes

```kotlin
// BAD — var properties in a data class defeat its purpose
data class Config(var host: String, var port: Int)
config.port = 9090   // mutation everywhere, no single source of truth

// GOOD — val + copy()
data class Config(val host: String, val port: Int)
val updated = config.copy(port = 9090)
```

A `data class` with mutable properties loses referential transparency: two copies
of the same object can diverge after mutation, breaking `equals`/`hashCode`
assumptions.

---

## `else` on a sealed/enum `when`

```kotlin
sealed interface Status { data object Active : Status; data object Inactive : Status }

// BAD — else silences the compiler; adding a new subtype won't warn you
fun label(s: Status) = when (s) {
    is Status.Active -> "active"
    else -> "inactive"  // new subtypes silently fall here
}

// GOOD — exhaustive, no else
fun label(s: Status) = when (s) {
    is Status.Active   -> "active"
    is Status.Inactive -> "inactive"
}
```

Adding a new case to the sealed hierarchy instantly produces a compile error on
every `when` without `else`. Preserve that safety net.

---

## `Utils` / `Helper` object anti-pattern

```kotlin
// BAD — Java static-utility class imported wholesale into Kotlin
object StringUtils {
    fun capitalize(s: String): String = s.replaceFirstChar { it.uppercase() }
    fun isBlankOrNull(s: String?): Boolean = s.isNullOrBlank()
}
StringUtils.capitalize(name)

// GOOD — extension function on the type it operates on
fun String.capitalizeFirst(): String = replaceFirstChar { it.uppercase() }
fun String?.isBlankOrNull(): Boolean = isNullOrBlank()
name.capitalizeFirst()
```

Extensions are discoverable (IDE autocomplete on the type), testable without the
wrapper, and read as natural English at the call site.

---

## Mutable companion-object state

```kotlin
// BAD — hidden global mutable state, untestable
class UserRepository {
    companion object {
        private var cache: MutableMap<Long, User> = mutableMapOf()  // global state
        fun get(id: Long) = cache[id]
    }
}

// GOOD — cache is a dependency injected via constructor
class UserRepository(private val cache: UserCache) {
    fun get(id: Long) = cache[id]
}
```

State in `companion object` or top-level `object` behaves like `static` mutable
fields in Java: tests share the same state and interfere with each other.

---

## `GlobalScope` and unstructured concurrency

```kotlin
// BAD — coroutine is fire-and-forget, leaks on shutdown, no error propagation
GlobalScope.launch {
    processOrder(order)
}

// GOOD — coroutine is tied to the lifecycle that owns it
class OrderService(private val scope: CoroutineScope) {
    fun processAsync(order: Order) {
        scope.launch { processOrder(order) }
    }
}
```

`GlobalScope` outlives the component that launched the coroutine, ignores
structured cancellation, and swallows exceptions silently. Always tie a coroutine
to a `CoroutineScope` whose lifetime matches the component that needs the result.
See `references/coroutines.md` for the full rules.

---

## Exception swallowing

```kotlin
// BAD — hides the failure completely
try {
    riskyOperation()
} catch (e: Exception) { }

// BAD — logs but swallows, execution continues as if nothing happened
try {
    riskyOperation()
} catch (e: Exception) {
    logger.error("Error", e)
}

// GOOD — rethrow, wrap, or handle meaningfully
try {
    riskyOperation()
} catch (e: IOException) {
    throw ServiceException("Failed to process: ${e.message}", e)
}
```

Kotlin does not have checked exceptions, so every `catch` is opt-in. That makes it
even more important to catch only what you can handle and let the rest propagate.

---

## Primitive obsession (missing value classes)

```kotlin
// BAD — which Long is the user ID and which is the account ID?
fun transfer(userId: Long, accountId: Long, amount: Long) { ... }

// GOOD — type-safe, zero runtime overhead
@JvmInline value class UserId(val value: Long)
@JvmInline value class AccountId(val value: Long)
@JvmInline value class Cents(val value: Long)

fun transfer(user: UserId, account: AccountId, amount: Cents) { ... }
```

Value classes also enforce invariants:

```kotlin
@JvmInline value class Email(val value: String) {
    init { require(value.contains('@')) { "Invalid email" } }
}
```

---

## Deeply nested scope functions

```kotlin
// BAD — what does this do? Three seconds of parsing just to start reading
val result = data?.let { d ->
    d.user?.run {
        name?.let { n ->
            transform(n)
        }
    }
}

// GOOD — extract steps to named functions
val result = data?.user?.name?.let(::transform)
// or, if it's more complex, extract to a named private function
```

If two scope functions aren't enough, the logic belongs in a named function.
Lambda-heavy chains look clever but become a maintenance burden fast.

---

## Returning nullable collections

```kotlin
// BAD — forces every caller to null-check before iterating
fun findOrders(userId: UserId): List<Order>? { ... }

// GOOD — empty collection is the correct "nothing found" signal
fun findOrders(userId: UserId): List<Order> {
    return repository.query(userId) ?: emptyList()
}
```

Never return `null` from a function that returns a collection. Callers almost
always want to iterate, and an empty list is always the right empty state.

---

## `lateinit` misuse

```kotlin
// BAD — lateinit used to avoid thinking about initialisation
class Service {
    lateinit var repository: Repository  // what sets this? when? is it thread-safe?
    fun doWork() = repository.find(...)  // UninitializedPropertyAccessException lurks
}

// GOOD — constructor injection makes dependency explicit
class Service(private val repository: Repository) {
    fun doWork() = repository.find(...)
}

// Acceptable — framework-managed lifecycle (Spring @Autowired, Android, test setup)
@Autowired
private lateinit var repository: Repository
```

`lateinit` is appropriate for properties that a DI framework or test lifecycle
sets before use. For everything else, inject via the constructor.

---

## Overloaded constructors instead of default parameters

```kotlin
// BAD — Java habit
class Config {
    constructor(host: String) : this(host, 8080)
    constructor(host: String, port: Int) : this(host, port, false)
    constructor(host: String, port: Int, tls: Boolean) { ... }
}

// GOOD — default parameters + named arguments
class Config(
    val host: String,
    val port: Int = 8080,
    val tls: Boolean = false,
)

val cfg = Config(host = "api.example.com", tls = true)
```

Default parameters eliminate most constructor overloads. Named arguments make
call sites self-documenting.

---

## Checked-exception wrapping boilerplate

```kotlin
// BAD — wrapping every checked Java exception in a try/catch at every call site
fun readFile(path: String): String {
    return try {
        File(path).readText()
    } catch (e: IOException) {
        throw RuntimeException(e)  // loses context, adds noise
    }
}

// GOOD — let it propagate or wrap with a domain-meaningful exception
fun readFile(path: String): String =
    runCatching { File(path).readText() }
        .getOrElse { throw ConfigLoadException("Cannot read $path", it) }
```

`runCatching` + `getOrElse` / `getOrThrow` / `map` / `recover` is the idiomatic
functional error-handling chain in Kotlin. Use it when the error path is part of
normal flow; throw domain exceptions when the error is not recoverable at this
level.
