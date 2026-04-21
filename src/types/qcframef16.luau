--!strict
--!optimize 2
--[[
    Quaternion CFrame
	14 bytes

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
const WRITE_QCF: (CFrame) -> () = writer.QCF16
const READ_QCF: () -> (number, CFrame?) = reader.QCF16
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function qcframef16_write(value: CFrame): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize QCFrameF16 type – "CFrame" expected, got "{vType}"`, 0)
		return FAIL
	end
	if not NEED(14) then
		return FAIL
	end
	WRITE_QCF(value)

	return SUCCESS
end

return table.freeze({
	write = qcframef16_write,
	read = READ_QCF,
	exType = "CFrame",
})
