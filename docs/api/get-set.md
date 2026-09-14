# Get and Set

Server signatures include `player`; client signatures do not:

```lua
Preferences:Get(player, key)
Preferences:Set(player, key, value)
Preferences:Get(key)
Preferences:Set(key, value)
```

`Get` returns `value` or `nil, errorMessage`. `Set` returns `true` or `false, errorMessage` and notifies observers only when the value changes.
