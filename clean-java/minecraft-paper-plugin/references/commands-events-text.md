# Commands, Events, Text & Data Storage

## Commands — Brigadier (the modern API)

Paper's command system is built on Mojang's Brigadier and registered via the
Lifecycle API, so you never have to handle `/reload` yourself. (Marked
experimental — pin versions.)

```java
@Override
public void onEnable() {
    LifecycleEventManager<Plugin> manager = this.getLifecycleManager();
    manager.registerEventHandler(LifecycleEvents.COMMANDS, event -> {
        final Commands commands = event.registrar();
        commands.register(
            Commands.literal("broadcast")
                .requires(src -> src.getSender().hasPermission("example.broadcast"))
                .then(Commands.argument("message", StringArgumentType.greedyString())
                    .executes(ctx -> {
                        String msg = StringArgumentType.getString(ctx, "message");
                        Bukkit.broadcast(MiniMessage.miniMessage().deserialize(msg));
                        return Command.SINGLE_SUCCESS;
                    }))
                .build(),
            "Broadcast a message",
            List.of("bc"));
    });
}
```

For simpler cases Paper offers the `BasicCommand` interface. For larger plugins,
**Incendo Cloud** (`cloud-paper`) gives annotated/builder commands with validation;
when using a framework, do **not** also declare commands in plugin.yml — the
framework registers them.

Avoid the old anti-pattern of one giant `onCommand` with nested `if
(args[0].equals(...))` string parsing.

## Events — priorities and rules

Listeners implement `Listener`; handlers use `@EventHandler`. Order is
`LOWEST → LOW → NORMAL → HIGH → HIGHEST → MONITOR`.

```java
@EventHandler(priority = EventPriority.HIGH, ignoreCancelled = true)
public void onBreak(BlockBreakEvent event) {
    if (isProtected(event.getBlock())) event.setCancelled(true);
}
```

Rules:
- **Never modify the event at `MONITOR`** — it is for observing the final outcome
  only (e.g. logging).
- Use `ignoreCancelled = true` rather than manually re-checking `isCancelled()`.
- Protection plugins that cancel a lot should listen early (`LOWEST`/`LOW`).
- Always assume another plugin may already have cancelled or modified the event.
- Don't call the synchronous API from async events.

## Text — Adventure / MiniMessage

Paper natively implements Adventure. Components support RGB, hover/click, and
style inheritance that legacy `§`/`ChatColor` can't represent.

```java
// BAD — legacy
player.sendMessage(ChatColor.GOLD + "Hello " + ChatColor.GREEN + name);

// GOOD — Adventure builder
player.sendMessage(Component.text("Hello ", NamedTextColor.GOLD)
    .append(Component.text(name, NamedTextColor.GREEN)));

// GOOD — MiniMessage (ideal for config-driven messages)
player.sendMessage(MiniMessage.miniMessage().deserialize("<gold>Hello <green>" + name));
```

There is no supported way to mix MiniMessage and legacy color codes — migrate
legacy strings once via `LegacyComponentSerializer`. Bridge PlaceholderAPI
placeholders with a custom `TagResolver` if needed.

## Custom data — PersistentDataContainer

The PDC stores custom data on items, entities, block entities, chunks, and worlds.
It replaces unreliable NBT-reflection hacks and survives version changes because it
doesn't touch server internals.

```java
NamespacedKey key = new NamespacedKey(plugin, "uses");
ItemMeta meta = item.getItemMeta();
meta.getPersistentDataContainer().set(key, PersistentDataType.INTEGER, 3);
item.setItemMeta(meta);
```

Reuse `NamespacedKey` instances. PDC data is not copied between holders
automatically. Saved automatically with the holder.

## Configuration

The built-in `YamlConfiguration` works but is stringly-typed; load/save off the
main thread. Better options: **Configurate** (used internally by Paper) or a
type-safe config library that maps annotated records to YAML. Put all user-facing
messages (as MiniMessage strings) and tunable values in config so server owners can
change them without recompiling.
