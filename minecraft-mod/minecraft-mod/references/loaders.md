# Mod Loaders: Fabric, Forge, NeoForge & Multi-loader

## Mods vs plugins (the core distinction)

| | Plugin (Bukkit/Spigot/Paper) | Mod (Fabric/Forge/NeoForge) |
|---|---|---|
| Runs on | server only | client and/or server, via a mod loader |
| Touches game code | no — stable API | yes — modifies the actual game |
| Obfuscation | not a concern | compiles against mappings; often uses Mixins |
| Distribution | drop-in jar | requires the loader installed |

If the target is a stable server API only, it's plugin development — use the
minecraft-paper-plugin skill instead.

## Fabric

- **Components:** Fabric Loader, Fabric API (hooks/utilities), Fabric Loom (Gradle
  plugin), mappings (historically Yarn, now migrating to Mojang Mappings).
- **`fabric.mod.json`** declares `id`, `name`, `environment`
  (`client`/`server`/`*`), `entrypoints`, `depends`, and `mixins`.
- **Entrypoints:** common via `ModInitializer.onInitialize()`, plus separate
  `client` (`ClientModInitializer`) and `server` entrypoints. Keep client-only
  code in the client entrypoint.

```java
public class ExampleMod implements ModInitializer {
    public static final String MOD_ID = "examplemod";
    @Override public void onInitialize() {
        // register blocks/items/etc. here
    }
}
```

- Start from the official **fabric-example-mod** template (or the IntelliJ
  Minecraft Development plugin). Loom produces intermediary-named binaries so mods
  survive version changes.
- Common mistakes: client-only code in the common entrypoint; mixins/dependencies
  not declared in `fabric.mod.json`.

## Forge (legacy versions only)

- **`@Mod`-annotated entrypoint**; initialize in the mod constructor, which
  receives the mod event bus.
- **Two event buses:** the mod bus (lifecycle: `FMLCommonSetupEvent`,
  `FMLClientSetupEvent`, `RegisterEvent`) and the game bus
  (`MinecraftForge.EVENT_BUS`).
- Registries via **`DeferredRegister`**; metadata in `mods.toml`.
- **ForgeGradle** build, **Forge MDK** starter (JDK 21 for modern versions).
- Use only for 1.12.2 / 1.16.5 / 1.18.2 era; otherwise prefer NeoForge.

## NeoForge (default for new modern mods)

Community-governed fork of Forge (MC 1.20.2+). Keeps Forge's event/registry/
capability model with a cleaner codebase and better docs.

- **Registration via `DeferredRegister`** (wrapper over `RegisterEvent`), with
  `DeferredHolder<R,T>` (replacing Forge's `RegistryObject`), plus specialized
  `DeferredRegister.Blocks`/`.Items` and `DeferredBlock`/`DeferredItem`.

```java
public static final DeferredRegister.Items ITEMS =
    DeferredRegister.createItems(MOD_ID);
public static final DeferredItem<Item> RUBY =
    ITEMS.registerItem("ruby", Item::new, new Item.Properties());
// in the mod constructor:  ITEMS.register(modEventBus);
```

- **Critical:** do NOT query registries while registration is still ongoing.
- **Events:** mod bus (lifecycle, some fired in parallel) vs `NeoForge.EVENT_BUS`
  (game). `@EventBusSubscriber` auto-registers static handlers — specify `modid`,
  bus, and `Dist`.
- **Data Attachments** (1.20.4+) replace capabilities for attaching data to block
  entities, chunks, entities, levels. Register an `AttachmentType` via a
  `DeferredRegister`; access with `getData`/`setData`/`hasData`/`removeData`.
- **Data Components** (1.20.5+) replace item NBT — immutable key-value data on an
  `ItemStack`, with correct `equals`/`hashCode` (NeoForge enforces this).
- Metadata in `neoforge.mods.toml`; **NeoForge MDK** starter.

## Multi-loader development

Target multiple loaders from one codebase: a **common** module compiled against
vanilla Minecraft (no loader-specific code) plus thin **fabric** / **neoforge**
modules that load the common code and implement platform specifics. Mirrors the
multi-platform plugin pattern.

- **jaredlll08/MultiLoader-Template** — widely-used NeoForge + Fabric template.
- **Architectury** (architectury-loom + architectury-api) — cross-loader
  abstractions and the `@ExpectPlatform` annotation that swaps a static method's
  implementation per loader at compile time.
- **SPI pattern:** a common `PlatformHelper` interface with
  `FabricPlatformHelper` / `NeoForgePlatformHelper` implementations.

## Reference repos & templates

- FabricMC/fabric-example-mod (official Fabric starter)
- NeoForge MDK / Forge MDK (official starters)
- jaredlll08/MultiLoader-Template (NeoForge + Fabric)
- architectury/architectury-api + architectury-loom
- VazkiiMods/Botania (large, mature, well-tested mod — good model for CI, style
  checks, and in-game GameTest suites)
