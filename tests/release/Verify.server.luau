local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Preferences = require(ReplicatedStorage.Packages.Preferences)
local passed = 0
local function check(condition, message)
    assert(condition, "Prefs release FAIL: " .. message)
    passed += 1
    print("Prefs release server PASS: " .. message)
end

local runtimePassed, runtimeFailed = require(script.Parent.RuntimeSpec)(ReplicatedStorage.Packages.Prefs)
check(runtimePassed > 0 and runtimeFailed == 0, "deterministic runtime regressions")
check(Preferences == require(ReplicatedStorage.Packages.Preferences), "repeat require shares runtime")
local network = ReplicatedStorage:FindFirstChild("PlayerPreferences")
check(network and #network:GetChildren() == 2, "exactly two automatically created remotes")
check(network:FindFirstChild("Request"):IsA("RemoteFunction") and network:FindFirstChild("Changed"):IsA("RemoteEvent"), "remote classes")

local function verify(player)
    local connection
    local received = false
    connection = Preferences:Observe(player, "MusicVolume", function(value)
        if value == 0.5 and not received then
            received = true
            check(Preferences:Get(player, "MusicVolume") == 0.5, "Basic client write reached server")
            check(Preferences:Set(player, "MusicVolume", 0.65), "server Set succeeds")
            player:SetAttribute("PrefsReleaseServerConfirmed", true)
        end
    end)
    check(connection ~= nil, "server Observe before or after Attach")
    local deadline = os.clock() + 15
    while not received and os.clock() < deadline do task.wait() end
    check(received, "Basic Attach/Get/Set/Observe workflow completed")
    connection:Disconnect()
    script:SetAttribute("Passed", passed)
    print(string.format("Prefs release server: %d passed, 0 failed", passed))
end
Players.PlayerAdded:Connect(verify)
for _, player in Players:GetPlayers() do task.spawn(verify, player) end
