--!strict
--!optimize 2
--[[
    Quaternion CFrame
	- 28 bytes
    a tiny bit less precise than matrix cframe but less bandwidth

    each component is serialized as float32
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")
const math = require("../shared/math")

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
const WRITE: (number) -> () = writer.F32
const READ: () -> (number, number?) = reader.F32
const NEW: (() -> CFrame) & ((Vector3) -> CFrame) & ((Vector3, Vector3) -> CFrame) & ((number, number, number) -> CFrame) & ((number, number, number, number, number, number, number) -> CFrame) & ((
	number,
	number,
	number,
	number,
	number,
	number,
	number,
	number,
	number,
	number,
	number,
	number
) -> CFrame) =
	CFrame.new
const TOQUATER: (CFrame) -> (number, number, number, number) = math.toQuaternion
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function qcframe_write(value: CFrame): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize QCFrame type – "CFrame" expected, got "{vType}"`)
		return FAIL
	end
	if not NEED(28) then
		return FAIL
	end
	const x: number, y: number, z: number = value.X, value.Y, value.Z
	const qx: number, qy: number, qz: number, qw: number = TOQUATER(value)

	WRITE(x)
	WRITE(y)
	WRITE(z)
	WRITE(qx)
	WRITE(qy)
	WRITE(qz)
	WRITE(qw)

	return SUCCESS
end

@native
const function qcframe_read(): (number, CFrame?)
	local x: number, y: number, z: number, qx: number, qy: number, qz: number, qw: number
	local flag: number
	flag, x = READ()
	flag, y = READ()
	flag, z = READ()
	flag, qx = READ()
	flag, qy = READ()
	flag, qz = READ()
	flag, qw = READ()
	-- doing 1 check per read is redundant for most cases, as most writes are valid,
	-- unless it's networker and exploiter spams invalid buffers, 1 check per read is worse for performance
	if flag == FAIL then
		return FAIL, nil
	end

	return flag, NEW(x :: number, y :: number, z :: number, qx :: number, qy :: number, qz :: number, qw :: number)
end

return table.freeze({
	write = qcframe_write,
	read = qcframe_read,
})
