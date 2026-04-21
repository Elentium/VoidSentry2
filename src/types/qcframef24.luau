--!strict
--!optimize 2
--[[
    Quaternion CFrame
	21 bytes
    a tiny bit less precise than matrix cframe but less bandwidth

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
const WRITE_QCF: (CFrame) -> () = writer.QCF24
const READ_QCF: () -> (number, CFrame?) = reader.QCF24
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function qcframef24_write(value: CFrame): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize QCFrameF24 type – "CFrame" expected, got "{vType}"`, 0)
		return FAIL
	end
	if not NEED(21) then
		return FAIL
	end
	WRITE_QCF(value)

	return SUCCESS
end

return table.freeze({
	write = qcframef24_write,
	read = READ_QCF,
	exType = "CFrame"
})
