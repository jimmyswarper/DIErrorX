--!nonstrict
-- n  ·  text panels: generated code, import, settings
--
-- The code panel is the point of the whole plugin, so it is not a preview
-- tucked in a drawer: it sits open beside the canvas, updates on every
-- keystroke, and is wired both ways -- hover a block to light up its lines,
-- hover a line to outline the block that wrote it.
--
-- Studio gives plugins no clipboard API, so "copy" opens the text selected and
-- ready for Ctrl+C rather than pretending.

local a = require(script.Parent.a)
local b = require(script.Parent.b)
local d = require(script.Parent.d)
local e = require(script.Parent.e)
local f = require(script.Parent.f)
local h = require(script.Parent.h)

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local n = {}

--=============================================================================
-- syntax highlighting
--=============================================================================

local function escape(text)
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	text = string.gsub(text, '"', "&quot;")
	return text
end

local function hex(colour)
	return string.format("#%02X%02X%02X",
		math.floor(colour.R * 255 + 0.5),
		math.floor(colour.G * 255 + 0.5),
		math.floor(colour.B * 255 + 0.5))
end

local function tokenColour(token, nextToken)
	local syntax = a.c.syntax
	if token.t == "comment" then return syntax.comment end
	if token.t == "kw" then return syntax.kw end
	if token.t == "string" then return syntax.str end
	if token.t == "number" then return syntax.num end
	if token.t == "name" then
		if nextToken and nextToken.t == "sym" and nextToken.v == "(" then
			return syntax.call
		end
		return syntax.name
	end
	return syntax.sym
end

-- One RichText string per line, coloured by the same lexer the parser uses.
function n.highlight(code)
	local tokens = f.scan(code)
	local lines = {}
	local starts = { 1 }
	for position in string.gmatch(code, "()\n") do
		starts[#starts + 1] = position + 1
	end

	local cursor = 1
	for index, lineStart in ipairs(starts) do
		local lineEnd = (starts[index + 1] and starts[index + 1] - 2) or #code
		local pieces = {}
		local at = lineStart

		-- rewind to the first token that could touch this line
		while cursor > 1 and tokens[cursor - 1] and tokens[cursor - 1].e >= lineStart do
			cursor = cursor - 1
		end
		local scan = cursor
		while tokens[scan] and tokens[scan].s <= lineEnd do
			local token = tokens[scan]
			if token.e >= lineStart then
				local from = math.max(token.s, lineStart)
				local to = math.min(token.e, lineEnd)
				if from > at then
					pieces[#pieces + 1] = escape(string.sub(code, at, from - 1))
				end
				if to >= from then
					pieces[#pieces + 1] = string.format('<font color="%s">%s</font>',
						hex(tokenColour(token, tokens[scan + 1])),
						escape(string.sub(code, from, to)))
					at = to + 1
				end
			end
			if token.e < lineStart then cursor = scan + 1 end
			scan = scan + 1
		end
		if at <= lineEnd then
			pieces[#pieces + 1] = escape(string.sub(code, at, lineEnd))
		end
		lines[index] = table.concat(pieces)
	end
	return lines
end

--=============================================================================
-- a modal of selectable text, standing in for a clipboard
--=============================================================================

function n.textModal(title, body, hint)
	local overlay = b.overlay()
	if not overlay then return end

	local shade = b.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		bg = "bg",
		BackgroundTransparency = 0.35,
		ZIndex = 900,
		Parent = overlay,
	})

	local panel = b.new("Frame", {
		Size = UDim2.new(0, 520, 0, 400),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		bg = "panel",
		stroke = { color = "line" },
		ZIndex = 901,
		Parent = shade,
	})

	b.micro(title, {
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(12, 8),
		fg = "accent",
		ZIndex = 902,
		Parent = panel,
	})

	b.text({
		Text = hint or "Select all with Ctrl+A, then copy with Ctrl+C.",
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(12, 28),
		fg = "text3",
		TextSize = 11,
		ZIndex = 902,
		Parent = panel,
	})

	local scroll = b.new("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -92),
		Position = UDim2.fromOffset(12, 50),
		bg = "field",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 902,
		Parent = panel,
	})

	local box = b.new("TextBox", {
		Text = body,
		MultiLine = true,
		ClearTextOnFocus = false,
		TextEditable = false,
		Size = UDim2.new(1, -8, 0, 0),
		Position = UDim2.fromOffset(4, 4),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = a.font.mono,
		TextSize = 12,
		fg = "text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 903,
		Parent = scroll,
	})

	local close = b.button({
		label = "Close",
		Size = UDim2.fromOffset(90, 26),
		Position = UDim2.new(1, -102, 1, -34),
		bg = "raised",
		ZIndex = 902,
		Parent = panel,
	})
	close.MouseButton1Click:Connect(function() shade:Destroy() end)

	task.defer(function()
		box:CaptureFocus()
		box.CursorPosition = #body + 1
		box.SelectionStart = 1
	end)
	return shade
end

--=============================================================================
-- code panel
--=============================================================================

local Code = {}
Code.__index = Code

function n.codePanel(app, parent)
	local view = setmetatable({ app = app, lineFrames = {} }, Code)

	view.frame = b.new("Frame", {
		Name = "Code",
		Size = UDim2.new(0, 400, 1, 0),
		bg = "panel",
		Parent = parent,
	})
	b.rule({ parent = view.frame })

	local head = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		Parent = view.frame,
	})
	b.micro("generated luau", {
		Size = UDim2.new(0, 140, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		fg = "text2",
		Parent = head,
	})
	view.count = b.mono({
		Text = "",
		Size = UDim2.new(0, 120, 1, 0),
		Position = UDim2.new(1, -132, 0, 0),
		TextSize = 10,
		fg = "text3",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = head,
	})
	b.rule({ Position = UDim2.new(0, 0, 1, 0), parent = head })

	view.scroll = b.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -34 - 40),
		Position = UDim2.fromOffset(0, 34),
		bg = "sunken",
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		Parent = view.frame,
	})
	view.layout = b.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
		Parent = view.scroll,
	})
	b.new("UIPadding", {
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 16),
		Parent = view.scroll })

	-- actions ------------------------------------------------------------------
	local bar = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, -40),
		bg = "panel",
		Parent = view.frame,
	})
	b.rule({ parent = bar })

	local insert = b.button({
		label = "Insert script",
		Size = UDim2.fromOffset(112, 26),
		Position = UDim2.fromOffset(12, 7),
		bg = "accent",
		labelColor = "accentInk",
		Parent = bar,
	})
	insert.MouseButton1Click:Connect(function() view:insertScript() end)

	local copy = b.button({
		label = "Copy",
		Size = UDim2.fromOffset(70, 26),
		Position = UDim2.fromOffset(132, 7),
		Parent = bar,
	})
	copy.MouseButton1Click:Connect(function()
		n.textModal("generated luau", view.code or "")
	end)

	view.kindButton = b.button({
		label = app.settings.scriptKind,
		Size = UDim2.fromOffset(96, 26),
		Position = UDim2.new(1, -108, 0, 7),
		Parent = bar,
	})
	view.kindButton.MouseButton1Click:Connect(function()
		local order = { "Script", "LocalScript", "ModuleScript" }
		local at = 1
		for index, kind in ipairs(order) do
			if kind == app.settings.scriptKind then at = index end
		end
		local nextKind = order[(at % #order) + 1]
		app:setSetting("scriptKind", nextKind)
		view.kindButton:FindFirstChildWhichIsA("TextLabel").Text = nextKind
		app:setStatus("will insert a " .. nextKind)
	end)
	b.tip(view.kindButton, "Which kind of script to insert. Server logic wants a\n" ..
		"Script; input and interface want a LocalScript.")

	app:on("doc", function() view:refresh() end)
	app:on("codeDirty", function() view:queueRefresh() end)
	app:on("hover", function(blockId) view:highlightBlock(blockId) end)
	a.onChange(function() view:refresh() end)

	view:refresh()
	return view
end

local MAX_INTERACTIVE_LINES = 700

-- Typing fires per keystroke; rebuilding a few hundred labels that often is
-- wasteful, so redraws are coalesced into roughly ten a second.
function Code:queueRefresh()
	self.refreshToken = (self.refreshToken or 0) + 1
	local token = self.refreshToken
	task.delay(0.1, function()
		if token == self.refreshToken then self:refresh() end
	end)
end

function Code:refresh()
	self.refreshToken = (self.refreshToken or 0) + 1
	local app = self.app
	local code, meta = e.generate(app.doc, { header = app.settings.banner })
	self.code = code
	self.meta = meta
	self.count.Text = meta.lineCount .. " lines"

	b.clear(self.scroll)
	self.lineFrames = {}

	if meta.lineCount > MAX_INTERACTIVE_LINES then
		b.mono({
			Text = code,
			Size = UDim2.new(1, -16, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(8, 0),
			TextYAlignment = Enum.TextYAlignment.Top,
			TextSize = 12,
			Parent = self.scroll,
		})
		return
	end

	local lines = n.highlight(code)
	for index, rich in ipairs(lines) do
		local blockId = meta.blockOfLine[index]
		local row = b.new("Frame", {
			Size = UDim2.new(0, 0, 0, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = index,
			bg = "sunken",
			Parent = self.scroll,
		})

		b.mono({
			Text = string.format("%3d", index),
			Size = UDim2.fromOffset(30, 16),
			TextSize = 10,
			fg = "text3",
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})

		b.mono({
			Text = rich,
			RichText = true,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			Position = UDim2.fromOffset(40, 0),
			TextSize = 12,
			Parent = row,
		})

		if blockId then
			self.lineFrames[index] = { frame = row, blockId = blockId }
			row.MouseEnter:Connect(function()
				self.app.hover = blockId
				self.app:emit("hover", blockId)
			end)
			row.MouseLeave:Connect(function()
				if self.app.hover == blockId then
					self.app.hover = nil
					self.app:emit("hover", nil)
				end
			end)
			row.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					self.app:select(blockId)
					if self.app.canvas then self.app.canvas:focusBlock(blockId) end
				end
			end)
		end
	end

	self:highlightBlock(self.app.hover)
end

function Code:highlightBlock(blockId)
	for _, entry in pairs(self.lineFrames) do
		if entry.frame.Parent then
			entry.frame.BackgroundColor3 =
				(blockId and entry.blockId == blockId) and a.c.select or a.c.sunken
		end
	end
end

local PARENTS = {
	Script = { "ServerScriptService", "Workspace", "ServerStorage" },
	LocalScript = { "StarterPlayer.StarterPlayerScripts", "StarterGui", "ReplicatedFirst" },
	ModuleScript = { "ReplicatedStorage", "ServerScriptService", "ServerStorage" },
}

local function resolveParent(path)
	local target = game
	for piece in string.gmatch(path, "[^%.]+") do
		local ok, child = pcall(function()
			return target:FindFirstChild(piece) or game:GetService(piece)
		end)
		if not ok or not child then return nil end
		target = child
	end
	return target
end

function Code:insertScript()
	local app = self.app
	local kind = app.settings.scriptKind
	local wanted = app.settings.insertParent
	local parent = resolveParent(wanted)
	if not parent or not table.find(PARENTS[kind] or {}, wanted) then
		parent = resolveParent(PARENTS[kind][1])
	end
	if not parent then
		app:setStatus("could not find somewhere to put it")
		return
	end

	local recording = ChangeHistoryService:TryBeginRecording("DIErrorX insert")
	local ok, err = pcall(function()
		local made = Instance.new(kind)
		made.Name = app.doc.name
		made.Source = self.code
		made.Parent = parent
		Selection:Set({ made })
		return made
	end)

	if recording then
		ChangeHistoryService:FinishRecording(recording,
			ok and Enum.FinishRecordingOperation.Commit
			or Enum.FinishRecordingOperation.Cancel)
	end

	if ok then
		app:setStatus("inserted " .. kind .. " into " .. parent.Name)
	else
		app:setStatus("Studio refused: allow script injection for this plugin")
		n.textModal("could not write the script", tostring(err),
			"Studio asks permission before a plugin may write script source.\n" ..
			"Look for the prompt, or allow it in Plugin Management, then try again.")
	end
end

--=============================================================================
-- import
--=============================================================================

function n.importView(app, parent)
	local view = { app = app }

	view.frame = b.new("Frame", {
		Name = "Import",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		bg = "bg",
		Parent = parent,
	})

	local column = b.new("Frame", {
		Size = UDim2.new(1, -80, 1, -40),
		Position = UDim2.fromOffset(40, 20),
		Parent = view.frame,
	})

	b.micro("paste luau, get blocks", {
		Size = UDim2.new(1, 0, 0, 18),
		fg = "accent",
		Parent = column,
	})
	b.text({
		Text = "Anything this converter does not recognise is kept exactly as it was, " ..
			"in a raw Luau block, so nothing is lost. Importing replaces the canvas.",
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 20),
		TextWrapped = true,
		fg = "text2",
		Parent = column,
	})

	local editor = b.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -160),
		Position = UDim2.fromOffset(0, 62),
		bg = "sunken",
		stroke = { color = "line" },
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = column,
	})

	view.input = b.new("TextBox", {
		Text = "",
		PlaceholderText = "-- paste a script here\n\nscript.Parent.Touched:Connect(function(hit)\n\tprint(hit)\nend)",
		MultiLine = true,
		ClearTextOnFocus = false,
		Size = UDim2.new(1, -16, 0, 0),
		Position = UDim2.fromOffset(8, 8),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = a.font.mono,
		TextSize = 13,
		fg = "text",
		ph = "text3",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = editor,
	})
	b.new("UISizeConstraint", { MinSize = Vector2.new(0, 260), Parent = view.input })

	local report = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 1, -90),
		Parent = column,
	})
	view.reportText = b.text({
		Text = "",
		Size = UDim2.new(1, 0, 1, 0),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		fg = "text2",
		TextSize = 11,
		Parent = report,
	})

	local convert = b.button({
		label = "Convert to blocks",
		Size = UDim2.fromOffset(150, 28),
		Position = UDim2.new(0, 0, 1, -32),
		bg = "accent",
		labelColor = "accentInk",
		Parent = column,
	})

	local sample = b.button({
		label = "Use a sample",
		Size = UDim2.fromOffset(120, 28),
		Position = UDim2.fromOffset(162, 0),
		Parent = convert.Parent,
	})
	sample.Position = UDim2.new(0, 162, 1, -32)
	sample.MouseButton1Click:Connect(function()
		view.input.Text = [[
local Players = game:GetService("Players")

local COOLDOWN = 3
local trap = script.Parent

trap.Touched:Connect(function(hit)
	local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum:TakeDamage(20)
	trap.Transparency = 0.7
	task.wait(COOLDOWN)
	trap.Transparency = 0
end)

Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " joined")
end)
]]
	end)

	convert.MouseButton1Click:Connect(function()
		local source = view.input.Text
		if string.match(source, "^%s*$") then
			view.reportText.Text = "Nothing to convert yet."
			view.reportText.TextColor3 = a.c.text3
			return
		end

		local doc, reportData, err = h.fromCode(source, app.doc.name)
		if not doc then
			view.reportText.TextColor3 = a.c.err
			view.reportText.Text = string.format(
				"Line %d, column %d: %s\n\nThe converter reads the whole script before " ..
				"building anything, so nothing has changed on the canvas.",
				err.line, err.col, err.msg)
			app:setStatus("import failed on line " .. err.line)
			return
		end

		app:setDoc(doc, "import luau")
		view.reportText.TextColor3 = a.c.text2

		local lines = {
			string.format("%d statements converted into %d blocks across %d stacks.",
				reportData.total, d.count(doc), reportData.stacks),
		}
		if reportData.raw > 0 then
			local where = {}
			for index, note in ipairs(reportData.notes) do
				if index <= 6 then
					where[#where + 1] = "line " .. note.line .. " (" .. note.text .. ")"
				end
			end
			lines[#lines + 1] = string.format(
				"%d kept as raw Luau: %s.", reportData.raw, table.concat(where, ", "))
		else
			lines[#lines + 1] = "Every statement matched a block."
		end
		view.reportText.Text = table.concat(lines, "\n")
		app:setStatus("imported " .. reportData.total .. " statements")
		if app.showTab then app.showTab("build") end
	end)

	return view
end

--=============================================================================
-- settings
--=============================================================================

local function section(parent, order, title)
	local frame = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		layout = { dir = "y", gap = 6 },
		Parent = parent,
	})
	b.micro(title, {
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 0,
		fg = "accent",
		Parent = frame,
	})
	b.rule({ LayoutOrder = 1, parent = frame, bg = "lineSoft" })
	return frame
end

local function row(parent, order, label, help)
	local frame = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, help and 40 or 28),
		LayoutOrder = order,
		Parent = parent,
	})
	b.text({
		Text = label,
		Size = UDim2.new(0, 210, 0, 20),
		Parent = frame,
	})
	if help then
		b.text({
			Text = help,
			Size = UDim2.new(1, -240, 0, 18),
			Position = UDim2.fromOffset(0, 18),
			fg = "text3",
			TextSize = 11,
			TextWrapped = true,
			Parent = frame,
		})
	end
	return frame
end

local function toggle(parent, value, onChange)
	local button = b.button({
		label = value and "on" or "off",
		Size = UDim2.fromOffset(56, 22),
		Position = UDim2.new(1, -60, 0, 0),
		bg = value and "accentSoft" or "raised",
		Parent = parent,
	})
	local label = button:FindFirstChildWhichIsA("TextLabel")
	button.MouseButton1Click:Connect(function()
		value = not value
		label.Text = value and "on" or "off"
		b.states(button, value and "accentSoft" or "raised")
		onChange(value)
	end)
	return button
end

function n.settingsView(app, parent)
	local view = { app = app }

	view.frame = b.new("Frame", {
		Name = "Settings",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		bg = "bg",
		Parent = parent,
	})

	local scroll = b.new("ScrollingFrame", {
		Size = UDim2.new(1, -40, 1, -20),
		Position = UDim2.fromOffset(20, 10),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = view.frame,
	})
	local column = b.new("Frame", {
		Size = UDim2.new(1, -20, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		layout = { dir = "y", gap = 18 },
		Parent = scroll,
	})
	b.new("UIPadding", { PaddingBottom = UDim.new(0, 40), Parent = column })

	-- projects -----------------------------------------------------------------
	local projects = section(column, 1, "projects")
	view.projectList = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		layout = { dir = "y", gap = 2 },
		Parent = projects,
	})

	local function paintProjects()
		b.clear(view.projectList)
		for index, project in ipairs(app.projects) do
			local isOpen = project.id == app.projectId
			local entry = b.new("Frame", {
				Size = UDim2.new(1, 0, 0, 26),
				LayoutOrder = index,
				bg = isOpen and "raised" or "panel",
				Parent = view.projectList,
			})
			b.text({
				Text = project.name or "Untitled",
				Size = UDim2.new(1, -220, 1, 0),
				Position = UDim2.fromOffset(8, 0),
				fg = isOpen and "text" or "text2",
				Font = isOpen and a.font.uiBold or a.font.ui,
				Parent = entry,
			})
			b.mono({
				Text = (project.blocks or 0) .. " blocks",
				Size = UDim2.fromOffset(90, 26),
				Position = UDim2.new(1, -190, 0, 0),
				TextSize = 10,
				fg = "text3",
				Parent = entry,
			})
			local open = b.button({
				label = isOpen and "open" or "switch to",
				Size = UDim2.fromOffset(84, 20),
				Position = UDim2.new(1, -96, 0, 3),
				Parent = entry,
			})
			open:SetAttribute("disabled", isOpen)
			open.MouseButton1Click:Connect(function()
				if isOpen then return end
				app:openProject(project.id)
			end)
			local remove = b.button({
				label = "delete",
				Size = UDim2.fromOffset(56, 20),
				Position = UDim2.new(1, -58, 0, 3),
				Parent = entry,
			})
			remove.MouseButton1Click:Connect(function()
				app:deleteProject(project.id)
			end)
		end
	end

	local buttons = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 3,
		layout = { dir = "x", gap = 8 },
		Parent = projects,
	})
	local newButton = b.button({ label = "New project", Size = UDim2.fromOffset(110, 26),
		LayoutOrder = 1, Parent = buttons })
	newButton.MouseButton1Click:Connect(function()
		app:newProject("Untitled " .. (#app.projects + 1))
	end)
	local copyButton = b.button({ label = "Duplicate", Size = UDim2.fromOffset(96, 26),
		LayoutOrder = 2, Parent = buttons })
	copyButton.MouseButton1Click:Connect(function() app:duplicateProject() end)

	local exportButton = b.button({ label = "Export as text", Size = UDim2.fromOffset(116, 26),
		LayoutOrder = 3, Parent = buttons })
	exportButton.MouseButton1Click:Connect(function()
		local raw, err = app:exportProject()
		if not raw then
			app:setStatus(err or "could not export")
			return
		end
		n.textModal("project as json", raw,
			"Select all with Ctrl+A, copy with Ctrl+C, and paste it into Import project.")
	end)

	local importButton = b.button({ label = "Import project", Size = UDim2.fromOffset(116, 26),
		LayoutOrder = 4, Parent = buttons })
	importButton.MouseButton1Click:Connect(function()
		local shade = n.textModal("paste a project", "",
			"Paste exported project JSON here, then press Load.")
		local panel = shade:FindFirstChildWhichIsA("Frame")
		local box = panel:FindFirstChildWhichIsA("ScrollingFrame"):FindFirstChildWhichIsA("TextBox")
		box.TextEditable = true
		box.Text = ""
		local load = b.button({
			label = "Load",
			Size = UDim2.fromOffset(90, 26),
			Position = UDim2.new(1, -200, 1, -34),
			bg = "accent",
			labelColor = "accentInk",
			ZIndex = 902,
			Parent = panel,
		})
		load.MouseButton1Click:Connect(function()
			local ok, err = app:importProject(box.Text)
			app:setStatus(ok and "project loaded" or (err or "could not load that"))
			if ok then shade:Destroy() end
		end)
	end)

	app:on("projects", paintProjects)
	app:on("doc", paintProjects)
	paintProjects()

	-- look ----------------------------------------------------------------------
	local look = section(column, 2, "look")
	local themeRow = row(look, 2, "Theme", "Ink is the dark drafting board; paper is the light one.")
	local themeButtons = b.new("Frame", {
		Size = UDim2.fromOffset(130, 22),
		Position = UDim2.new(1, -134, 0, 0),
		layout = { dir = "x", gap = 6 },
		Parent = themeRow,
	})
	for index, name in ipairs({ "ink", "paper" }) do
		local button = b.button({
			label = name,
			Size = UDim2.fromOffset(60, 22),
			LayoutOrder = index,
			bg = a.c.name == name and "accentSoft" or "raised",
			Parent = themeButtons,
		})
		button.MouseButton1Click:Connect(function()
			a.setTheme(name)
			app:setSetting("theme", name)
		end)
	end

	local bannerRow = row(look, 3, "Banner comment",
		"Two lines at the top of the generated script naming the project.")
	toggle(bannerRow, app.settings.banner, function(value)
		app:setSetting("banner", value)
		app:emit("codeDirty")
	end)

	-- behaviour -------------------------------------------------------------------
	local behaviour = section(column, 3, "behaviour")
	local saveRow = row(behaviour, 2, "Autosave",
		"Saves a couple of seconds after you stop editing.")
	toggle(saveRow, app.settings.autoSave, function(value)
		app:setSetting("autoSave", value)
	end)

	local parentRow = row(behaviour, 3, "Insert into",
		"Where the Insert script button puts the script.")
	local parentButton = b.button({
		label = app.settings.insertParent,
		Size = UDim2.fromOffset(220, 22),
		Position = UDim2.new(1, -224, 0, 0),
		Parent = parentRow,
	})
	parentButton.MouseButton1Click:Connect(function()
		local options = PARENTS[app.settings.scriptKind] or PARENTS.Script
		local at = table.find(options, app.settings.insertParent) or 0
		local nextParent = options[(at % #options) + 1]
		app:setSetting("insertParent", nextParent)
		parentButton:FindFirstChildWhichIsA("TextLabel").Text = nextParent
	end)

	-- shortcuts ---------------------------------------------------------------------
	local keys = section(column, 4, "keyboard")
	local list = {
		{ "Ctrl+Z / Ctrl+Y", "undo, redo" },
		{ "Delete", "remove the selected block and what follows it" },
		{ "Ctrl+D", "duplicate the selection" },
		{ "Ctrl+F", "search the palette" },
		{ "Ctrl+S", "save the project" },
		{ "Ctrl+Enter", "insert the script into the game" },
		{ "Ctrl+L", "tidy the canvas" },
		{ "Ctrl+0", "zoom back to 100%" },
		{ "Ctrl+Space", "open the completion list in a field" },
		{ "Escape", "dismiss the completion list, or deselect" },
	}
	for index, entry in ipairs(list) do
		local line = b.new("Frame", {
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = index + 1,
			Parent = keys,
		})
		b.mono({
			Text = entry[1],
			Size = UDim2.fromOffset(150, 20),
			TextSize = 11,
			fg = "text",
			Parent = line,
		})
		b.text({
			Text = entry[2],
			Size = UDim2.new(1, -160, 1, 0),
			Position = UDim2.fromOffset(160, 0),
			fg = "text2",
			TextSize = 11,
			Parent = line,
		})
	end

	return view
end

return n
