---
name: minecraft-mod
description: Build high-quality Minecraft mods on Fabric, NeoForge, or Forge — modifying the actual game (client and/or server) via a mod loader, mappings, and Mixins — while avoiding the side-safety crashes, registry-timing bugs, and hardcoding that low-quality "AI slop" mods are full of. Use this skill whenever the user wants to create, edit, review, or debug a Minecraft mod, or mentions Fabric, Forge, NeoForge, Mixins, mod loaders, mappings (Yarn/Mojmap/Parchment), DeferredRegister, fabric.mod.json, @Mod, datagen, or multi-loader development. NOTE: this is for game MODS, not server plugins — for Bukkit/Spigot/Paper use the minecraft-paper-plugin skill instead. Pair with the clean-java skill for general Java quality.
---

# Minecraft Mod Development

Mods modify the actual game code and run on a mod loader, unlike server plugins
which only use a stable server API. This is fundamentally harder because the game
is obfuscated: mods compile against **mappings** and often use **Mixins** to inject
into game bytecode. The defining bugs of bad mods are **side-safety crashes**
(client-only code on a server), **registry-timing errors**, and **hardcoding**
values that should be data-driven JSON.

This skill assumes the **clean-java** skill is also in effect.

## Choosing a loader (2026 default)

- **NeoForge** — the de-facto standard for new Forge-style modern content
  (community-governed fork of Forge, MC 1.20.2+). Default choice for new mods with
  blocks/items/mechanics.
- **Fabric** — lightweight, fast updates, dominant for performance/utility mods.
- **Forge** — only for legacy versions (1.12.2 / 1.16.5 / 1.18.2). NeoForge and
  Forge mods are binary-incompatible on 1.20.4+.
- **Multi-loader** — target Fabric + NeoForge from one codebase via
  MultiLoader-Template or Architectury (common module + thin platform modules).

Read the matching reference file for details:
- `references/loaders.md` — Fabric, Forge, NeoForge specifics, registries, entry
  points, multi-loader.
- `references/mixins-and-mappings.md` — how obfuscation/mappings work, Mixin
  injectors and pitfalls.
- `references/best-practices.md` — side-safety, registry timing, data-driven
  design, config, compatibility, and modding beyond Minecraft.

## The non-negotiable rules

**Side-safety: never reference client-only classes from common/server code.**
Calling `Minecraft.getInstance()` from a block, block entity, or common class will
crash any dedicated server. Keep client code in client entrypoints / client-only
classes, gate with `Dist`/`@Environment`, and never transfer data between logical
sides via static fields — use network packets.

**Register at the right time.** Use `DeferredRegister` (NeoForge/Forge) or the
correct Fabric registration in your initializer. Never register objects outside the
proper lifecycle phase, and never query a registry while registration is still
ongoing.

**Be data-driven, not hardcoded.** Generate recipes, loot tables, tags, models,
and block states as JSON via datagen instead of hardcoding values in Java. This
avoids a whole class of errors and lets pack makers override behaviour.

**Prefer the loader API over Mixins.** Use a Mixin only when no API hook exists.
When you must, prefer precise injection points over fragile offset shifts, and
avoid `@Overwrite` (worst compatibility) unless there is no alternative.

**Match code to your exact MC + loader version.** Registry, capability/attachment,
and data-component APIs differ significantly between versions. Always follow the
versioned official docs (docs.fabricmc.net, docs.neoforged.net,
docs.minecraftforge.net).

**Don't break with other mods present.** Declare soft dependencies, use tags
rather than hardcoded IDs, and don't assume you're the only mod touching a system.

## Quick checklist before shipping

- [ ] No client-only class referenced from common/server code
- [ ] Registration via DeferredRegister / proper Fabric init, at the right time
- [ ] No registry queried during ongoing registration
- [ ] Recipes/loot/tags/models are datagen JSON, not hardcoded
- [ ] Mixins used only where no API exists; precise injection points; no needless @Overwrite
- [ ] Data crosses sides via packets, never static fields
- [ ] Config used for tunables (Forge/NeoForge config or Cloth Config on Fabric)
- [ ] Code matches the target MC + loader version's API
- [ ] No swallowed exceptions, immutable data, constructor injection (clean-java)
