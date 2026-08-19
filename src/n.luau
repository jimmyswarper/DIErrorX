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
local o = require(script.Parent.o)
local q = require(script.Parent.q)

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
		Size = UDim2.new(0, 160, 1, 0),
		Position = UDim2.new(1, -172, 0, 0),
		TextSize = 10,
		fg = "text3",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = head,
	})
	b.rule({ Position = UDim2.new(0, 0, 1, 0), parent = head })

	-- Advice about the script kind this is headed for sits between the header
	-- and the code, where it is impossible to miss and costs no space when
	-- there is nothing to say.
	view.advice = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.Y,
		bg = "err",
		Visible = false,
		Parent = view.frame,
	})
	view.adviceText = b.text({
		Text = "",
		Size = UDim2.new(1, -16, 0, 0),
		Position = UDim2.fromOffset(14, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 11,
		LineHeight = 1.25,
		fg = "text2",
		bg = "panel",
		Parent = view.advice,
	})
	b.new("UIPadding", {
		PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
		Parent = view.adviceText })

	view.scroll = b.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -34),
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
	local kindNow = app:scriptKind()
	self.code = code
	self.meta = meta
	self.count.Text = kindNow .. "   " .. meta.lineCount .. " lines"

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

	self:showAdvice(e.advise(code, kindNow))

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

-- Shows the strip only when there is something to say.
function Code:showAdvice(notes)
	if #notes == 0 then
		self.advice.Visible = false
		self.scroll.Position = UDim2.fromOffset(0, 34)
		self.scroll.Size = UDim2.new(1, 0, 1, -34)
		return
	end

	local lines = {}
	for _, note in ipairs(notes) do
		lines[#lines + 1] = note.text
	end
	self.adviceText.Text = table.concat(lines, "\n")
	self.advice.Visible = true

	-- The strip auto-sizes, so the code area is repositioned once it has.
	task.defer(function()
		if not self.advice.Visible then return end
		local height = self.advice.AbsoluteSize.Y
		self.scroll.Position = UDim2.fromOffset(0, 34 + height)
		self.scroll.Size = UDim2.new(1, 0, 1, -34 - height)
	end)
end

function Code:highlightBlock(blockId)
	for _, entry in pairs(self.lineFrames) do
		if entry.frame.Parent then
			entry.frame.BackgroundColor3 =
				(blockId and entry.blockId == blockId) and a.c.select or a.c.sunken
		end
	end
end

--=============================================================================
-- writing the script out
--
-- Where the code goes is decided by what kind of script it is, and whether
-- this project was read out of a script that is still there.  Reading a
-- script's Source and writing it back both need Studio's script-injection
-- permission, so both are wrapped and explained rather than left to fail
-- silently.
--=============================================================================

-- Writes back into the script this project came from, when it still exists;
-- otherwise makes a new one where that kind of script belongs.
function Code:insertScript()
	local app = self.app
	local kind = app:scriptKind()
	local existing = app:originInstance()

	local recording = ChangeHistoryService:TryBeginRecording(
		existing and "ABlocks update" or "ABlocks insert")

	local ok, err = pcall(function()
		if existing then
			existing.Source = self.code
			Selection:Set({ existing })
			return existing
		end

		local parentPath = app:destinationFor(kind)
		local parent = o.resolvePath(parentPath)
		if not parent then
			error("could not find " .. parentPath, 0)
		end

		local made = Instance.new(kind)
		made.Name = app.doc.name
		made.Source = self.code
		made.Parent = parent
		Selection:Set({ made })
		app:setOrigin(made)
		return made
	end)

	if recording then
		ChangeHistoryService:FinishRecording(recording,
			ok and Enum.FinishRecordingOperation.Commit
			or Enum.FinishRecordingOperation.Cancel)
	end

	if ok then
		if existing then
			app:setStatus("updated " .. existing:GetFullName())
		else
			app:setStatus("inserted a " .. kind .. " into " .. app:destinationFor(kind))
		end
		app:emit("doc")
		return true
	end

	app:setStatus("Studio would not let the plugin write that script")
	n.textModal("could not write the script", tostring(err),
		"Studio asks permission before a plugin may read or write script " ..
		"source.\nLook for the prompt, or allow it in Plugins -> Manage " ..
		"Plugins, then try again.")
	return false
end

-- What the button should say and do next, for the window's bottom bar.
function Code:insertLabel()
	local existing = self.app:originInstance()
	if existing then
		return "Update " .. b.truncate(existing.Name, 18),
			"Writes this code back into " .. existing:GetFullName() .. "."
	end
	local kind = self.app:scriptKind()
	return "Insert " .. kind,
		"Creates a new " .. kind .. " in " .. self.app:destinationFor(kind) .. "."
end

--=============================================================================
-- import
--=============================================================================

local KIND_MARK = {
	Script = { letter = "S", token = "data", note = "runs on the server" },
	LocalScript = { letter = "L", token = "text", note = "runs on one player's device" },
	ModuleScript = { letter = "M", token = "funcs", note = "loaded by other scripts" },
}

-- The first script among whatever is selected in the Explorer.
local function selectedScript()
	local chosen, total = nil, 0
	for _, instance in ipairs(Selection:Get()) do
		if instance:IsA("LuaSourceContainer") then
			total = total + 1
			chosen = chosen or instance
		end
	end
	return chosen, total
end

-- Reading Source needs Studio's permission, which is only prompted on a real
-- attempt, so a failure here is expected rather than exceptional.
local function readSource(instance)
	local ok, source = pcall(function() return instance.Source end)
	if ok then return source end
	return nil
end

function n.importView(app, parent)
	local view = { app = app }

	view.frame = b.new("Frame", {
		Name = "Import",
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
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		layout = { dir = "y", gap = 10 },
		Parent = scroll,
	})
	b.new("UISizeConstraint", {
		MaxSize = Vector2.new(760, math.huge), Parent = column })
	b.new("UIPadding", { PaddingBottom = UDim.new(0, 40), Parent = column })

	b.micro("turn a script into blocks", {
		Size = UDim2.new(1, 0, 0, 18),
		fg = "accent",
		LayoutOrder = 1,
		Parent = column,
	})
	b.text({
		Text = "Select a Script, LocalScript or ModuleScript in the Explorer and it " ..
			"shows up here. Converting replaces the canvas, and the code can be " ..
			"written straight back into that same script afterwards.",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		fg = "text2",
		LayoutOrder = 2,
		Parent = column,
	})

	-- the selection card -------------------------------------------------------
	local card = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 74),
		bg = "panel",
		stroke = { color = "line" },
		LayoutOrder = 3,
		Parent = column,
	})
	view.card = card

	local chipHolder = b.new("Frame", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(14, 14),
		Parent = card,
	})
	view.chipHolder = chipHolder

	view.cardName = b.text({
		Text = "Nothing selected",
		Size = UDim2.new(1, -180, 0, 20),
		Position = UDim2.fromOffset(54, 12),
		Font = a.font.uiBold,
		TextSize = 14,
		fg = "text2",
		Parent = card,
	})
	view.cardPath = b.mono({
		Text = "select a script in the Explorer",
		Size = UDim2.new(1, -180, 0, 16),
		Position = UDim2.fromOffset(54, 32),
		TextSize = 11,
		fg = "text3",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	view.cardFacts = b.mono({
		Text = "",
		Size = UDim2.new(1, -70, 0, 14),
		Position = UDim2.fromOffset(54, 50),
		TextSize = 10,
		fg = "text3",
		Parent = card,
	})

	local convert = b.button({
		label = "Convert",
		Size = UDim2.fromOffset(150, 30),
		Position = UDim2.new(1, -164, 0, 22),
		bg = "accent",
		labelColor = "accentInk",
		Parent = card,
	})
	view.convert = convert
	local convertLabel = convert:FindFirstChildWhichIsA("TextLabel")

	view.report = b.text({
		Text = "",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		fg = "text2",
		TextSize = 11,
		LayoutOrder = 4,
		Parent = column,
	})

	--------------------------------------------------------------------------
	local function describe()
		local instance, total = selectedScript()
		view.target = instance

		b.clear(chipHolder)
		if not instance then
			view.cardName.Text = "Nothing selected"
			view.cardName.TextColor3 = a.c.text3
			view.cardPath.Text = "select a script in the Explorer"
			view.cardFacts.Text = ""
			convert:SetAttribute("disabled", true)
			convertLabel.Text = "Convert"
			convertLabel.TextTransparency = 0.55
			local blank = b.chip("?", a.c.text3, 28)
			blank.Parent = chipHolder
			return
		end

		local mark = KIND_MARK[instance.ClassName] or KIND_MARK.Script
		local chip = b.chip(mark.letter, a.c.cats[mark.token], 28)
		chip.Parent = chipHolder

		view.cardName.Text = instance.Name
		view.cardName.TextColor3 = a.c.text
		view.cardPath.Text = instance:GetFullName()

		local source = readSource(instance)
		local facts = instance.ClassName .. " -- " .. mark.note
		if source then
			local lines = 1
			for _ in string.gmatch(source, "\n") do lines = lines + 1 end
			facts = facts .. "   " .. lines .. " lines"
		else
			facts = facts .. "   (Studio will ask permission to read it)"
		end
		if total > 1 then
			facts = facts .. "   " .. total .. " scripts selected, this is the first"
		end
		view.cardFacts.Text = facts

		convert:SetAttribute("disabled", false)
		convertLabel.Text = "Convert " .. b.truncate(instance.Name, 14)
		convertLabel.TextTransparency = 0
	end
	view.describe = describe

	--------------------------------------------------------------------------
	local function convertSource(source, name, instance)
		if not source or string.match(source, "^%s*$") then
			view.report.TextColor3 = a.c.text3
			view.report.Text = "That script is empty."
			return false
		end

		local doc, reportData, err = h.fromCode(source, name)
		if not doc then
			view.report.TextColor3 = a.c.err
			view.report.Text = string.format(
				"Line %d, column %d: %s\n\nThe whole script is read before anything " ..
				"is built, so the canvas is untouched.", err.line, err.col, err.msg)
			app:setStatus("could not read that script -- line " .. err.line)
			return false
		end

		app:setDoc(doc, "convert " .. name)
		app:setOrigin(instance)
		view.report.TextColor3 = a.c.text2

		local lines = {
			string.format("%d statements became %d blocks across %d stacks.",
				reportData.total, d.count(doc), reportData.stacks),
		}
		if instance then
			lines[#lines + 1] = "Insert will write back into " ..
				instance:GetFullName() .. "."
		end
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
		view.report.Text = table.concat(lines, "\n")
		app:setStatus("converted " .. name)
		if app.showTab then app.showTab("build") end
		return true
	end
	view.convertSource = convertSource

	convert.MouseButton1Click:Connect(function()
		local instance = view.target
		if not instance then
			app:setStatus("select a script in the Explorer first")
			return
		end
		local source = readSource(instance)
		if not source then
			view.report.TextColor3 = a.c.err
			view.report.Text = "Studio would not let the plugin read that script. " ..
				"Look for the permission prompt, or allow script access in " ..
				"Plugins -> Manage Plugins, then try again."
			return
		end
		convertSource(source, instance.Name, instance)
	end)

	Selection.SelectionChanged:Connect(describe)
	describe()

	-- pasting, for code that is not in the place yet -----------------------------
	b.spacer(6, 5).Parent = column
	b.rule({ LayoutOrder = 6, parent = column, bg = "lineSoft" })
	b.micro("or paste code", {
		Size = UDim2.new(1, 0, 0, 16),
		fg = "text3",
		LayoutOrder = 7,
		Parent = column,
	})

	local editor = b.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 220),
		bg = "sunken",
		stroke = { color = "line" },
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		LayoutOrder = 8,
		Parent = column,
	})
	view.input = b.new("TextBox", {
		Text = "",
		PlaceholderText = "-- paste Luau here if it is not in the place yet",
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
	b.new("UISizeConstraint", { MinSize = Vector2.new(0, 200), Parent = view.input })

	local pasteRow = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		layout = { dir = "x", gap = 8 },
		LayoutOrder = 9,
		Parent = column,
	})
	local convertPasted = b.button({
		label = "Convert pasted code",
		Size = UDim2.fromOffset(170, 28),
		LayoutOrder = 1,
		Parent = pasteRow,
	})
	view.convertPasted = convertPasted
	convertPasted.MouseButton1Click:Connect(function()
		convertSource(view.input.Text, "Pasted", nil)
	end)

	local sample = b.button({
		label = "Use a sample",
		Size = UDim2.fromOffset(120, 28),
		LayoutOrder = 2,
		Parent = pasteRow,
	})
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

	a.onChange(describe)
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

	-- where each kind of script goes ------------------------------------------
	local places = section(column, 4, "where scripts go")
	b.text({
		Text = "A new script is put where that kind of script belongs. Click to " ..
			"cycle through the sensible alternatives.",
		Size = UDim2.new(1, 0, 0, 28),
		TextWrapped = true,
		TextSize = 11,
		fg = "text3",
		LayoutOrder = 2,
		Parent = places,
	})

	for index, kind in ipairs(o.KINDS) do
		local mark = KIND_MARK[kind]
		local placeRow = row(places, index + 2, kind, mark and mark.note or nil)
		local button = b.button({
			label = app:destinationFor(kind),
			Size = UDim2.fromOffset(240, 22),
			Position = UDim2.new(1, -244, 0, 0),
			Parent = placeRow,
		})
		local label = button:FindFirstChildWhichIsA("TextLabel")
		button.MouseButton1Click:Connect(function()
			local options = o.DESTINATIONS[kind]
			local at = table.find(options, app:destinationFor(kind)) or 0
			local nextPlace = options[(at % #options) + 1]
			app:setDestination(kind, nextPlace)
			label.Text = nextPlace
			app:setStatus(kind .. " goes to " .. nextPlace)
		end)
	end

	-- your own blocks ---------------------------------------------------------
	-- Plugin settings live in one Studio install, so a library that is worth
	-- keeping wants to be a ModuleScript: committed, dragged into a model, or
	-- handed over in a place file.
	local mine = section(column, 5, "your blocks")
	local mineNote = b.text({
		Text = "",
		Size = UDim2.new(1, 0, 0, 30),
		TextWrapped = true,
		TextSize = 11,
		fg = "text3",
		LayoutOrder = 2,
		Parent = mine,
	})

	local mineButtons = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 3,
		layout = { dir = "x", gap = 6 },
		Parent = mine,
	})

	local function paintMine()
		local count = #q.list()
		mineNote.Text = count == 0
			and ("You have not made any blocks yet. The palette has a \"your " ..
				"blocks\" section at the bottom with a New block button, and " ..
				"right-clicking anything on the canvas offers Make into a block.")
			or (count .. (count == 1 and " block" or " blocks") ..
				" of your own. Saving writes them into a ModuleScript you can " ..
				"commit or share; loading reads one back.")
	end
	app:on("customs", paintMine)
	app:on("doc", paintMine)
	paintMine()

	local newBlock = b.button({
		label = "New block",
		Size = UDim2.fromOffset(104, 26),
		LayoutOrder = 1,
		Parent = mineButtons,
	})
	newBlock.MouseButton1Click:Connect(function()
		if app.openBlockEditor then app.openBlockEditor(nil) end
	end)

	local saveLibrary = b.button({
		label = "Save to a ModuleScript",
		Size = UDim2.fromOffset(172, 26),
		LayoutOrder = 2,
		Parent = mineButtons,
	})
	b.tip(saveLibrary, "Writes every block you have made into one ModuleScript.")
	saveLibrary.MouseButton1Click:Connect(function()
		local list = q.list()
		if #list == 0 then
			app:setStatus("no blocks of your own to save yet")
			return
		end
		local source = q.toModuleSource(list, app.doc.name)
		local recording = ChangeHistoryService:TryBeginRecording("ABlocks block library")
		local ok, err = pcall(function()
			local parentPath = app:destinationFor("ModuleScript")
			local parent = o.resolvePath(parentPath)
			if not parent then error("could not find " .. parentPath, 0) end
			local made = Instance.new("ModuleScript")
			made.Name = "ABlocksBlocks"
			made.Source = source
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
			app:setStatus(string.format("saved %d blocks into ABlocksBlocks in %s",
				#list, app:destinationFor("ModuleScript")))
		else
			n.textModal("could not save the library", tostring(err),
				"Studio asks permission before a plugin may write script source.")
		end
	end)

	local loadLibrary = b.button({
		label = "Load from a ModuleScript",
		Size = UDim2.fromOffset(186, 26),
		LayoutOrder = 3,
		Parent = mineButtons,
	})
	b.tip(loadLibrary, "Select a saved library in the Explorer first.\n" ..
		"Loaded blocks are added, never overwritten.")
	loadLibrary.MouseButton1Click:Connect(function()
		local instance = Selection:Get()[1]
		if not instance or not instance:IsA("ModuleScript") then
			app:setStatus("select the ModuleScript in the Explorer first")
			return
		end
		local source, readErr = readSource(instance)
		if not source then
			app:setStatus(readErr or "could not read that script")
			return
		end
		local made, err = q.fromModuleSource(source)
		if not made then
			-- Not a saved library, then. A module of ordinary functions is
			-- still useful: offer one block for each function it exports.
			if app.makeBlocksFromModule and app.makeBlocksFromModule(instance) then
				return
			end
			app:setStatus(tostring(err))
			return
		end
		local added = 0
		for _, custom in ipairs(made) do
			if app:putCustom(custom) then added += 1 end
		end
		app:setStatus(string.format("added %d blocks from %s", added, instance.Name))
	end)

	-- shortcuts ---------------------------------------------------------------------
	local keys = section(column, 6, "keyboard")
	local list = {
		{ "Ctrl+Z / Ctrl+Y", "undo, redo" },
		{ "Delete", "remove the selected block and what follows it" },
		{ "Ctrl+D", "duplicate the selection" },
		{ "Ctrl+F", "search the palette" },
		{ "Ctrl+S", "save the project" },
		{ "Ctrl+Enter", "write the script into the game" },
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
