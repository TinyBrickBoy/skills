# Mixins & Mappings

## Why mappings exist (and why modding ≠ plugin dev)

Minecraft: Java Edition was obfuscated from release until 1.21.11 — class and
method names are scrambled (e.g. `brc` instead of `CreeperEntity`). Mods compile
against **mappings** that translate obfuscated names to readable ones. This is the
fundamental reason modding is harder than plugin development.

Mapping sets:
- **Intermediary** — stable names across versions (Fabric's build pipeline).
- **Yarn** — Fabric's open CC0 community mappings (historically default, now being
  deprecated).
- **Mojang Mappings (Mojmap)** — official, lack parameter names/Javadocs.
- **Parchment** — layers parameter names/Javadocs on top of Mojmap.
- **MCP/SRG** — legacy Forge mappings.

**2025–2026 shift:** from MC 1.21.11 Mojang ships unobfuscated code; Fabric is
deprecating Yarn/Intermediary and recommends migrating to Mojang Mappings (via
Loom's `migrateMappings` or the Ravel IntelliJ plugin). For versions after 1.21.11,
default to Mojang Mappings.

## Mixins (bytecode injection)

A Mixin (SpongePowered/Mixin) weaves your handler method into a target game class
at a specified **injection point**. Use it only when no loader API hook exists.

Injector types, from most to least compatible:
- **`@Inject`** — adds a callback at an injection point (`HEAD`, `RETURN`/`TAIL`,
  `INVOKE`, …) via `CallbackInfo` / `CallbackInfoReturnable` (can cancel/return).
- **`@ModifyVariable` / `@ModifyArg(s)` / `@ModifyReturnValue`** — alter locals,
  call arguments, or return values (the latter from MixinExtras).
- **`@Redirect` / `@WrapOperation`** — redirect or wrap a method call / field
  access. Powerful but higher conflict risk.
- **`@Overwrite`** — replaces the whole method. Last resort; worst compatibility.

```java
@Mixin(MinecraftServer.class)
public class MinecraftServerMixin {
    @Inject(method = "tickServer", at = @At("HEAD"))
    private void onTickStart(CallbackInfo ci) {
        // runs at the start of each server tick
    }
}
```

### Mixin best practices & pitfalls

- Prefer the provided API over a Mixin whenever one exists.
- Prefer precise injection points (`@At("INVOKE")` targeting a specific method
  call) over fragile `shift`/`by` offsets — offset shifting is heavily
  discouraged. Use `slice` to narrow the target region.
- Specify `minVersion` and keep the mixin small.
- Mixins are a **compatibility hazard**: multiple mods may target the same method.
  The more invasive the injector, the higher the conflict risk — another reason to
  avoid `@Redirect`/`@Overwrite` where `@Inject`/`@ModifyReturnValue` would do.
- Declare your mixin config in `fabric.mod.json` (Fabric) or the appropriate
  config (NeoForge/Forge) or it won't apply.
