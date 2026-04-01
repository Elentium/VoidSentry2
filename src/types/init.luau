--!strict
--[[
    shared types storage + sign map

    signMap is populated by src/init.luau after all modules are loaded
    (avoids circular dependency: config -> types -> config)

    used by VoidSentry2, Config, and Dynanode
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local exports = require("./shared/exports")
-----------------------------------------------------
-- MODULE                                          --
-----------------------------------------------------
local module = {
	signMap = {} :: { [number]: exports.possibleNode },
	types = {} :: exports.types,
}

return module
