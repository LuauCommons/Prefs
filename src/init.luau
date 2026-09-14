local Schema = require(script.Schema)
local Runtime = require(script.Runtime)

local Prefs = {
	boolean = Schema.boolean,
	number = Schema.number,
	string = Schema.string,
	enum = Schema.enum,
}

function Prefs.define(definitions, options)
	local compiled = Schema.compile(definitions)
	return Runtime.new(compiled, options)
end

Prefs.Schema = Schema
return Prefs
