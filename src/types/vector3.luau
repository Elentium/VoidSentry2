--!strict
--!optimize 2
--[[
	vector3
	roblox Vector3 type
	12 bytes
	each axis is serialized as float32
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
const WRITE: (number) -> () = writer.F32
const READ: () -> (number, number?) = reader.F32

const NEW: (number?, number?, number?) -> Vector3 = Vector3.new
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function vector3_write(value: Vector3): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize Vector3 type – "vector" expected, got "{vType}"`)
		return FAIL
	end
	if not NEED(12) then
		return FAIL
	end
	WRITE(value.x)
	WRITE(value.y)
	WRITE(value.z)
	return SUCCESS
end

@native
const function vector3_read(): (number, Vector3?)
	local flag: number, x: number?, y: number?, z: number?

	flag, x = READ()
	flag, y = READ()
	flag, z = READ()
	if flag == FAIL then
		return FAIL, nil
	end

	return flag, NEW(x, y, z)
end

return table.freeze({
	write = vector3_write,
	read = vector3_read,
})
