--!strict
--!optimize 2
--[[
	color3
	roblox Color3 type
	3 bytes
	each RGB field is serialized as uint8
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

const VAL_TYPE: string = "Color3"

const RECIPROCAL: number = 1 / 255

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = typeof
const NEED: (number) -> boolean = writer.NEED
const WRITE: (number) -> () = writer.U8
const READ: () -> (number, number?) = reader.U8
const NEW: (number?, number?, number?) -> Color3 = Color3.fromRGB
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function color3_write(value: Color3): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize Color3 type – "Color3" expected, got "{vType}"`)
		return FAIL
	end
	if not NEED(3) then
		return FAIL
	end
	WRITE(value.R // RECIPROCAL)
	WRITE(value.G // RECIPROCAL)
	WRITE(value.B // RECIPROCAL)
	return SUCCESS
end

@native
const function color3_read(): (number, Color3?)
	local flag: number, r: number?, g: number?, b: number?

	flag, r = READ()
	flag, g = READ()
	flag, b = READ()
	if flag == FAIL then
		return FAIL, nil
	end

	return flag, NEW(r, g, b)
end

return table.freeze({
	write = color3_write,
	read = color3_read,
})
