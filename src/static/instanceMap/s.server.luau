--!strict
--!optimize 2
--[[
    InstanceMap.server V0.1.1

    Initializes server instance map
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const instanceMap = require("./")
const config = require("../../shared/config")

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const ATTRIBUTE_NAME: string = config.instanceIdAttribute

-----------------------------------------------------
-- MAIN                                            --
-----------------------------------------------------
local i: number = 0

const function onInstance(instance: Instance): ()
	i += 1
	instance:SetAttribute(ATTRIBUTE_NAME, i)
	instanceMap[i] = instance
end

game.DescendantAdded:Connect(onInstance)

for _, instance: Instance in game:GetDescendants() do
	onInstance(instance)
end
