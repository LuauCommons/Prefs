local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Preferences = require(ReplicatedStorage.Packages.Preferences)
local PreferencesAgain = require(ReplicatedStorage.Packages.Preferences)
local Secondary = require(ReplicatedStorage.Packages.SecondaryPreferences)
local SecondaryAgain = require(ReplicatedStorage.Packages.SecondaryPreferences)
local Prefs = require(ReplicatedStorage.Packages.Prefs)
local PrefsAgain = require(ReplicatedStorage.Packages.Prefs)
local control = ReplicatedStorage:WaitForChild("PrefsFixtureControl"):WaitForChild("Handshake")
local request = ReplicatedStorage:WaitForChild("PrefsStudioFixture"):WaitForChild("Request")
local failures, passes = 0, 0
local function check(ok, message)
    if ok then passes += 1; print("[Prefs fixture] PASS - " .. message) else failures += 1; warn("[Prefs fixture] FAIL - " .. message) end
end
local function invoke(...) return pcall(function(...) return request:InvokeServer(...) end, ...) end
local function waitUntil(predicate, timeout)
    local deadline = os.clock() + (timeout or 5)
    while os.clock() < deadline do if predicate() then return true end task.wait() end
    return predicate()
end
check(Preferences == PreferencesAgain, "duplicate client requires share one runtime")
check(Secondary == SecondaryAgain, "secondary duplicate client requires share one runtime")
check(Prefs == PrefsAgain, "duplicate client package requires share one module")
local duplicateOk = pcall(function() Prefs.define({ Probe = Prefs.boolean(false) }, { name = "PrefsStudioFixture" }) end)
check(not duplicateOk, "duplicate client define is rejected")
control:InvokeServer("clientStarted")
check(waitUntil(function() return control:InvokeServer("isPrepared") == true end, 15), "server completes Attach and reconciliation before client assertions")
local ready, readyErr = Preferences:WaitForReady(10)
check(ready, "delayed Attach snapshot reaches client (" .. tostring(readyErr) .. ")")
if not ready then return end
check(Preferences:Get("MusicVolume") == 0.25, "client receives latest server value")
local secondaryReady = Secondary:WaitForReady(10)
check(secondaryReady, "secondary runtime receives its own snapshot")
check(Secondary:Get("SecondaryFlag") == true, "secondary value is isolated and replicated")
local observed = 0
local observer = Preferences:Observe("MusicVolume", function() observed += 1 end)
check(observer ~= nil, "client observer registers")
task.wait(); check(observed > 0, "initial client observer callback is delivered")
local ok, result = Preferences:Set("MusicVolume", 0.5)
check(ok and type(result) == "table", "valid client-writable Set is accepted with snapshot")
check(waitUntil(function() return Preferences:Get("MusicVolume") == 0.5 end, 3), "confirmed value replicates back")
local enumWrite, enumWriteResult = Preferences:Set("SprintMode", "Toggle")
check(enumWrite and type(enumWriteResult) == "table", "client-writable enum Set is accepted")
local serverOnly, serverOnlyErr = Preferences:Set("ServerFlag", true)
check(not serverOnly and tostring(serverOnlyErr):find("client%-writable") ~= nil, "server-only preference cannot be client-written")
local pcallOk, rawOk, rawErr = invoke("set", "MusicVolume", "bad")
check(pcallOk and not rawOk and tostring(rawErr):find("invalid") ~= nil, "malformed type request is rejected safely")
local unknownPcall, unknownOk, unknownErr = invoke("set", "UnknownPreference", 1)
check(unknownPcall and not unknownOk and tostring(unknownErr):find("unknown preference") ~= nil, "unknown key request is rejected")
local nan = 0 / 0
local nanPcall, nanOk, nanErr = invoke("set", "MusicVolume", nan)
check(nanPcall and not nanOk and tostring(nanErr):find("finite") ~= nil, "NaN is rejected by server validation (transport failure would fail this check)")
local posInfPcall, posInfOk, posInfErr = invoke("set", "MusicVolume", math.huge)
check(posInfPcall and not posInfOk and tostring(posInfErr):find("finite") ~= nil, "+infinity is rejected by server validation")
local negInfPcall, negInfOk, negInfErr = invoke("set", "MusicVolume", -math.huge)
check(negInfPcall and not negInfOk and tostring(negInfErr):find("finite") ~= nil, "-infinity is rejected by server validation")
local rangePcall, rangeOk = invoke("set", "MusicVolume", 2)
check(rangePcall and not rangeOk, "out-of-range number request is rejected")
local enumPcall, enumOk = invoke("set", "SprintMode", "Invalid")
check(enumPcall and not enumOk, "invalid enum request is rejected")
local malformedKeyPcall, malformedKeyOk = invoke("set", 123, true)
check(malformedKeyPcall and not malformedKeyOk, "malformed key request is rejected")
local attachOk, attachErr = Preferences:Attach(nil, {})
check(not attachOk and tostring(attachErr):find("server%-only") ~= nil, "client cannot Attach")
local loadOk, loadErr = Preferences:Load(nil, {})
check(not loadOk and tostring(loadErr):find("server%-only") ~= nil, "client cannot Load")
local detachOk, detachErr = Preferences:Detach(nil)
check(not detachOk and tostring(detachErr):find("server%-only") ~= nil, "client cannot Detach")
local destroyOk, destroyErr = Preferences:Destroy()
check(not destroyOk and tostring(destroyErr):find("server%-only") ~= nil, "client cannot Destroy the server runtime")
local _, resetAllOk, resetAllSnapshot = invoke("resetAll")
check(resetAllOk and type(resetAllSnapshot) == "table" and resetAllSnapshot.ServerFlag == true, "client ResetAll preserves server-only preferences")
local accepted, rateRejected, otherRejected, finished = 0, 0, 0, 0
for i = 1, 80 do task.spawn(function()
    local success, detail = Preferences:Set("MusicVolume", (i % 100) / 100)
    if success then
        accepted += 1
    elseif tostring(detail):find("rate limit") then
        rateRejected += 1
    else
        otherRejected += 1
    end
    finished += 1
end) end
check(waitUntil(function() return finished == 80 end, 10), "all concurrent slider requests complete")
check(accepted > 0 and rateRejected > 0 and otherRejected == 0, "concurrent volume slider burst is explicitly rate-limited")
local ratePcall, rateLimitedOk, rateErr = invoke("set", "MusicVolume", 0.88)
check(ratePcall and (rateLimitedOk or tostring(rateErr):find("rate limit") ~= nil), "burst responses are either accepted or explicitly rate-limited")
task.wait(2.2)
local refillOk = Preferences:Set("MusicVolume", 0.37)
check(refillOk, "rate limiter refills for later valid request")
check(waitUntil(function() return Preferences:Get("MusicVolume") == 0.37 end, 3), "final slider value is authoritative")
local beforeStale = Preferences:Get("MusicVolume")
check(control:InvokeServer("staleRevision") == true, "server sends stale revision fixture packet")
task.wait(0.2)
check(Preferences:Get("MusicVolume") == beforeStale, "out-of-order stale revision cannot overwrite client state")
local beforeDisconnect = observed
if observer then observer:Disconnect() end
task.wait(0.2)
check(observed == beforeDisconnect, "disconnected observer receives no queued callbacks")
check(observer == nil or not observer.Connected, "client observer disconnects cleanly")
local mutationOk = Preferences:Set("MusicVolume", 0.41)
task.wait(0.2)
check(mutationOk and observed == beforeDisconnect, "disconnected observer receives no later mutations")
local detachReattachOk, detachReattachErr = control:InvokeServer("detachReattach")
check(detachReattachOk, "server supports detach and re-attach (" .. tostring(detachReattachErr) .. ")")
local reattached = Preferences:WaitForReady(5)
check(reattached and waitUntil(function() return Preferences:IsAttached() end, 5) and Preferences:Get("MusicVolume") == 0.41, "client becomes ready after detach and re-attach")
check(control:InvokeServer("clientDone") == true, "client reports completed checks")
if failures == 0 then print(("[Prefs fixture] ALL CLIENT CHECKS PASSED (PASS_COUNT=%d FAIL_COUNT=0)"):format(passes)) else warn(("[Prefs fixture] CLIENT CHECKS: PASS_COUNT=%d FAIL_COUNT=%d"):format(passes, failures)) end
