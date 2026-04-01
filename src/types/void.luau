--!strict
--[[
	void
	empty table
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
	write = @native function(value: {}): number
		return SUCCESS
	end,

	read = @native function(_lastFlag: number?): (number, {})
		return _lastFlag or SUCCESS, {}
	end,
}
