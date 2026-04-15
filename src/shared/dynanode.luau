--!optimize 2
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
const inferValueType = require("./inferValueType")
const config = require("./config")
const exports = require("./exports")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")
const enumMap = require("../static/enumMap")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>

type possibleNode = exports.possibleNode

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const UNKNOWN: number = config.unknownType
const typeSigns = config.typeSigns

const FAIL: number = config.fail

local ANY_NODE: typeNode<any> = nil
local SIGNMAP: typeof(typesModule.signMap) = nil

const ANYID: number = typeSigns.any
const ARRAYID: number = typeSigns.array
const ARRAY255ID: number = typeSigns.array255
const MAPID: number = typeSigns.map
const SER_INSTANCE_ID: number = typeSigns.serInstance
local SER_INSTANCE_SIGNMAP: typeof(serInstanceSigns.signLookup) = nil
local SER_INSTANCE_NAMEMAP: typeof(serInstanceSigns.nameLookup) = nil
const ENUM_ID: number = typeSigns.enum
const enumIdMap: { [number]: Enum } = enumMap.idMap
const enumReverseMap: { [Enum]: number } = enumMap.reverseMap

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const NEED: (number) -> boolean = writer.NEED
const READ_SIGN: (...any) -> (number, number?) = reader.U8
const WRITE_SIGN: (number) -> () = writer.U8
const WRITE_ID: (number) -> () = writer.U16
const READ_ID: () -> (number, number?) = reader.U16
const TYPE: <T>(T) -> string = type
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn

return table.freeze({
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
		const sign: number = inferValueType(value)
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
				const className: string = value.ClassName
				node = node(className)
				-- write ID
				const isign: number = SER_INSTANCE_NAMEMAP[className]
				-- the sign will always exist (if it does not – the node constructor will error)
				if not NEED(1) then
					FAIL_FN(`[VoidSentry2]: Dynamic write failed – Buffer access out of bounds`)
				end
				WRITE_SIGN(isign)
			elseif sign == ENUM_ID then
				const enum: Enum = value.EnumType
				const id: number = enumReverseMap[enum]
				WRITE_ID(id)
				node = node(enum)
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
				const className: string = SER_INSTANCE_SIGNMAP[isign]
				if not className then
					FAIL_FN(`[VoidSentry2]: Dynamic node build failed – Invalid serInstance sign ({isign})`)
					return FAIL
				end
				node = node(className)
			elseif sign == ENUM_ID then
				local id: number?
				flag, id = READ_ID()
				if flag == FAIL then
					FAIL_FN(`[VoidSentry2]: Dynamic node build failed – Failed to read enum sign`)
					return FAIL
				end
				const enum: Enum = enumIdMap[id :: number]
				if not enum then
					FAIL_FN(`[VoidSentry2]: Dynamic node build failed – The enum ID is invalid {id}`)
					return FAIL
				end
				node = node(enum)
			end
		end

		return (node :: typeNode).read(flag)
	end,
})