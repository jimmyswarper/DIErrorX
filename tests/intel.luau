-- IntelliSense: context detection, type resolution, fuzzy ranking.
local i = require(script.Parent.i)
local d = require(script.Parent.d)

local function names(result, count)
	local out = {}
	for index = 1, math.min(count or 5, #result.items) do
		out[#out + 1] = result.items[index].name
	end
	return table.concat(out, ",")
end

local function has(result, name)
	for _, item in ipairs(result.items) do
		if item.name == name then return item end
	end
	return nil
end

local expr = { kind = "expr" }

-- fuzzy ranking ---------------------------------------------------------------
check("score: subsequence matches", i.score("ffc", "FindFirstChild") ~= nil)
check("score: non-subsequence is rejected", i.score("zzz", "FindFirstChild") == nil)
check("score: capital-letter match beats scattered letters",
	i.score("ffc", "FindFirstChild") > i.score("ffc", "affectionateCurve"))
check("score: prefix beats mid-word",
	i.score("pos", "Position") > i.score("pos", "WorldPosition"))
check("score: exact wins outright",
	i.score("Size", "Size") > i.score("Size", "TextSize"))

-- word context ------------------------------------------------------------------
local result = i.complete({ text = "pri", cursor = 4, field = expr })
eq("word: print is the top hit for 'pri'", result.items[1].name, "print")
eq("word: replacement starts at the word", result.from, 1)
check("word: keywords appear too", has(result, "print") ~= nil)

result = i.complete({ text = "", cursor = 1, field = expr })
check("word: an empty field still offers something", #result.items > 10)

-- member context ------------------------------------------------------------------
result = i.complete({ text = "workspace.", cursor = 11, field = expr })
eq("member: context detected", result.kind, "member")
eq("member: base captured", result.base, "workspace")
check("member: workspace properties offered", has(result, "Gravity") ~= nil)
check("member: inherited Instance members offered", has(result, "Name") ~= nil)

result = i.complete({ text = "workspace:", cursor = 11, field = expr })
check("member: colon hides properties", has(result, "Gravity") == nil)
check("member: colon keeps methods", has(result, "FindFirstChild") ~= nil)

result = i.complete({ text = "math.", cursor = 6, field = expr })
check("library: math members offered", has(result, "clamp") ~= nil)
eq("library: math.huge is a value, not a call", has(result, "huge").insert, "huge")
eq("library: methods insert their brackets", has(result, "floor").insert, "floor()")

result = i.complete({ text = "Enum.", cursor = 6, field = expr })
check("enum: families offered", has(result, "KeyCode") ~= nil)

result = i.complete({ text = "Enum.KeyCode.", cursor = 14, field = expr })
check("enum: items offered", has(result, "Space") ~= nil)

result = i.complete({ text = "game:", cursor = 6, field = expr })
check("game: GetService offered", has(result, "GetService") ~= nil)

-- string context inside an expression ------------------------------------------------
result = i.complete({ text = 'Instance.new("Pa', cursor = 17, field = expr })
eq("string: class names inside Instance.new", result.kind, "string")
eq("string: best match first", result.items[1].name, "Part")
eq("string: replaces only the typed part", result.from, 15)

result = i.complete({ text = 'game:GetService("Tw', cursor = 20, field = expr })
eq("string: services inside GetService", result.items[1].name, "TweenService")

-- the document teaches it about your own names -----------------------------------
local doc = d.newDoc("Test")
local stack = d.newStack(doc, 0, 0)
local make = d.create(doc, "create")
make.f.name, make.f.class = "door", "Part"
d.attachToStack(doc, make, stack, nil, {})
local svc = d.create(doc, "svc")
svc.f.name = "TweenService"
d.attachToStack(doc, svc, stack, nil, {})

eq("resolve: a created instance keeps its class", i.resolveType(doc, "door"), "Part")
eq("resolve: a service block names a service", i.resolveType(doc, "TweenService"), "TweenService")

result = i.complete({ text = "door.Anch", cursor = 10, doc = doc, field = expr })
eq("document: the right property leads", result.items[1].name, "Anchored")

result = i.complete({ text = "do", cursor = 3, doc = doc, field = expr })
check("document: your own names complete", has(result, "door") ~= nil)

result = i.complete({ text = "TweenService:", cursor = 14, doc = doc, field = expr })
check("document: service methods complete", has(result, "Create") ~= nil)

-- chains and conventions ------------------------------------------------------------
eq("resolve: property chains", i.resolveType(doc, "player.Character"), "Model")
eq("resolve: Players.LocalPlayer", i.resolveType(doc, "Players.LocalPlayer"), "Player")
eq("resolve: conventional names are a last resort", i.resolveType(doc, "hum"), "Humanoid")

result = i.complete({ text = "hum.Wal", cursor = 8, doc = doc, field = expr })
eq("convention: humanoid properties", result.items[1].name, "WalkSpeed")

result = i.complete({ text = "somethingUnknown.", cursor = 18, field = expr })
check("fallback: unknown bases still offer Instance members",
	has(result, "Destroy") ~= nil)

-- non-expression fields -----------------------------------------------------------
result = i.complete({ text = "Hum", cursor = 4,
	field = { kind = "str", hint = "class" } })
eq("field: class hint", result.items[1].name, "Humanoid")

result = i.complete({ text = "", cursor = 1,
	field = { kind = "choice", options = { "min", "max" } } })
eq("field: choice lists its options", #result.items, 2)

result = i.complete({ text = "Anch", cursor = 5,
	field = { kind = "str", hint = "prop" } })
eq("field: property hint", result.items[1].name, "Anchored")

result = i.complete({ text = "x", cursor = 2, field = { kind = "name" } })
eq("field: plain name fields stay quiet", #result.items, 0)

-- signature help --------------------------------------------------------------------
local signature = i.signature("math.clamp(value, ", 19)
check("signature: found", signature ~= nil)
eq("signature: label", signature and signature.label, "clamp(n, min, max): number")
eq("signature: argument index", signature and signature.argument, 2)

signature = i.signature("print(", 7)
eq("signature: globals too", signature and signature.label, "print(...)")

signature = i.signature("workspace:FindFirstChild(", 26, doc)
eq("signature: methods on a resolved type",
	signature and signature.label, "FindFirstChild(name, recursive?): Instance?")

check("signature: nothing outside a call", i.signature("hello", 6) == nil)

-- every documented member is well formed ------------------------------------------
local checked = 0
for _, className in ipairs(i.classNames()) do
	for _, member in ipairs(i.membersOf(className)) do
		checked = checked + 1
		if not (member.name and #member.name > 0) then
			check("api: member of " .. className .. " has a name", false)
		end
		if member.kind == "method" and not string.match(member.detail or "", "^%(") then
			check("api: " .. className .. "." .. member.name ..
				" documents its arguments", false)
		end
	end
end
check("api: a useful amount of surface is covered", checked > 250, checked)

report("intellisense")
if TESTS_FAILED > 0 then error("test failures", 0) end
