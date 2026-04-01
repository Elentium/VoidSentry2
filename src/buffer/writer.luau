--!strict
--[[
	BufferWriter V0.1.0

	Serializes into one reusable big buffer (config.maxBufferSize).
	START only resets cursor / offset; FINISH allocates an exact-sized buffer and copies bytes [0, cursor).

	Type nodes are responsible for calling NEED(n) once before writing their fields.
	The primitive write functions themselves do no bounds checking.
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local config = require("../shared/config")

-----------------------------------------------------
-- CONSTANTS / STATE                               --
-----------------------------------------------------
local bigCap: number = config.maxBufferSize
local bigBuffer: buffer = buffer.create(bigCap)
local cursor: number = 0

-----------------------------------------------------
-- LOCALIZE BUILTINS                               --
-----------------------------------------------------
local CREATE = buffer.create
local COPY = buffer.copy

local WRITE_U8 = buffer.writeu8
local WRITE_I8 = buffer.writei8
local WRITE_U16 = buffer.writeu16
local WRITE_I16 = buffer.writei16
local WRITE_U32 = buffer.writeu32
local WRITE_I32 = buffer.writei32
local WRITE_F32 = buffer.writef32
local WRITE_F64 = buffer.writef64
local WRITE_STRING = buffer.writestring

local ABS = math.abs
local FREXP = math.frexp

local AND = bit32.band
local OR = bit32.bor
local EXTRACT = bit32.extract
local LSHIFT = bit32.lshift

-----------------------------------------------------
-- FAIL/STRICT HANDLING                            --
-----------------------------------------------------
local failFn = config.strictMode and error or warn

-----------------------------------------------------
-- NEED (called once per type node write)          --
-----------------------------------------------------
@native
local function need(size: number): boolean
	if cursor + size > bigCap then
		failFn(
			`VoidSentry2 writer: need {size} byte(s) at cursor {cursor} but bigBuffer ends at {bigCap} (config.maxBufferSize)`
		)
		return false
	end
	return true
end

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
@native
local function start(offset: number?)
	cursor = offset or 0
	if cursor > bigCap then
		failFn(`VoidSentry2 writer: offset {cursor} exceeds bigBuffer size {bigCap}`)
		cursor = bigCap + 1 -- poison; every subsequent need() call will fail.
	end
end

@native
local function finish(): buffer
	local b: buffer = CREATE(cursor)
	if cursor > 0 then
		COPY(b, 0, bigBuffer, 0, cursor)
	end
	return b
end

-----------------------------------------------------
-- PRIMITIVE WRITES                                --
-----------------------------------------------------
@native
local function writeu8(value: number): ()
	WRITE_U8(bigBuffer, cursor, value)
	cursor += 1
end

@native
local function writei8(value: number): ()
	WRITE_I8(bigBuffer, cursor, value)
	cursor += 1
end

@native
local function writeu16(value: number): ()
	WRITE_U16(bigBuffer, cursor, value)
	cursor += 2
end

@native
local function writei16(value: number): ()
	WRITE_I16(bigBuffer, cursor, value)
	cursor += 2
end

--[[
	Float16 write operation: 1s | 5e(bias15) | 10m
	Special values: ±Inf stored as exp=0x1F mant=0; NaN as exp=0x1F mant=0x200.
]]
@native
local function writef16(value: number): ()
	local packed: number
	if value ~= value then
		packed = 0x7E00
	elseif value == math.huge then
		packed = 0x7C00
	elseif value == -math.huge then
		packed = 0xFC00
	elseif value == 0 then
		packed = 0
	else
		local sign: number = if value < 0 then 1 else 0
		local m: number, e: number = FREXP(ABS(value))
		local biasedExp: number = e + 14
		if biasedExp >= 0x1F then
			packed = OR(LSHIFT(sign, 15), 0x7C00)
		elseif biasedExp <= 0 then
			packed = LSHIFT(sign, 15)
		else
			local mant10: number = (m * 2 - 1) * 1024 + 0.5
			mant10 = mant10 // 1
			packed = OR(LSHIFT(sign, 15), LSHIFT(biasedExp, 10), AND(mant10, 0x3FF))
		end
	end
	WRITE_U16(bigBuffer, cursor, packed)
	cursor += 2
end

@native
local function writeu24(value: number): ()
	WRITE_U16(bigBuffer, cursor, AND(value, 0xFFFF))
	WRITE_U8(bigBuffer, cursor + 2, EXTRACT(value, 16, 8))
	cursor += 3
end

--[[
	Float24 write operation: 1s | 7e(bias63) | 16m
	Layout in buffer: [lo16 of mantissa] [sign(1) | exp(7)]
]]
@native
local function writef24(value: number): ()
	local mant16: number
	local byte2: number
	if value ~= value then
		mant16 = 0x8000
		byte2 = 0x7F
	elseif value == math.huge then
		mant16 = 0
		byte2 = 0x7F
	elseif value == -math.huge then
		mant16 = 0
		byte2 = 0xFF
	elseif value == 0 then
		mant16 = 0
		byte2 = 0
	else
		local sign: number = if value < 0 then 1 else 0
		local m: number, e: number = FREXP(ABS(value))
		local biasedExp: number = e + 62
		if biasedExp >= 0x7F then
			mant16 = 0
			byte2 = OR(LSHIFT(sign, 7), 0x7F)
		elseif biasedExp <= 0 then
			mant16 = 0
			byte2 = LSHIFT(sign, 7)
		else
			local frac: number = m * 2 - 1
			mant16 = AND((frac * 65536 + 0.5) // 1, 0xFFFF)
			byte2 = OR(LSHIFT(sign, 7), biasedExp)
		end
	end
	WRITE_U16(bigBuffer, cursor, mant16)
	WRITE_U8(bigBuffer, cursor + 2, byte2)
	cursor += 3
end

@native
local function writeu32(value: number): ()
	WRITE_U32(bigBuffer, cursor, value)
	cursor += 4
end

@native
local function writei32(value: number): ()
	WRITE_I32(bigBuffer, cursor, value)
	cursor += 4
end

@native
local function writef32(value: number): ()
	WRITE_F32(bigBuffer, cursor, value)
	cursor += 4
end

@native
local function writef64(value: number): ()
	WRITE_F64(bigBuffer, cursor, value)
	cursor += 8
end

@native
local function writes255(value: string, len: number): ()
	WRITE_U8(bigBuffer, cursor, len)
	cursor += 1
	WRITE_STRING(bigBuffer, cursor, value)
	cursor += len
end

@native
local function writes65(value: string, len: number): ()
	WRITE_U16(bigBuffer, cursor, len)
	cursor += 2
	WRITE_STRING(bigBuffer, cursor, value)
	cursor += len
end

return {
	START = start,
	FINISH = finish,
	NEED = need,

	U8 = writeu8,
	I8 = writei8,
	U16 = writeu16,
	I16 = writei16,
	F16 = writef16,
	F24 = writef24,
	U24 = writeu24,
	I24 = writeu24, -- write process is the same, the read isn't
	U32 = writeu32,
	I32 = writei32,
	F32 = writef32,
	F64 = writef64,
	STR_S = writes255,
	STR = writes65,
}
