--!strict
--[[
	Boolean
	1 byte
	simple true/false value
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

local VAL_TYPE: string = "boolean"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
local TYPE = type
local NEED = writer.NEED
local WRITE = writer.U8
local READ = reader.U8

return {
	write = @native function(value: boolean): number
		if TYPE(value) ~= VAL_TYPE then
			return FAIL
		end
		if not NEED(1) then
			return FAIL
		end
		WRITE(value and 1 or 0)
		return SUCCESS
	end,

	read = @native function(): (number, boolean?)
		local flag: number, value: number? = READ()
		if flag == FAIL then
			return flag, nil
		end
		return flag, value == 1
	end,
}
