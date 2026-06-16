# Project Structure, Build & Lifecycle

## Package organization

Organize by responsibility, not one giant class:

```
com.example.myplugin/
├── MyPlugin.java          # thin JavaPlugin: wires things in onEnable/onDisable
├── command/               # command classes
├── listener/              # event listeners
├── config/                # config models (records) + loading
├── storage/               # repositories, HikariCP datasource
├── model/                 # domain records/value types
└── service/               # business logic
```

Keep `MyPlugin` thin — it constructs services and registers listeners/commands; it
does not contain business logic.

## Dependency injection over singletons

```java
public final class MyPlugin extends JavaPlugin {
    @Override public void onEnable() {
        var config = new PluginConfig(this);
        var dataSource = HikariFactory.create(config);
        var repo = new PlayerRepository(dataSource);
        getServer().getPluginManager()
            .registerEvents(new JoinListener(repo, config), this);
        this.dataSource = dataSource;   // keep a reference to close later
    }
    @Override public void onDisable() {
        if (dataSource != null) dataSource.close();
        Bukkit.getScheduler().cancelTasks(this);
    }
}

public final class JoinListener implements Listener {
    private final PlayerRepository repo;
    private final PluginConfig config;
    public JoinListener(PlayerRepository repo, PluginConfig config) {
        this.repo = repo;
        this.config = config;
    }
}
```

Avoid `MyPlugin.getInstance()` static singletons — they couple every class to the
plugin and make testing hard. Use Bukkit's `ServicesManager` to expose/consume
cross-plugin services.

## Lifecycle cleanup (prevents leaks and post-/reload ghosts)

In `onDisable` (and generally):
- Cancel scheduled tasks (`Bukkit.getScheduler().cancelTasks(plugin)`).
- Unregister dynamically registered listeners
  (`HandlerList.unregisterAll(plugin)`).
- Close `HikariDataSource`, executors, file handles.
- Don't hold long-lived `Player`/entity references; key by `UUID` and remove on
  quit.
- Never swallow exceptions — log with the plugin logger and handle or rethrow.

## paper-plugin.yml vs plugin.yml

Legacy Bukkit uses `plugin.yml`; Paper's modern system uses `paper-plugin.yml`,
which differs:
- **Bootstrappers** (`PluginBootstrap`) run before the server is created and can
  pass values into your plugin constructor. (Experimental API.)
- **Plugin loaders** (`PluginLoader`) build the runtime classpath / supply
  libraries.
- **Classloader isolation** by default; `join-classpath` opts into sharing.
- Dependencies use `load: BEFORE|AFTER|OMIT`, `required`, `join-classpath` — not
  the legacy `dependencies` semantics. Paper does **not** resolve cyclic loading;
  it errors out.
- **No `commands:` block** — register commands via the Brigadier Lifecycle API.
- You can ship both files; Paper prioritizes `paper-plugin.yml`.

Always set `api-version` (1.13+). If omitted, the plugin loads as legacy with a
warning.

## Gradle setup (modern reference)

- Pin the Java toolchain to **21** and set `options.release = 21`.
- `compileOnly("io.papermc.paper:paper-api:<version>")` for normal plugins.
- Use **paperweight-userdev** only if you need NMS/internals (it integrates with
  Shadow).
- Use **xyz.jpenilla.run-paper** for a `runServer` test task.
- Generate `plugin.yml` from build config (Minecrell/plugin-yml) instead of
  hand-maintaining it.
- **Shade + relocate** bundled libraries with the Shadow plugin so they don't
  clash with other plugins (e.g. relocate `com.zaxxer.hikari` to
  `com.example.myplugin.libs.hikari`). Add `mergeServiceFiles()`; consider
  `minimize()`.

## Avoiding NMS / version-specific code

Prefer API over internals — Paper offers no support for programming against
internals, and they change without notice. If you truly need internals, use
**paperweight-userdev**, not reflection or shading the server jar. Note Paper is
Mojang-mapped at runtime since 1.20.5, so parsing the version from package names no
longer works. Isolate any version-specific code behind an interface with one impl
per version, and cache reflective `Field`/`Method` lookups.

## Testing

Use **MockBukkit** + **JUnit 5**:

```java
private ServerMock server;
private MyPlugin plugin;

@BeforeEach void setUp() {
    server = MockBukkit.mock();
    plugin = MockBukkit.load(MyPlugin.class);
}
@AfterEach void tearDown() { MockBukkit.unmock(); }
```

It can simulate players (`server.addPlayer()`), fire real events, and create
worlds without a running server.
