--!strict
--[[
	Instance
	3 bytes

    Writes a U24 instance ID, when deserializing does a instanceMap lookup
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local config = require("../shared/config")
local writer = require("../buffer/writer")
local reader = require("../buffer/reader")
local instanceMap = require("../static/instanceMap")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
local SUCCESS: number = config.success
local FAIL: number = config.fail

local VAL_TYPE: string = "Instance"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
local TYPE = typeof
local NEED = writer.NEED
local WRITE = writer.U24
local READ = reader.U24

return {
	write = @native function(value: Instance): number
		if TYPE(value) ~= VAL_TYPE then
			return FAIL
		end

		local id: number? = value:GetAttribute("_VSID") :: any
		if not NEED(3) or not id then
			return FAIL
		end
		WRITE(id)
		return SUCCESS
	end,

	read = @native function(): (number, Instance?)
		local flag: number, id: number? = READ()
		if flag == FAIL then
			return FAIL, nil
		end

		local instance: Instance? = instanceMap[id :: number]
		if not instance then
			return FAIL, nil
		end

		return flag, instance
	end,
}
