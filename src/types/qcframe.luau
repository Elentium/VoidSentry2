--!strict
--[[
    Quaternion CFrame
	- 28 bytes
    a tiny bit less precise than matrix cframe but less bandwidth

    each component is serialized as float32
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local config = require("../shared/config")
local writer = require("../buffer/writer")
local reader = require("../buffer/reader")
local math = require("../shared/math")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
local SUCCESS: number = config.success
local FAIL: number = config.fail

local VAL_TYPE: string = "CFrame"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
local TYPE = typeof
local NEED = writer.NEED
local WRITE = writer.F32
local READ = reader.F32
local NEW = CFrame.new
local TOQUATER = math.toQuater

return {
	write = @native function(value: CFrame): number
		if TYPE(value) ~= VAL_TYPE then
			return FAIL
		end
		if not NEED(28) then
			return FAIL
		end
		local x: number, y: number, z: number = value.X, value.Y, value.Z
		local qx: number, qy: number, qz: number, qw: number = TOQUATER(value)

		WRITE(x)
		WRITE(y)
		WRITE(z)
		WRITE(qx)
		WRITE(qy)
		WRITE(qz)
		WRITE(qw)

		return SUCCESS
	end,

	read = @native function(): (number, CFrame?)
		local x: number, y: number, z: number, qx: number, qy: number, qz: number, qw: number
		local flag: number
		flag, x = READ()
		flag, y = READ()
		flag, z = READ()
		flag, qx = READ()
		flag, qy = READ()
		flag, qz = READ()
		flag, qw = READ()
		-- doing 1 check per read is redundant for most cases, as most writes are valid,
		-- unless it's networker and exploiter spams invalid buffers, 1 check per read is worse for performance
		if flag == FAIL then
			return FAIL, nil
		end

		return flag, NEW(x :: number, y :: number, z :: number, qx :: number, qy :: number, qz :: number, qw :: number)
	end,
}
