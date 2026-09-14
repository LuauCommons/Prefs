local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Preferences = require(ReplicatedStorage.Packages.Preferences)
local PreferencesAgain = require(ReplicatedStorage.Packages.Preferences)
local Secondary = require(ReplicatedStorage.Packages.SecondaryPreferences)
local SecondaryAgain = require(ReplicatedStorage.Packages.SecondaryPreferences)
local Prefs = require(ReplicatedStorage.Packages.Prefs)
local PrefsAgain = require(ReplicatedStorage.Packages.Prefs)

local failures, passes = 0, 0
local function check(ok, message)
    if ok then passes += 1; print("[Prefs fixture] PASS - " .. message) else failures += 1; warn("[Prefs fixture] FAIL - " .. message) end
end
local function waitUntil(predicate, timeout)
    local deadline = os.clock() + (timeout or 5)
    while os.clock() < deadline do if predicate() then return true end task.wait() end
    return predicate()
end

local controlFolder = ReplicatedStorage:FindFirstChild("PrefsFixtureControl") or Instance.new("Folder")
controlFolder.Name = "PrefsFixtureControl"; controlFolder.Parent = ReplicatedStorage
local control = controlFolder:FindFirstChild("Handshake") or Instance.new("RemoteFunction")
control.Name = "Handshake"; control.Parent = controlFolder
local started, prepared, done, observers, attachedData = {}, {}, {}, {}, {}
check(Preferences == PreferencesAgain, "duplicate requires return one shared runtime")
check(Secondary == SecondaryAgain, "secondary duplicate requires return one shared runtime")
check(Prefs == PrefsAgain, "duplicate package requires return one shared module")
local remotes = ReplicatedStorage:WaitForChild("PrefsStudioFixture")
local secondaryRemotes = ReplicatedStorage:WaitForChild("PrefsStudioSecondary")
local changedRemote = remotes:WaitForChild("Changed")
control.OnServerInvoke = function(player, op)
    if op == "clientStarted" then started[player] = true; return true end
    if op == "isPrepared" then return prepared[player] == true end
    if op == "detachReattach" then
        local data = attachedData[player]
        if not data then return false, "fixture player data is unavailable" end
        local detached = Preferences:Detach(player)
        local attached, err = Preferences:Attach(player, data)
        return detached == true and attached == true, err
    end
    if op == "staleRevision" then
        -- Use the RemoteEvent child explicitly. `Folder.Changed` is the
        -- Instance.Changed signal and is not the library transport event.
        changedRemote:FireClient(player, "state", { MusicVolume = 0.01 }, 1)
        return true
    end
    if op == "clientDone" then done[player] = true; return true end
    return false, "unknown fixture operation"
end
check(remotes:FindFirstChild("Request") and remotes.Request:IsA("RemoteFunction"), "library Request RemoteFunction exists")
check(changedRemote:IsA("RemoteEvent"), "library Changed RemoteEvent exists")
check(#remotes:GetChildren() == 2, "duplicate requires create no extra library remotes")
local before = #remotes:GetChildren()
local duplicateOk = pcall(function() Prefs.define({ Probe = Prefs.boolean(false) }, { name = "PrefsStudioFixture" }) end)
check(not duplicateOk and #remotes:GetChildren() == before, "duplicate define fails without extra remotes")
check(secondaryRemotes ~= remotes and secondaryRemotes:FindFirstChild("Request") ~= nil and secondaryRemotes:FindFirstChild("Changed") ~= nil, "secondary schema creates isolated remotes")

local function runPlayer(player)
    waitUntil(function() return started[player] end, 5)
    task.wait(1)
    local settings = { MusicVolume = 7, CameraShake = "yes", SprintMode = "Invalid", LegacyField = { preserved = true } }
    local secondarySettings = { SecondaryFlag = false, Keep = "secondary" }
    check(Secondary:Attach(player, secondarySettings), "secondary schema attaches its own table")
    check(Secondary:Set(player, "SecondaryFlag", true), "secondary schema Set succeeds independently")
    check(Secondary:Get(player, "SecondaryFlag") == true and settings.SecondaryFlag == nil, "secondary state is isolated")
    local secondarySnapshot = Secondary:Serialize(player)
    check(secondarySnapshot.SecondaryFlag == true and secondarySnapshot.Keep == nil, "secondary Serialize is schema-only")
    local malformedRoot = setmetatable({ Keep = 42 }, { __newindex = function() error("immutable") end })
    local bad = Preferences:Attach(player, malformedRoot)
    check(not bad and malformedRoot.Keep == 42, "malformed Attach root is rejected without mutation")
    local attached, attachErr = Preferences:Attach(player, settings)
    attachedData[player] = settings
    check(attached, "Attach accepts mutable saved data (" .. tostring(attachErr) .. ")")
    check(settings.MusicVolume == 0.8, "out-of-range numbers reset to defaults (never clamp)")
    check(settings.CameraShake == true, "wrong types reset to defaults")
    check(settings.SprintMode == "Hold", "invalid enum resets to default")
    check(settings.Language == "en", "new preferences are added")
    check(settings.LegacyField and settings.LegacyField.preserved == true, "unrelated attached fields remain intact")
    check(Preferences:Get(player, "MusicVolume") == 0.8, "Get returns reconciled value")
    local snapshot = Preferences:Serialize(player)
    check(snapshot.LegacyField == nil and snapshot.MusicVolume == 0.8, "Serialize excludes unknown fields")
    local observed = 0
    local observer = Preferences:Observe(player, "MusicVolume", function() observed += 1 end)
    observers[player] = observer
    check(observer and observer.Connected, "server observer registers")
    check(observed == 0, "observer callback is deferred")
    waitUntil(function() return observed > 0 end, 2)
    check(observed > 0, "deferred observer callback runs")
    local errorObserver = Preferences:Observe(player, "MusicVolume", function()
        error("intentional observer callback failure")
    end)
    check(errorObserver and errorObserver.Connected, "observer callback errors are isolated")
    check(Preferences:Set(player, "MusicVolume", 0.7), "observer callback failure does not reject Set")
    task.wait()
    check(Preferences:Get(player, "MusicVolume") == 0.7, "value commits despite observer callback failure")
    errorObserver:Disconnect()
    check(Preferences:Load(player, { CameraShake = false }), "Load accepts a valid false value")
    check(Preferences:Get(player, "CameraShake") == false, "valid false saved value is preserved")
    check(Preferences:Set(player, "MusicVolume", 0.5), "server Set accepts valid value")
    check(Preferences:Toggle(player, "CameraShake"), "Toggle changes boolean")
    check(Preferences:Reset(player, "MusicVolume"), "Reset restores one default")
    check(Preferences:Set(player, "MusicVolume", 0.2), "set value before ResetAll")
    check(Preferences:ResetAll(player), "ResetAll restores all server values")
    check(Preferences:Get(player, "MusicVolume") == 0.8 and Preferences:Get(player, "CameraShake") == true, "ResetAll values are defaults")
    check(settings.LegacyField.preserved == true, "ResetAll preserves unrelated fields")
    local loadOk = Preferences:Load(player, { MusicVolume = 0.25, Language = 42, LegacyField = "ignored" })
    check(loadOk and Preferences:Get(player, "MusicVolume") == 0.25, "Load keeps valid values")
    check(Preferences:Get(player, "Language") == "en", "Load repairs malformed values")
    check(settings.LegacyField.preserved == true, "Load does not overwrite unrelated attached fields")
    check(Preferences:Set(player, "ServerFlag", true), "server-only preference can be changed on server")
    prepared[player] = true
    check(waitUntil(function() return done[player] end, 15), "client/server handshake completed")
    check(observer.Connected, "observer remains connected while player is present")
end

for _, player in Players:GetPlayers() do task.spawn(runPlayer, player) end
Players.PlayerAdded:Connect(function(player) task.spawn(runPlayer, player) end)
Players.PlayerRemoving:Connect(function(player)
    task.defer(function()
        check(not Preferences:IsAttached(player), "PlayerRemoving automatically detaches state")
        check(observers[player] == nil or not observers[player].Connected, "player observers are cleaned up on departure")
        check(Preferences._limits[player] == nil and Preferences._revisions[player] == nil, "rate and revision state are removed on departure")
        started[player] = nil; prepared[player] = nil; done[player] = nil; observers[player] = nil; attachedData[player] = nil
    end)
end)
game:BindToClose(function()
    Preferences:Destroy()
    check(remotes.Parent == nil or remotes:FindFirstChild("Request") == nil, "Destroy removes owned remotes")
    if failures == 0 then print(("[Prefs fixture] ALL SERVER CHECKS PASSED (PASS_COUNT=%d FAIL_COUNT=0)"):format(passes)) else warn(("[Prefs fixture] SERVER CHECKS: PASS_COUNT=%d FAIL_COUNT=%d"):format(passes, failures)) end
end)
