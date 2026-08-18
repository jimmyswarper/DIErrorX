-- The strongest guarantee this plugin makes: code -> blocks -> code is stable,
-- and never loses a statement.
local g = require(script.Parent.g)
local h = require(script.Parent.h)
local e = require(script.Parent.e)
local d = require(script.Parent.d)

local NO_HEADER = { header = false }

-- import, emit, import again, emit again: pass two must equal pass one
local function roundTrip(label, src)
	local doc, report, err = h.fromCode(src, "T")
	if not doc then
		check(label .. ": imports", false,
			string.format("line %d: %s", err.line, err.msg))
		return nil
	end

	local first = e.generate(doc, NO_HEADER)
	local chunk, parseErr = g.parse(first)
	if not chunk then
		check(label .. ": output is valid Luau", false,
			string.format("line %d: %s\n--- output ---\n%s",
				parseErr.line, parseErr.msg, first))
		return nil
	end

	local doc2 = h.fromCode(first, "T")
	local second = e.generate(doc2, NO_HEADER)
	eq(label .. ": stable through a second pass", second, first)
	return first, report
end

-- Every construct the importer claims to understand.
local samples = {
	{ "services and locals", [[
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MAX_HEALTH = 100
local spawns = {}
local part = script.Parent
local sign: string = "hello"
]] },
	{ "instances", [[
local part = Instance.new("Part")
part.Anchored = true
part.Position = Vector3.new(0, 10, 0)
part.Color = Color3.fromRGB(255, 170, 60)
part.Transparency = 0.5
part.Parent = workspace
part:Destroy()
]] },
	{ "events", [[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

script.Parent.Touched:Connect(function(hit)
	print(hit)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		print(char)
	end)
end)

RunService.Heartbeat:Connect(function(dt)
	print(dt)
end)

script.Parent:GetPropertyChangedSignal("Transparency"):Connect(function()
	print("changed")
end)

workspace.Baseplate.Changed:Once(function(prop)
	print(prop)
end)
]] },
	{ "control flow", [[
for i = 1, 10 do
	print(i)
end

for i = 10, 1, -1 do
	print(i)
end

for _ = 1, 3 do
	print("hi")
end

for index, item in ipairs(list) do
	print(item)
end

for key, value in pairs(record) do
	print(key)
end

while running do
	task.wait(1)
end

repeat
	task.wait()
until done

do
	local scoped = 1
	print(scoped)
end
]] },
	{ "branching", [[
if hp <= 0 then
	print("dead")
elseif hp < 20 then
	print("hurt")
else
	print("fine")
end

if a and b then
	print(1)
end

if not ready then
	print(2)
end

if typeof(value) == "string" then
	print(3)
end

if part:IsA("BasePart") then
	print(4)
end

if table.find(list, "x") then
	print(5)
end

if not char then return end

if done then return end
]] },
	{ "functions", [[
local function heal(hum, amount)
	hum.Health = math.min(hum.Health + amount, hum.MaxHealth)
	return hum.Health
end

function Module:start(config)
	self.config = config
end

local ok, err = pcall(function()
	heal(nil, 10)
end)

heal(hum, 25)

local total = heal(hum, 5)

return Module
]] },
	{ "data and text", [[
local list = {}
local nums = { 1, 2, 3 }

table.insert(list, "a")
table.insert(list, 1, "b")
table.remove(list, 1)
table.sort(list)
table.clear(list)

record["key"] = 5
local value = record["key"]
local count = #list

print("hello")
print(count)
warn("careful")
score += 10
flag = not flag
name = nil
]] },
	{ "players", [[
local Players = game:GetService("Players")

for _, player in ipairs(Players:GetPlayers()) do
	local char = player.Character
	local hum = char:FindFirstChildOfClass("Humanoid")
	hum.WalkSpeed = 24
	hum:TakeDamage(10)
	char:PivotTo(CFrame.new(0, 10, 0))
	player:LoadCharacter()
end
]] },
	{ "comments are kept", [[
-- set up the door
local door = script.Parent

-- open it when touched
door.Touched:Connect(function(hit)
	-- only real characters
	print(hit)
end)
]] },
	{ "awkward but legal luau", [[
--!strict
local CollectionService = game:GetService("CollectionService")

export type Hazard = { damage: number, part: BasePart }

local registry: { [Instance]: Hazard } = {}

@native
local function compute(a: number, b: number): number
	return a // b + a % b
end

local function describe(hazard: Hazard): string
	return `{hazard.part.Name} hits for {hazard.damage}`
end

for _, part in ipairs(CollectionService:GetTagged("Hazard")) do
	local damage = part:GetAttribute("Damage") or 10
	registry[part] = { damage = damage, part = part }
	print(describe(registry[part]), compute(damage, 3))
end
]] },
	{ "unsupported code survives", [[
local mt = setmetatable({}, { __index = function(t, k) return k end })

x, y = 1, 2

function globalHelper(a)
	return a
end

local co = coroutine.create(function()
	coroutine.yield()
end)

if a then
	x, y = y, x
end
]] },
}

for _, sample in ipairs(samples) do
	roundTrip(sample[1], sample[2])
end

-- exact output for the mappings people will notice ---------------------------
local function emits(label, src, expected)
	local doc = h.fromCode(src, "T")
	if not doc then
		check(label, false, "did not import")
		return
	end
	eq(label, e.generate(doc, NO_HEADER), expected)
end

emits("import: touch event keeps its shape",
	"script.Parent.Touched:Connect(function(hit)\n\tprint(hit)\nend)",
	"script.Parent.Touched:Connect(function(hit)\n\tprint(hit)\nend)")

emits("import: elseif chain stays flat",
	"if a then\n\tprint(1)\nelseif b then\n\tprint(2)\nelse\n\tprint(3)\nend",
	"if a then\n\tprint(1)\nelseif b then\n\tprint(2)\nelse\n\tprint(3)\nend")

emits("import: service preamble is not duplicated",
	'local Players = game:GetService("Players")\n\nPlayers.PlayerAdded:Connect(function(player)\n\tprint(player)\nend)',
	'local Players = game:GetService("Players")\n\nPlayers.PlayerAdded:Connect(function(player)\n\tprint(player)\nend)')

emits("import: unknown statement kept verbatim",
	"local mt = setmetatable({}, {})",
	"local mt = setmetatable({}, {})")

emits("import: nested indentation is rebuilt",
	"while true do\n\tif a then\n\t\tprint(1)\n\tend\nend",
	"while true do\n\tif a then\n\t\tprint(1)\n\tend\nend")

emits("import: blank lines become separate stacks",
	"print(1)\n\nprint(2)",
	"print(1)\n\nprint(2)")

-- the service preamble appears for blocks that need it ------------------------
local doc = h.fromCode("workspace.Part.Touched:Connect(function(hit)\n\tprint(hit)\nend)")
local block = nil
d.walk(doc, function(b) if b.k == "onTouch" then block = b end end)
check("import: touch maps to the touch block", block ~= nil)

doc = d.newDoc("Preamble")
local stack = d.newStack(doc, 0, 0)
local join = d.create(doc, "onPlayerAdded")
join.f.player = "player"
d.attachToStack(doc, join, stack, nil, {})
local code = e.generate(doc, NO_HEADER)
check("codegen: hoists the services a block needs",
	string.find(code, 'local Players = game:GetService("Players")', 1, true) == 1, code)

-- nothing is silently dropped -------------------------------------------------
local wild = [[
local a = 1
b = 2
print(a)
if a then print(b) end
for i = 1, 2 do print(i) end
]]
local wildDoc, wildReport = h.fromCode(wild)
eq("import: reports every statement it saw", wildReport.total >= 5, true)
eq("import: nothing landed in raw", wildReport.raw, 0)

report("roundtrip")
if TESTS_FAILED > 0 then error("test failures", 0) end
