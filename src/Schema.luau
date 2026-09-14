-- Pure Luau schema definitions and validation.
local Schema = {}

local brands = setmetatable({}, { __mode = "k" })

local function fail(message)
	error("Prefs schema error: " .. message, 3)
end

local function optsTable(options)
	if options == nil then return {} end
	if type(options) ~= "table" then fail("options must be a table") end
	if getmetatable(options) ~= nil then fail("options must be a plain table") end
	return options
end

local function checkOptionKeys(o, allowed)
	for k in pairs(o) do if not allowed[k] then fail("unknown option '" .. tostring(k) .. "'") end end
end

local function checkClientWritable(v)
	if v == nil then return false end
	if type(v) ~= "boolean" then fail("clientWritable must be a boolean") end
	return v
end

local function checkNumber(n, label)
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then fail(label .. " must be a finite number") end
end

local function validString(value)
	if type(value) ~= "string" or #value > 4096 then return false end
	if utf8 and utf8.len then
		local ok, length = pcall(utf8.len, value)
		if not ok or length == nil then return false end
	end
	return true
end

local function make(kind, default, options)
	local o = optsTable(options)
	local d = { kind = kind, default = default, clientWritable = checkClientWritable(o.clientWritable) }
	brands[d] = true
	return table.freeze(d)
end

function Schema.boolean(default, options)
	if type(default) ~= "boolean" then fail("boolean default must be boolean") end
	local o = optsTable(options); checkOptionKeys(o, { clientWritable = true })
	return make("boolean", default, o)
end

function Schema.number(default, options)
	if type(default) ~= "number" then fail("number default must be number") end
	checkNumber(default, "number default")
	local o = optsTable(options)
	checkOptionKeys(o, { min = true, max = true, clientWritable = true })
	local min, max = o.min, o.max
	if min ~= nil then checkNumber(min, "min") end
	if max ~= nil then checkNumber(max, "max") end
	if min ~= nil and max ~= nil and min > max then fail("min cannot be greater than max") end
	if min ~= nil and default < min then fail("number default is below min") end
	if max ~= nil and default > max then fail("number default is above max") end
	local d = { kind = "number", default = default, min = min, max = max, clientWritable = checkClientWritable(o.clientWritable) }
	brands[d] = true
	return table.freeze(d)
end

function Schema.string(default, options)
	if type(default) ~= "string" then fail("string default must be string") end
	if not validString(default) then fail("string default must be valid UTF-8 and at most 4096 bytes") end
	local o = optsTable(options); checkOptionKeys(o, { clientWritable = true })
	return make("string", default, o)
end

function Schema.enum(default, values, options)
	if type(default) ~= "string" or default == "" then fail("enum default must be a non-empty string") end
	if type(values) ~= "table" or getmetatable(values) ~= nil then fail("enum values must be a plain array") end
	local n = #values
	if n < 1 then fail("enum values must not be empty") end
	local count = 0
	for k in pairs(values) do if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > n then fail("enum values must be a dense array") end; count += 1 end
	if count ~= n then fail("enum values must be a dense array") end
	local copy, allowed = {}, {}
	for i = 1, n do
		local v = values[i]
		if type(v) ~= "string" or v == "" then fail("enum values must be non-empty strings") end
		if not validString(v) then fail("enum value must be valid UTF-8 and at most 4096 bytes") end
		if allowed[v] then fail("enum values must be unique") end
		allowed[v] = true; copy[i] = v
	end
	if allowed[default] ~= true then fail("enum default must be one of the allowed values") end
	local o = optsTable(options)
	checkOptionKeys(o, { clientWritable = true })
	local d = { kind = "enum", default = default, values = table.freeze(copy), allowed = table.freeze(allowed), clientWritable = checkClientWritable(o.clientWritable) }
	brands[d] = true
	return table.freeze(d)
end

function Schema.compile(schema)
	if type(schema) ~= "table" or getmetatable(schema) ~= nil then fail("definition must be a plain table") end
	local out = {}
	for key, def in pairs(schema) do
		if type(key) ~= "string" or key == "" or #key > 100 then fail("setting names must be non-empty strings of at most 100 bytes") end
		if not brands[def] then fail("setting '" .. key .. "' is not a Prefs definition") end
		out[key] = def
	end
	return table.freeze(out)
end

function Schema.validate(def, value)
	if not brands[def] then return false, "unknown preference definition" end
	if def.kind == "boolean" then
		if type(value) ~= "boolean" then return false, "expected boolean" end
	elseif def.kind == "number" then
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return false, "expected finite number" end
		if def.min ~= nil and value < def.min then return false, "below minimum " .. tostring(def.min) end
		if def.max ~= nil and value > def.max then return false, "above maximum " .. tostring(def.max) end
	elseif def.kind == "string" then
		if type(value) ~= "string" then return false, "expected string" end
		if not validString(value) then return false, "string must be valid UTF-8 and at most 4096 bytes" end
	elseif def.kind == "enum" then
		if type(value) ~= "string" then return false, "expected one of enum strings" end
		if not def.allowed[value] then return false, "value is not an allowed enum value" end
	end
	return true
end

function Schema.defaults(schema)
	local out = {}
	for key, def in pairs(schema) do out[key] = def.default end
	return out
end

Schema._isDefinition = function(def) return brands[def] == true end
return table.freeze(Schema)
