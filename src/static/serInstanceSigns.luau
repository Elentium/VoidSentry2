--!strict
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local instanceSchemas = require("../shared/config/instanceSchemas")

-----------------------------------------------------
-- VARIABLES                                       --
-----------------------------------------------------
local signLookup = {}
local nameLookup = {}
local serInstanceSigns = {
	signLookup = signLookup :: { [number]: string },
	nameLookup = nameLookup :: { [string]: number },
}

-----------------------------------------------------
-- INIT                                            --
-----------------------------------------------------
for className: string in instanceSchemas do
	table.insert(signLookup, className)
end
table.sort(signLookup)

for sign: number, className: string in signLookup do
	nameLookup[className] = sign
end

return serInstanceSigns
