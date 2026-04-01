--!strict
--[[
	any
	supported types:
	- int8
	- int16
	- int32
	- uint8
	- uint16
	- uint32
	- float32
	- boolean
	- string
	- string255
	- array
	- array255
	- map
	- void
	- nothing
	- vector/vector3 (configurable)
	- vector2
	- cframe
	- color3
	- instance

	1 + nodeSize bytes
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local dynanode = require("../shared/dynanode")

return {
	write = dynanode.write,
	read = dynanode.read,
}
