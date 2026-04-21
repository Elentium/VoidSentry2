--!strict
--!optimize 2
--[[
	Array
	2 + vSize(n) bytes

	max 65535 elements
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

const MAX_LEN: number = 0xFFFF

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const NEED: (number) -> boolean = writer.NEED
const WRITE_U16: (number) -> () = writer.U16
const READ_U16: () -> (number, number?) = reader.U16
const CREATE: typeof(table.create) = table.create
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

@native
const function arrayNodeBuild<T>(valueType: typeNode<T>): typeNode<{ T }>
	const valWrite: (T?) -> number = valueType.write
	const valRead: (number?) -> (number, T?) = valueType.read

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function array_write(value: { T }): number
		const vType: string = TYPE(value)
		if vType ~= VAL_TYPE then
			FAIL_FN(`[VoidSentry2]: Failed to serialize Array type – "table" expected, got "{vType}"`, 0)
			return FAIL
		end

		const len: number = #value
		if not NEED(2) then
			return FAIL
		elseif len > MAX_LEN then
			FAIL_FN(
				`[VoidSentry2]: Failed to serialize Array type – array length exceeds max limit; length: {len}, limit: {MAX_LEN}`,
				0
			)
			return FAIL
		end
		WRITE_U16(len)
		for i: number, v: any in value do
			if valWrite(v) == FAIL then
				return FAIL
			end
		end
		return SUCCESS
	end

	@native
	const function array_read(): (number, { T }?)
		const flag: number, len: number? = READ_U16()
		if flag == FAIL then
			return FAIL, nil
		end
		const array: { T } = CREATE(len :: number)
		local rflag: number = flag

		for i = 1, len :: number do
			rflag, array[i] = valRead()
			if rflag == FAIL then
				return FAIL, nil
			end
		end

		return rflag, array
	end

	return table.freeze({
		write = array_write,
		read = array_read,
		exType = "array"
	}) :: typeNode<{ T }>
end


return arrayNodeBuild
