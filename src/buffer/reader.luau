--!strict
--!optimize 2
--[[
    BufferReader V0.1.0

	Middleware for deserializing the current buffer
	manages overflow handling, offset pointer(cursor), extra types(float16, float24, uint24, int24)
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const SUCCESS: number = config.success
const FAIL: number = config.fail
const EOR: number = config.eor
-----------------------------------------------------
-- STATE                                           --
-----------------------------------------------------
local currentBuffer: buffer? = nil
local cursor: number = 0
local len: number = 0

-----------------------------------------------------
-- LOCALIZE BUILTINS                               --
-----------------------------------------------------
const READ_U8: (buffer, number) -> number = buffer.readu8
const READ_I8: (buffer, number) -> number = buffer.readi8
const READ_U16: (buffer, number) -> number = buffer.readu16
const READ_I16: (buffer, number) -> number = buffer.readi16
const READ_U32: (buffer, number) -> number = buffer.readu32
const READ_I32: (buffer, number) -> number = buffer.readi32
const READ_F32: (buffer, number) -> number = buffer.readf32
const READ_F64: (buffer, number) -> number = buffer.readf64
const READ_STRING: (buffer, number, number) -> string = buffer.readstring
const LEN: (buffer) -> number = buffer.len

const LDEXP: (number, number) -> number = math.ldexp

const AND: (...number) -> number = bit32.band
const OR: (...number) -> number = bit32.bor
const LSHIFT: (number, number) -> number = bit32.lshift
const EXTRACT: (number, number, number?) -> number = bit32.extract

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
--[[
    Initializes the variables for the reader operations
]]
@native
const function start(b: buffer, offset: number?): ()
	currentBuffer = b
	cursor = offset or 0
	len = LEN(b)
end

--[[
    Removes the buffer reference to GC the buffer
]]
@native
const function finish(): ()
	currentBuffer = nil -- clear the reference to GC the buffer
	-- zeroing cursor/len is unnecessary as it is just extra instructions which give no benefits
end

--[[
    UInt8 read operation
]]
@native
const function readu8(): (number, number?)
	if cursor + 1 > len then
		return FAIL, nil
	end

	const value: number = READ_U8(currentBuffer :: buffer, cursor)
	cursor += 1
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Int8 read operation
]]
@native
const function readi8(): (number, number?)
	if cursor + 1 > len then
		return FAIL, nil
	end

	const value: number = READ_I8(currentBuffer :: buffer, cursor)
	cursor += 1
	return cursor == len and EOR or SUCCESS, value
end

--[[
    UInt16 read operation
]]
@native
const function readu16(): (number, number?)
	if cursor + 2 > len then
		return FAIL, nil
	end

	const value: number = READ_U16(currentBuffer :: buffer, cursor)
	cursor += 2
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Int16 read operation
]]
@native
const function readi16(): (number, number?)
	if cursor + 2 > len then
		return FAIL, nil
	end

	const value: number = READ_I16(currentBuffer :: buffer, cursor)
	cursor += 2
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Float16 read operation
    Unpacks 1s|5e(bias15)|10m.
    Special values: ±Inf and NaN are preserved.
]]
@native
const function readf16(): (number, number?)
	if cursor + 2 > len then
		return FAIL, nil
	end
	const packed: number = READ_U16(currentBuffer :: buffer, cursor)
	cursor += 2

	const sign: number = EXTRACT(packed, 15, 1)
	const exp16: number = EXTRACT(packed, 10, 5)
	const mant10: number = EXTRACT(packed, 0, 10)

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
const function readu24(): (number, number?)
	if cursor + 3 > len then
		return FAIL, nil
	end

	const low: number = READ_U16(currentBuffer :: buffer, cursor)
	const high: number = READ_U8(currentBuffer :: buffer, cursor + 2)
	cursor += 3
	return cursor == len and EOR or SUCCESS, OR(low, LSHIFT(high, 16))
end

--[[
    Int24 read operation
]]
@native
const function readi24(): (number, number?)
	if cursor + 3 > len then
		return FAIL, nil
	end

	const low: number = READ_U16(currentBuffer :: buffer, cursor)
	const high: number = READ_U8(currentBuffer :: buffer, cursor + 2)
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
const function readf24(): (number, number?)
	if cursor + 3 > len then
		return FAIL, nil
	end
	const mant16: number = READ_U16(currentBuffer :: buffer, cursor)
	const byte2: number = READ_U8(currentBuffer :: buffer, cursor + 2)
	cursor += 3

	const sign: number = EXTRACT(byte2, 7, 1)
	const exp24: number = AND(byte2, 0x7F)

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
const function readu32(): (number, number?)
	if cursor + 4 > len then
		return FAIL, nil
	end

	const value: number = READ_U32(currentBuffer :: buffer, cursor)
	cursor += 4
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Int32 read operation
]]
@native
const function readi32(): (number, number?)
	if cursor + 4 > len then
		return FAIL, nil
	end

	const value: number = READ_I32(currentBuffer :: buffer, cursor)
	cursor += 4
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Float32 read operation
]]
@native
const function readf32(): (number, number?)
	if cursor + 4 > len then
		return FAIL, nil
	end

	const value: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	return cursor == len and EOR or SUCCESS, value
end

--[[
    Float64 read operation
]]
@native
const function readf64(): (number, number?)
	if cursor + 8 > len then
		return FAIL, nil
	end

	const value: number = READ_F64(currentBuffer :: buffer, cursor)
	cursor += 8
	return cursor == len and EOR or SUCCESS, value
end

--[[
    String255 read operation
]]
@native
const function reads255(): (number, string?)
	if cursor >= len then
		return FAIL, nil
	end
	const strlen: number = READ_U8(currentBuffer :: buffer, cursor)
	cursor += 1
	if cursor + strlen > len then
		return FAIL, nil
	end

	const value: string = READ_STRING(currentBuffer :: buffer, cursor, strlen)
	cursor += strlen
	return cursor == len and EOR or SUCCESS, value
end

--[[
    String65535 read operation
]]
@native
const function reads65(): (number, string?)
	if cursor + 2 > len then
		return FAIL, nil
	end
	const strlen: number = READ_U16(currentBuffer :: buffer, cursor)
	cursor += 2
	if cursor + strlen > len then
		return FAIL, nil
	end

	const value: string = READ_STRING(currentBuffer :: buffer, cursor, strlen)
	cursor += strlen
	return cursor == len and EOR or SUCCESS, value
end

return table.freeze({
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
})