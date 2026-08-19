-- Mounts the entire plugin against the Roblox mock and drives it: every tab,
-- every tutorial, the palette, field editing, dragging, import, undo and both
-- themes.  Anything that would throw in Studio throws here.
local a = require(script.Parent.a)
local b = require(script.Parent.b)
local c = require(script.Parent.c)
local d = require(script.Parent.d)
local j = require(script.Parent.j)
local m = require(script.Parent.m)
local o = require(script.Parent.o)
local i = require(script.Parent.i)
local p = require(script.Parent.p)
local q = require(script.Parent.q)

local function noErrors(label)
	if #MOCK_ERRORS > 0 then
		check(label, false, table.concat(MOCK_ERRORS, "\n        "))
		MOCK_ERRORS = {}
		return false
	end
	TESTS_RUN = TESTS_RUN + 1
	return true
end

-- mount ------------------------------------------------------------------------
local pluginMock = MOCK.newPlugin()
local widget = pluginMock:CreateDockWidgetPluginGui("ABlocksTest", DockWidgetPluginGuiInfo.new())
widget.Enabled = true
local app = o.newApp(pluginMock, widget)
local shell = p.mount(app, widget)
MOCK.flush()
noErrors("mounts without error")

check("window is built", widget:FindFirstChild("ABlocks") ~= nil)
eq("a first run opens on the lessons", shell.tab, "learn")
shell.showTab("build")
MOCK.flush()
check("rail is present", MOCK.findText(widget, "BUILD") ~= nil)
check("code panel is present", MOCK.findText(widget, "GENERATED LUAU") ~= nil)
check("starter project has blocks", d.count(app.doc) >= 4)
check("canvas drew every block", (function()
	local drawn = 0
	for _ in pairs(app.canvas.frames) do drawn = drawn + 1 end
	return drawn == d.count(app.doc)
end)(), "canvas frames did not match the document")

-- the code panel ------------------------------------------------------------------
check("code panel produced Luau",
	string.find(shell.code.code, "Touched:Connect", 1, true) ~= nil, shell.code.code)
check("code panel counted its lines", shell.code.meta.lineCount > 4)
check("every generated line knows its block", (function()
	local mapped = 0
	for _ in pairs(shell.code.meta.blockOfLine) do mapped = mapped + 1 end
	return mapped >= 4
end)())

-- palette ---------------------------------------------------------------------------
shell.palette.search.Text = "touch"
MOCK.flush()
noErrors("palette search runs")
check("palette found the touch block", MOCK.findText(shell.palette.scroll, "on touched") ~= nil)

shell.palette.search.Text = "zzzznothing"
MOCK.flush()
check("palette says so when nothing matches",
	MOCK.findText(shell.palette.scroll, "Nothing matches") ~= nil)

shell.palette.search.Text = ""
MOCK.flush()
noErrors("palette resets")

-- adding, selecting, duplicating, deleting -------------------------------------------
local before = d.count(app.doc)
local added = app.canvas:addBlock("printText")
MOCK.flush()
eq("adding a block grows the document", d.count(app.doc), before + 1)
eq("the new block is selected", app.selection, added.id)
check("the new block reaches the code panel",
	string.find(shell.code.code, "hello world", 1, true) ~= nil)

app.canvas:duplicateSelected()
MOCK.flush()
eq("duplicating grows the document", d.count(app.doc), before + 2)
noErrors("duplicate is clean")

app.canvas:deleteSelected()
MOCK.flush()
eq("deleting shrinks the document", d.count(app.doc), before + 1)

app:undo()
MOCK.flush()
eq("undo brings it back", d.count(app.doc), before + 2)
app:redo()
MOCK.flush()
eq("redo removes it again", d.count(app.doc), before + 1)
noErrors("history is clean")

-- one of every block, drawn ------------------------------------------------------------
local everyBlock = d.newDoc("Every block")
local stack = d.newStack(everyBlock, 20, 20)
for _, def in ipairs(c.order) do
	local block = d.create(everyBlock, def.id)
	d.attachToStack(everyBlock, block, stack, nil, {})
end
app:setDoc(everyBlock, "every block")
MOCK.flush()
noErrors("canvas draws all " .. c.count() .. " block kinds")
eq("all of them are on the canvas", (function()
	local drawn = 0
	for _ in pairs(app.canvas.frames) do drawn = drawn + 1 end
	return drawn
end)(), c.count())

-- editing a field ------------------------------------------------------------------------
app:undo()
MOCK.flush()

local target = nil
d.walk(app.doc, function(block)
	if block.k == "onTouch" and not target then target = block end
end)
check("found a block to edit", target ~= nil)

local frame = app.canvas.frames[target.id]
local editable = nil
for _, node in ipairs(frame:GetDescendants()) do
	if node:IsA("TextBox") and not editable then editable = node end
end
check("the block has an editable field", editable ~= nil)

if editable then
	MOCK.fire(editable, "Focused")
	MOCK.flush()
	noErrors("focusing a field opens completion cleanly")
	check("IntelliSense offered something", m.popup().open)

	editable.Text = "workspace.Baseplate"
	MOCK.flush()
	eq("typing reaches the document", target.f.part, "workspace.Baseplate")
	check("typing reaches the code panel",
		string.find(shell.code.code, "workspace.Baseplate", 1, true) ~= nil)

	local undoDepth = #app.undoStack
	MOCK.fire(editable, "FocusLost", false)
	MOCK.flush()
	check("finishing an edit records one undo step", #app.undoStack == undoDepth + 1)
	noErrors("field editing is clean")
end

-- completion navigation ------------------------------------------------------------------
local pop = m.popup()
if editable then
	MOCK.fire(editable, "Focused")
	editable.Text = "workspace.Base"
	MOCK.flush()
	if pop.open then
		local first = pop.items[1] and pop.items[1].name
		pop:move(1)
		check("completion moves down", pop.index == 2 or #pop.items == 1)
		pop:setIndex(1)
		pop:accept(1)
		MOCK.flush()
		check("accepting a completion rewrites the field",
			editable.Text ~= "workspace.Base", editable.Text)
		noErrors("accepting a completion is clean")
	end
	MOCK.fire(editable, "FocusLost", false)
	MOCK.flush()
end

-- typing again after accepting a completion must reopen the list -----------------------------
if editable then
	MOCK.fire(editable, "Focused")
	editable.Text = "work"
	MOCK.flush()
	check("completion opens while typing", m.popup().open)
	m.popup():accept(1)
	MOCK.flush()
	check("the list closes once a completion is taken", not m.popup().open,
		"it should not offer back the word just accepted")
	editable.Text = editable.Text .. ".Grav"
	MOCK.flush()
	check("the list comes back on the next keystroke", m.popup().open,
		"popup stayed shut after an accept")
	MOCK.fire(editable, "FocusLost", false)
	MOCK.flush()
	noErrors("completion lifecycle is clean")
end

-- a completion accepted with the mouse must survive the field losing focus -------------------
if editable then
	MOCK.fire(editable, "Focused")
	editable.Text = "workspace.Gra"
	MOCK.flush()
	check("the list is open before the click", m.popup().open)

	-- clicking a row is: pointer over the popup, then the field loses focus,
	-- then the row's click arrives
	m.popup().hovering = true
	MOCK.fire(editable, "FocusLost", false)
	MOCK.flush()
	check("the list survives the field losing focus to it", m.popup().open,
		"the popup closed before the click could land")

	local row = m.popup().rows[1]
	MOCK.fire(row, "MouseButton1Click")
	MOCK.flush()
	eq("clicking a completion inserts it", editable.Text, "workspace.Gravity")
	eq("and the block kept the value", target.f.part, "workspace.Gravity")
	m.popup().hovering = false
	MOCK.fire(editable, "FocusLost", false)
	MOCK.flush()
	noErrors("clicking a completion is clean")
end

-- dragging ---------------------------------------------------------------------------------
local doc = d.newDoc("Drag test")
local stackA = d.newStack(doc, 20, 20)
local loop = d.create(doc, "for")
d.attachToStack(doc, loop, stackA, nil, {})
local stackB = d.newStack(doc, 300, 20)
local say = d.create(doc, "printText")
d.attachToStack(doc, say, stackB, nil, {})
app:setDoc(doc, "drag test")
MOCK.flush()

-- give the mock frames believable geometry so the drop maths has something to chew
MOCK.setAbsolute(app.canvas.content, Vector2.new(0, 0), Vector2.new(1000, 700))
local loopFrame = app.canvas.frames[loop.id]
MOCK.setAbsolute(loopFrame, Vector2.new(20, 20), Vector2.new(200, 60))
for _, info in ipairs(app.canvas.lists) do
	if info.kind == "slot" and info.parent == loop then
		MOCK.setAbsolute(info.frame, Vector2.new(38, 44), Vector2.new(120, 16))
	end
end
local sayFrame = app.canvas.frames[say.id]
MOCK.setAbsolute(sayFrame, Vector2.new(300, 20), Vector2.new(160, 24))
MOCK.setAbsolute(app.canvas.stackFrames[stackB.id], Vector2.new(300, 20), Vector2.new(160, 24))

app.canvas:beginDrag(say, Vector2.new(300, 20))
MOCK.flush()
noErrors("starting a drag is clean")
check("the dragged block is on its own stack", say.st ~= nil and say.p == nil)

-- nothing lays the mock out, so place the floating stack by hand: just inside
-- the loop's body, which is where a person would be aiming
MOCK.setAbsolute(app.canvas.drag.frame, Vector2.new(40, 46), Vector2.new(160, 24))
app.canvas:updateDrag(Vector2.new(44, 48))
noErrors("dragging is clean")
check("a drop target was found", app.canvas.drag.target ~= nil)

app.canvas:endDrag()
MOCK.flush()
noErrors("dropping is clean")
eq("the block landed inside the loop", say.p, loop.id)
eq("it landed in the loop's body", say.ps, "body")
eq("the canvas is one stack again", #app.doc.stacks, 1)

-- the window's shape: tabs on top, actions along the bottom ---------------------------------
do
	local root = widget:FindFirstChild("ABlocks")
	local top = root:FindFirstChild("TopBar")
	local actions = root:FindFirstChild("ActionBar")
	local status = root:FindFirstChild("StatusStrip")

	check("there is a top bar", top ~= nil)
	check("it sits at the top", top and top.Position.Y.Scale == 0 and top.Position.Y.Offset == 0)
	for _, name in ipairs({ "BUILD", "LEARN", "IMPORT", "SETUP" }) do
		check("tab " .. name .. " is in the top bar", MOCK.findText(top, name) ~= nil)
	end

	check("there is an action bar", actions ~= nil)
	check("it is anchored to the bottom", actions and actions.Position.Y.Scale == 1
		and actions.Position.Y.Offset < 0)
	for _, name in ipairs({ "undo", "redo", "tidy", "save", "copy" }) do
		check("action " .. name .. " is in the bottom bar",
			MOCK.findText(actions, name) ~= nil)
	end
	check("so is the button that writes the script out",
		MOCK.findText(actions, "Insert") ~= nil or MOCK.findText(actions, "Update") ~= nil)

	check("the status strip is below the actions", status ~= nil
		and status.Position.Y.Scale == 1
		and status.Position.Y.Offset > actions.Position.Y.Offset)

	check("nothing is left of the old side rail", root:FindFirstChild("Rail") == nil)
end

-- an empty canvas explains itself ------------------------------------------------------
local emptyDoc = d.newDoc("Nothing")
app:setDoc(emptyDoc, "empty")
MOCK.flush()
check("the empty canvas says what to do",
	MOCK.findText(app.canvas.root, "Nothing here yet") ~= nil)
app:undo()
MOCK.flush()
check("and the hint goes once there are blocks again",
	MOCK.findText(app.canvas.root, "Nothing here yet") == nil)

-- Enter in the palette search places the top match -----------------------------------------
shell.palette.search.Text = "wait"
MOCK.flush()
local countBeforeEnter = d.count(app.doc)
MOCK.fire(shell.palette.search, "FocusLost", true)
MOCK.flush()
eq("Enter in the search box adds the top match", d.count(app.doc), countBeforeEnter + 1)
shell.palette.search.Text = ""
MOCK.flush()
app:undo()
MOCK.flush()

-- typing must not trigger canvas shortcuts ---------------------------------------------------
do
	local blocksBefore = d.count(app.doc)
	MOCK.fire(shell.palette.search, "Focused")
	MOCK.keyUp(MOCK.key(Enum.KeyCode.Delete))
	MOCK.flush()
	eq("Delete while typing does not delete a block", d.count(app.doc), blocksBefore)
	MOCK.fire(shell.palette.search, "FocusLost", false)
	MOCK.flush()
end

-- clicking a field selects rather than drags ---------------------------------------------------
do
	local anyBlock = nil
	d.walk(app.doc, function(block) anyBlock = anyBlock or block end)
	local frame = app.canvas.frames[anyBlock.id]
	local box = nil
	for _, node in ipairs(frame:GetDescendants()) do
		if node:IsA("TextBox") and not box then box = node end
	end
	if box then
		MOCK.setAbsolute(box, Vector2.new(60, 60), Vector2.new(80, 18))
		MOCK_MOUSE = Vector2.new(80, 66)
		app.canvas:beginPress(anyBlock, { UserInputType = Enum.UserInputType.MouseButton1 })
		MOCK.flush()
		check("pressing a field does not start a drag", app.canvas.dragging ~= true)
		eq("but it does select the block", app.selection, anyBlock.id)
		MOCK_MOUSE = Vector2.new(0, 0)
	end
end

-- settings survive a reload ------------------------------------------------------------------------
do
	local read = { ["cat-events"] = true }
	app:setSetting("read", read)
	app:save()
	local reopened = o.newApp(pluginMock, widget)
	check("tutorial progress survives a reload",
		type(reopened.settings.read) == "table" and reopened.settings.read["cat-events"] == true)
	eq("the theme setting survives too", reopened.settings.theme, app.settings.theme)
end

-- tabs ---------------------------------------------------------------------------------------
for _, tab in ipairs({ "learn", "import", "setup", "build" }) do
	shell.showTab(tab)
	MOCK.flush()
	noErrors("switching to the " .. tab .. " tab is clean")
end

-- every tutorial renders ------------------------------------------------------------------------
for _, entry in ipairs(j.tutorials) do
	shell.learn:open(entry)
	MOCK.flush()
	if not noErrors("lesson renders: " .. entry.id) then break end
end
check("the lesson pane has content", MOCK.findText(shell.learn.reader, "Events") ~= nil
	or MOCK.findText(shell.learn.reader, "blocks") ~= nil)

shell.learn.query = "leaderboard"
shell.learn:refreshList()
MOCK.flush()
noErrors("lesson search is clean")
shell.learn.query = ""
shell.learn:refreshList()

-- building a lesson's example -----------------------------------------------------------------
local lesson = nil
for _, entry in ipairs(j.tutorials) do
	if entry.example and not lesson then lesson = entry end
end
shell.learn:open(lesson)
MOCK.flush()
local buildButton = nil
for _, node in ipairs(shell.learn.reader:GetDescendants()) do
	if node:IsA("TextLabel") and node.Text == "Build this example" then
		buildButton = node.Parent
	end
end
check("the lesson offers to build its example", buildButton ~= nil)
if buildButton then
	MOCK.fire(buildButton, "MouseButton1Click")
	MOCK.flush()
	noErrors("building a lesson example is clean")
	check("the example became blocks", d.count(app.doc) >= 3, d.count(app.doc))
end

-- converting the script you have selected -------------------------------------------------------
shell.showTab("import")
MOCK.flush()

local ServerScriptService = game:GetService("ServerScriptService")
local sourceScript = Instance.new("Script")
sourceScript.Name = "Trap"
sourceScript.Source = [[
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	print(player.Name)
end)
]]
sourceScript.Parent = ServerScriptService

check("nothing selected is stated plainly",
	string.find(shell.import.cardName.Text, "Nothing selected", 1, true) ~= nil)

MOCK.select({ sourceScript })
MOCK.flush()
noErrors("reacting to a selection is clean")
eq("the selected script is named", shell.import.cardName.Text, "Trap")
eq("its path is shown", shell.import.cardPath.Text, "ServerScriptService.Trap")
check("its kind and size are shown",
	string.find(shell.import.cardFacts.Text, "Script", 1, true) ~= nil
	and string.find(shell.import.cardFacts.Text, "lines", 1, true) ~= nil,
	shell.import.cardFacts.Text)

MOCK.fire(shell.import.convert, "MouseButton1Click")
MOCK.flush()
noErrors("converting a selected script is clean")
check("it became blocks", d.count(app.doc) >= 2, d.count(app.doc))
eq("the project is tied to that script", app.doc.origin.path, "ServerScriptService.Trap")
eq("and remembers what kind it was", app.doc.origin.kind, "Script")
eq("converting switches to the canvas", shell.tab, "build")
check("the report says what happened",
	string.find(shell.import.report.Text, "became", 1, true) ~= nil,
	shell.import.report.Text)

-- writing it back where it came from ----------------------------------------------------------------
do
	local actions = widget:FindFirstChild("ABlocks"):FindFirstChild("ActionBar")
	check("the bottom bar now offers to update the original",
		MOCK.findText(actions, "Update Trap") ~= nil,
		"the button label did not follow the conversion")
end

local label, hint = shell.code:insertLabel()
check("the button offers to update the original", string.find(label, "Update", 1, true) ~= nil,
	label)
check("and says where", string.find(hint, "ServerScriptService.Trap", 1, true) ~= nil, hint)

app.canvas:addBlock("printText")
MOCK.flush()
shell.code:insertScript()
MOCK.flush()
noErrors("writing back is clean")
check("the original script was rewritten",
	string.find(sourceScript.Source, "hello world", 1, true) ~= nil,
	sourceScript.Source)
check("no second script appeared",
	#ServerScriptService:GetChildren() == 1,
	#ServerScriptService:GetChildren() .. " children")

-- a project with no origin goes where its kind belongs -------------------------------------------------
app:newProject("Fresh")
MOCK.flush()
app.canvas:addBlock("printText")
MOCK.flush()

eq("a fresh project defaults to a server Script", app:scriptKind(), "Script")
shell.code:insertScript()
MOCK.flush()
noErrors("inserting a new Script is clean")
eq("it landed in ServerScriptService", #ServerScriptService:GetChildren(), 2)

app:newProject("Client thing")
app:setScriptKind("LocalScript")
app.canvas:addBlock("printText")
MOCK.flush()
eq("LocalScripts are aimed at StarterPlayerScripts",
	app:destinationFor("LocalScript"), "StarterPlayer.StarterPlayerScripts")
eq("ModuleScripts are aimed at ReplicatedStorage",
	app:destinationFor("ModuleScript"), "ReplicatedStorage")

local starterPlayer = Instance.new("Folder")
starterPlayer.Name = "StarterPlayer"
starterPlayer.Parent = game
local playerScripts = Instance.new("Folder")
playerScripts.Name = "StarterPlayerScripts"
playerScripts.Parent = starterPlayer

shell.code:insertScript()
MOCK.flush()
noErrors("inserting a LocalScript is clean")
eq("it landed in StarterPlayerScripts", #playerScripts:GetChildren(), 1)
eq("as a LocalScript", MOCK.className(playerScripts:GetChildren()[1]), "LocalScript")

-- choosing a kind by hand unties it from the script it came from -----------------------------------------
MOCK.select({ sourceScript })
MOCK.flush()
MOCK.fire(shell.import.convert, "MouseButton1Click")
MOCK.flush()
check("tied again after converting", app.doc.origin ~= nil)
app:setScriptKind("ModuleScript")
MOCK.flush()
check("changing kind unties it", app.doc.origin == nil)
eq("and the kind sticks", app:scriptKind(), "ModuleScript")

-- pasting still works ---------------------------------------------------------------------------------
shell.showTab("import")
shell.import.input.Text = "print(1)\n\nprint(2)"
MOCK.fire(shell.import.convertPasted, "MouseButton1Click")
MOCK.flush()
noErrors("pasting is clean")
eq("pasted code has no origin", app.doc.origin, nil)
check("pasted code became blocks", d.count(app.doc) == 2, d.count(app.doc))

shell.showTab("import")
shell.import.input.Text = "if a then"
MOCK.fire(shell.import.convertPasted, "MouseButton1Click")
MOCK.flush()
check("a broken paste is reported, not thrown",
	string.find(shell.import.report.Text, "Line", 1, true) ~= nil,
	shell.import.report.Text)
noErrors("a failed conversion is clean")

-- settings and projects -----------------------------------------------------------------------------
shell.showTab("setup")
MOCK.flush()
local saveCount = #app.projects
app:save()
MOCK.flush()
check("saving records a project", #app.projects >= math.max(saveCount, 1))
check("the project went to plugin settings",
	MOCK.settings["ablocks.projects.v1"] ~= nil)

app:newProject("Second")
MOCK.flush()
noErrors("starting a new project is clean")
eq("the new project is empty", d.count(app.doc), 0)
check("there are now two projects", #app.projects >= 2)

local exported = app:exportProject()
check("a project exports as text", type(exported) == "string" and #exported > 10)
local ok = app:importProject(exported)
check("an exported project imports again", ok)
noErrors("export and import round-trip is clean")

check("junk is refused, not thrown", (app:importProject("not json at all")) == false)

app:openProject(app.projects[1].id)
MOCK.flush()
noErrors("switching project is clean")

-- themes --------------------------------------------------------------------------------------------
a.setTheme("paper")
MOCK.flush()
noErrors("the paper theme applies")
eq("theme switched", a.c.name, "paper")
shell.showTab("learn")
MOCK.flush()
noErrors("lessons redraw in the paper theme")
a.setTheme("ink")
MOCK.flush()
noErrors("the ink theme applies")

-- canvas navigation -----------------------------------------------------------------------------------
shell.showTab("build")
app.canvas:setZoom(1.5)
app.canvas:setZoom(0.75)
app.canvas:resetZoom()
app.canvas:setPan(-100, -50)
app.canvas:tidy()
MOCK.flush()
noErrors("zooming, panning and tidying are clean")
eq("tidy lines the stacks up", app.doc.stacks[1] and app.doc.stacks[1].x, 24)

-- keyboard ------------------------------------------------------------------------------------------------
local function pressKey(name, ctrl)
	local modifier = ctrl and MOCK.key(Enum.KeyCode.LeftControl) or nil
	local key = MOCK.key(Enum.KeyCode[name])
	MOCK.flush()
	MOCK.keyUp(key)
	if modifier then MOCK.keyUp(modifier) end
	MOCK.flush()
end

app.canvas:addBlock("wait")
MOCK.flush()
local countBefore = d.count(app.doc)
pressKey("Delete", false)
check("Delete removes the selection", d.count(app.doc) < countBefore)
pressKey("Z", true)
check("Ctrl+Z puts it back", d.count(app.doc) == countBefore)
pressKey("D", true)
pressKey("L", true)
pressKey("S", true)
pressKey("Escape", false)
noErrors("keyboard shortcuts are clean")

-- no block may contain a child whose size depends on the block's own size ------------------
-- Both axes: a block auto-sizes in X and Y now that it is a filled slab, so a
-- scale-sized child on either axis is a feedback loop the engine cannot settle.
do
	shell.showTab("build")
	local offenders = {}
	for id, frame in pairs(app.canvas.frames) do
		for _, node in ipairs(frame:GetChildren()) do
			if node:IsA("GuiObject") then
				local size = node.Size
				if size.Y.Scale ~= 0 or size.X.Scale ~= 0 then
					offenders[#offenders + 1] = id .. "/" .. node.Name
				end
			end
		end
	end
	check("a block's size comes only from its content", #offenders == 0,
		table.concat(offenders, ", "))
end

-- blocks interlock -----------------------------------------------------------------
do
	shell.showTab("build")
	local doc = d.newDoc("Interlock")
	local stack = d.newStack(doc, 0, 0)
	local first = d.create(doc, "printText")
	local second = d.create(doc, "wait")
	d.attachToStack(doc, first, stack, nil, {})
	d.attachToStack(doc, second, stack, nil, {})
	app:setDoc(doc, "interlock")
	MOCK.flush()
	noErrors("drawing an interlocked run is clean")

	local firstFrame = app.canvas.frames[first.id]
	local secondFrame = app.canvas.frames[second.id]
	local function notchOf(frame)
		local strip = frame:FindFirstChild("Notch")
		return strip and strip:GetChildren()[1] or nil
	end

	check("every block has a notch bitten out of its top",
		notchOf(firstFrame) ~= nil and notchOf(secondFrame) ~= nil)
	eq("the notch is as deep as the tab is tall",
		notchOf(firstFrame).Size.Y.Offset, a.metric.notchH)

	-- the first block sits on the canvas, so its notch shows the canvas
	local topCut = notchOf(firstFrame).BackgroundColor3
	check("the top block's notch shows the canvas through it",
		topCut == a.c.bg, tostring(topCut))

	-- the second sits under the first, so its notch is filled by the first
	local jointCut = notchOf(secondFrame).BackgroundColor3
	eq("a joint is filled with the colour of the block above it",
		jointCut, a.blockColor(c.get("printText").cat))
	check("which is not the canvas", jointCut ~= a.c.bg)

	local stackFrame = app.canvas.stackFrames[stack.id]
	check("the run ends with a tab", stackFrame:FindFirstChild("Tab") ~= nil)
	eq("painted like the last block in the run",
		stackFrame:FindFirstChild("Tab"):GetChildren()[1].BackgroundColor3,
		a.blockColor(c.get("wait").cat))

	local layout = nil
	for _, node in ipairs(stackFrame:GetChildren()) do
		if node:IsA("UIListLayout") then layout = node end
	end
	eq("blocks in a run touch, so the joint is the only thing between them",
		layout.Padding.Offset, 0)
end

-- a container block is a C, with the workspace showing through its mouth --------------
do
	local doc = d.newDoc("C block")
	local stack = d.newStack(doc, 0, 0)
	local loop = d.create(doc, "repeatN")
	d.attachToStack(doc, loop, stack, nil, {})
	local inside = d.create(doc, "printText")
	d.attachToSlot(doc, inside, loop, "body", nil, {})
	app:setDoc(doc, "c block")
	MOCK.flush()
	noErrors("drawing a C block is clean")

	local frame = app.canvas.frames[loop.id]
	local wrap = frame:FindFirstChild("slot_body")
	check("the slot is there", wrap ~= nil)
	local mouth = wrap and wrap:FindFirstChild("mouth")
	check("with a mouth inside it", mouth ~= nil)
	eq("the mouth shows the workspace", mouth.BackgroundColor3, a.c.bg)

	local arm = nil
	for _, node in ipairs(wrap:GetChildren()) do
		if node:IsA("UIPadding") then arm = node end
	end
	check("and the arm runs down the left of it",
		arm ~= nil and arm.PaddingLeft.Offset == a.metric.arm)

	check("the block inside is drawn inside the mouth",
		app.canvas.frames[inside.id].Parent == mouth)
	eq("so its notch shows the mouth, not the block around it",
		app.canvas.frames[inside.id]:FindFirstChild("Notch"):GetChildren()[1]
			.BackgroundColor3, a.c.bg)
end

-- a block is picked up by holding, not by clicking ---------------------------------
do
	local doc = d.newDoc("Hold")
	local stack = d.newStack(doc, 0, 0)
	local block = d.create(doc, "printText")
	d.attachToStack(doc, block, stack, nil, {})
	app:setDoc(doc, "hold")
	MOCK.flush()

	check("a flick of the button is not a drag", not app.canvas:shouldLift(0.02))
	check("nor is a quick click", not app.canvas:shouldLift(0.1))
	check("holding it is", app.canvas:shouldLift(0.4))

	-- pressing and letting go selects and nothing more
	MOCK_MOUSE = Vector2.new(400, 400)
	local tap = MOCK.press()
	MOCK.release(tap)
	app.canvas:beginPress(block, tap)
	MOCK.flush()
	noErrors("a press that is let go of is clean")
	eq("it selected the block", app.selection, block.id)
	check("and left it where it was", app.canvas.dragging ~= true)
	eq("the document did not change", d.count(app.doc), 1)
end

-- and then it actually moves -----------------------------------------------------
--
-- The gesture is driven the way Studio drives it, through the widget's own
-- input events, because that is the only route input over a plugin window
-- takes.  A drag loop that asks UserInputService instead sees a button that is
-- never down and quietly does nothing, which is a bug no amount of testing
-- around the loop will find.
do
	local doc = d.newDoc("Drag")
	local stack = d.newStack(doc, 0, 0)
	local block = d.create(doc, "printText")
	d.attachToStack(doc, block, stack, nil, {})
	app:setDoc(doc, "drag")
	MOCK.flush()

	app.canvas.liftAfter = 0
	MOCK_MOUSE = Vector2.new(400, 400)

	local frames, liftedAt = 0, nil
	local input = MOCK.press()
	MOCK.onWait = function()
		frames = frames + 1
		if app.canvas.dragging and not liftedAt then liftedAt = frames end
		MOCK_MOUSE = Vector2.new(400 + frames * 20, 400 + frames * 12)
		if frames >= 4 then MOCK.release(input) end
	end
	app.canvas:beginPress(block, input)
	MOCK.onWait = nil
	MOCK.flush()

	noErrors("holding and moving is clean")
	check("holding the button picks the block up", liftedAt ~= nil)
	check("the drag ends when the button comes up", not app.canvas.dragging)
	check("and the block went with the pointer",
		(app.doc.stacks[1] and app.doc.stacks[1].x or 0) ~= 0
			or (app.doc.stacks[1] and app.doc.stacks[1].y or 0) ~= 0)
	eq("without gaining or losing a block", d.count(app.doc), 1)

	app.canvas.liftAfter = nil
end

-- a gesture cannot be built on UserInputService ------------------------------------
--
-- Stated as a check of its own so the reason survives: a plugin widget is
-- invisible to that service, so anything reading button or key state from it
-- is reading a permanent "no".
do
	local uis = game:GetService("UserInputService")
	check("the service never sees the button over a widget",
		uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) == false)
	check("nor a key", uis:IsKeyDown(Enum.KeyCode.LeftControl) == false)

	local held = MOCK.press()
	check("but the widget does", b.pressing(held, Enum.UserInputType.MouseButton1))
	MOCK.release(held)
	check("and knows when it is let go",
		not b.pressing(held, Enum.UserInputType.MouseButton1))

	local key = MOCK.key(Enum.KeyCode.LeftShift)
	check("the same goes for keys", b.keyDown(Enum.KeyCode.LeftShift))
	MOCK.keyUp(key)
	check("released too", not b.keyDown(Enum.KeyCode.LeftShift))
end

-- writing on a block has to be readable, on every category and in both themes --------
do
	-- WCAG relative luminance, so this is the real contrast ratio rather than
	-- a guess at one
	local function channel(value)
		if value <= 0.03928 then return value / 12.92 end
		return ((value + 0.055) / 1.055) ^ 2.4
	end
	local function luminance(colour)
		return 0.2126 * channel(colour.R) + 0.7152 * channel(colour.G)
			+ 0.0722 * channel(colour.B)
	end
	local function ratio(one, two)
		local high, low = luminance(one), luminance(two)
		if low > high then high, low = low, high end
		return (high + 0.05) / (low + 0.05)
	end

	for _, theme in ipairs({ "ink", "paper" }) do
		a.setTheme(theme)
		local worstText, worstTextAt = 21, ""
		local worstEdge, worstEdgeAt = 21, ""
		for _, cat in ipairs(c.cats) do
			local body = a.blockColor(cat.id)
			local text = ratio(body, a.inkOn(body))
			if text < worstText then worstText, worstTextAt = text, cat.id end
			-- a field pill has to be visible against the block it sits on
			local pill = ratio(body, a.c.well)
			if pill < worstEdge then worstEdge, worstEdgeAt = pill, cat.id end
			-- and the block has to be visible against the canvas
			check(theme .. ": " .. cat.id .. " stands out from the canvas",
				ratio(body, a.c.bg) >= 1.6,
				string.format("%.2f:1", ratio(body, a.c.bg)))
		end
		check(theme .. ": block wording is readable on every category",
			worstText >= 4.5,
			string.format("worst is %s at %.2f:1", worstTextAt, worstText))
		check(theme .. ": field pills stand out on every category",
			worstEdge >= 3, string.format("worst is %s at %.2f:1", worstEdgeAt, worstEdge))
	end
	a.setTheme(app.settings.theme or "ink")
	MOCK.flush()
	noErrors("checking contrast is clean")
end

-- fields on a block are pale pills, not sunken wells --------------------------------
do
	shell.showTab("build")
	local doc = d.newDoc("Pills")
	local stack = d.newStack(doc, 0, 0)
	local block = d.create(doc, "printText")
	d.attachToStack(doc, block, stack, nil, {})
	app:setDoc(doc, "pills")
	MOCK.flush()

	local box = nil
	for _, node in ipairs(app.canvas.frames[block.id]:GetDescendants()) do
		if node:IsA("TextBox") and not box then box = node end
	end
	check("the block has a field", box ~= nil)
	eq("it is a pale pill", box.BackgroundColor3, a.c.well)
	eq("with dark writing in it", box.TextColor3, a.c.wellInk)
	local corner = nil
	for _, node in ipairs(box:GetChildren()) do
		if node:IsA("UICorner") then corner = node end
	end
	check("and it is rounded like one",
		corner ~= nil and corner.CornerRadius.Offset >= 8,
		corner and tostring(corner.CornerRadius.Offset) or "no corner")
end

-- nothing may leak across re-renders ---------------------------------------------------------
do
	shell.showTab("build")
	app.canvas:render()
	MOCK.flush()
	local baseline = a.listenerCount()
	for _ = 1, 12 do
		app.canvas:render()
	end
	MOCK.flush()
	check("re-rendering does not pile up theme listeners",
		a.listenerCount() <= baseline + 2,
		string.format("%d listeners after twelve renders, was %d",
			a.listenerCount(), baseline))
end

-- the palette's own sections ----------------------------------------------------
do
	shell.showTab("build")
	local palette = shell.palette
	palette.search.Text = ""

	-- a big category is broken into subgroups rather than one long list
	local biggest, most = nil, 0
	for _, cat in ipairs(c.cats) do
		local groups = {}
		local count = 0
		for _, def in ipairs(c.byCat(cat.id)) do
			if not groups[def.group or "General"] then
				groups[def.group or "General"] = true
				count += 1
			end
		end
		if count > most then biggest, most = cat, count end
	end
	check("some category has more than one subgroup", most > 1,
		"every category is one flat list")

	palette.openCat = biggest.id
	palette:refresh()
	MOCK.flush()
	noErrors("opening a category is clean")
	local firstGroup = nil
	for _, def in ipairs(c.byCat(biggest.id)) do
		firstGroup = firstGroup or def.group
	end
	check("an opened category shows its subgroup headings",
		firstGroup == nil or MOCK.findText(palette.scroll, string.upper(firstGroup)) ~= nil,
		"no heading for " .. tostring(firstGroup) .. " in " .. biggest.name)

	-- starring a block puts it at the top
	palette.openCat = nil
	palette:toggleFavourite("printText")
	MOCK.flush()
	noErrors("starring a block is clean")
	check("the starred strip appears", MOCK.findText(palette.scroll, "STARRED") ~= nil)
	check("with the starred block in it",
		MOCK.findText(palette.scroll, c.get("printText").label) ~= nil)
	palette:toggleFavourite("printText")
	MOCK.flush()
	check("unstarring takes the strip away",
		MOCK.findText(palette.scroll, "STARRED") == nil)

	-- and using one puts it in recents
	palette:remember("wait")
	MOCK.flush()
	check("the recent strip appears", MOCK.findText(palette.scroll, "RECENT") ~= nil)
	check("recents survive a reload", (function()
		for _, id in ipairs(app.settings.recents or {}) do
			if id == "wait" then return true end
		end
		return false
	end)())

	-- search results are grouped by category
	palette.search.Text = "part"
	MOCK.flush()
	noErrors("searching is clean")
	check("search says how many matched",
		MOCK.findText(palette.scroll, "MATCHING") ~= nil)
	palette.search.Text = ""
	MOCK.flush()
end

-- the side filter follows what kind of script this is ------------------------------
do
	local palette = shell.palette
	local serverOnly, clientOnly = nil, nil
	for _, def in ipairs(c.order) do
		if def.side == "server" then serverOnly = serverOnly or def end
		if def.side == "client" then clientOnly = clientOnly or def end
	end
	check("there are server-only blocks", serverOnly ~= nil)
	check("there are client-only blocks", clientOnly ~= nil)

	app:setSetting("filterBySide", true)
	app:setScriptKind("LocalScript")
	MOCK.flush()
	check("a LocalScript hides the server-only blocks",
		serverOnly == nil or not palette:allows(serverOnly), serverOnly and serverOnly.id)
	check("and keeps the client-only ones",
		clientOnly == nil or palette:allows(clientOnly))

	app:setScriptKind("Script")
	MOCK.flush()
	check("a Script hides the client-only blocks",
		clientOnly == nil or not palette:allows(clientOnly))
	check("the palette redrew when the kind changed",
		string.find(palette.filterLabel.Text, "Script", 1, true) ~= nil,
		palette.filterLabel.Text)

	app:setSetting("filterBySide", false)
	MOCK.flush()
	check("turning the filter off shows everything again",
		palette:allows(clientOnly) and palette:allows(serverOnly))
	noErrors("the side filter is clean")
end

-- making a block of your own -----------------------------------------------------
do
	shell.showTab("build")
	local before = #q.list()

	app.openBlockEditor(nil)
	MOCK.flush()
	noErrors("the block editor opens cleanly")
	check("the editor is on screen", app.blockEditor ~= nil)
	check("it says what it is", MOCK.findText(app.blockEditor, "MAKE A BLOCK") ~= nil)

	-- fill it in the way a person would: a name and some Luau with a hole
	local boxes = {}
	for _, node in ipairs(app.blockEditor:GetDescendants()) do
		if node:IsA("TextBox") then boxes[#boxes + 1] = node end
	end
	check("the editor has fields to fill in", #boxes >= 3, #boxes .. " text boxes")

	boxes[1].Text = "Heal someone"
	MOCK.fire(boxes[1], "FocusLost", false)
	MOCK.flush()

	local codeBox = nil
	for _, node in ipairs(boxes) do
		if node.MultiLine then codeBox = codeBox or node end
	end
	check("one of them takes the Luau", codeBox ~= nil)
	if codeBox then
		codeBox.Text = "{who}.Humanoid.Health += {amount}"
		MOCK.fire(codeBox, "FocusLost", false)
		MOCK.flush()
		noErrors("typing the Luau is clean")
		check("the editor noticed both holes",
			MOCK.findText(app.blockEditor, "who") ~= nil
			and MOCK.findText(app.blockEditor, "amount") ~= nil)
		check("and previewed the wording",
			MOCK.findText(app.blockEditor, "Heal someone") ~= nil)
	end

	local saveButton = nil
	for _, node in ipairs(app.blockEditor:GetDescendants()) do
		if node:IsA("TextLabel") and node.Text == "Save block" then
			saveButton = node.Parent
		end
	end
	check("the editor has a save button", saveButton ~= nil)
	if saveButton then
		MOCK.fire(saveButton, "MouseButton1Click")
		MOCK.flush()
		noErrors("saving a block is clean")
		eq("the library grew by one", #q.list(), before + 1)
		check("the editor closed", app.blockEditor == nil)
	end

	-- it is a real block now: place it and it writes real Luau
	local mine = nil
	for _, custom in ipairs(q.list()) do
		if custom.label == "Heal someone" then mine = custom end
	end
	check("the block is in the library", mine ~= nil)
	if mine then
		local fresh = d.newDoc("Using my block")
		d.newStack(fresh, 0, 0)
		app:setDoc(fresh, "my block")
		MOCK.flush()
		local placed = app.canvas:addBlock("custom_" .. mine.id)
		MOCK.flush()
		noErrors("placing your own block is clean")
		check("it drew on the canvas", app.canvas.frames[placed.id] ~= nil)
		check("and it wrote the Luau",
			string.find(shell.code.code, "Humanoid.Health", 1, true) ~= nil,
			shell.code.code)
		check("with the helper written out once",
			string.find(shell.code.code, "local function " .. mine.fn, 1, true) ~= nil,
			shell.code.code)
	end

	-- the palette shows it, with a way back into the editor
	shell.palette.openCat = "custom"
	shell.palette:refresh()
	MOCK.flush()
	check("your category lists it", MOCK.findText(shell.palette.scroll, "Heal someone") ~= nil)
	check("and offers a new one", MOCK.findText(shell.palette.scroll, "New block") ~= nil)
	shell.palette.openCat = nil
	shell.palette:refresh()
	MOCK.flush()
end

-- turning what is on the canvas into a block --------------------------------------
do
	shell.showTab("build")
	local fresh = d.newDoc("To become a block")
	local stack = d.newStack(fresh, 0, 0)
	local first = d.create(fresh, "printText")
	d.attachToStack(fresh, first, stack, nil, {})
	app:setDoc(fresh, "canvas to block")
	app:select(first.id)
	MOCK.flush()

	app.makeBlockFromSelection()
	MOCK.flush()
	noErrors("making a block from the canvas is clean")
	check("the editor opened on it", app.blockEditor ~= nil)
	check("seeded with the code those blocks write",
		MOCK.findText(app.blockEditor, "print") ~= nil)

	local cancel = nil
	for _, node in ipairs(app.blockEditor:GetDescendants()) do
		if node:IsA("TextLabel") and node.Text == "Cancel" then cancel = node.Parent end
	end
	check("it can be backed out of", cancel ~= nil)
	if cancel then
		MOCK.fire(cancel, "MouseButton1Click")
		MOCK.flush()
		check("cancelling closes it", app.blockEditor == nil)
	end

	-- and the canvas menu offers the same thing
	app.canvas:contextMenu(first)
	MOCK.flush()
	noErrors("the canvas menu opens cleanly")
	check("the menu offers to make a block",
		MOCK.findText(app.canvas.menu, "Make into a block") ~= nil)
	app.canvas.menu:Destroy()
	app.canvas.menu = nil
end

-- your blocks are completed inside fields ------------------------------------------
do
	local helper = nil
	for _, custom in ipairs(q.list()) do
		if q.isHelper(custom) then helper = custom end
	end
	check("there is a helper block to complete", helper ~= nil)
	if helper then
		local result = i.complete({
			text = string.sub(helper.fn, 1, 3),
			cursor = 4,
			doc = app.doc,
			field = { kind = "expr" },
		})
		local found = false
		for _, item in ipairs(result.items) do
			if item.name == helper.fn then found = true end
		end
		check("IntelliSense offers your own block's function", found, helper.fn)
	end
end

-- saving the library out to a ModuleScript ------------------------------------------
do
	shell.showTab("setup")
	MOCK.flush()
	check("settings has a section for your blocks",
		MOCK.findText(shell.setup.frame, "YOUR BLOCKS") ~= nil)

	local saveLibrary = nil
	for _, node in ipairs(shell.setup.frame:GetDescendants()) do
		if node:IsA("TextLabel") and node.Text == "Save to a ModuleScript" then
			saveLibrary = node.Parent
		end
	end
	check("and a button to save them out", saveLibrary ~= nil)
	if saveLibrary then
		MOCK.fire(saveLibrary, "MouseButton1Click")
		MOCK.flush()
		noErrors("saving the library is clean")
		local made = game:GetService("Selection"):Get()[1]
		check("it made a ModuleScript", made ~= nil and made:IsA("ModuleScript"),
			made and made.ClassName or "nothing selected")
		if made then
			eq("named for the plugin", made.Name, "ABlocksBlocks")
			local read = q.fromModuleSource(made.Source)
			check("and the plugin can read it back", read ~= nil)
			eq("with every block in it", read and #read or 0, #q.list())
		end
	end
	-- and a plain module of functions becomes one block each
	local helper = Instance.new("ModuleScript")
	helper.Name = "Helper"
	helper.Source = [[
local Helper = {}

function Helper.greet(name)
	print("hello " .. name)
end

function Helper.farewell(name)
	print("bye " .. name)
end

return Helper
]]
	helper.Parent = game:GetService("ReplicatedStorage")
	eq("the plugin can spell the path to a module", o.pathTo(helper),
		'game:GetService("ReplicatedStorage").Helper')

	local loadLibrary = nil
	for _, node in ipairs(shell.setup.frame:GetDescendants()) do
		if node:IsA("TextLabel") and node.Text == "Load from a ModuleScript" then
			loadLibrary = node.Parent
		end
	end
	check("and a button to read one back in", loadLibrary ~= nil)

	MOCK.select({ helper })
	MOCK.flush()
	local countBefore = #q.list()
	if loadLibrary then
		MOCK.fire(loadLibrary, "MouseButton1Click")
		MOCK.flush()
		noErrors("reading a module of functions is clean")
		eq("one block per exported function", #q.list(), countBefore + 2)
		local names = {}
		for _, custom in ipairs(q.list()) do names[custom.label] = true end
		check("named after the functions", names.greet and names.farewell)
	end

	-- and a library the plugin saved reads back as the same blocks
	local saved = Instance.new("ModuleScript")
	saved.Name = "SharedBlocks"
	saved.Source = q.toModuleSource({ q.list()[1] }, "Shared")
	saved.Parent = game:GetService("ReplicatedStorage")
	MOCK.select({ saved })
	MOCK.flush()
	local beforeShared = #q.list()
	if loadLibrary then
		MOCK.fire(loadLibrary, "MouseButton1Click")
		MOCK.flush()
		noErrors("reading a saved library is clean")
		eq("a saved library adds its blocks", #q.list(), beforeShared + 1)
	end

	shell.showTab("build")
	MOCK.flush()
end

-- every category has an ink of its own, in both themes -----------------------------
do
	for _, theme in ipairs({ "ink", "paper" }) do
		a.setTheme(theme)
		local seen, seenBlock = {}, {}
		for _, cat in ipairs(c.cats) do
			local colour = a.catColor(cat.id)
			check(theme .. ": " .. cat.id .. " has a colour",
				colour ~= nil and colour ~= a.c.text2,
				"it would fall back to grey")
			local function key(value)
				return string.format("%d,%d,%d",
					math.floor(value.R * 255), math.floor(value.G * 255),
					math.floor(value.B * 255))
			end
			check(theme .. ": " .. cat.id .. " does not share an ink",
				not seen[key(colour)], "same as " .. tostring(seen[key(colour)]))
			seen[key(colour)] = cat.id
			-- and the darkening a block goes through must not collapse two
			-- categories onto the same colour
			local block = a.blockColor(cat.id)
			check(theme .. ": " .. cat.id .. " is its own colour as a block",
				not seenBlock[key(block)],
				"same as " .. tostring(seenBlock[key(block)]))
			seenBlock[key(block)] = cat.id
		end
	end
	a.setTheme(app.settings.theme or "ink")
	MOCK.flush()
	noErrors("repainting for the colour check is clean")
end

-- warnings ------------------------------------------------------------------------------------------------
check("nothing warned during the whole run", #MOCK_WARNINGS == 0,
	table.concat(MOCK_WARNINGS, "\n        "))

report("ui")
if TESTS_FAILED > 0 then error("test failures", 0) end
