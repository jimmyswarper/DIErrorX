-- Custom blocks: making one four ways, compiling it, using it, saving it,
-- converting code back into it, and editing it as a canvas.
local c = require(script.Parent.c)
local d = require(script.Parent.d)
local e = require(script.Parent.e)
local g = require(script.Parent.g)
local h = require(script.Parent.h)
local q = require(script.Parent.q)

local NO_HEADER = { header = false }

local function docUsing(def, fields)
	local doc = d.newDoc("Using it")
	local stack = d.newStack(doc, 0, 0)
	local block = d.create(doc, def.id)
	for key, value in pairs(fields or {}) do block.f[key] = value end
	d.attachToStack(doc, block, stack, nil, {})
	return doc, block
end

-- reading the shape out of the Luau ---------------------------------------------
local fields, slots = q.readShape("{player}.leaderstats.Coins.Value += {amount}")
eq("shape: inline placeholders are fields", table.concat(fields, ","), "player,amount")
eq("shape: and there are no slots", #slots, 0)

fields, slots = q.readShape("if {player}.Team == teamA then\n\t{body}\nend")
eq("shape: a placeholder on its own line is a slot", table.concat(slots, ","), "body")
eq("shape: the rest are still fields", table.concat(fields, ","), "player")

-- a block with no slots becomes a function ----------------------------------------
local coin = q.fromLuau("Give a coin", "{player}.leaderstats.Coins.Value += {amount}")
coin.fields[1].default = "player"
coin.fields[2].default = "1"
check("register: it builds", (q.register(coin)) ~= nil)
eq("register: it got a function name", coin.fn, "giveACoin")

local def = c.get("custom_" .. coin.id)
check("register: it is in the registry", def ~= nil)
eq("register: it lands in the custom category", def.cat, "custom")
check("register: it is a helper", def.custom.helper == true)

local doc = docUsing(def, { player = "target", amount = "5" })
local code = e.generate(doc, NO_HEADER)
eq("codegen: one function and one call", code,
	"local function giveACoin(player, amount)\n" ..
	"\tplayer.leaderstats.Coins.Value += amount\n" ..
	"end\n\n" ..
	"giveACoin(target, 5)")

-- used twice, defined once ------------------------------------------------------------
local twice = d.newDoc("Twice")
local stack = d.newStack(twice, 0, 0)
for _, who in ipairs({ "a", "b" }) do
	local block = d.create(twice, def.id)
	block.f.player, block.f.amount = who, "1"
	d.attachToStack(twice, block, stack, nil, {})
end
local twiceCode = e.generate(twice, NO_HEADER)
local _, definitions = string.gsub(twiceCode, "local function giveACoin", "")
eq("codegen: the helper is written once however often it is used", definitions, 1)

-- code comes back as the block ----------------------------------------------------------
local reimported = h.fromCode(code)
local found = nil
d.walk(reimported, function(block)
	if block.k == def.id then found = block end
end)
check("import: a call to the helper becomes the block again", found ~= nil)
eq("import: with its fields filled in", found and found.f.player, "target")
eq("import: and the second one too", found and found.f.amount, "5")

local again = e.generate(reimported, NO_HEADER)
eq("import: and the whole thing round-trips", again, code)

-- a block with a slot inlines instead ----------------------------------------------------
local guard = q.fromLuau("Only for the red team",
	"if {player}.Team == teamRed then\n\t{body}\nend")
guard.fields[1].default = "player"
q.register(guard)
local guardDef = c.get("custom_" .. guard.id)
check("slots: it is not a helper", guardDef.custom.helper == false)
eq("slots: the slot was found", #guardDef.slots, 1)

local slotDoc, slotBlock = docUsing(guardDef, { player = "who" })
local say = d.create(slotDoc, "printText")
say.f.msg = "hello"
d.attachToSlot(slotDoc, say, slotBlock, "body", nil, {})
eq("slots: it inlines with the body inside", e.generate(slotDoc, NO_HEADER),
	"if who.Team == teamRed then\n\tprint(\"hello\")\nend")

-- a block that gives a value back ------------------------------------------------------------
local dist = q.fromLuau("Distance between", "({a} - {b}).Magnitude")
dist.returns = true
dist.fields[1].default = "here"
dist.fields[2].default = "there"
q.register(dist)
local distDef = c.get("custom_" .. dist.id)
check("returns: it asks for a name to put the answer in", distDef.fields.out ~= nil)

local valueDoc = docUsing(distDef, { out = "gap", a = "one", b = "two" })
eq("returns: it assigns the call", e.generate(valueDoc, NO_HEADER),
	"local function distanceBetween(a, b)\n" ..
	"\treturn (a - b).Magnitude\n" ..
	"end\n\n" ..
	"local gap = distanceBetween(one, two)")

local valueBack = h.fromCode(e.generate(valueDoc, NO_HEADER))
eq("returns: and comes back as the block", e.generate(valueBack, NO_HEADER),
	e.generate(valueDoc, NO_HEADER))

-- made from blocks on the canvas ----------------------------------------------------------------
local source = d.newDoc("Source")
local sourceStack = d.newStack(source, 0, 0)
local loop = d.create(source, "for")
loop.f.var, loop.f.to = "i", "3"
d.attachToStack(source, loop, sourceStack, nil, {})
local inside = d.create(source, "printValue")
inside.f.value = "i"
d.attachToSlot(source, inside, loop, "body", nil, {})

local fromCanvas = q.fromBlocks(source, loop)
check("from blocks: it captured the Luau",
	string.find(fromCanvas.luau, "for i = 1, 3 do", 1, true) ~= nil, fromCanvas.luau)
q.register(fromCanvas)
check("from blocks: and it compiles", c.get("custom_" .. fromCanvas.id) ~= nil)

-- made from a function block already in the project -------------------------------------------------
local project = d.newDoc("Project")
local projectStack = d.newStack(project, 0, 0)
local define = d.create(project, "def")
define.f.name, define.f.params = "healUp", "who, amount"
d.attachToStack(project, define, projectStack, nil, {})

local fromFunction = q.fromFunctionBlock(project, define)
eq("from a function: it is named after it", fromFunction.label, "healUp")
eq("from a function: it calls it with its inputs", fromFunction.luau,
	"healUp({who}, {amount})")
eq("from a function: with one field per parameter", #fromFunction.fields, 2)

-- made from a ModuleScript --------------------------------------------------------------------------
local module = Instance.new("ModuleScript")
module.Name = "Helper"
module.Source = [[
local Helper = {}

function Helper.greet(name, loud)
	print(name)
end

function Helper.farewell(name)
	print(name)
end

return Helper
]]
local fromModule, moduleErr = q.fromModule(module, "game.ReplicatedStorage.Helper")
check("from a module: it found the functions", fromModule ~= nil, moduleErr)
eq("from a module: one block each", fromModule and #fromModule, 2)
eq("from a module: named after the function", fromModule and fromModule[1].label, "greet")
eq("from a module: calling through require", fromModule and fromModule[1].luau,
	"require(game.ReplicatedStorage.Helper).greet({name}, {loud})")

-- editing one as a canvas -----------------------------------------------------------------------------
local editable = q.fromLuau("Push a player",
	"{hum}.WalkSpeed = {speed}\n{hum}.JumpPower = 0")
local canvas, canvasErr = q.toCanvas(editable)
check("edit: it opens as blocks", canvas ~= nil,
	canvasErr and canvasErr.msg or nil)
if canvas then
	check("edit: with a block per line", d.count(canvas) == 2, d.count(canvas))
	q.fromCanvas(editable, canvas)
	eq("edit: and the placeholders survive the round trip", editable.luau,
		"{hum}.WalkSpeed = {speed}\n{hum}.JumpPower = 0")
end

-- saving the library ---------------------------------------------------------------------------------------
local saved = q.toSave(coin)
q.unregister(coin.id)
check("save: unregistering removes it from the palette", c.get("custom_" .. coin.id) == nil)
local restored = q.fromSave(saved)
check("save: it comes back", restored ~= nil)
q.register(restored)
check("save: and works again", c.get("custom_" .. restored.id) ~= nil)
eq("save: keeping its function name", restored.fn, "giveACoin")

-- a project carries the blocks it uses -----------------------------------------------------------------------
local carrier, carrierBlock = docUsing(c.get("custom_" .. restored.id),
	{ player = "p", amount = "2" })
local embedded = q.embed(carrier)
eq("embed: the project carries the block it uses", #embedded, 1)

q.unregister(restored.id)
eq("embed: which is gone from the palette", c.get("custom_" .. restored.id), nil)
eq("embed: until the project is opened again", q.adopt(embedded), 1)
check("embed: and then it is back", c.get("custom_" .. restored.id) ~= nil)

-- names never collide ------------------------------------------------------------------------------------------
local first = q.fromLuau("Do a thing", "print(1)")
q.register(first)
local second = q.fromLuau("Do a thing", "print(2)")
q.register(second)
check("names: two blocks with the same label get different functions",
	first.fn ~= second.fn, first.fn .. " vs " .. second.fn)

-- broken Luau is refused rather than half-registered -------------------------------------------------------------
local counted = #q.list()
local blank = q.fromLuau("", "")
q.register(blank)
check("empty: an empty block still compiles to something",
	#q.list() == counted + 1)

-- the library as a ModuleScript -------------------------------------------------
do
	local tricky = q.fromLuau("Say a line",
		"local said = \"he said \\\"hi\\\"\"\nprint({who} .. said)\nfor _ = 1, {times} do\n\t{body}\nend")
	tricky.doc = "Quotes, newlines, tabs -- all of it has to survive the trip."
	tricky.group = "Talking"
	tricky.fields[1].default = "\"Bob\""
	tricky.fields[2].default = "3"
	q.register(tricky)

	local source = q.toModuleSource({ tricky }, "Test project")
	check("module: it is valid Luau", (g.parse(source)) ~= nil)

	local read, err = q.fromModuleSource(source)
	check("module: it reads back", read ~= nil, tostring(err))
	eq("module: one block in, one block out", read and #read or 0, 1)

	local back = read[1]
	eq("module: the label survives", back.label, tricky.label)
	eq("module: the group survives", back.group, tricky.group)
	eq("module: the docs survive", back.doc, tricky.doc)
	eq("module: the Luau survives exactly", back.luau, tricky.luau)
	eq("module: the fields survive", #back.fields, #tricky.fields)
	eq("module: so do their defaults", back.fields[1].default, "\"Bob\"")
	eq("module: and the slots", #back.slots, #tricky.slots)
	check("module: a loaded block is a new block, not the same one",
		back.id ~= tricky.id)

	-- and it still compiles to the same code once registered
	q.register(back)
	local loadedDef = c.get("custom_" .. back.id)
	check("module: the loaded block registers", loadedDef ~= nil)
	local docA = docUsing(c.get("custom_" .. tricky.id))
	local docB = docUsing(loadedDef)
	eq("module: and writes the same Luau",
		(string.gsub(e.generate(docB, NO_HEADER), back.fn, "F")),
		(string.gsub(e.generate(docA, NO_HEADER), tricky.fn, "F")))

	-- a whole library at once
	local wholeLibrary = q.toModuleSource(nil, "Everything")
	local everything = q.fromModuleSource(wholeLibrary)
	check("module: the whole library round-trips", everything ~= nil)
	eq("module: with every block in it", everything and #everything or 0, #q.list())

	-- and rubbish is refused rather than half-read
	local _, refused = q.fromModuleSource("return 5")
	eq("module: a module that returns a number is refused",
		refused, "that module does not return a list of blocks")
	local _, broken = q.fromModuleSource("return {")
	check("module: unparseable source is refused", broken ~= nil)
	local _, dangerous = q.fromModuleSource("return { { luau = os.time() } }")
	check("module: a block whose code is an expression is refused", dangerous ~= nil)
end

report("custom blocks")
if TESTS_FAILED > 0 then error("test failures", 0) end
