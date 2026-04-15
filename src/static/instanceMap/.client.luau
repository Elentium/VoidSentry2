--!strict
--!optimize 2
--[[
    InstanceMap.client V0.1.0

    Initializes client instance map
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const instanceMap = require("./")

-----------------------------------------------------
-- MAIN                                            --
-----------------------------------------------------
const deferFetch = function(instance: Instance): number
	const co = coroutine.running()
	task.delay(0, function()
		task.defer(co, instance:GetAttribute("_VSID"))
	end)
	return coroutine.yield()
end

const onInstance = function(instance: Instance): ()
	const id: number = instance:GetAttribute("_VSID") or deferFetch(instance)
	if not id then
		return
	end
	instanceMap[id] = instance
end

for _, instance: Instance in game:GetDescendants() do
	onInstance(instance)
end

game.DescendantAdded:Connect(onInstance)
