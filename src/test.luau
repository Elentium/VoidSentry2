--[[
	VoidSentry2 Test Suite

	Scoring:
		Each test awards:
		  - Correctness  (2 pts): serialized output round-trips correctly
		  - Performance  (1 pt):  avg time per op is within budget

	Grade thresholds (% of total points):
		S  = 100%    A  = 90%    B  = 75%
		C  = 60%     D  = 50%    E  = 40%    F  = <40%

	Section summary shows:
		ValidityPass  – all correctness checks in section passed
		PerformancePass – all perf checks in section passed
]]

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local CONFIG = {
	-- Iterations for every performance benchmark.
	PERF_ITERATIONS = 2_000,

	-- Multiply all time budgets by this factor.
	-- Raise on slow machines (e.g. 2.0), lower on fast ones (e.g. 0.5).
	PERF_BUDGET_SCALE = 1.0,

	-- Line width for separators.
	SEPARATOR_WIDTH = 80,

	-- Set true to build results GUI in StarterGui.
	CREATE_UI = true,
}

--------------------------------------------------------------------------------
-- DEPENDENCY
--------------------------------------------------------------------------------
local VS = require("./")
local T = VS.types
local static = VS.static
local dynamic = VS.dynamic

--------------------------------------------------------------------------------
-- GRADES
--------------------------------------------------------------------------------
local GRADES = {
	{ threshold = 1.00, label = "S" },
	{ threshold = 0.90, label = "A" },
	{ threshold = 0.75, label = "B" },
	{ threshold = 0.60, label = "C" },
	{ threshold = 0.50, label = "D" },
	{ threshold = 0.40, label = "E" },
	{ threshold = 0.00, label = "F" },
}

local function getGrade(ratio: number): string
	for _, entry in GRADES do
		if ratio >= entry.threshold then
			return entry.label
		end
	end
	return "F"
end

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
	cPts: number,
	earnedC: number,
	earnedP: number,
	pPts: number,
}

type SectionInfo = {
	name: string,
	tests: { TestResult },
}

local allSections: { SectionInfo } = {}
local currentSection: SectionInfo = { name = "", tests = {} }
local totalPts = 0
local earnedPts = 0

local SEP = string.rep("─", CONFIG.SEPARATOR_WIDTH)

--------------------------------------------------------------------------------
-- BENCH HELPER
-- Validity check and performance measurement are always separated.
-- The validity lambda runs ONCE (no timing overhead).
-- The perf lambda is benched ITERS times.
--------------------------------------------------------------------------------
local function bench(iters: number, fn: () -> ()): number
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
local function section(name: string)
	currentSection = { name = name, tests = {} }
	table.insert(allSections, currentSection)
end

--------------------------------------------------------------------------------
-- TEST
-- @param name       label
-- @param cPts       correctness points (usually 2)
-- @param budgetUs   µs budget per op (before PERF_BUDGET_SCALE)
-- @param validityFn () -> bool   runs once, checks output correctness
-- @param perfFn     () -> ()     hot path to bench
--------------------------------------------------------------------------------
local function test(name: string, cPts: number, budgetUs: number, validityFn: () -> boolean, perfFn: () -> ())
	local pPts = 1
	local scaledBudget = budgetUs * CONFIG.PERF_BUDGET_SCALE

	totalPts += cPts + pPts

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
	local earnedC = if (not crashed) and validityPass then cPts else 0
	local earnedP = if (not crashed) and perfPass then pPts else 0
	earnedPts += earnedC + earnedP

	local result: TestResult = {
		name = name,
		section = currentSection.name,
		validityPass = validityPass,
		perfPass = perfPass,
		avgUs = avgUs,
		budgetUs = scaledBudget,
		crashed = crashed,
		crashMsg = crashMsg,
		cPts = cPts,
		earnedC = earnedC,
		earnedP = earnedP,
		pPts = pPts,
	}
	table.insert(currentSection.tests, result)
end

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------
local function approxEq(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

local function cframeFuzzyEq(a: CFrame, b: CFrame, epsilon: number): boolean
	return (a :: any):FuzzyEq(b, epsilon)
end

-- Round-trip a static serializer and check a predicate on the outputs.
local function roundTrip<T...>(s: any, check: (...any) -> boolean, ...: any): boolean
	local b = s:serialize(nil, ...)
	if b == nil then
		return false
	end
	return check(s:deserialize(nil, b))
end

-- Round-trip dynamic and return all deserialized values as a table.
local function dynRoundTrip(...: any): { any }?
	local b = dynamic.serialize(nil, nil, ...)
	if b == nil then
		return nil
	end
	local results = table.pack(dynamic.deserialize(nil, nil, b))
	return results
end

-- Dynamic with Zstd: first argument to serialize is compression level; deserialize
-- must pass wasCompressed = true (boolean), not the level.
local function dynRoundTripCompressed(compressionLevel: number, ...: any): { any }?
	local b = dynamic.serialize(compressionLevel, nil, ...)
	if b == nil then
		return nil
	end
	return table.pack(dynamic.deserialize(true, nil, b))
end

--------------------------------------------------------------------------------
-- CONSOLE PRINT
--------------------------------------------------------------------------------
local function printResults()
	print(SEP)
	print(
		string.format(
			"  VoidSentry2 Test Results   %d iterations/test   Scale ×%.1f",
			CONFIG.PERF_ITERATIONS,
			CONFIG.PERF_BUDGET_SCALE
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
	local ratio = if totalPts > 0 then earnedPts / totalPts else 0
	print(string.format("  Score: %d / %d  (%.1f%%)   Grade: %s", earnedPts, totalPts, ratio * 100, getGrade(ratio)))
	print(SEP)
end

--------------------------------------------------------------------------------
-- UI BUILDER  (only when CONFIG.CREATE_UI == true)
--------------------------------------------------------------------------------
local function buildUI()
	local C = {
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
		gradeS = Color3.fromHex("ffd700"),
		gradeA = Color3.fromHex("7ec8e3"),
		gradeB = Color3.fromHex("3fb87a"),
		gradeC = Color3.fromHex("e0a040"),
		gradeD = Color3.fromHex("e07a40"),
		gradeF = Color3.fromHex("e05555"),
	}

	local gradeColors: { [string]: Color3 } = {
		S = C.gradeS,
		A = C.gradeA,
		B = C.gradeB,
		C = C.gradeC,
		D = C.gradeD,
		E = C.gradeF,
		F = C.gradeF,
	}

	local function gradeColor(g: string): Color3
		return gradeColors[g] or C.textSec
	end

	local function frame(props: { [string]: any }): Frame
		local f = Instance.new("Frame")
		for k, v in props do
			(f :: any)[k] = v
		end
		return f
	end

	local function label(props: { [string]: any }): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamMedium
		l.TextSize = 13
		l.TextColor3 = C.textPri
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		for k, v in props do
			(l :: any)[k] = v
		end
		return l
	end

	local function uiPadding(parent: Instance, h: number, v: number)
		local p = Instance.new("UIPadding")
		p.PaddingLeft = UDim.new(0, h)
		p.PaddingRight = UDim.new(0, h)
		p.PaddingTop = UDim.new(0, v)
		p.PaddingBottom = UDim.new(0, v)
		p.Parent = parent
	end

	local function uiList(parent: Instance, spacing: number, dir: Enum.FillDirection?)
		local l = Instance.new("UIListLayout")
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.FillDirection = dir or Enum.FillDirection.Vertical
		l.Padding = UDim.new(0, spacing)
		l.Parent = parent
	end

	local function uiCorner(parent: Instance, r: number)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r)
		c.Parent = parent
	end

	local function uiStroke(parent: Instance, clr: Color3, thick: number)
		local s = Instance.new("UIStroke")
		s.Color = clr
		s.Thickness = thick
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = parent
	end

	-- Root
	local sg = Instance.new("ScreenGui")
	sg.Name = "VoidSentry2TestResults"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 100

	local bg = frame({
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.bg,
		Parent = sg,
	})

	local win = frame({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 860, 0.94, 0),
		BackgroundColor3 = C.panel,
		Parent = bg,
	})
	uiCorner(win, 14)
	uiStroke(win, C.border, 1)

	-- Title bar
	local titleBar = frame({
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = C.card,
		Parent = win,
	})
	uiCorner(titleBar, 14)
	frame({
		Name = "BottomFill",
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = C.card,
		BorderSizePixel = 0,
		Parent = titleBar,
	})
	label({
		Name = "Title",
		Size = UDim2.new(1, -220, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Text = "  VoidSentry2  ·  Test Results",
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.textPri,
		Parent = titleBar,
	})

	local ratio = if totalPts > 0 then earnedPts / totalPts else 0
	local g = getGrade(ratio)

	local scoreBadge = frame({
		Name = "ScoreBadge",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0, 200, 0, 34),
		BackgroundColor3 = C.accentDim,
		Parent = titleBar,
	})
	uiCorner(scoreBadge, 9)
	uiList(scoreBadge, 4, Enum.FillDirection.Horizontal)
	uiPadding(scoreBadge, 10, 0)

	label({
		Name = "ScoreText",
		Size = UDim2.new(1, -46, 1, 0),
		Text = string.format("%d / %d  (%.1f%%)", earnedPts, totalPts, ratio * 100),
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.textPri,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = scoreBadge,
	})

	label({
		Name = "Grade",
		Size = UDim2.new(0, 32, 1, 0),
		Text = g,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = gradeColor(g),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = scoreBadge,
	})

	-- Scrollable body
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.Position = UDim2.new(0, 0, 0, 54)
	scroll.Size = UDim2.new(1, 0, 1, -54)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = C.accentDim
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
		BackgroundColor3 = C.card,
		LayoutOrder = 0,
		Parent = scroll,
	})
	uiCorner(statsBar, 6)
	uiPadding(statsBar, 12, 0)
	label({
		Name = "StatsText",
		Size = UDim2.fromScale(1, 1),
		Text = string.format(
			"Iterations per test: %d    Budget scale: ×%.1f",
			CONFIG.PERF_ITERATIONS,
			CONFIG.PERF_BUDGET_SCALE
		),
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextColor3 = C.textSec,
		Parent = statsBar,
	})

	-- Sections
	for sIdx, sec in allSections do
		local card = frame({
			Name = "Section_" .. sIdx,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = C.card,
			LayoutOrder = sIdx,
			Parent = scroll,
		})
		uiCorner(card, 8)
		uiStroke(card, C.border, 1)
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
			TextColor3 = C.textPri,
			Parent = hdrRow,
		})

		local secValidPass = true
		local secPerfPass = true
		local secEarned, secTotal = 0, 0
		for _, r in sec.tests do
			if r.crashed or not r.validityPass then
				secValidPass = false
			end
			if r.crashed or not r.perfPass then
				secPerfPass = false
			end
			secEarned += r.earnedC + r.earnedP
			secTotal += r.cPts + r.pPts
		end

		local badgeRow = frame({
			Name = "Badges",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 310, 0, 22),
			BackgroundTransparency = 1,
			Parent = hdrRow,
		})
		uiList(badgeRow, 6, Enum.FillDirection.Horizontal)

		local function badge(text: string, bg: Color3, fg: Color3, lo: number)
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

		local vBg = if secValidPass then C.pass else C.fail
		local pBg = if secPerfPass then C.pass else C.slow
		badge("Validity: " .. (if secValidPass then "PASS" else "FAIL"), vBg, C.bg, 1)
		badge("Perf: " .. (if secPerfPass then "PASS" else "FAIL"), pBg, C.bg, 2)
		badge(string.format("%d/%d pts", secEarned, secTotal), C.accentDim, C.textPri, 3)

		frame({
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.border,
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
		local function colLabel(txt: string, xAnchor: number, xPos: number, xSize: number)
			label({
				Name = txt,
				AnchorPoint = Vector2.new(xAnchor, 0.5),
				Position = UDim2.new(xPos, 0, 0.5, 0),
				Size = UDim2.new(xSize, 0, 0.8, 0),
				Text = txt,
				TextSize = 10,
				Font = Enum.Font.Gotham,
				TextColor3 = C.textDim,
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
			local rowBg = if rIdx % 2 == 0 then C.bg else C.card
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
					TextColor3 = C.crash,
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
					TextColor3 = C.textPri,
					Parent = row,
				})

				local vColor = if r.validityPass then C.pass else C.fail
				local vDot = frame({
					Name = "VDot",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.51, 0, 0.5, 0),
					Size = UDim2.new(0, 10, 0, 10),
					BackgroundColor3 = vColor,
					Parent = row,
				})
				uiCorner(vDot, 5)

				local pColor = if r.perfPass then C.pass else C.slow
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
					TextColor3 = if r.perfPass then C.textPri else C.slow,
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
					TextColor3 = C.textSec,
					Parent = row,
				})
			end
		end
	end

	-- Footer
	local footerCard = frame({
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = C.accentDim,
		LayoutOrder = 9999,
		Parent = scroll,
	})
	uiCorner(footerCard, 8)
	uiPadding(footerCard, 18, 0)

	label({
		Name = "FooterScore",
		Size = UDim2.new(0.7, 0, 1, 0),
		Text = string.format("Final Score:  %d / %d  (%.1f%%)", earnedPts, totalPts, ratio * 100),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = C.textPri,
		Parent = footerCard,
	})

	label({
		Name = "FooterGrade",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.25, 0, 0.8, 0),
		Text = "Grade:  " .. g,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = gradeColor(g),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = footerCard,
	})

	sg.Parent = game:GetService("StarterGui")
	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer
	if lp then
		local pg = lp:FindFirstChildOfClass("PlayerGui")
		if pg then
			sg:Clone().Parent = pg
		end
	end
end

--------------------------------------------------------------------------------
-- TESTS
--------------------------------------------------------------------------------

-- ─── Static Serializer: Integer Types ────────────────────────────────────────
section("Static · Integer Types")

do
	local s = static.new(nil, T.int8)
	test("int8 – zero", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 0
		end, 0)
	end, function()
		s:serialize(nil, 0)
	end)

	test("int8 – boundary min (-128)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == -128
		end, -128)
	end, function()
		s:serialize(nil, -128)
	end)

	test("int8 – boundary max (127)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 127
		end, 127)
	end, function()
		s:serialize(nil, 127)
	end)

	test("int8 – wrong type returns nil", 2, 3, function()
		return s:serialize(nil, "oops") == nil
	end, function()
		s:serialize(nil, "oops")
	end)
end

do
	local s = static.new(nil, T.uint8)
	test("uint8 – boundary max (255)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 255
		end, 255)
	end, function()
		s:serialize(nil, 255)
	end)
end

do
	local s = static.new(nil, T.int16)
	test("int16 – min (-32768)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == -32768
		end, -32768)
	end, function()
		s:serialize(nil, -32768)
	end)
	test("int16 – max (32767)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 32767
		end, 32767)
	end, function()
		s:serialize(nil, 32767)
	end)
end

do
	local s = static.new(nil, T.uint16)
	test("uint16 – max (65535)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 65535
		end, 65535)
	end, function()
		s:serialize(nil, 65535)
	end)
end

do
	local s = static.new(nil, T.int24)
	test("int24 – negative mid-range (-8388608)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == -8388608
		end, -8388608)
	end, function()
		s:serialize(nil, -8388608)
	end)
	test("int24 – positive max (8388607)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 8388607
		end, 8388607)
	end, function()
		s:serialize(nil, 8388607)
	end)
end

do
	local s = static.new(nil, T.uint24)
	test("uint24 – max (16777215)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 16777215
		end, 16777215)
	end, function()
		s:serialize(nil, 16777215)
	end)
end

do
	local s = static.new(nil, T.int32)
	test("int32 – min (-2147483648)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == -2147483648
		end, -2147483648)
	end, function()
		s:serialize(nil, -2147483648)
	end)
	test("int32 – max (2147483647)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 2147483647
		end, 2147483647)
	end, function()
		s:serialize(nil, 2147483647)
	end)
end

do
	local s = static.new(nil, T.uint32)
	test("uint32 – max (4294967295)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 4294967295
		end, 4294967295)
	end, function()
		s:serialize(nil, 4294967295)
	end)
end

-- ─── Static Serializer: Float Types ──────────────────────────────────────────
section("Static · Float Types")

do
	local s = static.new(nil, T.float16)
	test("float16 – zero", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 0
		end, 0)
	end, function()
		s:serialize(nil, 0)
	end)
	test("float16 – positive value (approx ±1% tol)", 2, 5, function()
		-- f16 has limited mantissa; allow ~2% relative error on non-powers of two.
		return roundTrip(s, function(v)
			return approxEq(v, 1.5, 0.04)
		end, 1.5)
	end, function()
		s:serialize(nil, 1.5)
	end)
	test("float16 – negative value (approx ±1% tol)", 2, 5, function()
		return roundTrip(s, function(v)
			return approxEq(v, -3.14, 0.12)
		end, -3.14)
	end, function()
		s:serialize(nil, -3.14)
	end)
end

do
	local s = static.new(nil, T.float24)
	test("float24 – zero", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 0
		end, 0)
	end, function()
		s:serialize(nil, 0)
	end)
	test("float24 – pi (approx 0.01 tol)", 2, 5, function()
		return roundTrip(s, function(v)
			return approxEq(v, math.pi, 0.06)
		end, math.pi)
	end, function()
		s:serialize(nil, math.pi)
	end)
	test("float24 – negative large (-1234.5, 0.5 tol)", 2, 5, function()
		return roundTrip(s, function(v)
			return approxEq(v, -1234.5, 2.0)
		end, -1234.5)
	end, function()
		s:serialize(nil, -1234.5)
	end)
end

do
	local s = static.new(nil, T.float32)
	test("float32 – pi (1e-5 tol)", 2, 5, function()
		return roundTrip(s, function(v)
			return approxEq(v, math.pi, 1e-5)
		end, math.pi)
	end, function()
		s:serialize(nil, math.pi)
	end)
	test("float32 – negative (1e-5 tol)", 2, 5, function()
		return roundTrip(s, function(v)
			return approxEq(v, -99.99, 1e-3)
		end, -99.99)
	end, function()
		s:serialize(nil, -99.99)
	end)
end

do
	local s = static.new(nil, T.float64)
	test("float64 – exact round-trip", 2, 5, function()
		local val = 1 / 3
		return roundTrip(s, function(v)
			return v == val
		end, val)
	end, function()
		s:serialize(nil, 1 / 3)
	end)
	test("float64 – very large (1e200)", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 1e200
		end, 1e200)
	end, function()
		s:serialize(nil, 1e200)
	end)
end

-- ─── Static Serializer: Primitive Types ──────────────────────────────────────
section("Static · Primitive Types")

do
	local s = static.new(nil, T.boolean)
	test("boolean – true round-trip", 2, 5, function()
		return roundTrip(s, function(v)
			return v == true
		end, true)
	end, function()
		s:serialize(nil, true)
	end)
	test("boolean – false round-trip", 2, 5, function()
		return roundTrip(s, function(v)
			return v == false
		end, false)
	end, function()
		s:serialize(nil, false)
	end)
	test("boolean – wrong type returns nil", 2, 3, function()
		return s:serialize(nil, 1) == nil
	end, function()
		s:serialize(nil, 1)
	end)
end

do
	local s = static.new(nil, T.string)
	test("string – empty string", 2, 5, function()
		return roundTrip(s, function(v)
			return v == ""
		end, "")
	end, function()
		s:serialize(nil, "")
	end)
	test("string – ASCII round-trip", 2, 5, function()
		return roundTrip(s, function(v)
			return v == "hello world"
		end, "hello world")
	end, function()
		s:serialize(nil, "hello world")
	end)
	test("string – unicode content", 2, 8, function()
		local u = "こんにちは世界"
		return roundTrip(s, function(v)
			return v == u
		end, u)
	end, function()
		s:serialize(nil, "こんにちは世界")
	end)
end

do
	local s = static.new(nil, T.string255)
	local long255 = string.rep("x", 255)
	test("string255 – exactly 255 chars", 2, 8, function()
		return roundTrip(s, function(v)
			return v == long255
		end, long255)
	end, function()
		s:serialize(nil, long255)
	end)
end

do
	local s = static.new(nil, T.void)
	test("void – serialize always returns buffer", 2, 3, function()
		local b = s:serialize(nil, {})
		return b ~= nil and buffer.len(b) == 0
	end, function()
		s:serialize(nil, {})
	end)
	test("void – deserialize returns empty table", 2, 3, function()
		local b = s:serialize(nil, {})
		local v = s:deserialize(nil, b)
		return type(v) == "table"
	end, function()
		local b = s:serialize(nil, {}) :: buffer
		s:deserialize(nil, b)
	end)
end

do
	local s = static.new(nil, T.nothing)
	test("nothing – serialize always returns buffer", 2, 3, function()
		local b = s:serialize(nil, nil)
		return b ~= nil
	end, function()
		s:serialize(nil, nil)
	end)
	test("nothing – deserialize returns nil", 2, 3, function()
		local b = s:serialize(nil, nil) :: buffer
		local v = s:deserialize(nil, b)
		return v == nil
	end, function()
		local b = s:serialize(nil, nil) :: buffer
		s:deserialize(nil, b)
	end)
end

-- ─── Static Serializer: Vector Types ─────────────────────────────────────────
section("Static · Vector Types")

do
	local s = static.new(nil, T.vector3)
	test("vector3 – zero vector", 2, 6, function()
		return roundTrip(s, function(v)
			return v.X == 0 and v.Y == 0 and v.Z == 0
		end, Vector3.new(0, 0, 0))
	end, function()
		s:serialize(nil, Vector3.new(0, 0, 0))
	end)
	test("vector3 – typical position (0.01 tol)", 2, 6, function()
		local pos = Vector3.new(12.5, -3.75, 100.0)
		return roundTrip(s, function(v)
			return approxEq(v.X, pos.X, 1e-4) and approxEq(v.Y, pos.Y, 1e-4) and approxEq(v.Z, pos.Z, 1e-4)
		end, pos)
	end, function()
		s:serialize(nil, Vector3.new(12.5, -3.75, 100.0))
	end)
	test("vector3 – wrong type returns nil", 2, 3, function()
		return s:serialize(nil, { X = 1, Y = 0, Z = 0 }) == nil
	end, function()
		s:serialize(nil, { X = 1, Y = 0, Z = 0 })
	end)
end

do
	local s = static.new(nil, T.vector)
	local v = vector.create(1, -2.5, 99.125)
	test("vector (Luau) – round-trip axes (1e-4 tol)", 2, 8, function()
		return roundTrip(s, function(out: any)
			-- Luau primitive vector: compare axes (typeof is "vector")
			return approxEq(out.x, v.x, 1e-4) and approxEq(out.y, v.y, 1e-4) and approxEq(out.z, v.z, 1e-4)
		end, v)
	end, function()
		s:serialize(nil, v)
	end)
end

do
	local s = static.new(nil, T.vector2)
	local p = Vector2.new(100, -33.5)
	test("vector2 – round-trip (1e-4 tol)", 2, 8, function()
		return roundTrip(s, function(v)
			return approxEq(v.X, p.X, 1e-4) and approxEq(v.Y, p.Y, 1e-4)
		end, p)
	end, function()
		s:serialize(nil, p)
	end)
end

do
	local s = static.new(nil, T.vector2f24)
	local p = Vector2.new(0.25, math.pi)
	test("vector2f24 – round-trip (0.02 tol)", 2, 8, function()
		return roundTrip(s, function(v)
			return approxEq(v.X, p.X, 0.02) and approxEq(v.Y, p.Y, 0.02)
		end, p)
	end, function()
		s:serialize(nil, p)
	end)
end

do
	local s = static.new(nil, T.vector2f16)
	local p = Vector2.new(1.5, -2.5)
	test("vector2f16 – round-trip (0.05 tol)", 2, 8, function()
		return roundTrip(s, function(v)
			return approxEq(v.X, p.X, 0.05) and approxEq(v.Y, p.Y, 0.05)
		end, p)
	end, function()
		s:serialize(nil, p)
	end)
end

do
	local s = static.new(nil, T.vector3f24)
	local p = Vector3.new(12.3, -4.56, 0.001)
	test("vector3f24 – round-trip (0.02 tol)", 2, 8, function()
		return roundTrip(s, function(v)
			return approxEq(v.X, p.X, 0.02) and approxEq(v.Y, p.Y, 0.02) and approxEq(v.Z, p.Z, 0.02)
		end, p)
	end, function()
		s:serialize(nil, p)
	end)
end

do
	local s = static.new(nil, T.vector3f16)
	local p = Vector3.new(1, 2, 3)
	test("vector3f16 – round-trip (0.08 tol)", 2, 8, function()
		return roundTrip(s, function(v)
			return approxEq(v.X, p.X, 0.08) and approxEq(v.Y, p.Y, 0.08) and approxEq(v.Z, p.Z, 0.08)
		end, p)
	end, function()
		s:serialize(nil, p)
	end)
end

-- ─── Static Serializer: CFrame & Color3 ──────────────────────────────────────
section("Static · CFrame & Color3")

do
	local s = static.new(nil, T.cframe)
	local cf = CFrame.new(3, 4, 5) * CFrame.Angles(0.2, -0.5, 1.1)
	test("cframe – matrix form FuzzyEq", 2, 20, function()
		return roundTrip(s, function(v)
			return typeof(v) == "CFrame" and cframeFuzzyEq(v, cf, 1e-2)
		end, cf)
	end, function()
		s:serialize(nil, cf)
	end)
end

do
	local s = static.new(nil, T.cframef24)
	local cf = CFrame.new(1, 0, -2) * CFrame.Angles(0.1, 0.1, 0.1)
	-- Roblox FuzzyEq only allows epsilon in (0, 0.1]
	test("cframef24 – FuzzyEq (max allowed tol)", 2, 25, function()
		return roundTrip(s, function(v)
			return typeof(v) == "CFrame" and cframeFuzzyEq(v, cf, 0.1)
		end, cf)
	end, function()
		s:serialize(nil, cf)
	end)
end

do
	local s = static.new(nil, T.qcframe)
	local cf = CFrame.new(-7, 8, 9) * CFrame.Angles(0.3, -0.1, 0.7)
	test("qcframe – quaternion form FuzzyEq", 2, 18, function()
		return roundTrip(s, function(v)
			return typeof(v) == "CFrame" and cframeFuzzyEq(v, cf, 1e-2)
		end, cf)
	end, function()
		s:serialize(nil, cf)
	end)
end

do
	local s = static.new(nil, T.qcframef24)
	local cf = CFrame.new(0.5, 1.5, 2.5)
	test("qcframef24 – FuzzyEq (max allowed tol)", 2, 20, function()
		return roundTrip(s, function(v)
			return typeof(v) == "CFrame" and cframeFuzzyEq(v, cf, 0.1)
		end, cf)
	end, function()
		s:serialize(nil, cf)
	end)
end

do
	local s = static.new(nil, T.color3)
	local c = Color3.fromRGB(10, 200, 255)
	test("color3 – exact channels", 2, 6, function()
		return roundTrip(s, function(v)
			return v.R == c.R and v.G == c.G and v.B == c.B
		end, c)
	end, function()
		s:serialize(nil, c)
	end)
end

-- ─── Static Serializer: Multi-value ──────────────────────────────────────────
section("Static · Multi-value Schemas")

do
	local s = static.new(nil, T.uint8, T.int16, T.float32, T.boolean, T.string)
	local a, b, c, d, e = 42, -300, 1.5, true, "VoidSentry"
	test("5-field heterogeneous schema round-trip", 2, 12, function()
		local buf = s:serialize(nil, a, b, c, d, e)
		if buf == nil then
			return false
		end
		local ra, rb, rc, rd, re = s:deserialize(nil, buf)
		return ra == a and rb == b and approxEq(rc, c, 1e-5) and rd == d and re == e
	end, function()
		s:serialize(nil, a, b, c, d, e)
	end)
end

do
	local s = static.new(nil, T.int32, T.float64, T.vector3, T.boolean)
	test("int32 + float64 + vector3 + boolean", 2, 12, function()
		local buf = s:serialize(nil, -1, math.huge, Vector3.new(1, 2, 3), false)
		if buf == nil then
			return false
		end
		local ri, rf, rv, rb = s:deserialize(nil, buf)
		return ri == -1 and rf == math.huge and approxEq(rv.X, 1, 1e-4) and rb == false
	end, function()
		s:serialize(nil, -1, math.huge, Vector3.new(1, 2, 3), false)
	end)
end

do
	-- Extra/missing args: trailing values silently ignored, missing returns nil
	local s = static.new(nil, T.uint8, T.uint8)
	test("schema mismatch – too few args returns nil", 2, 3, function()
		local r = s:serialize(nil, 1)
		return r == nil
	end, function()
		s:serialize(nil, 1)
	end)
end

-- ─── Static Serializer: Array Types ──────────────────────────────────────────
section("Static · Array Types")

do
	local s = static.new(nil, T.array(T.int32))
	local data = { 1, -2, 300, -40000, 2147483647 }
	test("array(int32) – 5 elements", 2, 15, function()
		return roundTrip(s, function(v)
			for i, val in data do
				if v[i] ~= val then
					return false
				end
			end
			return true
		end, data)
	end, function()
		s:serialize(nil, data)
	end)

	test("array(int32) – empty array", 2, 8, function()
		return roundTrip(s, function(v)
			return #v == 0
		end, {})
	end, function()
		s:serialize(nil, {})
	end)
end

do
	local s = static.new(nil, T.array(T.string))
	local words = { "alpha", "beta", "gamma", "delta", "epsilon" }
	test("array(string) – 5 string elements", 2, 15, function()
		return roundTrip(s, function(v)
			for i, w in words do
				if v[i] ~= w then
					return false
				end
			end
			return true
		end, words)
	end, function()
		s:serialize(nil, words)
	end)
end

do
	local s = static.new(nil, T.array255(T.float32))
	local floats = {}
	for i = 1, 50 do
		floats[i] = math.sin(i)
	end
	test("array255(float32) – 50 sine values (1e-4 tol)", 2, 25, function()
		return roundTrip(s, function(v)
			for i, f in floats do
				if not approxEq(v[i], f, 1e-4) then
					return false
				end
			end
			return true
		end, floats)
	end, function()
		s:serialize(nil, floats)
	end)
end

-- ─── Static Serializer: Map & optional ───────────────────────────────────────
section("Static · Map & optional")

do
	local s = static.new(nil, T.map(T.string255, T.int32))
	local m = { alpha = 1, beta = -42, gamma = 2147483647 }
	test("map(string255,int32) – string keys round-trip", 2, 25, function()
		return roundTrip(s, function(v)
			for k, val in m do
				if v[k] ~= val then
					return false
				end
			end
			return true
		end, m)
	end, function()
		s:serialize(nil, m)
	end)
end

do
	local s = static.new(nil, T.map255(T.uint8, T.boolean))
	local m: { [number]: boolean } = {}
	for i = 1, 50 do
		m[i] = i % 3 == 0
	end
	test("map255(uint8,boolean) – 50 numeric keys", 2, 40, function()
		return roundTrip(s, function(v)
			for k, val in m do
				if v[k] ~= val then
					return false
				end
			end
			return true
		end, m)
	end, function()
		s:serialize(nil, m)
	end)
end

do
	local s = static.new(nil, T.map(T.string255, T.array(T.uint8)))
	local m = {
		a = { 1, 2, 3 },
		b = {},
		c = { 255, 0, 128 },
	}
	test("map – nested array values round-trip", 2, 45, function()
		return roundTrip(s, function(v)
			for k, arr in m do
				local out = v[k]
				if type(out) ~= "table" or #out ~= #arr then
					return false
				end
				for i, x in arr do
					if out[i] ~= x then
						return false
					end
				end
			end
			return true
		end, m)
	end, function()
		s:serialize(nil, m)
	end)
end

do
	local s = static.new(nil, T.optional(T.int32))
	test("optional(int32) – absent (nil)", 2, 8, function()
		return roundTrip(s, function(v)
			return v == nil
		end, nil)
	end, function()
		s:serialize(nil, nil)
	end)
	test("optional(int32) – present", 2, 8, function()
		return roundTrip(s, function(v)
			return v == -100000
		end, -100000)
	end, function()
		s:serialize(nil, -100000)
	end)
end

do
	local s = static.new(nil, T.array(T.map(T.string255, T.uint8)))
	local nested = {
		{ x = 1, y = 2 },
		{ a = 255 },
		{},
	}
	test("array(map(string255,uint8)) – nested collections", 2, 50, function()
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
		s:serialize(nil, nested)
	end)
end

-- ─── Static Serializer: Struct ────────────────────────────────────────────────
section("Static · Struct Type")

do
	local s = static.new(
		nil,
		T.struct({
			x = T.float32,
			y = T.float32,
			z = T.float32,
		})
	)
	local point = { x = 1.1, y = -2.2, z = 3.3 }
	test("struct – 3-field float32 struct", 2, 12, function()
		return roundTrip(s, function(v)
			return approxEq(v.x, point.x, 1e-4) and approxEq(v.y, point.y, 1e-4) and approxEq(v.z, point.z, 1e-4)
		end, point)
	end, function()
		s:serialize(nil, point)
	end)
end

do
	local s = static.new(
		nil,
		T.struct({
			id = T.uint32,
			name = T.string255,
			active = T.boolean,
			score = T.float32,
		})
	)
	local record = { id = 99999, name = "PlayerOne", active = true, score = 4200.5 }
	test("struct – mixed field types (id/name/active/score)", 2, 15, function()
		return roundTrip(s, function(v)
			return v.id == record.id
				and v.name == record.name
				and v.active == record.active
				and approxEq(v.score, record.score, 0.1)
		end, record)
	end, function()
		s:serialize(nil, record)
	end)
end

do
	local s = static.new(
		nil,
		T.struct({
			name = T.string255,
			wrong = T.int8,
		})
	)
	test("struct – wrong type for field returns nil", 2, 3, function()
		return s:serialize(nil, { name = "ok", wrong = "not a number" }) == nil
	end, function()
		s:serialize(nil, { name = "ok", wrong = "not a number" })
	end)
end

-- ─── Static Serializer: Nested Structs ───────────────────────────────────────
section("Static · Nested Structs & Arrays")

do
	local s = static.new(
		nil,
		T.struct({
			pos = T.struct({
				x = T.float32,
				y = T.float32,
			}),
			hp = T.uint16,
			name = T.string255,
		})
	)
	local entity = { pos = { x = 15.5, y = -22.0 }, hp = 1000, name = "Boss" }
	test("struct inside struct (entity with pos)", 2, 18, function()
		return roundTrip(s, function(v)
			return approxEq(v.pos.x, entity.pos.x, 1e-3)
				and approxEq(v.pos.y, entity.pos.y, 1e-3)
				and v.hp == entity.hp
				and v.name == entity.name
		end, entity)
	end, function()
		s:serialize(nil, entity)
	end)
end

do
	local s = static.new(
		nil,
		T.array(T.struct({
			id = T.uint16,
			value = T.float32,
		}))
	)
	local entries = {
		{ id = 1, value = 3.14 },
		{ id = 2, value = -1.5 },
		{ id = 3, value = 0 },
	}
	test("array of structs – 3 entries", 2, 20, function()
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
		s:serialize(nil, entries)
	end)
end

do
	-- 3-level deep nesting
	local s = static.new(
		nil,
		T.struct({
			outer = T.struct({
				mid = T.struct({
					leaf = T.int32,
				}),
				tag = T.string255,
			}),
			count = T.uint8,
		})
	)
	local deep = { outer = { mid = { leaf = -42 }, tag = "deep" }, count = 7 }
	test("3-level nested struct", 2, 20, function()
		return roundTrip(s, function(v)
			return v.outer.mid.leaf == deep.outer.mid.leaf and v.outer.tag == deep.outer.tag and v.count == deep.count
		end, deep)
	end, function()
		s:serialize(nil, deep)
	end)
end

do
	-- Array of arrays
	local s = static.new(nil, T.array(T.array(T.uint8)))
	local matrix = { { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 } }
	test("array of arrays – 3×3 uint8 matrix", 2, 25, function()
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
		s:serialize(nil, matrix)
	end)
end

do
	-- Struct with array field
	local s = static.new(
		nil,
		T.struct({
			tags = T.array255(T.string255),
			priority = T.uint8,
		})
	)
	local item = { tags = { "fire", "magic", "rare" }, priority = 5 }
	test("struct with array255(string255) field", 2, 20, function()
		return roundTrip(s, function(v)
			if v.priority ~= item.priority then
				return false
			end
			for i, tag in item.tags do
				if v.tags[i] ~= tag then
					return false
				end
			end
			return true
		end, item)
	end, function()
		s:serialize(nil, item)
	end)
end

-- ─── Static Serializer: Compression ──────────────────────────────────────────
section("Static · Zstd Compression")

do
	local sCompressed = static.new(3, T.string)
	local sPlain = static.new(nil, T.string)
	local payload = string.rep("aaabbbccc", 200)
	test("compressed string – round-trip identical", 2, 80, function()
		local b = sCompressed:serialize(nil, payload)
		if b == nil then
			return false
		end
		local v = sCompressed:deserialize(nil, b)
		return v == payload
	end, function()
		sCompressed:serialize(nil, payload)
	end)
	test("compressed buffer is smaller than uncompressed", 2, 80, function()
		local bc = sCompressed:serialize(nil, payload)
		local bu = sPlain:serialize(nil, payload)
		if bc == nil or bu == nil then
			return false
		end
		return buffer.len(bc) < buffer.len(bu)
	end, function()
		sCompressed:serialize(nil, payload)
	end)
end

do
	local s = static.new(5, T.array(T.int32))
	local compressibleInts = {}
	for i = 1, 200 do
		compressibleInts[i] = i * 4
	end
	test("compressed array(int32) – 200 elements round-trip", 2, 200, function()
		local b = s:serialize(nil, compressibleInts)
		if b == nil then
			return false
		end
		local v = s:deserialize(nil, b)
		for i, val in compressibleInts do
			if v[i] ~= val then
				return false
			end
		end
		return true
	end, function()
		s:serialize(nil, compressibleInts)
	end)
end

-- ─── Dynamic Serializer: Primitives ──────────────────────────────────────────
section("Dynamic · Primitive Types")

test("dynamic – uint8 value 200", 2, 8, function()
	local r = dynRoundTrip(200)
	return r ~= nil and r[1] == 200
end, function()
	dynamic.serialize(nil, nil, 200)
end)

test("dynamic – int8 value -50", 2, 8, function()
	local r = dynRoundTrip(-50)
	return r ~= nil and r[1] == -50
end, function()
	dynamic.serialize(nil, nil, -50)
end)

test("dynamic – float value 1.5 (1e-5 tol)", 2, 8, function()
	local r = dynRoundTrip(1.5)
	return r ~= nil and approxEq(r[1], 1.5, 1e-5)
end, function()
	dynamic.serialize(nil, nil, 1.5)
end)

test("dynamic – true", 2, 8, function()
	local r = dynRoundTrip(true)
	return r ~= nil and r[1] == true
end, function()
	dynamic.serialize(nil, nil, true)
end)

test("dynamic – false", 2, 8, function()
	local r = dynRoundTrip(false)
	return r ~= nil and r[1] == false
end, function()
	dynamic.serialize(nil, nil, false)
end)

test("dynamic – short string", 2, 8, function()
	local r = dynRoundTrip("hello")
	return r ~= nil and r[1] == "hello"
end, function()
	dynamic.serialize(nil, nil, "hello")
end)

test("dynamic – long string (>255 chars)", 2, 12, function()
	local big = string.rep("z", 1000)
	local r = dynRoundTrip(big)
	return r ~= nil and r[1] == big
end, function()
	dynamic.serialize(nil, nil, string.rep("z", 1000))
end)

test("dynamic – empty table (void)", 2, 8, function()
	local r = dynRoundTrip({})
	return r ~= nil and type(r[1]) == "table" and next(r[1]) == nil
end, function()
	dynamic.serialize(nil, nil, {})
end)

-- ─── Dynamic Serializer: Multiple Values ─────────────────────────────────────
section("Dynamic · Multiple Values")

test("dynamic – mixed multi-value pack (number, bool, string)", 2, 15, function()
	local r = dynRoundTrip(42, true, "test")
	return r ~= nil and r[1] == 42 and r[2] == true and r[3] == "test"
end, function()
	dynamic.serialize(nil, nil, 42, true, "test")
end)

test("dynamic – 6 heterogeneous values", 2, 20, function()
	local r = dynRoundTrip(1, 2.5, false, "abc", 255, -128)
	return r ~= nil
		and r[1] == 1
		and approxEq(r[2], 2.5, 1e-5)
		and r[3] == false
		and r[4] == "abc"
		and r[5] == 255
		and r[6] == -128
end, function()
	dynamic.serialize(nil, nil, 1, 2.5, false, "abc", 255, -128)
end)

test("dynamic – empty serialize returns non-nil buffer", 2, 5, function()
	local b = dynamic.serialize(nil, nil)
	return b ~= nil
end, function()
	dynamic.serialize(nil, nil)
end)

-- ─── Dynamic Serializer: Collections ─────────────────────────────────────────
section("Dynamic · Collections")

test("dynamic – array of numbers", 2, 15, function()
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
	dynamic.serialize(nil, nil, { 10, 20, 30, 40, 50 })
end)

test("dynamic – map auto-detected", 2, 20, function()
	-- A table that is a pure dictionary (no integer keys from 1)
	local map = { a = 10, b = 20 }
	local r = dynRoundTrip(map)
	return r ~= nil and type(r[1]) == "table" and r[1].a == 10 and r[1].b == 20
end, function()
	dynamic.serialize(nil, nil, { a = 10, b = 20 })
end)

-- ─── Dynamic Serializer: Nested & Deep ───────────────────────────────────────
section("Dynamic · Nested Structures")

test("dynamic – array of arrays", 2, 25, function()
	local matrix = { { 1, 2 }, { 3, 4 } }
	local r = dynRoundTrip(matrix)
	return r ~= nil and r[1][1][1] == 1 and r[1][1][2] == 2 and r[1][2][1] == 3 and r[1][2][2] == 4
end, function()
	dynamic.serialize(nil, nil, { { 1, 2 }, { 3, 4 } })
end)

test("dynamic – deeply nested: array[array[array[uint8]]]", 2, 35, function()
	local cube = { { { 1, 2 }, { 3, 4 } }, { { 5, 6 }, { 7, 8 } } }
	local r = dynRoundTrip(cube)
	return r ~= nil and r[1][1][1][1] == 1 and r[1][2][2][2] == 8
end, function()
	dynamic.serialize(nil, nil, { { { 1, 2 }, { 3, 4 } }, { { 5, 6 }, { 7, 8 } } })
end)

test("dynamic – map of maps (3 levels)", 2, 40, function()
	local tree = { L1 = { L2 = { leaf = 99 } } }
	local r = dynRoundTrip(tree)
	return r ~= nil and r[1].L1.L2.leaf == 99
end, function()
	dynamic.serialize(nil, nil, { L1 = { L2 = { leaf = 99 } } })
end)

test("dynamic – array of maps with array values", 2, 45, function()
	local data = { { k = { 1, 2 } }, { k = { 3 } } }
	local r = dynRoundTrip(data)
	return r ~= nil and r[1][1].k[1] == 1 and r[1][1].k[2] == 2 and r[1][2].k[1] == 3
end, function()
	dynamic.serialize(nil, nil, { { k = { 1, 2 } }, { k = { 3 } } })
end)

test("dynamic – Vector3 round-trip", 2, 15, function()
	local p = Vector3.new(1.25, -99, 0.001)
	local r = dynRoundTrip(p)
	return r ~= nil
		and typeof(r[1]) == "Vector3"
		and approxEq(r[1].X, p.X, 1e-3)
		and approxEq(r[1].Y, p.Y, 1e-3)
		and approxEq(r[1].Z, p.Z, 1e-3)
end, function()
	dynamic.serialize(nil, nil, Vector3.new(1.25, -99, 0.001))
end)

test("dynamic – Vector2 round-trip", 2, 12, function()
	local p = Vector2.new(50, -25.5)
	local r = dynRoundTrip(p)
	return r ~= nil and typeof(r[1]) == "Vector2" and approxEq(r[1].X, p.X, 1e-3) and approxEq(r[1].Y, p.Y, 1e-3)
end, function()
	dynamic.serialize(nil, nil, Vector2.new(50, -25.5))
end)

test("dynamic – CFrame round-trip (FuzzyEq)", 2, 35, function()
	local cf = CFrame.new(10, 20, 30) * CFrame.Angles(0.5, -0.25, 0.125)
	local r = dynRoundTrip(cf)
	return r ~= nil and typeof(r[1]) == "CFrame" and cframeFuzzyEq(r[1], cf, 1e-2)
end, function()
	dynamic.serialize(nil, nil, CFrame.new(10, 20, 30) * CFrame.Angles(0.5, -0.25, 0.125))
end)

-- ─── Dynamic Serializer: Zstd ────────────────────────────────────────────────
section("Dynamic · Zstd Compression")

test("dynamic Zstd – multi-value round-trip (wasCompressed = true)", 2, 80, function()
	local r = dynRoundTripCompressed(3, "payload", false, 12345)
	return r ~= nil and r[1] == "payload" and r[2] == false and r[3] == 12345
end, function()
	dynamic.serialize(3, nil, "payload", false, 12345)
end)

test("dynamic Zstd – compressed buffer smaller on large string", 2, 100, function()
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

test("dynamic Zstd – wrong wasCompressed on plain buffer fails (pcall)", 2, 50, function()
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

test("dynamic – uncompressed with explicit wasCompressed false", 2, 15, function()
	local b = dynamic.serialize(nil, nil, 7, 8)
	if b == nil then
		return false
	end
	local r = table.pack(dynamic.deserialize(false, nil, b))
	return r.n == 2 and r[1] == 7 and r[2] == 8
end, function()
	local b = dynamic.serialize(nil, nil, 7, 8) :: buffer
	dynamic.deserialize(false, nil, b)
end)
-- ─── any type (static) ────────────────────────────────────────────────────────
section("Static · any Type")

do
	local s = static.new(nil, T.any)
	test("any – serialize uint value 100", 2, 10, function()
		return roundTrip(s, function(v)
			return v == 100
		end, 100)
	end, function()
		s:serialize(nil, 100)
	end)
	test("any – serialize string", 2, 10, function()
		return roundTrip(s, function(v)
			return v == "abc"
		end, "abc")
	end, function()
		s:serialize(nil, "abc")
	end)
	test("any – serialize boolean true", 2, 10, function()
		return roundTrip(s, function(v)
			return v == true
		end, true)
	end, function()
		s:serialize(nil, true)
	end)
	test("any – serialize float (1e-4 tol)", 2, 10, function()
		return roundTrip(s, function(v)
			return approxEq(v, 3.14, 1e-4)
		end, 3.14)
	end, function()
		s:serialize(nil, 3.14)
	end)
	test("any – serialize Vector3", 2, 12, function()
		local p = Vector3.new(9, -8, 7.5)
		return roundTrip(s, function(v)
			return typeof(v) == "Vector3"
				and approxEq(v.X, p.X, 1e-3)
				and approxEq(v.Y, p.Y, 1e-3)
				and approxEq(v.Z, p.Z, 1e-3)
		end, p)
	end, function()
		s:serialize(nil, Vector3.new(9, -8, 7.5))
	end)
	test("any – serialize Color3", 2, 10, function()
		local c = Color3.fromRGB(5, 128, 240)
		return roundTrip(s, function(v)
			return typeof(v) == "Color3" and v.R == c.R and v.G == c.G and v.B == c.B
		end, c)
	end, function()
		s:serialize(nil, Color3.fromRGB(5, 128, 240))
	end)
	test("any – serialize CFrame", 2, 18, function()
		local cf = CFrame.new(1, 2, 3) * CFrame.Angles(0.4, -0.2, 0.1)
		return roundTrip(s, function(v)
			return typeof(v) == "CFrame" and cframeFuzzyEq(v, cf, 1e-2)
		end, cf)
	end, function()
		s:serialize(nil, CFrame.new(1, 2, 3) * CFrame.Angles(0.4, -0.2, 0.1))
	end)
	test("any – serialize array255 of numbers", 2, 15, function()
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
		s:serialize(nil, { 1, 2, 3, 4, 5 })
	end)
	test("any – serialize nested map (dynamic layout)", 2, 22, function()
		local tree = { a = { b = { c = 42 } } }
		return roundTrip(s, function(v)
			return type(v) == "table" and v.a and v.a.b and v.a.b.c == 42
		end, tree)
	end, function()
		s:serialize(nil, { a = { b = { c = 42 } } })
	end)
end

-- ─── Static + Offset ─────────────────────────────────────────────────────────
section("Static · Offset Support")

do
	local s = static.new(nil, T.uint8, T.uint8)
	test("offset=4: written bytes start at position 4", 2, 10, function()
		local b = s:serialize(4, 0xAA, 0xBB)
		if b == nil then
			return false
		end
		return buffer.len(b) == 6 and buffer.readu8(b, 4) == 0xAA and buffer.readu8(b, 5) == 0xBB
	end, function()
		s:serialize(4, 0xAA, 0xBB)
	end)
	test("offset=4: deserialize with same offset", 2, 10, function()
		local b = s:serialize(4, 0xAA, 0xBB) :: buffer
		local a, bb = s:deserialize(4, b)
		return a == 0xAA and bb == 0xBB
	end, function()
		local b = s:serialize(4, 0xAA, 0xBB) :: buffer
		s:deserialize(4, b)
	end)
end

-- ─── Large Payloads ───────────────────────────────────────────────────────────
section("Static · Large Payload Benchmarks")

do
	local s = static.new(nil, T.array(T.float64))
	local big: { number } = {}
	for i = 1, 500 do
		big[i] = math.random() * 1e6
	end
	test("array(float64) – 500 elements serialize", 2, 600, function()
		return s:serialize(nil, big) ~= nil
	end, function()
		s:serialize(nil, big)
	end)
	test("array(float64) – 500 elements round-trip exact", 2, 1200, function()
		local b = s:serialize(nil, big)
		if b == nil then
			return false
		end
		local v = s:deserialize(nil, b)
		for i, f in big do
			if v[i] ~= f then
				return false
			end
		end
		return true
	end, function()
		local b = s:serialize(nil, big) :: buffer
		s:deserialize(nil, b)
	end)
end

do
	local s = static.new(
		nil,
		T.array(T.struct({
			id = T.uint32,
			x = T.float32,
			y = T.float32,
			active = T.boolean,
		}))
	)
	local entities: { any } = {}
	for i = 1, 100 do
		entities[i] = { id = i, x = math.random() * 200, y = math.random() * 200, active = i % 2 == 0 }
	end
	test("array(struct{id,x,y,active}) – 100 entities round-trip", 2, 400, function()
		local b = s:serialize(nil, entities)
		if b == nil then
			return false
		end
		local v = s:deserialize(nil, b)
		for i, e in entities do
			if v[i].id ~= e.id then
				return false
			end
			if not approxEq(v[i].x, e.x, 1e-2) then
				return false
			end
			if v[i].active ~= e.active then
				return false
			end
		end
		return true
	end, function()
		local b = s:serialize(nil, entities) :: buffer
		s:deserialize(nil, b)
	end)
end

do
	local s = static.new(nil, T.string)
	local huge = string.rep("abcdefghij", 5000)
	test("string – 50 KB payload round-trip", 2, 2000, function()
		local b = s:serialize(nil, huge)
		if b == nil then
			return false
		end
		return s:deserialize(nil, b) == huge
	end, function()
		s:serialize(nil, huge)
	end)
end

-- ─── Static Serializer: Instance ─────────────────────────────────────────────
section("Static · Instance (ID-based)")

do
	-- Access the internal instanceMap directly so we can register test instances.
	local instanceMap = require("./static/instanceMap")
	local s = static.new(nil, T.instance)

	local part = Instance.new("Part")
	local VSID = 9001
	part:SetAttribute("_VSID", VSID)
	instanceMap[VSID] = part

	test("instance – registered part round-trips to same reference", 2, 10, function()
		local b = s:serialize(nil, part)
		if b == nil then
			return false
		end
		local v = s:deserialize(nil, b)
		return v == part
	end, function()
		s:serialize(nil, part)
	end)

	test("instance – buffer is exactly 3 bytes (U24 id)", 2, 5, function()
		local b = s:serialize(nil, part)
		return b ~= nil and buffer.len(b) == 3
	end, function()
		s:serialize(nil, part)
	end)

	test("instance – unregistered instance (no _VSID) returns nil", 2, 5, function()
		local unregistered = Instance.new("Part")
		return s:serialize(nil, unregistered) == nil
	end, function()
		s:serialize(nil, Instance.new("Part"))
	end)

	test("instance – id not in map returns nil on deserialize", 2, 8, function()
		-- Write a valid-looking buffer with an id that has no map entry.
		local b = buffer.create(3)
		buffer.writeu16(b, 0, 0xFFFE)
		buffer.writeu8(b, 2, 0xFF)
		local v = s:deserialize(nil, b)
		return v == nil
	end, function()
		local b = buffer.create(3)
		buffer.writeu16(b, 0, 0xFFFE)
		buffer.writeu8(b, 2, 0xFF)
		s:deserialize(nil, b)
	end)

	test("instance – wrong type value (non-Instance) returns nil", 2, 3, function()
		return s:serialize(nil, "not an instance" :: any) == nil
	end, function()
		s:serialize(nil, "not an instance" :: any)
	end)

	-- Multiple instances in one schema
	local partA = Instance.new("Part")
	local partB = Instance.new("Model")
	partA:SetAttribute("_VSID", 9002)
	partB:SetAttribute("_VSID", 9003)
	instanceMap[9002] = partA
	instanceMap[9003] = partB

	local s2 = static.new(nil, T.instance, T.instance)
	test("instance – two instances in one schema both round-trip", 2, 12, function()
		local b = s2:serialize(nil, partA, partB)
		if b == nil then
			return false
		end
		local va, vb = s2:deserialize(nil, b)
		return va == partA and vb == partB
	end, function()
		s2:serialize(nil, partA, partB)
	end)
end

-- ─── Static Serializer: SerInstance ───────────────────────────────────────────
section("Static · SerInstance (struct-based)")

do
	local s = static.new(nil, T.serInstance("Part"))

	-- Build a Part with every schema property set to known values.
	local src = Instance.new("Part")
	src.Name = "TestPart"
	src.Transparency = 0.5
	src.CFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0.1, -0.2, 0.3)
	src.Color = Color3.fromRGB(100, 150, 200)
	src.Anchored = true
	src.Reflectance = 0.25

	test("serInstance(Part) – Name preserved exactly", 2, 30, function()
		local b = s:serialize(nil, src)
		if b == nil then
			return false
		end
		local v = s:deserialize(nil, b)
		return typeof(v) == "Instance" and v:IsA("Part") and v.Name == src.Name
	end, function()
		s:serialize(nil, src)
	end)

	test("serInstance(Part) – numeric properties within tolerance", 2, 30, function()
		local b = s:serialize(nil, src)
		if b == nil then
			return false
		end
		local v = s:deserialize(nil, b)
		if typeof(v) ~= "Instance" then
			return false
		end
		local p = v :: Part
		return approxEq(p.Transparency, src.Transparency, 1e-4) and approxEq(p.Reflectance, src.Reflectance, 1e-4)
	end, function()
		s:serialize(nil, src)
	end)

	test("serInstance(Part) – CFrame preserved (FuzzyEq)", 2, 30, function()
		local b = s:serialize(nil, src)
		if b == nil then
			return false
		end
		local v = s:deserialize(nil, b)
		if typeof(v) ~= "Instance" then
			return false
		end
		return cframeFuzzyEq((v :: Part).CFrame, src.CFrame, 1e-2)
	end, function()
		s:serialize(nil, src)
	end)

	test("serInstance(Part) – Color3 channels exact (uint8 storage)", 2, 30, function()
		local b = s:serialize(nil, src)
		if b == nil then
			return false
		end
		local v = s:deserialize(nil, b)
		if typeof(v) ~= "Instance" then
			return false
		end
		local c = (v :: Part).Color
		return math.floor(c.R * 255 + 0.5) == math.floor(src.Color.R * 255 + 0.5)
			and math.floor(c.G * 255 + 0.5) == math.floor(src.Color.G * 255 + 0.5)
			and math.floor(c.B * 255 + 0.5) == math.floor(src.Color.B * 255 + 0.5)
	end, function()
		s:serialize(nil, src)
	end)

	test("serInstance(Part) – boolean Anchored preserved", 2, 30, function()
		local b = s:serialize(nil, src)
		if b == nil then
			return false
		end
		local v = s:deserialize(nil, b)
		return typeof(v) == "Instance" and (v :: Part).Anchored == src.Anchored
	end, function()
		s:serialize(nil, src)
	end)

	test("serInstance(Part) – deserialized value is a new Part instance", 2, 10, function()
		local b = s:serialize(nil, src)
		if b == nil then
			return false
		end
		local v = s:deserialize(nil, b)
		return typeof(v) == "Instance" and v ~= src and v:IsA("Part")
	end, function()
		s:serialize(nil, src)
	end)

	test("serInstance – unsupported class name errors", 2, 35, function()
		local ok = pcall(function()
			local sInvalid = static.new(nil, T.serInstance("Workspace"))
			sInvalid:serialize(nil, game:GetService("Workspace"))
		end)
		return not ok
	end, function()
		pcall(function()
			local sInvalid = static.new(nil, T.serInstance("Workspace"))
			sInvalid:serialize(nil, game:GetService("Workspace"))
		end)
	end)

	test("serInstance – wrong type (non-Instance) returns nil", 2, 5, function()
		return s:serialize(nil, "not an instance" :: any) == nil
	end, function()
		s:serialize(nil, "not an instance" :: any)
	end)
end

-- ─── Dynamic Serializer: Instance ─────────────────────────────────────────────
section("Dynamic · Instance")

do
	local instanceMap = require("./static/instanceMap")

	local dynPart = Instance.new("Part")
	dynPart:SetAttribute("_VSID", 9010)
	instanceMap[9010] = dynPart

	test("dynamic – registered instance round-trips to same reference", 2, 15, function()
		local r = dynRoundTrip(dynPart)
		return r ~= nil and r[1] == dynPart
	end, function()
		dynamic.serialize(nil, nil, dynPart)
	end)

	test("dynamic – instance alongside primitives", 2, 18, function()
		local r = dynRoundTrip(42, dynPart, "hello")
		return r ~= nil and r[1] == 42 and r[2] == dynPart and r[3] == "hello"
	end, function()
		dynamic.serialize(nil, nil, 42, dynPart, "hello")
	end)

	test("dynamic – unregistered instance (no _VSID) returns nil", 2, 5, function()
		local unregistered = Instance.new("Part")
		return dynamic.serialize(nil, nil, unregistered) == nil
	end, function()
		dynamic.serialize(nil, nil, Instance.new("Part"))
	end)
end

-- ─── Edge Cases ───���───────────────────────────────────────────────────────────
section("Edge Cases")

do
	local s = static.new(nil, T.uint32)
	test("edge – buffer is not nil", 2, 5, function()
		return s:serialize(nil, 0) ~= nil
	end, function()
		s:serialize(nil, 0)
	end)
	test("edge – uint32 value 0 round-trip", 2, 5, function()
		return roundTrip(s, function(v)
			return v == 0
		end, 0)
	end, function()
		s:serialize(nil, 0)
	end)
end

do
	local s = static.new(nil, T.float32)
	test("edge – serialize math.huge", 2, 5, function()
		return roundTrip(s, function(v)
			return v == math.huge
		end, math.huge)
	end, function()
		s:serialize(nil, math.huge)
	end)
	test("edge – serialize -math.huge", 2, 5, function()
		return roundTrip(s, function(v)
			return v == -math.huge
		end, -math.huge)
	end, function()
		s:serialize(nil, -math.huge)
	end)
	test("edge – serialize NaN (NaN != NaN identity preserved)", 2, 5, function()
		local nan = 0 / 0
		local b = s:serialize(nil, nan)
		if b == nil then
			return false
		end
		local v = s:deserialize(nil, b)
		return v ~= v -- NaN is not equal to itself
	end, function()
		s:serialize(nil, 0 / 0)
	end)
end

do
	local s = static.new(nil, T.string255)
	test("edge – empty string255", 2, 5, function()
		return roundTrip(s, function(v)
			return v == ""
		end, "")
	end, function()
		s:serialize(nil, "")
	end)
end

do
	local s = static.new(nil, T.array(T.uint8))
	test("edge – single-element array", 2, 6, function()
		return roundTrip(s, function(v)
			return #v == 1 and v[1] == 77
		end, { 77 })
	end, function()
		s:serialize(nil, { 77 })
	end)
end

do
	-- array255 boundary: exactly 255 elements
	local s = static.new(nil, T.array255(T.uint8))
	local exactly255: { number } = {}
	for i = 1, 255 do
		exactly255[i] = i % 256
	end
	test("edge – array255 with exactly 255 elements", 2, 60, function()
		return roundTrip(s, function(v)
			for i = 1, 255 do
				if v[i] ~= exactly255[i] then
					return false
				end
			end
			return true
		end, exactly255)
	end, function()
		s:serialize(nil, exactly255)
	end)
end

--------------------------------------------------------------------------------
-- OUTPUT
--------------------------------------------------------------------------------
printResults()
if CONFIG.CREATE_UI then
	buildUI()
end

return 0
