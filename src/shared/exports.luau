--[[
	VoidSentry2 Type Exports Module
]]
export type typeNode = {
	write: (value: any) -> number,
	read: (_lastFlag: number?) -> (number, any?),
}

export type possibleNode = typeNode | (...any) -> typeNode

export type staticObject<T... = ()> = {
	_compressionLevel: number?,
	_schema: { any },

	serialize: (self: staticObject<T...>, offset: number?, T...) -> buffer?,
	deserialize: (self: staticObject<T...>, offset: number?, input: buffer) -> T...,
}

export type staticSerializer = {
	new: <T...>(compressionLevel: number?, T...) -> staticObject<T...>,
}

export type dynamicSerializer = {
	serialize: (compressionLevel: number?, offset: number?, ...any) -> buffer?,
	deserialize: (wasCompressed: boolean?, offset: number?, input: buffer) -> ...any?,
}

export type types = {
	-- NUMBER TYPES --
	int8: number,
	uint8: number,
	int16: number,
	uint16: number,
	float16: number,
	int24: number,
	uint24: number,
	float24: number,
	int32: number,
	uint32: number,
	float32: number,
	float64: number,

	-- PRIMITIVE TYPES --
	boolean: boolean,
	string: string,
	string255: string,
	vector: vector,
	nothing: nil,

	-- COLLECTION TYPES --
	array: <V>(valueType: V) -> { V },
	array255: <V>(valueType: V) -> { V },
	map: <K, V>(keyType: K, valueType: V) -> { [K]: V },
	map255: <K, V>(keyType: K, valueType: V) -> { [K]: V },

	-- ROBLOX TYPES --
	vector3: Vector3,
	cframe: CFrame,
	vector2: Vector2,
	color3: Color3,

	vector3f24: Vector3,
	vector3f16: Vector3,

	vector2f24: Vector2,
	vector2f16: Vector2,

	qcframe: CFrame,
	qcframef24: CFrame,
	cframef24: CFrame,

	instance: Instance,
	serInstance: (className: string) -> Instance,

	-- SPECIAL TYPES --
	struct: <T>(struct: { [string]: any } & T) -> T,
	void: {},
	any: any,
	optional: <V>(v: V) -> V?,
}

export type voidSentry = {
	static: staticSerializer,
	dynamic: dynamicSerializer,
	types: types,
}

return {}
