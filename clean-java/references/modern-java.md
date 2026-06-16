# Modern Java (17 → 21+) Features

Target Java 21 LTS. These features replace dated Java-8-style boilerplate and are
the clearest signal of professional modern code.

## Table of contents
- Records
- Sealed types
- Pattern matching (instanceof, switch, record patterns)
- Switch expressions
- Text blocks
- `var`
- Sequenced collections
- Common misuse

## Records

Transparent, shallowly-immutable data carriers. Auto-generate the canonical
constructor, accessors, `equals`/`hashCode`/`toString`.

```java
// GOOD — intent-revealing, immutable, zero boilerplate
public record Customer(String name, String email) {}

// Enforce invariants with a compact constructor
public record Range(int low, int high) {
    public Range {
        if (low > high) throw new IllegalArgumentException("low > high");
    }
}
```

Use for: DTOs, value objects, event payloads, coordinates, config models.
Don't use for: things needing mutability or JPA-entity identity.

## Sealed types

Restrict who can implement/extend, enabling exhaustive `switch` with no `default`.

```java
sealed interface Shape permits Circle, Rectangle {}
record Circle(double radius) implements Shape {}
record Rectangle(double w, double h) implements Shape {}

double area(Shape s) {
    return switch (s) {                          // exhaustive — compiler-checked
        case Circle(double r) -> Math.PI * r * r;       // record pattern
        case Rectangle(double w, double h) -> w * h;
    };
}
```

Adding a new permitted subtype turns every non-exhaustive switch into a compile
error — exactly what you want. Do **not** add a `default` branch over a sealed
type; it defeats this checking.

## Pattern matching

```java
// instanceof — no cast boilerplate
if (obj instanceof String s && !s.isBlank()) {
    System.out.println(s.length());
}

// switch with patterns + guards
String describe(Object o) {
    return switch (o) {
        case Integer i when i < 0 -> "negative int";
        case Integer i           -> "int " + i;
        case String s            -> "string of length " + s.length();
        case null                -> "null";
        default                  -> "other";
    };
}
```

## Switch expressions

Arrow form, no fall-through, returns a value (`yield` inside a block).

```java
int days = switch (month) {
    case FEB -> 28;
    case APR, JUN, SEP, NOV -> 30;
    default -> 31;
};
```

## Text blocks

```java
String json = """
    {
      "name": "%s",
      "active": true
    }""".formatted(name);
```

## `var`

Use only where the right-hand side makes the type obvious.

```java
var customers = new ArrayList<Customer>();   // GOOD — type is clear
var result = service.process();              // BAD — what type is this?
```

## Sequenced collections (Java 21)

`SequencedCollection` / `SequencedMap` give a uniform `getFirst()`, `getLast()`,
`addFirst()`, `addLast()`, `reversed()` API across `List`, `Deque`,
`LinkedHashMap`, etc.

## Common misuse to avoid

- `var` everywhere, including on opaque method returns.
- Records used as mutable holders, or with leaked mutable components (defensively
  copy mutable inputs in a compact constructor if needed).
- `default` on a sealed/enum switch (kills exhaustiveness checking).
- Relying on preview features as if stable. String templates were a preview
  feature and were **withdrawn** — do not use them. Structured concurrency and
  scoped values are still preview; treat their APIs as subject to change.
