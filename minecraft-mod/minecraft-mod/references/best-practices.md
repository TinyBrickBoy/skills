# Modding Best Practices & Common Mistakes

## Side-safety (the #1 crash cause)

Minecraft has two logical sides: client and server. A dedicated server has no
client classes loaded — referencing them crashes it.

```java
// BAD — crashes any dedicated server: Minecraft is a client-only class
public class RubyBlock extends Block {
    public void onUse() {
        Minecraft.getInstance().player.sendMessage(...);  // CRASH on server
    }
}
```

Rules:
- Never reference `net.minecraft.client.*` from common/server code.
- Keep client code in client entrypoints (Fabric `ClientModInitializer`) or
  client-only classes, gated by side:
  - Fabric: `@Environment(EnvType.CLIENT)`; check `FabricLoader` env.
  - NeoForge/Forge: `@EventBusSubscriber(value = Dist.CLIENT)`, sided setup events
    (`FMLClientSetupEvent` / `FMLDedicatedServerSetupEvent`), or
    `FMLEnvironment.dist`. Do **not** use `@OnlyIn` directly.
- **Never transfer data between logical sides via static fields** — even in
  single-player the two sides run on different threads. Use network packets.

## Registry timing

- Register through `DeferredRegister` (NeoForge/Forge) or your Fabric initializer
  — never in the wrong lifecycle phase.
- Do not query a registry while registration is still ongoing.
- Don't register from arbitrary constructors or static initializers that run too
  early.

## Data-driven design (don't hardcode)

Use **datagen** to generate JSON for recipes, loot tables, tags, block states,
models, and advancements instead of hardcoding. This avoids hand-written-JSON
errors and lets data packs override your content. Reference other content by
**tags**, not hardcoded item/block IDs, so you stay compatible with other mods.

## Configuration

- Forge/NeoForge: the built-in config system (`ModConfigSpec`).
- Fabric: a config library such as **Cloth Config**.
- Put tunable values in config; don't hardcode them in Java.

## Networking

Send custom data between sides with the loader's packet/payload system
(NeoForge payloads, Fabric networking API). Validate and bounds-check anything
received from the client on the server — never trust client input.

## Mod compatibility

- Declare soft dependencies for optional integrations.
- Don't assume you're the only mod touching a block/entity/system.
- Use the attachment/data-component systems and tags rather than hardcoding.
- Avoid invasive Mixins where an API or event exists.

## Performance

- Avoid per-tick allocation in hot paths (block ticks, entity ticks, rendering).
- Cache expensive lookups; don't query registries or parse data every tick.
- Profile with a mod profiler (e.g. Spark) before optimizing.

## Modding/extension beyond Minecraft

The same extension patterns recur across Java software:
- **RuneLite** (Old School RuneScape) — plugins extend `Plugin`, annotated
  `@PluginDescriptor`, with a `Config` interface, `Overlay`s, and an `@Subscribe`
  EventBus; distributed via the Plugin Hub.
- Other ecosystems: Terasology, jMonkeyEngine games, Robocode.
- **General Java plugin architecture:** `java.util.ServiceLoader` / SPI is the
  standard JDK mechanism for runtime-discovered extensions; OSGi for dynamic
  modules; classloader isolation to separate extension code. These same patterns
  underlie the mod loaders themselves.
