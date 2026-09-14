-- Shared ModuleScript: ReplicatedStorage/Packages/Preferences
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Prefs = require(ReplicatedStorage.Packages.Prefs)

return Prefs.define({
    MusicVolume = Prefs.number(0.8, {
        min = 0,
        max = 1,
        clientWritable = true,
    }),
    CameraShake = Prefs.boolean(true, {
        clientWritable = true,
    }),
    SprintMode = Prefs.enum("Hold", { "Hold", "Toggle" }),
}, {
    -- This name is used for the generated remotes. Keep it stable and unique.
    name = "PlayerPreferences",
})
