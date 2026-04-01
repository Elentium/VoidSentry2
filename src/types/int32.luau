--!strict
--[[
	Signed 32-bit integer
	4 bytes
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

local NUM_TYPE: string = "number"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
local TYPE = type
local NEED = writer.NEED
local WRITE = writer.I32
local READ = reader.I32

return {
	write = @native function(value: number): number
		if TYPE(value) ~= NUM_TYPE then
			return FAIL
		end
		if not NEED(4) then
			return FAIL
		end
		WRITE(value)
		return SUCCESS
	end,

	read = READ, -- avoid possible extra function call
}
