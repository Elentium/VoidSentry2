--[[
	InferValueType V0.1.0

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
	- color3
	- instance
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local config = require("./config")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
local UNKNOWN: number = config.unknownType
local typeSigns = config.typeSigns
local VECTOR: number = config.dynamicVectorType == "Vector3" and typeSigns.vector3 or typeSigns.vector
local INT32: number = typeSigns.int32
local INT16: number = typeSigns.int16
local INT8: number = typeSigns.int8
local UINT32: number = typeSigns.uint32
local UINT16: number = typeSigns.uint16
local UINT8: number = typeSigns.uint8
local FLOAT: number = typeSigns.float32
local BOOL: number = typeSigns.boolean
local STR: number = typeSigns.string
local STR255: number = typeSigns.string255
local VOID: number = typeSigns.void
local ARRAY: number = typeSigns.array
local MAP: number = typeSigns.map
local ARRAY255: number = typeSigns.array255
local CFRAME: number = typeSigns.cframe
local VECTOR2: number = typeSigns.vector2
local COLOR3: number = typeSigns.color3
local INSTANCE: number = config.dynamicInstanceType == "instance" and typeSigns.instance or typeSigns.serInstance
-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
local TYPE = typeof

@native
local function inferValueType(element: any): number
	local type = TYPE(element)

	if type == "number" then
		local isInteger: boolean = element // 1 == element
		if isInteger then
			if element >= 0 then
				-- unsigned Logic
				if element <= 0xFF then
					return UINT8
				elseif element <= 0xFFFF then
					return UINT16
				elseif element <= 0xFFFFFFFF then
					return UINT32
				end
			else
				-- signed Logic
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
	elseif type == "boolean" then
		return BOOL
	elseif type == "string" then
		return #element <= 255 and STR255 or STR
	elseif type == "table" then
		local len: number = #element
		-- empty table or a map
		if len == 0 then
			return next(element) == nil and VOID or MAP
		end

		local isMap: boolean = next(element, #element) ~= nil
		return if isMap then MAP else len <= 255 and ARRAY255 or ARRAY
	elseif type == "Vector3" then
		return VECTOR
	elseif type == "Vector2" then
		return VECTOR2
	elseif type == "CFrame" then
		return CFRAME
	elseif type == "Color3" then
		return COLOR3
	elseif type == "Instance" then
		return INSTANCE
	end

	return UNKNOWN
end

return inferValueType
