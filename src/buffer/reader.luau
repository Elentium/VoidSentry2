--!strict
--[[
    BufferReader V0.1.0

	Middleware for deserializing the current buffer
	manages overflow handling, offset pointer(cursor), extra types(float16, float24, uint24, int24)
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local config = require("../shared/config")
-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
local SUCCESS = config.success
local FAIL = config.fail
local EOR = config.eor
-----------------------------------------------------
-- STATE                                           --
-----------------------------------------------------
local currentBuffer: buffer? = nil
local cursor: number = 0
local len: number = 0

-----------------------------------------------------
-- LOCALIZE BUILTINS                               --
-----------------------------------------------------
local READ_U8 = buffer.readu8
local READ_I8 = buffer.readi8
local READ_U16 = buffer.readu16
local READ_I16 = buffer.readi16
local READ_U32 = buffer.readu32
local READ_I32 = buffer.readi32
local READ_F32 = buffer.readf32
local READ_F64 = buffer.readf64
local READ_STRING = buffer.readstring
local LEN = buffer.len

local LDEXP = math.ldexp

local AND = bit32.band
local OR = bit32.bor
local LSHIFT = bit32.lshift
local EXTRACT = bit32.extract

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
--[[
    Initializes the variables for the reader operations
]]
@native
local function start(b: buffer, offset: number?): ()
	currentBuffer = b
	cursor = offset or 0
	len = LEN(b)
end

--[[
    Removes the buffer reference to GC the buffer
]]
local finish = function(): ()
	currentBuffer = nil -- clear the reference to GC the buffer
	-- zeroing cursor/len is unnecessary as it is just extra instructions which give no benefits
end

--[[
    UInt8 read operation
]]
@native
local function readu8(): (number, number?)
	if cursor + 1 > len then
		return FAIL, nil
	end

	local value: number = READ_U8(currentBuffer :: buffer, cursor)
	cursor += 1
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Int8 read operation
]]
@native
local function readi8(): (number, number?)
	if cursor + 1 > len then
		return FAIL, nil
	end

	local value: number = READ_I8(currentBuffer :: buffer, cursor)
	cursor += 1
	return cursor == len and EOR or SUCCESS, value
end

--[[
    UInt16 read operation
]]
@native
local function readu16(): (number, number?)
	if cursor + 2 > len then
		return FAIL, nil
	end

	local value: number = READ_U16(currentBuffer :: buffer, cursor)
	cursor += 2
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Int16 read operation
]]
@native
local function readi16(): (number, number?)
	if cursor + 2 > len then
		return FAIL, nil
	end

	local value: number = READ_I16(currentBuffer :: buffer, cursor)
	cursor += 2
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Float16 read operation
    Unpacks 1s|5e(bias15)|10m.
    Special values: ±Inf and NaN are preserved.
]]
@native
local function readf16(): (number, number?)
	if cursor + 2 > len then
		return FAIL, nil
	end
	local packed: number = READ_U16(currentBuffer :: buffer, cursor)
	cursor += 2

	local sign: number = EXTRACT(packed, 15, 1)
	local exp16: number = EXTRACT(packed, 10, 5)
	local mant10: number = EXTRACT(packed, 0, 10)

	local result: number
	if exp16 == 0x1F then
		result = if mant10 ~= 0 then 0 / 0 else math.huge
	elseif exp16 == 0 then
		result = 0
	else
		-- Normal: (1 + mant10/1024) * 2^(exp16 - 15)
		result = LDEXP(1 + mant10 / 1024, exp16 - 15)
	end

	if sign == 1 then
		result = -result
	end

	return cursor == len and EOR or SUCCESS, result
end

--[[
    UInt24 read operation
]]
@native
local function readu24(): (number, number?)
	if cursor + 3 > len then
		return FAIL, nil
	end

	local low: number = READ_U16(currentBuffer :: buffer, cursor)
	local high: number = READ_U8(currentBuffer :: buffer, cursor + 2)
	cursor += 3
	return cursor == len and EOR or SUCCESS, OR(low, LSHIFT(high, 16))
end

--[[
    Int24 read operation
]]
@native
local function readi24(): (number, number?)
	if cursor + 3 > len then
		return FAIL, nil
	end

	local low: number = READ_U16(currentBuffer :: buffer, cursor)
	local high: number = READ_U8(currentBuffer :: buffer, cursor + 2)
	cursor += 3

	local value: number = OR(low, LSHIFT(high, 16))
	-- bit32.arshift returns an unsigned 32-bit number; manually sign-extend to 24-bit.
	if value >= 0x800000 then
		value -= 0x1000000
	end
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Float24 read operation
    Unpacks 16m | (1s | 7e(bias63)).
    Special values: ±Inf and NaN are preserved (exp24=0x7F).
]]
@native
local function readf24(): (number, number?)
	if cursor + 3 > len then
		return FAIL, nil
	end
	local mant16: number = READ_U16(currentBuffer :: buffer, cursor)
	local byte2: number = READ_U8(currentBuffer :: buffer, cursor + 2)
	cursor += 3

	local sign: number = EXTRACT(byte2, 7, 1)
	local exp24: number = AND(byte2, 0x7F)

	local result: number
	if exp24 == 0x7F then
		result = if mant16 ~= 0 then 0 / 0 else math.huge
	elseif exp24 == 0 then
		result = 0
	else
		-- Normal: (1 + mant16/65536) * 2^(exp24 - 63)
		result = LDEXP(1 + mant16 / 65536, exp24 - 63)
	end

	if sign == 1 then
		result = -result
	end

	return cursor == len and EOR or SUCCESS, result
end

--[[
    UInt32 read operation
]]
@native
local function readu32(): (number, number?)
	if cursor + 4 > len then
		return FAIL, nil
	end

	local value: number = READ_U32(currentBuffer :: buffer, cursor)
	cursor += 4
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Int32 read operation
]]
@native
local function readi32(): (number, number?)
	if cursor + 4 > len then
		return FAIL, nil
	end

	local value: number = READ_I32(currentBuffer :: buffer, cursor)
	cursor += 4
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Float32 read operation
]]
@native
local function readf32(): (number, number?)
	if cursor + 4 > len then
		return FAIL, nil
	end

	local value: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Float64 read operation
]]
@native
local function readf64(): (number, number?)
	if cursor + 8 > len then
		return FAIL, nil
	end

	local value: number = READ_F64(currentBuffer :: buffer, cursor)
	cursor += 8
	return cursor == len and EOR or SUCCESS, value
end

--[[
    String255 read operation
]]
@native
local function reads255(): (number, string?)
	if cursor >= len then
		return FAIL, nil
	end
	local strlen: number = READ_U8(currentBuffer :: buffer, cursor)
	cursor += 1
	if cursor + strlen > len then
		return FAIL, nil
	end

	local value: string = READ_STRING(currentBuffer :: buffer, cursor, strlen)
	cursor += strlen
	return cursor == len and EOR or SUCCESS, value
end

--[[
    String65535 read operation
]]
@native
local function reads65(): (number, string?)
	if cursor + 2 > len then
		return FAIL, nil
	end
	local strlen: number = READ_U16(currentBuffer :: buffer, cursor)
	cursor += 2
	if cursor + strlen > len then
		return FAIL, nil
	end

	local value: string = READ_STRING(currentBuffer :: buffer, cursor, strlen)
	cursor += strlen
	return cursor == len and EOR or SUCCESS, value
end

return {
	U8 = readu8,
	I8 = readi8,
	U16 = readu16,
	I16 = readi16,
	F16 = readf16,
	U24 = readu24,
	I24 = readi24,
	F24 = readf24,
	U32 = readu32,
	I32 = readi32,
	F32 = readf32,
	F64 = readf64,
	STR_S = reads255,
	STR = reads65,

	START = start,
	FINISH = finish,
}
