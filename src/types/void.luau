--!strict
--!optimize 2
--[[
	void
	empty table
	0 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const SUCCESS: number = config.success

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function void_write(value: {}): number
	return SUCCESS
end

@native
const function void_read(_lastFlag: number?): (number, {})
	return _lastFlag or SUCCESS, {}
end

return table.freeze({
	write = void_write,
	read = void_read,
})
