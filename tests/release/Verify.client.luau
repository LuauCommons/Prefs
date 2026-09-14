local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Preferences = require(ReplicatedStorage.Packages.Preferences)
local passed = 0
local function check(condition, message)
    assert(condition, "Prefs release FAIL: " .. message)
    passed += 1
    print("Prefs release client PASS: " .. message)
end
check(Preferences == require(ReplicatedStorage.Packages.Preferences), "repeat require shares runtime")
check(Preferences:WaitForReady(15), "client becomes ready without manual remotes")
local observed
local connection = Preferences:Observe("MusicVolume", function(value) observed = value end)
check(connection ~= nil, "client observer registers")
local deadline = os.clock() + 15
while (observed ~= 0.65 or Preferences:Get("CameraShake") ~= false or not Players.LocalPlayer:GetAttribute("PrefsReleaseServerConfirmed")) and os.clock() < deadline do task.wait() end
check(observed == 0.65, "client observer receives confirmed server change")
check(Preferences:Get("MusicVolume") == 0.65, "client Get matches authoritative value")
check(Preferences:Serialize().SprintMode == "Hold", "schema default replicated")
check(Preferences:Get("CameraShake") == false, "Basic client Toggle confirmed")
local ok, err = Preferences:Set("SprintMode", "Toggle")
check(ok == false and type(err) == "string" and err:find("client-writable", 1, true), "default server-only permission")
connection:Disconnect()
check(not connection.Connected, "observer disconnect")
script:SetAttribute("Passed", passed)
print(string.format("Prefs release client: %d passed, 0 failed", passed))
