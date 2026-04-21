--!strict
--!optimize 2
--[[
    Union
    1 + nodeSize bytes

    max of 255 possible unions

    each node.exType must be unique; otherwise cannot determine the node for the input value
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
const extypeof = require("../shared/extypeof")
const exports = require("../shared/exports")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>
type unionOfPack<T> = exports.unionOfPack<T>

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const FAIL: number = config.fail
const UNSUPPORTED_EXTYPES: { [string]: boolean } = config.unsupportedUnionExTypes :: { [string]: boolean }

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const WRITE: (number) -> () = writer.U8
const READ: () -> (number, number?) = reader.U8
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.strictMode and error or warn
const NEED: (number) -> boolean = writer.NEED

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
@native local function unionNodeBuild<T...>(...: T...): typeNode<unionOfPack<(T...) -> ()>>
    const variants: { typeNode } = { ... } :: { typeNode }
    const exTypeMap: { [string]: typeNode } = {}
    const signMap: { [typeNode]: number } = {}

    for i: number, variant: typeNode in variants do
        const exType: string = variant.exType
        if exTypeMap[exType] then
            error(`[VoidSentry2]: Union type node build failed – The variants include duplicate ExType while proper type node cannot be inferred for duplicate ExTypes; duplicate exType: {variant.exType}`, 0)
        elseif UNSUPPORTED_EXTYPES[exType] then
            error(`[VoidSentry2]: Union type node build failed – Unsupported union type: {exType}`, 0)
		end
        exTypeMap[exType] = variant
        signMap[variant] = i
    end

    @native local function union_write(value: unionOfPack<(T...) -> ()>): number
        const exType: string = extypeof(value)
        const node: typeNode = exTypeMap[exType]
        if not node then
            FAIL_FN(`[VoidSentry2]: Failed to serialize Union type – Variant for the input value not found, ExType: {exType}`, 0)
            return FAIL
        elseif not NEED(1) then
            return FAIL
        end

        local sign: number = signMap[node]
        WRITE(sign)
        return node.write(value)
    end

    @native local function union_read(): (number, unionOfPack<(T...) -> ()>?)
        local flag: number, sign: number? = READ()
        if flag == FAIL then
            return FAIL, nil
        end

        local node: typeNode = variants[sign :: number]
        if not node then
            FAIL_FN(`[VoidSentry2]: Failed to serialize Union type - Invalid sign, Variant Node not found; sign: {sign}`, 0)
            return FAIL, nil
        end

        return node.read()
    end

    return table.freeze({
        write = union_write,
        read = union_read,
        exType = "union"
    }) :: typeNode<unionOfPack<(T...) -> ()>>
end

return unionNodeBuild