--!strict
--!optimize 2
--[[
    InstanceMap.server V0.1.0

    Initializes server instance map
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const instanceMap = require("./")
-----------------------------------------------------
-- MAIN                                            --
-----------------------------------------------------
local i: number = 0

const onInstance = function(instance: Instance): ()
	i += 1
	instance:SetAttribute("_VSID", i)
	instanceMap[i] = instance
end

game.DescendantAdded:Connect(onInstance)

for _, instance: Instance in game:GetDescendants() do
	onInstance(instance)
end
