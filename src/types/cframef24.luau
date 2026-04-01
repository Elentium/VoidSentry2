--!strict
--[[
    CFrame(matrix) 
	- 36 bytes

	each component is serialized as float24
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local config = require("../shared/config")
local writer = require("../buffer/writer")
local reader = require("../buffer/reader")

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
local WRITE = writer.F24
local READ = reader.F24
local NEW = CFrame.new

return {
	write = @native function(value: CFrame): number
		if TYPE(value) ~= VAL_TYPE then
			return FAIL
		end
		if not NEED(36) then
			return FAIL
		end
		local x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
			value:GetComponents()

		WRITE(x)
		WRITE(y)
		WRITE(z)
		WRITE(R0)
		WRITE(R01)
		WRITE(R02)
		WRITE(R10)
		WRITE(R11)
		WRITE(R12)
		WRITE(R20)
		WRITE(R21)
		WRITE(R22)

		return SUCCESS
	end,

	read = @native function(): (number, CFrame?)
		local x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number
		local flag: number
		flag, x = READ()
		flag, y = READ()
		flag, z = READ()
		flag, R0 = READ()
		flag, R01 = READ()
		flag, R02 = READ()
		flag, R10 = READ()
		flag, R11 = READ()
		flag, R12 = READ()
		flag, R20 = READ()
		flag, R21 = READ()
		flag, R22 = READ()
		-- doing 1 check per read is redundant for most cases, as most writes are valid,
		-- unless it's networker and exploiter spams invalid buffers, 1 check per read is worse for performance
		if flag == FAIL then
			return FAIL, nil
		end

		return flag,
			NEW(
				x :: number,
				y :: number,
				z :: number,
				R0 :: number,
				R01 :: number,
				R02 :: number,
				R10 :: number,
				R11 :: number,
				R12 :: number,
				R20 :: number,
				R21 :: number,
				R22 :: number
			)
	end,
}
