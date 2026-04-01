--[[
	Dynanode V0.1.0

	Dynamic node behaviour shared by @any.luau and @dynamic.luau

	Infers types at runtime
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local typesModule: typeof(require("../types")) = nil
local serInstanceSigns: typeof(require("../static/serInstanceSigns")) = nil
local inferElementType = require("./inferValueType")
local config = require("./config")
local exports = require("./exports")
local writer = require("../buffer/writer")
local reader = require("../buffer/reader")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode = exports.typeNode

type possibleNode = exports.possibleNode

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
local UNKNOWN: number = config.unknownType
local typeSigns = config.typeSigns

local FAIL: number = config.fail

local ANY_NODE: typeNode = nil

local SIGNMAP: typeof(typesModule.signMap) = nil

local ANYID: number = typeSigns.any
local ARRAYID: number = typeSigns.array
local ARRAY255ID: number = typeSigns.array255
local MAPID: number = typeSigns.map
local SER_INSTANCE_ID = typeSigns.serInstance
local SER_INSTANCE_SIGNMAP: typeof(serInstanceSigns.signLookup) = nil
local SER_INSTANCE_NAMEMAP: typeof(serInstanceSigns.nameLookup) = nil

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
local NEED = writer.NEED
local READ_SIGN = reader.U8
local WRITE_SIGN = writer.U8
local TYPE = type
local FAIL_FN = config.strictMode and error or warn

return {
	write = @native function(value: any): number
		-- initialize types & other related constants on first op (prevent recursive dependency from any <-> types <--> dynanode)
		if typesModule == nil then
			typesModule = require("../types" :: string)
			serInstanceSigns = require("../static/serInstanceSigns")
			SER_INSTANCE_NAMEMAP = serInstanceSigns.nameLookup
			SER_INSTANCE_SIGNMAP = serInstanceSigns.signLookup
			SIGNMAP = typesModule.signMap
			ANY_NODE = SIGNMAP[ANYID]
		end
		local sign: number = inferElementType(value)
		if sign == UNKNOWN then
			-----------------------------------------------------
			-- UNKNOWN HANDLING                                --
			-----------------------------------------------------
			FAIL_FN(`[VoidSentry2]: Dynamic write failed – Unknown/Unsupported type {typeof(value)}`)
			return FAIL
		end
		local node: possibleNode = SIGNMAP[sign]

		if not node then
			FAIL_FN(`[VoidSentry2]: Dynamic node build failed – Invalid type sign ({sign})`)
			return FAIL
		elseif not NEED(1) then
			FAIL_FN(`[VoidSentry2]: Dynamic write failed – Buffer access out of bounds`)
			return FAIL
		end

		WRITE_SIGN(sign)

		if TYPE(node) == "function" then
			-- inline handling
			-- arrays/maps do not store per value/key signs as it will always be `any(dynamic)`
			if sign == ARRAYID or sign == ARRAY255ID then
				node = node(ANY_NODE)
			elseif sign == MAPID then
				node = node(ANY_NODE, ANY_NODE)
			elseif sign == SER_INSTANCE_ID then
				local className: string = value.ClassName
				node = node(className)
				-- write ID
				local isign: number = SER_INSTANCE_NAMEMAP[className]
				-- the sign will always exist (if it does not – the node constructor will error)
				if not NEED(1) then
					FAIL_FN(`[VoidSentry2]: Dynamic write failed – Buffer access out of bounds`)
				end
				WRITE_SIGN(isign)
			end
		end

		-- now the node write
		return (node :: typeNode).write(value)
	end,

	read = @native function(): (number, any?)
		if typesModule == nil then
			typesModule = require("../types" :: string)
			serInstanceSigns = require("../static/serInstanceSigns")
			SIGNMAP = typesModule.signMap
			ANY_NODE = SIGNMAP[ANYID]
		end
		local flag: number, sign: number? = READ_SIGN()
		if flag == FAIL then
			FAIL_FN(`[VoidSentry2]: Dynamic sign read failed`)
			return flag
		end

		local node: possibleNode = SIGNMAP[sign :: number]
		if not node then
			FAIL_FN(`[VoidSentry2]: Dynamic node build failed – Invalid type sign ({sign})`)
			return FAIL
		end

		if TYPE(node) == "function" then
			if sign == ARRAYID or sign == ARRAY255ID then
				node = node(ANY_NODE)
			elseif sign == MAPID then
				node = node(ANY_NODE, ANY_NODE)
			elseif sign == SER_INSTANCE_ID then
				local isign: number
				flag, isign = READ_SIGN()
				if flag == FAIL then
					FAIL_FN(`[VoidSentry2]: Dynamic node build failed – Failed to read serInstance sign`)
					return FAIL
				end
				local className: string = SER_INSTANCE_SIGNMAP[isign]
				if not className then
					FAIL_FN(`[VoidSentry2]: Dynamic node build failed – Invalid serInstance sign ({isign})`)
					return FAIL
				end
				node = node(className)
			end
		end

		return (node :: typeNode).read(flag)
	end,
}
