--!strict
--!optimize 2
--[[
	Signed 8-bit integer
	1 byte
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const SUCCESS: number = config.success
const FAIL: number = config.fail

const NUM_TYPE: string = "number"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const NEED: (number) -> boolean = writer.NEED
const WRITE: (number) -> () = writer.I8
const READ: () -> (number, number?) = reader.I8
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function int8_write(value: number): number
	const vType: string = TYPE(value)
	if vType ~= NUM_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize Int8 type – "number" expected, got "{vType}"`, 0)
		return FAIL
	end
	if not NEED(1) then
		return FAIL
	end
	WRITE(value)
	return SUCCESS
end

return table.freeze({
	write = int8_write,
	read = READ, -- avoid possible extra function call
	exType = "int"
})
