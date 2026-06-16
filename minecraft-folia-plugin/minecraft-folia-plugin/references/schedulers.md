# The Folia Schedulers

Folia replaces the single `BukkitScheduler` with four schedulers, each tied to a
thread context. All live in `io.papermc.paper.threadedregions.scheduler`. The same
API is backported into mainline Paper, so this code runs on both.

Retrieval:

```java
RegionScheduler region   = Bukkit.getRegionScheduler();
AsyncScheduler  async    = Bukkit.getAsyncScheduler();
GlobalRegionScheduler global = Bukkit.getGlobalRegionScheduler();
EntityScheduler entityScheduler = entity.getScheduler();   // per-entity
```

## RegionScheduler — work at a location/region

Use for modifying a block or chunk at a known position. Delays are in **ticks**.
Methods: `execute(plugin, location, Runnable)`, `run(plugin, location, task)`
(next tick), `runDelayed(...)`, `runAtFixedRate(...)`. Overloads take a `Location`
or `(World, chunkX, chunkZ)`.

```java
// GOOD — set a block on the region that owns the location
Bukkit.getRegionScheduler().execute(plugin, loc, () -> loc.getBlock().setType(Material.BEEHIVE));
```

Do **not** use the region scheduler for entity tasks — if the entity moves to
another region before the task runs, you touch it from the wrong thread.

## EntityScheduler — work on a specific entity

An entity may move between regions, so its scheduler "follows" it. Every method
takes an extra **`retired`** `Runnable`, invoked if the entity is removed before
the task runs. Exactly one of `run` or `retired` fires (never both); if the entity
is already gone, scheduling returns false/null and neither fires.

```java
// GOOD — modify an entity safely on its owning region
entity.getScheduler().run(plugin, task -> entity.setVelocity(new Vector(0, 1, 0)), null);
```

```java
// BAD — entity work on the region scheduler: wrong thread if it moved
Bukkit.getRegionScheduler().run(plugin, entity.getLocation(),
    task -> entity.setVelocity(new Vector(0, 1, 0)));   // thread-check crash
```

Warning: the `retired` callback runs in critical code — do not remove entities,
load chunks/worlds, or modify ticket levels from inside it.

## AsyncScheduler — I/O and computation, no world access

Runs on a dedicated async thread pool, independent of the tick loop. **Time-based**
(`TimeUnit`, not ticks): `runNow(plugin, task)`,
`runDelayed(plugin, task, delay, unit)`,
`runAtFixedRate(plugin, task, initialDelay, period, unit)`, `cancelTasks(plugin)`.
Never touch world/entity/block state here.

```java
Bukkit.getAsyncScheduler().runDelayed(plugin, task -> {
    String data = readFromDatabase();   // safe: no world access
}, 5, TimeUnit.SECONDS);
```

## GlobalRegionScheduler — world-independent global state

For state owned by the global region: day time, weather, world border, console
commands, and misc tasks belonging to no region. Tick-based. Methods:
`execute`, `run`, `runDelayed`, `runAtFixedRate`, `cancelTasks`.

```java
Bukkit.getGlobalRegionScheduler().runAtFixedRate(plugin, task -> {
    // broadcast, change weather, run a console command
}, 20L, 20L * 60);   // after 1s, every 60s
```

Caveat: the global region owns no chunks/entities. Do NOT iterate
`world.getLivingEntities()` or edit blocks from a global task — hop to the owning
region/entity scheduler first.

## The canonical pattern: async, then hop back

Blocking work goes async; applying results goes back to the owning region/entity
thread.

```java
Bukkit.getAsyncScheduler().runNow(plugin, task -> {
    PlayerData data = database.load(playerId);          // blocking I/O off-tick
    player.getScheduler().run(plugin, t ->
        applyData(player, data), null);                 // back on player's region
});
```

## Ownership checks

Before touching world state from an ambiguous context, verify the current thread
owns it. `Bukkit.isOwnedByCurrentRegion(...)` accepts a `Location`, an `Entity`,
or `(World, chunkX, chunkZ)`.

```java
if (Bukkit.isOwnedByCurrentRegion(entity)) {
    entity.remove();                                    // safe right now
} else {
    entity.getScheduler().execute(plugin, entity::remove, null, 1L);
}
```

## Teleportation

Synchronous `teleport()` is removed on Folia and never returning — cross-region
teleport requires async chunk loading.

```java
// GOOD
player.teleportAsync(destination).thenAccept(success -> {
    if (success) { /* runs on the region that now owns the player */ }
});

// BAD — does not work on Folia
player.teleport(destination);
```

Never call `.get()`/`.join()` on the teleport future from a tick thread — it
deadlocks if the destination chunk isn't loaded. Always chain with
`thenAccept`/`thenRun`.

## Other broken/changed API on Folia

All scoreboard API, parts of portal/respawn/player-login, and world load/unload are
currently broken or global-state-limited. The `async` event modifier is
deprecated — all region/global events are treated as synchronous. Feature-gate
these when running on Folia.
