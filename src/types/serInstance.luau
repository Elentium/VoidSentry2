--!strict
--[[
	SerializedInstance
	struct bytes

    If the instance is supported (the class struct is defined) it will serialize the defined properties.
    On deserialization creates a new instance and sets up the properties.
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local exports = require("../shared/exports")
local struct = require("./struct") -- manual require to avoid recursive requires
local constants = require("../shared/config/constants")
local instanceSchemas = require("../shared/config/instanceSchemas")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode = exports.typeNode

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
local FAIL: number = constants.fail
local VAL_TYPE: string = "Instance"

local FAIL_FN = constants.strictMode and error or warn

-----------------------------------------------------
-- STATE                                           --
-----------------------------------------------------
-- Compiled struct nodes keyed by className, built on first call per class.
-- instanceSchemas is populated by src/init.luau after all type nodes exist,
-- so compilation is deferred to first use to guarantee nodes are non-nil.
local compiledSchemas: { [string]: typeNode & { T: { [string]: typeNode } } } = {}

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
local TYPE = typeof
local NEW = Instance.new

@native
local function TBLSET(tbl: { [string]: any }, instance: Instance, origin: { [string]: any }): ()
	for property: string in origin do
		tbl[property] = (instance :: any)[property]
	end
end

@native
local function INSTSET(instance: Instance, tbl: { [string]: any }): ()
	for property: string, value: any in tbl do
		(instance :: any)[property] = value
	end
end

@native
local function getSchema(className: string): (typeNode & { T: { [string]: typeNode } })?
	local cached = compiledSchemas[className]
	if cached then
		return cached
	end

	local propertiesSchema = instanceSchemas[className]
	if not propertiesSchema then
		return nil
	end

	local node = struct(propertiesSchema) :: typeNode & { T: { [string]: typeNode } }
	node.T = propertiesSchema
	compiledSchemas[className] = node
	return node
end

@native
local function serInstanceNodeBuild(className: string): typeNode
	return {
		write = @native function(value: Instance): number
			if TYPE(value) ~= VAL_TYPE then
				return FAIL
			end

			local schema = getSchema(className)
			if not schema then
				FAIL_FN(`Unsupported instance schema for classname: {className}`)
				return FAIL
			end

			local tbl: { [string]: any } = {}
			local success, err: string? =
				pcall(TBLSET :: ({ [string]: any }, Instance, { [string]: any }) -> any, tbl, value, schema.T)
			if not success then
				FAIL_FN(`Failed to fetch instance properties data, error: {err}`)
				return FAIL
			end

			return schema.write(tbl)
		end,

		read = @native function(): (number, Instance?)
			local schema = getSchema(className)
			if not schema then
				FAIL_FN(`Unsupported instance schema for classname: {className}`)
				return FAIL, nil
			end

			local flag: number, tbl: { [string]: any } = schema.read()
			if flag == FAIL then
				return FAIL, nil
			end

			local instance = NEW(className)
			local success: boolean, err: string? = pcall(INSTSET :: (Instance, { [string]: any }) -> any, instance, tbl)
			if not success then
				FAIL_FN(`Failed to set instance properties, error: {err}`)
			end

			return flag, instance
		end,
	}
end

return serInstanceNodeBuild
