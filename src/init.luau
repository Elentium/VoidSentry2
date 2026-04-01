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
	  VoidSentry.types    -- named type nodes/factories; pass as schema arguments
	  VoidSentry.static   -- schema-based serializer; fastest, layout known upfront
	  VoidSentry.dynamic  -- schemaless serializer; tags each value at runtime

	  static.new(compressionLevel: number?, ...schema) -> serializer
	    :serialize(offset: number?, ...values)   -> buffer?
	    :deserialize(offset: number?, buf: buffer)       -> ...values?

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
	    array(T)          2+n*T    ordered list; max 65535 elements
	    array255(T)       1+n*T    ordered list; max 255 elements
	    map(K,V)          2+n*(K+V)  uint16 n, then n (key,value) pairs; K,V sized per entry if fixed
	    map255(K,V)       1+n*(K+V)  uint8 n; max 255 pairs; same layout

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
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local exports = require("@self/shared/exports")
local static = require("@self/serializers/static")
local dynamic = require("@self/serializers/dynamic")
local typeSigns = require("@self/shared/config/typeSigns")
local instanceSchemas = require("@self/shared/config/instanceSchemas")
local typesModule = require("@self/types")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
export type staticSerializer = exports.staticSerializer
export type staticObject<T... = ()> = exports.staticObject
export type dynamicSerializer = exports.dynamicSerializer
export type types = exports.types
export type voidSentry = exports.voidSentry
type possibleNode = exports.possibleNode
type typeNode = exports.typeNode

-----------------------------------------------------
-- VARIABLES                                       --
-----------------------------------------------------
local signMap = typesModule.signMap
local types = typesModule.types :: { [string]: any }

-----------------------------------------------------
-- INIT                                            --
-----------------------------------------------------
for name: string, sign: number in typeSigns :: { [string]: number } do
	local node = require(`@self/types/{name}`)
	signMap[sign] = node
	types[name] = node
end

-----------------------------------------------------
-- SER INSTANCE SCHEMAS                            --
-----------------------------------------------------
instanceSchemas.Part = {
	Name = types.string,
	Transparency = types.float32,
	CFrame = types.cframe,
	Color = types.color3,
	Anchored = types.boolean,
	Reflectance = types.float32,
}
-----------------------------------------------------
-- MODULE                                          --
-----------------------------------------------------
local VoidSentry = {
	types = typesModule.types,
	static = static,
	dynamic = dynamic,
}

return VoidSentry :: voidSentry
