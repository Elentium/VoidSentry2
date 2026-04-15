--!strict
--[[
	Float24
	3 bytes

	Custom precision float
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
const WRITE: (number) -> () = writer.F24
const READ: () -> (number, number?) = reader.F24
const FAIL_FN = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function float24_write(value: number): number
	const vType: string = TYPE(value)
	if vType ~= NUM_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize Float24 type – "number" expected, got "{vType}"`)
		return FAIL
	end
	if not NEED(3) then
		return FAIL
	end
	WRITE(value)
	return SUCCESS
end

return table.freeze({
	write = float24_write,
	read = READ, -- avoid possible extra function call
})
