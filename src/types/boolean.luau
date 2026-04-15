--!strict
--!optimize 2
--[[
	Boolean
	1 byte
	simple true/false value
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

const VAL_TYPE: string = "boolean"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const NEED: (number) -> boolean = writer.NEED
const WRITE: (number) -> () = writer.U8
const READ: () -> (number, number?) = reader.U8
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function boolean_write(value: boolean): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize Boolean type – "boolean" expected, got "{vType}"`)
		return FAIL
	end
	if not NEED(1) then
		return FAIL
	end
	WRITE(value and 1 or 0)
	return SUCCESS
end

@native
const function boolean_read(): (number, boolean?)
	const flag: number, value: number? = READ()
	if flag == FAIL then
		return flag, nil
	end
	return flag, value == 1
end

return table.freeze({
	write = boolean_write,
	read = boolean_read,
})