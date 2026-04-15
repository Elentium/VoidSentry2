--!strict
--!optimize 2
--[[
	BufferWriter V0.1.0

	Serializes into one reusable big buffer (config.maxBufferSize).
	START sets the write cursor (with optional offset for metadata/headers)
	FINISH allocates a buffer of length `cursor` and copies bigBuffer [0, cursor).

	Type nodes are responsible for calling NEED(n) once before writing their fields.
	The primitive write functions themselves do no bounds checking.
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")

-----------------------------------------------------
-- LOCALIZE BUILTINS                               --
-----------------------------------------------------
const CREATE: (number) -> buffer = buffer.create
const COPY: (buffer, number, buffer, number?, number?) -> () = buffer.copy

const WRITE_U8: (buffer, number, number) -> () = buffer.writeu8
const WRITE_I8: (buffer, number, number) -> () = buffer.writei8
const WRITE_U16: (buffer, number, number) -> () = buffer.writeu16
const WRITE_I16: (buffer, number, number) -> () = buffer.writei16
const WRITE_U32: (buffer, number, number) -> () = buffer.writeu32
const WRITE_I32: (buffer, number, number) -> () = buffer.writei32
const WRITE_F32: (buffer, number, number) -> () = buffer.writef32
const WRITE_F64: (buffer, number, number) -> () = buffer.writef64
const WRITE_STRING: (buffer, number, string, number?) -> () = buffer.writestring

const ABS: (number) -> number = math.abs
const FREXP: (number) -> (number, number) = math.frexp

const AND: (...number) -> number = bit32.band
const OR: (...number) -> number = bit32.bor
const EXTRACT: (number, number, number?) -> number = bit32.extract
const LSHIFT: (number, number) -> number = bit32.lshift

const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

const HUGE: number = math.huge
const NHUGE: number = -HUGE

-----------------------------------------------------
-- STATE                    			           --
-----------------------------------------------------
const bigCap: number = config.maxBufferSize
const bigBuffer: buffer = CREATE(bigCap)

local cursor: number = 0
local off: number = 0

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
@native
const function need(size: number): boolean
	if cursor + size > bigCap then
		FAIL_FN(
			`[VoidSentry2]: writer.need throw – need {size} byte(s) at cursor {cursor} but bigBuffer ends at {bigCap} (config.maxBufferSize)`
		)
		return false
	end
	return true
end

@native
const function start(offset: number?)
	cursor = offset or 0
	off = cursor
	if cursor > bigCap then
		FAIL_FN(`VoidSentry2 writer: offset {cursor} exceeds bigBuffer size {bigCap}`)
		cursor = bigCap + 1 -- poison; every subsequent need() call will fail.
	end
end

@native
const function finish(): buffer
	const b: buffer = CREATE(cursor)
	if cursor > 0 then
		-- ensure the offset bytes are all zeroed
		-- if previous operation(s) had no offset – the first bytes have previous data
		COPY(b, off, bigBuffer, off, cursor - off)
	end
	return b
end

-----------------------------------------------------
-- PRIMITIVE WRITES                                --
-----------------------------------------------------
@native
const function writeu8(value: number): ()
	WRITE_U8(bigBuffer, cursor, value)
	cursor += 1
end

@native
const function writei8(value: number): ()
	WRITE_I8(bigBuffer, cursor, value)
	cursor += 1
end

@native
const function writeu16(value: number): ()
	WRITE_U16(bigBuffer, cursor, value)
	cursor += 2
end

@native
const function writei16(value: number): ()
	WRITE_I16(bigBuffer, cursor, value)
	cursor += 2
end

--[[
	Float16 write operation: 1s | 5e(bias15) | 10m
	Special values: ±Inf stored as exp=0x1F mant=0; NaN as exp=0x1F mant=0x200.
]]
@native
const function writef16(value: number): ()
	local packed: number
	if value ~= value then
		packed = 0x7E00
	elseif value == HUGE then
		packed = 0x7C00
	elseif value == NHUGE then
		packed = 0xFC00
	elseif value == 0 then
		packed = 0
	else
		const sign: number = if value < 0 then 1 else 0
		const m: number, e: number = FREXP(ABS(value))
		const biasedExp: number = e + 14
		if biasedExp >= 0x1F then
			packed = OR(LSHIFT(sign, 15), 0x7C00)
		elseif biasedExp <= 0 then
			packed = LSHIFT(sign, 15)
		else
			const mant10: number = ((m * 2 - 1) * 1024 + 0.5) // 1
			packed = OR(LSHIFT(sign, 15), LSHIFT(biasedExp, 10), AND(mant10, 0x3FF))
		end
	end
	WRITE_U16(bigBuffer, cursor, packed)
	cursor += 2
end

@native
const function writeu24(value: number): ()
	WRITE_U16(bigBuffer, cursor, AND(value, 0xFFFF))
	WRITE_U8(bigBuffer, cursor + 2, EXTRACT(value, 16, 8))
	cursor += 3
end

--[[
	Float24 write operation: 1s | 7e(bias63) | 16m
	Layout in buffer: [lo16 of mantissa] [sign(1) | exp(7)]
]]
@native
const function writef24(value: number): ()
	local mant16: number
	local byte2: number
	if value ~= value then
		mant16 = 0x8000
		byte2 = 0x7F
	elseif value == HUGE then
		mant16 = 0
		byte2 = 0x7F
	elseif value == NHUGE then
		mant16 = 0
		byte2 = 0xFF
	elseif value == 0 then
		mant16 = 0
		byte2 = 0
	else
		const sign: number = if value < 0 then 1 else 0
		const m: number, e: number = FREXP(ABS(value))
		const biasedExp: number = e + 62
		if biasedExp >= 0x7F then
			mant16 = 0
			byte2 = OR(LSHIFT(sign, 7), 0x7F)
		elseif biasedExp <= 0 then
			mant16 = 0
			byte2 = LSHIFT(sign, 7)
		else
			const frac: number = m * 2 - 1
			mant16 = AND((frac * 65536 + 0.5) // 1, 0xFFFF)
			byte2 = OR(LSHIFT(sign, 7), biasedExp)
		end
	end
	WRITE_U16(bigBuffer, cursor, mant16)
	WRITE_U8(bigBuffer, cursor + 2, byte2)
	cursor += 3
end

@native
const function writeu32(value: number): ()
	WRITE_U32(bigBuffer, cursor, value)
	cursor += 4
end

@native
const function writei32(value: number): ()
	WRITE_I32(bigBuffer, cursor, value)
	cursor += 4
end

@native
const function writef32(value: number): ()
	WRITE_F32(bigBuffer, cursor, value)
	cursor += 4
end

@native
const function writef64(value: number): ()
	WRITE_F64(bigBuffer, cursor, value)
	cursor += 8
end

@native
const function writes255(value: string, len: number): ()
	WRITE_U8(bigBuffer, cursor, len)
	cursor += 1
	WRITE_STRING(bigBuffer, cursor, value)
	cursor += len
end

@native
const function writes65(value: string, len: number): ()
	WRITE_U16(bigBuffer, cursor, len)
	cursor += 2
	WRITE_STRING(bigBuffer, cursor, value)
	cursor += len
end

return table.freeze({
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
})
