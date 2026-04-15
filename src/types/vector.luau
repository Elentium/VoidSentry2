--!strict
--!optimize 2
--[[
	vector
	luau primitive vector type
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
const READ: (...any) -> (number, number?) = reader.F32
const NEW: (number, number, number?) -> vector = vector.create
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function vector_write(value: vector): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize Vector type – "vector" expected, got "{vType}"`)
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
const function vector_read(): (number, vector?)
	local flag: number, x: number?, y: number?, z: number?

	flag, x = READ()
	flag, y = READ()
	flag, z = READ()
	if flag == FAIL then
		return FAIL, nil
	end

	return flag, NEW(x :: number, y :: number, z :: number)
end

return table.freeze({
	write = vector_write,
	read = vector_read,
})
