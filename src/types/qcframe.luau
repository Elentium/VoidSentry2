--!strict
--!optimize 2
--[[
    Quaternion CFrame
	28 bytes
    a tiny bit less precise than matrix cframe but less bandwidth

    each component is serialized as float32
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
const WRITE_QCF: (CFrame) -> () = writer.QCF32
const READ_QCF: () -> (number, CFrame?) = reader.QCF32
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function qcframe_write(value: CFrame): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize QCFrame type – "CFrame" expected, got "{vType}"`, 0)
		return FAIL
	end
	if not NEED(28) then
		return FAIL
	end
	WRITE_QCF(value)

	return SUCCESS
end

return table.freeze({
	write = qcframe_write,
	read = READ_QCF,
	exType = "CFrame"
})
