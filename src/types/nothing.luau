--!strict
--!optimize 2
--[[
	nothing
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
const function nothing_write(value: nil): number
	return SUCCESS
end

@native
const function nothing_read(_lastFlag: number?): (number, nil)
	return _lastFlag or SUCCESS, nil
end

return table.freeze({
	write = nothing_write,
	read = nothing_read,
	exType = "nil"
})
