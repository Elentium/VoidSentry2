--!strict
--!optimize 2
--[[
	VoidSentry2 Type Signs
	Maps type names to their 1-byte discriminator values written on the wire.
]]
return {
	-- NUMBER TYPES
	int8 = 1,
	uint8 = 2,
	int16 = 3,
	uint16 = 4,
	float16 = 5,
	int24 = 6,
	uint24 = 7,
	float24 = 8,
	int32 = 9,
	uint32 = 10,
	float32 = 11,
	float64 = 12,

	-- PRIMITIVE TYPES
	string = 13,
	string255 = 14,
	boolean = 15,
	vector = 16,

	-- COLLECTION TYPES
	array = 17,
	array255 = 18,
	map = 19,
	map255 = 20,

	-- SPECIAL TYPES
	void = 21,
	struct = 22,
	any = 23,
	nothing = 24,
	optional = 25,

	-- ROBLOX TYPES
	vector3 = 26,
	cframe = 27,
	cframef24 = 28,
	qcframe = 29,
	qcframef24 = 30,
	color3 = 31,
	vector2 = 32,
	vector2f24 = 33,
	vector2f16 = 34,
	vector3f24 = 35,
	vector3f16 = 36,
	instance = 37,
	serInstance = 38,
	enum = 39,
}
