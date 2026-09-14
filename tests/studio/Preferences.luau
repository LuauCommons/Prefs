-- Shared schema used by both server and client in the Studio fixture.
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
    SprintMode = Prefs.enum("Hold", { "Hold", "Toggle" }, { clientWritable = true }),
    Language = Prefs.string("en", { clientWritable = true }),
    ServerFlag = Prefs.boolean(false),
}, { name = "PrefsStudioFixture" })
