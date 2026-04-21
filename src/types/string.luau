--!strict
--!optimize 2
--[[
	string
	2 + strlen bytes

	max amount of 65535 characters
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

const VAL_TYPE: string = "string"

const LEN_LIMIT: number = 0xFFFF

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const NEED: (number) -> boolean = writer.NEED
const WRITE: (string, number) -> () = writer.STR
const READ: () -> (number, string?) = reader.STR
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function string_write(value: string): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize String type – "string" expected, got "{vType}"`, 0)
		return FAIL
	end

	const len: number = #value
	if len > LEN_LIMIT then
		FAIL_FN(
			`[VoidSentry2]: Failed to serialize String type – String max length is 65535, input value length is {len}`,
			0
		)
		return FAIL
	end
	if not NEED(2 + len) then
		return FAIL
	end
	WRITE(value, len)
	return SUCCESS
end

return table.freeze({
	write = string_write,
	read = READ, -- avoid possible extra function call
	exType = "string"
})
