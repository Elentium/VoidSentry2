--!strict
--!optimize 2
--[[
	deltaStruct
	1 + n*(1 + field) bytes

	Sparse struct: serializes present input keys only.
	u8 present-count and u8 field ids (max 255 present fields).
	Field ids are 1-based into lexicographically sorted schema keys;
	entry order follows the input table.
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")
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
const MAX_LEN: number = 0xFF

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const SORT: <V>({ V }, ((V, V) -> boolean)?) -> () = table.sort
const CREATE: <V>(number, V?) -> { V } = table.create
const NEED: (number) -> boolean = writer.NEED
const WRITE_LEN: (number) -> () = writer.U8
const READ_LEN: () -> (number, number?) = reader.U8
const WRITE_ID: (number) -> () = writer.U8
const READ_ID: () -> (number, number?) = reader.U8
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn

@native
const function deltaStructNodeBuild<T>(struct: T & { [string]: typeNode }): typeNode<T>
	const keys: { string } = {}
	local idx: number = 0
	for key: string in struct :: { [string]: typeNode } do
		idx += 1
		keys[idx] = key
	end
	SORT(keys)

	const writes = CREATE<<<V>(V) -> number>>(idx)
	const reads = CREATE<<() -> (number, any?)>>(idx)
	const lookup: { [string]: number } = {}

	for i: number, key: string in keys do
		const node: typeNode = (struct :: { [string]: typeNode })[key]
		writes[i] = node.write
		reads[i] = node.read
		lookup[key] = i
	end

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function deltaStruct_write<V>(value: { [string]: V }): number
		const vType: string = TYPE(value)
		if vType ~= VAL_TYPE then
			FAIL_FN(`[VoidSentry2]: Failed to serialize DeltaStruct type – "table" expected, got "{vType}"`, 0)
			return FAIL
		end

		local len: number = 0
		-- this is very slow, but there is currently no other way to solve that other than changing the library structure; maybe in the next updates
		for key: string in value do
			if lookup[key] ~= nil then
				len += 1
			end
		end
		if not NEED(1) then
			return FAIL
		elseif len > MAX_LEN then
			FAIL_FN(
				`[VoidSentry2]: Failed to serialize DeltaStruct type – DeltaStruct max present fields is 255, the input has {len}`,
				0
			)
			return FAIL
		end

		WRITE_LEN(len)
		for key: string, field: V in value do
			const id: number? = lookup[key]
			if id ~= nil then
				if not NEED(1) then
					return FAIL
				end
				WRITE_ID(id)
				if writes[id](field) == FAIL then
					return FAIL
				end
			end
		end
		return SUCCESS
	end

	@native
	const function deltaStruct_read(): (number, T?)
		const out: { [string]: any } = {}
		local flag: number, len: number? = READ_LEN()
		if flag == FAIL then
			return FAIL, nil
		end

		for _ = 1, len :: number do
			local id: number?
			flag, id = READ_ID()
			if flag == FAIL then
				return FAIL, nil
			end
			if (id :: number) < 1 or (id :: number) > idx then
				return FAIL, nil
			end
			local field: any?
			flag, field = reads[id :: number]()
			if flag == FAIL then
				return FAIL, nil
			end
			out[keys[id :: number]] = field
		end
		return flag, out
	end

	return table.freeze({
		write = deltaStruct_write,
		read = deltaStruct_read,
		exType = "map",
	}) :: typeNode<T>
end

return deltaStructNodeBuild
