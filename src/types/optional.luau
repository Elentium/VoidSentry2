--!strict
--[[
	Optional mark
	1 + nodeSize? bytes

	1 if value exists 0 if not

	if value does not exist, it takes only 1 byte
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

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
local NEED = writer.NEED
local WRITE = writer.U8
local READ = reader.U8

@native
local function optionalNodeBuild(node: typeNode): typeNode
	local write = node.write
	local read = node.read
	return {
		write = @native function(value: any?): number
			if not NEED(1) then
				return FAIL
			end
			local sign: number = value ~= nil and 1 or 0
			WRITE(sign)

			if value ~= nil then
				return write(value)
			end
			return SUCCESS
		end,

		read = @native function(): (number, any?)
			local flag: number, sign: number? = READ()
			if flag == FAIL then
				return FAIL
			end

			if sign == 1 then
				return read()
			end
			return flag, nil
		end,
	}
end

return optionalNodeBuild
