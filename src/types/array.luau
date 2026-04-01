--!strict
--[[
	Array
	2 + vSize(n) bytes

	max 65535 elements
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local config = require("../shared/config")
local writer = require("../buffer/writer")
local reader = require("../buffer/reader")
local exports = require("../shared/exports")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode = exports.typeNode
-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
local SUCCESS: number = config.success
local FAIL: number = config.fail

local VAL_TYPE: string = "table"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
local TYPE = type
local NEED = writer.NEED
local WRITE_U16 = writer.U16
local READ_U16 = reader.U16
local CREATE = table.create

@native
local function arrayNodeBuild(valueType: typeNode): typeNode
	local valWrite = valueType.write
	local valRead = valueType.read
	return {
		write = @native function(value: { any }): number
			if TYPE(value) ~= VAL_TYPE then
				return FAIL
			end

			local len: number = #value
			if not NEED(2) then
				return FAIL
			end
			WRITE_U16(len)
			for i: number, v: any in value do
				if valWrite(v) == FAIL then
					return FAIL
				end
			end
			return SUCCESS
		end,
		read = @native function(): (number, any?)
			local flag: number, len: number? = READ_U16()
			if flag == FAIL then
				return FAIL
			end
			local array: { any } = CREATE(len :: number)
			local rflag: number = flag

			for i = 1, len :: number do
				rflag, array[i] = valRead()
				if rflag == FAIL then
					return FAIL
				end
			end

			return rflag, array
		end,
	}
end

return arrayNodeBuild
