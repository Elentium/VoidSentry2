--!strict
--!optimize 2
--[[
	vector3
	roblox Vector3 type
	6 bytes
	each axis is serialized as float16
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

const VAL_TYPE: string = "vector"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const NEED: (number) -> boolean = writer.NEED
const WRITE_VEC: (vector | Vector3) -> () = writer.VF16
const READ_VEC: () -> (number, vector?) = reader.VF16
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function vector3f16_write(value: Vector3): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize Vector3F16 type – "Vector3" expected, got "{vType}"`, 0)
		return FAIL
	end
	if not NEED(6) then
		return FAIL
	end
	WRITE_VEC(value)
	return SUCCESS
end

return table.freeze({
	write = vector3f16_write,
	read = READ_VEC,
	exType = "Vector3"
})
