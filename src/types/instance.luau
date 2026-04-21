--!strict
--!optimize 2
--[[
	Instance
	3 bytes

    Writes a U24 instance ID, when deserializing does a instanceMap lookup
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")
const instanceMap = require("../static/instanceMap")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const SUCCESS: number = config.success
const FAIL: number = config.fail

const VAL_TYPE: string = "Instance"
const ID_ATTRIBUTE: string = config.instanceIdAttribute

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = typeof
const NEED: (number) -> boolean = writer.NEED
const WRITE: (number) -> () = writer.U24
const READ: () -> (number, number?) = reader.U24
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function instance_write(value: Instance): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[VoidSentry2]: Failed to serialize Instance type – "Instance" expected, got "{vType}"`, 0)
		return FAIL
	end

	const id: number? = value:GetAttribute(ID_ATTRIBUTE) :: any
	if not NEED(3) then
		return FAIL
	elseif not id then
		FAIL_FN(
			`[VoidSentry2]: Failed to serialize Instance type – The provided instance does not have "{ID_ATTRIBUTE}" identifier attribute`,
			0
		)
		return FAIL
	end
	WRITE(id)
	return SUCCESS
end

@native
const function instance_read(): (number, Instance?)
	const flag: number, id: number? = READ()
	if flag == FAIL then
		return FAIL, nil
	end

	const inst: Instance? = instanceMap[id :: number]
	if not inst then
		FAIL_FN(
			`[VoidSentry2]: Failed to deserialize Instance type – The instance was not found in the instanceMap`,
			0
		)
		return FAIL, nil
	end

	return flag, inst
end

return table.freeze({
	write = instance_write,
	read = instance_read,
	exType = "Instance"
})
