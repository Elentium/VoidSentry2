--!strict
--!optimize 2
--[[
	Key-value Map
	2 + nodeSize(n) bytes
	max amount of 65535 entries
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

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const NEED: (number) -> boolean = writer.NEED
const WRITE_LEN: (number) -> () = writer.U16
const READ_LEN: () -> (number, number?) = reader.U16
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

@native
const function mapNodeBuild<K, V>(keyType: typeNode<K>, valueType: typeNode<V>): typeNode<{ [K]: V }>
	const valWrite: (V) -> number = valueType.write
	const valRead: (number?) -> (number, V?) = valueType.read
	const keyWrite: (K) -> number = keyType.write
	const keyRead: (number?) -> (number, K?) = keyType.read

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function map_write(value: { [K]: V }): number
		const vType: string = TYPE(value)
		if vType ~= VAL_TYPE then
			FAIL_FN(`[VoidSentry2]: Failed to serialize Map type – "table" expected, got "{vType}"`)
			return FAIL
		end

		local len: number = 0
		for _ in value do
			len += 1
		end
		if not NEED(2) then
			return FAIL
		elseif len > 0xFFFF then
			FAIL_FN(
				`[VoidSentry2]: Failed to serialize Map type – Map max length is 65535, the input value length is {len}`
			)
			return FAIL
		end
		WRITE_LEN(len)
		for k: K, v: V in value do
			if keyWrite(k) == FAIL then
				return FAIL
			elseif valWrite(v) == FAIL then
				return FAIL
			end
		end

		return SUCCESS
	end

	@native
	const function map_read(): (number, { [K]: V }?)
		local flag: number, len: number? = READ_LEN()
		if flag == FAIL then
			return FAIL, nil
		end
		const tbl: { [K]: V } = {}

		for i = 1, len :: number do
			local key: K?, val: V?
			flag, key = keyRead()
			flag, val = valRead()
			if flag == FAIL then
				return FAIL, nil
			end
			tbl[key] = val
		end

		return flag, tbl
	end

	return table.freeze({
		write = map_write,
		read = map_read,
	}) :: typeNode<{ [K]: V }>
end

return mapNodeBuild
