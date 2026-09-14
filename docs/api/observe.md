# Observe

```lua
local connection, err = Preferences:Observe(player, "MusicVolume", callback)
connection:Disconnect()
```

The client form omits `player`. Registration emits the current value asynchronously when attached. Each accepted change emits `(value, previousValue)`.
