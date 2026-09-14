# Toggle and reset

```lua
Preferences:Toggle(player, "CameraShake")
Preferences:Reset(player, "MusicVolume")
Preferences:ResetAll(player)
```

Client calls omit `player`. `Toggle` is valid only for booleans. `Reset` restores one schema default; `ResetAll` restores every default on the server and only client-writable settings through the client API.
