# Common usage

```lua
local Preferences = Prefs.define({
    MusicVolume = Prefs.number(0.8, { min = 0, max = 1, clientWritable = true }),
    CameraShake = Prefs.boolean(true, { clientWritable = true }),
    SprintMode = Prefs.enum("Hold", { "Hold", "Toggle" }),
})

-- Server
Preferences:Attach(player, profile.Data.Settings)
Preferences:Observe(player, "MusicVolume", function(value)
    print("Volume changed", value)
end)

-- Client
assert(Preferences:WaitForReady(10))
Preferences:Set("MusicVolume", 0.5)
Preferences:Toggle("CameraShake")
```
