--!strict
--[[
	struct
	nodeSize per node bytes

	predefined schema which does not serialize keys, only values
	better than map if the keys are known on both sides
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local config = require("../shared/config")
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
local SORT = table.sort

@native
local function structNodeBuild(struct: { [string]: typeNode }): typeNode
	local keys: { string } = {}
	local writes: { [string]: (any) -> number } = {}
	local reads: { [string]: () -> (number, any?) } = {}
	for key: string, value: typeNode in struct :: { [string]: typeNode } do
		keys[#keys + 1] = key
		writes[key] = value.write
		reads[key] = value.read
	end
	SORT(keys)

	return {
		write = @native function(value: { [string]: any }): number
			if TYPE(value) ~= VAL_TYPE then
				return FAIL
			end

			for _, key: string in keys do
				local write = writes[key]
				if write(value[key]) == FAIL then
					return FAIL
				end
			end
			return SUCCESS
		end,
		read = @native function(): (number, { [string]: any }?)
			local struct: { [string]: any } = {}

			local flag: number
			for _, key: string in keys do
				local read = reads[key]
				if not read then
					return FAIL, nil
				end

				flag, struct[key] = read()
				if flag == FAIL then
					return FAIL, nil
				end
			end

			return flag, struct
		end,
	}
end

return structNodeBuild
