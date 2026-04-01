--!strict
--[[
	Key-value Map
	1 + nodeSize(n) bytes
	max amount of 255 entries
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
local WRITE_LEN = writer.U8
local READ_LEN = reader.U8

local FAIL_FN = config.strictMode and error or warn

@native
local function map255NodeBuild(keyType: typeNode, valueType: typeNode): typeNode
	local valWrite = valueType.write
	local valRead = valueType.read
	local keyWrite = keyType.write
	local keyRead = keyType.read

	return {
		write = @native function(value: { [any]: any }): number
			if TYPE(value) ~= VAL_TYPE then
				return FAIL
			end

			local len: number = 0
			for _ in value do
				len += 1
			end
			if not NEED(1) then
				return FAIL
			elseif len > 0xFF then
				FAIL_FN(`Map max length is 255, the input length is {len}`)
				return FAIL
			end
			WRITE_LEN(len)
			for k: any, v: any in value do
				if keyWrite(k) == FAIL then
					return FAIL
				elseif valWrite(v) == FAIL then
					return FAIL
				end
			end

			return SUCCESS
		end,
		read = @native function(): (number, any?)
			local flag: number, len: number? = READ_LEN()
			if flag == FAIL then
				return FAIL
			end
			local map: { [any]: any } = {}
			local key: any, value: any

			for i = 1, len :: number do
				flag, key = keyRead()
				flag, value = valRead()
				if flag == FAIL then
					return FAIL
				end
				map[key] = value
			end

			return flag, map
		end,
	}
end

return map255NodeBuild
