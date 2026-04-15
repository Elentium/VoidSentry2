--!strict
--!optimize 2
--[[
    Full precision CFrame(matrix) 
	- 48 bytes

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
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function cframe_write(value: CFrame): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize CFrame type – "CFrame" expected, got "{vType}"`)
		return FAIL
	end
	if not NEED(48) then
		return FAIL
	end
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
		value:GetComponents()

	WRITE(x)
	WRITE(y)
	WRITE(z)
	WRITE(R0)
	WRITE(R01)
	WRITE(R02)
	WRITE(R10)
	WRITE(R11)
	WRITE(R12)
	WRITE(R20)
	WRITE(R21)
	WRITE(R22)

	return SUCCESS
end

@native
const function cframe_read(): (number, CFrame?)
	local x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number
	local flag: number
	flag, x = READ()
	flag, y = READ()
	flag, z = READ()
	flag, R0 = READ()
	flag, R01 = READ()
	flag, R02 = READ()
	flag, R10 = READ()
	flag, R11 = READ()
	flag, R12 = READ()
	flag, R20 = READ()
	flag, R21 = READ()
	flag, R22 = READ()
	-- doing 1 check per read is redundant for most cases, as most writes are valid,
	-- unless it's networker and exploiter spams invalid buffers, 1 check per read is worse for performance
	if flag == FAIL then
		return FAIL, nil
	end

	return flag,
		NEW(
			x :: number,
			y :: number,
			z :: number,
			R0 :: number,
			R01 :: number,
			R02 :: number,
			R10 :: number,
			R11 :: number,
			R12 :: number,
			R20 :: number,
			R21 :: number,
			R22 :: number
		)
end

return table.freeze({
	write = cframe_write,
	read = cframe_read,
})