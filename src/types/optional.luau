--!strict
--!optimize 2
--[[
	Optional mark
	1 + nodeSize? bytes

	1 if value exists 0 if not

	if value does not exist, it takes only 1 byte
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

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const NEED: (number) -> boolean = writer.NEED
const WRITE: (number) -> () = writer.U8
const READ: () -> (number, number?) = reader.U8

@native
const function optionalNodeBuild<T>(node: typeNode<T>): typeNode<T?>
	const innerWrite: (T?) -> number = node.write
	const innerRead: (number?) -> (number, T?) = node.read

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function optional_write(value: T?): number
		if not NEED(1) then
			return FAIL
		end
		const sign: number = value ~= nil and 1 or 0
		WRITE(sign)

		if value ~= nil then
			return innerWrite(value)
		end
		return SUCCESS
	end

	@native
	const function optional_read(): (number, T?)
		const flag: number, sign: number? = READ()
		if flag == FAIL then
			return FAIL, nil
		end

		if sign == 1 then
			return innerRead()
		end
		return flag, nil
	end

	return table.freeze({
		write = optional_write,
		read = optional_read,
	}) :: typeNode<T?>
end

return optionalNodeBuild
