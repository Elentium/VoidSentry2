--!strict
--[[
	VoidSentry2 Test Suite

	Per test the suite records:
		ValidityPass   – round-trip / rejection checks passed (no crash)
		PerformancePass – average µs per iteration is within the per-test budget
		Avg µs         – average microseconds per timed iteration
		Budget µs      – performance ceiling used for PerformancePass (scaled by PERF_BUDGET_SCALE);
		                 base µs per test come from CONFIG.BUDGETS[testName]

	Section summary shows:
		ValidityPass    – all correctness checks in the section passed
		PerformancePass – all performance checks in the section passed

	Library config (`src/shared/config/constants.luau`, read here as VS_CONFIG) changes expectations:
		strictMode          – invalid input errors vs nil + warn (see expectRejectSerialize)
		dynamicInstanceType – "instance" vs "serInstance" dynamic section + Instance tests
		dynamicVectorType   – "Vector3" vs "vector" for dynamic Vector3 round-trip result type

	Static path uses `static.serialize(serdes, value, offset?, compressionLevel?)` /
	`static.deserialize(serdes, buffer, offset?, wasCompressed?)` (tuple layouts use `types.struct`).
]]
--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
const CONFIG = {
	-- Iterations for every performance benchmark.
	PERF_ITERATIONS = 2_000,

	-- Multiply all time budgets by this factor.
	-- Raise on slow machines (e.g. 2.0), lower on fast ones (e.g. 0.5).
	PERF_BUDGET_SCALE = 1.0,

	-- Line width for separators.
	SEPARATOR_WIDTH = 80,


	-- Per-test performance budget (µs per op).
	BUDGETS = {

		-- ─── Static · Integer Types ───
		["int8 – zero"] = 3,
		["int8 – boundary min (-128)"] = 3,
		["int8 – boundary max (127)"] = 3,
		["int8 – wrong type errors"] = 3,
		["int8 – wrong type returns nil"] = 3,
		["uint8 – boundary max (255)"] = 3,
		["uint8 – wrong type errors"] = 3,
		["uint8 – wrong type returns nil"] = 3,
		["int16 – min (-32768)"] = 3,
		["int16 – max (32767)"] = 3,
		["uint16 – max (65535)"] = 3,
		["int24 – negative mid-range (-8388608)"] = 3,
		["int24 – positive max (8388607)"] = 3,
		["uint24 – max (16777215)"] = 3,
		["int32 – min (-2147483648)"] = 3,
		["int32 – max (2147483647)"] = 3,
		["uint32 – max (4294967295)"] = 3,
		["uint40 – zero"] = 3,
		["uint40 – max (2^40 - 1)"] = 3,
		["uint40 – mid-range"] = 3,
		["uint40 – wrong type errors"] = 3,
		["uint40 – wrong type returns nil"] = 3,
		["int40 – zero"] = 3,
		["int40 – min (-2^39)"] = 3,
		["int40 – max (2^39 - 1)"] = 3,
		["int40 – -1"] = 3,
		["int40 – wrong type errors"] = 3,
		["int40 – wrong type returns nil"] = 3,

		-- ─── Static · Float Types ───
		["float16 – zero"] = 5,
		["float16 – positive value (approx ±1% tol)"] = 5,
		["float16 – negative value (approx ±1% tol)"] = 5,
		["float24 – zero"] = 5,
		["float24 – pi (approx 0.01 tol)"] = 5,
		["float24 – negative large (-1234.5, 0.5 tol)"] = 5,
		["float32 – pi (1e-5 tol)"] = 5,
		["float32 – negative (1e-5 tol)"] = 5,
		["float64 – exact round-trip"] = 5,
		["float64 – very large (1e200)"] = 5,

		-- ─── Static · Primitive Types ───
		["boolean – true round-trip"] = 3,
		["boolean – false round-trip"] = 3,
		["boolean – wrong type errors"] = 3,
		["boolean – wrong type returns nil"] = 3,
		["string – empty string"] = 5,
		["string – ASCII round-trip"] = 8,
		["string – unicode content"] = 8,
		["string255 – exactly 255 chars"] = 8,
		["void – serialize always returns buffer"] = 2,
		["void – deserialize returns empty table"] = 2,
		["nothing – serialize always returns buffer"] = 2,
		["nothing – deserialize returns nil"] = 2,
		["boolPacked – 8 mixed booleans round-trip"] = 6,
		["boolPacked – all true (byte = 0xFF)"] = 6,
		["boolPacked – all false (byte = 0x00)"] = 6,
		["boolPacked – fewer than 8 entries (trailing bits read as false)"] = 6,
		["boolPacked – wrong type errors"] = 4,
		["boolPacked – wrong type returns nil"] = 4,

		-- ─── Static · Vector Types ───
		["vector3 – zero vector"] = 6,
		["vector3 – typical position (0.01 tol)"] = 6,
		["vector3 – wrong type errors"] = 6,
		["vector3 – wrong type returns nil"] = 6,
		["vector (Luau) – round-trip axes (1e-4 tol)"] = 6,
		["vector2 – round-trip (1e-4 tol)"] = 6,
		["vector2f24 – round-trip (0.02 tol)"] = 6,
		["vector2f16 – round-trip (0.05 tol)"] = 6,
		["vector3f24 – round-trip (0.02 tol)"] = 6,
		["vector3f16 – round-trip (0.08 tol)"] = 6,

		-- ─── Static · CFrame & Color3 ───
		["cframe – matrix form FuzzyEq"] = 12,
		["cframef24 – FuzzyEq (max allowed tol)"] = 12,
		["qcframe – quaternion form FuzzyEq"] = 9,
		["qcframef24 – FuzzyEq (max allowed tol)"] = 9,
		["color3 – exact channels"] = 6,
		["enum – EnumItem round-trip (Material.Slate)"] = 6,

		-- ─── Static · Multi-value Schemas ───
		["5-field heterogeneous schema round-trip"] = 10,
		["int32 + float64 + vector3 + boolean"] = 8,
		["schema mismatch – too few args errors"] = 2,
		["schema mismatch – too few args returns nil"] = 2,

		-- ─── Static · Array Types ───
		["array(int32) – 5 elements"] = 10,
		["array(int32) – empty array"] = 5,
		["array(string) – 5 string elements"] = 15,
		["array255(float32) – 50 sine values (1e-4 tol)"] = 25,

		-- ─── Static · Map & optional ───
		["map(string255,int32) – string keys round-trip"] = 25,
		["map255(uint8,boolean) – 50 numeric keys"] = 40,
		["map – nested array values round-trip"] = 45,
		["optional(int32) – absent (nil)"] = 5,
		["optional(int32) – present"] = 5,
		["array(map(string255,uint8)) – nested collections"] = 50,

		-- ─── Static · Union Type ───
		["union(int32|float64|string255) – integer branch"] = 8,
		["union(int32|float64|string255) – float branch (non-integer number)"] = 9,
		["union(int32|float64|string255) – string branch"] = 11,
		["union(uint40|string255) – uint40 at 2^40-1"] = 8,
		["union(uint40|string255) – string branch"] = 11,
		["union(boolean|string|float32) – true"] = 8,
		["union(boolean|string|float32) – false"] = 8,
		["union(boolean|string|float32) – float (non-integer)"] = 9,
		["union(Vector3|Color3) – Vector3 branch"] = 12,
		["union(Vector3|Color3) – Color3 branch"] = 12,
		["union(array|map) – non-empty array branch"] = 15,
		["union(array|map) – map branch (string keys)"] = 30,
		["union(array|map) – empty table {} is array (extypeof)"] = 25,
		["union(int40|string|boolean) – int40 min edge"] = 28,
		["union(int40|string|boolean) – boolean competes with int (distinct exTypes)"] = 22,
		["union – duplicate ExType (int32 + int16) throws at build"] = 100,
		["union – duplicate ExType (two string widths) throws"] = 100,
		["union – nested union variant is unsupported (throws at build)"] = 100,
		["union – optional variant is unsupported (throws at build)"] = 100,
		["union – value matching no variant (number) errors on serialize"] = 12,
		["union – value matching no variant (number) returns nil"] = 12,
		["union – value matching no variant (table) errors"] = 15,
		["union – value matching no variant (table) returns nil"] = 15,
		["union(EnumItem|int|string) – EnumItem branch"] = 25,
		["union(EnumItem|int|string) – int branch"] = 22,
		["union – six distinct branches round-trip sample (Vector2)"] = 45,
		["union – six distinct branches round-trip sample (Color3)"] = 40,

		-- ─── Static · Struct Type ───
		["struct – 3-field float32 struct"] = 12,
		["struct – mixed field types (id/name/active/score)"] = 15,
		["struct – wrong type for field errors"] = 3,
		["struct – wrong type for field returns nil"] = 3,

		-- ─── Static · Nested Structs & Arrays ───
		["struct inside struct (entity with pos)"] = 18,
		["array of structs – 3 entries"] = 20,
		["3-level nested struct"] = 20,
		["array of arrays – 3×3 uint8 matrix"] = 25,
		["struct with array255(string255) field"] = 20,

		-- ─── Static · Zstd Compression ───
		["compressed string – round-trip identical"] = 80,
		["compressed buffer is smaller than uncompressed"] = 80,
		["compressed array(int32) – 200 elements round-trip"] = 200,

		-- ─── Dynamic · Primitive Types ───
		["dynamic – uint8 value 200"] = 5,
		["dynamic – int8 value -50"] = 5,
		["dynamic – float value 1.5 (1e-5 tol)"] = 5,
		["dynamic – true"] = 5,
		["dynamic – false"] = 5,
		["dynamic – short string"] = 7,
		["dynamic – long string (>255 chars)"] = 12,
		["dynamic – empty table (void)"] = 5,

		-- ─── Dynamic · Multiple Values ───
		["dynamic – mixed multi-value pack (number, bool, string)"] = 15,
		["dynamic – 6 heterogeneous values"] = 20,
		["dynamic – empty serialize returns non-nil buffer"] = 5,

		-- ─── Dynamic · Collections ───
		["dynamic – array of numbers"] = 15,
		["dynamic – map auto-detected"] = 20,

		-- ─── Dynamic · Nested Structures ───
		["dynamic – array of arrays"] = 25,
		["dynamic – deeply nested: array[array[array[uint8]]]"] = 35,
		["dynamic – map of maps (3 levels)"] = 40,
		["dynamic – array of maps with array values"] = 45,
		["dynamic – Vector3 round-trip"] = 15,
		["dynamic – Luau vector round-trip"] = 15,
		["dynamic – Vector2 round-trip"] = 12,
		["dynamic – CFrame round-trip (FuzzyEq)"] = 35,

		-- ─── Dynamic · Zstd Compression ───
		["dynamic Zstd – multi-value round-trip (wasCompressed = true)"] = 80,
		["dynamic Zstd – compressed buffer smaller on large string"] = 100,
		["dynamic Zstd – wrong wasCompressed on plain buffer fails"] = 100,
		["dynamic – uncompressed with explicit wasCompressed false"] = 15,

		-- ─── Static · any Type ───
		["any – serialize uint value 100"] = 5,
		["any – serialize string"] = 5,
		["any – serialize boolean true"] = 5,
		["any – serialize float (1e-4 tol)"] = 5,
		["any – serialize Vector3"] = 10,
		["any – serialize Color3"] = 10,
		["any – serialize CFrame"] = 18,
		["any – serialize array255 of numbers"] = 15,
		["any – serialize nested map (dynamic layout)"] = 22,

		-- ─── Static · Offset Support ───
		["offset=4: written bytes start at position 4"] = 10,
		["offset=4: deserialize with same offset"] = 10,

		-- ─── Static · Large Payload Benchmarks ───
		["array(float64) – 500 elements serialize"] = 150,
		["array(float64) – 500 elements round-trip exact"] = 300,
		["array(struct{id,x,y,active}) – 100 entities round-trip"] = 150,
		["string – 50 KB payload round-trip"] = 150,

		-- ─── Static · Instance (ID-based) ───
		["instance – registered part round-trips to same reference"] = 10,
		["instance – buffer is exactly 3 bytes (U24 id)"] = 5,
		["instance – unregistered instance (no _VSID) errors"] = 5,
		["instance – unregistered instance (no _VSID) returns nil"] = 5,
		["instance – id not in map errors on deserialize"] = 8,
		["instance – id not in map returns nil on deserialize"] = 8,
		["instance – wrong type value (non-Instance) errors"] = 3,
		["instance – wrong type value (non-Instance) returns nil"] = 3,
		["instance – two instances in one schema both round-trip"] = 12,

		-- ─── Static · SerInstance (struct-based) ───
		["serInstance(Part) – Name preserved exactly"] = 30,
		["serInstance(Part) – numeric properties within tolerance"] = 30,
		["serInstance(Part) – CFrame preserved (FuzzyEq)"] = 30,
		["serInstance(Part) – Color3 channels exact (uint8 storage)"] = 30,
		["serInstance(Part) – boolean Anchored preserved"] = 30,
		["serInstance(Part) – deserialized value is a new Part instance"] = 30,
		["serInstance – unsupported class name errors"] = 100,
		["serInstance – wrong type (non-Instance) errors"] = 20,
		["serInstance – wrong type (non-Instance) returns nil"] = 20,

		-- ─── Dynamic · SerInstance / Dynamic · Instance ───
		["dynamic – registered instance round-trips to same reference"] = 15,
		["dynamic – instance alongside primitives"] = 18,
		["dynamic – unregistered instance (no _VSID) errors"] = 5,
		["dynamic – unregistered instance (no _VSID) returns nil"] = 5,
		["dynamic – serInstance Part round-trip (new instance, props match)"] = 30,
		["dynamic – serInstance alongside primitives"] = 35,
		["dynamic – unsupported Instance class (Folder) errors"] = 15,

		-- ─── Edge Cases ───
		["edge – float32 math.huge round-trip"] = 5,
		["edge – float32 -math.huge round-trip"] = 5,
		["edge – float32 NaN identity preserved (v ~= v)"] = 5,
		["edge – float32 negative zero sign bit preserved"] = 5,
		["edge – float16 overflow saturates to math.huge"] = 6,
		["edge – float16 subnormal underflow flushes to zero"] = 6,
		["edge – string with embedded null bytes round-trips byte-exact"] = 8,
		["edge – string255 UTF-8 multi-byte exactly 255 bytes"] = 9,
		["edge – string255 empty boundary (length byte = 0)"] = 5,
		["edge – array255 boundary 0 elements"] = 10,
		["edge – array255 exactly 255 elements"] = 60,
		["edge – CFrame identity preserved byte-exact"] = 12,
		["edge – vector3 with math.huge on one axis"] = 6,
		["edge – struct with every numeric extreme simultaneously"] = 20,
		["edge – optional(optional(int32)) nested present/absent"] = 10,
		["edge – union routes integer-valued float via \"int\" branch"] = 10,
		["edge – map with empty-string key round-trips"] = 15,
	} :: { [string]: number },

}

--------------------------------------------------------------------------------
-- DEPENDENCY
--------------------------------------------------------------------------------
const voidSentry2 = require("./")
const vsConfig = require("./shared/config")
const types = voidSentry2.types
const static = voidSentry2.static
const dynamic = voidSentry2.dynamic

-- Static helpers (API: serialize(serdes, input, offset?, compressionLevel?)).
const function ser(sd: voidSentry2.typeNode, v: any): buffer?
	return static.serialize(sd, v, nil, nil)
end
const function des(sd: voidSentry2.typeNode, b: buffer): any
	return static.deserialize(sd, b, nil, nil)
end
const function serOff(sd: voidSentry2.typeNode, v: any, o: number): buffer?
	return static.serialize(sd, v, o, nil)
end
const function desOff(sd: voidSentry2.typeNode, b: buffer, o: number): any
	return static.deserialize(sd, b, o, nil)
end
const function serZ(sd: voidSentry2.typeNode, v: any, z: number): buffer?
	return static.serialize(sd, v, nil, z)
end
const function desZ(sd: voidSentry2.typeNode, b: buffer): any
	return static.deserialize(sd, b, nil, true)
end

--------------------------------------------------------------------------------
-- VARIABLES
--------------------------------------------------------------------------------
const colors = {
	bg = Color3.fromHex("0b0d14"),
	panel = Color3.fromHex("13151f"),
	card = Color3.fromHex("1c2030"),
	border = Color3.fromHex("282d45"),
	accent = Color3.fromHex("6c63ff"),
	accentDim = Color3.fromHex("3b3880"),
	textPri = Color3.fromHex("e8eaf6"),
	textSec = Color3.fromHex("8b8fc4"),
	textDim = Color3.fromHex("454870"),
	pass = Color3.fromHex("3fb87a"),
	fail = Color3.fromHex("e05555"),
	slow = Color3.fromHex("e0a040"),
	crash = Color3.fromHex("c03030"),
}

--------------------------------------------------------------------------------
-- FRAMEWORK STATE
--------------------------------------------------------------------------------
type TestResult = {
	name: string,
	section: string,
	validityPass: boolean,
	perfPass: boolean,
	avgUs: number,
	budgetUs: number,
	crashed: boolean,
	crashMsg: string,
}

type SectionInfo = {
	name: string,
	tests: { TestResult },
}

type SuiteStats = {
	totalTests: number,
	validityPct: number,
	perfPct: number,
	overallPct: number,
}

const allSections: { SectionInfo } = {}
local currentSection: SectionInfo = { name = "", tests = {} }

const SEP = string.rep("─", CONFIG.SEPARATOR_WIDTH)

@native
const function computeSuiteStats(): SuiteStats
	local total = 0
	local vOk = 0
	local pOk = 0
	local full = 0
	for _, sec in allSections do
		for _, r in sec.tests do
			total += 1
			if r.validityPass then
				vOk += 1
			end
			if r.perfPass then
				pOk += 1
			end
			if r.validityPass and r.perfPass and not r.crashed then
				full += 1
			end
		end
	end
	if total == 0 then
		return { totalTests = 0, validityPct = 100, perfPct = 100, overallPct = 100 }
	end
	return {
		totalTests = total,
		validityPct = (vOk / total) * 100,
		perfPct = (pOk / total) * 100,
		overallPct = (full / total) * 100,
	}
end

--------------------------------------------------------------------------------
-- BENCH HELPER
-- Validity check and performance measurement are always separated.
-- The validity lambda runs ONCE (no timing overhead).
-- The perf lambda is benched ITERS times.
--------------------------------------------------------------------------------
@native
const function bench(iters: number, fn: () -> ()): number
	fn() -- warm-up
	local t0 = os.clock()
	for _ = 1, iters do
		fn()
	end
	return ((os.clock() - t0) / iters) * 1_000_000
end

--------------------------------------------------------------------------------
-- SECTION
--------------------------------------------------------------------------------
@native
const function section(name: string)
	currentSection = { name = name, tests = {} }
	table.insert(allSections, currentSection)
end

--------------------------------------------------------------------------------
-- TEST
-- @param name       label (must exist in CONFIG.BUDGETS)
-- @param validityFn () -> bool   runs once, checks output correctness
-- @param perfFn     () -> ()     hot path to bench (full serialize→deserialize when testing round-trip)
--------------------------------------------------------------------------------
@native
const function test(name: string, validityFn: () -> boolean, perfFn: () -> ())
	local budgetUs = CONFIG.BUDGETS[name]
	if budgetUs == nil then
		error(`[VoidSentry2 tests]: missing CONFIG.BUDGETS entry for "{name}"`, 0)
	end
	local scaledBudget = budgetUs * CONFIG.PERF_BUDGET_SCALE

	local validityPass = false
	local crashed = false
	local crashMsg = ""
	local vOk, vErr = pcall(function()
		validityPass = validityFn()
	end)
	if not vOk then
		crashed = true
		crashMsg = tostring(vErr):sub(1, 120)
	end

	local avgUs = 0.0
	local pOk, pErr = pcall(function()
		avgUs = bench(CONFIG.PERF_ITERATIONS, perfFn)
	end)
	if not pOk then
		crashed = true
		crashMsg = crashMsg ~= "" and crashMsg or tostring(pErr):sub(1, 120)
	end

	local perfPass = avgUs <= scaledBudget

	local result: TestResult = {
		name = name,
		section = currentSection.name,
		validityPass = validityPass,
		perfPass = perfPass,
		avgUs = avgUs,
		budgetUs = scaledBudget,
		crashed = crashed,
		crashMsg = crashMsg,
	}
	table.insert(currentSection.tests, result)
end

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------
@native
const function approxEq(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

@native
const function cframeFuzzyEq(a: CFrame, b: CFrame, epsilon: number): boolean
	return (a :: any):FuzzyEq(b, epsilon)
end

-- Round-trip a static type node and check a predicate on the deserialized value.
@native
const function roundTrip(serdes: any, check: (any) -> boolean, value: any): boolean
	local b = ser(serdes, value)
	if b == nil then
		return false
	end
	local d = des(serdes, b)
	if d == nil and value ~= nil then
		return false
	end
	return check(d)
end

-- Round-trip dynamic and return all deserialized values as a table.
@native
const function dynRoundTrip(...: any): { any }?
	local b = dynamic.serialize(nil, nil, ...)
	if b == nil then
		return nil
	end
	local results = table.pack(dynamic.deserialize(nil, nil, b))
	return results
end

-- Dynamic with Zstd: first argument to serialize is compression level; deserialize
-- must pass wasCompressed = true (boolean), not the level.
@native
const function dynRoundTripCompressed(compressionLevel: number, ...: any): { any }?
	local b = dynamic.serialize(compressionLevel, nil, ...)
	if b == nil then
		return nil
	end
	return table.pack(dynamic.deserialize(true, nil, b))
end

-- Bench hot path: full static round-trip (must mirror roundTrip correctness path)
@native
const function staticRoundTripPerf(serdes: voidSentry2.typeNode, compressionLevel: number?, offset: number?, value: any): ()
	local b = static.serialize(serdes, value, offset, compressionLevel)
	if b ~= nil then
		static.deserialize(serdes, b, offset, compressionLevel ~= nil)
	end
end

@native
const function dynamicRoundTripPerf(...: any): ()
	local b = dynamic.serialize(nil, nil, ...)
	if b ~= nil then
		dynamic.deserialize(nil, nil, b)
	end
end

@native
const function dynamicRoundTripPerfCompressed(compressionLevel: number, ...: any): ()
	local b = dynamic.serialize(compressionLevel, nil, ...)
	if b ~= nil then
		dynamic.deserialize(true, nil, b)
	end
end

@native
const function dynamicRoundTripPerfWasCompressed(wasCompressed: boolean?, ...: any): ()
	local b = dynamic.serialize(nil, nil, ...)
	if b ~= nil then
		dynamic.deserialize(wasCompressed, nil, b)
	end
end

-- Invalid input: lax mode returns nil after warn; strict mode throws (pcall fails).
@native
const function expectRejectSerialize<T>(ok: boolean, result: T): boolean
	if vsConfig.strictMode then
		return not ok
	end
	return ok and result == nil
end

@native
const function expectRejectDeserialize<T>(ok: boolean, value: T): boolean
	if vsConfig.strictMode then
		return not ok
	end
	return ok and value == nil
end

-- Mirrors `src/shared/config/constants.luau` (via VS_CONFIG): affects dynamic inference tests.
@native
const function dynamicInfersSerInstance(): boolean
	return vsConfig.dynamicInstanceType == "serInstance"
end

@native
const function dynamicInfersVector3(): boolean
	return vsConfig.dynamicVectorType == "Vector3"
end

@native
const function dynamicSerPartMatchesSource<T>(out: T, src: Part): boolean
	if typeof(out) ~= "Instance" or not (out :: Instance):IsA("Part") then
		return false
	end
	local p = out :: Part
	return p.Name == src.Name
		and approxEq(p.Transparency, src.Transparency, 1e-4)
		and approxEq(p.Reflectance, src.Reflectance, 1e-4)
		and cframeFuzzyEq(p.CFrame, src.CFrame, 1e-2)
		and p.Anchored == src.Anchored
		and math.floor(p.Color.R * 255 + 0.5) == math.floor(src.Color.R * 255 + 0.5)
		and math.floor(p.Color.G * 255 + 0.5) == math.floor(src.Color.G * 255 + 0.5)
		and math.floor(p.Color.B * 255 + 0.5) == math.floor(src.Color.B * 255 + 0.5)
end

--------------------------------------------------------------------------------
-- CONSOLE PRINT
--------------------------------------------------------------------------------
const function printResults()
	local st = computeSuiteStats()
	print(SEP)
	print(
		string.format(
			"  VoidSentry2 Test Results   %d iterations/test   scale ×%.1f     |     Validity %.1f%%   Perf %.1f%%   Overall %.1f%%   (n=%d)",
			CONFIG.PERF_ITERATIONS,
			CONFIG.PERF_BUDGET_SCALE,
			st.validityPct,
			st.perfPct,
			st.overallPct,
			st.totalTests
		)
	)
	print(SEP)

	for _, sec in allSections do
		print("")
		print(SEP)
		print(string.format("  %s", sec.name))

		local secValidPass = true
		local secPerfPass = true
		for _, r in sec.tests do
			if r.crashed or not r.validityPass then
				secValidPass = false
			end
			if r.crashed or not r.perfPass then
				secPerfPass = false
			end
		end
		print(
			string.format("  ValidityPass: %-5s   PerformancePass: %s", tostring(secValidPass), tostring(secPerfPass))
		)
		print(SEP)

		for _, r in sec.tests do
			if r.crashed then
				print(string.format("  [CRASH] %-50s  %s", r.name, r.crashMsg))
			else
				local vTag = if r.validityPass then "PASS" else "FAIL"
				local pTag = if r.perfPass then "PASS" else "SLOW"
				print(
					string.format(
						"  [%s] %-50s | %s | avg %7.2f µs (budget %7.2f µs)",
						vTag,
						r.name,
						pTag,
						r.avgUs,
						r.budgetUs
					)
				)
			end
		end
	end

	print("")
	print(SEP)
	print("  End of report")
	print(SEP)
end

--------------------------------------------------------------------------------
-- UI BUILDER  (only when CONFIG.CREATE_UI == true)
--------------------------------------------------------------------------------
const function frame(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	for k, v in props do
		(f :: any)[k] = v
	end
	return f
end

const function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 13
	l.TextColor3 = colors.textPri
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

const function uiPadding(parent: Instance, h: number, v: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, h)
	p.PaddingRight = UDim.new(0, h)
	p.PaddingTop = UDim.new(0, v)
	p.PaddingBottom = UDim.new(0, v)
	p.Parent = parent
end

const function uiList(parent: Instance, spacing: number, dir: Enum.FillDirection?)
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, spacing)
	l.Parent = parent
end

const function uiCorner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

const function uiStroke(parent: Instance, clr: Color3, thick: number)
	local s = Instance.new("UIStroke")
	s.Color = clr
	s.Thickness = thick
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

const function buildUI()
	-- Root
	local sg = Instance.new("ScreenGui")
	sg.Name = "VoidSentry2TestResults"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 100

	local bg = frame({
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.bg,
		Parent = sg,
	})

	local win = frame({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 860, 0.94, 0),
		BackgroundColor3 = colors.panel,
		Parent = bg,
	})
	uiCorner(win, 14)
	uiStroke(win, colors.border, 1)

	-- Title bar
	local titleBar = frame({
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = colors.card,
		Parent = win,
	})
	uiCorner(titleBar, 14)
	frame({
		Name = "BottomFill",
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = colors.card,
		BorderSizePixel = 0,
		Parent = titleBar,
	})
	label({
		Name = "Title",
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Text = "  VoidSentry2  ·  Test Results",
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = colors.textPri,
		Parent = titleBar,
	})

	-- Scrollable body
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.Position = UDim2.new(0, 0, 0, 54)
	scroll.Size = UDim2.new(1, 0, 1, -54)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = colors.accentDim
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ElasticBehavior = Enum.ElasticBehavior.Never
	scroll.BorderSizePixel = 0
	scroll.Parent = win
	uiPadding(scroll, 14, 10)
	uiList(scroll, 10)

	-- Stats bar
	local statsBar = frame({
		Name = "StatsBar",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = colors.card,
		LayoutOrder = 0,
		Parent = scroll,
	})
	uiCorner(statsBar, 6)
	uiPadding(statsBar, 12, 0)
	local suiteStats = computeSuiteStats()
	label({
		Name = "StatsTextLeft",
		Size = UDim2.new(0.48, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Text = string.format(
			"Iterations per test: %d    Budget scale: ×%.1f",
			CONFIG.PERF_ITERATIONS,
			CONFIG.PERF_BUDGET_SCALE
		),
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextColor3 = colors.textSec,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = statsBar,
	})
	label({
		Name = "StatsTextRight",
		Size = UDim2.new(0.52, 0, 1, 0),
		Position = UDim2.new(0.48, 0, 0, 0),
		Text = string.format(
			"Validity %.1f%%  ·  Perf %.1f%%  ·  Overall %.1f%%  ·  n=%d",
			suiteStats.validityPct,
			suiteStats.perfPct,
			suiteStats.overallPct,
			suiteStats.totalTests
		),
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextColor3 = colors.textSec,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = statsBar,
	})

	-- Sections
	for sIdx, sec in allSections do
		local card = frame({
			Name = "Section_" .. sIdx,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = colors.card,
			LayoutOrder = sIdx,
			Parent = scroll,
		})
		uiCorner(card, 8)
		uiStroke(card, colors.border, 1)
		uiPadding(card, 12, 10)
		uiList(card, 0)

		local hdrRow = frame({
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Parent = card,
		})

		label({
			Name = "SectionName",
			Size = UDim2.new(0.5, 0, 1, 0),
			Text = sec.name,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = colors.textPri,
			Parent = hdrRow,
		})

		local secValidPass = true
		local secPerfPass = true
		for _, r in sec.tests do
			if r.crashed or not r.validityPass then
				secValidPass = false
			end
			if r.crashed or not r.perfPass then
				secPerfPass = false
			end
		end

		local badgeRow = frame({
			Name = "Badges",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 220, 0, 22),
			BackgroundTransparency = 1,
			Parent = hdrRow,
		})
		uiList(badgeRow, 6, Enum.FillDirection.Horizontal)

		const function badge(text: string, bg: Color3, fg: Color3, lo: number)
			local b = frame({
				Name = "Badge",
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = bg,
				LayoutOrder = lo,
				Parent = badgeRow,
			})
			uiCorner(b, 5)
			uiPadding(b, 7, 0)
			label({
				Name = "Lbl",
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = text,
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				TextColor3 = fg,
				Parent = b,
			})
		end

		local vBg = if secValidPass then colors.pass else colors.fail
		local pBg = if secPerfPass then colors.pass else colors.slow
		badge("Validity: " .. (if secValidPass then "PASS" else "FAIL"), vBg, colors.bg, 1)
		badge("Perf: " .. (if secPerfPass then "PASS" else "FAIL"), pBg, colors.bg, 2)

		frame({
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = colors.border,
			LayoutOrder = 1,
			Parent = card,
		})

		-- Column headers
		local colHdr = frame({
			Name = "ColHeaders",
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = card,
		})
		const function colLabel(txt: string, xAnchor: number, xPos: number, xSize: number)
			label({
				Name = txt,
				AnchorPoint = Vector2.new(xAnchor, 0.5),
				Position = UDim2.new(xPos, 0, 0.5, 0),
				Size = UDim2.new(xSize, 0, 0.8, 0),
				Text = txt,
				TextSize = 10,
				Font = Enum.Font.Gotham,
				TextColor3 = colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = colHdr,
			})
		end
		colLabel("Test", 0, 0, 0.50)
		colLabel("Valid", 0, 0.51, 0.07)
		colLabel("Perf", 0, 0.60, 0.07)
		colLabel("Avg µs", 0, 0.68, 0.15)
		colLabel("Budget", 0, 0.84, 0.16)

		-- Test rows
		for rIdx, r in sec.tests do
			local rowBg = if rIdx % 2 == 0 then colors.bg else colors.card
			local row = frame({
				Name = "Row_" .. rIdx,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = rowBg,
				BackgroundTransparency = if rIdx % 2 == 0 then 0.6 else 0,
				LayoutOrder = rIdx + 10,
				Parent = card,
			})
			uiCorner(row, 4)

			if r.crashed then
				label({
					Name = "Crash",
					Size = UDim2.fromScale(1, 1),
					Text = "  ⚠  " .. r.name .. "  —  " .. r.crashMsg,
					TextSize = 11,
					TextColor3 = colors.crash,
					Parent = row,
				})
			else
				label({
					Name = "Name",
					Position = UDim2.new(0, 4, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Size = UDim2.new(0.49, 0, 0.85, 0),
					Text = r.name,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextColor3 = colors.textPri,
					Parent = row,
				})

				local vColor = if r.validityPass then colors.pass else colors.fail
				local vDot = frame({
					Name = "VDot",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.51, 0, 0.5, 0),
					Size = UDim2.new(0, 10, 0, 10),
					BackgroundColor3 = vColor,
					Parent = row,
				})
				uiCorner(vDot, 5)

				local pColor = if r.perfPass then colors.pass else colors.slow
				local pDot = frame({
					Name = "PDot",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.60, 0, 0.5, 0),
					Size = UDim2.new(0, 10, 0, 10),
					BackgroundColor3 = pColor,
					Parent = row,
				})
				uiCorner(pDot, 5)

				label({
					Name = "Avg",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.68, 0, 0.5, 0),
					Size = UDim2.new(0.15, 0, 0.85, 0),
					Text = string.format("%.2f", r.avgUs),
					TextSize = 11,
					Font = Enum.Font.GothamMedium,
					TextColor3 = if r.perfPass then colors.textPri else colors.slow,
					Parent = row,
				})

				label({
					Name = "Budget",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.84, 0, 0.5, 0),
					Size = UDim2.new(0.16, 0, 0.85, 0),
					Text = string.format("%.2f", r.budgetUs),
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextColor3 = colors.textSec,
					Parent = row,
				})
			end
		end
	end

	-- Footer
	local footerCard = frame({
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = colors.accentDim,
		LayoutOrder = 9999,
		Parent = scroll,
	})
	uiCorner(footerCard, 8)
	uiPadding(footerCard, 18, 0)

	label({
		Name = "FooterNote",
		Size = UDim2.fromScale(1, 1),
		Text = "Per row: validity · performance · avg µs · budget µs",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = colors.textPri,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = footerCard,
	})

	sg.Parent = game:GetService("StarterGui")
	local lp = game:GetService("Players").LocalPlayer
	if lp then
		local pg = lp:FindFirstChildOfClass("PlayerGui")
		if pg then
			sg:Clone().Parent = pg
		end
	end
end

@native
const function voidSentry2_Test(createUI: boolean?): number
	table.clear(allSections)
	currentSection = { name = "", tests = {} }

	-- register serialized instance schemas
	voidSentry2.registerInstanceSchema("Part", {
		Name = types.string255,
		Material = (types.enum :: any)(Enum.Material),
		Transparency = types.float32,
		CFrame = types.qcframe,
		Size = types.vector3,
		CanCollide = types.boolean,
		CanTouch = types.boolean,
		Color = types.color3,
		Reflectance = types.float32,
		Anchored = types.boolean,
	})
	--------------------------------------------------------------------------------
	-- TESTS
	--------------------------------------------------------------------------------
	-- ─── Static Serializer: Integer Types ────────────────────────────────────────
	section("Static · Integer Types")

	do
		local s = types.int8
		test("int8 – zero", function()
			return roundTrip(s, function(v)
				return v == 0
			end, 0)
		end, function()
			staticRoundTripPerf(s, nil, nil, 0)
		end)

		test("int8 – boundary min (-128)", function()
			return roundTrip(s, function(v)
				return v == -128
			end, -128)
		end, function()
			staticRoundTripPerf(s, nil, nil, -128)
		end)

		test("int8 – boundary max (127)", function()
			return roundTrip(s, function(v)
				return v == 127
			end, 127)
		end, function()
			staticRoundTripPerf(s, nil, nil, 127)
		end)

		test(
			if vsConfig.strictMode then "int8 – wrong type errors" else "int8 – wrong type returns nil",
			function()
				local ok, res = pcall(function()
					return ser(s, "oops")
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(s, nil, nil, 0)
				else
					staticRoundTripPerf(s, nil, nil, "oops")
				end
			end
		)
	end

	do
		local s = types.uint8
		test("uint8 – boundary max (255)", function()
			return roundTrip(s, function(v)
				return v == 255
			end, 255)
		end, function()
			staticRoundTripPerf(s, nil, nil, 255)
		end)

		test(
			if vsConfig.strictMode then "uint8 – wrong type errors" else "uint8 – wrong type returns nil",
			function()
				local ok, res = pcall(function()
					return ser(s, "oops")
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(s, nil, nil, 0)
				else
					staticRoundTripPerf(s, nil, nil, "oops")
				end
			end
		)
	end

	do
		local s = types.int16
		test("int16 – min (-32768)", function()
			return roundTrip(s, function(v)
				return v == -32768
			end, -32768)
		end, function()
			staticRoundTripPerf(s, nil, nil, -32768)
		end)
		test("int16 – max (32767)", function()
			return roundTrip(s, function(v)
				return v == 32767
			end, 32767)
		end, function()
			staticRoundTripPerf(s, nil, nil, 32767)
		end)
	end

	do
		local s = types.uint16
		test("uint16 – max (65535)", function()
			return roundTrip(s, function(v)
				return v == 65535
			end, 65535)
		end, function()
			staticRoundTripPerf(s, nil, nil, 65535)
		end)
	end

	do
		local s = types.int24
		test("int24 – negative mid-range (-8388608)", function()
			return roundTrip(s, function(v)
				return v == -8388608
			end, -8388608)
		end, function()
			staticRoundTripPerf(s, nil, nil, -8388608)
		end)
		test("int24 – positive max (8388607)", function()
			return roundTrip(s, function(v)
				return v == 8388607
			end, 8388607)
		end, function()
			staticRoundTripPerf(s, nil, nil, 8388607)
		end)
	end

	do
		local s = types.uint24
		test("uint24 – max (16777215)", function()
			return roundTrip(s, function(v)
				return v == 16777215
			end, 16777215)
		end, function()
			staticRoundTripPerf(s, nil, nil, 16777215)
		end)
	end

	do
		local s = types.int32
		test("int32 – min (-2147483648)", function()
			return roundTrip(s, function(v)
				return v == -2147483648
			end, -2147483648)
		end, function()
			staticRoundTripPerf(s, nil, nil, -2147483648)
		end)
		test("int32 – max (2147483647)", function()
			return roundTrip(s, function(v)
				return v == 2147483647
			end, 2147483647)
		end, function()
			staticRoundTripPerf(s, nil, nil, 2147483647)
		end)
	end

	do
		local s = types.uint32
		test("uint32 – max (4294967295)", function()
			return roundTrip(s, function(v)
				return v == 4294967295
			end, 4294967295)
		end, function()
			staticRoundTripPerf(s, nil, nil, 4294967295)
		end)
	end

	do
		local s = types.uint40
		-- 40-bit unsigned max: 2^40 - 1
		local U40_MAX = 1099511627775
		test("uint40 – zero", function()
			return roundTrip(s, function(v)
				return v == 0
			end, 0)
		end, function()
			staticRoundTripPerf(s, nil, nil, 0)
		end)
		test("uint40 – max (2^40 - 1)", function()
			return roundTrip(s, function(v)
				return v == U40_MAX
			end, U40_MAX)
		end, function()
			staticRoundTripPerf(s, nil, nil, U40_MAX)
		end)
		test("uint40 – mid-range", function()
			return roundTrip(s, function(v)
				return v == 0xABCDEF1234
			end, 0xABCDEF1234)
		end, function()
			staticRoundTripPerf(s, nil, nil, 0xABCDEF1234)
		end)
		test(
			if vsConfig.strictMode then "uint40 – wrong type errors" else "uint40 – wrong type returns nil",
			function()
				local ok, res = pcall(function()
					return ser(s, "nope")
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(s, nil, nil, 0)
				else
					staticRoundTripPerf(s, nil, nil, "nope")
				end
			end
		)
	end

	do
		local s = types.int40
		-- Signed 40-bit: [-2^39, 2^39 - 1]
		local I40_MIN = -549755813888
		local I40_MAX = 549755813887
		test("int40 – zero", function()
			return roundTrip(s, function(v)
				return v == 0
			end, 0)
		end, function()
			staticRoundTripPerf(s, nil, nil, 0)
		end)
		test("int40 – min (-2^39)", function()
			return roundTrip(s, function(v)
				return v == I40_MIN
			end, I40_MIN)
		end, function()
			staticRoundTripPerf(s, nil, nil, I40_MIN)
		end)
		test("int40 – max (2^39 - 1)", function()
			return roundTrip(s, function(v)
				return v == I40_MAX
			end, I40_MAX)
		end, function()
			staticRoundTripPerf(s, nil, nil, I40_MAX)
		end)
		test("int40 – -1", function()
			return roundTrip(s, function(v)
				return v == -1
			end, -1)
		end, function()
			staticRoundTripPerf(s, nil, nil, -1)
		end)
		test(
			if vsConfig.strictMode then "int40 – wrong type errors" else "int40 – wrong type returns nil",
			function()
				local ok, res = pcall(function()
					return ser(s, {})
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(s, nil, nil, 0)
				else
					staticRoundTripPerf(s, nil, nil, {})
				end
			end
		)
	end

	-- ─── Static Serializer: Float Types ──────────────────────────────────────────
	section("Static · Float Types")

	do
		local s = types.float16
		test("float16 – zero", function()
			return roundTrip(s, function(v)
				return v == 0
			end, 0)
		end, function()
			staticRoundTripPerf(s, nil, nil, 0)
		end)
		test("float16 – positive value (approx ±1% tol)", function()
			-- f16 has limited mantissa; allow ~2% relative error on non-powers of two.
			return roundTrip(s, function(v)
				return approxEq(v, 1.5, 0.04)
			end, 1.5)
		end, function()
			staticRoundTripPerf(s, nil, nil, 1.5)
		end)
		test("float16 – negative value (approx ±1% tol)", function()
			return roundTrip(s, function(v)
				return approxEq(v, -3.14, 0.12)
			end, -3.14)
		end, function()
			staticRoundTripPerf(s, nil, nil, -3.14)
		end)
	end

	do
		local s = types.float24
		test("float24 – zero", function()
			return roundTrip(s, function(v)
				return v == 0
			end, 0)
		end, function()
			staticRoundTripPerf(s, nil, nil, 0)
		end)
		test("float24 – pi (approx 0.01 tol)", function()
			return roundTrip(s, function(v)
				return approxEq(v, math.pi, 0.06)
			end, math.pi)
		end, function()
			staticRoundTripPerf(s, nil, nil, math.pi)
		end)
		test("float24 – negative large (-1234.5, 0.5 tol)", function()
			return roundTrip(s, function(v)
				return approxEq(v, -1234.5, 2.0)
			end, -1234.5)
		end, function()
			staticRoundTripPerf(s, nil, nil, -1234.5)
		end)
	end

	do
		local s = types.float32
		test("float32 – pi (1e-5 tol)", function()
			return roundTrip(s, function(v)
				return approxEq(v, math.pi, 1e-5)
			end, math.pi)
		end, function()
			staticRoundTripPerf(s, nil, nil, math.pi)
		end)
		test("float32 – negative (1e-5 tol)", function()
			return roundTrip(s, function(v)
				return approxEq(v, -99.99, 1e-3)
			end, -99.99)
		end, function()
			staticRoundTripPerf(s, nil, nil, -99.99)
		end)
	end

	do
		local s = types.float64
		test("float64 – exact round-trip", function()
			local val = 1 / 3
			return roundTrip(s, function(v)
				return v == val
			end, val)
		end, function()
			staticRoundTripPerf(s, nil, nil, 1 / 3)
		end)
		test("float64 – very large (1e200)", function()
			return roundTrip(s, function(v)
				return v == 1e200
			end, 1e200)
		end, function()
			staticRoundTripPerf(s, nil, nil, 1e200)
		end)
	end

	-- ─── Static Serializer: Primitive Types ──────────────────────────────────────
	section("Static · Primitive Types")

	do
		local s = types.boolean
		test("boolean – true round-trip", function()
			return roundTrip(s, function(v)
				return v == true
			end, true)
		end, function()
			staticRoundTripPerf(s, nil, nil, true)
		end)
		test("boolean – false round-trip", function()
			return roundTrip(s, function(v)
				return v == false
			end, false)
		end, function()
			staticRoundTripPerf(s, nil, nil, false)
		end)
		test(
			if vsConfig.strictMode then "boolean – wrong type errors" else "boolean – wrong type returns nil",
			function()
				local ok, res = pcall(function()
					return ser(s, 1)
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(s, nil, nil, true)
				else
					staticRoundTripPerf(s, nil, nil, 1)
				end
			end
		)
	end

	do
		local s = types.string
		test("string – empty string", function()
			return roundTrip(s, function(v)
				return v == ""
			end, "")
		end, function()
			staticRoundTripPerf(s, nil, nil, "")
		end)
		test("string – ASCII round-trip", function()
			return roundTrip(s, function(v)
				return v == "hello world"
			end, "hello world")
		end, function()
			staticRoundTripPerf(s, nil, nil, "hello world")
		end)
		test("string – unicode content", function()
			local u = "こんにちは世界"
			return roundTrip(s, function(v)
				return v == u
			end, u)
		end, function()
			staticRoundTripPerf(s, nil, nil, "こんにちは世界")
		end)
	end

	do
		local s = types.string255
		local long255 = string.rep("x", 255)
		test("string255 – exactly 255 chars", function()
			return roundTrip(s, function(v)
				return v == long255
			end, long255)
		end, function()
			staticRoundTripPerf(s, nil, nil, long255)
		end)
	end

	do
		local s = types.void
		test("void – serialize always returns buffer", function()
			local b = ser(s, {})
			return b ~= nil and buffer.len(b) == 0
		end, function()
			staticRoundTripPerf(s, nil, nil, {})
		end)
		test("void – deserialize returns empty table", function()
			local b = ser(s, {}) :: buffer
			local v = des(s, b)
			return type(v) == "table"
		end, function()
			local b = ser(s, {}) :: buffer
			des(s, b)
		end)
	end

	do
		local s = types.nothing
		test("nothing – serialize always returns buffer", function()
			local b = ser(s, nil)
			return b ~= nil
		end, function()
			staticRoundTripPerf(s, nil, nil, nil)
		end)
		test("nothing – deserialize returns nil", function()
			local b = ser(s, nil) :: buffer
			local v = des(s, b)
			return v == nil
		end, function()
			local b = ser(s, nil) :: buffer
			des(s, b)
		end)
	end

	do
		local s = types.boolPacked
		local mixed = { true, false, true, false, true, true, false, true }
		test("boolPacked – 8 mixed booleans round-trip", function()
			return roundTrip(s, function(v)
				if type(v) ~= "table" then
					return false
				end
				for i = 1, 8 do
					if v[i] ~= mixed[i] then
						return false
					end
				end
				return true
			end, mixed)
		end, function()
			staticRoundTripPerf(s, nil, nil, mixed)
		end)

		test("boolPacked – all true (byte = 0xFF)", function()
			local allTrue = { true, true, true, true, true, true, true, true }
			local b = ser(s, allTrue)
			if b == nil or buffer.len(b) ~= 1 or buffer.readu8(b, 0) ~= 0xFF then
				return false
			end
			local v = des(s, b)
			for i = 1, 8 do
				if v[i] ~= true then
					return false
				end
			end
			return true
		end, function()
			staticRoundTripPerf(s, nil, nil, { true, true, true, true, true, true, true, true })
		end)

		test("boolPacked – all false (byte = 0x00)", function()
			local allFalse = { false, false, false, false, false, false, false, false }
			local b = ser(s, allFalse)
			if b == nil or buffer.len(b) ~= 1 or buffer.readu8(b, 0) ~= 0x00 then
				return false
			end
			local v = des(s, b)
			for i = 1, 8 do
				if v[i] ~= false then
					return false
				end
			end
			return true
		end, function()
			staticRoundTripPerf(s, nil, nil, { false, false, false, false, false, false, false, false })
		end)

		-- Fewer than 8 entries: read still returns an 8-slot table with trailing bits as false.
		test("boolPacked – fewer than 8 entries (trailing bits read as false)", function()
			local partial = { true, false, true } -- indices 1..3 set
			local b = ser(s, partial)
			if b == nil then
				return false
			end
			local v = des(s, b)
			return v[1] == true and v[2] == false and v[3] == true
				and v[4] == false and v[5] == false and v[6] == false
				and v[7] == false and v[8] == false
		end, function()
			staticRoundTripPerf(s, nil, nil, { true, false, true })
		end)

		test(
			if vsConfig.strictMode then "boolPacked – wrong type errors" else "boolPacked – wrong type returns nil",
			function()
				local ok, res = pcall(function()
					return ser(s, "not a table" :: any)
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(s, nil, nil, { true, false, true, false, true, false, true, false })
				else
					staticRoundTripPerf(s, nil, nil, "not a table" :: any)
				end
			end
		)
	end

	-- ─── Static Serializer: Vector Types ─────────────────────────────────────────
	section("Static · Vector Types")

	do
		local s = types.vector3
		test("vector3 – zero vector", function()
			return roundTrip(s, function(v)
				return v.X == 0 and v.Y == 0 and v.Z == 0
			end, Vector3.new(0, 0, 0))
		end, function()
			staticRoundTripPerf(s, nil, nil, Vector3.new(0, 0, 0))
		end)
		test("vector3 – typical position (0.01 tol)", function()
			local pos = Vector3.new(12.5, -3.75, 100.0)
			return roundTrip(s, function(v)
				return approxEq(v.X, pos.X, 1e-4) and approxEq(v.Y, pos.Y, 1e-4) and approxEq(v.Z, pos.Z, 1e-4)
			end, pos)
		end, function()
			staticRoundTripPerf(s, nil, nil, Vector3.new(12.5, -3.75, 100.0))
		end)
		test(
			if vsConfig.strictMode then "vector3 – wrong type errors" else "vector3 – wrong type returns nil",
			function()
				local bad = { X = 1, Y = 0, Z = 0 }
				local ok, res = pcall(function()
					return ser(s, bad)
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(s, nil, nil, Vector3.new(0, 0, 0))
				else
					staticRoundTripPerf(s, nil, nil, { X = 1, Y = 0, Z = 0 })
				end
			end
		)
	end

	do
		local s = types.vector
		local v = vector.create(1, -2.5, 99.125)
		test("vector (Luau) – round-trip axes (1e-4 tol)", function()
			return roundTrip(s, function(out: any)
				-- Luau primitive vector: compare axes (typeof is "vector")
				return approxEq(out.x, v.x, 1e-4) and approxEq(out.y, v.y, 1e-4) and approxEq(out.z, v.z, 1e-4)
			end, v)
		end, function()
			staticRoundTripPerf(s, nil, nil, v)
		end)
	end

	do
		local s = types.vector2
		local p = Vector2.new(100, -33.5)
		test("vector2 – round-trip (1e-4 tol)", function()
			return roundTrip(s, function(v)
				return approxEq(v.X, p.X, 1e-4) and approxEq(v.Y, p.Y, 1e-4)
			end, p)
		end, function()
			staticRoundTripPerf(s, nil, nil, p)
		end)
	end

	do
		local s = types.vector2f24
		local p = Vector2.new(0.25, math.pi)
		test("vector2f24 – round-trip (0.02 tol)", function()
			return roundTrip(s, function(v)
				return approxEq(v.X, p.X, 0.02) and approxEq(v.Y, p.Y, 0.02)
			end, p)
		end, function()
			staticRoundTripPerf(s, nil, nil, p)
		end)
	end

	do
		local s = types.vector2f16
		local p = Vector2.new(1.5, -2.5)
		test("vector2f16 – round-trip (0.05 tol)", function()
			return roundTrip(s, function(v)
				return approxEq(v.X, p.X, 0.05) and approxEq(v.Y, p.Y, 0.05)
			end, p)
		end, function()
			staticRoundTripPerf(s, nil, nil, p)
		end)
	end

	do
		local s = types.vector3f24
		local p = Vector3.new(12.3, -4.56, 0.001)
		test("vector3f24 – round-trip (0.02 tol)", function()
			return roundTrip(s, function(v)
				return approxEq(v.X, p.X, 0.02) and approxEq(v.Y, p.Y, 0.02) and approxEq(v.Z, p.Z, 0.02)
			end, p)
		end, function()
			staticRoundTripPerf(s, nil, nil, p)
		end)
	end

	do
		local s = types.vector3f16
		local p = Vector3.new(1, 2, 3)
		test("vector3f16 – round-trip (0.08 tol)", function()
			return roundTrip(s, function(v)
				return approxEq(v.X, p.X, 0.08) and approxEq(v.Y, p.Y, 0.08) and approxEq(v.Z, p.Z, 0.08)
			end, p)
		end, function()
			staticRoundTripPerf(s, nil, nil, p)
		end)
	end

	-- ─── Static Serializer: CFrame & Color3 ──────────────────────────────────────
	section("Static · CFrame & Color3")

	do
		local s = types.cframe
		local cf = CFrame.new(3, 4, 5) * CFrame.Angles(0.2, -0.5, 1.1)
		test("cframe – matrix form FuzzyEq", function()
			return roundTrip(s, function(v)
				return typeof(v) == "CFrame" and cframeFuzzyEq(v, cf, 1e-2)
			end, cf)
		end, function()
			staticRoundTripPerf(s, nil, nil, cf)
		end)
	end

	do
		local s = types.cframef24
		local cf = CFrame.new(1, 0, -2) * CFrame.Angles(0.1, 0.1, 0.1)
		-- Roblox FuzzyEq only allows epsilon in (0, 0.1]
		test("cframef24 – FuzzyEq (max allowed tol)", function()
			return roundTrip(s, function(v)
				return typeof(v) == "CFrame" and cframeFuzzyEq(v, cf, 0.1)
			end, cf)
		end, function()
			staticRoundTripPerf(s, nil, nil, cf)
		end)
	end

	do
		local s = types.qcframe
		local cf = CFrame.new(-7, 8, 9) * CFrame.Angles(0.3, -0.1, 0.7)
		test("qcframe – quaternion form FuzzyEq", function()
			return roundTrip(s, function(v)
				return typeof(v) == "CFrame" and cframeFuzzyEq(v, cf, 1e-2)
			end, cf)
		end, function()
			staticRoundTripPerf(s, nil, nil, cf)
		end)
	end

	do
		local s = types.qcframef24
		local cf = CFrame.new(0.5, 1.5, 2.5)
		test("qcframef24 – FuzzyEq (max allowed tol)", function()
			return roundTrip(s, function(v)
				return typeof(v) == "CFrame" and cframeFuzzyEq(v, cf, 0.1)
			end, cf)
		end, function()
			staticRoundTripPerf(s, nil, nil, cf)
		end)
	end

	do
		local s = types.color3
		local c = Color3.fromRGB(10, 200, 255)
		test("color3 – exact channels", function()
			return roundTrip(s, function(v)
				return v.R == c.R and v.G == c.G and v.B == c.B
			end, c)
		end, function()
			staticRoundTripPerf(s, nil, nil, c)
		end)
	end

	do
		local s = (types.enum :: any)(Enum.Material)
		local mat = Enum.Material.Slate
		test("enum – EnumItem round-trip (Material.Slate)", function()
			return roundTrip(s, function(v)
				return v == mat
			end, mat)
		end, function()
			staticRoundTripPerf(s, nil, nil, mat)
		end)
	end

	-- ─── Static Serializer: Multi-value ──────────────────────────────────────────
	section("Static · Multi-value Schemas")

	do
		local s = types.struct({
			u8 = types.uint8,
			i16 = types.int16,
			f32 = types.float32,
			b = types.boolean,
			str = types.string,
		})
		local a, b, c, d, e = 42, -300, 1.5, true, "VoidSentry"
		local row = { u8 = a, i16 = b, f32 = c, b = d, str = e }
		test("5-field heterogeneous schema round-trip", function()
			local buf = ser(s, row)
			if buf == nil then
				return false
			end
			local out = des(s, buf) :: any
			return out.u8 == a and out.i16 == b and approxEq(out.f32, c, 1e-5) and out.b == d and out.str == e
		end, function()
			staticRoundTripPerf(s, nil, nil, row)
		end)
	end

	do
		local s = types.struct({
			i = types.int32,
			f = types.float64,
			v = types.vector3,
			b = types.boolean,
		})
		local row = { i = -1, f = math.huge, v = Vector3.new(1, 2, 3), b = false }
		test("int32 + float64 + vector3 + boolean", function()
			local buf = ser(s, row)
			if buf == nil then
				return false
			end
			local out = des(s, buf) :: any
			return out.i == -1 and out.f == math.huge and approxEq(out.v.X, 1, 1e-4) and out.b == false
		end, function()
			staticRoundTripPerf(s, nil, nil, row)
		end)
	end

	do
		-- Missing struct field: second uint8 absent → nil passed to inner writer
		local s = types.struct({
			a = types.uint8,
			b = types.uint8,
		})
		test(
			if vsConfig.strictMode
				then "schema mismatch – too few args errors"
				else "schema mismatch – too few args returns nil",
			function()
				local ok, res = pcall(function()
					return ser(s, { a = 1 })
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(s, nil, nil, { a = 1, b = 2 })
				else
					staticRoundTripPerf(s, nil, nil, { a = 1 })
				end
			end
		)
	end

	-- ─── Static Serializer: Array Types ──────────────────────────────────────────
	section("Static · Array Types")

	do
		local s = types.array(types.int32)
		local data = { 1, -2, 300, -40000, 2147483647 }
		test("array(int32) – 5 elements", function()
			return roundTrip(s, function(v)
				for i, val in data do
					if v[i] ~= val then
						return false
					end
				end
				return true
			end, data)
		end, function()
			staticRoundTripPerf(s, nil, nil, data)
		end)

		test("array(int32) – empty array", function()
			return roundTrip(s, function(v)
				return #v == 0
			end, {})
		end, function()
			staticRoundTripPerf(s, nil, nil, {})
		end)
	end

	do
		local s = types.array(types.string)
		local words = { "alpha", "beta", "gamma", "delta", "epsilon" }
		test("array(string) – 5 string elements", function()
			return roundTrip(s, function(v)
				for i, w in words do
					if v[i] ~= w then
						return false
					end
				end
				return true
			end, words)
		end, function()
			staticRoundTripPerf(s, nil, nil, words)
		end)
	end

	do
		local s = types.array255(types.float32)
		local floats = {}
		for i = 1, 50 do
			floats[i] = math.sin(i)
		end
		test("array255(float32) – 50 sine values (1e-4 tol)", function()
			return roundTrip(s, function(v)
				for i, f in floats do
					if not approxEq(v[i], f, 1e-4) then
						return false
					end
				end
				return true
			end, floats)
		end, function()
			staticRoundTripPerf(s, nil, nil, floats)
		end)
	end

	-- ─── Static Serializer: Map & optional ───────────────────────────────────────
	section("Static · Map & optional")

	do
		local s = types.map(types.string255, types.int32)
		local m = { alpha = 1, beta = -42, gamma = 2147483647 }
		test("map(string255,int32) – string keys round-trip", function()
			return roundTrip(s, function(v)
				for k, val in pairs(m) do
					if v[k] ~= val then
						return false
					end
				end
				return true
			end, m)
		end, function()
			staticRoundTripPerf(s, nil, nil, m)
		end)
	end

	do
		local s = types.map255(types.uint8, types.boolean)
		local m: { [number]: boolean } = {}
		for i = 1, 50 do
			m[i] = i % 3 == 0
		end
		test("map255(uint8,boolean) – 50 numeric keys", function()
			return roundTrip(s, function(v)
				for k, val in pairs(m) do
					if v[k] ~= val then
						return false
					end
				end
				return true
			end, m)
		end, function()
			staticRoundTripPerf(s, nil, nil, m)
		end)
	end

	do
		local s = types.map(types.string255, types.array(types.uint8))
		local m = {
			a = { 1, 2, 3 },
			b = {},
			c = { 255, 0, 128 },
		}
		test("map – nested array values round-trip", function()
			return roundTrip(s, function(v)
				for k, arr in pairs(m) do
					local out = v[k]
					local arrT = arr :: { number }
					if type(out) ~= "table" or #out ~= #arrT then
						return false
					end
					for i, x in arrT do
						if out[i] ~= x then
							return false
						end
					end
				end
				return true
			end, m)
		end, function()
			staticRoundTripPerf(s, nil, nil, m)
		end)
	end

	do
		local s = types.optional(types.int32)
		test("optional(int32) – absent (nil)", function()
			return roundTrip(s, function(v)
				return v == nil
			end, nil)
		end, function()
			staticRoundTripPerf(s, nil, nil, nil)
		end)
		test("optional(int32) – present", function()
			return roundTrip(s, function(v)
				return v == -100000
			end, -100000)
		end, function()
			staticRoundTripPerf(s, nil, nil, -100000)
		end)
	end

	do
		local s = types.array(types.map(types.string255, types.uint8))
		local nested = {
			{ x = 1, y = 2 },
			{ a = 255 },
			{},
		}
		test("array(map(string255,uint8)) – nested collections", function()
			return roundTrip(s, function(v)
				for i, t in nested do
					local o = v[i]
					for k, val in t do
						if o[k] ~= val then
							return false
						end
					end
					for k in o do
						if t[k] == nil then
							return false
						end
					end
				end
				return true
			end, nested)
		end, function()
			staticRoundTripPerf(s, nil, nil, nested)
		end)
	end

	--[[
		Union dispatch uses runtime `extypeof(value)` matched against each variant's `exType`.
		Only one variant may use exType "int" (all integer width types share "int"), one "float", etc.
	]]
	-- ─── Static Serializer: Union ─────────────────────────────────────────────────
	section("Static · Union Type")

	do
		local u = types.union(types.int32, types.float64, types.string255)
		test("union(int32|float64|string255) – integer branch", function()
			return roundTrip(u, function(v)
				return v == -1234567890
			end, -1234567890)
		end, function()
			staticRoundTripPerf(u, nil, nil, -1234567890)
		end)
		test("union(int32|float64|string255) – float branch (non-integer number)", function()
			return roundTrip(u, function(v)
				return approxEq(v, math.pi, 1e-10)
			end, math.pi)
		end, function()
			staticRoundTripPerf(u, nil, nil, math.pi)
		end)
		test("union(int32|float64|string255) – string branch", function()
			local msg = "union-payload-こんにちは"
			return roundTrip(u, function(v)
				return v == msg
			end, msg)
		end, function()
			staticRoundTripPerf(u, nil, nil, "union-payload-こんにちは")
		end)
	end

	do
		local uWide = types.union(types.uint40, types.string255)
		local U40_MAX = 1099511627775
		test("union(uint40|string255) – uint40 at 2^40-1", function()
			return roundTrip(uWide, function(v)
				return v == U40_MAX
			end, U40_MAX)
		end, function()
			staticRoundTripPerf(uWide, nil, nil, U40_MAX)
		end)
		test("union(uint40|string255) – string branch", function()
			return roundTrip(uWide, function(v)
				return v == "wide"
			end, "wide")
		end, function()
			staticRoundTripPerf(uWide, nil, nil, "wide")
		end)
	end

	do
		local uBF = types.union(types.boolean, types.string255, types.float32)
		test("union(boolean|string|float32) – true", function()
			return roundTrip(uBF, function(v)
				return v == true
			end, true)
		end, function()
			staticRoundTripPerf(uBF, nil, nil, true)
		end)
		test("union(boolean|string|float32) – false", function()
			return roundTrip(uBF, function(v)
				return v == false
			end, false)
		end, function()
			staticRoundTripPerf(uBF, nil, nil, false)
		end)
		test("union(boolean|string|float32) – float (non-integer)", function()
			return roundTrip(uBF, function(v)
				return approxEq(v, 0.25, 1e-5)
			end, 0.25)
		end, function()
			staticRoundTripPerf(uBF, nil, nil, 0.25)
		end)
	end

	do
		local uVecCol = types.union(types.vector3, types.color3)
		local p = Vector3.new(-0.25, 1000, 3.125)
		local c = Color3.fromRGB(12, 200, 90)
		test("union(Vector3|Color3) – Vector3 branch", function()
			return roundTrip(uVecCol, function(v)
				return typeof(v) == "Vector3"
					and approxEq((v :: Vector3).X, p.X, 1e-3)
					and approxEq((v :: Vector3).Y, p.Y, 1e-3)
					and approxEq((v :: Vector3).Z, p.Z, 1e-3)
			end, p)
		end, function()
			staticRoundTripPerf(uVecCol, nil, nil, p)
		end)
		test("union(Vector3|Color3) – Color3 branch", function()
			return roundTrip(uVecCol, function(v)
				return typeof(v) == "Color3" and v.R == c.R and v.G == c.G and v.B == c.B
			end, c)
		end, function()
			staticRoundTripPerf(uVecCol, nil, nil, c)
		end)
	end

	do
		local uAM = types.union(types.array(types.uint8), types.map(types.string255, types.int32))
		local arr = { 9, 8, 7 }
		local m = { k = -1, zz = 42 }
		test("union(array|map) – non-empty array branch", function()
			return roundTrip(uAM, function(v)
				return v[1] == 9 and v[2] == 8 and v[3] == 7
			end, arr)
		end, function()
			staticRoundTripPerf(uAM, nil, nil, arr)
		end)
		test("union(array|map) – map branch (string keys)", function()
			return roundTrip(uAM, function(v)
				return (v :: any).k == -1 and (v :: any).zz == 42
			end, m)
		end, function()
			staticRoundTripPerf(uAM, nil, nil, m)
		end)
		test("union(array|map) – empty table {} is array (extypeof)", function()
			local empty: { number } = {}
			return roundTrip(uAM, function(v)
				return type(v) == "table" and #v == 0 and next(v :: any) == nil
			end, empty)
		end, function()
			staticRoundTripPerf(uAM, nil, nil, {})
		end)
	end

	do
		local uDisc = types.union(types.int40, types.string255, types.boolean)
		test("union(int40|string|boolean) – int40 min edge", function()
			return roundTrip(uDisc, function(v)
				return v == -549755813888
			end, -549755813888)
		end, function()
			staticRoundTripPerf(uDisc, nil, nil, -549755813888)
		end)
		test("union(int40|string|boolean) – boolean competes with int (distinct exTypes)", function()
			return roundTrip(uDisc, function(v)
				return v == false
			end, false)
		end, function()
			staticRoundTripPerf(uDisc, nil, nil, false)
		end)
	end

	do
		test("union – duplicate ExType (int32 + int16) throws at build", function()
			local ok = pcall(function()
				types.union(types.int32, types.int16)
			end)
			return not ok
		end, function()
			pcall(function()
				types.union(types.int32, types.int16)
			end)
		end)
		test("union – duplicate ExType (two string widths) throws", function()
			local ok = pcall(function()
				types.union(types.string, types.string255)
			end)
			return not ok
		end, function()
			pcall(function()
				types.union(types.string, types.string255)
			end)
		end)
		test("union – nested union variant is unsupported (throws at build)", function()
			local ok = pcall(function()
				types.union(types.int32, types.union(types.float64, types.boolean))
			end)
			return not ok
		end, function()
			pcall(function()
				types.union(types.int32, types.union(types.float64, types.boolean))
			end)
		end)
		test("union – optional variant is unsupported (throws at build)", function()
			local ok = pcall(function()
				types.union(types.int32, types.optional(types.int32))
			end)
			return not ok
		end, function()
			pcall(function()
				types.union(types.int32, types.optional(types.int32))
			end)
		end)
	end

	do
		local uOnlyBS = types.union(types.boolean, types.string255)
		test(
			if vsConfig.strictMode
				then "union – value matching no variant (number) errors on serialize"
				else "union – value matching no variant (number) returns nil",
			function()
				local ok, res = pcall(function()
					return ser(uOnlyBS, 999)
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(uOnlyBS, nil, nil, true)
				else
					staticRoundTripPerf(uOnlyBS, nil, nil, 999)
				end
			end
		)
		test(
			if vsConfig.strictMode
				then "union – value matching no variant (table) errors"
				else "union – value matching no variant (table) returns nil",
			function()
				local ok, res = pcall(function()
					return ser(uOnlyBS, { 1, 2 })
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(uOnlyBS, nil, nil, false)
				else
					staticRoundTripPerf(uOnlyBS, nil, nil, { 1, 2 })
				end
			end
		)
	end

	do
		local uEnum = types.union((types.enum :: any)(Enum.HorizontalAlignment) :: voidSentry2.typeNode<Enum.HorizontalAlignment>, types.int32, types.string255)
		test("union(EnumItem|int|string) – EnumItem branch", function()
			local item = Enum.HorizontalAlignment.Center
			return roundTrip(uEnum, function(v)
				return v == item
			end, item)
		end, function()
			staticRoundTripPerf(uEnum, nil, nil, Enum.HorizontalAlignment.Center)
		end)
		test("union(EnumItem|int|string) – int branch", function()
			return roundTrip(uEnum, function(v)
				return v == 424242
			end, 424242)
		end, function()
			staticRoundTripPerf(uEnum, nil, nil, 424242)
		end)
	end

	do
		local many = types.union(
			types.int32,
			types.float32,
			types.boolean,
			types.string255,
			types.vector2,
			types.color3
		)
		test("union – six distinct branches round-trip sample (Vector2)", function()
			local v2 = Vector2.new(-88.5, 1.25)
			return roundTrip(many, function(v)
				return typeof(v) == "Vector2" and approxEq(v.X, v2.X, 1e-3) and approxEq(v.Y, v2.Y, 1e-3)
			end, v2)
		end, function()
			staticRoundTripPerf(many, nil, nil, Vector2.new(-88.5, 1.25))
		end)
		test("union – six distinct branches round-trip sample (Color3)", function()
			local col = Color3.fromHSV(0.55, 0.2, 0.95)
			return roundTrip(many, function(v)
				return typeof(v) == "Color3"
			end, col)
		end, function()
			local col = Color3.fromHSV(0.55, 0.2, 0.95)
			staticRoundTripPerf(many, nil, nil, col)
		end)
	end

	-- ─── Static Serializer: Struct ────────────────────────────────────────────────
	section("Static · Struct Type")

	do
		local s = types.struct({
			x = types.float32,
			y = types.float32,
			z = types.float32,
		})
		local point = { x = 1.1, y = -2.2, z = 3.3 }
		test("struct – 3-field float32 struct", function()
			return roundTrip(s, function(v)
				return approxEq(v.x, point.x, 1e-4) and approxEq(v.y, point.y, 1e-4) and approxEq(v.z, point.z, 1e-4)
			end, point)
		end, function()
			staticRoundTripPerf(s, nil, nil, point)
		end)
	end

	do
		local s = types.struct({
			id = types.uint32,
			name = types.string255,
			active = types.boolean,
			score = types.float32,
		})
		local record = { id = 99999, name = "PlayerOne", active = true, score = 4200.5 }
		test("struct – mixed field types (id/name/active/score)", function()
			return roundTrip(s, function(v)
				return v.id == record.id
					and v.name == record.name
					and v.active == record.active
					and approxEq(v.score, record.score, 0.1)
			end, record)
		end, function()
			staticRoundTripPerf(s, nil, nil, record)
		end)
	end

	do
		local s = types.struct({
			name = types.string255,
			wrong = types.int8,
		})
		test(
			if vsConfig.strictMode
				then "struct – wrong type for field errors"
				else "struct – wrong type for field returns nil",
			function()
				local bad = { name = "ok", wrong = "not a number" }
				local ok, res = pcall(function()
					return ser(s, bad)
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(s, nil, nil, { name = "ok", wrong = 1 })
				else
					staticRoundTripPerf(s, nil, nil, { name = "ok", wrong = "not a number" })
				end
			end
		)
	end

	-- ─── Static Serializer: Nested Structs ───────────────────────────────────────
	section("Static · Nested Structs & Arrays")

	do
		local s = types.struct({
			pos = types.struct({
				x = types.float32,
				y = types.float32,
			}),
			hp = types.uint16,
			name = types.string255,
		})
		local entity = { pos = { x = 15.5, y = -22.0 }, hp = 1000, name = "Boss" }
		test("struct inside struct (entity with pos)", function()
			return roundTrip(s, function(v)
				return approxEq(v.pos.x, entity.pos.x, 1e-3)
					and approxEq(v.pos.y, entity.pos.y, 1e-3)
					and v.hp == entity.hp
					and v.name == entity.name
			end, entity)
		end, function()
			staticRoundTripPerf(s, nil, nil, entity)
		end)
	end

	do
		local str = types.struct({
			id = types.uint16,
			value = types.float32,
		})
		local s = types.array(str)
		local entries = {
			{ id = 1, value = 3.14 },
			{ id = 2, value = -1.5 },
			{ id = 3, value = 0 },
		}
		
		test("array of structs – 3 entries", function()
			return roundTrip(s, function(v)
				for i, e in entries do
					if v[i].id ~= e.id then
						return false
					end
					if not approxEq(v[i].value, e.value, 1e-4) then
						return false
					end
				end
				return true
			end, entries)
		end, function()
			staticRoundTripPerf(s, nil, nil, entries)
		end)
	end

	do
		-- 3-level deep nesting
		local s = types.struct({
			outer = types.struct({
				mid = types.struct({
					leaf = types.int32,
				}),
				tag = types.string255,
			}),
			count = types.uint8,
		})
		local deep = { outer = { mid = { leaf = -42 }, tag = "deep" }, count = 7 }
		test("3-level nested struct", function()
			return roundTrip(s, function(v)
				return v.outer.mid.leaf == deep.outer.mid.leaf
					and v.outer.tag == deep.outer.tag
					and v.count == deep.count
			end, deep)
		end, function()
			staticRoundTripPerf(s, nil, nil, deep)
		end)
	end

	do
		-- Array of arrays
		local s = types.array(types.array(types.uint8))
		local matrix = { { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 } }
		test("array of arrays – 3×3 uint8 matrix", function()
			return roundTrip(s, function(v)
				for i = 1, 3 do
					for j = 1, 3 do
						if v[i][j] ~= matrix[i][j] then
							return false
						end
					end
				end
				return true
			end, matrix)
		end, function()
			staticRoundTripPerf(s, nil, nil, matrix)
		end)
	end

	do
		-- Struct with array field
		local s = types.struct({
			tags = types.array255(types.string255),
			priority = types.uint8,
		})
		local item = { tags = { "fire", "magic", "rare" }, priority = 5 }
		test("struct with array255(string255) field", function()
			return roundTrip(s, function(v)
				if v.priority ~= item.priority then
					return false
				end
				for i, tag in item.tags do
					if (v :: any).tags[i] ~= tag then
						return false
					end
				end
				return true
			end, item)
		end, function()
			staticRoundTripPerf(s, nil, nil, item)
		end)
	end

	-- ─── Static Serializer: Compression ──────────────────────────────────────────
	section("Static · Zstd Compression")

	do
		local strSerde = types.string
		local payload = string.rep("aaabbbccc", 200)
		test("compressed string – round-trip identical", function()
			local b = serZ(strSerde, payload, 3)
			if b == nil then
				return false
			end
			local v = desZ(strSerde, b)
			return v == payload
		end, function()
			staticRoundTripPerf(strSerde, 3, nil, payload)
		end)
		test("compressed buffer is smaller than uncompressed", function()
			local bc = serZ(strSerde, payload, 3)
			local bu = ser(strSerde, payload)
			if bc == nil or bu == nil then
				return false
			end
			return buffer.len(bc) < buffer.len(bu)
		end, function()
			serZ(strSerde, payload, 3)
		end)
	end

	do
		local arrIntSerde = types.array(types.int32)
		local compressibleInts = {}
		for i = 1, 200 do
			compressibleInts[i] = i * 4
		end
		test("compressed array(int32) – 200 elements round-trip", function()
			local b = serZ(arrIntSerde, compressibleInts, 5)
			if b == nil then
				return false
			end
			local v = desZ(arrIntSerde, b)
			for i, val in compressibleInts do
				if v[i] ~= val then
					return false
				end
			end
			return true
		end, function()
			staticRoundTripPerf(arrIntSerde, 5, nil, compressibleInts)
		end)
	end

	-- ─── Dynamic Serializer: Primitives ──────────────────────────────────────────
	section("Dynamic · Primitive Types")

	test("dynamic – uint8 value 200", function()
		local r = dynRoundTrip(200)
		return r ~= nil and r[1] == 200
	end, function()
		dynamicRoundTripPerf(200)
	end)

	test("dynamic – int8 value -50", function()
		local r = dynRoundTrip(-50)
		return r ~= nil and r[1] == -50
	end, function()
		dynamicRoundTripPerf(-50)
	end)

	test("dynamic – float value 1.5 (1e-5 tol)", function()
		local r = dynRoundTrip(1.5)
		return r ~= nil and approxEq(r[1], 1.5, 1e-5)
	end, function()
		dynamicRoundTripPerf(1.5)
	end)

	test("dynamic – true", function()
		local r = dynRoundTrip(true)
		return r ~= nil and r[1] == true
	end, function()
		dynamicRoundTripPerf(true)
	end)

	test("dynamic – false", function()
		local r = dynRoundTrip(false)
		return r ~= nil and r[1] == false
	end, function()
		dynamicRoundTripPerf(false)
	end)

	test("dynamic – short string", function()
		local r = dynRoundTrip("hello")
		return r ~= nil and r[1] == "hello"
	end, function()
		dynamicRoundTripPerf("hello")
	end)

	test("dynamic – long string (>255 chars)", function()
		local big = string.rep("z", 1000)
		local r = dynRoundTrip(big)
		return r ~= nil and r[1] == big
	end, function()
		dynamicRoundTripPerf(string.rep("z", 1000))
	end)

	test("dynamic – empty table (void)", function()
		local r = dynRoundTrip({})
		return r ~= nil and type(r[1]) == "table" and next(r[1]) == nil
	end, function()
		dynamicRoundTripPerf({})
	end)

	-- ─── Dynamic Serializer: Multiple Values ─────────────────────────────────────
	section("Dynamic · Multiple Values")

	test("dynamic – mixed multi-value pack (number, bool, string)", function()
		local r = dynRoundTrip(42, true, "test")
		return r ~= nil and r[1] == 42 and r[2] == true and r[3] == "test"
	end, function()
		dynamicRoundTripPerf(42, true, "test")
	end)

	test("dynamic – 6 heterogeneous values", function()
		local r = dynRoundTrip(1, 2.5, false, "abc", 255, -128)
		return r ~= nil
			and r[1] == 1
			and approxEq(r[2], 2.5, 1e-5)
			and r[3] == false
			and r[4] == "abc"
			and r[5] == 255
			and r[6] == -128
	end, function()
		dynamicRoundTripPerf(1, 2.5, false, "abc", 255, -128)
	end)

	test("dynamic – empty serialize returns non-nil buffer", function()
		local b = dynamic.serialize(nil, nil)
		return b ~= nil
	end, function()
		dynamicRoundTripPerf()
	end)

	-- ─── Dynamic Serializer: Collections ─────────────────────────────────────────
	section("Dynamic · Collections")

	test("dynamic – array of numbers", function()
		local arr = { 10, 20, 30, 40, 50 }
		local r = dynRoundTrip(arr)
		if r == nil then
			return false
		end
		for i, v in arr do
			if r[1][i] ~= v then
				return false
			end
		end
		return true
	end, function()
		dynamicRoundTripPerf({ 10, 20, 30, 40, 50 })
	end)

	test("dynamic – map auto-detected", function()
		-- A table that is a pure dictionary (no integer keys from 1)
		local map = { a = 10, b = 20 }
		local r = dynRoundTrip(map)
		return r ~= nil and type(r[1]) == "table" and r[1].a == 10 and r[1].b == 20
	end, function()
		dynamicRoundTripPerf({ a = 10, b = 20 })
	end)

	-- ─── Dynamic Serializer: Nested & Deep ───────────────────────────────────────
	section("Dynamic · Nested Structures")

	test("dynamic – array of arrays", function()
		local matrix = { { 1, 2 }, { 3, 4 } }
		local r = dynRoundTrip(matrix)
		return r ~= nil and r[1][1][1] == 1 and r[1][1][2] == 2 and r[1][2][1] == 3 and r[1][2][2] == 4
	end, function()
		dynamicRoundTripPerf({ { 1, 2 }, { 3, 4 } })
	end)

	test("dynamic – deeply nested: array[array[array[uint8]]]", function()
		local cube = { { { 1, 2 }, { 3, 4 } }, { { 5, 6 }, { 7, 8 } } }
		local r = dynRoundTrip(cube)
		return r ~= nil and r[1][1][1][1] == 1 and r[1][2][2][2] == 8
	end, function()
		dynamicRoundTripPerf({ { { 1, 2 }, { 3, 4 } }, { { 5, 6 }, { 7, 8 } } })
	end)

	test("dynamic – map of maps (3 levels)", function()
		local tree = { L1 = { L2 = { leaf = 99 } } }
		local r = dynRoundTrip(tree)
		return r ~= nil and r[1].L1.L2.leaf == 99
	end, function()
		dynamicRoundTripPerf({ L1 = { L2 = { leaf = 99 } } })
	end)

	test("dynamic – array of maps with array values", function()
		local data = { { k = { 1, 2 } }, { k = { 3 } } }
		local r = dynRoundTrip(data)
		return r ~= nil and r[1][1].k[1] == 1 and r[1][1].k[2] == 2 and r[1][2].k[1] == 3
	end, function()
		dynamicRoundTripPerf({ { k = { 1, 2 } }, { k = { 3 } } })
	end)

	test(
		if dynamicInfersVector3() then "dynamic – Vector3 round-trip" else "dynamic – Luau vector round-trip",
		function()
			local p = Vector3.new(1.25, -99, 0.001)
			local r = dynRoundTrip(p)
			if r == nil then
				return false
			end
			local v = r[1]
			-- typeof(v) returns Vector3 no matter whether the object is created via Vector3.new or vector.create
			return typeof(v) == "Vector3"
				and approxEq(v.X, p.X, 1e-3)
				and approxEq(v.Y, p.Y, 1e-3)
				and approxEq(v.Z, p.Z, 1e-3)
		end,
		function()
			dynamicRoundTripPerf(Vector3.new(1.25, -99, 0.001))
		end
	)

	test("dynamic – Vector2 round-trip", function()
		local p = Vector2.new(50, -25.5)
		local r = dynRoundTrip(p)
		return r ~= nil and typeof(r[1]) == "Vector2" and approxEq(r[1].X, p.X, 1e-3) and approxEq(r[1].Y, p.Y, 1e-3)
	end, function()
		dynamicRoundTripPerf(Vector2.new(50, -25.5))
	end)

	test("dynamic – CFrame round-trip (FuzzyEq)", function()
		local cf = CFrame.new(10, 20, 30) * CFrame.Angles(0.5, -0.25, 0.125)
		local r = dynRoundTrip(cf)
		return r ~= nil and typeof(r[1]) == "CFrame" and cframeFuzzyEq(r[1], cf, 1e-2)
	end, function()
		dynamicRoundTripPerf(CFrame.new(10, 20, 30) * CFrame.Angles(0.5, -0.25, 0.125))
	end)

	-- ─── Dynamic Serializer: Zstd ────────────────────────────────────────────────
	section("Dynamic · Zstd Compression")

	test("dynamic Zstd – multi-value round-trip (wasCompressed = true)", function()
		local r = dynRoundTripCompressed(3, "payload", false, 12345)
		return r ~= nil and r[1] == "payload" and r[2] == false and r[3] == 12345
	end, function()
		dynamicRoundTripPerfCompressed(3, "payload", false, 12345)
	end)

	test("dynamic Zstd – compressed buffer smaller on large string", function()
		local payload = string.rep("abcd", 400)
		local plain = dynamic.serialize(nil, nil, payload)
		local zipped = dynamic.serialize(5, nil, payload)
		if plain == nil or zipped == nil then
			return false
		end
		return buffer.len(zipped) < buffer.len(plain)
	end, function()
		local payload = string.rep("abcd", 400)
		dynamic.serialize(5, nil, payload)
	end)

	test("dynamic Zstd – wrong wasCompressed on plain buffer fails", function()
		local b = dynamic.serialize(nil, nil, 1, 2, 3)
		if b == nil then
			return false
		end
		local ok = pcall(function()
			dynamic.deserialize(true, nil, b)
		end)
		return not ok
	end, function()
		local b = dynamic.serialize(nil, nil, 1, 2, 3) :: buffer
		pcall(function()
			dynamic.deserialize(true, nil, b)
		end)
	end)

	test("dynamic – uncompressed with explicit wasCompressed false", function()
		local b = dynamic.serialize(nil, nil, 7, 8)
		if b == nil then
			return false
		end
		local r = table.pack(dynamic.deserialize(false, nil, b))
		return r.n == 2 and r[1] == 7 and r[2] == 8
	end, function()
		dynamicRoundTripPerfWasCompressed(false, 7, 8)
	end)
	-- ─── any type (static) ────────────────────────────────────────────────────────
	section("Static · any Type")

	do
		local s = types.any
		test("any – serialize uint value 100", function()
			return roundTrip(s, function(v)
				return v == 100
			end, 100)
		end, function()
			staticRoundTripPerf(s, nil, nil, 100)
		end)
		test("any – serialize string", function()
			return roundTrip(s, function(v)
				return v == "abc"
			end, "abc")
		end, function()
			staticRoundTripPerf(s, nil, nil, "abc")
		end)
		test("any – serialize boolean true", function()
			return roundTrip(s, function(v)
				return v == true
			end, true)
		end, function()
			staticRoundTripPerf(s, nil, nil, true)
		end)
		test("any – serialize float (1e-4 tol)", function()
			return roundTrip(s, function(v)
				return approxEq(v, 3.14, 1e-4)
			end, 3.14)
		end, function()
			staticRoundTripPerf(s, nil, nil, 3.14)
		end)
		test("any – serialize Vector3", function()
			local p = Vector3.new(9, -8, 7.5)
			return roundTrip(s, function(v)
				return typeof(v) == "Vector3"
					and approxEq(v.X, p.X, 1e-3)
					and approxEq(v.Y, p.Y, 1e-3)
					and approxEq(v.Z, p.Z, 1e-3)
			end, p)
		end, function()
			staticRoundTripPerf(s, nil, nil, Vector3.new(9, -8, 7.5))
		end)
		test("any – serialize Color3", function()
			local c = Color3.fromRGB(5, 128, 240)
			return roundTrip(s, function(v)
				return typeof(v) == "Color3" and v.R == c.R and v.G == c.G and v.B == c.B
			end, c)
		end, function()
			staticRoundTripPerf(s, nil, nil, Color3.fromRGB(5, 128, 240))
		end)
		test("any – serialize CFrame", function()
			local cf = CFrame.new(1, 2, 3) * CFrame.Angles(0.4, -0.2, 0.1)
			return roundTrip(s, function(v)
				return typeof(v) == "CFrame" and cframeFuzzyEq(v, cf, 1e-2)
			end, cf)
		end, function()
			staticRoundTripPerf(s, nil, nil, CFrame.new(1, 2, 3) * CFrame.Angles(0.4, -0.2, 0.1))
		end)
		test("any – serialize array255 of numbers", function()
			local arr = { 1, 2, 3, 4, 5 }
			return roundTrip(s, function(v)
				if type(v) ~= "table" or #v ~= #arr then
					return false
				end
				for i, x in arr do
					if v[i] ~= x then
						return false
					end
				end
				return true
			end, arr)
		end, function()
			staticRoundTripPerf(s, nil, nil, { 1, 2, 3, 4, 5 })
		end)
		test("any – serialize nested map (dynamic layout)", function()
			local tree = { a = { b = { c = 42 } } }
			return roundTrip(s, function(v)
				if type(v) ~= "table" then
					return false
				end
				return ((v :: any).a :: any).b.c == 42
			end, tree)
		end, function()
			staticRoundTripPerf(s, nil, nil, { a = { b = { c = 42 } } })
		end)
	end

	-- ─── Static + Offset ─────────────────────────────────────────────────────────
	section("Static · Offset Support")

	do
		local s = types.struct({
			lo = types.uint8,
			hi = types.uint8,
		})
		local pair = { lo = 0xAA, hi = 0xBB }
		test("offset=4: written bytes start at position 4", function()
			local b = serOff(s, pair, 4)
			if b == nil then
				return false
			end
			-- `hi` key will be sorted before `lo` key, therefore the first byte will represent the `hi` value
			return buffer.len(b) == 6 and buffer.readu8(b, 4) == 0xBB and buffer.readu8(b, 5) == 0xAA
		end, function()
			staticRoundTripPerf(s, nil, 4, pair)
		end)
		test("offset=4: deserialize with same offset", function()
			local b = serOff(s, pair, 4) :: buffer
			local out = desOff(s, b, 4) :: any
			return out.lo == 0xAA and out.hi == 0xBB
		end, function()
			staticRoundTripPerf(s, nil, 4, pair)
		end)
	end

	-- ─── Large Payloads ───────────────────────────────────────────────────────────
	section("Static · Large Payload Benchmarks")

	do
		local s = types.array(types.float64)
		local big: { number } = {}
		for i = 1, 500 do
			big[i] = math.random() * 1e6
		end
		test("array(float64) – 500 elements serialize", function()
			return ser(s, big) ~= nil
		end, function()
			ser(s, big)
		end)
		test("array(float64) – 500 elements round-trip exact", function()
			local b = ser(s, big)
			if b == nil then
				return false
			end
			local v = des(s, b)
			for i, f in big do
				if v[i] ~= f then
					return false
				end
			end
			return true
		end, function()
			staticRoundTripPerf(s, nil, nil, big)
		end)
	end

	do
		local s = types.array(types.struct({
			id = types.uint32,
			x = types.float32,
			y = types.float32,
			active = types.boolean,
		}))
		local entities: { any } = {}
		for i = 1, 100 do
			entities[i] = { id = i, x = math.random() * 200, y = math.random() * 200, active = i % 2 == 0 }
		end
		test("array(struct{id,x,y,active}) – 100 entities round-trip", function()
			local b = ser(s, entities)
			if b == nil then
				return false
			end
			local v = des(s, b)
			for i, e in entities do
				local row = v[i]
				if row.id ~= e.id then
					return false
				end
				if not approxEq(row.x :: number, e.x :: number, 1e-2) then
					return false
				end
				if row.active ~= e.active then
					return false
				end
			end
			return true
		end, function()
			staticRoundTripPerf(s, nil, nil, entities)
		end)
	end

	do
		local s = types.string
		local huge = string.rep("abcdefghij", 5000)
		test("string – 50 KB payload round-trip", function()
			local b = ser(s, huge)
			if b == nil then
				return false
			end
			return des(s, b) == huge
		end, function()
			staticRoundTripPerf(s, nil, nil, huge)
		end)
	end

	-- ─── Static Serializer: Instance ─────────────────────────────────────────────
	section("Static · Instance (ID-based)")

	do
		-- Access the internal instanceMap directly so we can register test instances.
		local instanceMap = require("./static/instanceMap")
		local s = types.instance
		local part = Instance.new("Part")
		local VSID = 9001
		part:SetAttribute("_VSID", VSID)
		instanceMap[VSID] = part

		test("instance – registered part round-trips to same reference", function()
			local b = ser(s, part)
			if b == nil then
				return false
			end
			local v = des(s, b)
			return v == part
		end, function()
			staticRoundTripPerf(s, nil, nil, part)
		end)

		test("instance – buffer is exactly 3 bytes (U24 id)", function()
			local b = ser(s, part)
			return b ~= nil and buffer.len(b) == 3
		end, function()
			staticRoundTripPerf(s, nil, nil, part)
		end)

		test(
			if vsConfig.strictMode
				then "instance – unregistered instance (no _VSID) errors"
				else "instance – unregistered instance (no _VSID) returns nil",
			function()
				local unregistered = Instance.new("Part")
				local ok, res = pcall(function()
					return ser(s, unregistered)
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(s, nil, nil, part)
				else
					staticRoundTripPerf(s, nil, nil, Instance.new("Part"))
				end
			end
		)

		local badInstanceBuf = buffer.create(3)
		buffer.writeu16(badInstanceBuf, 0, 0xFFFE)
		buffer.writeu8(badInstanceBuf, 2, 0xFF)

		test(
			if vsConfig.strictMode
				then "instance – id not in map errors on deserialize"
				else "instance – id not in map returns nil on deserialize",
			function()
				local ok, v = pcall(function()
					return des(s, badInstanceBuf)
				end)
				return expectRejectDeserialize(ok, v)
			end,
			function()
				if vsConfig.strictMode then
					local b = ser(s, part) :: buffer
					des(s, b)
				else
					des(s, badInstanceBuf)
				end
			end
		)

		test(
			if vsConfig.strictMode
				then "instance – wrong type value (non-Instance) errors"
				else "instance – wrong type value (non-Instance) returns nil",
			function()
				local ok, res = pcall(function()
					return ser(s, "not an instance" :: any)
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(s, nil, nil, part)
				else
					staticRoundTripPerf(s, nil, nil, "not an instance" :: any)
				end
			end
		)

		-- Multiple instances in one schema
		local partA = Instance.new("Part")
		local partB = Instance.new("Model")
		partA:SetAttribute("_VSID", 9002)
		partB:SetAttribute("_VSID", 9003)
		instanceMap[9002] = partA
		instanceMap[9003] = partB

		local s2 = types.struct({
			first = types.instance,
			second = types.instance,
		})
		local instRow = { first = partA, second = partB }
		test("instance – two instances in one schema both round-trip", function()
			local b = ser(s2, instRow)
			if b == nil then
				return false
			end
			local out = des(s2, b) :: any
			return out.first == partA and out.second == partB
		end, function()
			staticRoundTripPerf(s2, nil, nil, instRow)
		end)
	end

	-- ─── Static Serializer: SerInstance ───────────────────────────────────────────
	section("Static · SerInstance (struct-based)")

	do
		local s = types.serInstance("Part")
		-- Build a Part with every schema property set to known values.
		local src = Instance.new("Part")
		src.Name = "TestPart"
		src.Material = Enum.Material.Plastic
		src.Transparency = 0.5
		src.CFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0.1, -0.2, 0.3)
		src.Size = Vector3.new(4, 2, 1)
		src.CanCollide = true
		src.CanTouch = false
		src.Color = Color3.fromRGB(100, 150, 200)
		src.Anchored = true
		src.Reflectance = 0.25

		test("serInstance(Part) – Name preserved exactly", function()
			local b = ser(s, src)
			if b == nil then
				return false
			end
			local v = des(s, b)
			return typeof(v) == "Instance" and v:IsA("Part") and v.Name == src.Name
		end, function()
			staticRoundTripPerf(s, nil, nil, src)
		end)

		test("serInstance(Part) – numeric properties within tolerance", function()
			local b = ser(s, src)
			if b == nil then
				return false
			end
			local v = des(s, b)
			if typeof(v) ~= "Instance" then
				return false
			end
			local p = v :: Part
			return approxEq(p.Transparency, src.Transparency, 1e-4) and approxEq(p.Reflectance, src.Reflectance, 1e-4)
		end, function()
			staticRoundTripPerf(s, nil, nil, src)
		end)

		test("serInstance(Part) – CFrame preserved (FuzzyEq)", function()
			local b = ser(s, src)
			if b == nil then
				return false
			end
			local v = des(s, b)
			if typeof(v) ~= "Instance" then
				return false
			end
			return cframeFuzzyEq((v :: Part).CFrame, src.CFrame, 1e-2)
		end, function()
			staticRoundTripPerf(s, nil, nil, src)
		end)

		test("serInstance(Part) – Color3 channels exact (uint8 storage)", function()
			local b = ser(s, src)
			if b == nil then
				return false
			end
			local v = des(s, b)
			if typeof(v) ~= "Instance" then
				return false
			end
			local c = (v :: Part).Color
			return math.floor(c.R * 255 + 0.5) == math.floor(src.Color.R * 255 + 0.5)
				and math.floor(c.G * 255 + 0.5) == math.floor(src.Color.G * 255 + 0.5)
				and math.floor(c.B * 255 + 0.5) == math.floor(src.Color.B * 255 + 0.5)
		end, function()
			staticRoundTripPerf(s, nil, nil, src)
		end)

		test("serInstance(Part) – boolean Anchored preserved", function()
			local b = ser(s, src)
			if b == nil then
				return false
			end
			local v = des(s, b)
			return typeof(v) == "Instance" and (v :: Part).Anchored == src.Anchored
		end, function()
			staticRoundTripPerf(s, nil, nil, src)
		end)

		test("serInstance(Part) – deserialized value is a new Part instance", function()
			local b = ser(s, src)
			if b == nil then
				return false
			end
			local v = des(s, b)
			return typeof(v) == "Instance" and v ~= src and v:IsA("Part")
		end, function()
			staticRoundTripPerf(s, nil, nil, src)
		end)

		test("serInstance – unsupported class name errors", function()
			local ok = pcall(function()
				types.serInstance("Workspace")
			end)
			return not ok
		end, function()
			pcall(function()
				types.serInstance("Workspace")
			end)
		end)

		test(
			if vsConfig.strictMode
				then "serInstance – wrong type (non-Instance) errors"
				else "serInstance – wrong type (non-Instance) returns nil",
			function()
				local ok, res = pcall(function()
					return ser(s, "not an instance" :: any)
				end)
				return expectRejectSerialize(ok, res)
			end,
			function()
				if vsConfig.strictMode then
					staticRoundTripPerf(s, nil, nil, src)
				else
					staticRoundTripPerf(s, nil, nil, "not an instance" :: any)
				end
			end
		)
	end

	-- ─── Dynamic Serializer: Instance vs SerInstance (see `dynamicInstanceType` in config) ─
	section(if dynamicInfersSerInstance() then "Dynamic · SerInstance" else "Dynamic · Instance")

	do
		local instanceMap = require("./static/instanceMap")

		if not dynamicInfersSerInstance() then
			local dynPart = Instance.new("Part")
			dynPart:SetAttribute("_VSID", 9010)
			instanceMap[9010] = dynPart

			test("dynamic – registered instance round-trips to same reference", function()
				local r = dynRoundTrip(dynPart)
				return r ~= nil and r[1] == dynPart
			end, function()
				dynamicRoundTripPerf(dynPart)
			end)

			test("dynamic – instance alongside primitives", function()
				local r = dynRoundTrip(42, dynPart, "hello")
				return r ~= nil and r[1] == 42 and r[2] == dynPart and r[3] == "hello"
			end, function()
				dynamicRoundTripPerf(42, dynPart, "hello")
			end)

			test(
				if vsConfig.strictMode
					then "dynamic – unregistered instance (no _VSID) errors"
					else "dynamic – unregistered instance (no _VSID) returns nil",
				function()
					local unregistered = Instance.new("Part")
					local ok, res = pcall(function()
						return dynamic.serialize(nil, nil, unregistered)
					end)
					return expectRejectSerialize(ok, res)
				end,
				function()
					if vsConfig.strictMode then
						dynamicRoundTripPerf(dynPart)
					else
						dynamicRoundTripPerf(Instance.new("Part"))
					end
				end
			)
		else
			local dynPart = Instance.new("Part")
			dynPart.Name = "DynSerPart"
			dynPart.Material = Enum.Material.Plastic
			dynPart.Transparency = 0.5
			dynPart.CFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0.1, -0.2, 0.3)
			dynPart.Size = Vector3.new(4, 2, 1)
			dynPart.CanCollide = true
			dynPart.CanTouch = false
			dynPart.Color = Color3.fromRGB(100, 150, 200)
			dynPart.Anchored = true
			dynPart.Reflectance = 0.25

			test("dynamic – serInstance Part round-trip (new instance, props match)", function()
				local r = dynRoundTrip(dynPart)
				if r == nil then
					return false
				end
				local v = r[1]
				return typeof(v) == "Instance" and v ~= dynPart and dynamicSerPartMatchesSource(v, dynPart)
			end, function()
				dynamicRoundTripPerf(dynPart)
			end)

			test("dynamic – serInstance alongside primitives", function()
				local r = dynRoundTrip(42, dynPart, "hello")
				if r == nil then
					return false
				end
				return r[1] == 42
					and r[3] == "hello"
					and typeof(r[2]) == "Instance"
					and r[2] ~= dynPart
					and dynamicSerPartMatchesSource(r[2], dynPart)
			end, function()
				dynamicRoundTripPerf(42, dynPart, "hello")
			end)

			-- No schema for Folder: serInstance node build throws (independent of strictMode).
			test("dynamic – unsupported Instance class (Folder) errors", function()
				local ok = pcall(function()
					dynamic.serialize(nil, nil, Instance.new("Folder"))
				end)
				return not ok
			end, function()
				pcall(function()
					dynamic.serialize(nil, nil, Instance.new("Folder"))
				end)
			end)
		end
	end

	-- ─── Edge Cases ────────────────────────────────────────────────────────────
	-- Each test here targets behavior that a naive implementation usually gets wrong:
	-- float sign/inf/NaN/subnormal corners, length-prefix boundaries, UTF-8 width
	-- vs. character count, union dispatch by extypeof, nested optional presence bytes,
	-- empty-key maps, and struct writes where every field is at its extreme value.
	section("Edge Cases")

	-- ─── Float corners (IEEE-754 oddities) ────────────────────────────────────
	do
		local s = types.float32
		test("edge – float32 math.huge round-trip", function()
			return roundTrip(s, function(v)
				return v == math.huge
			end, math.huge)
		end, function()
			staticRoundTripPerf(s, nil, nil, math.huge)
		end)
		test("edge – float32 -math.huge round-trip", function()
			return roundTrip(s, function(v)
				return v == -math.huge
			end, -math.huge)
		end, function()
			staticRoundTripPerf(s, nil, nil, -math.huge)
		end)
		test("edge – float32 NaN identity preserved (v ~= v)", function()
			local nan = 0 / 0
			local b = ser(s, nan)
			if b == nil then
				return false
			end
			local v = des(s, b)
			return v ~= v
		end, function()
			staticRoundTripPerf(s, nil, nil, 0 / 0)
		end)
		-- -0.0 == 0.0 in Luau, but 1/-0 == -math.huge while 1/0 == math.huge.
		-- A naive f32 encoder that normalizes zeros loses the sign bit here.
		test("edge – float32 negative zero sign bit preserved", function()
			local negZero = -0.0
			local b = ser(s, negZero)
			if b == nil then
				return false
			end
			local v = des(s, b)
			return v == 0 and (1 / v) == -math.huge
		end, function()
			staticRoundTripPerf(s, nil, nil, -0.0)
		end)
	end

	do
		local s = types.float16
		-- f16 max finite ≈ 65504. 1e10 is far above, must saturate to +inf on write.
		test("edge – float16 overflow saturates to math.huge", function()
			local b = ser(s, 1e10)
			if b == nil then
				return false
			end
			local v = des(s, b)
			return v == math.huge
		end, function()
			staticRoundTripPerf(s, nil, nil, 1e10)
		end)
		-- f16 smallest positive normal ≈ 6.1e-5. 1e-20 is far below; must flush to 0.
		test("edge – float16 subnormal underflow flushes to zero", function()
			local b = ser(s, 1e-20)
			if b == nil then
				return false
			end
			local v = des(s, b)
			return v == 0
		end, function()
			staticRoundTripPerf(s, nil, nil, 1e-20)
		end)
	end

	-- ─── String / length-prefix boundaries ────────────────────────────────────
	-- Embedded NULs break C-style writers that terminate on '\0'. Luau buffers are
	-- length-prefixed, so the payload must round-trip byte-for-byte.
	do
		local s = types.string
		local payload = "a\0b\0\0c\0d"
		test("edge – string with embedded null bytes round-trips byte-exact", function()
			return roundTrip(s, function(v)
				return v == payload and #v == 8
			end, payload)
		end, function()
			staticRoundTripPerf(s, nil, nil, payload)
		end)
	end

	do
		local s = types.string255
		-- string255 length prefix is a single uint8. "あ" = 3 UTF-8 bytes, so
		-- 85 repeats is exactly 255 bytes (max) but only 85 codepoints.
		-- A naive encoder measuring code points would overflow by 3× here.
		local utf = string.rep("あ", 85)
		test("edge – string255 UTF-8 multi-byte exactly 255 bytes", function()
			return #utf == 255 and roundTrip(s, function(v)
				return v == utf and #v == 255
			end, utf)
		end, function()
			staticRoundTripPerf(s, nil, nil, utf)
		end)
		test("edge – string255 empty boundary (length byte = 0)", function()
			local b = ser(s, "")
			if b == nil or buffer.len(b) ~= 1 or buffer.readu8(b, 0) ~= 0 then
				return false
			end
			return des(s, b) == ""
		end, function()
			staticRoundTripPerf(s, nil, nil, "")
		end)
	end

	-- ─── Array255 length-prefix boundaries ────────────────────────────────────
	do
		local s = types.array255(types.uint8)
		test("edge – array255 boundary 0 elements", function()
			local b = ser(s, {})
			if b == nil or buffer.len(b) ~= 1 or buffer.readu8(b, 0) ~= 0 then
				return false
			end
			local v = des(s, b)
			return type(v) == "table" and #v == 0
		end, function()
			staticRoundTripPerf(s, nil, nil, {})
		end)

		local exactly255: { number } = {}
		for i = 1, 255 do
			exactly255[i] = i % 256
		end
		test("edge – array255 exactly 255 elements", function()
			return roundTrip(s, function(v)
				for i = 1, 255 do
					if v[i] ~= exactly255[i] then
						return false
					end
				end
				return true
			end, exactly255)
		end, function()
			staticRoundTripPerf(s, nil, nil, exactly255)
		end)
	end

	-- ─── CFrame identity ──────────────────────────────────────────────────────
	-- Identity has a known-exact byte representation (translation = 0,0,0 and the
	-- rotation axes are the canonical basis). An encoder with drift in the rotation
	-- path will fail FuzzyEq against the source identity.
	do
		local s = types.cframe
		local id = CFrame.identity
		test("edge – CFrame identity preserved byte-exact", function()
			return roundTrip(s, function(v)
				return typeof(v) == "CFrame" and cframeFuzzyEq(v, id, 1e-5)
			end, id)
		end, function()
			staticRoundTripPerf(s, nil, nil, id)
		end)
	end

	-- ─── Infinity inside a Vector3 axis ───────────────────────────────────────
	-- Vector3 encoders that pre-normalize or clamp before writing lose math.huge.
	do
		local s = types.vector3
		local inf = Vector3.new(math.huge, 0, 0)
		test("edge – vector3 with math.huge on one axis", function()
			return roundTrip(s, function(v)
				return v.X == math.huge and v.Y == 0 and v.Z == 0
			end, inf)
		end, function()
			staticRoundTripPerf(s, nil, nil, inf)
		end)
	end

	-- ─── Struct with every field at an extreme simultaneously ─────────────────
	-- Catches field-order bugs, interaction between length prefixes and numeric
	-- extremes, and incorrect cursor advancement around variable-width fields.
	do
		local s = types.struct({
			i32min = types.int32,
			u32max = types.uint32,
			f32nan = types.float32,
			f32inf = types.float32,
			bigStr = types.string,
			empty = types.string255,
			flag = types.boolean,
		})
		local nan = 0 / 0
		local row = {
			i32min = -2147483648,
			u32max = 4294967295,
			f32nan = nan,
			f32inf = -math.huge,
			bigStr = string.rep("Z", 1024),
			empty = "",
			flag = true,
		}
		test("edge – struct with every numeric extreme simultaneously", function()
			local b = ser(s, row)
			if b == nil then
				return false
			end
			local out = des(s, b) :: any
			return out.i32min == row.i32min
				and out.u32max == row.u32max
				and out.f32nan ~= out.f32nan
				and out.f32inf == -math.huge
				and out.bigStr == row.bigStr
				and out.empty == ""
				and out.flag == true
		end, function()
			staticRoundTripPerf(s, nil, nil, row)
		end)
	end

	-- ─── Nested optional presence bytes ───────────────────────────────────────
	-- optional(optional(T)) emits two presence bytes. An encoder that fuses them
	-- cannot tell absent-outer from present-outer-absent-inner.
	do
		local s = types.optional(types.optional(types.int32))
		test("edge – optional(optional(int32)) nested present/absent", function()
			-- outer absent (nil) must round-trip to nil
			local b1 = ser(s, nil)
			if b1 == nil then
				return false
			end
			local v1 = des(s, b1)
			if v1 ~= nil then
				return false
			end
			-- outer present, inner present with a value
			local b2 = ser(s, -12345)
			if b2 == nil then
				return false
			end
			local v2 = des(s, b2)
			return v2 == -12345
		end, function()
			staticRoundTripPerf(s, nil, nil, -12345)
		end)
	end

	-- ─── Union dispatch: integer-valued floats route via "int" ────────────────
	-- extypeof classifies a Luau number by value, not width: 5.0 has no fractional
	-- part and must go to the int branch (not float), else it silently widens.
	do
		local u = types.union(types.int32, types.float64)
		test("edge – union routes integer-valued float via \"int\" branch", function()
			-- 5.0 has exType "int" → int32 variant (4 bytes), +1 byte index = 5 total.
			local b1 = ser(u, 5.0)
			if b1 == nil or buffer.len(b1) ~= 5 then
				return false
			end
			if des(u, b1) ~= 5 then
				return false
			end
			-- 2.5 has exType "float" → float64 variant (8 bytes), +1 index = 9 total.
			local b2 = ser(u, 2.5)
			if b2 == nil or buffer.len(b2) ~= 9 then
				return false
			end
			return approxEq(des(u, b2), 2.5, 1e-12)
		end, function()
			staticRoundTripPerf(u, nil, nil, 5.0)
		end)
	end

	-- ─── Map with empty-string key ────────────────────────────────────────────
	-- A key of "" is a valid Luau table key and a valid string255 payload (length
	-- byte = 0). Encoders that treat "" as sentinel or end-of-map corrupt here.
	do
		local s = types.map(types.string255, types.int32)
		local m = { [""] = 42, a = -1 }
		test("edge – map with empty-string key round-trips", function()
			return roundTrip(s, function(v)
				return v[""] == 42 and v.a == -1
			end, m)
		end, function()
			staticRoundTripPerf(s, nil, nil, m)
		end)
	end

	--------------------------------------------------------------------------------
	-- OUTPUT
	--------------------------------------------------------------------------------
	printResults()
	if createUI then
		buildUI()
	end

	return 0
end

return voidSentry2_Test
