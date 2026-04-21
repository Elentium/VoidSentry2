--!strict
--!optimize 2
--[[
	VoidSentry2 Configuration Module
]]
const constants = require("@self/constants")
const typeSigns = require("@self/typeSigns")

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
	unsupportedUnionExTypes = constants.unsupportedUnionExTypes,
	instanceIdAttribute = constants.instanceIdAttribute,

	-- type signs
	typeSigns = typeSigns,
}
