# Observe

Observers receive the current value asynchronously when registered, then `(value, previousValue)` for accepted changes.

```lua
local connection = Preferences:Observe(player, "MusicVolume", function(value, previous)
    print(previous, "->", value)
end)
connection:Disconnect()
```

Client code omits `player`. Callback errors are protected and warned. Disconnect observers when a feature no longer needs them; `Detach` and player cleanup disconnect the remaining observers automatically.
