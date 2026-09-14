-- Dependency-free tests: luau tests/run.luau
-- Real Roblox transport is exercised separately by tests/studio.
local function expect(condition, message)
    if not condition then error(message or "expectation failed", 2) end
end

local function eq(actual, expected, message)
    expect(actual == expected, (message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

local function success(fn)
    local ok, result, err = pcall(fn)
    expect(ok, "unexpected exception: " .. tostring(result))
    expect(result == true, "expected success, got " .. tostring(result) .. ": " .. tostring(err))
end

local function badCall(fn)
    local ok, err = pcall(fn)
    expect(not ok, "expected schema construction to fail")
    expect(string.find(tostring(err), "Prefs", 1, true), "schema error should identify Prefs")
end

local function rejected(fn, fragment)
    local ok, result, err = pcall(fn)
    expect(ok, "rejection must not throw: " .. tostring(result))
    expect(result == false or result == nil, "expected rejection")
    expect(type(err) == "string" and #err > 0, "rejection needs an explanatory error")
    if fragment then expect(string.find(err, fragment, 1, true), "error should include '" .. fragment .. "': " .. err) end
end

local Schema = require("../src/Schema")
local Store = require("../src/Store")

local function makeSchema()
    return Schema.compile({
        MusicVolume = Schema.number(0.8, { min = 0, max = 1, clientWritable = true }),
        CameraShake = Schema.boolean(true, { clientWritable = true }),
        Name = Schema.string("Player"),
        SprintMode = Schema.enum("Hold", { "Hold", "Toggle" }),
    })
end

local function attached(onCommit, dispatch)
    local store = Store.new(makeSchema(), onCommit, dispatch)
    local player, data = {}, {}
    success(function() return store:Attach(player, data) end)
    return store, player, data
end

local function queuedStore()
    local queue = {}
    local store, player, data = attached(nil, function(fn) table.insert(queue, fn) end)
    local function flush()
        while #queue > 0 do local fn = table.remove(queue, 1); fn() end
    end
    return store, player, data, flush
end

local tests = {}
local function test(name, fn) table.insert(tests, { name, fn }) end

test("defaults are isolated and definitions immutable", function()
    local s = makeSchema(); local d = Schema.defaults(s)
    eq(d.MusicVolume, 0.8); eq(d.CameraShake, true); eq(d.Name, "Player"); eq(d.SprintMode, "Hold")
    d.MusicVolume = 0; eq(Schema.defaults(s).MusicVolume, 0.8)
    expect(table.isfrozen(s) and table.isfrozen(s.MusicVolume))
    local values = { "Hold", "Toggle" }; local def = Schema.enum("Hold", values)
    values[2] = "Other"
    expect(Schema.validate(def, "Toggle")); expect(not Schema.validate(def, "Other"))
    expect(table.isfrozen(def.values) and table.isfrozen(def.allowed))
end)

test("invalid schemas and options explain construction failures", function()
    badCall(function() Schema.boolean("true") end)
    badCall(function() Schema.boolean(true, { clientWritable = 1 }) end)
    badCall(function() Schema.string(3) end)
    badCall(function() Schema.number(1, { minimum = 0 }) end)
    badCall(function() Schema.number(1, { min = 2, max = 0 }) end)
    badCall(function() Schema.number(1, { min = 2 }) end)
    badCall(function() Schema.number(1, { max = 0 }) end)
    badCall(function() Schema.number(0 / 0) end)
    badCall(function() Schema.number(1, { max = math.huge }) end)
    badCall(function() Schema.compile({ Fake = { kind = "number", default = 1 } }) end)
    badCall(function() Schema.compile({ [""] = Schema.boolean(true) }) end)
    badCall(function() Schema.compile(setmetatable({}, {})) end)
    badCall(function() Schema.boolean(true, setmetatable({}, {})) end)
end)

test("number bounds are inclusive and nonfinite values rejected", function()
    local def = makeSchema().MusicVolume
    for _, value in ipairs({ 0, 0.5, 1 }) do expect(Schema.validate(def, value)) end
    for _, value in ipairs({ -0.0001, 1.0001, math.huge, -math.huge, 0 / 0, "0.5", false, {} }) do
        expect(not Schema.validate(def, value))
    end
    expect(not Schema.validate(def, nil))
    expect(Schema.validate(Schema.number(0), -1000000))
    expect(Schema.validate(Schema.number(0, { min = 0 }), 1000000))
    expect(Schema.validate(Schema.number(0, { max = 0 }), -1000000))
end)

test("strings validate UTF-8 and a 4096 byte boundary", function()
    local def = Schema.string("")
    expect(Schema.validate(def, "")); expect(Schema.validate(def, string.rep("x", 4096)))
    expect(not Schema.validate(def, string.rep("x", 4097)))
    local twoBytes = string.char(195, 169)
    expect(Schema.validate(def, string.rep(twoBytes, 2048)))
    expect(not Schema.validate(def, string.rep(twoBytes, 2049)))
    for _, value in ipairs({ string.char(255), string.char(195), string.char(192, 128), 1, false, {} }) do
        expect(not Schema.validate(def, value))
    end
    badCall(function() Schema.string(string.char(255)) end)
    badCall(function() Schema.string(string.rep("x", 4097)) end)
end)

test("enums allow only explicit strings and dense unique arrays", function()
    local def = makeSchema().SprintMode
    expect(Schema.validate(def, "Hold")); expect(Schema.validate(def, "Toggle"))
    expect(not Schema.validate(def, "hold")); expect(not Schema.validate(def, 1)); expect(not Schema.validate(def, {}))
    badCall(function() Schema.enum("X", { "A", "A" }) end)
    badCall(function() Schema.enum("X", {}) end)
    badCall(function() Schema.enum("X", { "A" }) end)
    badCall(function() Schema.enum("A", { [1] = "A", [3] = "B" }) end)
    badCall(function() Schema.enum("A", { "A", extra = "B" }) end)
    badCall(function() Schema.enum("A", { "A", "" }) end)
    badCall(function() Schema.enum("A", { "A", string.char(255) }) end)
end)

test("Get and Set mutate the attached table and reject invalid writes atomically", function()
    local store, player, data = attached()
    success(function() return store:Set(player, "MusicVolume", 0.5) end)
    eq(store:Get(player, "MusicVolume"), 0.5); eq(data.MusicVolume, 0.5)
    rejected(function() return store:Set(player, "MusicVolume", 3) end, "MusicVolume")
    rejected(function() return store:Set(player, "CameraShake", "true") end, "boolean")
    rejected(function() return store:Set(player, "SprintMode", "Free") end, "SprintMode")
    rejected(function() return store:Set(player, "Unknown", 1) end, "unknown")
    rejected(function() return store:Set(player, {}, 1) end, "string")
    eq(data.MusicVolume, 0.5); eq(data.CameraShake, true); eq(data.SprintMode, "Hold")
    rejected(function() return store:Get({}, "MusicVolume") end, "attached")
    rejected(function() return store:Get(player, "Unknown") end, "unknown")
end)

test("Toggle, Reset and ResetAll update only schema preferences", function()
    local store, player, data = attached(); local extra = {}; data.Unrelated = extra
    success(function() return store:Toggle(player, "CameraShake") end); eq(data.CameraShake, false)
    success(function() return store:Set(player, "MusicVolume", 0.2) end)
    success(function() return store:Reset(player, "MusicVolume") end); eq(data.MusicVolume, 0.8)
    success(function() return store:Set(player, "Name", "X") end)
    success(function() return store:ResetAll(player) end)
    eq(data.Name, "Player"); eq(data.MusicVolume, 0.8); eq(data.CameraShake, true); eq(data.Unrelated, extra)
    rejected(function() return store:Toggle(player, "MusicVolume") end, "boolean")
    rejected(function() return store:Reset(player, "Unknown") end, "unknown")
end)

test("selective ResetAll preserves server-only values", function()
    local store, player, data = attached()
    success(function() return store:Set(player, "Name", "Server name") end)
    success(function() return store:Set(player, "MusicVolume", 0.1) end)
    success(function() return store:ResetAll(player, function(_, def) return def.clientWritable end) end)
    eq(data.MusicVolume, 0.8); eq(data.Name, "Server name")
end)

test("old data preserves false, valid values and unrelated field identity", function()
    local store, player, nested = Store.new(makeSchema()), {}, { keep = true }
    local data = { MusicVolume = 0.4, CameraShake = false, Legacy = nested, OtherFlag = false }
    success(function() return store:Attach(player, data) end)
    eq(data.MusicVolume, 0.4); eq(data.CameraShake, false); eq(data.SprintMode, "Hold"); eq(data.Name, "Player")
    eq(data.Legacy, nested); eq(data.OtherFlag, false)
    success(function() return store:Set(player, "Name", "Updated") end); eq(data.Name, "Updated")
    local serialized = store:Serialize(player)
    expect(serialized ~= data); eq(serialized.Legacy, nil); eq(serialized.OtherFlag, nil)
end)

test("all invalid saved numbers restore default instead of clamping", function()
    for _, value in ipairs({ -1, 2, math.huge, -math.huge, 0 / 0, "0.4", false, {} }) do
        local store, player = Store.new(makeSchema()), {}; local data = { MusicVolume = value, CameraShake = false }
        success(function() return store:Attach(player, data) end)
        eq(data.MusicVolume, 0.8); eq(data.CameraShake, false)
    end
end)

test("malformed stored types, enums and strings restore defaults", function()
    local store, player = Store.new(makeSchema()), {}
    local data = { CameraShake = "false", SprintMode = "Free", Name = string.char(255) }
    success(function() return store:Attach(player, data) end)
    eq(data.CameraShake, true); eq(data.SprintMode, "Hold"); eq(data.Name, "Player"); eq(data.MusicVolume, 0.8)
end)

test("non-table, metatable and frozen roots reject without replacing state", function()
    local store, player, data = attached()
    success(function() return store:Set(player, "MusicVolume", 0.4) end)
    for _, root in ipairs({ false, 1, "bad", function() end, setmetatable({}, {}), table.freeze({}) }) do
        local fresh = {}
        rejected(function() return store:Attach(fresh, root) end, "plain mutable table")
        expect(not store:IsAttached(fresh))
        rejected(function() return store:Load(player, root) end, "plain mutable table")
        eq(data.MusicVolume, 0.4)
    end
    rejected(function() return store:Attach({}, nil) end, "plain mutable table")
    rejected(function() return store:Load(player, nil) end, "plain mutable table")
end)

test("duplicate Attach emits nothing unless reconciliation repairs a value", function()
    local commits = 0; local store, player, data = attached(function() commits += 1 end)
    local observed = 0; store:Observe(player, "MusicVolume", function() observed += 1 end)
    eq(commits, 1); eq(observed, 1)
    success(function() return store:Attach(player, data) end)
    eq(commits, 1); eq(observed, 1)
    data.MusicVolume = 3
    success(function() return store:Attach(player, data) end)
    eq(data.MusicVolume, 0.8); eq(commits, 2); eq(observed, 2)
end)

test("Load keeps attached identity, unknown fields and false values", function()
    local store, player, data = attached(); local nested = {}; data.Legacy = nested
    local input = { MusicVolume = 0.1, CameraShake = false, Name = "N", Legacy = "replace?", Extra = true }
    success(function() return store:Load(player, input) end)
    eq(data.MusicVolume, 0.1); eq(data.CameraShake, false); eq(data.Name, "N"); eq(data.SprintMode, "Hold")
    eq(data.Legacy, nested); eq(data.Extra, nil); eq(input.Legacy, "replace?")
    success(function() return store:Set(player, "Name", "Still attached") end); eq(data.Name, "Still attached")
    success(function() return store:Load(player, { MusicVolume = 5 }) end)
    eq(data.MusicVolume, 0.8); eq(data.CameraShake, true); eq(data.Legacy, nested)
end)

test("unattached Load and Serialize do not expose a mutable backing table", function()
    local store, player = Store.new(makeSchema()), {}
    local input = { MusicVolume = 0.3, CameraShake = false, Other = 1 }
    success(function() return store:Load(player, input) end)
    input.MusicVolume = 1
    eq(store:Get(player, "MusicVolume"), 0.3); eq(store:Get(player, "CameraShake"), false)
    local copy = store:Serialize(player); copy.MusicVolume = 0
    eq(store:Get(player, "MusicVolume"), 0.3); eq(copy.Other, nil)
end)

test("observers receive initial, changed and previous values exactly once", function()
    local store, player, values = Store.new(makeSchema()), {}, {}
    local conn = store:Observe(player, "MusicVolume", function(value, previous) table.insert(values, { value, previous }) end)
    expect(conn and conn.Connected); eq(#values, 0)
    success(function() return store:Attach(player, { MusicVolume = 0.4 }) end)
    eq(#values, 1); eq(values[1][1], 0.4); eq(values[1][2], nil)
    success(function() return store:Set(player, "MusicVolume", 0.2) end)
    eq(#values, 2); eq(values[2][1], 0.2); eq(values[2][2], 0.4)
    success(function() return store:Set(player, "MusicVolume", 0.2) end); eq(#values, 2)
    conn:Disconnect(); conn:Disconnect(); expect(not conn.Connected)
    success(function() return store:Set(player, "MusicVolume", 0.1) end); eq(#values, 2)
end)

test("queued initial Observe snapshots value at registration", function()
    local store, player, _, flush = queuedStore(); local values = {}
    store:Observe(player, "MusicVolume", function(value, previous) table.insert(values, { value, previous }) end)
    success(function() return store:Set(player, "MusicVolume", 0.2) end)
    eq(#values, 0); flush()
    eq(#values, 2); eq(values[1][1], 0.8); eq(values[1][2], nil)
    eq(values[2][1], 0.2); eq(values[2][2], 0.8)
end)

test("cleanup suppresses queued callbacks and releases connection references", function()
    for _, action in ipairs({ "Disconnect", "Detach", "Destroy" }) do
        local store, player, _, flush = queuedStore(); local called = 0
        local conn = store:Observe(player, "MusicVolume", function() called += 1 end)
        success(function() return store:Set(player, "MusicVolume", 0.2) end)
        if action == "Disconnect" then conn:Disconnect()
        elseif action == "Detach" then success(function() return store:Detach(player) end)
        else success(function() return store:Destroy() end) end
        flush(); eq(called, 0); eq(conn.Connected, false)
        eq(conn.callback, nil, action .. " must release callback")
        eq(conn.store, nil, action .. " must release store")
        eq(conn.subject, nil, action .. " must release subject")
        conn:Disconnect()
    end
end)

test("observer errors and disconnect during dispatch do not break writes", function()
    local store, player = attached()
    store:Observe(player, "Name", function() error("expected observer test error") end)
    local called = 0; local first
    first = store:Observe(player, "Name", function(_, previous) if previous ~= nil then first:Disconnect() end end)
    store:Observe(player, "Name", function() called += 1 end); eq(called, 1)
    success(function() return store:Set(player, "Name", "Z") end)
    eq(called, 2); eq(first.Connected, false)
    success(function() return store:Set(player, "Name", "Y") end); eq(called, 3)
end)

test("invalid observers reject without allocating state", function()
    local store, player = Store.new(makeSchema()), {}
    rejected(function() return store:Observe(player, "Missing", function() end) end, "unknown")
    rejected(function() return store:Observe(player, "Name", true) end, "callback")
    rejected(function() return store:Observe(player, {}, function() end) end, "string")
    eq(store.states[player], nil)
end)

test("client validation enforces permissions, types, bounds and enum values", function()
    local defs = {}; for key, def in pairs(makeSchema()) do defs[key] = def end
    defs.ClientMode = Schema.enum("A", { "A", "B" }, { clientWritable = true })
    local store = Store.new(Schema.compile(defs))
    success(function() return store:ValidateClient("MusicVolume", 0.4) end)
    success(function() return store:ValidateClient("CameraShake", false) end)
    success(function() return store:ValidateClient("ClientMode", "B") end)
    rejected(function() return store:ValidateClient("Name", "x") end, "client-writable")
    rejected(function() return store:ValidateClient("SprintMode", "Toggle") end, "client-writable")
    rejected(function() return store:ValidateClient("MusicVolume", 9) end, "MusicVolume")
    rejected(function() return store:ValidateClient("MusicVolume", 0 / 0) end, "finite")
    rejected(function() return store:ValidateClient("CameraShake", "yes") end, "boolean")
    rejected(function() return store:ValidateClient("ClientMode", "C") end, "enum")
    rejected(function() return store:ValidateClient("Missing", 1) end, "unknown")
    rejected(function() return store:ValidateClient({}, true) end, "string")
    rejected(function() return store:ValidateClient(nil, true) end, "string")
end)

test("detach releases ownership and old observers stay disconnected after reattach", function()
    local store, player, data = attached()
    rejected(function() return store:Attach({}, data) end, "another subject")
    rejected(function() return store:Attach(player, {}) end, "different data table")
    local called = 0; local conn = store:Observe(player, "Name", function() called += 1 end); eq(called, 1)
    success(function() return store:Detach(player) end)
    success(function() return store:Detach(player) end)
    expect(not conn.Connected and not store:IsAttached(player))
    eq(store.states[player], nil); eq(store.owners[data], nil)
    rejected(function() return store:Get(player, "Name") end, "attached")
    success(function() return store:Attach(player, data) end)
    success(function() return store:Set(player, "Name", "Reattached") end); eq(called, 1)
    success(function() return store:Detach(player) end)
    success(function() return store:Attach({}, data) end)
end)

test("nil subjects reject before destroy without throwing or allocating state", function()
    local store = Store.new(makeSchema())
    rejected(function() return store:Attach(nil, {}) end, "subject")
    rejected(function() return store:Load(nil, {}) end, "subject")
    rejected(function() return store:Observe(nil, "Name", function() end) end, "subject")
    rejected(function() return store:Get(nil, "Name") end)
    rejected(function() return store:Set(nil, "Name", "X") end)
    success(function() return store:Detach(nil) end)
    eq(next(store.states), nil)
end)

test("Destroy clears all subjects and prevents stale store reuse", function()
    local store, player, data = attached(); local other = {}
    success(function() return store:Attach(other, {}) end)
    local conn = store:Observe(player, "Name", function() end)
    local pending = store:Observe({}, "Name", function() end)
    success(function() return store:Destroy() end)
    eq(next(store.states), nil); eq(next(store.owners), nil)
    expect(not conn.Connected and not pending.Connected and not store:IsAttached(player))
    eq(data.Name, "Player", "cleanup must not erase externally owned data")
    eq(store:Destroy(), false)
    success(function() return store:Detach(player) end)
    rejected(function() return store:Attach({}, {}) end, "destroyed")
    rejected(function() return store:Load({}, {}) end, "destroyed")
    rejected(function() return store:Get(player, "Name") end, "destroyed")
    rejected(function() return store:Set(player, "Name", "X") end, "destroyed")
    rejected(function() return store:Toggle(player, "CameraShake") end, "destroyed")
    rejected(function() return store:Reset(player, "Name") end, "destroyed")
    rejected(function() return store:ResetAll(player) end, "destroyed")
    rejected(function() return store:Serialize(player) end, "destroyed")
    rejected(function() return store:Observe(player, "Name", function() end) end, "destroyed")
    rejected(function() return store:ValidateClient("MusicVolume", 0.5) end, "destroyed")
end)

local failures = 0
for _, item in ipairs(tests) do
    local ok, err = pcall(item[2])
    if ok then print("PASS", item[1]) else failures += 1; print("FAIL", item[1], err) end
end
print(string.format("%d tests, %d failures", #tests, failures))
-- Standalone Luau has no os.exit; an uncaught error exits with a nonzero status.
if failures > 0 then error(string.format("Prefs: %d pure Luau tests failed", failures), 0) end
