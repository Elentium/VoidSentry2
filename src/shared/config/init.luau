--!strict
--[[
	VoidSentry2 Configuration Module
]]
local constants = require("@self/constants")
local typeSigns = require("@self/typeSigns")
local instanceSchemas = require("@self/instanceSchemas")

return {
	-- constants
	maxBufferSize = constants.maxBufferSize,
	strictMode = constants.strictMode,
	dynamicVectorType = constants.dynamicVectorType,
	dynamicInstanceType = constants.dynamicInstanceType,
	unknownType = constants.unknownType,
	success = constants.success,
	fail = constants.fail,
	eor = constants.eor,

	-- type signs
	typeSigns = typeSigns,

	-- instance schemas (live table; populated by src/init.luau)
	serializedInstanceSchemas = instanceSchemas,
}
