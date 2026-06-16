# Java Anti-Patterns: The "AI Slop" Catalogue

These are the smells that code generators (and rushed humans) produce most often.
Each entry shows the bad pattern and its fix. Studies of LLM-generated Java
consistently find "code smells" as the most frequent issue type — so treat this
list as the primary review checklist.

## Table of contents
- God class
- Anemic domain model
- Swallowing exceptions
- Returning null
- Static / singleton overuse
- Magic numbers and strings
- Stringly-typed code & primitive obsession
- Excessive getters/setters
- Incorrect equals/hashCode
- Resource leaks
- Stream misuse
- Unnecessary boxing
- Mutable shared state

## God class

One class doing everything. Split by responsibility (Extract Class). A class
should have one reason to change.

## Anemic domain model

A class that is "a bag of getters and setters" with all the logic living in a
separate service. It has the cost of a domain model with none of the benefit.
Put behaviour next to the data:

```java
// BAD
class Account { private long balance; /* getters/setters */ }
class AccountService { void withdraw(Account a, long amt) { a.setBalance(a.getBalance() - amt); } }

// GOOD
class Account {
    private long balance;
    void withdraw(long amount) {
        if (amount > balance) throw new InsufficientFundsException();
        balance -= amount;
    }
}
```

## Swallowing exceptions

```java
// BAD — hides the bug, impossible to debug
try { risky(); } catch (Exception e) {}

// GOOD — act, or wrap with cause preserved
try {
    risky();
} catch (IOException e) {
    throw new DataAccessException("failed to read config", e);
}
```

Never catch `Exception`/`Throwable` broadly unless you genuinely handle all of
them and re-log. Never leave the catch empty.

## Returning null

```java
// BAD
List<Order> findOrders(UUID id) { if (none) return null; ... }

// GOOD — empty collection for "no items"
List<Order> findOrders(UUID id) { if (none) return List.of(); ... }

// GOOD — Optional for "maybe one"
Optional<Customer> findCustomer(UUID id) { ... }
```

## Static / singleton overuse

Static mutable state and `getInstance()` singletons create hidden coupling and
make unit testing impossible. Inject dependencies through the constructor instead.

## Magic numbers and strings

```java
// BAD
if (status == 3) sendEmail();

// GOOD
enum Status { NEW, ACTIVE, CLOSED }
if (status == Status.CLOSED) sendEmail();
```

## Stringly-typed code & primitive obsession

Passing meaning around as raw `String`/`int`. Wrap it in a type:

```java
// BAD
void transfer(String from, String to, long cents) { ... }

// GOOD
record AccountId(UUID value) {}
record Money(long cents) {}
void transfer(AccountId from, AccountId to, Money amount) { ... }
```

## Excessive getters/setters

If a class is only getters/setters, it should probably be a `record`. Setters that
expose every field break encapsulation — prefer immutability.

## Incorrect equals/hashCode

Override both or neither, and keep them consistent. Records do this correctly for
free — another reason to prefer them for value types.

## Resource leaks

```java
// BAD
Connection c = ds.getConnection();
// ... exception here leaks the connection

// GOOD
try (Connection c = ds.getConnection();
     PreparedStatement ps = c.prepareStatement(SQL)) {
    ...
}
```

## Stream misuse

```java
// BAD — side effect inside the pipeline
names.stream().forEach(n -> results.add(transform(n)));

// GOOD — collect the result
var results = names.stream().map(this::transform).toList();
```

Avoid overly clever unreadable one-liners. If the pipeline fights you, a plain
`for` loop is clearer and that's fine.

## Unnecessary boxing

Prefer primitive streams (`IntStream`) and primitive types in hot paths; don't box
`int` to `Integer` in tight loops or large collections without reason.

## Mutable shared state

Sharing a non-thread-safe collection or mutable object across threads is a data
race. Prefer immutability; if you must share, use `java.util.concurrent`
collections or proper synchronization — and document the threading model.
