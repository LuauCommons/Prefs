# First preference

Start with a scalar setting and expand the schema as your game needs it:

```lua
local Preferences = Prefs.define({
    MusicVolume = Prefs.number(0.8, { min = 0, max = 1, clientWritable = true }),
})
```

Attach a mutable plain table on the server. Missing values are inserted using the schema default. A setting can be read or changed with `Get` and `Set`:

```lua
local settings = { MusicVolume = 0.4 }
Preferences:Attach(player, settings)
Preferences:Set(player, "MusicVolume", 0.6)
```

Use the client form of the methods from a LocalScript. The server remains authoritative and confirms accepted changes.
