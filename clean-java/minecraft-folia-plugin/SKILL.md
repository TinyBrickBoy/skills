---
name: minecraft-folia-plugin
description: Build Minecraft plugins that run correctly on Folia, PaperMC's region-based multithreaded server fork, without the threading crashes and data corruption that naive ports suffer. Use this skill whenever the user wants to create, edit, review, debug, or migrate a plugin for Folia, or make a Paper plugin Folia-compatible — anything involving regionised multithreading, RegionScheduler/EntityScheduler/AsyncScheduler/GlobalRegionScheduler, teleportAsync, folia-supported, isOwnedByCurrentRegion, or "there is no main thread". Triggers: "Folia plugin", "Folia support", "make my plugin Folia-compatible", region threading, FoliaLib, FoliaScheduler. Pair with the minecraft-paper-plugin skill (Folia is a Paper fork) and the clean-java skill for general Java quality.
---

# Minecraft Folia Plugin Development

Folia is PaperMC's region-based multithreaded fork of Paper. It splits each world
into independent **regions** of nearby chunks, and each region ticks in parallel on
a thread pool. **There is no main thread anymore** — each region effectively has
its own. This is why almost every existing plugin needs changes: the old
`BukkitScheduler`/`BukkitRunnable` model assumes one main thread, and touching an
entity, block, or world from the wrong thread now fails hard with a thread check.

This skill assumes the **minecraft-paper-plugin** and **clean-java** skills are
also in effect — Folia is still Paper, so all their rules apply, plus the ones
here.

## How to use this skill

Read the reference file matching the task:
- `references/schedulers.md` — the four Folia schedulers, when to use each, the
  "async then hop back" pattern, ownership checks, teleportAsync.
- `references/thread-safety-and-migration.md` — the data-sharing rules, the
  migration anti-pattern table, `folia-supported` / build setup, and
  cross-compatibility (one plugin for Paper + Folia, wrapper libraries).

Default target: the current Folia line built on **Paper API**. The Folia scheduler
API is backported into mainline Paper, so the same scheduler code runs on both.

## The mental model

- A **region** owns a set of nearby chunks and everything in them. Only the thread
  currently ticking that region may touch its entities, blocks, and chunk data.
- The **global region** owns world-independent state: day time, weather, the world
  border, and console command execution. It owns no chunks or entities.
- **Async threads** run work tied to no region (I/O, computation).
- Regions tick **in parallel, not concurrently** — they do not share data, and
  *sharing data will cause corruption*. "Multithreading" in the name does **not**
  make the API thread-safe.

## The non-negotiable rules

**Never use `BukkitScheduler` or `BukkitRunnable`.** They assume a single main
thread and are deprecated/unsupported on Folia. Use the right Folia scheduler:
- `RegionScheduler` — work at a **location** (set a block, affect a chunk).
- `EntityScheduler` (`entity.getScheduler()`) — work on a **specific entity**; it
  follows the entity if it changes region. Always use this for entity tasks, never
  the region scheduler.
- `AsyncScheduler` (`Bukkit.getAsyncScheduler()`) — I/O and heavy computation, no
  world access.
- `GlobalRegionScheduler` — world-independent global state.

**Never call synchronous `teleport()`.** It is permanently removed on Folia. Use
`teleportAsync(loc).thenAccept(...)`. Never call `.get()`/`.join()` on the future
from a tick thread — it deadlocks if the target chunk isn't loaded.

**Never touch world/entity/block state from the wrong thread.** Do blocking I/O on
the `AsyncScheduler`, then hop back to the owning region/entity scheduler to apply
results. When a context is ambiguous, guard with
`Bukkit.isOwnedByCurrentRegion(...)` before touching state.

**Never share mutable plugin state across regions carelessly.** Event handlers now
fire on parallel region threads. A `static HashMap` written from handlers is a
race; even a `ConcurrentHashMap` only makes single operations atomic (compound
check-then-act still races). Confine mutation to one scheduler context, use atomics
or immutable snapshots, or properly synchronize.

**Declare support explicitly.** Add `folia-supported: true` to plugin.yml /
paper-plugin.yml. Without it, Folia refuses to load the plugin. The flag alone is
not enough — the code must actually follow these rules.

## When Folia is (and isn't) worth supporting

Folia is still **experimental** and helps only servers that spread players across
the world (SkyBlock, SMP) on many-core hardware (16+ cores recommended). For
lobbies/minigames where everyone is clustered in one region, it gives little or no
benefit — that one region is effectively single-threaded. Recommend it
accordingly; don't tell users it's a drop-in Paper replacement.

## Quick checklist before shipping

- [ ] `folia-supported: true` declared
- [ ] No `BukkitScheduler` / `BukkitRunnable` anywhere
- [ ] Entity tasks use `entity.getScheduler()`, not the region scheduler
- [ ] Location/block tasks use `RegionScheduler`
- [ ] Global state (time/weather/console) uses `GlobalRegionScheduler`
- [ ] I/O on `AsyncScheduler`, then hop back to apply results
- [ ] `teleportAsync(...).thenAccept(...)`; no `.get()`/`.join()` on a tick thread
- [ ] Shared mutable state confined/synchronized; compound ops not racy
- [ ] Ambiguous accesses guarded by `isOwnedByCurrentRegion(...)`
- [ ] Tested on real Folia with players spread across regions (watch for
      "failed main thread check" stack traces — each is a real bug)
