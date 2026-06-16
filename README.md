# skills

A collection of [Claude Code skills](https://code.claude.com/docs) for writing high-quality Java and Minecraft plugin/mod code. These skills guide Claude to produce clean, idiomatic, production-ready Java instead of generic "AI slop".

## Skills

All skills live in the `clean-java/` folder:

| Skill | Purpose |
|-------|---------|
| `clean-java` | Modern, idiomatic Java 21+ — records, immutability, proper error handling, no anti-patterns |
| `minecraft-paper-plugin` | Paper/Spigot/Bukkit server plugins without threading bugs |
| `minecraft-folia-plugin` | Folia region-threaded plugins — correct scheduler usage, no main-thread crashes |
| `minecraft-mod` | Fabric/NeoForge/Forge mods — side-safety, registry timing, Mixins |

> The Minecraft skills build on `clean-java`. Claude applies all clean-java rules automatically when a Minecraft skill is active.

---

## Installation

### 1. Install Claude Code

**Option A — CLI (recommended for developers)**

```bash
npm install -g @anthropic-ai/claude-code
```

Requires Node.js 18+. After install, authenticate:

```bash
claude
```

**Option B — Web**  
Open [claude.ai/code](https://claude.ai/code) in your browser — no local install needed.

**Option C — IDE extension**  
Install the Claude Code extension for [VS Code](https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-code) or JetBrains IDEs from their respective marketplaces.

---

### 2. Add the skills to Claude Code

#### Option A — Use the hosted repository (easiest)

Run this once in any project where you want the skills active:

```bash
claude skills add https://github.com/tinybrickboy/skills
```

Claude will automatically pick up the right skill(s) based on what you're working on.

#### Option B — Clone and use locally

```bash
git clone https://github.com/tinybrickboy/skills.git ~/.claude/skills/java-minecraft
```

Then register it in your global or project settings (`~/.claude/settings.json` or `.claude/settings.json`):

```json
{
  "skills": [
    "~/.claude/skills/java-minecraft"
  ]
}
```

#### Option C — Claude Code on the web

1. Open a session at [claude.ai/code](https://claude.ai/code)
2. Go to **Settings → Skills**
3. Add the repository URL: `https://github.com/tinybrickboy/skills`

---

## Skill Triggers

Skills activate automatically based on what you're editing. You don't need to ask for them explicitly.

| When you work on… | Skill(s) activated |
|---|---|
| Any `.java` file | `clean-java` |
| A Paper/Spigot/Bukkit plugin | `minecraft-paper-plugin` + `clean-java` |
| A Folia plugin | `minecraft-folia-plugin` + `minecraft-paper-plugin` + `clean-java` |
| A Fabric/NeoForge/Forge mod | `minecraft-mod` + `clean-java` |

---

## What each skill enforces

### `clean-java`
- Records for data carriers, sealed types + exhaustive switch for hierarchies
- No `null` returns — use `Optional`, empty collections, or throw
- Constructor injection, no static singletons
- No swallowed exceptions, always try-with-resources for `Closeable`
- Streams for transformation only, never for side effects
- Java 21 LTS target (virtual threads, pattern matching, switch expressions)

### `minecraft-paper-plugin`
- Never block the main thread (no sync DB/HTTP on main)
- Never touch Bukkit/Paper API from async threads
- Adventure + MiniMessage for all text (no `ChatColor`)
- Brigadier commands, PersistentDataContainer, player data keyed by UUID
- Clean `onDisable` — cancel tasks, close pools, unregister listeners

### `minecraft-folia-plugin`
- No `BukkitScheduler` / `BukkitRunnable` — use the four Folia schedulers
- `entity.getScheduler()` for entity tasks, `RegionScheduler` for location tasks
- `teleportAsync()` only, never synchronous `teleport()`
- `folia-supported: true` in plugin metadata
- Shared mutable state confined to one scheduler context

### `minecraft-mod`
- Side-safety: no client-only classes in common/server code
- Registration via `DeferredRegister` (NeoForge/Forge) or Fabric init at the right lifecycle phase
- Data-driven: recipes, loot tables, models, tags via datagen JSON
- Mixins only when no API hook exists; no `@Overwrite` unless unavoidable
- NeoForge default for MC 1.20.2+, Fabric for utility/performance mods

---

## Repository structure

```
skills/
└── clean-java/               ← skill package (add this path to Claude Code)
    ├── SKILL.md              ← clean-java skill definition
    ├── references/           ← clean-java reference docs
    │   ├── anti-patterns.md
    │   ├── concurrency-and-errors.md
    │   ├── modern-java.md
    │   └── testing-and-tooling.md
    ├── minecraft-paper-plugin/
    │   ├── SKILL.md
    │   └── references/
    │       ├── commands-events-text.md
    │       ├── structure-and-build.md
    │       └── threading.md
    ├── minecraft-mod/
    │   ├── SKILL.md
    │   └── references/
    │       ├── best-practices.md
    │       ├── loaders.md
    │       └── mixins-and-mappings.md
    └── minecraft-folia-plugin/
        ├── SKILL.md
        └── references/
            ├── schedulers.md
            └── thread-safety-and-migration.md
```

---

## License

MIT — see [LICENSE](LICENSE).
