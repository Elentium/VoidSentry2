--!strict
--!optimize 2
--[[
	vector2
	roblox Vector2 type
	6 bytes
	each axis is serialized as float24
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
const WRITE_V2: (Vector2) -> () = writer.V2F24
const READ_V2: () -> (number, Vector2?) = reader.V2F24
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function vector2f24_write(value: Vector2): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize Vector2F24 type – "Vector2" expected, got "{vType}"`, 0)
		return FAIL
	end
	if not NEED(6) then
		return FAIL
	end
	WRITE_V2(value)
	return SUCCESS
end

return table.freeze({
	write = vector2f24_write,
	read = READ_V2,
	exType = "Vector2"
})
