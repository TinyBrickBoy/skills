# Threading, Schedulers & Folia

The Bukkit/Paper API is single-threaded. Almost the entire API must be called from
the main thread. Paper's own scheduler docs warn: *asynchronous tasks should never
access any API in Bukkit*. Conversely, blocking the main thread destroys TPS.

## The split-work pattern

Heavy or blocking work goes async; API mutations come back to the main thread.

```java
@EventHandler
public void onJoin(PlayerJoinEvent event) {
    Player player = event.getPlayer();
    UUID uuid = player.getUniqueId();

    Bukkit.getAsyncScheduler().runNow(plugin, task -> {
        PlayerData data = database.load(uuid);   // I/O only — NO Bukkit API
        // hop back to a thread allowed to touch the player:
        player.getScheduler().run(plugin, t ->
            player.sendMessage(mm.deserialize("<green>Loaded " + data.balance())),
            null);
    });
}
```

## Bad pattern — blocking the main thread

```java
// BAD: synchronous DB load inside an event handler freezes the whole server
@EventHandler
public void onJoin(PlayerJoinEvent event) {
    PlayerData data = database.loadSync(event.getPlayer().getUniqueId()); // blocks!
    event.getPlayer().sendMessage("Balance: " + data.getBalance());
}
```

## Scheduler guidance

On regular Paper, `BukkitScheduler` and `BukkitRunnable` are valid:

```java
new BukkitRunnable() {
    @Override public void run() { /* main-thread work */ }
}.runTaskLater(plugin, 100L);   // 100 ticks ≈ 5s at 20 TPS (longer if lagging)
```

- Tick-based delays scale with TPS — for wall-clock timing use an async task or a
  `ScheduledExecutorService`.
- A `BukkitRunnable` can cancel itself with `cancel()`.
- Cancel all of a plugin's tasks on disable: `Bukkit.getScheduler().cancelTasks(plugin)`.

## Async events

Some events (`AsyncChatEvent`, `AsyncPlayerPreLoginEvent`) fire off the main
thread. Do **not** call the synchronous Bukkit API from inside them.

## Database access (async-safe)

- Use **HikariCP** connection pooling. Opening a raw connection is expensive (TCP
  handshake, auth, session init — tens to hundreds of ms, and several MB of
  memory each), so never open per query.
- Size the pool roughly `((coreCount * 2) + effectiveSpindleCount)`. Smaller pools
  are often dramatically faster — don't set 100 connections "to be safe".
- Always run queries off the main thread, use try-with-resources for
  `Connection`/`PreparedStatement`/`ResultSet`, and use prepared statements.
- Set `maxLifetime` a few seconds shorter than any DB/infra connection timeout.
- Close the `HikariDataSource` in `onDisable`.

## Folia (region-based multithreading)

Folia groups nearby chunks into independent regions, each ticking in parallel —
**there is no single main thread**. Nearly every plugin needs changes to run on
Folia.

- The whole `BukkitScheduler` is deprecated on Folia. Use `RegionScheduler`,
  `EntityScheduler`, `AsyncScheduler`, or `GlobalRegionScheduler`.
- Declare `folia-supported: true`.
- Use `teleportAsync(...)` instead of `teleport(...)`.
- Guard thread ownership with `Bukkit.isOwnedByCurrentRegion(...)`.
- Regions tick in parallel and do **not** share data — sharing data across regions
  causes corruption. A concurrent collection used carelessly only hides the bug.
- Cross-platform scheduler wrapper libraries exist that fall back to the Bukkit
  scheduler when Folia is absent.
