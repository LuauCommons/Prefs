# Quick start

Create one shared ModuleScript in `ReplicatedStorage/Packages/Preferences`:

```lua
local Prefs = require(game:GetService("ReplicatedStorage").Packages.Prefs)

return Prefs.define({
    MusicVolume = Prefs.number(0.8, { min = 0, max = 1, clientWritable = true }),
    CameraShake = Prefs.boolean(true, { clientWritable = true }),
    SprintMode = Prefs.enum("Hold", { "Hold", "Toggle" }),
}, { name = "PlayerPreferences" })
```

On the server, attach your existing settings table:

```lua
local Preferences = require(game:GetService("ReplicatedStorage").Packages.Preferences)

game:GetService("Players").PlayerAdded:Connect(function(player)
    local settings = {}
    assert(Preferences:Attach(player, settings))
    print(Preferences:Get(player, "MusicVolume"))
end)
```

On the client, wait for the initial snapshot before reading:

```lua
local Preferences = require(game:GetService("ReplicatedStorage").Packages.Preferences)
assert(Preferences:WaitForReady(10))
Preferences:Observe("MusicVolume", function(value)
    print("Confirmed volume", value)
end)
assert(Preferences:Set("MusicVolume", 0.5))
```

The server creates the namespace folder, `Request` RemoteFunction, and `Changed` RemoteEvent automatically.
