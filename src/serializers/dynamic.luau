--!strict
--[[
	Dynamic V0.1.0

	Schemaless serializer for VoidSentry2
	Uses dynanode for dynamic behaviour
]]
-----------------------------------------------------
-- SERVICES                                        --
-----------------------------------------------------
local EncodingService = game:GetService("EncodingService")
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local dynanode = require("../shared/dynanode")
local config = require("../shared/config")
local reader = require("../buffer/reader")
local writer = require("../buffer/writer")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
local FAIL: number = config.fail
local EOR: number = config.eor
local ALG: Enum.CompressionAlgorithm = Enum.CompressionAlgorithm.Zstd

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
local PACK = table.pack
local UNPACK = table.unpack
local DYNANODE_WRITE = dynanode.write
local W_START = writer.START
local W_FINISH = writer.FINISH
local R_START = reader.START
local R_FINISH = reader.FINISH
local LEN = buffer.len

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
local dynamic = {}

@native
function dynamic.serialize(compressionLevel: number?, offset: number?, ...: any): buffer?
	local input: { [number]: any, n: number } = PACK(...)
	local n: number = input.n

	W_START(offset)
	for i = 1, n do
		local value: any = input[i]
		local flag: number = DYNANODE_WRITE(value)
		if flag == FAIL then
			W_FINISH()
			return nil
		end
	end
	local b: buffer = W_FINISH()
	if compressionLevel then
		b = EncodingService:CompressBuffer(b, ALG, compressionLevel)
	end

	return b
end

@native
function dynamic.deserialize(wasCompressed: boolean?, offset: number?, input: buffer): ...any?
	local output: { any } = {}
	if wasCompressed then
		input = EncodingService:DecompressBuffer(input, ALG)
	end
	if LEN(input) - (offset or 0) == 0 then
		-- empty buffer
		return
	end
	R_START(input, offset)
	local i: number = 0
	while true do
		i += 1
		local flag: number
		flag, output[i] = dynanode.read()
		if flag == FAIL then
			-- something went wrong(e.g, the sign existed but there was no data after the sign or the buffer is corrupted)
			R_FINISH()
			return
		elseif flag == EOR then
			break
		end
	end
	R_FINISH()
	return UNPACK(output, 1, i)
end

return dynamic
