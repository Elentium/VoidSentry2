--!strict
--[[
	vector
	luau primitive vector type
	12 bytes
	each axis is serialized as float32
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local config = require("../shared/config")
local writer = require("../buffer/writer")
local reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
local SUCCESS: number = config.success
local FAIL: number = config.fail

local VAL_TYPE: string = "vector"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
local TYPE = type
local NEED = writer.NEED
local WRITE = writer.F32
local READ = reader.F32

local NEW = vector.create

return {
	write = @native function(value: vector): number
		if TYPE(value) ~= VAL_TYPE then
			return FAIL
		end
		if not NEED(12) then
			return FAIL
		end
		WRITE(value.x)
		WRITE(value.y)
		WRITE(value.z)
		return SUCCESS
	end,

	read = @native function(): (number, vector?)
		local flag: number, x: number?, y: number?, z: number?

		flag, x = READ()
		flag, y = READ()
		flag, z = READ()
		if flag == FAIL then
			return FAIL, nil
		end

		return flag, NEW(x :: number, y :: number, z :: number)
	end,
}
