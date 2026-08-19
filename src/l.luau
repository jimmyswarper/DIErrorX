--!nonstrict
-- l  ·  the palette
--
-- Seven hundred blocks need more than one long list, so this has four things
-- the old palette did not: subgroups inside each category, a strip of recent
-- and starred blocks at the top, search results grouped by category, and a
-- filter that hides server-only blocks while you are building a LocalScript.
--
-- A row can be clicked (drops the block on the canvas near your selection) or
-- dragged straight onto it.  Your own blocks live in their own category, with
-- the group names you gave them.

local a = require(script.Parent.a)
local b = require(script.Parent.b)
local c = require(script.Parent.c)
local i = require(script.Parent.i)
local q = require(script.Parent.q)

local RunService = game:GetService("RunService")

local l = {}

local RECENT_LIMIT = 6

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
	local firstWord = string.match(def.label, "^%S+")
	if firstWord and string.sub(string.lower(firstWord), 1, #query) == query then
		best = (best or 0) + 30
	end
	return best
end

function l.search(query, allowed)
	query = string.lower(string.match(query or "", "^%s*(.-)%s*$"))
	if query == "" then return nil end
	local hits = {}
	for _, def in ipairs(c.order) do
		if not allowed or allowed(def) then
			local score = rank(query, def)
			if score then hits[#hits + 1] = { def = def, score = score } end
		end
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
-- what belongs in this project
--=============================================================================

function View:allows(def)
	if not self.app.settings.filterBySide then return true end
	if not def.side then return true end
	local kind = self.app:scriptKind()
	if kind == "LocalScript" then return def.side ~= "server" end
	if kind == "Script" then return def.side ~= "client" end
	return true
end

--=============================================================================
-- rows
--=============================================================================

-- A palette entry is a small version of the block it places, notch and all, so
-- that what you pick up looks like what you dropped.
function View:blockRow(def, order)
	local row = b.new("TextButton", {
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		bg = "panel",
	})

	local paint = function() return a.blockColor(def.cat) end
	local chip = b.new("Frame", {
		Size = UDim2.new(1, -52, 0, 24),
		Position = UDim2.fromOffset(4, 3),
		bg = paint,
		radius = 5,
		Parent = row,
	})
	-- the notch, filled with the palette behind it, so it reads as a cut
	b.new("Frame", {
		Size = UDim2.fromOffset(14, 3),
		Position = UDim2.fromOffset(9, 0),
		bg = "panel",
		radius = 1,
		Parent = chip,
	})
	-- and the tab underneath, half out of the bottom edge
	b.new("Frame", {
		Size = UDim2.fromOffset(14, 3),
		Position = UDim2.fromOffset(9, 24),
		bg = paint,
		radius = 1,
		Parent = row,
	})

	b.text({
		Text = def.label,
		Size = UDim2.new(1, -22, 1, -4),
		Position = UDim2.fromOffset(10, 3),
		Font = a.font.uiMedium,
		TextSize = 12,
		fg = function() return a.inkOn(a.blockColor(def.cat)) end,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = chip,
	})

	-- starring keeps a block at the top of the palette
	local favourites = self.app.settings.favourites or {}
	local star = b.new("TextButton", {
		Size = UDim2.fromOffset(18, 30),
		Position = UDim2.new(1, -40, 0, 0),
		bg = "panel",
		BackgroundTransparency = 1,
		Parent = row,
	})
	local starMark = b.mono({
		Text = "+",
		Size = UDim2.fromScale(1, 1),
		TextSize = 13,
		fg = favourites[def.id] and "accent" or "text3",
		TextTransparency = favourites[def.id] and 0 or 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = star,
	})
	b.tip(star, favourites[def.id] and "Remove from your starred blocks."
		or "Keep this block at the top of the palette.")
	star.MouseButton1Click:Connect(function()
		self:toggleFavourite(def.id)
	end)

	local plus = b.mono({
		Text = ">",
		Size = UDim2.fromOffset(16, 30),
		Position = UDim2.new(1, -18, 0, 0),
		TextSize = 12,
		fg = "text3",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Parent = row,
	})

	b.hover(row, function()
		row.BackgroundColor3 = a.c.raised
		plus.TextTransparency = 0
		if not favourites[def.id] then starMark.TextTransparency = 0.45 end
	end, function()
		row.BackgroundColor3 = a.c.panel
		plus.TextTransparency = 1
		if not favourites[def.id] then starMark.TextTransparency = 1 end
	end)

	b.tip(row, function()
		local parts = { def.doc }
		if def.side then
			parts[#parts + 1] = "\nOnly works on the " .. def.side .. "."
		end
		parts[#parts + 1] = "\n" .. def.sample
		return table.concat(parts, "")
	end)

	-- click to place, drag to carry
	row.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		local canvas = self.app.canvas
		if not canvas then return end
		local gui = self.frame:FindFirstAncestorWhichIsA("PluginGui")
		if not gui then return end

		local start = gui:GetRelativeMousePosition()
		b.noteDown(input.UserInputType)
		task.spawn(function()
			local carried = false
			while b.pressing(input, Enum.UserInputType.MouseButton1) do
				local now = gui:GetRelativeMousePosition()
				if not carried and (now - start).Magnitude > 6 then
					carried = true
					b.hideTip()
					self:remember(def.id)
					canvas:spawnAndDrag(def.id, now, input)
					return
				end
				RunService.Heartbeat:Wait()
			end
			if not carried then
				self:remember(def.id)
				canvas:addBlock(def.id)
				self.app:setStatus("added " .. def.label)
			end
		end)
	end)

	return row
end

function View:heading(text, order, token)
	return b.micro(text, {
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = order,
		fg = token or "text3",
		Parent = self.scroll,
	})
end

function View:categoryHeader(cat, order, open, count)
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
		Text = tostring(count),
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
-- state
--=============================================================================

function View:toggleFavourite(defId)
	local favourites = {}
	for key, value in pairs(self.app.settings.favourites or {}) do
		favourites[key] = value
	end
	favourites[defId] = (not favourites[defId]) or nil
	self.app:setSetting("favourites", favourites)
	self:refresh()
end

function View:remember(defId)
	local recents = {}
	for _, id in ipairs(self.app.settings.recents or {}) do
		if id ~= defId then recents[#recents + 1] = id end
	end
	table.insert(recents, 1, defId)
	while #recents > RECENT_LIMIT do
		recents[#recents] = nil
	end
	self.app:setSetting("recents", recents)
	self:refresh()
end

function View:focusSearch()
	self.search:CaptureFocus()
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
	view.search.FocusLost:Connect(function(enterPressed)
		if not enterPressed or not view.topHit then return end
		if app.canvas then
			view:remember(view.topHit.id)
			app.canvas:addBlock(view.topHit.id)
			app:setStatus("added " .. view.topHit.label)
		end
	end)

	-- the side filter ------------------------------------------------------------
	local filterRow = b.new("Frame", {
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 42),
		Parent = view.frame,
	})
	view.filterLabel = b.mono({
		Text = "",
		Size = UDim2.new(1, -60, 1, 0),
		TextSize = 10,
		fg = "text3",
		Parent = filterRow,
	})
	local filterButton = b.button({
		label = "all",
		Size = UDim2.fromOffset(54, 18),
		Position = UDim2.new(1, -54, 0, 1),
		Parent = filterRow,
	})
	local filterText = filterButton:FindFirstChildWhichIsA("TextLabel")
	b.tip(filterButton, "Show every block, or only the ones that work in the\n" ..
		"kind of script this project is heading for.")
	filterButton.MouseButton1Click:Connect(function()
		app:setSetting("filterBySide", not app.settings.filterBySide)
		filterText.Text = app.settings.filterBySide and "fits" or "all"
		view:refresh()
	end)
	filterText.Text = app.settings.filterBySide and "fits" or "all"

	-- list --------------------------------------------------------------------
	view.scroll = b.new("ScrollingFrame", {
		Size = UDim2.new(1, -6, 1, -70),
		Position = UDim2.fromOffset(0, 68),
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
		if over then app:setStatus("release to delete") end
	end)

	app:on("customs", function() view:refresh() end)
	app:on("doc", function() view:refreshIfKindChanged() end)
	a.onChange(function() view:refresh() end)
	view:refresh()
	return view
end

-- The side filter depends on the script kind, so the palette follows it.
function View:refreshIfKindChanged()
	local kind = self.app:scriptKind()
	if kind ~= self.lastKind then
		self.lastKind = kind
		self:refresh()
	end
end

--=============================================================================
-- drawing
--=============================================================================

function View:refresh()
	b.clear(self.scroll)
	local order = 0
	local function next_() order = order + 1 return order end

	local allowed = function(def) return self:allows(def) end
	local kind = self.app:scriptKind()
	self.lastKind = kind
	self.filterLabel.Text = self.app.settings.filterBySide
		and ("showing what fits a " .. kind) or "showing every block"

	-- search results, grouped by category ---------------------------------------
	local hits = l.search(self.query, allowed)
	self.topHit = hits and hits[1] or nil
	if hits then
		if #hits == 0 then
			b.text({
				Text = "Nothing matches. Try a word from the Luau you want,\nsuch as 'clone' or 'tween'.",
				Size = UDim2.new(1, 0, 0, 44),
				TextWrapped = true,
				fg = "text3",
				LayoutOrder = next_(),
				Parent = self.scroll,
			})
			return
		end

		local byCat, catOrder = {}, {}
		for _, def in ipairs(hits) do
			if not byCat[def.cat] then
				byCat[def.cat] = {}
				catOrder[#catOrder + 1] = def.cat
			end
			table.insert(byCat[def.cat], def)
		end

		self:heading(#hits .. " matching", next_(), "accent")
		for _, catId in ipairs(catOrder) do
			local cat = c.catById[catId]
			self:heading(cat.name .. "  " .. #byCat[catId], next_())
			for _, def in ipairs(byCat[catId]) do
				self:blockRow(def, next_()).Parent = self.scroll
			end
		end
		return
	end

	-- starred and recent ----------------------------------------------------------
	local favourites = self.app.settings.favourites or {}
	local starred = {}
	for defId in pairs(favourites) do
		local def = c.get(defId)
		if def then starred[#starred + 1] = def end
	end
	table.sort(starred, function(x, y) return x.label < y.label end)
	if #starred > 0 then
		self:heading("starred", next_(), "accent")
		for _, def in ipairs(starred) do
			self:blockRow(def, next_()).Parent = self.scroll
		end
		b.spacer(8, next_()).Parent = self.scroll
	end

	local recents = {}
	for _, defId in ipairs(self.app.settings.recents or {}) do
		local def = c.get(defId)
		if def and not favourites[defId] then recents[#recents + 1] = def end
	end
	if #recents > 0 then
		self:heading("recent", next_())
		for _, def in ipairs(recents) do
			self:blockRow(def, next_()).Parent = self.scroll
		end
		b.spacer(8, next_()).Parent = self.scroll
	end

	-- categories -------------------------------------------------------------------
	for _, cat in ipairs(c.cats) do
		local blocks = {}
		for _, def in ipairs(c.byCat(cat.id)) do
			if allowed(def) then blocks[#blocks + 1] = def end
		end

		local open = self.openCat == cat.id
		self:categoryHeader(cat, next_(), open, #blocks).Parent = self.scroll

		if open then
			b.rule({ LayoutOrder = next_(), parent = self.scroll, bg = "lineSoft" })
			b.text({
				Text = cat.blurb,
				Size = UDim2.new(1, 0, 0, 30),
				TextWrapped = true,
				TextSize = 11,
				fg = "text3",
				LayoutOrder = next_(),
				Parent = self.scroll,
			})

			if cat.id == "custom" then
				self:customControls(next_)
			end

			-- subgroups keep a category of seventy readable
			local groups, byGroup = {}, {}
			for _, def in ipairs(blocks) do
				local group = def.group or "General"
				if not byGroup[group] then
					byGroup[group] = {}
					groups[#groups + 1] = group
				end
				table.insert(byGroup[group], def)
			end

			for _, group in ipairs(groups) do
				if #groups > 1 then
					self:heading(group, next_())
				end
				for _, def in ipairs(byGroup[group]) do
					self:blockRow(def, next_()).Parent = self.scroll
				end
			end

			if #blocks == 0 then
				b.text({
					Text = cat.id == "custom"
						and "You have not made any blocks yet."
						or "Nothing here fits a " .. kind .. ". Switch the filter to see them.",
					Size = UDim2.new(1, 0, 0, 30),
					TextWrapped = true,
					TextSize = 11,
					fg = "text3",
					LayoutOrder = next_(),
					Parent = self.scroll,
				})
			end
			b.spacer(10, next_()).Parent = self.scroll
		end
	end
end

-- The buttons at the top of your own category.
function View:customControls(next_)
	local row = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = next_(),
		layout = { dir = "x", gap = 6 },
		Parent = self.scroll,
	})

	local make = b.button({
		label = "New block",
		Size = UDim2.fromOffset(96, 24),
		LayoutOrder = 1,
		bg = "accent",
		labelColor = "accentInk",
		Parent = row,
	})
	b.tip(make, "Write a block of your own, out of Luau with {holes} in it.")
	make.MouseButton1Click:Connect(function()
		if self.app.openBlockEditor then self.app.openBlockEditor(nil) end
	end)

	local fromCanvas = b.button({
		label = "From selection",
		Size = UDim2.fromOffset(110, 24),
		LayoutOrder = 2,
		Parent = row,
	})
	b.tip(fromCanvas, "Turn the selected block, and everything under it,\ninto a block of your own.")
	fromCanvas.MouseButton1Click:Connect(function()
		if self.app.makeBlockFromSelection then self.app.makeBlockFromSelection() end
	end)

	-- one edit row per block you have made
	for _, custom in ipairs(q.list()) do
		local editRow = b.new("Frame", {
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = next_(),
			Parent = self.scroll,
		})
		b.mono({
			Text = custom.label,
			Size = UDim2.new(1, -60, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			TextSize = 11,
			fg = "text3",
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = editRow,
		})
		local edit = b.button({
			label = "edit",
			Size = UDim2.fromOffset(46, 18),
			Position = UDim2.new(1, -48, 0, 1),
			Parent = editRow,
		})
		edit.MouseButton1Click:Connect(function()
			if self.app.openBlockEditor then self.app.openBlockEditor(custom.id) end
		end)
	end
end

return l
