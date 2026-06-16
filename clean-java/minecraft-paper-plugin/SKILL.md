---
name: minecraft-paper-plugin
description: Build high-quality Minecraft server plugins on the Paper API (the high-performance Spigot/Bukkit fork) without the threading bugs and dated patterns that low-quality "AI slop" plugins are full of. Use this skill whenever the user wants to create, edit, review, or debug a Bukkit/Spigot/Paper plugin — anything involving JavaPlugin, plugin.yml/paper-plugin.yml, listeners, commands, schedulers, events, or a Minecraft server plugin. Triggers: "Paper plugin", "Spigot plugin", "Bukkit plugin", "Minecraft plugin", PaperMC, JavaPlugin, onEnable, @EventHandler. Pair this with the clean-java skill for general Java quality. NOTE: this is for SERVER PLUGINS, not game mods — for Fabric/Forge/NeoForge mods use the minecraft-mod skill instead.
---

# Minecraft Paper Plugin Development

Paper plugins run server-side against a stable API. The single biggest quality
differentiator is **correct threading**: the Bukkit/Paper API is *not*
thread-safe and must only be touched from the main (region) thread, while all
blocking I/O (database, HTTP, file saves) must run *off* it. Getting this wrong is
the #1 cause of both server lag and data corruption in bad plugins.

This skill assumes the **clean-java** skill is also in effect — apply its rules
(records, immutability, constructor injection, no swallowed exceptions) here too.

## How to use this skill

Read the reference file matching the task:
- `references/threading.md` — schedulers, async I/O, the main-thread rule, Folia.
- `references/structure-and-build.md` — project layout, Gradle setup,
  paper-plugin.yml vs plugin.yml, dependency injection, lifecycle/cleanup.
- `references/commands-events-text.md` — Brigadier commands, the event system,
  Adventure/MiniMessage text, PersistentDataContainer storage.

Default target: **Paper API on Java 21**.

## The non-negotiable rules

**Never block the main thread.** No `Thread.sleep`, no synchronous database
queries, no HTTP calls, no large file reads on the main thread. Move blocking work
to an async task; then hop back to the main thread for any API call.

**Never touch the Bukkit/Paper API from an async thread.** Reading or mutating
worlds, blocks, entities, inventories, or firing events off-thread is unsafe and
can corrupt server state or deadlock. Async tasks do pure I/O/computation only.

```java
// GOOD: async I/O, then hop back to the player's thread for the API call
Bukkit.getAsyncScheduler().runNow(plugin, task -> {
    PlayerData data = database.load(uuid);            // safe: no Bukkit API here
    player.getScheduler().run(plugin, t ->
        player.sendMessage(mm.deserialize("<green>Balance: " + data.balance())), null);
});
```

**Clean up everything on disable.** Cancel scheduled tasks, unregister dynamically
registered listeners, close database pools and executors. Never leave work running
after `onDisable`.

**Key player data by `UUID`, never by storing `Player` objects.** Holding
`Player`/entity references in long-lived collections leaks memory. Map by `UUID`
and remove on quit.

**Use the modern stack, not legacy APIs:**
- Text: **Adventure `Component` / MiniMessage**, never `ChatColor` / `§` codes.
- Commands: the **Brigadier** command API (or a framework like Incendo Cloud),
  not raw string parsing scattered across an `onCommand`.
- Custom data: the **PersistentDataContainer**, not NMS/NBT reflection.
- Config: put all messages and tunable values in config (ideally MiniMessage
  strings); never hardcode user-facing text.

**Keep the main `JavaPlugin` class thin.** It wires services together in
`onEnable`/`onDisable`. Use constructor injection for listeners/services rather
than a static `getInstance()` singleton.

**Respect the event system.** Never modify an event at `MONITOR` priority
(observe only). Use `ignoreCancelled = true` instead of re-checking cancellation.
Assume another plugin may already have cancelled/modified the event.

## Quick checklist before shipping

- [ ] No blocking I/O on the main thread
- [ ] No Bukkit API calls from async tasks
- [ ] Tasks cancelled and listeners/pools closed in `onDisable`
- [ ] Player data keyed by `UUID`, removed on quit
- [ ] Adventure/MiniMessage for all text (no `ChatColor`)
- [ ] Commands via Brigadier (not duplicated in plugin.yml when using a framework)
- [ ] Messages/values in config, not hardcoded
- [ ] `api-version` set; main class thin; dependencies injected
- [ ] No swallowed exceptions (see clean-java)
