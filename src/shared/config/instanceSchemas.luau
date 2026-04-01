--!strict
--[[
	VoidSentry2 Serialized Instance Schemas

	Empty table populated by src/init.luau after all type nodes are loaded.
	Modules that require this file always receive the same live table reference,
	so they automatically see entries added later by init.luau.

	Format: { [ClassName]: { [property]: typeNode } }
	Edit the entries in src/init.luau, not here.
]]
local exports = require("../../shared/exports")

type typeNode = exports.typeNode

local instanceSchemas: { [string]: { [string]: typeNode } } = {}

return instanceSchemas
