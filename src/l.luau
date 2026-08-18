--!nonstrict
-- l  ·  the palette
--
-- The list of blocks on the left.  Categories behave as an accordion -- one
-- open at a time -- and the search box collapses the whole thing into one
-- ranked list.  Search matches the wording on the block, the Luau it writes and
-- its description, so `connect` finds the event blocks even though none of them
-- say "connect" on the front.
--
-- A row can be clicked (drops the block on the canvas near your selection) or
-- dragged straight onto the canvas.

local a = require(script.Parent.a)
local b = require(script.Parent.b)
local c = require(script.Parent.c)
local i = require(script.Parent.i)

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local l = {}

local View = {}
View.__index = View

--=============================================================================
-- search
--=============================================================================

local function rank(query, def)
	local best = i.score(query, def.label)
	local byId = i.score(query, def.id)
	if byId and (not best or byId > best) then best = byId end
	if string.find(def.searchText, query, 1, true) then
		best = math.max(best or 0, 24)
	end
	-- the first word of the label matching is worth more than a scattered hit
	local firstWord = string.match(def.label, "^%S+")
	if firstWord and string.sub(string.lower(firstWord), 1, #query) == query then
		best = (best or 0) + 30
	end
	return best
end

function l.search(query)
	query = string.lower(string.match(query or "", "^%s*(.-)%s*$"))
	if query == "" then return nil end
	local hits = {}
	for _, def in ipairs(c.order) do
		local score = rank(query, def)
		if score then hits[#hits + 1] = { def = def, score = score } end
	end
	table.sort(hits, function(x, y)
		if x.score ~= y.score then return x.score > y.score end
		return x.def.label < y.def.label
	end)
	local out = {}
	for _, hit in ipairs(hits) do out[#out + 1] = hit.def end
	return out
end

--=============================================================================
-- rows
--=============================================================================

-- The Luau a block writes, with its defaults filled in -- shown in the tooltip
-- so you can see what you are about to add.
local function sampleCode(def)
	local lines = {}
	for _, template in ipairs(def.codeLines) do
		lines[#lines + 1] = (string.gsub(
			c.fill(c.parseTemplate(template), def, { f = {} }), "^\t", ""))
	end
	if #def.slots > 0 then lines[#lines + 1] = "\t..." end
	for _, template in ipairs(def.codeTailLines or {}) do
		lines[#lines + 1] = (string.gsub(
			c.fill(c.parseTemplate(template), def, { f = {} }), "^\t", ""))
	end
	return table.concat(lines, "\n")
end

function View:blockRow(def, order)
	local row = b.new("TextButton", {
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = order,
		bg = "panel",
	})

	b.new("Frame", {
		Size = UDim2.fromOffset(2, 16),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = a.catColor(def.cat),
		BackgroundTransparency = 0,
		Parent = row,
	})

	b.mono({
		Text = def.label,
		Size = UDim2.new(1, -34, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextSize = 12,
		fg = "text",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local plus = b.mono({
		Text = "+",
		Size = UDim2.fromOffset(16, 24),
		Position = UDim2.new(1, -20, 0, 0),
		TextSize = 14,
		fg = "text3",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Parent = row,
	})

	b.hover(row, function()
		row.BackgroundColor3 = a.c.raised
		plus.TextTransparency = 0
	end, function()
		row.BackgroundColor3 = a.c.panel
		plus.TextTransparency = 1
	end)

	b.tip(row, function()
		return def.doc .. "\n\n" .. sampleCode(def)
	end)

	-- click to place, drag to carry
	row.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		local canvas = self.app.canvas
		if not canvas then return end
		local gui = self.frame:FindFirstAncestorWhichIsA("PluginGui")
		if not gui then return end

		local start = gui:GetRelativeMousePosition()
		task.spawn(function()
			local carried = false
			while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
				local now = gui:GetRelativeMousePosition()
				if not carried and (now - start).Magnitude > 6 then
					carried = true
					b.hideTip()
					canvas:spawnAndDrag(def.id, now)
					return
				end
				RunService.Heartbeat:Wait()
			end
			if not carried then
				canvas:addBlock(def.id)
				self.app:setStatus("added " .. def.label)
			end
		end)
	end)

	return row
end

function View:categoryHeader(cat, order, open)
	local header = b.new("TextButton", {
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = order,
		bg = "panel",
	})

	local chip = b.chip(cat.glyph, a.catColor(cat.id), 14)
	chip.Position = UDim2.fromOffset(0, 7)
	chip.Parent = header

	b.text({
		Text = cat.name,
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(22, 0),
		Font = open and a.font.uiBold or a.font.uiMedium,
		fg = open and "text" or "text2",
		Parent = header,
	})

	b.mono({
		Text = tostring(#c.byCat(cat.id)),
		Size = UDim2.fromOffset(24, 28),
		Position = UDim2.new(1, -40, 0, 0),
		TextSize = 10,
		fg = "text3",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})

	local chevron = b.chevron(8, open and "accent" or "text3")
	chevron.Position = UDim2.new(1, -14, 0, 12)
	chevron.Rotation = open and 0 or -90
	chevron.Parent = header

	b.hover(header, function() header.BackgroundColor3 = a.c.raised end,
		function() header.BackgroundColor3 = a.c.panel end)

	header.MouseButton1Click:Connect(function()
		self.openCat = (self.openCat == cat.id) and nil or cat.id
		self:refresh()
	end)

	b.tip(header, cat.blurb)
	return header
end

--=============================================================================
-- assembly
--=============================================================================

function l.mount(app, parent)
	local view = setmetatable({ app = app, openCat = "events", query = "" }, View)

	view.frame = b.new("Frame", {
		Name = "Palette",
		Size = UDim2.new(0, 236, 1, 0),
		bg = "panel",
		Parent = parent,
	})
	app.paletteFrame = view.frame

	b.rule({ Position = UDim2.new(1, -1, 0, 0), parent = view.frame })

	-- search ------------------------------------------------------------------
	local searchRow = b.new("Frame", {
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 10),
		bg = "field",
		stroke = { color = "fieldLine" },
		radius = a.metric.radius,
		Parent = view.frame,
	})

	b.mono({
		Text = "/",
		Size = UDim2.fromOffset(16, 26),
		Position = UDim2.fromOffset(8, 0),
		fg = "text3",
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = searchRow,
	})

	view.search = b.new("TextBox", {
		Text = "",
		PlaceholderText = "search " .. c.count() .. " blocks",
		ClearTextOnFocus = false,
		Size = UDim2.new(1, -34, 1, 0),
		Position = UDim2.fromOffset(26, 0),
		Font = a.font.mono,
		TextSize = 12,
		fg = "text",
		ph = "text3",
		Parent = searchRow,
	})
	view.search:GetPropertyChangedSignal("Text"):Connect(function()
		view.query = view.search.Text
		view:refresh()
	end)

	-- list --------------------------------------------------------------------
	view.scroll = b.new("ScrollingFrame", {
		Size = UDim2.new(1, -6, 1, -46),
		Position = UDim2.fromOffset(0, 44),
		Parent = view.frame,
	})
	view.layout = b.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
		Parent = view.scroll,
	})
	b.new("UIPadding", {
		PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12), Parent = view.scroll })
	b.autoCanvas(view.scroll, view.layout, 16)

	-- dropping a block back onto the palette throws it away
	app:on("dragOverPalette", function(over)
		view.frame.BackgroundColor3 = over and a.c.err:Lerp(a.c.panel, 0.75) or a.c.panel
		if over then
			app:setStatus("release to delete")
		end
	end)

	a.onChange(function() view:refresh() end)
	view:refresh()
	return view
end

function View:focusSearch()
	self.search:CaptureFocus()
end

function View:refresh()
	b.clear(self.scroll)
	local order = 1

	local hits = l.search(self.query)
	if hits then
		b.micro(#hits .. " matching", {
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = order,
			Parent = self.scroll,
		})
		order = order + 1
		for _, def in ipairs(hits) do
			self:blockRow(def, order).Parent = self.scroll
			order = order + 1
		end
		if #hits == 0 then
			b.text({
				Text = "Nothing matches. Try a word from the Luau you want,\nsuch as 'clone' or 'wait'.",
				Size = UDim2.new(1, 0, 0, 44),
				TextWrapped = true,
				fg = "text3",
				LayoutOrder = order,
				Parent = self.scroll,
			})
		end
		return
	end

	for _, cat in ipairs(c.cats) do
		local open = self.openCat == cat.id
		self:categoryHeader(cat, order, open).Parent = self.scroll
		order = order + 1

		if open then
			b.rule({ LayoutOrder = order, parent = self.scroll, bg = "lineSoft" })
			order = order + 1
			b.text({
				Text = cat.blurb,
				Size = UDim2.new(1, 0, 0, 30),
				TextWrapped = true,
				TextSize = 11,
				fg = "text3",
				LayoutOrder = order,
				Parent = self.scroll,
			})
			order = order + 1
			for _, def in ipairs(c.byCat(cat.id)) do
				self:blockRow(def, order).Parent = self.scroll
				order = order + 1
			end
			b.spacer(10, order).Parent = self.scroll
			order = order + 1
		end
	end
end

return l
