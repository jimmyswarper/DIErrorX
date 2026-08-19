--!nonstrict
-- r  ·  the block editor
--
-- Where a custom block is written.  Two ways in and out of the same thing:
-- the panel here edits the Luau directly, and `open as canvas` turns that Luau
-- into blocks, drops them on the canvas, and turns them back when you save.
-- The placeholders survive the trip because the importer round-trips.

local a = require(script.Parent.a)
local b = require(script.Parent.b)
local c = require(script.Parent.c)
local d = require(script.Parent.d)
local e = require(script.Parent.e)
local q = require(script.Parent.q)

local r = {}

local KINDS = { "expr", "name", "str", "num", "multiline" }

--=============================================================================
-- the panel
--=============================================================================

local function labelled(parent, order, text, help)
	local row = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, help and 38 or 24),
		LayoutOrder = order,
		Parent = parent,
	})
	b.text({
		Text = text,
		Size = UDim2.fromOffset(96, 22),
		fg = "text2",
		Parent = row,
	})
	if help then
		b.text({
			Text = help,
			Size = UDim2.new(1, -100, 0, 14),
			Position = UDim2.fromOffset(100, 22),
			TextSize = 10,
			fg = "text3",
			Parent = row,
		})
	end
	return row
end

local function textField(parent, value, placeholder, onChange, multiline)
	local holder = b.new("Frame", {
		Size = multiline and UDim2.new(1, -100, 0, 150) or UDim2.new(1, -100, 0, 22),
		Position = UDim2.fromOffset(100, 0),
		bg = "field",
		stroke = { color = "fieldLine" },
		radius = a.metric.radius,
		Parent = parent,
	})
	local box = b.new("TextBox", {
		Text = value or "",
		PlaceholderText = placeholder or "",
		ClearTextOnFocus = false,
		MultiLine = multiline == true,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		Font = a.font.mono,
		TextSize = 12,
		fg = "text",
		ph = "text3",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
		Parent = holder,
	})
	box:GetPropertyChangedSignal("Text"):Connect(function()
		onChange(box.Text)
	end)
	return box
end

-- Opens the editor for an existing block, or a blank one when id is nil.
-- `customId` opens one you already have; `seed` opens the editor on a block
-- that has been built but not saved yet, which is how "from selection" and
-- "from a module" arrive here.
function r.open(app, customId, seed)
	local overlay = b.overlay()
	if not overlay then return end
	if app.blockEditor then app.blockEditor:Destroy() end

	local existing = customId and q.get(customId) or nil
	local custom
	if existing then
		custom = q.fromSave(q.toSave(existing))
		custom.id = existing.id
		custom.fn = existing.fn
	elseif seed then
		custom = seed
	else
		custom = q.new("My block", "-- what this block should do")
	end

	local shade = b.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		bg = "bg",
		BackgroundTransparency = 0.4,
		ZIndex = 940,
		Parent = overlay,
	})
	app.blockEditor = shade

	local panel = b.new("Frame", {
		Size = UDim2.new(0, 620, 0, 560),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		bg = "panel",
		stroke = { color = "line" },
		ZIndex = 941,
		Parent = shade,
	})

	b.micro(existing and "edit a block" or "make a block", {
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(14, 10),
		fg = "accent",
		ZIndex = 942,
		Parent = panel,
	})

	local scroll = b.new("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -86),
		Position = UDim2.fromOffset(12, 34),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 942,
		Parent = panel,
	})
	local column = b.new("Frame", {
		Size = UDim2.new(1, -14, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		layout = { dir = "y", gap = 8 },
		ZIndex = 942,
		Parent = scroll,
	})

	local order = 0
	local function next_() order = order + 1 return order end

	-- Declared up front because the fields below all want to redraw the preview
	-- as they are typed into, and the preview is built further down.
	local redraw

	-- name and group ------------------------------------------------------------
	local nameRow = labelled(column, next_(), "Name")
	textField(nameRow, custom.label, "Give a coin", function(text)
		custom.label = text
		if redraw then redraw() end
	end)

	local groupRow = labelled(column, next_(), "Group",
		"The heading it appears under in your category.")
	textField(groupRow, custom.group, "Mine", function(text)
		custom.group = text
	end)

	local wordingRow = labelled(column, next_(), "Wording",
		"How it reads on the canvas. Use the same {holes} as the Luau.")
	local wordingBox = textField(wordingRow, custom.wording or "", q.wordingOf(custom),
		function(text)
			custom.wording = text
			if redraw then redraw() end
		end)

	local docRow = labelled(column, next_(), "Description",
		"Shown in the tooltip, like every other block.")
	textField(docRow, custom.doc, "What it does, and the catch.", function(text)
		custom.doc = text
	end)

	-- the luau -------------------------------------------------------------------
	local luauRow = labelled(column, next_(), "Luau",
		"A {hole} inline is an input. A {hole} alone on a line is a slot.")
	luauRow.Size = UDim2.new(1, 0, 0, 172)
	local preview, inputList
	textField(luauRow, custom.luau, "", function(text)
		custom.luau = text
		q.refresh(custom)
		if redraw then redraw() end
	end, true)

	-- inputs and slots --------------------------------------------------------------
	inputList = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = next_(),
		layout = { dir = "y", gap = 4 },
		ZIndex = 942,
		Parent = column,
	})

	local returnsRow = b.new("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = next_(),
		ZIndex = 942,
		Parent = column,
	})
	b.text({
		Text = "Gives a value back",
		Size = UDim2.fromOffset(200, 22),
		fg = "text2",
		ZIndex = 943,
		Parent = returnsRow,
	})
	local returnsButton = b.button({
		label = custom.returns and "yes" or "no",
		Size = UDim2.fromOffset(56, 22),
		Position = UDim2.fromOffset(200, 0),
		bg = custom.returns and "accentSoft" or "raised",
		ZIndex = 943,
		Parent = returnsRow,
	})
	b.tip(returnsButton, "A block that gives a value back reads as\n" ..
		"`make x = ...` and can be used in any field.")

	-- preview --------------------------------------------------------------------------
	b.rule({ LayoutOrder = next_(), parent = column, bg = "lineSoft" })
	b.micro("what it will write", {
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = next_(),
		fg = "text3",
		ZIndex = 942,
		Parent = column,
	})
	preview = b.mono({
		Text = "",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 11,
		fg = "text2",
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = next_(),
		ZIndex = 942,
		Parent = column,
	})

	-- keeps the inputs list and the preview in step with the Luau -------------------------
	function redraw()
		b.clear(inputList)
		-- the placeholder shows the wording you would get for free, so it has to
		-- follow the name and the holes
		wordingBox.PlaceholderText = q.wordingOf(custom)
		for index, field in ipairs(custom.fields) do
			local row = b.new("Frame", {
				Size = UDim2.new(1, 0, 0, 24),
				LayoutOrder = index,
				ZIndex = 942,
				Parent = inputList,
			})
			b.mono({
				Text = "{" .. field.key .. "}",
				Size = UDim2.fromOffset(120, 22),
				TextSize = 12,
				fg = "accent",
				ZIndex = 943,
				Parent = row,
			})

			local kindButton = b.button({
				label = field.kind,
				Size = UDim2.fromOffset(80, 20),
				Position = UDim2.fromOffset(124, 1),
				ZIndex = 943,
				Parent = row,
			})
			local kindText = kindButton:FindFirstChildWhichIsA("TextLabel")
			b.tip(kindButton, "What sort of value belongs here. Expression fields\n" ..
				"get the full completion list.")
			kindButton.MouseButton1Click:Connect(function()
				local at = table.find(KINDS, field.kind) or 1
				field.kind = KINDS[(at % #KINDS) + 1]
				kindText.Text = field.kind
			end)

			local holder = b.new("Frame", {
				Size = UDim2.new(1, -212, 0, 22),
				Position = UDim2.fromOffset(208, 0),
				bg = "field",
				stroke = { color = "fieldLine" },
				radius = a.metric.radius,
				ZIndex = 943,
				Parent = row,
			})
			local defaultBox = b.new("TextBox", {
				Text = field.default or "",
				PlaceholderText = "default",
				ClearTextOnFocus = false,
				Size = UDim2.new(1, -12, 1, 0),
				Position = UDim2.fromOffset(6, 0),
				Font = a.font.mono,
				TextSize = 11,
				fg = "text",
				ph = "text3",
				ZIndex = 944,
				Parent = holder,
			})
			defaultBox:GetPropertyChangedSignal("Text"):Connect(function()
				field.default = defaultBox.Text
			end)
		end

		if #custom.slots > 0 then
			local names = {}
			for _, slot in ipairs(custom.slots) do names[#names + 1] = slot.key end
			b.text({
				Text = "Slots: " .. table.concat(names, ", ") ..
					"   (blocks with slots are written out in place, not as a function)",
				Size = UDim2.new(1, 0, 0, 18),
				TextSize = 10,
				fg = "text3",
				LayoutOrder = 900,
				ZIndex = 942,
				Parent = inputList,
			})
		end

		-- preview: compile a throwaway copy and generate a single use
		local trial = q.fromSave(q.toSave(custom))
		trial.id = "preview"
		trial.fn = custom.fn or q.functionName(custom.label)
		q.unregister("preview")
		local ok = q.register(trial)
		if ok then
			local def = c.get("custom_preview")
			local doc = d.newDoc("preview")
			local stack = d.newStack(doc, 0, 0)
			local block = d.create(doc, def.id)
			d.attachToStack(doc, block, stack, nil, {})
			if #def.slots > 0 then
				local inner = d.create(doc, "printText")
				inner.f.msg = "your blocks here"
				d.attachToSlot(doc, inner, block, def.slots[1].key, nil, {})
			end
			preview.Text = e.generate(doc, { header = false })
			q.unregister("preview")
		else
			preview.Text = "-- this block does not compile yet"
		end
	end
	returnsButton.MouseButton1Click:Connect(function()
		custom.returns = not custom.returns
		returnsButton:FindFirstChildWhichIsA("TextLabel").Text =
			custom.returns and "yes" or "no"
		b.states(returnsButton, custom.returns and "accentSoft" or "raised")
		redraw()
	end)

	redraw()

	-- buttons along the bottom ------------------------------------------------------------
	local bar = b.new("Frame", {
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.new(0, 12, 1, -44),
		layout = { dir = "x", gap = 6 },
		ZIndex = 942,
		Parent = panel,
	})

	local function close()
		shade:Destroy()
		app.blockEditor = nil
	end

	local canvasButton = b.button({
		label = "Open as canvas",
		Size = UDim2.fromOffset(126, 26),
		LayoutOrder = 1,
		ZIndex = 943,
		Parent = bar,
	})
	b.tip(canvasButton, "Edit the inside as blocks. Your project is put back\n" ..
		"when you finish.")
	canvasButton.MouseButton1Click:Connect(function()
		local doc, err = q.toCanvas(custom)
		if not doc then
			app:setStatus("that Luau does not parse: " ..
				(err and err.msg or "unknown"))
			return
		end
		app.customDraft = custom
		app.customReturnTo = app.doc
		app:setDoc(doc, "edit block")
		app.editingCustom = custom.id
		app:emit("editingCustom")
		if app.showTab then app.showTab("build") end
		app:setStatus("editing the block " .. custom.label)
		close()
	end)

	if existing then
		local copyButton = b.button({
			label = "Duplicate",
			Size = UDim2.fromOffset(90, 26),
			LayoutOrder = 2,
			ZIndex = 943,
			Parent = bar,
		})
		copyButton.MouseButton1Click:Connect(function()
			local copy = q.fromSave(q.toSave(custom))
			copy.id = nil
			copy = q.new(custom.label .. " copy", custom.luau)
			copy.group, copy.doc, copy.wording = custom.group, custom.doc, custom.wording
			copy.returns = custom.returns
			app:putCustom(copy)
			close()
			r.open(app, copy.id)
		end)

		local deleteButton = b.button({
			label = "Delete",
			Size = UDim2.fromOffset(80, 26),
			LayoutOrder = 3,
			ZIndex = 943,
			Parent = bar,
		})
		deleteButton.MouseButton1Click:Connect(function()
			app:dropCustom(custom.id)
			close()
		end)
	end

	local cancel = b.button({
		label = "Cancel",
		Size = UDim2.fromOffset(80, 26),
		Position = UDim2.new(1, -186, 0, 0),
		ZIndex = 943,
		Parent = bar,
	})
	cancel.MouseButton1Click:Connect(close)

	local save = b.button({
		label = "Save block",
		Size = UDim2.fromOffset(100, 26),
		Position = UDim2.new(1, -100, 0, 0),
		bg = "accent",
		labelColor = "accentInk",
		ZIndex = 943,
		Parent = bar,
	})
	save.MouseButton1Click:Connect(function()
		q.refresh(custom)
		if app:putCustom(custom) then close() end
	end)

	return shade
end

--=============================================================================
-- editing one as a canvas
--=============================================================================

-- The strip that appears across the canvas while a block is open as blocks.
function r.banner(app, parent)
	local strip = b.new("Frame", {
		Name = "EditingBlock",
		Size = UDim2.new(1, 0, 0, 30),
		bg = "accentSoft",
		Visible = false,
		ZIndex = 40,
		Parent = parent,
	})

	local label = b.text({
		Text = "",
		Size = UDim2.new(1, -240, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		Font = a.font.uiMedium,
		fg = "text",
		ZIndex = 41,
		Parent = strip,
	})

	local saveButton = b.button({
		label = "Save block",
		Size = UDim2.fromOffset(100, 22),
		Position = UDim2.new(1, -212, 0, 4),
		bg = "accent",
		labelColor = "accentInk",
		ZIndex = 41,
		Parent = strip,
	})

	local cancelButton = b.button({
		label = "Cancel",
		Size = UDim2.fromOffset(80, 22),
		Position = UDim2.new(1, -100, 0, 4),
		ZIndex = 41,
		Parent = strip,
	})

	local function finish()
		app.editingCustom = nil
		app.customDraft = nil
		if app.customReturnTo then
			app:setDoc(app.customReturnTo, "back to the project")
			app.customReturnTo = nil
		end
		app:emit("editingCustom")
	end

	saveButton.MouseButton1Click:Connect(function()
		local custom = app.customDraft
		if not custom then return end
		q.fromCanvas(custom, app.doc)
		app:putCustom(custom)
		finish()
	end)
	cancelButton.MouseButton1Click:Connect(function()
		app:setStatus("left the block as it was")
		finish()
	end)

	local function paint()
		local custom = app.customDraft
		strip.Visible = app.editingCustom ~= nil and custom ~= nil
		if custom then
			label.Text = "Editing the block \"" .. custom.label ..
				"\" -- the blocks below are its insides"
		end
	end
	app:on("editingCustom", paint)
	paint()

	return strip
end

return r
