--!strict
--[[
	Static V0.1.0

	Schematized serializer for VoidSentry2
	Faster compared to Dynamic serializer as it has no type inferring overhead
]]
-----------------------------------------------------
-- SERVICES                                        --
-----------------------------------------------------
local EncodingService = game:GetService("EncodingService")

-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local exports = require("../shared/exports")
local writer = require("../buffer/writer")
local reader = require("../buffer/reader")
local config = require("../shared/config")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
local FAIL: number = config.fail
local ALG: Enum.CompressionAlgorithm = Enum.CompressionAlgorithm.Zstd
-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------

type serializer = exports.staticSerializer
type object<T... = ()> = exports.staticObject

type typeNode = exports.typeNode

-----------------------------------------------------
-- LOCALIZE                                        --
-----------------------------------------------------
local UNPACK = table.unpack
local PACK = table.pack

local W_FINISH = writer.FINISH
local W_START = writer.START

local R_FINISH = reader.FINISH
local R_START = reader.START

local FAIL_FN = config.strictMode and error or warn

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
local static = {}
static.__index = static

function static.new<T...>(compressionLevel: number?, ...: T...): object<T...>
	local object = setmetatable({}, static) :: object<T...>
	local schema: { any } = { ... }
	object._schema = schema
	object._compressionLevel = compressionLevel
	return object
end

@native
function static.serialize(self: object, offset: number?, ...: any): buffer?
	local schema: { typeNode } = self._schema
	local schemaLen: number = #schema
	local input = PACK(...)
	local inputLen: number = input.n
	if inputLen ~= schemaLen then
		FAIL_FN(
			`[VoidSentry]: Serialization failed – received values count does not match the schema, received: {inputLen}, expected: {schemaLen}`
		)
		return nil
	end
	W_START(offset)
	for i: number, node: typeNode in schema do
		local val: any = input[i]

		local result: number = node.write(val)
		if result == FAIL then
			W_FINISH()
			return nil
		end
	end

	local b: buffer = W_FINISH()
	local compressionLevel: number? = self._compressionLevel
	if compressionLevel then
		b = EncodingService:CompressBuffer(b, ALG, compressionLevel)
	end

	return b
end

@native
function static.deserialize(self: object, offset: number?, b: buffer): ...any?
	local schema: { typeNode } = self._schema
	local compressionLevel: number? = self._compressionLevel
	if compressionLevel then
		b = EncodingService:DecompressBuffer(b, ALG)
	end
	R_START(b, offset)
	local output: { any } = {}
	local schemaLen: number = #schema
	for i: number, node: typeNode in schema do
		local flag: number
		flag, output[i] = node.read()
		if flag == FAIL then
			R_FINISH()
			return nil
		end
	end

	R_FINISH()

	return UNPACK(output, 1, schemaLen)
end

return static
