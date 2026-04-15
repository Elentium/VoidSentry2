--!strict
--!optimize 2
--[[
	struct
	nodeSize per node bytes

	predefined schema which does not serialize keys, only values
	better than map if the keys are known on both sides
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
const exports = require("../shared/exports")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>
-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const SUCCESS: number = config.success
const FAIL: number = config.fail

const VAL_TYPE: string = "table"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const SORT: <V>({ V }, ((V, V) -> boolean)?) -> () = table.sort
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

@native
const function structNodeBuild<T>(struct: T & { [string]: typeNode }): typeNode<T>
	const keys: { string } = {}
	const writes: { [string]: <T>(T) -> number } = {}
	const reads: { [string]: () -> (number, any?) } = {}
	for key: string, value: typeNode in struct :: { [string]: typeNode } do
		keys[#keys + 1] = key
		writes[key] = value.write
		reads[key] = value.read
	end
	SORT(keys)

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function struct_write<V>(value: { [string]: V } & T): number
		const vType: string = TYPE(value)
		if vType ~= VAL_TYPE then
			FAIL_FN(`[VoidSentry2]: Failed to serialize Struct type – "table" expected, got "{vType}"`)
			return FAIL
		end

		for _, key: string in keys do
			const fieldWrite: <Z>(Z) -> number = writes[key]
			if fieldWrite(value[key]) == FAIL then
				return FAIL
			end
		end
		return SUCCESS
	end

	@native
	const function struct_read(): (number, T?)
		const out: { [string]: any } = {}

		local flag: number
		for _, key: string in keys do
			const fieldRead: () -> (number, any?) = reads[key]
			flag, out[key] = fieldRead()
			if flag == FAIL then
				return FAIL, nil
			end
		end

		return flag, out
	end

	return table.freeze({
		write = struct_write,
		read = struct_read,
	}) :: typeNode<T>
end

return structNodeBuild
