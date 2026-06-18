# Kotlin Testing & Tooling

## Table of contents
- Kotest
- MockK
- Testing coroutines
- Gradle Kotlin DSL
- ktlint and detekt
- Build conventions

---

## Kotest

[Kotest](https://kotest.io) is the idiomatic Kotlin testing framework. It offers
several spec styles; prefer `FunSpec` for simple tests and `DescribeSpec` for
hierarchical behaviour specs.

```kotlin
class UserServiceTest : FunSpec({

    val repo = mockk<UserRepository>()
    val service = UserService(repo)

    test("returns user when found") {
        val expected = User(UserId(1L), "Alice")
        every { repo.findById(UserId(1L)) } returns expected

        service.getUser(UserId(1L)) shouldBe expected
    }

    test("throws NotFoundException when not found") {
        every { repo.findById(any()) } returns null

        shouldThrow<NotFoundException> { service.getUser(UserId(99L)) }
    }
})
```

**Kotest matchers are the preferred assertion library:**

```kotlin
result shouldBe expected
result shouldNotBe null
list   shouldHaveSize 3
string shouldContain "foo"
number shouldBeGreaterThan 0
```

Use `shouldThrow<ExceptionType>` instead of `assertThrows` for a Kotlin-idiomatic
style.

---

## MockK

[MockK](https://mockk.io) is the idiomatic Kotlin mocking library. It supports
Kotlin-specific features like coroutines, extension functions, and top-level functions.

```kotlin
// Creating mocks
val repo = mockk<UserRepository>()              // strict by default
val repo = mockk<UserRepository>(relaxed = true) // returns defaults for unstubbed calls

// Stubbing
every { repo.findById(UserId(1L)) }  returns User(...)
every { repo.findById(any()) }       throws NotFoundException()
every { repo.count() }               returnsMany listOf(0, 1, 2)

// Suspending functions
coEvery { repo.findAsync(any()) } returns User(...)

// Verification
verify { repo.findById(UserId(1L)) }
coVerify { repo.findAsync(UserId(1L)) }
verify(exactly = 2) { repo.findById(any()) }
verify(exactly = 0) { repo.delete(any()) }   // ensure delete was NOT called
```

**Spies** wrap real objects for partial mocking — use sparingly:

```kotlin
val realService = UserService(repo)
val spy = spyk(realService)
every { spy.validate(any()) } returns true
```

**Rules:**
- Prefer constructor injection over field injection so you can pass mocks directly.
- Do not mock data classes or value classes; just instantiate them with test values.
- Prefer `verify(exactly = 0)` over `verifyNever` for negation consistency.
- Annotate test classes with `@ExtendWith(MockKExtension::class)` when using
  annotations (`@MockK`, `@InjectMockKs`) in JUnit-style tests.

---

## Testing coroutines

Use `kotlinx-coroutines-test` for deterministic coroutine testing.

```kotlin
class TimerServiceTest : FunSpec({

    test("emits tick every second") = runTest {
        val service = TimerService()
        val results = mutableListOf<Long>()

        val job = launch { service.ticks().take(3).collect { results.add(it) } }
        advanceTimeBy(3_000)
        job.join()

        results shouldBe listOf(1L, 2L, 3L)
    }
})
```

**Key APIs:**
- `runTest { }` — sets up a `TestCoroutineScope` with virtual time.
- `advanceTimeBy(ms)` — advance virtual time, running any pending coroutines.
- `advanceUntilIdle()` — run all pending coroutines to completion.
- `runCurrent()` — run all coroutines scheduled for the current virtual time.

**Inject the dispatcher** so tests can replace it with `UnconfinedTestDispatcher`:

```kotlin
class DataLoader(
    private val dispatcher: CoroutineDispatcher = Dispatchers.IO
) {
    suspend fun load(): Data = withContext(dispatcher) { ... }
}

// In tests
val loader = DataLoader(UnconfinedTestDispatcher())
```

---

## Gradle Kotlin DSL

Use `.kts` files throughout the build for type safety and IDE completion.

**`build.gradle.kts` (minimal app module):**

```kotlin
plugins {
    kotlin("jvm") version "2.1.20"
    application
}

group   = "com.example"
version = "1.0.0"

kotlin {
    jvmToolchain(21)
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.1")
    testImplementation("io.kotest:kotest-runner-junit5:5.9.1")
    testImplementation("io.mockk:mockk:1.13.12")
}

tasks.test {
    useJUnitPlatform()
}
```

**Version catalogs (`gradle/libs.versions.toml`) — preferred for multi-module:**

```toml
[versions]
kotlin       = "2.1.20"
coroutines   = "1.10.1"
kotest       = "5.9.1"
mockk        = "1.13.12"

[libraries]
coroutines-core     = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core",     version.ref = "coroutines" }
kotest-runner       = { module = "io.kotest:kotest-runner-junit5",                    version.ref = "kotest" }
mockk               = { module = "io.mockk:mockk",                                   version.ref = "mockk" }

[plugins]
kotlin-jvm   = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
```

**Rules:**
- Use `kotlin { jvmToolchain(21) }` — do not set `sourceCompatibility` /
  `targetCompatibility` manually; the toolchain handles it.
- Prefer version catalogs over hardcoded version strings in `build.gradle.kts`.
- Use `implementation` / `testImplementation` consistently; do not use deprecated
  `compile` / `testCompile`.
- Use `tasks.withType<KotlinCompile>` to add compiler options globally.

---

## ktlint and detekt

**ktlint** — enforces Kotlin coding conventions (formatting). Zero configuration
needed for the standard rules.

```kotlin
// build.gradle.kts
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "12.1.2"
}
ktlint {
    version = "1.5.0"
    android = false
}
```

Run: `./gradlew ktlintCheck` / `./gradlew ktlintFormat`

**detekt** — static analysis for code smells, complexity, and style issues.

```kotlin
plugins {
    id("io.gitlab.arturbosch.detekt") version "1.23.7"
}
detekt {
    config.setFrom("detekt.yml")
    buildUponDefaultConfig = true
}
```

Minimal `detekt.yml` overrides to avoid false positives:

```yaml
complexity:
  LongMethod:
    threshold: 60
  TooManyFunctions:
    thresholdInFiles: 20
style:
  MagicNumber:
    active: true
    ignoreNumbers: ['-1', '0', '1', '2']
```

Run: `./gradlew detekt`

**Recommended CI pipeline:**

```
./gradlew ktlintCheck detekt test
```

All three gates should pass before merging. Configure them as required checks in
the branch protection rules.

---

## Build conventions

For multi-module builds, extract shared build logic into convention plugins in
`buildSrc/` or a dedicated `build-logic/` module rather than repeating
`build.gradle.kts` boilerplate.

```kotlin
// buildSrc/src/main/kotlin/kotlin-conventions.gradle.kts
plugins {
    kotlin("jvm")
    id("org.jlleitschuh.gradle.ktlint")
}

kotlin { jvmToolchain(21) }
ktlint { version = "1.5.0" }

dependencies {
    testImplementation("io.kotest:kotest-runner-junit5:5.9.1")
    testImplementation("io.mockk:mockk:1.13.12")
}

tasks.test { useJUnitPlatform() }
```

Every module then just applies the convention:

```kotlin
// module/build.gradle.kts
plugins { id("kotlin-conventions") }

dependencies {
    implementation(libs.coroutines.core)
}
```
