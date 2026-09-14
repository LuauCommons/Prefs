-- Roblox transport and the small public facade around the pure Store.
local Store = require(script.Parent.Store)

local Runtime = {}
Runtime.__index = Runtime
local active = {}

local function applySnapshot(self, snapshot, revision)
	if self._destroyed or type(snapshot) ~= "table" then return end
	if type(revision) == "number" and revision <= self._revision then return end
	local loaded = self._store:Load(self._subject, snapshot)
	if loaded == true then
		self._ready = true
		self._revision = revision or self._revision
	end
end

-- RemoteFunction invocation can fail while a server is shutting down or when a
-- player leaves between frames. Keep those transport errors in the normal
-- `(false, message)` API shape instead of surfacing an exception to callers.
local function invokeServer(remote, ...)
	local ok, result, detail, revision = pcall(function(...)
		return remote:InvokeServer(...)
	end, ...)
	if not ok then return false, "Prefs: server request failed: " .. tostring(result) end
	return result, detail, revision
end

function Runtime.new(compiled, options)
	if options ~= nil and (type(options) ~= "table" or getmetatable(options) ~= nil) then error("Prefs: options must be a plain table", 2) end
	options = options or {}
	for key in pairs(options) do
		if key ~= "name" then error("Prefs: unknown option '" .. tostring(key) .. "'", 2) end
	end
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local name = options.name
	if name == nil then name = "Prefs" end
	if type(name) ~= "string" or name == "" then error("Prefs: options.name must be a non-empty string", 2) end
	if active[name] then
		error("Prefs: a runtime named '" .. name .. "' already exists; require the shared Preferences module instead of defining it again", 2)
	end
	local self = setmetatable({ schema = compiled, _server = RunService:IsServer(), _name = name, _revision = 0, _revisions = {}, _destroyed = false, _connections = {}, _limits = {} }, Runtime)
	if self._server then
		local folder = ReplicatedStorage:FindFirstChild(name)
		local ownsFolder = folder == nil
		if folder and not folder:IsA("Folder") then error("Prefs: ReplicatedStorage." .. name .. " is not a Folder") end
		folder = folder or Instance.new("Folder", ReplicatedStorage); folder.Name = name
		local request = folder:FindFirstChild("Request")
		if request and not request:IsA("RemoteFunction") then error("Prefs: " .. name .. ".Request must be a RemoteFunction") end
		request = request or Instance.new("RemoteFunction", folder); request.Name = "Request"
		local changed = folder:FindFirstChild("Changed")
		if changed and not changed:IsA("RemoteEvent") then error("Prefs: " .. name .. ".Changed must be a RemoteEvent") end
		changed = changed or Instance.new("RemoteEvent", folder); changed.Name = "Changed"
		self._request, self._changed, self._folder, self._ownsFolder = request, changed, folder, ownsFolder
		self._store = Store.new(compiled, function(player, snapshot)
			self._revisions[player] = (self._revisions[player] or 0) + 1
			local revision = self._revisions[player]
			if snapshot then changed:FireClient(player, "state", snapshot, revision) else changed:FireClient(player, "detach", nil, revision) end
		end, task.defer)
		request.OnServerInvoke = function(player, op, key, value)
			-- A small application-level bucket complements Roblox's transport limits.
			local now = os.clock(); local bucket = self._limits[player]
			if not bucket then bucket = { time = now, tokens = 30 }; self._limits[player] = bucket end
			bucket.tokens = math.min(30, bucket.tokens + (now - bucket.time) * 15); bucket.time = now
			if bucket.tokens < 1 then return false, "Prefs: request rate limit exceeded" end
			bucket.tokens -= 1
			-- Never let malformed client payloads escape the RemoteFunction callback as
			-- an exception. This is especially important for requests made while a
			-- profile is being detached.
			local ok, result, detail, revision = pcall(function()
				if type(op) ~= "string" then return false, "Prefs: invalid request" end
				if op == "sync" then
					local snapshot, syncErr = self._store:Serialize(player)
					if not snapshot then return false, syncErr end
					return true, snapshot, self._revisions[player] or 0
				end
				local accepted, err
				if op == "set" then
					accepted, err = self._store:ValidateClient(key, value)
					if accepted then accepted, err = self._store:Set(player, key, value) end
				elseif op == "toggle" then
					local def = type(key) == "string" and self.schema[key] or nil
					if type(key) ~= "string" then accepted, err = false, "Prefs: preference name must be a string"
					elseif not def then accepted, err = false, "Prefs: unknown preference '" .. key .. "'"
					elseif not def.clientWritable then accepted, err = false, "Prefs: preference '" .. key .. "' is not client-writable"
					else accepted, err = self._store:Toggle(player, key) end
				elseif op == "reset" then
					local def = type(key) == "string" and self.schema[key] or nil
					if type(key) ~= "string" then accepted, err = false, "Prefs: preference name must be a string"
					elseif not def then accepted, err = false, "Prefs: unknown preference '" .. key .. "'"
					elseif not def.clientWritable then accepted, err = false, "Prefs: preference '" .. key .. "' is not client-writable"
					else accepted, err = self._store:Reset(player, key) end
				elseif op == "resetAll" then
					accepted, err = self._store:ResetAll(player, function(_, def) return def.clientWritable end)
				else
					return false, "Prefs: unknown request"
				end
				if not accepted then return false, err end
				return true, self._store:Serialize(player), self._revisions[player] or 0
			end)
			if not ok then return false, "Prefs: invalid request" end
			return result, detail, revision
		end
		self._connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
			self._store:Detach(player)
			self._limits[player] = nil
			self._revisions[player] = nil
		end)
	else
		-- Reserve the namespace before yielding so concurrent definitions cannot
		-- install a second listener while the server creates its remotes.
		active[name] = self
		local function waitForNetwork(parent, childName, className)
			local child = parent:WaitForChild(childName, 10)
			if not child or not child:IsA(className) then
				active[name] = nil
				if not child then error("Prefs: timed out waiting for server networking '" .. name .. "." .. childName .. "'") end
				error("Prefs: server networking '" .. name .. "." .. childName .. "' must be a " .. className)
			end
			return child
		end
		local folder = waitForNetwork(ReplicatedStorage, name, "Folder")
		self._request = waitForNetwork(folder, "Request", "RemoteFunction")
		self._changed = waitForNetwork(folder, "Changed", "RemoteEvent")
		local subject = self
		self._store = Store.new(compiled, nil, task.defer)
		self._subject = subject
		self._connections.changed = self._changed.OnClientEvent:Connect(function(kind, snapshot, revision)
			if kind == "state" then
				applySnapshot(self, snapshot, revision)
			elseif kind == "detach" then
				if type(revision) == "number" and revision <= self._revision then return end
				self._store:Detach(subject); self._ready = false; self._revision = revision or self._revision
			end
		end)
		task.spawn(function()
			local ok, snapshot, revision = invokeServer(self._request, "sync")
			if ok then applySnapshot(self, snapshot, revision) end
		end)
	end
	active[name] = self
	return self
end

function Runtime:_subjectOrPlayer(player) return self._server and player or self._subject end
function Runtime:_alive()
		return not self._destroyed
end
function Runtime:Get(player, key)
	if not self:_alive() then return nil, "Prefs: runtime has been destroyed" end
	if self._server then return self._store:Get(player, key) end
	return self._store:Get(self._subject, player)
end
function Runtime:Set(player, key, value)
	if not self:_alive() then return false, "Prefs: runtime has been destroyed" end
	if self._server then return self._store:Set(player, key, value) end
	local ok, result, revision = invokeServer(self._request, "set", player, key, value)
	if ok then applySnapshot(self, result, revision) end
	return ok, result
end
function Runtime:Toggle(player, key)
	if not self:_alive() then return false, "Prefs: runtime has been destroyed" end
	if self._server then return self._store:Toggle(player, key) end
	local ok, result, revision = invokeServer(self._request, "toggle", player)
	if ok then applySnapshot(self, result, revision) end
	return ok, result
end
function Runtime:Reset(player, key)
	if not self:_alive() then return false, "Prefs: runtime has been destroyed" end
	if self._server then return self._store:Reset(player, key) end
	local ok, result, revision = invokeServer(self._request, "reset", player)
	if ok then applySnapshot(self, result, revision) end
	return ok, result
end
function Runtime:ResetAll(player)
	if not self:_alive() then return false, "Prefs: runtime has been destroyed" end
	if self._server then return self._store:ResetAll(player) end
	local ok, result, revision = invokeServer(self._request, "resetAll")
	if ok then applySnapshot(self, result, revision) end
	return ok, result
end
function Runtime:Attach(player, data) if not self._server then return false, "Prefs: Attach is server-only" end; if not self:_alive() then return false, "Prefs: runtime has been destroyed" end; return self._store:Attach(player, data) end
function Runtime:Load(player, data) if not self._server then return false, "Prefs: Load is server-only" end; if not self:_alive() then return false, "Prefs: runtime has been destroyed" end; return self._store:Load(player, data) end
function Runtime:Detach(player) if not self._server then return false, "Prefs: Detach is server-only" end; if not self:_alive() then return true end; return self._store:Detach(player) end
function Runtime:Serialize(player) if not self:_alive() then return nil, "Prefs: runtime has been destroyed" end; return self._store:Serialize(self:_subjectOrPlayer(player)) end
function Runtime:Observe(player, key, callback)
	if not self:_alive() then return nil, "Prefs: runtime has been destroyed" end
	if self._server then return self._store:Observe(player, key, callback) end
	return self._store:Observe(self._subject, player, key)
end
function Runtime:WaitForReady(timeout)
	if not self:_alive() then return false, "Prefs: runtime has been destroyed" end
	if self._server then return true end
	if timeout == nil then timeout = 10 end
	if type(timeout) ~= "number" or timeout ~= timeout or timeout == math.huge or timeout < 0 then return false, "Prefs: timeout must be a finite non-negative number" end
	local start = os.clock()
	while not self._ready and os.clock() - start < timeout do task.wait() end
	if self._ready then return true end
	return false, "Prefs: timed out waiting for server preferences"
end
function Runtime:IsAttached(player) if not self:_alive() then return false end; return self._store:IsAttached(self:_subjectOrPlayer(player)) end
function Runtime:Destroy()
	if not self._server then return false, "Prefs: Destroy is server-only" end
	if self._destroyed then return false end
	self._destroyed = true
	for _, c in pairs(self._connections) do c:Disconnect() end
	table.clear(self._connections)
	self._store:Destroy(); self._ready = false
	table.clear(self._limits)
	table.clear(self._revisions)
	if active[self._name] == self then active[self._name] = nil end
	-- Do not leave a destroyed runtime reachable through a surviving folder
	-- (for example when the folder was supplied by the game). A later client
	-- request must fail cleanly instead of invoking stale state and closures.
	if self._server and self._request then self._request.OnServerInvoke = nil end
	if self._server and self._ownsFolder and self._folder and self._folder.Parent then self._folder:Destroy() end
	self._store.onCommit = nil
	self._request, self._changed, self._folder = nil, nil, nil
	return true
end

return Runtime
