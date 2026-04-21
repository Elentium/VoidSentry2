--!strict
--!optimize 2
--[[
	SerializedInstance
	struct bytes

    If the instance is supported (the class struct is defined) it will serialize the defined properties.
    On deserialization creates a new instance and sets up the properties.
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const exports = require("../shared/exports")
const struct = require("./struct") -- manual require to avoid recursive requires
const constants = require("../shared/config/constants")
const instanceSchemas = require("../static/instanceSchemas")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const FAIL: number = constants.fail
const VAL_TYPE: string = "Instance"
-----------------------------------------------------
-- STATE                                           --
-----------------------------------------------------
-- Compiled struct nodes keyed by className, built on first call per class.
-- instanceSchemas is populated by src/init.luau after all type nodes exist,
-- so compilation is deferred to first use to guarantee nodes are non-nil.
const compiledSchemas: { [string]: typeNode & { T: { [string]: typeNode } } } = {}

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = typeof
const NEW: (string, Instance?) -> Instance = Instance.new
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = constants.strictMode and error or warn

@native
const function TBLSET(tbl: { [string]: any }, instance: Instance, origin: { [string]: any }): ()
	for property: string in origin do
		tbl[property] = (instance :: any)[property]
	end
end

@native
const function INSTSET(instance: Instance, tbl: { [string]: any }): ()
	for property: string, value: any in tbl do
		(instance :: any)[property] = value
	end
end

@native
const function getSchema(className: string): (typeNode & { T: { [string]: typeNode } })?
	const cached: typeNode & { T: { [string]: typeNode } } = compiledSchemas[className]
	if cached then
		return cached
	end

	const propertiesSchema: { [string]: typeNode } = instanceSchemas[className]
	if not propertiesSchema then
		return nil
	end

	const structNode = struct(propertiesSchema)
	const node: typeNode & { T: { [string]: typeNode } } = table.freeze({
		write = structNode.write,
		read = structNode.read,
		T = propertiesSchema,
	}) :: typeNode & { T: { [string]: typeNode } }
	compiledSchemas[className] = node
	return node
end

@native
const function serInstanceNodeBuild(className: string): typeNode<Instance>
	const schema: (typeNode & { T: { [string]: typeNode } })? = getSchema(className)
	if not schema then
		error(
			`[VoidSentry2]: Failed to serialize SerInstance type – Unsupported/Undefined Schema for ClassName {className}`,
			0
		)
	end
	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function serInstance_write(value: Instance): number
		const vType: string = TYPE(value)
		if vType ~= VAL_TYPE then
			FAIL_FN(`[VoidSentry2]: Failed to serialize SerInstance type – "Instance" expected, got "{vType}"`, 0)
			return FAIL
		end

		const tbl: { [string]: any } = {}
		const success, err: string? =
			pcall(TBLSET :: ({ [string]: any }, Instance, { [string]: any }) -> any, tbl, value, schema.T)
		if not success then
			FAIL_FN(`[VoidSentry2]: Failed to serialize SerInstance type – Failed to fetch instance properties data, error: {err}`, 0)
			return FAIL
		end

		return schema.write(tbl)
	end

	@native
	const function serInstance_read(): (number, Instance?)
		const flag: number, tbl: { [string]: any } = schema.read()
		if flag == FAIL then
			return FAIL, nil
		end

		const inst: Instance = NEW(className)
		const success: boolean, err: string? = pcall(INSTSET :: (Instance, { [string]: any }) -> any, inst, tbl)
		if not success then
			FAIL_FN(
				`[VoidSentry2]: Failed to deserialize SerInstance type – Failed to set instance properties, error: {err}`,
				0
			)
		end

		return flag, inst
	end

	return table.freeze({
		write = serInstance_write,
		read = serInstance_read,
		exType = "Instance"
	}) :: typeNode
end

return serInstanceNodeBuild
