-- Script: ServerScriptService/PreferencesServer (replaces Basic/Server.server.luau)
-- ProfileStore owns persistence; Prefs only manages profile.Data.Settings.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileStore = require(ServerScriptService.ProfileStore)
local Preferences = require(ReplicatedStorage.Packages.Preferences)

local PlayerStore = ProfileStore.New("PlayerData", {
    Settings = {},
})
local Profiles = {}

local function loadPlayer(player: Player)
    local profile = PlayerStore:StartSessionAsync(tostring(player.UserId), {
        Cancel = function()
            return player.Parent ~= Players
        end,
    })
    if profile == nil then
        player:Kick("Profile load failed; please rejoin")
        return
    end

    if player.Parent ~= Players then
        profile:EndSession()
        return
    end
    profile:AddUserId(player.UserId)
    profile:Reconcile()
    profile.OnSessionEnd:Connect(function()
        Profiles[player] = nil
        Preferences:Detach(player)
        if player.Parent == Players then
            player:Kick("Profile session ended; please rejoin")
        end
    end)

    if type(profile.Data.Settings) ~= "table" then profile.Data.Settings = {} end
    local attached, attachErr = Preferences:Attach(player, profile.Data.Settings)
    if not attached then
        warn(("Could not attach preferences for %s: %s"):format(player.Name, attachErr))
        profile:EndSession()
        return
    end
    Profiles[player] = profile
end

Players.PlayerAdded:Connect(loadPlayer)
for _, player in Players:GetPlayers() do
    task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
    local profile = Profiles[player]
    Profiles[player] = nil
    Preferences:Detach(player)
    if profile then
        profile:EndSession()
    end
end)
