--!strict
--!optimize 2
--[[
	VoidSentry2 Configuration Module
]]
const constants = require("@self/constants")
const typeSigns = require("@self/typeSigns")
const createFailFn = require("@self/failFn")

local config = {
	-- constants
	maxBufferSize = constants.maxBufferSize,
	strictMode = constants.strictMode,
	dynamicVectorType = constants.dynamicVectorType,
	dynamicInstanceType = constants.dynamicInstanceType,
	unknownType = constants.unknownType,
	success = constants.success,
	fail = constants.fail,
	eor = constants.eor,
	unsupportedUnionExTypes = constants.unsupportedUnionExTypes,
	instanceIdAttribute = constants.instanceIdAttribute,

	editableConstantsMap = {
		maxBufferSize = "number",
		strictMode = "boolean",
		dynamicVectorType = "string",
		dynamicInstanceType = "string",
		unsupportedUnionExTypes = "table",
	},

	-- type signs
	typeSigns = typeSigns,
}

config.failFn = createFailFn(config)

return config
