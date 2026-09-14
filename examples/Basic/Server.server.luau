-- Script: ServerScriptService/PreferencesServer
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Preferences = require(ReplicatedStorage.Packages.Preferences)

local function onPlayerAdded(player: Player)
    -- Without a data store, pass an empty table. Prefs fills schema defaults.
    local settings = {}
    local ok, err = Preferences:Attach(player, settings)
    if not ok then
        warn(("Prefs:Attach(%s) failed: %s"):format(player.Name, err))
        return
    end

    Preferences:Observe(player, "MusicVolume", function(value, previous)
        print(player.Name, "music volume", previous, "->", value)
    end)
end

for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
    -- Detach early if a profile session ends before the player leaves.
    Preferences:Detach(player)
end)
