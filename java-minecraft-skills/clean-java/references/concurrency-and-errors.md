# Concurrency, Error Handling & Optional

## Concurrency & thread safety

Use `java.util.concurrent`: `ExecutorService`, `CompletableFuture`, concurrent
collections (`ConcurrentHashMap`, `CopyOnWriteArrayList`). Prefer immutability —
an immutable object is automatically thread-safe.

### Virtual threads (Java 21, final)

Lightweight JVM-managed threads, ideal for I/O-bound, thread-per-request work.
They are **not** a parallelism/CPU tool.

Rules:
- **Never pool virtual threads.** They are cheap — create one per task. To bound
  concurrency against a downstream service, use a `Semaphore`, not a thread pool.
- Use `Executors.newVirtualThreadPerTaskExecutor()`.
- Pinning inside `synchronized` was largely eliminated in JDK 24 (JEP 491);
  remaining pinning is mostly native/FFM calls. On older JDKs, prefer
  `ReentrantLock` over `synchronized` around blocking calls in virtual threads.

```java
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    for (var task : tasks) {
        executor.submit(() -> handle(task));   // one virtual thread per task
    }
}
```

### Structured concurrency (preview)

Treats a group of subtasks as one unit of work with a clear owner, so errors and
cancellation propagate correctly. Still a preview feature — APIs are changing, so
don't rely on it as stable yet. The principle: virtual threads remove the *cost*
of threads; structured concurrency removes the *risk*.

## Error handling

- **Checked vs unchecked:** checked exceptions for conditions a caller can
  reasonably recover from; unchecked (`RuntimeException`) for programming errors
  and precondition violations.
- **Never use exceptions for control flow.** They are for exceptional conditions.
- **Wrap to preserve abstraction**, always keeping the cause:
  `throw new ServiceException("...", e);`
- **Fail fast** — validate inputs at the boundary and throw early.
- Design a small, meaningful exception hierarchy rather than throwing raw
  `RuntimeException` everywhere.

## Optional — the rules

`Optional` exists for return types that need a clear "no result" signal. Misusing
it is itself a smell.

1. Never return `null` from an `Optional`-returning method — return
   `Optional.empty()`.
2. Never call `.get()` unless presence is already proven; prefer `map`,
   `orElse`, `orElseThrow`, `ifPresent`.
3. Prefer `map`/`filter`/`orElse` chains over `isPresent()` + `get()`.
4. Never return `Optional<Collection>` — return an empty collection instead.
5. Don't use `Optional` for fields or method parameters. It was designed for
   library method return types, not as a general "maybe" container.

```java
// GOOD
return repository.findById(id)            // Optional<Customer>
    .map(Customer::email)
    .orElseThrow(() -> new NotFoundException(id));
```
