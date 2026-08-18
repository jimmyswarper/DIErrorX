-- Minimal Roblox stand-ins so pure-logic modules can run under the Luau CLI.
-- Only what the tested modules actually touch is stubbed.
local function ro(name, fields)
	local t = fields or {}
	t.__typename = name
	return t
end

Color3 = {
	fromRGB = function(r, gg, b)
		return ro("Color3", { R = r / 255, G = gg / 255, B = b / 255 })
	end,
	new = function(r, gg, b) return ro("Color3", { R = r, G = gg, B = b }) end,
}
function Color3.fromHex(hex) return Color3.fromRGB(0, 0, 0) end

Vector2 = { new = function(x, y) return ro("Vector2", { X = x, Y = y }) end }

local function udim(scale, offset) return { Scale = scale, Offset = offset } end
UDim = { new = udim }
UDim2 = {
	new = function(xs, xo, ys, yo)
		return { X = udim(xs, xo), Y = udim(ys, yo) }
	end,
	fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,
	fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,
}

local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, family)
		if not enumCache[family] then
			enumCache[family] = setmetatable({}, {
				__index = function(_, item)
					return { Name = item, EnumType = family, Value = 0 }
				end,
			})
		end
		return enumCache[family]
	end,
})

TESTS_RUN = 0
TESTS_FAILED = 0

function check(label, condition, detail)
	TESTS_RUN = TESTS_RUN + 1
	if not condition then
		TESTS_FAILED = TESTS_FAILED + 1
		print("  FAIL  " .. label .. (detail and ("\n        " .. tostring(detail)) or ""))
	end
end

function eq(label, got, want)
	TESTS_RUN = TESTS_RUN + 1
	if got ~= want then
		TESTS_FAILED = TESTS_FAILED + 1
		print("  FAIL  " .. label)
		print("        want: " .. string.gsub(tostring(want), "\n", "\n              "))
		print("        got:  " .. string.gsub(tostring(got), "\n", "\n              "))
	end
end

function report(suite)
	if TESTS_FAILED == 0 then
		print(string.format("  ok    %s (%d checks)", suite, TESTS_RUN))
	else
		print(string.format("  FAILED %s: %d of %d checks failed",
			suite, TESTS_FAILED, TESTS_RUN))
	end
end
