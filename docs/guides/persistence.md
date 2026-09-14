# Persistence

Prefs does not save data. It operates on a table owned by your data layer:

```lua
Preferences:Attach(player, profile.Data.Settings)
```

Use `Serialize` for a schema-only copy and `Load` to apply a full snapshot. Keep the attached table identity stable so accepted writes reach the data layer.
