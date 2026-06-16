# Thread Safety, Migration & Cross-Compatibility

## Data sharing — the rule that catches everyone

Folia's only thread-safety guarantee is that a ticking region owns its
entity/chunk/POI data. **This says nothing about your plugin's data.** Because
regions tick in parallel, your event handlers, commands, and tasks now run on
different threads at the same time.

- **"Multithreading" does not mean thread-safe.** Most of the API is unchanged.
- **Static mutable state is dangerous.** A `static` map/list/field read or written
  from handlers that now fire on parallel region threads is a classic race.
- **A `ConcurrentHashMap` is necessary but not sufficient.** It makes single
  operations atomic; compound check-then-act (manual `containsKey` then `put`)
  still races. Used carelessly it only *hides* threading bugs, which then become
  near-impossible to debug.

Correct patterns:
- Keep per-region data inside the region; don't share it.
- To act on another region, schedule onto its scheduler — don't reach into its
  data.
- For genuinely global plugin state: confine all mutation to one scheduler context
  (e.g. always mutate from the global region scheduler so writes serialize), use
  atomics (`AtomicInteger`, `AtomicReference`), use immutable snapshots, or
  synchronize properly. Prefer atomic compound ops (`compute`, `merge`,
  `computeIfAbsent`).

```java
// BAD — shared state mutated from parallel region threads
public static final Map<UUID, Integer> KILLS = new HashMap<>();
@EventHandler public void onKill(EntityDeathEvent e) {
    KILLS.merge(killerId, 1, Integer::sum);            // racy across regions
}

// BETTER — confine all writes to one serialized context
private final Map<UUID, Integer> kills = new ConcurrentHashMap<>();
@EventHandler public void onKill(EntityDeathEvent e) {
    UUID id = killerId;
    Bukkit.getGlobalRegionScheduler().execute(plugin,
        () -> kills.merge(id, 1, Integer::sum));        // all writes on global region
}
```

## Migration anti-pattern table

| Anti-pattern | Why it breaks | Fix |
|---|---|---|
| `new BukkitRunnable().runTaskTimer(...)` / `Bukkit.getScheduler().runTask(...)` | Assumes single main thread; deprecated/throws on Folia | Use the Folia scheduler that fits |
| Touching an entity from a `RegionScheduler` task | Entity may move regions → off-owning-thread access | `entity.getScheduler()` (follows the entity) |
| Iterating `world.getLivingEntities()` / editing blocks from a global or async task | Those threads own no chunks/entities | Hop to the owning region/entity scheduler |
| `entity.teleport(loc)` | Removed on Folia | `entity.teleportAsync(loc).thenAccept(...)` |
| `.join()`/`.get()` on a teleport future on a tick thread | Deadlock if target chunk not loaded | Chain `thenAccept`/`thenRun` |
| `static`/shared mutable collections written from handlers | Handlers fire on parallel region threads | Confine to one scheduler / synchronize / atomics |
| `ConcurrentHashMap` for check-then-act | Only single ops atomic | `compute`/`merge`/locks/single-thread confinement |
| Blocking I/O (DB/HTTP) in a region/global task | Blocks that region's tick loop | `AsyncScheduler`, then hop back |

### What is safe where
- Sending packets/messages to players: any thread.
- Reading/writing a block or chunk: only the region owning that location.
- Modifying an entity: only the region owning that entity.
- Global state (time/weather/console): `GlobalRegionScheduler`.
- I/O and CPU-heavy work: `AsyncScheduler`, then hop back.

## Declaring support & build setup

Add to `plugin.yml` / `paper-plugin.yml`:

```yaml
folia-supported: true
```

Without it, Folia will not load the plugin. The flag alone is not enough — the
code must actually follow the rules above.

With the `net.minecrell.plugin-yml` Gradle plugin:

```kotlin
bukkit {
    main = "com.example.MyPlugin"
    foliaSupported = true
}
```

Build: because the Folia scheduler API is backported into mainline Paper, most
plugins just compile against `paper-api` and use the Folia schedulers directly.
Only depend on the `dev.folia:folia-api` artifact if you specifically need
Folia-only API. (Pin the exact version and JDK to your target build — Folia/Paper
adopted Mojang's calendar versioning, e.g. the 26.x line, with a higher JDK
baseline than the older 1.21.x/Java 21 line.)

## Cross-compatibility: one plugin for Paper + Folia

Detect Folia at runtime:

```java
private static boolean isFolia() {
    try {
        Class.forName("io.papermc.paper.threadedregions.RegionizedServer");
        return true;
    } catch (ClassNotFoundException e) {
        return false;
    }
}
```

Simplest approach for modern Paper + Folia: **always use the Folia schedulers** —
on Paper they are internally handled to behave the same. You only need more than
this if you must also support Spigot/legacy Paper, in which case:

- Abstract the scheduler behind your own interface (`runAtEntity`,
  `runAtLocation`, `runGlobal`, `runAsync`) with a Folia impl and a Bukkit
  fallback impl, chosen at startup; or
- Use a maintained wrapper library:
  - **CJCrafter's FoliaScheduler** (`com.cjcrafter:foliascheduler`) — Spigot/Paper/
    Folia, falls back to `BukkitRunnable`; clean `scheduler.entity(e).run(...)` /
    `scheduler.async().runDelayed(...)` / `scheduler.global().run(...)` syntax.
  - **TechnicallyCoded's FoliaLib** (`com.tcoded:FoliaLib`) — broad version range;
    `runNextTick`/`runAsync`/`runTimer`/`teleportAsync` plus `isFolia()`.
    **Must be relocated/shaded** to avoid conflicts.

## Testing & profiling

- Test on a real Folia build with players spread far apart so multiple region
  threads tick at once. Watch the console for "failed main thread check" /
  "Accessing entity state off owning region's thread" — each is a real bug.
- Profile with **spark** (region-aware `/tps` and profiler), not legacy Timings
  (force-disabled on Folia).

## Reference implementations to study

LuckPerms (minimal changes, uses `AsyncScheduler` for data work), spark
(region-aware profiler), EssentialsX (Folia fork), Chunky (pre-generation), and
WeaponMechanics/MechanicsCore (FoliaScheduler adopters). PaperMC's Hangar lists
100+ Folia-supporting plugins.
