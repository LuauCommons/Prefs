-- Runtime preference store. This module intentionally has no Roblox dependencies.
local Store = {}
Store.__index = Store
local Schema = script and require(script.Parent.Schema) or require("./Schema")

local function plainMutable(t)
	if type(t) ~= "table" or getmetatable(t) ~= nil then return false end
	local marker = {}
	local ok = pcall(function() rawset(t, marker, true); rawset(t, marker, nil) end)
	return ok
end

local function cloneSchema(schema, data)
	local out = {}
	for key in pairs(schema) do out[key] = data[key] end
	return out
end

function Store.new(schema, onCommit, dispatch)
	local self = setmetatable({ schema = schema, schemaValidate = Schema.validate, states = {}, owners = setmetatable({}, { __mode = "k" }), onCommit = onCommit, dispatch = dispatch, destroyed = false }, Store)
	return self
end

-- Stores are single-lifetime objects. Runtime.Destroy marks its store dead so
-- stale references cannot attach new subjects after cleanup.
function Store:_alive()
	return not self.destroyed
end

function Store:_state(subject, create)
	local s = self.states[subject]
	if not s and create then s = { attached = false, data = nil, observers = {} }; self.states[subject] = s end
	return s
end

function Store:_emit(subject, s, changes, initial)
	if self.onCommit then
		local snap = s.attached and cloneSchema(self.schema, s.data) or nil
		pcall(self.onCommit, subject, snap)
	end
	for key, pair in pairs(changes) do
		local list = s.observers[key]
		if list then
			-- Snapshot the list: callbacks are allowed to Disconnect themselves or
			-- other listeners without causing iteration skips.
			local listeners = {}
			for index, listener in ipairs(list) do listeners[index] = listener end
			for _, conn in ipairs(listeners) do
				if conn.Connected then
					local value, previous = pair[1], pair[2]
					local function invoke()
						if not conn.Connected then return end
						local callbackOk, callbackErr = pcall(conn.callback, value, previous)
						if not callbackOk and warn then warn("Prefs observer for '" .. key .. "' failed: " .. tostring(callbackErr)) end
					end
					local dispatchOk, dispatchErr = pcall(self.dispatch or function(fn) fn() end, invoke)
					if not dispatchOk and warn then warn("Prefs observer dispatch failed: " .. tostring(dispatchErr)) end
				end
			end
		end
	end
end

function Store:_reconcile(data, replace)
	local changes = {}
	for key, def in pairs(self.schema) do
		local old = data[key]
		local valid = old ~= nil and self.schemaValidate(def, old)
		local value = def.default
		if valid then value = old end
		if replace or not valid then data[key] = value end
		if old ~= value then changes[key] = { value, old } end
	end
	return changes
end

function Store:Attach(subject, data)
	if not self:_alive() then return false, "Prefs: store has been destroyed" end
	if subject == nil then return false, "Prefs: subject is required" end
	if not plainMutable(data) then return false, "Prefs: attached data must be a plain mutable table" end
	local owner = self.owners[data]
	if owner ~= nil and owner ~= subject then return false, "Prefs: data table is already attached to another subject" end
	local s = self:_state(subject, true)
	if s.attached and s.data ~= data then return false, "Prefs: subject is already attached to a different data table" end
	local wasAttached = s.attached
	self.owners[data] = subject; s.data = data; s.attached = true
	local changes = self:_reconcile(data, false)
	local initial = {}
	if not wasAttached then
		for key in pairs(s.observers) do initial[key] = { data[key], nil } end
	end
	for key, pair in pairs(changes) do if initial[key] == nil then initial[key] = pair end end
	if not wasAttached or next(initial) ~= nil then self:_emit(subject, s, initial, true) end
	return true
end

function Store:IsAttached(subject)
	if not self:_alive() then return false end
	local s = self:_state(subject, false); return s ~= nil and s.attached
end

function Store:Get(subject, key)
	if not self:_alive() then return nil, "Prefs: store has been destroyed" end
	local s = self:_state(subject, false)
	if not s or not s.attached then return nil, "Prefs: subject is not attached" end
	if type(key) ~= "string" then return nil, "Prefs: preference name must be a string" end
	if self.schema[key] == nil then return nil, "Prefs: unknown preference '" .. tostring(key) .. "'" end
	return s.data[key]
end

function Store:Set(subject, key, value)
	if not self:_alive() then return false, "Prefs: store has been destroyed" end
	local s = self:_state(subject, false)
	if not s or not s.attached then return false, "Prefs: subject is not attached" end
	if type(key) ~= "string" then return false, "Prefs: preference name must be a string" end
	local def = self.schema[key]
	if not def then return false, "Prefs: unknown preference '" .. tostring(key) .. "'" end
	local ok, reason = self.schemaValidate(def, value)
	if not ok then return false, "Prefs: invalid '" .. key .. "': " .. reason end
	local old = s.data[key]
	if old == value then return true end
	s.data[key] = value
	self:_emit(subject, s, { [key] = { value, old } })
	return true
end

function Store:Toggle(subject, key)
	if not self:_alive() then return false, "Prefs: store has been destroyed" end
	local s = self:_state(subject, false); if not s or not s.attached then return false, "Prefs: subject is not attached" end
	if type(key) ~= "string" then return false, "Prefs: preference name must be a string" end
	local def = self.schema[key]
	if not def then return false, "Prefs: unknown preference '" .. tostring(key) .. "'" end
	if def.kind ~= "boolean" then return false, "Prefs: preference '" .. key .. "' is not boolean" end
	return self:Set(subject, key, not s.data[key])
end

function Store:Reset(subject, key)
	if not self:_alive() then return false, "Prefs: store has been destroyed" end
	if type(key) ~= "string" then return false, "Prefs: preference name must be a string" end
	local def = self.schema[key]; if not def then return false, "Prefs: unknown preference '" .. tostring(key) .. "'" end
	return self:Set(subject, key, def.default)
end

function Store:ResetAll(subject, predicate)
	if not self:_alive() then return false, "Prefs: store has been destroyed" end
	local s = self:_state(subject, false); if not s or not s.attached then return false, "Prefs: subject is not attached" end
	local changes = {}
	for key, def in pairs(self.schema) do
		if predicate == nil or predicate(key, def) then
		local old = s.data[key]; local value = def.default
		if old ~= value then s.data[key] = value; changes[key] = { value, old } end
		end
	end
	if next(changes) then self:_emit(subject, s, changes) end
	return true
end

function Store:Observe(subject, key, callback)
	if not self:_alive() then return nil, "Prefs: store has been destroyed" end
	if subject == nil then return nil, "Prefs: subject is required" end
	if type(key) ~= "string" then return nil, "Prefs: preference name must be a string" end
	if self.schema[key] == nil then return nil, "Prefs: unknown preference '" .. tostring(key) .. "'" end
	if type(callback) ~= "function" then return nil, "Prefs: callback must be a function" end
	local s = self:_state(subject, true)
	local conn = { Connected = true, callback = callback, store = self, subject = subject, key = key }
	function conn:Disconnect()
		if not self.Connected then return end
		self.Connected = false
		local st = self.store.states[self.subject]; local list = st and st.observers[self.key]
		if list then for i, c in ipairs(list) do if c == self then table.remove(list, i); break end end end
		self.callback, self.store, self.subject, self.key = nil, nil, nil, nil
	end
	s.observers[key] = s.observers[key] or {}; table.insert(s.observers[key], conn)
	if s.attached then
		local initialValue = s.data[key]
		local function invoke()
			if not conn.Connected then return end
			local callbackOk, callbackErr = pcall(conn.callback, initialValue, nil)
			if not callbackOk and warn then warn("Prefs observer for '" .. key .. "' failed: " .. tostring(callbackErr)) end
		end
		pcall(self.dispatch or function(fn) fn() end, invoke)
	end
	return conn
end

function Store:Serialize(subject)
	if not self:_alive() then return nil, "Prefs: store has been destroyed" end
	local s = self:_state(subject, false); if not s or not s.attached then return nil, "Prefs: subject is not attached" end
	return cloneSchema(self.schema, s.data)
end

function Store:Load(subject, input)
	if not self:_alive() then return false, "Prefs: store has been destroyed" end
	if subject == nil then return false, "Prefs: subject is required" end
	if not plainMutable(input) then return false, "Prefs: load data must be a plain mutable table" end
	local s = self:_state(subject, true)
	if not s.attached then
		local data = {}; for k, v in pairs(input) do data[k] = v end
		self.owners[data] = subject; s.data = data; s.attached = true
		local changes = self:_reconcile(data, true); local initial = {}; for key in pairs(s.observers) do initial[key] = { data[key], nil } end
		self:_emit(subject, s, initial); return true
	end
	local changes = {}
	for key, def in pairs(self.schema) do
		local old = s.data[key]; local candidate = input[key]; local ok = candidate ~= nil and self.schemaValidate(def, candidate)
		local value = def.default
		if ok then value = candidate end
		if old ~= value then s.data[key] = value; changes[key] = { value, old } end
	end
	if next(changes) then self:_emit(subject, s, changes) end
	return true
end

function Store:Detach(subject)
	if not self:_alive() then return true end
	local s = self:_state(subject, false); if not s then return true end
	if s.attached then self.owners[s.data] = nil end
	for _, list in pairs(s.observers) do
		for index = #list, 1, -1 do list[index]:Disconnect() end
	end
	s.attached, s.data, s.observers = false, nil, {}
	self.states[subject] = nil
	if self.onCommit then pcall(self.onCommit, subject, nil) end
	return true
end

function Store:Destroy()
	if self.destroyed then return false end
	local subjects = {}; for subject in pairs(self.states) do subjects[#subjects + 1] = subject end
	for _, subject in ipairs(subjects) do self:Detach(subject) end
	self.states = {}; self.owners = setmetatable({}, { __mode = "k" })
	self.destroyed = true
	return true
end

function Store:ValidateClient(key, value)
	if not self:_alive() then return false, "Prefs: store has been destroyed" end
	if type(key) ~= "string" then return false, "Prefs: preference name must be a string" end
	local def = self.schema[key]; if not def then return false, "Prefs: unknown preference '" .. tostring(key) .. "'" end
	if not def.clientWritable then return false, "Prefs: preference '" .. key .. "' is not client-writable" end
	local ok, reason = self.schemaValidate(def, value); if not ok then return false, "Prefs: invalid '" .. key .. "': " .. reason end
	return true
end

return Store
