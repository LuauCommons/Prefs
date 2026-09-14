# Serialize and Load

```lua
local snapshot = Preferences:Serialize(player)
Preferences:Load(player, snapshot)
```

`Serialize` returns a fresh table with schema keys only. `Load` applies a full schema snapshot, normalizing missing or invalid values to defaults. `Load` is server-only.
