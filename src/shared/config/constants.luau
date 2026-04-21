--!strict
--!optimize 2
--[[
	VoidSentry2 Constants
	Static configuration values with no dependencies.
]]
return {
	-- When serializing, VoidSentry2 writes into a single reusable scratch buffer.
	-- FINISH copies bytes [0, cursor) into an exact-sized buffer.
	-- NOTE: This is a hard cap; if a serialization exceeds this size, it fails.
	maxBufferSize = 10_000_000,

	-- If true: overflows (and other writer failures) throw.
	-- If false: failures warn and return FAIL/nil style instead.
	strictMode = true,

	-- Which type will be inferred when the input value is a vector
	dynamicVectorType = "vector" :: "Vector3" | "vector",
	-- Which value will be inferred when the input value is an instance
	dynamicInstanceType = "instance" :: "serInstance" | "instance",

	-- Instance unique id attribute name
	instanceIdAttribute = "_VSID",

	unknownType = 0,
	success = 0,
	fail = 1,
	eor = 2,
	unsupportedUnionExTypes = {
		union = true,
		any = true,
		void = true,
		optional = true,
	},
}
