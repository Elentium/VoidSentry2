--!strict
--[[
	vector2
	roblox Vector2 type
	8 bytes
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

local VAL_TYPE: string = "Vector2"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
local TYPE = typeof
local NEED = writer.NEED
local WRITE = writer.F32
local READ = reader.F32

local NEW = Vector2.new

return {
	write = @native function(value: Vector2): number
		if TYPE(value) ~= VAL_TYPE then
			return FAIL
		end
		if not NEED(8) then
			return FAIL
		end
		WRITE(value.X)
		WRITE(value.Y)
		return SUCCESS
	end,

	read = @native function(): (number, Vector2?)
		local flag: number, x: number?, y: number?

		flag, x = READ()
		flag, y = READ()
		if flag == FAIL then
			return FAIL, nil
		end

		return flag, NEW(x, y)
	end,
}
