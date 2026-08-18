-- Every block in the registry must be well formed and must emit Luau that
-- actually parses -- including with children dropped into each of its slots.
local c = require(script.Parent.c)
local d = require(script.Parent.d)
local e = require(script.Parent.e)
local g = require(script.Parent.g)

local problems = c.validate()
if #problems > 0 then
	for _, problem in ipairs(problems) do
		check("registry: " .. problem, false)
	end
else
	TESTS_RUN = TESTS_RUN + 1
end

-- category shape ---------------------------------------------------------------
local teaching = 0
for _, cat in ipairs(c.cats) do
	if not cat.extra then
		teaching = teaching + 1
		local blocks = c.byCat(cat.id)
		check("category " .. cat.id .. " has a useful number of blocks",
			#blocks >= 8, tostring(#blocks) .. " blocks")
		check("category " .. cat.id .. " explains itself",
			cat.blurb and #cat.blurb > 15)
	end
end
eq("registry: ten teaching categories", teaching, 10)
check("registry: a substantial palette", c.count() >= 100, c.count() .. " blocks")

-- every block compiles ----------------------------------------------------------
local unique = {}
for _, def in ipairs(c.order) do
	check("block id is unique: " .. def.id, not unique[def.id])
	unique[def.id] = true

	local doc = d.newDoc("T")
	local stack = d.newStack(doc, 0, 0)
	local block = d.create(doc, def.id)
	d.attachToStack(doc, block, stack, nil, {})

	-- put something in every slot so the closing lines are exercised too
	for _, slot in ipairs(def.slots) do
		local child = d.create(doc, "printText")
		child.f.msg = "inside " .. slot.key
		d.attachToSlot(doc, child, block, slot.key, nil, {})
	end

	local code = e.generate(doc, { header = false })
	-- break/continue/return are only legal inside a loop, so give them one
	local wrapped = "while true do\n" .. code .. "\nend"
	local chunk, err = g.parse(wrapped)
	check("block emits valid Luau: " .. def.id, chunk ~= nil,
		err and (err.msg .. "\n--- emitted ---\n" .. code) or nil)

	-- and the label a person reads must not be empty or leftover placeholder
	check("block has a readable label: " .. def.id,
		def.label ~= nil and #def.label >= 2)
	check("block documents itself: " .. def.id, def.doc and #def.doc >= 20)
end

-- field defaults are sane --------------------------------------------------------
for _, def in ipairs(c.order) do
	for key, field in pairs(def.fields) do
		check("field kind is known: " .. def.id .. "." .. key,
			field.kind == "expr" or field.kind == "name" or field.kind == "str"
			or field.kind == "num" or field.kind == "choice"
			or field.kind == "params" or field.kind == "multiline", field.kind)
		if field.kind == "choice" then
			check("choice field lists options: " .. def.id .. "." .. key,
				field.options and #field.options >= 2)
			local hasDefault = false
			for _, option in ipairs(field.options or {}) do
				if option == field.default then hasDefault = true end
			end
			check("choice default is one of the options: " .. def.id .. "." .. key,
				hasDefault, field.default)
		end
	end
end

-- advice about the script kind the code is headed for ------------------------------
local function advice(code, kind)
	local notes = e.advise(code, kind)
	local text = {}
	for _, note in ipairs(notes) do text[#text + 1] = note.text end
	return #notes, table.concat(text, " ")
end

local count, text = advice("local M = {}\nreturn M", "ModuleScript")
eq("advice: a module that returns is fine", count, 0)

count, text = advice("local M = {}\nprint(M)", "ModuleScript")
eq("advice: a module that returns nothing is flagged", count, 1)
check("advice: and says what to do", string.find(text, "give back", 1, true) ~= nil, text)

count = advice("local M = {}\nreturn M", "Script")
eq("advice: a Script need not return", count, 0)

count, text = advice('local s = game:GetService("ServerStorage")', "LocalScript")
eq("advice: server-only code in a LocalScript is flagged", count, 1)
check("advice: names the reason", string.find(text, "invisible to the client", 1, true) ~= nil,
	text)

count, text = advice("local me = Players.LocalPlayer", "Script")
eq("advice: client-only code in a server Script is flagged", count, 1)
check("advice: names LocalPlayer", string.find(text, "LocalPlayer", 1, true) ~= nil, text)

count = advice("local me = Players.LocalPlayer", "LocalScript")
eq("advice: the same code in a LocalScript is fine", count, 0)

count = advice('print("hello")', "Script")
eq("advice: ordinary code says nothing", count, 0)

-- documents survive a save/load round trip ---------------------------------------
local doc = d.newDoc("Save me")
local stack = d.newStack(doc, 40, 60)
local loop = d.create(doc, "for")
loop.f.var, loop.f.to = "n", "5"
d.attachToStack(doc, loop, stack, nil, {})
local say = d.create(doc, "printValue")
say.f.value = "n"
d.attachToSlot(doc, say, loop, "body", nil, {})

local before = e.generate(doc, { header = false })
local restored = d.fromSave(d.toSave(doc))
eq("save/load: name survives", restored.name, "Save me")
eq("save/load: code is identical", e.generate(restored, { header = false }), before)
eq("save/load: stack position survives", restored.stacks[1].x, 40)
eq("save/load: block count survives", d.count(restored), d.count(doc))

-- a damaged file still opens ------------------------------------------------------
local broken = d.toSave(doc)
broken.stacks[1].ids = { "nope" }
local rescued = d.fromSave(broken)
check("save/load: orphaned blocks are rescued, not dropped",
	rescued ~= nil and d.count(rescued) > 0)

check("save/load: junk is refused", (d.fromSave({ hello = true })) == nil)

-- dragging a block takes the blocks under it ---------------------------------------
doc = d.newDoc("Drag")
stack = d.newStack(doc, 0, 0)
local first = d.create(doc, "printText")
local second = d.create(doc, "printText")
local third = d.create(doc, "printText")
d.attachToStack(doc, first, stack, nil, {})
d.attachToStack(doc, second, stack, nil, {})
d.attachToStack(doc, third, stack, nil, {})
d.detach(doc, second, 200, 200)
eq("drag: original stack keeps the block above", #doc.stacks[1].ids, 1)
eq("drag: dragged block carries the ones below it", #doc.stacks[2].ids, 2)

-- a stack cannot be dropped inside itself -------------------------------------------
doc = d.newDoc("Cycle")
stack = d.newStack(doc, 0, 0)
local outer = d.create(doc, "if")
local inner = d.create(doc, "if")
d.attachToStack(doc, outer, stack, nil, {})
d.attachToSlot(doc, inner, outer, "body", nil, {})
check("drag: refuses to swallow its own parent",
	d.attachToSlot(doc, outer, inner, "body", nil, {}) == false)

report("blocks")
if TESTS_FAILED > 0 then error("test failures", 0) end
