local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Prefs = require(ReplicatedStorage.Packages.Prefs)

return Prefs.define({
    SecondaryFlag = Prefs.boolean(false, { clientWritable = true }),
}, { name = "PrefsStudioSecondary" })
