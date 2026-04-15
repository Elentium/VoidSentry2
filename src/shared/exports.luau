--!strict
--[[
	VoidSentry2 Type Exports Module
]]
export type possibleNode = typeNode | (...any) -> typeNode
export type typeNode<T = any> = {
	write: (value: T) -> number,
	read: (_lastFlag: number?) -> (number, T),
	_T: T
}
export type staticSerializer = {
	serialize: <T>(serdes: typeNode<T>, input: T, offset: number?, compressionLevel: number?) -> buffer,
	deserialize: <T>(serdes: typeNode<T>, input: buffer, offset: number?, wasCompressed: boolean?) -> T,
}

export type dynamicSerializer = {
	serialize: <T...>(compressionLevel: number?, offset: number?, T...) -> buffer?,
	deserialize: (wasCompressed: boolean?, offset: number?, input: buffer) -> ...any?,
}

export type instanceSchemas = {
	[string]: {
		[string]: any,
	},
}

export type function getItemType(target)
	return target:indexer().readresult
end

export type function extractTypeNode(typeNode: type)
	return typeNode:readproperty(types.singleton("_T"))
end

export type function extractTypeNodes(type: type)
    local tbl = types.newtable()
    for key, value in type:properties() do
        tbl:setproperty(key, extractTypeNode(value.read))
    end
    return tbl
end

export type table<KEY = any, VALUE = any> = { [KEY]: VALUE }

export type voidSentryTypes = {
	-- NUMBER TYPES --
	int8: typeNode<number>,
	uint8: typeNode<number>,
	int16: typeNode<number>,
	uint16: typeNode<number>,
	float16: typeNode<number>,
	int24: typeNode<number>,
	uint24: typeNode<number>,
	float24: typeNode<number>,
	int32: typeNode<number>,
	uint32: typeNode<number>,
	float32: typeNode<number>,
	float64: typeNode<number>,

	-- PRIMITIVE TYPES --
	boolean: typeNode<boolean>,
	string: typeNode<string>,
	string255: typeNode<string>,
	vector: typeNode<vector>,
	nothing: typeNode<nil>,

	-- COLLECTION TYPES --
	array: <V>(valueType: V) -> typeNode<{ extractTypeNode<V> }>,
	array255: <V>(valueType: V) -> typeNode<{ extractTypeNode<V> }>,
	map: <K, V>(keyType: K, valueType: V) -> typeNode<{ [extractTypeNode<K>]: extractTypeNode<V> }>,
	map255: <K, V>(keyType: K, valueType: V) -> typeNode<{ [extractTypeNode<K>]: extractTypeNode<V> }>,

	-- ROBLOX TYPES --
	vector3: typeNode<Vector3>,
	cframe: typeNode<CFrame>,
	vector2: typeNode<Vector2>,
	color3: typeNode<Color3>,

	vector3f24: typeNode<Vector3>,
	vector3f16: typeNode<Vector3>,

	vector2f24: typeNode<Vector2>,
	vector2f16: typeNode<Vector2>,

	qcframe: typeNode<CFrame>,
	qcframef24: typeNode<CFrame>,
	cframef24: typeNode<CFrame>,

	instance: typeNode<Instance>,
	serInstance: (className: string) -> typeNode<Instance>,

	enum: <T>(enum: T & Enum) -> typeNode<getItemType<T>>,

	-- SPECIAL TYPES --
	struct: <T>(struct: T) -> typeNode<extractTypeNodes<T>>,
	void: typeNode<{}>,
	any: typeNode<any>,
	optional: <V>(v: V) -> typeNode<extractTypeNode<V>?>,
}

export type voidSentry2 = {
	static: staticSerializer,
	dynamic: dynamicSerializer,
	types: voidSentryTypes,
	combine: <T1, T2>(t1: T1 & table, t2: T2 & table) -> T1 & T2,
	registerInstanceSchema: (className: string, schema: { [string]: any }) -> (),
}

return {}
