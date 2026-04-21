--!strict
--!optimize 2
--[[
    CFrame(matrix) 
	36 bytes

	each component is serialized as float24
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

const VAL_TYPE: string = "CFrame"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = typeof
const NEED: (number) -> boolean = writer.NEED
const WRITE_CF: (CFrame) -> () = writer.CF24
const READ_CF: () -> (number, CFrame?) = reader.CF24
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function cframef24_write(value: CFrame): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize CFrame type – "CFrame" expected, got "{vType}"`, 0)
		return FAIL
	end
	if not NEED(36) then
		return FAIL
	end
	WRITE_CF(value)

	return SUCCESS
end

return table.freeze({
	write = cframef24_write,
	read = READ_CF,
	exType = "CFrame"
})
