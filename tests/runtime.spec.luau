-- Run in Studio: require(thisModule)(ReplicatedStorage.Packages.Prefs).
-- Transport stubs make response ordering deterministic; real networking is
-- covered separately by the Studio integration fixture.
return function(packageModule)
	local Runtime = require(packageModule.Runtime)
	local Store = require(packageModule.Store)
	local Schema = require(packageModule.Schema)
	local schema = Schema.compile({
		Volume = Schema.number(0.8, { min = 0, max = 1, clientWritable = true }),
		Enabled = Schema.boolean(true, { clientWritable = true }),
	})
	local passed, failed = 0, 0
	local function test(name, callback)
		local ok, err = pcall(callback)
		if ok then
			passed += 1
			print("Prefs runtime PASS: " .. name)
		else
			failed += 1
			warn("Prefs runtime FAIL: " .. name .. ": " .. tostring(err))
		end
	end
	local function client(reply, revision)
		local runtime = setmetatable({
			_server = false, _destroyed = false, _revision = 0,
			_store = Store.new(schema),
		}, Runtime)
		runtime._subject = runtime
		runtime._request = {
			InvokeServer = function(_, ...)
				runtime.lastRequest = table.pack(...)
				return true, reply, revision
			end,
		}
		return runtime
	end
	for _, mutation in ipairs({
		{ method = "Set", op = "set", args = { "Volume", 0.5 } },
		{ method = "Toggle", op = "toggle", args = { "Enabled" } },
		{ method = "Reset", op = "reset", args = { "Volume" } },
		{ method = "ResetAll", op = "resetAll", args = {} },
	}) do
		test(mutation.method .. " response establishes readiness before initial sync", function()
			local runtime = client({ Volume = 0.5, Enabled = false }, 2)
			local seen = {}
			local connection = runtime:Observe("Volume", function(value) table.insert(seen, value) end)
			assert(runtime[mutation.method](runtime, table.unpack(mutation.args)) == true)
			assert(runtime:WaitForReady(0) == true)
			assert(runtime:Get("Volume") == 0.5 and runtime:Get("Enabled") == false)
			assert(runtime._revision == 2 and #seen == 1 and seen[1] == 0.5)
			assert(runtime.lastRequest[1] == mutation.op)
			for index, arg in ipairs(mutation.args) do assert(runtime.lastRequest[index + 1] == arg) end
			connection:Disconnect()
			runtime._store:Destroy()
		end)
	end
	test("stale and equal mutation responses cannot replace newer state", function()
		local runtime = client({ Volume = 0.1, Enabled = false }, 2)
		assert(runtime._store:Attach(runtime, { Volume = 0.9, Enabled = true }))
		runtime._revision = 3
		runtime._ready = true
		assert(runtime:Set("Volume", 0.1))
		assert(runtime:Get("Volume") == 0.9 and runtime._revision == 3)
		runtime._revision = 2
		assert(runtime:Set("Volume", 0.1))
		assert(runtime:Get("Volume") == 0.9 and runtime._revision == 2)
		runtime._store:Destroy()
	end)
	test("false namespace is rejected before creating networking", function()
		local ok, err = pcall(Runtime.new, schema, { name = false })
		assert(not ok and tostring(err):find("options.name", 1, true))
	end)
	test("Destroy releases player and network references", function()
		local subject, disconnected = {}, false
		local request = { OnServerInvoke = function() end }
		local runtime = setmetatable({
			_server = true, _destroyed = false, _name = "PrefsRuntimeRegression",
			_store = Store.new(schema), _limits = { [subject] = {} },
			_revisions = { [subject] = 1 }, _request = request,
			_changed = {}, _folder = {}, _ownsFolder = false,
			_connections = { removing = { Disconnect = function() disconnected = true end } },
		}, Runtime)
		assert(runtime._store:Attach(subject, {}))
		local connection = runtime:Observe(subject, "Volume", function() end)
		assert(runtime:Destroy() == true and runtime:Destroy() == false)
		assert(disconnected and not connection.Connected)
		assert(next(runtime._limits) == nil and next(runtime._revisions) == nil)
		assert(next(runtime._connections) == nil and next(runtime._store.states) == nil)
		assert(request.OnServerInvoke == nil and runtime._request == nil)
		assert(runtime._changed == nil and runtime._folder == nil and runtime._store.onCommit == nil)
	end)
	print(string.format("Prefs runtime regressions: %d passed, %d failed", passed, failed))
	assert(failed == 0, "Prefs runtime regression failures")
	return passed, failed
end
