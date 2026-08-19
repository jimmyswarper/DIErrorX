--!nonstrict
-- m  ·  the canvas
--
-- Draws the document, and handles everything you do with a mouse: dragging
-- stacks about, snapping them together, editing fields, panning and zooming.
--
-- Layout is left to Roblox.  Every block is an auto-sizing frame with a list
-- layout inside it, so a field growing as you type widens its block, which
-- widens its parent, with no measuring code anywhere.  What this module does
-- own is where the drop indicator goes, which is the one thing the engine
-- cannot work out for us.

local a = require(script.Parent.a)
local b = require(script.Parent.b)
local c = require(script.Parent.c)
local d = require(script.Parent.d)
local i = require(script.Parent.i)

local RunService = game:GetService("RunService")

local m = {}

local GRID = 20
local SNAP_RADIUS = 96
local LIFT_SECONDS = 0.16
local MIN_ZOOM, MAX_ZOOM = 0.5, 2

--=============================================================================
-- completion popup
--
-- One popup, reused by whichever field has focus.
--=============================================================================

local KIND_GLYPH = {
	property = "p", method = "m", event = "e", variable = "v", parameter = "a",
	["function"] = "f", service = "s", class = "c", enum = "u", snippet = "n",
	keyword = "k", global = "g", library = "l", choice = "o",
}

local function kindColor(kind)
	local map = {
		property = "cats.inst", method = "cats.funcs", event = "cats.events",
		variable = "cats.vars", parameter = "cats.vars", ["function"] = "cats.funcs",
		service = "cats.player", class = "cats.data", enum = "cats.logic",
		snippet = "accent", keyword = "cats.control", global = "cats.math",
		library = "cats.math", choice = "cats.text",
	}
	local token = map[kind] or "text3"
	local group, key = string.match(token, "^(%w+)%.(%w+)$")
	if group then return a.c[group][key] end
	return a.c[token]
end

local Popup = {}
Popup.__index = Popup

local function newPopup()
	local self = setmetatable({ open = false, items = {}, index = 1 }, Popup)

	self.frame = b.new("Frame", {
		Visible = false,
		Size = UDim2.fromOffset(340, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		bg = "raised",
		stroke = { color = "line" },
		ZIndex = 800,
		layout = { dir = "y", gap = 0 },
	})

	self.signature = b.mono({
		Name = "Signature",
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 11,
		fg = "accent",
		Visible = false,
		LayoutOrder = 1,
		ZIndex = 801,
		Parent = self.frame,
	})
	b.new("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = self.signature })

	self.list = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		layout = { dir = "y", gap = 0 },
		ZIndex = 801,
	})
	self.list.Parent = self.frame

	self.docPane = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		bg = "panel",
		pad = { x = 8, y = 6 },
		ZIndex = 801,
		Visible = false,
	})
	self.docPane.Parent = self.frame
	self.docText = b.text({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 11,
		fg = "text2",
		ZIndex = 802,
		Parent = self.docPane,
	})

	-- Clicking a row takes focus off the field, and the field's FocusLost would
	-- otherwise close the list before the click was delivered.  This flag lets
	-- the field tell "clicked the list" apart from "clicked away".
	self.frame.MouseEnter:Connect(function() self.hovering = true end)
	self.frame.MouseLeave:Connect(function() self.hovering = false end)

	return self
end

function Popup:hide()
	self.open = false
	self.frame.Visible = false
	self.textBox = nil
end

function Popup:rowFor(index, item)
	local row = b.new("TextButton", {
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = index,
		bg = "raised",
		ZIndex = 802,
		layout = { dir = "x", gap = 6, align = "middle" },
	})
	b.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = row })

	local chip = b.new("Frame", {
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = kindColor(item.kind),
		BackgroundTransparency = 0,
		LayoutOrder = 1,
		ZIndex = 803,
		Parent = row,
	})
	b.new("TextLabel", {
		Text = KIND_GLYPH[item.kind] or "?",
		Size = UDim2.fromScale(1, 1),
		Font = a.font.uiBold,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 804,
		Parent = chip,
	})

	b.mono({
		Text = item.name,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		TextSize = 12,
		fg = "text",
		LayoutOrder = 2,
		ZIndex = 803,
		Parent = row,
	})

	if item.detail then
		b.mono({
			Text = b.truncate(item.detail, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			TextSize = 11,
			fg = "text3",
			LayoutOrder = 3,
			ZIndex = 803,
			Parent = row,
		})
	end

	row.MouseButton1Click:Connect(function()
		self:accept(index)
	end)
	row.MouseEnter:Connect(function()
		self:setIndex(index)
	end)
	return row
end

function Popup:setIndex(index)
	if #self.items == 0 then return end
	self.index = math.clamp(index, 1, #self.items)
	for order, row in ipairs(self.rows or {}) do
		local chosen = order == self.index
		row.BackgroundColor3 = chosen and a.c.select or a.c.raised
	end
	local item = self.items[self.index]
	local text = item and (item.doc or item.detail)
	self.docPane.Visible = text ~= nil
	if text then self.docText.Text = text end
end

function Popup:move(delta)
	if not self.open then return false end
	self:setIndex(self.index + delta)
	return true
end

function Popup:accept(index)
	if not self.open or not self.textBox then return false end
	local item = self.items[index or self.index]
	if not item then return false end

	local box = self.textBox
	local text = box.Text
	local cursor = self.cursor
	local head = string.sub(text, 1, self.from - 1)
	local tail = string.sub(text, cursor)
	local insert = item.insert or item.name

	box.Text = head .. insert .. tail
	local caret = self.from + (item.caret or #insert)
	box.CursorPosition = caret

	-- Offering the list again here would just propose the word that was
	-- accepted, so it stays shut until the text changes again.
	self.suppressText = box.Text

	local callback = self.onAccept
	self:hide()
	if callback then callback(box) end
	if not box:IsFocused() then
		task.defer(function() box:CaptureFocus() end)
	end
	return true
end

function Popup:show(textBox, result, signature, anchor)
	local overlay = b.overlay()
	if not overlay then return end
	self.frame.Parent = overlay

	b.clear(self.list)
	self.rows = {}
	self.items = {}
	for index = 1, math.min(#result.items, 9) do
		local item = result.items[index]
		self.items[index] = item
		self.rows[index] = self:rowFor(index, item)
		self.rows[index].Parent = self.list
	end

	self.signature.Visible = signature ~= nil
	if signature then
		self.signature.Text = signature.label ..
			(signature.argument and ("   arg " .. signature.argument) or "")
	end

	if #self.items == 0 and not signature then
		self:hide()
		return
	end

	self.textBox = textBox
	self.from = result.from
	self.cursor = result.cursor
	self.open = #self.items > 0
	self.index = 1
	self:setIndex(1)

	local at = anchor.AbsolutePosition
	local size = anchor.AbsoluteSize
	local origin = overlay.AbsolutePosition
	local x = at.X - origin.X
	local y = at.Y - origin.Y + size.Y + 2
	local maxX = overlay.AbsoluteSize.X - 344
	local frameHeight = 22 * #self.items + 46
	if y + frameHeight > overlay.AbsoluteSize.Y and y > frameHeight then
		y = at.Y - origin.Y - frameHeight - 2
	end
	self.frame.Position = UDim2.fromOffset(math.clamp(x, 4, math.max(4, maxX)), math.max(4, y))
	self.frame.Visible = true
end

local popup = nil
local function getPopup()
	if not popup then popup = newPopup() end
	return popup
end

m.popup = getPopup

--=============================================================================
-- fields
--=============================================================================

-- A field sits on a coloured block, so it is a pale pill rather than a sunken
-- well: the block is the surface, and the pill is the hole cut in it.  Pills
-- are fully rounded; a multi-line field is a panel and keeps square-ish corners
-- because an oval that tall reads as a mistake.
local FIELD_H = 22

-- A text field inside a block: monospace, because a field is Luau.
local function makeTextField(view, block, def, field, value)
	local app = view.app
	local multiline = field.kind == "multiline"

	local box = b.new("TextBox", {
		Text = value,
		PlaceholderText = field.placeholder,
		ClearTextOnFocus = false,
		MultiLine = multiline,
		TextWrapped = false,
		Font = a.font.mono,
		TextSize = a.metric.blockText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
		AutomaticSize = multiline and Enum.AutomaticSize.XY or Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(multiline and 220 or 0, multiline and 44 or FIELD_H),
		bg = "well",
		fg = "wellInk",
		ph = "wellHint",
		radius = multiline and 4 or a.metric.wellRadius,
	})
	b.new("UIPadding", {
		PaddingLeft = UDim.new(0, multiline and 6 or 8),
		PaddingRight = UDim.new(0, multiline and 6 or 8),
		PaddingTop = UDim.new(0, multiline and 5 or 0),
		PaddingBottom = UDim.new(0, multiline and 5 or 0),
		Parent = box,
	})
	b.new("UISizeConstraint", {
		MinSize = Vector2.new(multiline and 220 or 30, multiline and 44 or FIELD_H),
		MaxSize = Vector2.new(multiline and 620 or 460, math.huge),
		Parent = box,
	})

	local pop = getPopup()
	local before = nil

	-- Keyed on which field has focus rather than on which one the popup last
	-- belonged to, so accepting a completion does not stop the list coming back.
	local function refreshCompletion()
		if view.editing ~= box then return end
		local cursor = box.CursorPosition or -1
		if cursor < 0 then return end

		local signature = nil
		if field.kind == "expr" or field.kind == "multiline" then
			signature = i.signature(box.Text, cursor, app.doc)
		end

		-- Straight after an accept, show the signature and nothing else; the
		-- next keystroke changes the text and brings the list back.
		if pop.suppressText == box.Text then
			if signature then
				pop:show(box, { items = {}, from = cursor, cursor = cursor },
					signature, box)
			else
				pop:hide()
			end
			return
		end

		local result = i.complete({
			text = box.Text, cursor = cursor, doc = app.doc, field = field,
		})
		result.cursor = cursor
		pop:show(box, result, signature, box)
	end

	box.Focused:Connect(function()
		-- One editing session is one undo step, even if focus bounces to the
		-- completion list and back in the middle of it.
		if not before then before = app:mark() end
		view.editing = box
		view.refreshCompletion = refreshCompletion
		-- the popup is shared, so it learns who it is serving on focus
		pop.onAccept = function(target)
			if target ~= box then return end
			block.f[field.key] = box.Text
			app:emit("codeDirty")
			task.defer(refreshCompletion)
		end
		app:select(block.id)
		refreshCompletion()
	end)

	box:GetPropertyChangedSignal("Text"):Connect(function()
		block.f[field.key] = box.Text
		app:emit("codeDirty")
		refreshCompletion()
	end)

	box:GetPropertyChangedSignal("CursorPosition"):Connect(refreshCompletion)

	box.FocusLost:Connect(function(enterPressed)
		-- The click landed on the completion list, not away from the field:
		-- leave everything as it is and take focus back.
		if pop.textBox == box and pop.hovering then
			task.defer(function()
				if view.editing == box and not box:IsFocused() then
					box:CaptureFocus()
				end
			end)
			return
		end

		if enterPressed and pop.open and pop.textBox == box then
			pop:accept()
			block.f[field.key] = box.Text
			app:commit("edit " .. field.key, before)
			before = nil
			task.defer(function() box:CaptureFocus() end)
			return
		end
		if pop.textBox == box then pop:hide() end
		view.editing = nil
		view.refreshCompletion = nil
		block.f[field.key] = box.Text
		if before then
			app:commit("edit " .. field.key, before)
			before = nil
		end
		view:render()
	end)

	return box
end

-- A dropdown field: the value, a chevron, and a list on click.
local function makeChoiceField(view, block, def, field, value)
	local app = view.app
	local button = b.new("TextButton", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, FIELD_H),
		bg = "well",
		radius = a.metric.wellRadius,
		layout = { dir = "x", gap = 5, align = "middle" },
	})
	b.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 7), Parent = button })

	local label = b.mono({
		Text = value,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, FIELD_H),
		LayoutOrder = 1,
		fg = "wellInk",
		Parent = button,
	})
	local chevron = b.chevron(7, "wellHint")
	chevron.LayoutOrder = 2
	chevron.Parent = button

	button.MouseButton1Click:Connect(function()
		local overlay = b.overlay()
		if not overlay then return end
		if view.menu then view.menu:Destroy() end

		local menu = b.new("Frame", {
			Size = UDim2.fromOffset(math.max(120, button.AbsoluteSize.X + 24), 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			bg = "raised",
			stroke = { color = "line" },
			layout = { dir = "y", gap = 0 },
			ZIndex = 820,
			Parent = overlay,
		})
		view.menu = menu
		local origin = overlay.AbsolutePosition
		menu.Position = UDim2.fromOffset(
			button.AbsolutePosition.X - origin.X,
			button.AbsolutePosition.Y - origin.Y + button.AbsoluteSize.Y + 2)

		for index, option in ipairs(field.options or {}) do
			local row = b.new("TextButton", {
				Size = UDim2.new(1, 0, 0, 20),
				LayoutOrder = index,
				bg = option == value and "select" or "raised",
				ZIndex = 821,
				Parent = menu,
			})
			b.mono({
				Text = option,
				Size = UDim2.new(1, -16, 1, 0),
				Position = UDim2.fromOffset(8, 0),
				TextSize = 12,
				ZIndex = 822,
				Parent = row,
			})
			b.states(row, option == value and "select" or "raised", 0.2)
			row.MouseButton1Click:Connect(function()
				menu:Destroy()
				view.menu = nil
				app:mutate("choose " .. field.key, function()
					block.f[field.key] = option
				end)
			end)
		end
	end)

	return button
end

--=============================================================================
-- block rendering
--=============================================================================

-- The wording on a block is prose, not code, so it is set in the interface
-- face; only the fields are monospace, because only the fields are Luau.
local function textRun(text, ink)
	local trimmed = string.match(text, "^%s*(.-)%s*$")
	if trimmed == "" then return nil end
	return b.text({
		Text = trimmed,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		Font = a.font.uiMedium,
		fg = ink,
		TextSize = a.metric.blockText,
	})
end

-- One line of a block: alternating words and fields.
local function renderRow(view, block, def, template, order, indentLeft, ink)
	local row = b.new("Frame", {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = order,
		layout = { dir = "x", gap = 6, align = "middle" },
	})
	b.new("UIPadding", {
		PaddingLeft = UDim.new(0, indentLeft or 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
		Parent = row,
	})

	local slot = 1
	for _, part in ipairs(template) do
		local child = nil
		if part.t == "text" then
			child = textRun(part.v, ink)
		else
			local field = def.fields[part.k]
			local value = c.fieldValue(def, block, part.k)
			if field and field.kind == "choice" then
				child = makeChoiceField(view, block, def, field, value)
			elseif field then
				child = makeTextField(view, block, def, field, value)
			end
		end
		if child then
			child.LayoutOrder = slot
			slot = slot + 1
			child.Parent = row
		end
	end
	return row
end

--=============================================================================
-- the interlock
--
-- A block has a notch bitten out of its top edge.  What fills that notch is
-- whatever is above the block: the block before it in the run, or the surface
-- the run is sitting on.  So a joint between two blocks shows the upper
-- block's colour carrying on down into the lower one, which is what makes a
-- run read as interlocked rather than as a pile of separate cards.  The last
-- block of a run is followed by a matching tab, so the bottom of a stack has
-- the piece that would fit into whatever came next.
--
-- Nothing here measures anything.  Both pieces are fixed-size rows in the same
-- list layout as everything else, so no child is ever sized from its parent.
--=============================================================================

local function joint(fill, order, name)
	local strip = b.new("Frame", {
		Name = name,
		Size = UDim2.fromOffset(a.metric.notchX + a.metric.notchW + 8, a.metric.notchH),
		LayoutOrder = order,
	})
	b.new("Frame", {
		Size = UDim2.fromOffset(a.metric.notchW, a.metric.notchH),
		Position = UDim2.fromOffset(a.metric.notchX, 0),
		bg = fill,
		radius = 2,
		Parent = strip,
	})
	return strip
end

-- What a notch is filled with, as a theme token so switching themes repaints
-- it: the category above, or the surface the run sits on.
local function fillOf(aboveCat, surface)
	if aboveCat then
		return function() return a.blockColor(aboveCat) end
	end
	return surface
end

local renderList

-- Returns the frame and the category it was painted with, so the next block in
-- the run knows what to fill its notch with.
local function renderBlock(view, block, order, aboveCat, surface)
	local def = c.get(block.k)
	local cat = def and def.cat or "special"
	local paint = function() return a.blockColor(cat) end
	local ink = function() return a.inkOn(a.blockColor(cat)) end

	local frame = b.new("Frame", {
		Name = block.id,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = order,
		bg = paint,
		radius = a.metric.blockRadius,
		layout = { dir = "y", gap = 0 },
	})
	b.new("UIPadding", {
		PaddingBottom = UDim.new(0, a.metric.notchH),
		Parent = frame,
	})
	joint(fillOf(aboveCat, surface), 0, "Notch").Parent = frame

	if not def then
		b.mono({
			Text = "unknown block: " .. tostring(block.k),
			Size = UDim2.fromOffset(240, 22),
			LayoutOrder = 1,
			fg = "err",
			Parent = frame,
		})
		view.frames[block.id] = frame
		return frame, cat
	end

	local order2 = 1
	for _, template in ipairs(def.headTpl) do
		renderRow(view, block, def, template, order2, 12, ink).Parent = frame
		order2 = order2 + 1
	end

	-- A block with slots is a C: the arm runs down the left of the mouth, and
	-- the tail row closes it off underneath.
	for _, slot in ipairs(def.slots) do
		if slot.preTpl then
			renderRow(view, block, def, slot.preTpl, order2, 12, ink).Parent = frame
			order2 = order2 + 1
		end
		local wrap = b.new("Frame", {
			Name = "slot_" .. slot.key,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = order2,
			layout = { dir = "y", gap = 0 },
			Parent = frame,
		})
		b.new("UIPadding", {
			PaddingLeft = UDim.new(0, a.metric.arm),
			PaddingRight = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 4),
			Parent = wrap,
		})
		-- the mouth is the workspace showing through the C, the way it does in
		-- every block editor worth copying
		local mouth = b.new("Frame", {
			Name = "mouth",
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			bg = "bg",
			radius = 4,
			layout = { dir = "y", gap = a.metric.rowGap },
			Parent = wrap,
		})
		b.new("UIPadding", {
			PaddingLeft = UDim.new(0, a.metric.mouthPad),
			PaddingRight = UDim.new(0, a.metric.mouthPad),
			PaddingTop = UDim.new(0, a.metric.mouthPad),
			PaddingBottom = UDim.new(0, a.metric.mouthPad),
			Parent = mouth,
		})
		order2 = order2 + 1
		renderList(view, d.children(view.app.doc, block, slot.key), mouth, {
			kind = "slot", parent = block, slotKey = slot.key, frame = mouth,
		}, "bg")
	end

	if def.tailTpl then
		renderRow(view, block, def, def.tailTpl, order2, 12, ink).Parent = frame
	end

	-- Selection and hover live on a stroke so nothing shifts when they change.
	-- At rest it is a darker edge of the block's own colour, which is what
	-- keeps two blocks of the same category from merging into one slab.
	local stroke = b.new("UIStroke", {
		Thickness = 2,
		Transparency = 0,
		Parent = frame,
	})
	a.bind(stroke, "Color", function() return a.blockEdge(cat) end)
	view.strokes[block.id] = { stroke = stroke, cat = cat }

	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			view:beginPress(block, input)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			view.app:select(block.id)
			view:contextMenu(block)
		end
	end)
	frame.MouseEnter:Connect(function()
		view.app.hover = block.id
		view.app:emit("hover", block.id)
	end)
	frame.MouseLeave:Connect(function()
		if view.app.hover == block.id then
			view.app.hover = nil
			view.app:emit("hover", nil)
		end
	end)

	if def.doc then
		b.tip(frame, function()
			if view.dragging then return nil end
			return def.label .. "  --  " .. def.doc ..
				"\nHold the left button on it to pick it up."
		end)
	end

	view.frames[block.id] = frame
	return frame, cat
end

-- Draws a run of blocks into `container` and registers it as a drop target.
-- `surface` is the theme token of whatever the run is sitting on, which is
-- what the first block's notch is filled with.
function renderList(view, blocks, container, info, surface)
	local items = {}
	local above = nil
	for index, block in ipairs(blocks) do
		local frame, cat = renderBlock(view, block, index, above, surface)
		frame.Parent = container
		items[#items + 1] = { block = block, frame = frame }
		above = cat
	end

	if #blocks == 0 then
		-- an empty mouth: a notch with nothing in it, so it reads as a socket
		local empty = b.new("Frame", {
			Name = "Empty",
			Size = UDim2.fromOffset(58, 16),
			LayoutOrder = 1,
			Parent = container,
		})
		b.new("Frame", {
			Size = UDim2.fromOffset(a.metric.notchW, a.metric.notchH),
			Position = UDim2.fromOffset(a.metric.notchX, 0),
			bg = "line",
			BackgroundTransparency = 0.55,
			radius = 2,
			Parent = empty,
		})
	else
		joint(fillOf(above, surface), #blocks + 1, "Tab").Parent = container
	end

	info.items = items
	view.lists[#view.lists + 1] = info
	return items
end

--=============================================================================
-- the view
--=============================================================================

local View = {}
View.__index = View

function m.mount(app, parent)
	local view = setmetatable({
		app = app,
		zoom = app.settings.zoom or 1,
		pan = Vector2.new(0, 0),
		frames = {},
		strokes = {},
		lists = {},
	}, View)

	view.root = b.new("Frame", {
		Name = "Canvas",
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		bg = "bg",
		Parent = parent,
	})

	view.gridLayer = b.new("Frame", {
		Name = "Grid",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = view.root,
	})

	view.content = b.new("Frame", {
		Name = "Content",
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 2,
		Parent = view.root,
	})
	view.scale = b.new("UIScale", { Scale = view.zoom, Parent = view.content })

	-- Where the block will land, drawn as the silhouette of a block's top edge:
	-- a bar with the tab standing on it.  A plain line says "somewhere here";
	-- this says "this is the socket it goes into".
	view.indicator = b.new("Frame", {
		Name = "Drop",
		Size = UDim2.fromOffset(80, 6),
		Visible = false,
		bg = "accent",
		radius = 3,
		ZIndex = 60,
		Parent = view.root,
	})
	b.new("Frame", {
		Size = UDim2.fromOffset(a.metric.notchW, a.metric.notchH),
		Position = UDim2.fromOffset(a.metric.notchX, -a.metric.notchH + 2),
		bg = "accent",
		radius = 2,
		ZIndex = 60,
		Parent = view.indicator,
	})


	view:makeLift()
	view:buildGrid()
	view:wireInput()

	app:on("doc", function() view:render() end)
	app:on("select", function() view:paintStates() end)
	app:on("hover", function() view:paintStates() end)
	a.onChange(function() view:render() end)

	view:render()
	return view
end

--=============================================================================
-- grid
--=============================================================================

-- The shadow a lifted stack casts, so a picked-up block reads as picked up
-- rather than merely selected.  It sits on the content layer so it pans and
-- zooms with the canvas, which means it is rebuilt with everything else.
function View:makeLift()
	self.lift = b.new("Frame", {
		Name = "Lift",
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
		bg = "shadow",
		BackgroundTransparency = 0.72,
		radius = a.metric.blockRadius,
		ZIndex = 45,
		Parent = self.content,
	})
	return self.lift
end

function View:buildGrid()
	self.gridLines = { vertical = {}, horizontal = {} }
	for index = 1, 90 do
		self.gridLines.vertical[index] = b.new("Frame", {
			Size = UDim2.new(0, 1, 1, 0),
			bg = "grid",
			Visible = false,
			Parent = self.gridLayer,
		})
	end
	for index = 1, 70 do
		self.gridLines.horizontal[index] = b.new("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			bg = "grid",
			Visible = false,
			Parent = self.gridLayer,
		})
	end
	self.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:layoutGrid()
	end)
	self:layoutGrid()
end

function View:layoutGrid()
	local spacing = GRID * self.zoom
	if spacing < 8 then spacing = spacing * 2 end
	local size = self.root.AbsoluteSize
	local startX = self.pan.X % spacing
	local startY = self.pan.Y % spacing

	local majorEvery = 5
	local firstIndexX = math.floor(-self.pan.X / spacing)
	for index, line in ipairs(self.gridLines.vertical) do
		local x = startX + (index - 1) * spacing
		if x > size.X + spacing then
			line.Visible = false
		else
			line.Visible = true
			line.Position = UDim2.fromOffset(math.floor(x), 0)
			local major = (firstIndexX + index - 1) % majorEvery == 0
			line.BackgroundColor3 = major and a.c.gridMajor or a.c.grid
		end
	end

	local firstIndexY = math.floor(-self.pan.Y / spacing)
	for index, line in ipairs(self.gridLines.horizontal) do
		local y = startY + (index - 1) * spacing
		if y > size.Y + spacing then
			line.Visible = false
		else
			line.Visible = true
			line.Position = UDim2.fromOffset(0, math.floor(y))
			local major = (firstIndexY + index - 1) % majorEvery == 0
			line.BackgroundColor3 = major and a.c.gridMajor or a.c.grid
		end
	end
end

--=============================================================================
-- rendering
--=============================================================================

function View:render()
	if self.rendering then return end
	self.rendering = true

	b.clear(self.content)
	-- the shadow lives on the content layer, so it goes with everything else
	self:makeLift()
	if self.empty then
		self.empty:Destroy()
		self.empty = nil
	end
	self.frames = {}
	self.strokes = {}
	self.lists = {}
	self.stackFrames = {}

	for _, stack in ipairs(self.app.doc.stacks) do
		local frame = b.new("Frame", {
			Name = stack.id,
			Position = UDim2.fromOffset(stack.x or 0, stack.y or 0),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			layout = { dir = "y", gap = a.metric.rowGap },
			Parent = self.content,
		})
		self.stackFrames[stack.id] = frame
		renderList(self, d.stackBlocks(self.app.doc, stack), frame, {
			kind = "stack", stack = stack, frame = frame,
		}, "bg")
	end

	if #self.app.doc.stacks == 0 then
		self.empty = b.new("Frame", {
			Size = UDim2.fromOffset(340, 60),
			Position = UDim2.fromScale(0.5, 0.42),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 3,
			Parent = self.root,
		})
		b.text({
			Text = "Nothing here yet",
			Size = UDim2.new(1, 0, 0, 20),
			Font = a.font.uiBold,
			TextSize = 14,
			fg = "text3",
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 4,
			Parent = self.empty,
		})
		b.text({
			Text = "Click a block in the palette to place it, or drag it out here.\n" ..
				"Once it is on the canvas, hold the left button on it to move it.",
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.fromOffset(0, 22),
			TextWrapped = true,
			TextSize = 12,
			fg = "text3",
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 4,
			Parent = self.empty,
		})
	elseif self.empty then
		self.empty:Destroy()
		self.empty = nil
	end

	self.content.Position = UDim2.fromOffset(self.pan.X, self.pan.Y)
	self.scale.Scale = self.zoom
	self:paintStates()
	self:layoutGrid()
	self.rendering = false
end

function View:paintStates()
	for id, entry in pairs(self.strokes) do
		local stroke = entry.stroke
		if stroke.Parent then
			if self.app.selection == id then
				stroke.Color = a.c.accent
				stroke.Thickness = 2
			elseif self.app.hover == id then
				stroke.Color = a.inkOn(a.blockColor(entry.cat))
				stroke.Thickness = 2
			else
				stroke.Color = a.blockEdge(entry.cat)
				stroke.Thickness = 2
			end
		end
	end
end

--=============================================================================
-- coordinates
--=============================================================================

function View:pluginGui()
	return self.root:FindFirstAncestorWhichIsA("PluginGui")
end

function View:mouse()
	local gui = self:pluginGui()
	if not gui then return Vector2.new(0, 0) end
	return gui:GetRelativeMousePosition()
end

-- Widget coordinates -> canvas coordinates.  `GetRelativeMousePosition` and
-- `AbsolutePosition` are both measured from the top left of the plugin window,
-- so no further translation is needed.
function View:toCanvas(point)
	return (point - self.content.AbsolutePosition) / self.zoom
end

function View:viewCentre()
	local size = self.root.AbsoluteSize
	return Vector2.new(
		(size.X / 2 - self.pan.X) / self.zoom,
		(size.Y / 2 - self.pan.Y) / self.zoom)
end

--=============================================================================
-- panning and zoom
--=============================================================================

function View:setPan(x, y)
	self.pan = Vector2.new(math.floor(x), math.floor(y))
	self.content.Position = UDim2.fromOffset(self.pan.X, self.pan.Y)
	self:layoutGrid()
end

function View:setZoom(zoom, focus)
	local wanted = math.clamp(zoom, MIN_ZOOM, MAX_ZOOM)
	if math.abs(wanted - self.zoom) < 0.001 then return end
	focus = focus or (self.root.AbsoluteSize / 2)
	-- keep whatever is under `focus` where it is
	local before = (focus - self.pan) / self.zoom
	self.zoom = wanted
	self.scale.Scale = wanted
	local after = before * wanted
	self:setPan(focus.X - after.X, focus.Y - after.Y)
	self.app:setSetting("zoom", wanted)
	self.app:setStatus(string.format("zoom %d%%", math.floor(wanted * 100 + 0.5)))
end

function View:resetZoom()
	self:setZoom(1, self.root.AbsoluteSize / 2)
end

function View:wireInput()
	local root = self.root

	root.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
		local delta = input.Position.Z
		local ctrl = b.keyDown(Enum.KeyCode.LeftControl)
			or b.keyDown(Enum.KeyCode.RightControl)
		if ctrl then
			local gui = self:pluginGui()
			local at = gui and (gui:GetRelativeMousePosition() - root.AbsolutePosition) or nil
			self:setZoom(self.zoom * (delta > 0 and 1.1 or 0.9), at)
		elseif b.keyDown(Enum.KeyCode.LeftShift) then
			self:setPan(self.pan.X + delta * 48, self.pan.Y)
		else
			self:setPan(self.pan.X, self.pan.Y + delta * 48)
		end
	end)

	root.InputBegan:Connect(function(input)
		local middle = input.UserInputType == Enum.UserInputType.MouseButton3
		local left = input.UserInputType == Enum.UserInputType.MouseButton1
		if not (middle or left) then return end

		if left then
			self.app:select(nil)
			if self.menu then
				self.menu:Destroy()
				self.menu = nil
			end
			getPopup():hide()
		end

		local gui = self:pluginGui()
		if not gui then return end
		local start = gui:GetRelativeMousePosition()
		local startPan = self.pan
		local button = middle and Enum.UserInputType.MouseButton3
			or Enum.UserInputType.MouseButton1
		local spaceHeld = b.keyDown(Enum.KeyCode.Space)
		b.noteDown(input.UserInputType)
		if left and not spaceHeld then
			-- plain left-drag on empty canvas still pans; a click alone deselects
		end

		task.spawn(function()
			while b.pressing(input, button) do
				local now = gui:GetRelativeMousePosition()
				local delta = now - start
				if delta.Magnitude > 2 then
					self:setPan(startPan.X + delta.X, startPan.Y + delta.Y)
				end
				RunService.Heartbeat:Wait()
			end
		end)
	end)
end

--=============================================================================
-- dragging
--=============================================================================

local function listIsInside(view, info, draggedBlock)
	if info.stack and view.drag and info.stack.id == view.drag.stack.id then
		return true
	end
	if info.parent then
		return d.isAncestor(view.app.doc, draggedBlock, info.parent)
	end
	return false
end

-- Every place the dragged stack could be dropped, in widget coordinates.
function View:dropPoints(draggedBlock)
	local points = {}
	for _, info in ipairs(self.lists) do
		if not listIsInside(self, info, draggedBlock) then
			local items = info.items or {}
			if #items == 0 then
				local at = info.frame.AbsolutePosition
				points[#points + 1] = {
					at = at + Vector2.new(4, info.frame.AbsoluteSize.Y / 2),
					info = info, index = 1,
					width = math.max(60, info.frame.AbsoluteSize.X),
				}
			else
				for index, item in ipairs(items) do
					points[#points + 1] = {
						at = item.frame.AbsolutePosition,
						info = info, index = index,
						width = item.frame.AbsoluteSize.X,
					}
				end
				local last = items[#items]
				points[#points + 1] = {
					at = last.frame.AbsolutePosition +
						Vector2.new(0, last.frame.AbsoluteSize.Y + a.metric.rowGap),
					info = info, index = #items + 1,
					width = last.frame.AbsoluteSize.X,
				}
			end
		end
	end
	return points
end

function View:beginDrag(block, mouse)
	local gui = self:pluginGui()
	local frame = self.frames[block.id]
	if not frame or not gui then return end

	b.hideTip()
	getPopup():hide()

	local canvasPos = (frame.AbsolutePosition - self.content.AbsolutePosition) / self.zoom
	self.dragBefore = self.app:mark()
	local stack = d.detach(self.app.doc, block, canvasPos.X, canvasPos.Y)
	self.drag = { block = block, stack = stack }
	self:render()

	local stackFrame = self.stackFrames[stack.id]
	if not stackFrame then
		self.drag = nil
		return
	end
	self.drag.frame = stackFrame
	self.drag.grab = mouse - stackFrame.AbsolutePosition
	self.drag.points = self:dropPoints(block)
	self.dragging = true

	stackFrame.ZIndex = 50
	for _, descendant in ipairs(stackFrame:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = descendant.ZIndex + 50
		end
	end
end

function View:updateDrag(mouse)
	local drag = self.drag
	if not drag or not drag.frame then return end
	local gui = self:pluginGui()
	if not gui then return end

	local wanted = mouse - drag.grab
	local canvas = (wanted - self.content.AbsolutePosition) / self.zoom
	drag.stack.x, drag.stack.y = canvas.X, canvas.Y
	drag.frame.Position = UDim2.fromOffset(canvas.X, canvas.Y)

	local origin = drag.frame.AbsolutePosition
	local best, bestScore = nil, SNAP_RADIUS
	for _, point in ipairs(drag.points) do
		local delta = point.at - origin
		local score = math.abs(delta.Y) + math.abs(delta.X) * 0.55
		if score < bestScore then
			best, bestScore = point, score
		end
	end

	-- dragging back over the palette throws the block away
	local palette = self.app.paletteFrame
	local overPalette = false
	if palette and palette.Visible then
		local at = palette.AbsolutePosition
		local size = palette.AbsoluteSize
		overPalette = mouse.X >= at.X and mouse.X <= at.X + size.X
			and mouse.Y >= at.Y and mouse.Y <= at.Y + size.Y
	end
	if overPalette ~= drag.overPalette then
		drag.overPalette = overPalette
		self.app:emit("dragOverPalette", overPalette)
	end
	if overPalette then
		best = nil
		self.indicator.Visible = false
	end

	drag.target = best
	if best then
		local at = best.at - self.root.AbsolutePosition
		self.indicator.Visible = true
		self.indicator.Position = UDim2.fromOffset(at.X, at.Y - 3)
		self.indicator.Size = UDim2.fromOffset(math.max(60, best.width), 6)
	else
		self.indicator.Visible = false
	end

	-- the shadow follows the stack, one block's corner behind it
	if self.lift then
		local size = drag.frame.AbsoluteSize / self.zoom
		self.lift.Visible = true
		self.lift.Position = UDim2.fromOffset(canvas.X + 5, canvas.Y + 6)
		self.lift.Size = UDim2.fromOffset(size.X, size.Y)
	end
end

function View:endDrag()
	local drag = self.drag
	self.dragging = false
	self.indicator.Visible = false
	if self.lift then self.lift.Visible = false end
	if not drag then return end

	local doc = self.app.doc
	local target = drag.target

	if drag.overPalette then
		self.app:emit("dragOverPalette", false)
		d.remove(doc, drag.block)
		self.app:select(nil)
		self.drag = nil
		self.app:commit("delete block", self.dragBefore)
		self.dragBefore = nil
		self.app:setStatus("deleted")
		return
	end

	if target then
		local info = target.info
		if info.kind == "slot" then
			d.attachToSlot(doc, drag.block, info.parent, info.slotKey, target.index)
		else
			d.attachToStack(doc, drag.block, info.stack, target.index)
		end
	else
		-- left loose: line it up with the grid so the canvas stays tidy
		drag.stack.x = math.floor((drag.stack.x or 0) / GRID + 0.5) * GRID
		drag.stack.y = math.floor((drag.stack.y or 0) / GRID + 0.5) * GRID
	end

	self.drag = nil
	self.app:commit(target and "move block" or "drag block", self.dragBefore)
	self.dragBefore = nil
end

-- Input bubbles up from a block's fields to the block itself, so dragging has
-- to ask whether the press actually landed on a field first -- otherwise
-- selecting text in a field would pick the whole stack up.
function View:overField(block)
	local frame = self.frames[block.id]
	if not frame then return false end
	local gui = self:pluginGui()
	if not gui then return false end
	local mouse = gui:GetRelativeMousePosition()
	for _, node in ipairs(frame:GetDescendants()) do
		if node:IsA("TextBox") or node:IsA("TextButton") then
			local at, size = node.AbsolutePosition, node.AbsoluteSize
			if mouse.X >= at.X and mouse.X <= at.X + size.X
				and mouse.Y >= at.Y and mouse.Y <= at.Y + size.Y then
				return true
			end
		end
	end
	return false
end

-- `carried` marks a block that arrived from the palette already under a held
-- button: the hold that picks it up happened over there, so it lifts at once
-- rather than asking for a second one.
function View:beginPress(block, input, carried)
	if self.dragging then return end
	local gui = self:pluginGui()
	if not gui then return end
	if input then b.noteDown(input.UserInputType) end
	if input and not carried and self:overField(block) then
		self.app:select(block.id)
		return
	end

	-- Space turns the whole canvas into a hand tool, blocks included.
	if b.keyDown(Enum.KeyCode.Space) then
		local start = gui:GetRelativeMousePosition()
		local startPan = self.pan
		task.spawn(function()
			while b.pressing(input, Enum.UserInputType.MouseButton1) do
				local delta = gui:GetRelativeMousePosition() - start
				self:setPan(startPan.X + delta.X, startPan.Y + delta.Y)
				RunService.Heartbeat:Wait()
			end
		end)
		return
	end

	self.app:select(block.id)
	local held = os.clock()

	task.spawn(function()
		local lifted = false
		if carried then
			lifted = true
			self:beginDrag(block, gui:GetRelativeMousePosition())
		end
		while b.pressing(input, Enum.UserInputType.MouseButton1) do
			local now = gui:GetRelativeMousePosition()
			if not lifted then
				if self:shouldLift(os.clock() - held) then
					lifted = true
					self:beginDrag(block, now)
				end
			else
				self:updateDrag(now)
			end
			RunService.Heartbeat:Wait()
		end
		if lifted then self:endDrag() end
	end)
end

-- A block is picked up by holding the button on it, not by clicking and
-- dragging.  A quick click therefore selects it and nothing else, which is
-- what makes it safe to click a block in a stack to read the code it wrote,
-- and what stops a stack coming apart under a slightly wobbly hand.
function View:shouldLift(heldFor)
	return heldFor >= (self.liftAfter or LIFT_SECONDS)
end

--=============================================================================
-- adding, removing, arranging
--=============================================================================

function View:addBlock(defId, canvasPosition)
	local app = self.app
	local selected = app:selected()
	local position = canvasPosition

	return app:mutate("add " .. defId, function(doc)
		local block = d.create(doc, defId)
		if not position and selected then
			-- drop it straight after whatever is selected, where a person
			-- would expect the next line to go
			local def = c.get(selected.k)
			if def and #def.slots > 0 and #d.children(doc, selected, def.slots[1].key) == 0 then
				d.attachToSlot(doc, block, selected, def.slots[1].key, 1, {})
				app:select(block.id)
				return block
			end
			local list, owner = d.listOf(doc, selected)
			local index = (d.indexOf(doc, selected) or 0) + 1
			if selected.p then
				d.attachToSlot(doc, block, doc.blocks[selected.p], selected.ps, index, {})
			else
				d.attachToStack(doc, block, owner, index, {})
			end
			app:select(block.id)
			return block
		end

		local at = position or self:viewCentre()
		local stack = d.newStack(doc,
			math.floor(at.X / GRID + 0.5) * GRID,
			math.floor(at.Y / GRID + 0.5) * GRID)
		d.attachToStack(doc, block, stack, 1, {})
		app:select(block.id)
		return block
	end)
end

-- Used by the palette: make the block, then pick it straight up.
function View:spawnAndDrag(defId, mouse, input)
	if not self:pluginGui() then return end
	local block = self:addBlock(defId, self:toCanvas(mouse))
	if not block then return end
	task.defer(function()
		local frame = self.frames[block.id]
		if frame then self:beginPress(block, input, true) end
	end)
	return block
end

function View:deleteSelected()
	local block = self.app:selected()
	if not block then
		self.app:setStatus("nothing selected")
		return
	end
	local def = c.get(block.k)
	self.app:mutate("delete " .. (def and def.label or "block"), function(doc)
		d.remove(doc, block)
	end)
	self.app:select(nil)
end

function View:duplicateSelected()
	local block = self.app:selected()
	if not block then return end
	self.app:mutate("duplicate", function(doc)
		local list, owner = d.listOf(doc, block)
		local copy = d.duplicate(doc, block, 0, 0)
		-- put the copy right under the original rather than loose on the canvas
		if block.p then
			d.attachToSlot(doc, copy, doc.blocks[block.p], block.ps,
				(d.indexOf(doc, block) or 0) + 1, {})
		elseif owner then
			d.attachToStack(doc, copy, owner, (d.indexOf(doc, block) or 0) + 1, {})
		end
		self.app:select(copy.id)
	end)
end

-- Lays every stack out in one column, in the order they will run.
function View:tidy()
	self.app:mutate("tidy canvas", function(doc)
		local sorted = d.sortedStacks(doc)
		local y = 24
		for _, stack in ipairs(sorted) do
			stack.x = 24
			stack.y = y
			local frame = self.stackFrames[stack.id]
			local height = frame and (frame.AbsoluteSize.Y / self.zoom) or 60
			y = y + height + 28
		end
		doc.stacks = sorted
	end)
	self:setPan(0, 0)
	self.app:setStatus("tidied " .. #self.app.doc.stacks .. " stacks")
end

function View:focusBlock(blockId)
	local frame = self.frames[blockId]
	if not frame then return end
	local at = (frame.AbsolutePosition - self.content.AbsolutePosition) / self.zoom
	local size = self.root.AbsoluteSize
	self:setPan(size.X / 3 - at.X * self.zoom, size.Y / 3 - at.Y * self.zoom)
end

--=============================================================================
-- context menu
--=============================================================================

function View:contextMenu(block)
	local overlay = b.overlay()
	if not overlay then return end
	if self.menu then self.menu:Destroy() end

	local def = c.get(block.k)
	local menu = b.new("Frame", {
		Size = UDim2.fromOffset(190, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		bg = "raised",
		stroke = { color = "line" },
		layout = { dir = "y", gap = 0 },
		ZIndex = 830,
		Parent = overlay,
	})
	self.menu = menu

	local gui = self:pluginGui()
	local at = gui and gui:GetRelativeMousePosition() or Vector2.new(0, 0)
	menu.Position = UDim2.fromOffset(at.X, at.Y)

	b.micro(def and def.label or "block", {
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 0),
		LayoutOrder = 0,
		ZIndex = 831,
		Parent = menu,
	})

	local actions = {
		{ "Duplicate", "Ctrl+D", function() self:duplicateSelected() end },
		{ "Pull out to canvas", "", function()
			self.app:mutate("detach", function(doc)
				local centre = self:viewCentre()
				d.detach(doc, block, centre.X, centre.Y)
			end)
		end },
		{ "Make into a block", "", function()
			self.app:select(block.id)
			if self.app.makeBlockFromSelection then
				self.app.makeBlockFromSelection()
			end
		end },
		{ "Delete", "Del", function() self:deleteSelected() end },
	}

	for index, action in ipairs(actions) do
		local row = b.new("TextButton", {
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = index,
			bg = "raised",
			ZIndex = 831,
			Parent = menu,
		})
		b.text({
			Text = action[1],
			Size = UDim2.new(1, -70, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			ZIndex = 832,
			Parent = row,
		})
		b.mono({
			Text = action[2],
			Size = UDim2.fromOffset(60, 24),
			Position = UDim2.new(1, -66, 0, 0),
			TextSize = 10,
			fg = "text3",
			ZIndex = 832,
			Parent = row,
		})
		b.states(row, "raised", 0.2)
		row.MouseButton1Click:Connect(function()
			menu:Destroy()
			self.menu = nil
			action[3]()
		end)
	end

	menu.MouseLeave:Connect(function()
		task.delay(0.35, function()
			if self.menu == menu then
				menu:Destroy()
				self.menu = nil
			end
		end)
	end)
end

return m
