--!strict
--!optimize 2
--[[
	Enum
	
    2 bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
const exports = require("../shared/exports")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>
type getItemType<T> = exports.getItemType<T>
-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const SUCCESS: number = config.success
const FAIL: number = config.fail

const VAL_TYPE: string = "Enum"
const VAL_TYPE2: string = "EnumItem"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = typeof
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn
const WRITE: (number) -> () = writer.U16
const READ: () -> (number, number?) = reader.U16

@native
const function enumNodeBuild<T>(input: T & Enum): typeNode<getItemType<T>>
	const enumType: string = TYPE(input)
	if enumType ~= VAL_TYPE then
		error(`[VoidSentry2]: Failed to build Enum node – invalid input argument, Enum expected, got {enumType}`)
	end

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function enum_write(value: getItemType<T> & EnumItem): number
		const vType: string = TYPE(value)
		if vType ~= VAL_TYPE2 then
			FAIL_FN(`[VoidSentry2]: Failed to serialize Enum type – "EnumItem" expected, got "{vType}"`)
			return FAIL
		end

		WRITE(value.Value)

		return SUCCESS
	end

	@native
	const function enum_read(): (number, getItemType<T>?)
		const flag: number, id: number? = READ()
		const enumItem: getItemType<T>? = flag ~= FAIL and input:FromValue(id :: number) or nil

		return flag, enumItem
	end

	return table.freeze({
		write = enum_write,
		read = enum_read,
	}) :: typeNode<getItemType<T>>
end

return enumNodeBuild
