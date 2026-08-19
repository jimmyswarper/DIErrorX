-- Mounts the entire plugin against the Roblox mock and drives it: every tab,
-- every tutorial, the palette, field editing, dragging, import, undo and both
-- themes.  Anything that would throw in Studio throws here.
local a = require(script.Parent.a)
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
	MOCK_KEYS = {}
	MOCK.fire(game:GetService("UserInputService"), "InputBegan", {
		UserInputType = Enum.UserInputType.Keyboard,
		KeyCode = Enum.KeyCode.Delete,
	}, false)
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
	MOCK_KEYS = ctrl and { LeftControl = true } or {}
	MOCK.fire(game:GetService("UserInputService"), "InputBegan", {
		UserInputType = Enum.UserInputType.Keyboard,
		KeyCode = Enum.KeyCode[name],
	}, false)
	MOCK.flush()
	MOCK_KEYS = {}
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
do
	shell.showTab("build")
	local anyBlock = nil
	d.walk(app.doc, function(block) anyBlock = anyBlock or block end)
	local frame = app.canvas.frames[anyBlock.id]
	check("a block's height comes only from its content", (function()
		for _, node in ipairs(frame:GetChildren()) do
			if node:IsA("GuiObject") then
				local size = node.Size
				-- a scale-sized child inside an auto-sizing parent is the loop
				if size and size.Y and size.Y.Scale ~= 0 then return false end
			end
		end
		return true
	end)(), "a child is sized from the block, which would stop it shrinking")
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
		local seen = {}
		for _, cat in ipairs(c.cats) do
			local colour = a.catColor(cat.id)
			check(theme .. ": " .. cat.id .. " has a colour",
				colour ~= nil and colour ~= a.c.text2,
				"it would fall back to grey")
			local key = string.format("%d,%d,%d",
				math.floor(colour.R * 255), math.floor(colour.G * 255),
				math.floor(colour.B * 255))
			check(theme .. ": " .. cat.id .. " does not share an ink", not seen[key],
				"same as " .. tostring(seen[key]))
			seen[key] = cat.id
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
