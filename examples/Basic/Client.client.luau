-- LocalScript: StarterPlayer/StarterPlayerScripts/PreferencesClient
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Preferences = require(ReplicatedStorage.Packages.Preferences)

local ready, err = Preferences:WaitForReady(10)
if not ready then
    warn("Preferences are unavailable: " .. tostring(err))
    return
end

local connection, observeErr = Preferences:Observe("MusicVolume", function(value, previous)
    print("Music volume", previous, "->", value)
    -- Apply value to your audio system here.
end)
if not connection then
    warn(observeErr)
end

-- Set asks the server. The local value changes only after server confirmation.
local accepted, setErr = Preferences:Set("MusicVolume", 0.5)
if not accepted then
    warn("MusicVolume was rejected: " .. tostring(setErr))
end

local toggled, toggleErr = Preferences:Toggle("CameraShake")
if not toggled then
    warn("CameraShake was rejected: " .. tostring(toggleErr))
end
