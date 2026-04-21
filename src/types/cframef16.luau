--!strict
--!optimize 2
--[[
    CFrame(matrix)
	24 bytes

	each component is serialized as float16
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
const WRITE_CF: (CFrame) -> () = writer.CF16
const READ_CF: () -> (number, CFrame?) = reader.CF16
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function cframef16_write(value: CFrame): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize CFrame type – "CFrame" expected, got "{vType}"`, 0)
		return FAIL
	end
	if not NEED(24) then
		return FAIL
	end
	WRITE_CF(value)

	return SUCCESS
end

return table.freeze({
	write = cframef16_write,
	read = READ_CF,
	exType = "CFrame",
})
