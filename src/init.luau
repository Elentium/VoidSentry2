--!optimize 2
--!native
--[[
	================================================================================
	  VoidSentry2  |  v0.1.0  |  Apache-2.0  |  by IAMNOTULTRA3
	================================================================================
	  Buffer serialization library for Roblox. Converts Luau & Roblox values into
	buffers and back. Supports schema-based (static) and schemaless
	  (dynamic) serialization with optional Zstd compression.
	================================================================================
	  API
	================================================================================
	  VoidSentry2.types    -- named type nodes/factories; pass as schema arguments
	  VoidSentry2.static   -- schema-based serializer; fastest, layout known upfront
	  VoidSentry2.dynamic  -- schemaless serializer; tags each value at runtime
	  VoidSentry2.instanceSchemas -- container for serialized instances schemas;

	  static.serialize(serdes, value, offset?, compressionLevel?) -> buffer?
	  static.deserialize(serdes, buf, offset?, wasCompressed?) -> value?

	  dynamic.serialize(compressionLevel: number?, offset: number?, ...values) -> buffer?
	  dynamic.deserialize(wasCompressed: boolean?, offset: number?, buf: buffer)     -> ...values?
	================================================================================
	  TYPES
	================================================================================
	  INTEGERS            size     range
	    int8              1 B      -128 .. 127
	    uint8             1 B      0 .. 255
	    int16             2 B      -32768 .. 32767
	    uint16            2 B      0 .. 65535
	    int24             3 B      -8388608 .. 8388607
	    uint24            3 B      0 .. 16777215
	    int32             4 B      -2147483648 .. 2147483647
	    uint32            4 B      0 .. 4294967295

	  FLOATS              size     notes
	    float16           2 B      half-precision (IEEE 754)
	    float24           3 B      24-bit custom encoding
	    float32           4 B      single-precision (IEEE 754)
	    float64           8 B      double-precision (IEEE 754)

	  PRIMITIVES          size     notes
	    boolean           1 B      true or false
	    string            2+n B    raw byte string; max 65535 bytes
	    string255         1+n B    raw byte string; max 255 bytes
	    vector            12 B     Luau vector (X Y Z as float32)
	    nothing           0 B      nil; writes and reads nothing

	  COLLECTIONS         size     notes
	    array(T)          2+T(n)   ordered list; max 65535 elements
	    array255(T)       1+T(n)    ordered list; max 255 elements
	    map(K,V)          2+n(K+V)  uint16 n, then n (key,value) pairs; K,V sized per entry if fixed
	    map255(K,V)       1+n (K+V)  uint8 n; max 255 pairs; same layout

	  SPECIAL             size     notes
	    void              0 B      empty table {}; no bytes written
	    struct({k=T})     sum(T)   values only, keys sorted, no names on wire
	    optional(T)       1+T?     1 B presence flag; inner T only if present
	    any               1+T      1 B discriminator + dynamically inferred value

	  ROBLOX TYPES        size     notes
	    vector3           12 B     Vector3 (X Y Z as float32)
	    vector3f24         9 B     Vector3 (X Y Z as float24)
	    vector3f16         6 B     Vector3 (X Y Z as float16)
	    vector2            8 B     Vector2 (X Y as float32)
	    vector2f24         6 B     Vector2 (X Y as float24)
	    vector2f16         4 B     Vector2 (X Y as float16)
	    color3             3 B     Color3 (R G B as uint8, 0-255 per channel)
	    cframe            48 B     CFrame 3x4 matrix (float32 components)
	    cframef24         36 B     CFrame 3x4 matrix (float24 components)
	    qcframe           28 B     CFrame quaternion + position (float32)
	    qcframef24        21 B     CFrame quaternion + position (float24)
		enum			  2  B     Roblox Enumeration (2 bytes for writing the EnumItem Value)
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const exports = require("@self/shared/exports")
const static = require("@self/serializers/static")
const dynamic = require("@self/serializers/dynamic")
const typeSigns = require("@self/shared/config/typeSigns")
const instanceSchemas = require("@self/static/instanceSchemas")
const typesModule = require("@self/types")
const config = require("@self/shared/config")
const serInstanceSigns = require("@self/static/serInstanceSigns")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
export type staticSerializer = exports.staticSerializer
export type dynamicSerializer = exports.dynamicSerializer
export type types = exports.voidSentryTypes
export type voidSentry2 = exports.voidSentry2
export type possibleNode = exports.possibleNode
export type typeNode<T = any> = exports.typeNode<T>
export type extractTypeNode<T> = exports.extractTypeNode<T>

-----------------------------------------------------
-- VARIABLES                                       --
-----------------------------------------------------
const signMap: { possibleNode } = typesModule.signMap
const types: types = typesModule.types
const failFn: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- INIT                                            --
-----------------------------------------------------
for name: string, sign: number in typeSigns :: { [string]: number } do
	const node = require(`@self/types/{name}`)
	signMap[sign] = node
	types[name] = node
end

-----------------------------------------------------
-- API					                           --
-----------------------------------------------------
--[[
	Combines 2 tables together (shallow copy)
	@param t1 – the first table
	@param t2 – the second table
	@returns t3 – a new table that contains data of both tables
]]
const function combine<T1, T2>(t1: T1, t2: T2): T1 & T2
	const firstArgType: string = type(t1)
	const secondArgType: string = type(t2)
	if firstArgType ~= "table" then
		failFn(`[VoidSentry2]: Table combining failed – Invalid argument #1, "table" expected, got {firstArgType}`)
		return
	elseif secondArgType ~= "table" then
		failFn(`[VoidSentry2]: Table combining failed – Invalid argument #2, "table" expected, got {secondArgType}`)
		return
	end
	const t3: T1 & T2 = {}
	for key, value in t1 do
		t3[key] = value
	end
	for key, value in t2 do
		t3[key] = value
	end
	return t3
end

--[[
	Registers classname schema & sign in @instanceSchemas and @serInstanceSigns
	@param className – the instance class name to register
	@param schema – the class schema
	@returns ()
]]
const function registerInstanceSchema(className: string, schema: { [string]: typeNode }): ()
	const firstArgType: string = type(className)
	const secondArgType: string = type(schema)
	if firstArgType ~= "string" then
		failFn(
			`[VoidSentry2]: Serialized instance schema registering failed – Invalid argument #1, "string" expected, got {firstArgType}`
		)
		return
	elseif secondArgType ~= "table" then
		failFn(
			`[VoidSentry2]: Serialized instance schema registering failed – Invalid argument #2, "table" expected, got {secondArgType}`
		)
		return
	end

	instanceSchemas[className] = schema
	const idx: number = #serInstanceSigns.signLookup + 1
	serInstanceSigns.signLookup[idx] = className
	serInstanceSigns.nameLookup[className] = idx
end

-----------------------------------------------------
-- MODULE                                          --
-----------------------------------------------------
const VoidSentry2 = {
	types = types,
	static = static,
	dynamic = dynamic,
	registerInstanceSchema = registerInstanceSchema,
	combine = combine,
}

return VoidSentry2 :: voidSentry2
