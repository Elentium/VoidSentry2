--!strict
--[[
	nothing
	0 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local config = require("../shared/config")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
local SUCCESS: number = config.success

return {
	write = @native function(value: nil): number
		return SUCCESS
	end,

	read = @native function(_lastFlag: number?): (number, nil)
		return _lastFlag or SUCCESS, nil
	end,
}
