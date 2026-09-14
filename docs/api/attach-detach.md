# Attach and detach

```lua
Preferences:Attach(player, profile.Data.Settings)
Preferences:Detach(player)
Preferences:IsAttached(player)
```

Both `Attach` and `Load` require a plain mutable table. A table can belong to only one player. `Detach` releases the table and disconnects that player's observers.
