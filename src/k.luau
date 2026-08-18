--!nonstrict
-- k  ·  the tutorials tab
--
-- A contents list on the left, the lesson on the right.  Two things make this
-- more than a help file: the block names in a lesson are live -- click one and
-- it lands on your canvas -- and lessons that carry an example can rebuild that
-- example as blocks, through the same importer the Import tab uses.

local a = require(script.Parent.a)
local b = require(script.Parent.b)
local c = require(script.Parent.c)
local d = require(script.Parent.d)
local h = require(script.Parent.h)
local j = require(script.Parent.j)
local n = require(script.Parent.n)

local k = {}

local LEVELS = {
	start = { label = "first steps", token = "ok" },
	build = { label = "building", token = "accent" },
	deep = { label = "going deeper", token = "cats.vars" },
}

local View = {}
View.__index = View

--=============================================================================
-- inline formatting: `code` spans become accent-coloured
--=============================================================================

local function escape(text)
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	return text
end

local function hex(colour)
	return string.format("#%02X%02X%02X",
		math.floor(colour.R * 255 + 0.5),
		math.floor(colour.G * 255 + 0.5),
		math.floor(colour.B * 255 + 0.5))
end

local function inline(text)
	local out = escape(text)
	out = string.gsub(out, "`([^`]+)`", function(code)
		return string.format('<font color="%s">%s</font>', hex(a.c.accent), code)
	end)
	return out
end

--=============================================================================
-- step renderers
--=============================================================================

function View:paragraph(text, order, parent)
	return b.text({
		Text = inline(text),
		RichText = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 13,
		LineHeight = 1.35,
		fg = "text2",
		LayoutOrder = order,
		Parent = parent,
	})
end

function View:heading(text, order, parent)
	local frame = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		Parent = parent,
	})
	b.text({
		Text = text,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 8),
		Font = a.font.uiBold,
		TextSize = 13,
		fg = "text",
		Parent = frame,
	})
	return frame
end

function View:codeBlock(code, order, parent)
	local frame = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		bg = "sunken",
		stroke = { color = "lineSoft" },
		radius = a.metric.radius,
		LayoutOrder = order,
		layout = { dir = "y", gap = 0 },
		Parent = parent,
	})
	b.new("UIPadding", {
		PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
		Parent = frame,
	})
	for index, line in ipairs(n.highlight(code)) do
		b.mono({
			Text = line == "" and " " or line,
			RichText = true,
			Size = UDim2.new(1, 0, 0, 17),
			TextSize = 12,
			LayoutOrder = index,
			Parent = frame,
		})
	end
	return frame
end

function View:calloutBlock(text, order, parent, token, label)
	local frame = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	b.new("Frame", {
		Size = UDim2.new(0, 2, 1, 0),
		bg = token,
		Parent = frame,
	})
	local column = b.new("Frame", {
		Size = UDim2.new(1, -18, 0, 0),
		Position = UDim2.fromOffset(14, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		layout = { dir = "y", gap = 3 },
		Parent = frame,
	})
	b.micro(label, {
		Size = UDim2.new(1, 0, 0, 14),
		fg = token,
		LayoutOrder = 1,
		Parent = column,
	})
	b.text({
		Text = inline(text),
		RichText = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 12,
		LineHeight = 1.3,
		fg = "text2",
		LayoutOrder = 2,
		Parent = column,
	})
	return frame
end

function View:numbered(lines, order, parent)
	local frame = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		layout = { dir = "y", gap = 6 },
		Parent = parent,
	})
	for index, line in ipairs(lines) do
		local row = b.new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = frame,
		})
		b.mono({
			Text = string.format("%02d", index),
			Size = UDim2.fromOffset(24, 18),
			TextSize = 11,
			fg = "text3",
			Parent = row,
		})
		b.text({
			Text = inline(line),
			RichText = true,
			Size = UDim2.new(1, -30, 0, 0),
			Position = UDim2.fromOffset(30, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextSize = 13,
			LineHeight = 1.3,
			fg = "text2",
			Parent = row,
		})
	end
	return frame
end

-- The blocks a lesson mentions, as chips you can click to place.
function View:blockChips(spec, order, parent)
	local frame = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	local grid = b.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 24),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})

	local index = 0
	for id in string.gmatch(spec, "[^,]+") do
		local def = c.get(id)
		if def then
			index = index + 1
			local chip = b.new("TextButton", {
				Size = UDim2.fromOffset(150, 24),
				LayoutOrder = index,
				bg = "raised",
				radius = a.metric.radius,
				Parent = frame,
			})
			b.new("Frame", {
				Size = UDim2.fromOffset(2, 16),
				Position = UDim2.fromOffset(6, 4),
				BackgroundColor3 = a.catColor(def.cat),
				BackgroundTransparency = 0,
				Parent = chip,
			})
			b.mono({
				Text = def.label,
				Size = UDim2.new(1, -20, 1, 0),
				Position = UDim2.fromOffset(14, 0),
				TextSize = 11,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = chip,
			})
			b.states(chip, "raised", 0.2)
			b.tip(chip, def.doc .. "\n\nClick to put this block on the canvas.")
			chip.MouseButton1Click:Connect(function()
				if self.app.canvas then self.app.canvas:addBlock(def.id) end
				if self.app.showTab then self.app.showTab("build") end
				self.app:setStatus("added " .. def.label)
			end)
		end
	end

	frame.Size = UDim2.new(1, 0, 0, math.ceil(index / 3) * 30)
	return frame
end

--=============================================================================
-- the lesson pane
--=============================================================================

function View:showTutorial(entry)
	self.current = entry
	b.clear(self.reader)
	self.readerScroll.CanvasPosition = Vector2.new(0, 0)

	local order = 1
	local function step() order = order + 1 return order - 1 end

	-- header ------------------------------------------------------------------
	local header = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = step(),
		layout = { dir = "y", gap = 8 },
		Parent = self.reader,
	})

	local meta = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
		layout = { dir = "x", gap = 10, align = "middle" },
		Parent = header,
	})
	b.mono({
		Text = string.format("%02d", entry.index),
		Size = UDim2.fromOffset(22, 16),
		TextSize = 11,
		fg = "accent",
		LayoutOrder = 1,
		Parent = meta,
	})
	local level = LEVELS[entry.level] or LEVELS.start
	b.micro(level.label, {
		Size = UDim2.fromOffset(80, 16),
		fg = level.token,
		LayoutOrder = 2,
		Parent = meta,
	})
	b.micro(entry.minutes .. " min read", {
		Size = UDim2.fromOffset(90, 16),
		fg = "text3",
		LayoutOrder = 3,
		Parent = meta,
	})
	if entry.cat then
		local cat = c.catById[entry.cat]
		if cat then
			b.micro(cat.name .. " blocks", {
				Size = UDim2.fromOffset(140, 16),
				fg = function(theme) return theme.cats[cat.id] end,
				LayoutOrder = 4,
				Parent = meta,
			})
		end
	end

	b.text({
		Text = entry.title,
		Size = UDim2.new(1, 0, 0, 30),
		Font = a.font.uiBold,
		TextSize = 20,
		fg = "text",
		LayoutOrder = 2,
		Parent = header,
	})
	b.text({
		Text = entry.blurb,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 14,
		LineHeight = 1.3,
		fg = "text3",
		LayoutOrder = 3,
		Parent = header,
	})
	b.rule({ LayoutOrder = 4, parent = header, bg = "line" })

	-- body ---------------------------------------------------------------------
	for _, entryStep in ipairs(entry.steps) do
		if entryStep.h then
			self:heading(entryStep.h, step(), self.reader)
		elseif entryStep.p then
			self:paragraph(entryStep.p, step(), self.reader)
		elseif entryStep.code then
			self:codeBlock(entryStep.code, step(), self.reader)
		elseif entryStep.blocks then
			self:blockChips(entryStep.blocks, step(), self.reader)
		elseif entryStep.note then
			self:calloutBlock(entryStep.note, step(), self.reader, "accent", "worth knowing")
		elseif entryStep.warn then
			self:calloutBlock(entryStep.warn, step(), self.reader, "err", "watch out")
		elseif entryStep.list then
			self:numbered(entryStep.list, step(), self.reader)
		elseif entryStep.try then
			self:calloutBlock(entryStep.try, step(), self.reader, "ok", "try it")
		end
	end

	-- footer --------------------------------------------------------------------
	b.spacer(10, step()).Parent = self.reader
	b.rule({ LayoutOrder = step(), parent = self.reader, bg = "lineSoft" })

	local footer = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = step(),
		layout = { dir = "x", gap = 8 },
		Parent = self.reader,
	})

	if entry.example then
		local load = b.button({
			label = "Build this example",
			Size = UDim2.fromOffset(150, 28),
			bg = "accent",
			labelColor = "accentInk",
			LayoutOrder = 1,
			Parent = footer,
		})
		b.tip(load, "Replaces the canvas with this lesson's example.\nCtrl+Z brings your own work back.")
		load.MouseButton1Click:Connect(function()
			local doc, report, err = h.fromCode(entry.example, entry.title)
			if not doc then
				self.app:setStatus("that example did not convert: " .. err.msg)
				return
			end
			self.app:setDoc(doc, "load example")
			if self.app.showTab then self.app.showTab("build") end
			self.app:setStatus("built " .. d.count(doc) .. " blocks from " .. entry.title)
		end)
	end

	local previous = j.tutorials[entry.index - 1]
	local following = j.tutorials[entry.index + 1]

	if previous then
		local button = b.button({
			label = "< " .. b.truncate(previous.title, 22),
			Size = UDim2.fromOffset(170, 28),
			LayoutOrder = 2,
			Parent = footer,
		})
		button.MouseButton1Click:Connect(function() self:open(previous) end)
	end
	if following then
		local button = b.button({
			label = b.truncate(following.title, 22) .. " >",
			Size = UDim2.fromOffset(170, 28),
			LayoutOrder = 3,
			Parent = footer,
		})
		button.MouseButton1Click:Connect(function() self:open(following) end)
	end

	b.spacer(30, step()).Parent = self.reader
end

function View:open(entry)
	local read = self.app.settings.read
	if type(read) ~= "table" then read = {} end
	read[entry.id] = true
	self.app:setSetting("read", read)
	self:showTutorial(entry)
	self:refreshList()
end

--=============================================================================
-- contents list
--=============================================================================

function View:listRow(entry, order)
	local read = type(self.app.settings.read) == "table" and self.app.settings.read or {}
	local isCurrent = self.current and self.current.id == entry.id

	local row = b.new("TextButton", {
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = order,
		bg = isCurrent and "raised" or "panel",
		Parent = self.list,
	})

	b.mono({
		Text = string.format("%02d", entry.index),
		Size = UDim2.fromOffset(24, 18),
		Position = UDim2.fromOffset(8, 5),
		TextSize = 10,
		fg = isCurrent and "accent" or "text3",
		Parent = row,
	})

	b.text({
		Text = entry.title,
		Size = UDim2.new(1, -50, 0, 18),
		Position = UDim2.fromOffset(34, 4),
		TextSize = 12,
		Font = isCurrent and a.font.uiBold or a.font.ui,
		fg = isCurrent and "text" or "text2",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	b.text({
		Text = b.truncate(entry.blurb, 46),
		Size = UDim2.new(1, -50, 0, 14),
		Position = UDim2.fromOffset(34, 20),
		TextSize = 10,
		fg = "text3",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	if read[entry.id] then
		b.new("Frame", {
			Size = UDim2.fromOffset(4, 4),
			Position = UDim2.new(1, -14, 0, 8),
			bg = "ok",
			radius = 2,
			Parent = row,
		})
	end

	local level = LEVELS[entry.level] or LEVELS.start
	b.new("Frame", {
		Size = UDim2.fromOffset(2, 40),
		bg = isCurrent and "accent" or (entry.kind == "category" and level.token or "lineSoft"),
		BackgroundTransparency = isCurrent and 0 or 0.4,
		Parent = row,
	})

	b.hover(row, function()
		if not isCurrent then row.BackgroundColor3 = a.c.raised end
	end, function()
		if not isCurrent then row.BackgroundColor3 = a.c.panel end
	end)
	row.MouseButton1Click:Connect(function() self:open(entry) end)
	return row
end

function View:refreshList()
	b.clear(self.list)
	local entries = j.search(self.query or "")
	local order = 1
	local shown = 0

	local function heading(text)
		b.micro(text, {
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = order,
			fg = "text3",
			Parent = self.list,
		})
		order = order + 1
	end

	local wantCategories = self.filter ~= "tips"
	local wantTips = self.filter ~= "categories"

	local categories, tips = {}, {}
	for _, entry in ipairs(entries) do
		if entry.kind == "category" then
			categories[#categories + 1] = entry
		else
			tips[#tips + 1] = entry
		end
	end

	if wantCategories and #categories > 0 then
		heading("one per block category")
		for _, entry in ipairs(categories) do
			self:listRow(entry, order)
			order = order + 1
			shown = shown + 1
		end
	end
	if wantTips and #tips > 0 then
		b.spacer(10, order).Parent = self.list
		order = order + 1
		heading("tips and technique")
		for _, entry in ipairs(tips) do
			self:listRow(entry, order)
			order = order + 1
			shown = shown + 1
		end
	end

	if shown == 0 then
		b.text({
			Text = "No lesson mentions that.",
			Size = UDim2.new(1, 0, 0, 40),
			fg = "text3",
			LayoutOrder = order,
			Parent = self.list,
		})
	end

	local read = type(self.app.settings.read) == "table" and self.app.settings.read or {}
	local done = 0
	for _, entry in ipairs(j.tutorials) do
		if read[entry.id] then done = done + 1 end
	end
	self.progress.Text = done .. " of " .. j.count() .. " read"
end

--=============================================================================
-- assembly
--=============================================================================

function k.mount(app, parent)
	local view = setmetatable({ app = app, query = "", filter = "all" }, View)

	view.frame = b.new("Frame", {
		Name = "Tutorials",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		bg = "bg",
		Parent = parent,
	})

	-- contents -----------------------------------------------------------------
	local side = b.new("Frame", {
		Size = UDim2.new(0, 300, 1, 0),
		bg = "panel",
		Parent = view.frame,
	})
	b.rule({ Position = UDim2.new(1, -1, 0, 0), parent = side })

	local searchRow = b.new("Frame", {
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 12),
		bg = "field",
		stroke = { color = "fieldLine" },
		radius = a.metric.radius,
		Parent = side,
	})
	local search = b.new("TextBox", {
		Text = "",
		PlaceholderText = "search " .. j.count() .. " lessons",
		ClearTextOnFocus = false,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Font = a.font.mono,
		TextSize = 12,
		fg = "text",
		ph = "text3",
		Parent = searchRow,
	})
	search:GetPropertyChangedSignal("Text"):Connect(function()
		view.query = search.Text
		view:refreshList()
	end)

	local filters = b.new("Frame", {
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 46),
		layout = { dir = "x", gap = 6 },
		Parent = side,
	})
	for index, option in ipairs({ { "all", "all" }, { "categories", "blocks" },
		{ "tips", "technique" } }) do
		local button = b.button({
			label = option[2],
			Size = UDim2.fromOffset(80, 20),
			LayoutOrder = index,
			bg = view.filter == option[1] and "accentSoft" or "raised",
			Parent = filters,
		})
		button.MouseButton1Click:Connect(function()
			view.filter = option[1]
			for _, other in ipairs(filters:GetChildren()) do
				if other:IsA("TextButton") then
					local isChosen = other == button
					b.states(other, isChosen and "accentSoft" or "raised")
				end
			end
			view:refreshList()
		end)
	end

	view.progress = b.mono({
		Text = "",
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(12, 72),
		TextSize = 10,
		fg = "text3",
		Parent = side,
	})

	local listScroll = b.new("ScrollingFrame", {
		Size = UDim2.new(1, -6, 1, -96),
		Position = UDim2.fromOffset(0, 94),
		Parent = side,
	})
	view.list = listScroll
	local listLayout = b.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 1),
		Parent = listScroll,
	})
	b.new("UIPadding", {
		PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 20), Parent = listScroll })
	b.autoCanvas(listScroll, listLayout, 24)

	-- reader --------------------------------------------------------------------
	view.readerScroll = b.new("ScrollingFrame", {
		Size = UDim2.new(1, -300, 1, 0),
		Position = UDim2.fromOffset(300, 0),
		bg = "bg",
		Parent = view.frame,
	})
	view.reader = b.new("Frame", {
		Size = UDim2.new(1, -80, 0, 0),
		Position = UDim2.fromOffset(40, 24),
		AutomaticSize = Enum.AutomaticSize.Y,
		layout = { dir = "y", gap = 12 },
		Parent = view.readerScroll,
	})
	b.new("UISizeConstraint", {
		MaxSize = Vector2.new(720, math.huge), Parent = view.reader })
	local readerLayout = view.reader:FindFirstChildWhichIsA("UIListLayout")
	readerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		view.readerScroll.CanvasSize =
			UDim2.new(0, 0, 0, readerLayout.AbsoluteContentSize.Y + 80)
	end)

	a.onChange(function()
		view:refreshList()
		if view.current then view:showTutorial(view.current) end
	end)

	-- opening the tab is not the same as reading a lesson, so this one does not
	-- count towards progress until it is chosen from the list
	view:showTutorial(j.tutorials[1])
	view:refreshList()
	return view
end

return k
