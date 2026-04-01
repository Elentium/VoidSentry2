--!strict
--[[
	color3
	roblox Color3 type
	3 bytes
	each RGB field is serialized as uint8
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

local VAL_TYPE: string = "Color3"

local RECIPROCAL: number = 1 / 255

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
local TYPE = typeof
local NEED = writer.NEED
local WRITE = writer.U8
local READ = reader.U8

local NEW = Color3.fromRGB

return {
	write = @native function(value: Color3): number
		if TYPE(value) ~= VAL_TYPE then
			return FAIL
		end
		if not NEED(3) then
			return FAIL
		end
		WRITE(value.R // RECIPROCAL)
		WRITE(value.G // RECIPROCAL)
		WRITE(value.B // RECIPROCAL)
		return SUCCESS
	end,

	read = @native function(): (number, Color3?)
		local flag: number, r: number?, g: number?, b: number?

		flag, r = READ()
		flag, g = READ()
		flag, b = READ()
		if flag == FAIL then
			return FAIL, nil
		end

		return flag, NEW(r, g, b)
	end,
}
