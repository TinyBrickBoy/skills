# Kotlin Coroutines, Structured Concurrency & Flow

Coroutines are the idiomatic Kotlin answer to async/concurrent work. They replace
callbacks, `CompletableFuture`, and raw threads with code that reads top-to-bottom
while remaining non-blocking.

## Table of contents
- Core model: suspend functions
- Structured concurrency and CoroutineScope
- Launching coroutines: `launch` vs `async`
- Dispatchers
- Cancellation
- Error handling
- Flow
- Channels
- Interop with blocking/Java code

---

## Core model: suspend functions

A `suspend` function can be paused and resumed without blocking a thread. It can
only be called from another `suspend` function or from within a coroutine builder.

```kotlin
suspend fun fetchUser(id: UserId): User {
    return httpClient.get("/users/${id.value}")  // suspends while waiting for I/O
}
```

**Rules:**
- Mark any function that does I/O, delays, or calls other suspend functions as
  `suspend`. This propagates the async boundary explicitly through the call graph.
- Do not mark CPU-only pure functions as `suspend`; it adds noise without benefit.
- A `suspend` function is not inherently concurrent — it just allows pausing. Use
  `async`/`launch` inside a scope to achieve actual concurrency.

---

## Structured concurrency and CoroutineScope

Every coroutine belongs to a `CoroutineScope`. The scope:
- Propagates cancellation downward (parent cancelled → all children cancelled).
- Waits for all children to complete before it completes.
- Propagates exceptions upward.

```kotlin
class OrderService(
    private val scope: CoroutineScope,  // inject the scope — never create GlobalScope
    private val repo: OrderRepository,
) {
    fun processAsync(order: Order): Job =
        scope.launch { repo.save(order) }
}
```

**Creating scopes for lifecycle-bound components:**

```kotlin
// Custom lifecycle — cancel when done
class WorkerNode {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    fun start() { scope.launch { runLoop() } }
    fun stop()  { scope.cancel() }
}
```

**`coroutineScope { }` — create a child scope inline:**

```kotlin
suspend fun loadDashboard(): Dashboard = coroutineScope {
    val users  = async { fetchUsers() }
    val orders = async { fetchOrders() }
    Dashboard(users.await(), orders.await())
    // scope completes only after both async blocks finish; cancels both on failure
}
```

**Never use `GlobalScope`.**  It lives for the entire process lifetime, is not
bound to any component, ignores cancellation, and swallows exceptions. Any
coroutine in `GlobalScope` is a resource leak by design.

---

## Launching coroutines: `launch` vs `async`

| Builder | Returns | Use when |
|---------|---------|----------|
| `launch` | `Job` | Fire-and-forget; you don't need a result |
| `async`  | `Deferred<T>` | You need the result; `await()` retrieves it |

```kotlin
// launch — side-effecting work
scope.launch {
    sendNotification(userId)
}

// async — parallel work with results
val result: Dashboard = coroutineScope {
    val a = async { serviceA.fetch() }
    val b = async { serviceB.fetch() }
    combine(a.await(), b.await())
}
```

**Do not call `async` and ignore the `Deferred`.** That is `launch` with extra
syntax and it swallows errors. Call `await()` or use `launch` explicitly.

---

## Dispatchers

| Dispatcher | Use for |
|------------|---------|
| `Dispatchers.Default` | CPU-bound work (parsing, sorting, computation) |
| `Dispatchers.IO`      | Blocking I/O (file, JDBC, legacy blocking APIs) |
| `Dispatchers.Main`    | UI updates (Android, JavaFX) |
| `Dispatchers.Unconfined` | Rarely — only in tests or simple scripts |

```kotlin
// Blocking JDBC call must run on IO dispatcher
suspend fun findById(id: Long): User = withContext(Dispatchers.IO) {
    database.query("SELECT * FROM users WHERE id = ?", id)
}
```

**Rules:**
- Inject the dispatcher instead of hardcoding it — this makes code testable with
  `TestCoroutineDispatcher` / `UnconfinedTestDispatcher`.
- Never call blocking code on `Default` — it starves the shared thread pool.
- Use `withContext(Dispatchers.IO)` as a narrow wrapper around the blocking call,
  not across an entire function.

---

## Cancellation

Cancellation is cooperative. A suspended coroutine is cancelled at the next
suspension point. CPU-bound code that never suspends must check cancellation
manually.

```kotlin
// Suspension points check cancellation automatically
suspend fun downloadAll(urls: List<String>) {
    for (url in urls) {
        ensureActive()          // explicit check in a tight loop
        download(url)           // suspends — checks cancellation here
    }
}
```

**Rules:**
- Never catch `CancellationException` and swallow it. Rethrow it or let it
  propagate; catching it breaks structured cancellation.
- Use `withTimeout(ms)` or `withTimeoutOrNull(ms)` to bound a suspend call.
- Clean up resources in `try/finally` — the `finally` block runs even on
  cancellation (but avoid calling new suspend functions in `finally`; use
  `NonCancellable` if you must).

```kotlin
// Cleanup on cancellation
try {
    while (isActive) { processNext() }
} finally {
    withContext(NonCancellable) { releaseResources() }
}
```

---

## Error handling

```kotlin
// launch — exceptions propagate to the scope's exception handler
scope.launch {
    try {
        riskyWork()
    } catch (e: NetworkException) {
        logger.error("Network failure", e)
        // handle or rethrow — don't swallow
    }
}

// async — exceptions are deferred until await()
val deferred = scope.async { riskyWork() }
try {
    deferred.await()
} catch (e: NetworkException) { ... }
```

**`SupervisorJob` — isolate child failures:**

```kotlin
// With SupervisorJob, one child failing doesn't cancel the others
val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
scope.launch { task1() }   // if this fails, task2 still runs
scope.launch { task2() }
```

**`CoroutineExceptionHandler` — last resort for unhandled exceptions:**

```kotlin
val handler = CoroutineExceptionHandler { _, e ->
    logger.error("Unhandled coroutine exception", e)
}
val scope = CoroutineScope(SupervisorJob() + handler)
```

Use `CoroutineExceptionHandler` as a safety net for logging, not as a catch-all
for recoverable errors. Recoverable errors belong in `try/catch` inside the
coroutine.

---

## Flow

`Flow<T>` is a cold, lazy stream of values — the coroutines equivalent of Rx
`Observable` or Java `Stream`, but integrated with structured concurrency.

```kotlin
// Producing a flow
fun liveOrders(userId: UserId): Flow<Order> = flow {
    while (true) {
        emit(repo.getLatestOrder(userId))
        delay(5_000)
    }
}

// Consuming
liveOrders(userId)
    .filter { it.isPending }
    .map    { it.toSummary() }
    .collect { summary -> display(summary) }
```

**StateFlow / SharedFlow — hot flows for state:**

```kotlin
// StateFlow — always holds the latest value, replays to new collectors
private val _state = MutableStateFlow(UiState.Loading)
val state: StateFlow<UiState> = _state.asStateFlow()

// Emit from anywhere in the scope
_state.value = UiState.Ready(data)
```

**Rules:**
- Use `Flow` for streams of values over time; `suspend fun` for single values.
- Always collect in a scope — `collect` is a terminal operator that suspends.
  Do not call `collect` inside `launch` and ignore the returned `Job`; the flow
  will be cancelled when the outer scope cancels.
- Prefer `flowOn(Dispatchers.IO)` to move upstream work off the main thread, rather
  than wrapping the entire `collect` in `withContext`.
- Use `stateIn(scope, SharingStarted.WhileSubscribed(), initialValue)` to turn a
  cold flow into a `StateFlow` efficiently.
- Never use `GlobalScope` to collect a flow.

---

## Channels

`Channel` is a hot, buffered pipe between coroutines — the coroutines equivalent of
a `BlockingQueue`. Use sparingly; most producer-consumer problems are better solved
with `Flow`.

```kotlin
val channel = Channel<Event>(capacity = 64)

// Producer
scope.launch {
    events.forEach { channel.send(it) }
    channel.close()
}

// Consumer
scope.launch {
    for (event in channel) {
        handle(event)
    }
}
```

Prefer `channelFlow` or `produce` builders over raw `Channel` for simpler
lifecycle management.

---

## Interop with blocking/Java code

```kotlin
// Calling a blocking API from a coroutine — use Dispatchers.IO
suspend fun readConfig(path: String): Config = withContext(Dispatchers.IO) {
    Files.readString(Path.of(path)).let { Json.decodeFromString(it) }
}

// Bridging a callback-based API to a suspend function
suspend fun awaitCallback(): Result = suspendCancellableCoroutine { cont ->
    legacyApi.fetchAsync(
        onSuccess = { cont.resume(it) },
        onError   = { cont.resumeWithException(it) },
    )
    cont.invokeOnCancellation { legacyApi.cancel() }
}

// Calling suspend code from Java / blocking context (e.g., tests, main)
runBlocking { myService.doWork() }
// runBlocking blocks the calling thread — never use inside a coroutine
```
