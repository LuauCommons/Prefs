<div class="prefs-hero">

# Prefs

Small, framework-independent Luau preferences for Roblox.

Define settings once and get defaults, validation, reconciliation, server-authoritative replication, and observers in one package.

<div class="prefs-actions">

[Get started](getting-started/installation.md){ .md-button .md-button--primary }
[GitHub](https://github.com/LuauCommons/Prefs){ .md-button }
[Releases](https://github.com/LuauCommons/Prefs/releases){ .md-button }

</div>
</div>

## A small preferences layer

Prefs attaches to a player-data table you already own, such as `profile.Data.Settings`. It does not save data, create UI, or replace ProfileStore.

```lua
local Preferences = Prefs.define({
    MusicVolume = Prefs.number(0.8, { min = 0, max = 1, clientWritable = true }),
    CameraShake = Prefs.boolean(true, { clientWritable = true }),
    SprintMode = Prefs.enum("Hold", { "Hold", "Toggle" }),
}, { name = "PlayerPreferences" })
```

### What is included

- Boolean, finite number, UTF-8 string, and string enum definitions
- In-place reconciliation of existing data
- Server validation and owner-only replication
- `Get`, `Set`, `Toggle`, `Reset`, `ResetAll`, `Observe`, `Serialize`, and `Load`
- Automatic networking and lifecycle cleanup

Continue with the [quick start](getting-started/quick-start.md), or browse the [API reference](api/define.md).
