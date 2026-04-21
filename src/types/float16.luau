--!strict
--[[
	Float16
	2 bytes

	IEEE 754 half precision float
]]
--!optimize 2
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
const WRITE: (number) -> () = writer.F16
const READ: () -> (number, number?) = reader.F16
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function float16_write(value: number): number
	const vType: string = TYPE(value)
	if vType ~= NUM_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize Float16 type – "number" expected, got "{vType}"`, 0)
		return FAIL
	end
	if not NEED(2) then
		return FAIL
	end
	WRITE(value)
	return SUCCESS
end

return table.freeze({
	write = float16_write,
	read = READ, -- avoid possible extra function call
	exType = "float"
})
