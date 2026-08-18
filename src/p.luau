--!nonstrict
-- p  ·  the window
--
-- Tabs across the top, work in the middle, actions along the bottom.  The
-- bottom bar is where the plugin's two real verbs live -- write the script out,
-- and undo -- so they sit in the same place whichever tab you are on.
--
-- Keyboard handling lives here too, because shortcuts belong to the window
-- rather than to any one view.

local a = require(script.Parent.a)
local b = require(script.Parent.b)
local c = require(script.Parent.c)
local j = require(script.Parent.j)
local k = require(script.Parent.k)
local l = require(script.Parent.l)
local m = require(script.Parent.m)
local n = require(script.Parent.n)
local o = require(script.Parent.o)

local UserInputService = game:GetService("UserInputService")

local p = {}

local TABS = {
	{ id = "build", label = "build", hint = "The canvas, the palette and the generated Luau." },
	{ id = "learn", label = "learn", hint = "Twenty-six lessons, from first block to first script." },
	{ id = "import", label = "import", hint = "Turn a script you have selected into blocks." },
	{ id = "setup", label = "setup", hint = "Projects, where scripts go, theme, shortcuts." },
}

--=============================================================================
-- top bar: wordmark, tabs, project name
--=============================================================================

local function topBar(app, parent, shell)
	local bar = b.new("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, a.metric.topBar),
		bg = "panel",
		Parent = parent,
	})
	b.rule({ Position = UDim2.new(0, 0, 1, -1), parent = bar })

	-- a drawn mark rather than an image asset
	local mark = b.new("Frame", {
		Size = UDim2.fromOffset(18, a.metric.topBar),
		Position = UDim2.fromOffset(14, 0),
		Parent = bar,
	})
	for index = 1, 3 do
		b.new("Frame", {
			Size = UDim2.fromOffset(14 - (index - 1) * 4, 2),
			Position = UDim2.fromOffset(0, 15 + (index - 1) * 5),
			bg = index == 1 and "accent" or "text3",
			BackgroundTransparency = index == 1 and 0 or 0.4,
			Parent = mark,
		})
	end

	b.text({
		Text = "ABlocks",
		Size = UDim2.fromOffset(70, a.metric.topBar),
		Position = UDim2.fromOffset(38, 0),
		Font = a.font.uiBold,
		TextSize = 13,
		fg = "text2",
		Parent = bar,
	})
	b.tip(mark, "ABlocks -- blocks in, Luau out.")

	local tabs = {}
	local tabStrip = b.new("Frame", {
		Size = UDim2.new(0, #TABS * 84, 1, 0),
		Position = UDim2.fromOffset(124, 0),
		layout = { dir = "x", gap = 0 },
		Parent = bar,
	})

	for index, tab in ipairs(TABS) do
		local button = b.new("TextButton", {
			Size = UDim2.fromOffset(84, a.metric.topBar),
			LayoutOrder = index,
			bg = "panel",
			Parent = tabStrip,
		})

		local label = b.text({
			Text = string.upper(tab.label),
			Size = UDim2.fromScale(1, 1),
			Font = a.font.uiBold,
			TextSize = 11,
			fg = "text3",
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})

		-- the active tab is marked by a rule under it, not by a filled shape
		local marker = b.new("Frame", {
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.new(0, 0, 1, -2),
			bg = "accent",
			Visible = false,
			ZIndex = 3,
			Parent = button,
		})

		b.tip(button, tab.hint)
		button.MouseButton1Click:Connect(function() shell.showTab(tab.id) end)
		b.hover(button, function()
			if shell.tab ~= tab.id then label.TextColor3 = a.c.text2 end
		end, function()
			if shell.tab ~= tab.id then label.TextColor3 = a.c.text3 end
		end)

		tabs[tab.id] = { button = button, label = label, marker = marker }
	end

	-- project name, editable in place
	local nameBox = b.new("TextBox", {
		Text = app.doc.name,
		PlaceholderText = "project name",
		ClearTextOnFocus = false,
		Size = UDim2.fromOffset(220, 24),
		Position = UDim2.new(1, -276, 0, 10),
		Font = a.font.uiBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		fg = "text",
		ph = "text3",
		Parent = bar,
	})
	nameBox.FocusLost:Connect(function()
		local name = string.match(nameBox.Text, "^%s*(.-)%s*$")
		if name == "" then name = "Untitled" end
		nameBox.Text = name
		app:rename(name)
	end)
	app:on("doc", function()
		if not nameBox:IsFocused() then nameBox.Text = app.doc.name end
	end)

	local themeButton = b.new("TextButton", {
		Size = UDim2.fromOffset(34, a.metric.topBar),
		Position = UDim2.new(1, -44, 0, 0),
		bg = "panel",
		Parent = bar,
	})
	local themeMark = b.new("Frame", {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.fromOffset(11, 16),
		bg = "text2",
		radius = 6,
		Parent = themeButton,
	})
	b.new("Frame", {
		Size = UDim2.fromOffset(6, 12),
		bg = "panel",
		Parent = themeMark,
	})
	b.tip(themeButton, "Switch between the ink and paper themes.")
	themeButton.MouseButton1Click:Connect(function()
		local name = a.toggleTheme()
		app:setSetting("theme", name)
		app:setStatus(name .. " theme")
	end)

	return bar, tabs
end

--=============================================================================
-- bottom: actions, then a thin status strip
--=============================================================================

local function actionBar(app, parent, shell)
	local bar = b.new("Frame", {
		Name = "ActionBar",
		Size = UDim2.new(1, 0, 0, a.metric.actionBar),
		Position = UDim2.new(0, 0, 1, -a.metric.actionBar - a.metric.statusBar),
		bg = "panel",
		Parent = parent,
	})
	b.rule({ parent = bar })

	local left = b.new("Frame", {
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		layout = { dir = "x", gap = 6, align = "middle" },
		Parent = bar,
	})

	local function action(parentFrame, label, hint, order, onClick, accent)
		local button = b.button({
			label = label,
			Size = UDim2.fromOffset(#label * 8 + 24, 26),
			LayoutOrder = order,
			bg = accent and "accent" or "raised",
			labelColor = accent and "accentInk" or "text",
			Parent = parentFrame,
		})
		b.tip(button, hint)
		button.MouseButton1Click:Connect(onClick)
		return button
	end

	local undo = action(left, "undo", "Ctrl+Z", 1, function() app:undo() end)
	local redo = action(left, "redo", "Ctrl+Y", 2, function() app:redo() end)
	action(left, "tidy", "Line every stack up in a column.  Ctrl+L", 3, function()
		if app.canvas then app.canvas:tidy() end
	end)
	action(left, "100%", "Zoom back to 100%.  Ctrl+0", 4, function()
		if app.canvas then app.canvas:resetZoom() end
	end)
	action(left, "save", "Save this project.  Ctrl+S", 5, function() app:save() end)

	local function paintHistory()
		undo:SetAttribute("disabled", not app:canUndo())
		redo:SetAttribute("disabled", not app:canRedo())
		undo:FindFirstChildWhichIsA("TextLabel").TextTransparency = app:canUndo() and 0 or 0.55
		redo:FindFirstChildWhichIsA("TextLabel").TextTransparency = app:canRedo() and 0 or 0.55
	end
	app:on("doc", paintHistory)
	paintHistory()

	-- right hand side: what kind of script, and writing it out
	local right = b.new("Frame", {
		Size = UDim2.new(0, 420, 1, 0),
		Position = UDim2.new(1, -432, 0, 0),
		Parent = bar,
	})
	b.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = right,
	})

	local kindButton = b.button({
		label = app:scriptKind(),
		Size = UDim2.fromOffset(110, 26),
		LayoutOrder = 1,
		Parent = right,
	})
	local kindLabel = kindButton:FindFirstChildWhichIsA("TextLabel")
	kindButton.MouseButton1Click:Connect(function()
		local at = table.find(o.KINDS, app:scriptKind()) or 0
		app:setScriptKind(o.KINDS[(at % #o.KINDS) + 1])
	end)

	local copy = b.button({
		label = "copy",
		Size = UDim2.fromOffset(64, 26),
		LayoutOrder = 2,
		Parent = right,
	})
	b.tip(copy, "Studio gives plugins no clipboard, so this opens the code\n" ..
		"selected and ready for Ctrl+C.")
	copy.MouseButton1Click:Connect(function()
		n.textModal("generated luau", shell.code and shell.code.code or "")
	end)

	local insert = b.button({
		label = "Insert script",
		Size = UDim2.fromOffset(170, 26),
		LayoutOrder = 3,
		bg = "accent",
		labelColor = "accentInk",
		Parent = right,
	})
	local insertLabel = insert:FindFirstChildWhichIsA("TextLabel")
	insert.MouseButton1Click:Connect(function()
		if shell.code then shell.code:insertScript() end
	end)

	-- Both the kind and the button follow the document: converting a script
	-- ties the project to it, and the button then offers to update it.
	local function paintTarget()
		kindLabel.Text = app:scriptKind()
		local tied = app.doc.origin ~= nil
		b.tip(kindButton, tied
			and ("This project came from a " .. app:scriptKind() ..
				".\nChanging it here unties it from that script.")
			or ("Which kind of script to write.\nA " .. app:scriptKind() ..
				" goes to " .. app:destinationFor() .. "."))
		if shell.code then
			local label, hint = shell.code:insertLabel()
			insertLabel.Text = label
			b.tip(insert, hint .. "   Ctrl+Enter")
		end
	end
	app:on("doc", paintTarget)
	app:on("settings", paintTarget)
	shell.paintTarget = paintTarget

	return bar
end

local function statusStrip(app, parent)
	local strip = b.new("Frame", {
		Name = "StatusStrip",
		Size = UDim2.new(1, 0, 0, a.metric.statusBar),
		Position = UDim2.new(0, 0, 1, -a.metric.statusBar),
		bg = "panel",
		Parent = parent,
	})
	b.rule({ parent = strip })

	local message = b.mono({
		Text = "ready",
		Size = UDim2.new(1, -320, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextSize = 10,
		fg = "text3",
		Parent = strip,
	})

	local stats = b.mono({
		Text = "",
		Size = UDim2.fromOffset(300, a.metric.statusBar),
		Position = UDim2.new(1, -312, 0, 0),
		TextSize = 10,
		fg = "text3",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = strip,
	})

	local function paint()
		local counts = app:stats()
		local saved = "unsaved"
		if not app.dirty then
			saved = app.lastSaved
				and ("saved " .. os.date("%H:%M", app.lastSaved))
				or "saved"
		end
		stats.Text = string.format("%d blocks   %d stacks   %s",
			counts.blocks, counts.stacks, saved)
	end
	app:on("doc", paint)
	app:on("status", paint)
	app:on("status", function(text)
		message.Text = text == "" and "ready" or text
	end)
	paint()
	return strip
end

--=============================================================================
-- keyboard
--=============================================================================

local function keyboard(app, shell)
	local focused = true
	local widget = app.widget

	widget.WindowFocused:Connect(function() focused = true end)
	widget.WindowFocusReleased:Connect(function() focused = false end)

	-- Any focused text box counts, not just a block field: Delete while typing
	-- in the palette search must delete a letter, not the selected block.
	local function typing()
		local ok, box = pcall(function()
			return UserInputService:GetFocusedTextBox()
		end)
		if ok and box then return true end
		local canvas = app.canvas
		return canvas and canvas.editing ~= nil
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not focused or not widget.Enabled then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

		local key = input.KeyCode
		local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		local popup = m.popup()

		-- the completion list gets first refusal on the navigation keys
		if popup.open then
			if key == Enum.KeyCode.Down then
				popup:move(1)
				return
			elseif key == Enum.KeyCode.Up then
				popup:move(-1)
				return
			elseif key == Enum.KeyCode.Tab then
				popup:accept()
				return
			elseif key == Enum.KeyCode.Escape then
				popup:hide()
				return
			end
		end

		-- Ctrl+Space reopens the completion list in whichever field has focus
		if ctrl and key == Enum.KeyCode.Space then
			local canvas = app.canvas
			if canvas and canvas.refreshCompletion then canvas.refreshCompletion() end
			return
		end

		if typing() then return end

		if ctrl then
			if key == Enum.KeyCode.Z then
				if shift then app:redo() else app:undo() end
			elseif key == Enum.KeyCode.Y then
				app:redo()
			elseif key == Enum.KeyCode.D then
				if app.canvas then app.canvas:duplicateSelected() end
			elseif key == Enum.KeyCode.S then
				app:save()
			elseif key == Enum.KeyCode.F then
				shell.showTab("build")
				if shell.palette then shell.palette:focusSearch() end
			elseif key == Enum.KeyCode.L then
				if app.canvas then app.canvas:tidy() end
			elseif key == Enum.KeyCode.Zero then
				if app.canvas then app.canvas:resetZoom() end
			elseif key == Enum.KeyCode.Return then
				if shell.code then shell.code:insertScript() end
			end
			return
		end

		if key == Enum.KeyCode.Delete or key == Enum.KeyCode.Backspace then
			if app.canvas then app.canvas:deleteSelected() end
		elseif key == Enum.KeyCode.Escape then
			app:select(nil)
		end
	end)
end

--=============================================================================
-- assembly
--=============================================================================

function p.mount(app, widget)
	a.setTheme(app.settings.theme or "ink")

	local shell = { tab = "build" }

	local rootFrame = b.new("Frame", {
		Name = "ABlocks",
		Size = UDim2.fromScale(1, 1),
		bg = "bg",
		Parent = widget,
	})

	local overlay = b.new("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 500,
		Parent = rootFrame,
	})
	b.setOverlay(overlay)

	local _, tabs = topBar(app, rootFrame, shell)

	local chrome = a.metric.topBar + a.metric.actionBar + a.metric.statusBar
	local pages = b.new("Frame", {
		Name = "Pages",
		Size = UDim2.new(1, 0, 1, -chrome),
		Position = UDim2.fromOffset(0, a.metric.topBar),
		Parent = rootFrame,
	})

	-- build ---------------------------------------------------------------------
	local buildPage = b.new("Frame", {
		Name = "Build",
		Size = UDim2.fromScale(1, 1),
		Parent = pages,
	})

	shell.palette = l.mount(app, buildPage)

	local middle = b.new("Frame", {
		Name = "Middle",
		Size = UDim2.new(1, -236, 1, 0),
		Position = UDim2.fromOffset(236, 0),
		Parent = buildPage,
	})

	local canvasHolder = b.new("Frame", {
		Size = UDim2.new(1, -400, 1, 0),
		Parent = middle,
	})
	app.canvas = m.mount(app, canvasHolder)

	local codeHolder = b.new("Frame", {
		Size = UDim2.new(0, 400, 1, 0),
		Position = UDim2.new(1, -400, 0, 0),
		Parent = middle,
	})
	shell.code = n.codePanel(app, codeHolder)

	-- the code panel can be folded away when the canvas needs the room
	local function applyCodeVisibility()
		local shown = app.settings.showCode
		codeHolder.Visible = shown
		canvasHolder.Size = shown and UDim2.new(1, -400, 1, 0) or UDim2.fromScale(1, 1)
	end
	app:on("settings", function(key)
		if key == "showCode" then applyCodeVisibility() end
	end)
	applyCodeVisibility()

	local fold = b.button({
		Size = UDim2.fromOffset(18, 34),
		Position = UDim2.new(1, -418, 0, 8),
		bg = "panel",
		ZIndex = 30,
		Parent = middle,
	})
	local foldMark = b.chevron(9, "text3")
	foldMark.Position = UDim2.fromOffset(4, 12)
	foldMark.Rotation = app.settings.showCode and -90 or 90
	foldMark.Parent = fold
	b.tip(fold, "Show or hide the generated Luau.")
	fold.MouseButton1Click:Connect(function()
		app:setSetting("showCode", not app.settings.showCode)
		fold.Position = app.settings.showCode
			and UDim2.new(1, -418, 0, 8) or UDim2.new(1, -26, 0, 8)
		foldMark.Rotation = app.settings.showCode and -90 or 90
	end)

	-- other tabs -------------------------------------------------------------------
	shell.learn = k.mount(app, pages)
	shell.import = n.importView(app, pages)
	shell.setup = n.settingsView(app, pages)

	actionBar(app, rootFrame, shell)
	statusStrip(app, rootFrame)

	local pageFor = {
		build = buildPage,
		learn = shell.learn.frame,
		import = shell.import.frame,
		setup = shell.setup.frame,
	}

	function shell.showTab(id)
		if not pageFor[id] then return end
		shell.tab = id
		for tabId, page in pairs(pageFor) do
			page.Visible = tabId == id
		end
		for tabId, parts in pairs(tabs) do
			local chosen = tabId == id
			parts.marker.Visible = chosen
			parts.label.TextColor3 = chosen and a.c.text or a.c.text3
			parts.button.BackgroundColor3 = chosen and a.c.raised or a.c.panel
		end
		-- the import tab is only truthful if it re-reads the selection on the
		-- way in, since the Explorer may have changed while it was hidden
		if id == "import" and shell.import and shell.import.describe then
			shell.import.describe()
		end
		if id ~= "build" and app.dirty then app:save() end
	end
	app.showTab = shell.showTab

	shell.paintTarget()
	-- First run has no saved project: open on the lessons rather than dropping
	-- someone straight onto a canvas they have no vocabulary for yet.
	shell.showTab(app.projectId and "build" or "learn")

	keyboard(app, shell)

	a.onChange(function()
		shell.showTab(shell.tab)
		shell.paintTarget()
	end)

	app:setStatus(string.format("%d blocks, %d lessons -- press learn if this is new",
		c.count(), j.count()))

	return shell
end

return p
