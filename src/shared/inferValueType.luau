--!optimize 2
--[[
	InferValueType V0.1.1

	Infers value type in a switch-like style

	supported types:
	- int8
	- int16
	- int32
	- uint8
	- uint16
	- uint32
	- float32
	- boolean
	- string
	- string255
	- array
	- array255
	- map
	- void
	- nothing
	- vector/vector3 (configurable)
	- vector2
	- cframe
	- enum
	- color3
	- instance
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("./config")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const UNKNOWN: number = config.unknownType
const typeSigns = config.typeSigns
const VECTOR: number = config.dynamicVectorType == "Vector3" and typeSigns.vector3 or typeSigns.vector
const INT32: number = typeSigns.int32
const INT16: number = typeSigns.int16
const INT8: number = typeSigns.int8
const UINT32: number = typeSigns.uint32
const UINT16: number = typeSigns.uint16
const UINT8: number = typeSigns.uint8
const FLOAT: number = typeSigns.float32
const BOOL: number = typeSigns.boolean
const STR: number = typeSigns.string
const STR255: number = typeSigns.string255
const VOID: number = typeSigns.void
const ARRAY: number = typeSigns.array
const MAP: number = typeSigns.map
const ARRAY255: number = typeSigns.array255
const CFRAME: number = typeSigns.cframe
const VECTOR2: number = typeSigns.vector2
const COLOR3: number = typeSigns.color3
const INSTANCE: number = config.dynamicInstanceType == "instance" and typeSigns.instance or typeSigns.serInstance
const ENUM: number = typeSigns.enum
-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const TYPE: <T>(T) -> string = typeof
const NEXT: <K, V>({ [K]: V }, K?) -> (K?, V) = next

@native
const function inferValueType<T>(element: T): number
	const vType: string = TYPE(element)

	if vType == "number" then
		const isInteger: boolean = element // 1 == element
		if isInteger then
			if element >= 0 then
				-- unsigned logic
				if element <= 0xFF then
					return UINT8
				elseif element <= 0xFFFF then
					return UINT16
				elseif element <= 0xFFFFFFFF then
					return UINT32
				end
			else
				-- signed logic
				if element >= -128 and element <= 127 then
					return INT8
				elseif element >= -32768 and element <= 32767 then
					return INT16
				elseif element >= -2147483648 and element <= 2147483647 then
					return INT32
				end
			end
		end

		return FLOAT
	elseif vType == "boolean" then
		return BOOL
	elseif vType == "string" then
		return #element <= 255 and STR255 or STR
	elseif vType == "table" then
		const len: number = #element
		-- empty table or a map
		if len == 0 then
			return NEXT(element) == nil and VOID or MAP
		end

		const isMap: boolean = NEXT(element, #element) ~= nil
		return if isMap then MAP else len <= 255 and ARRAY255 or ARRAY
	elseif vType == "Vector3" then
		return VECTOR
	elseif vType == "Vector2" then
		return VECTOR2
	elseif vType == "CFrame" then
		return CFRAME
	elseif vType == "Color3" then
		return COLOR3
	elseif vType == "Instance" then
		return INSTANCE
	elseif vType == "EnumItem" then
		return ENUM
	end

	return UNKNOWN
end

return inferValueType
