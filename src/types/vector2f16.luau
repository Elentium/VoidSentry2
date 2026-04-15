--!strict
--!optimize 2
--[[
	vector2
	roblox Vector2 type
	4 bytes
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

const VAL_TYPE: string = "Vector2"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = typeof
const NEED: (number) -> boolean = writer.NEED
const WRITE: (number) -> () = writer.F16
const READ: () -> (number, number?) = reader.F16
const NEW: (number?, number?) -> Vector2 = Vector2.new
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function vector2f16_write(value: Vector2): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize Vector2F16 type – "Vector2" expected, got "{vType}"`)
		return FAIL
	end
	if not NEED(4) then
		return FAIL
	end
	WRITE(value.X)
	WRITE(value.Y)
	return SUCCESS
end

@native
const function vector2f16_read(): (number, Vector2?)
	local flag: number, x: number?, y: number?

	flag, x = READ()
	flag, y = READ()
	if flag == FAIL then
		return FAIL, nil
	end

	return flag, NEW(x, y)
end

return table.freeze({
	write = vector2f16_write,
	read = vector2f16_read,
})
