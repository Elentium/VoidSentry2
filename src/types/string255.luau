--!strict
--[[
	string255
	1 + strlen bytes
	max amount of 255 characters
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

local VAL_TYPE: string = "string"

local LEN_LIMIT: number = 0xFF

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
local TYPE = type
local NEED = writer.NEED
local WRITE = writer.STR_S
local READ = reader.STR_S

return {
	write = @native function(value: string): number
		if TYPE(value) ~= VAL_TYPE then
			return FAIL
		end

		local len: number = #value
		if len > LEN_LIMIT then
			return FAIL
		end
		if not NEED(1 + len) then
			return FAIL
		end
		WRITE(value, len)
		return SUCCESS
	end,

	read = READ, -- avoid possible extra function call
}
