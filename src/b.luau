--!nonstrict
-- b  ·  interface primitives
--
-- A thin layer over Instance.new so the rest of the plugin reads as layout
-- rather than boilerplate.  Colour properties take theme token names instead of
-- Color3 values, which is what lets the whole window repaint when the theme
-- changes.
--
--   b.new("TextLabel", { Text = "hello", fg = "text2", Size = ... })
--
-- Shorthand keys: bg · fg · stroke · radius · pad · layout · parent · children

local a = require(script.Parent.a)

local b = {}

local overlay = nil
local typingIn = nil

function b.setOverlay(frame)
	overlay = frame
end

function b.overlay()
	return overlay
end

local SHORTHAND = {
	bg = true, fg = true, stroke = true, radius = true, pad = true,
	layout = true, parent = true, children = true, ph = true,
}

local function applyPad(instance, pad)
	local padding = Instance.new("UIPadding")
	if type(pad) == "number" then
		padding.PaddingLeft = UDim.new(0, pad)
		padding.PaddingRight = UDim.new(0, pad)
		padding.PaddingTop = UDim.new(0, pad)
		padding.PaddingBottom = UDim.new(0, pad)
	else
		padding.PaddingLeft = UDim.new(0, pad.l or pad.x or 0)
		padding.PaddingRight = UDim.new(0, pad.r or pad.x or 0)
		padding.PaddingTop = UDim.new(0, pad.t or pad.y or 0)
		padding.PaddingBottom = UDim.new(0, pad.b or pad.y or 0)
	end
	padding.Parent = instance
	return padding
end

local function applyLayout(instance, layout)
	local list = Instance.new("UIListLayout")
	list.FillDirection = layout.dir == "x" and Enum.FillDirection.Horizontal
		or Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, layout.gap or 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	if layout.align == "center" then
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
	elseif layout.align == "right" then
		list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	elseif layout.align == "middle" then
		list.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	list.Parent = instance
	return list
end

function b.new(className, props, children)
	local instance = Instance.new(className)
	props = props or {}

	if instance:IsA("GuiObject") then
		instance.BorderSizePixel = 0
		instance.BackgroundColor3 = a.c.panel
		instance.BackgroundTransparency = props.bg and 0 or 1
	end
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		instance.Font = a.font.ui
		instance.TextSize = a.metric.uiText
		instance.TextXAlignment = Enum.TextXAlignment.Left
		instance.TextYAlignment = Enum.TextYAlignment.Center
		instance.TextColor3 = a.c.text
		if instance:IsA("TextButton") then
			instance.AutoButtonColor = false
			instance.Text = ""
		end
	end
	if instance:IsA("TextBox") then
		-- UserInputService cannot see a text box inside a plugin widget, so the
		-- plugin keeps its own answer to "is the user typing?"
		instance.Focused:Connect(function() typingIn = instance end)
		instance.FocusLost:Connect(function()
			if typingIn == instance then typingIn = nil end
		end)
	end
	if instance:IsA("ScrollingFrame") then
		instance.ScrollBarThickness = 4
		instance.ScrollBarImageTransparency = 0.4
		instance.BorderSizePixel = 0
		instance.CanvasSize = UDim2.new()
		a.bind(instance, "ScrollBarImageColor3", "text3")
	end

	for key, value in pairs(props) do
		if not SHORTHAND[key] then
			instance[key] = value
		end
	end

	if props.bg then
		a.bind(instance, "BackgroundColor3", props.bg)
		instance.BackgroundTransparency = props.BackgroundTransparency or 0
	end
	if props.fg then
		a.bind(instance, "TextColor3", props.fg)
	end
	if props.ph then
		a.bind(instance, "PlaceholderColor3", props.ph)
	end
	if props.radius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, props.radius)
		corner.Parent = instance
	end
	if props.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = props.stroke.thickness or 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Transparency = props.stroke.transparency or 0
		a.bind(stroke, "Color", props.stroke.color or "line")
		stroke.Parent = instance
		instance:SetAttribute("hasStroke", true)
	end
	if props.pad then applyPad(instance, props.pad) end
	if props.layout then applyLayout(instance, props.layout) end

	for _, child in ipairs(children or props.children or {}) do
		if child then child.Parent = instance end
	end
	if props.parent then instance.Parent = props.parent end
	return instance
end

--=============================================================================
-- text
--=============================================================================

function b.text(props)
	props = props or {}
	props.fg = props.fg or "text"
	props.Size = props.Size or UDim2.new(1, 0, 0, a.metric.row)
	return b.new("TextLabel", props)
end

-- Small, spaced, upper-case label used for section headings.
function b.micro(text, props)
	props = props or {}
	props.Text = string.upper(text)
	props.Font = a.font.uiBold
	props.TextSize = a.metric.microText
	props.fg = props.fg or "text3"
	props.Size = props.Size or UDim2.new(1, 0, 0, 14)
	return b.new("TextLabel", props)
end

function b.mono(props)
	props = props or {}
	props.Font = a.font.mono
	props.TextSize = props.TextSize or a.metric.blockText
	props.fg = props.fg or "text"
	return b.new("TextLabel", props)
end

--=============================================================================
-- rules and spacers
--
-- Hairlines carry the layout here; there are no card borders or shadows.
--=============================================================================

function b.rule(props)
	props = props or {}
	local vertical = props.vertical
	return b.new("Frame", {
		Size = vertical and UDim2.new(0, 1, 1, 0) or UDim2.new(1, 0, 0, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		bg = props.bg or "line",
		BackgroundTransparency = props.transparency or 0,
		Parent = props.parent,
		ZIndex = props.ZIndex,
	})
end

function b.spacer(size, order)
	return b.new("Frame", {
		Size = UDim2.new(1, 0, 0, size),
		LayoutOrder = order,
		BackgroundTransparency = 1,
	})
end

--=============================================================================
-- interaction
--=============================================================================

function b.hover(gui, onEnter, onLeave)
	gui.MouseEnter:Connect(function()
		if gui:GetAttribute("disabled") then return end
		onEnter()
	end)
	gui.MouseLeave:Connect(onLeave)
	return gui
end

-- Wires a button's fill to hover and press states derived from a base token.
-- Calling it again on the same button retunes it rather than stacking up a
-- second set of handlers.
local stateHandlers = setmetatable({}, { __mode = "k" })

function b.states(button, baseToken, hoverAmount)
	local state = stateHandlers[button]
	if state then
		state.token = baseToken
		state.amount = hoverAmount or 0.12
		state.paint(0)
		return button
	end

	state = { token = baseToken, amount = hoverAmount or 0.12 }
	function state.paint(mix)
		local base = type(state.token) == "function" and state.token() or a.c[state.token]
		if base then button.BackgroundColor3 = base:Lerp(a.c.accent, mix) end
	end
	stateHandlers[button] = state

	-- The canvas rebuilds its buttons on every render, so this listener has to
	-- go when the button does, or the theme's listener list grows without end.
	local unsubscribe = a.onChange(function() state.paint(0) end)
	button.Destroying:Connect(unsubscribe)
	b.hover(button, function() state.paint(state.amount) end, function() state.paint(0) end)
	button.MouseButton1Down:Connect(function() state.paint(state.amount + 0.1) end)
	button.MouseButton1Up:Connect(function() state.paint(state.amount) end)
	state.paint(0)
	return button
end

function b.button(props)
	props = props or {}
	local label = props.label
	local onClick = props.onClick
	local labelColor = props.labelColor
	local hoverAmount = props.hoverAmount
	props.label, props.onClick, props.labelColor, props.hoverAmount = nil, nil, nil, nil
	props.Size = props.Size or UDim2.new(0, 90, 0, 24)
	props.bg = props.bg or "raised"
	props.radius = props.radius ~= nil and props.radius or a.metric.radius

	local button = b.new("TextButton", props)
	local text = b.text({
		Text = label or "",
		Size = UDim2.new(1, 0, 1, 0),
		fg = labelColor or "text",
		Font = a.font.uiMedium,
		TextSize = a.metric.uiText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = button,
	})
	button:SetAttribute("label", label or "")
	b.states(button, props.bg, hoverAmount)
	if onClick then
		button.MouseButton1Click:Connect(function()
			if button:GetAttribute("disabled") then return end
			onClick()
		end)
	end
	return button, text
end

--=============================================================================
-- decoration
--=============================================================================

-- The small square letter that marks a block's category.
function b.chip(letter, color, size)
	size = size or 16
	local frame = b.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		radius = 2,
	})
	b.new("TextLabel", {
		Text = letter,
		Size = UDim2.fromScale(1, 1),
		Font = a.font.uiBold,
		TextSize = size - 6,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextTransparency = 0.05,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	return frame
end

-- A chevron drawn from two hairlines, so it never depends on a font having
-- the right glyph.
function b.chevron(size, token)
	local frame = b.new("Frame", { Size = UDim2.fromOffset(size + 2, size) })
	for _, side in ipairs({ -1, 1 }) do
		b.new("Frame", {
			Size = UDim2.fromOffset(size * 0.8, 1),
			Position = UDim2.fromOffset(size * 0.5 + side * size * 0.28, size * 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = side * 40,
			bg = token or "text3",
			Parent = frame,
		})
	end
	return frame
end

--=============================================================================
-- tooltips
--=============================================================================

local tooltip = nil
local tooltipToken = 0

local function ensureTooltip()
	if tooltip and tooltip.Parent then return tooltip end
	if not overlay then return nil end
	tooltip = b.new("Frame", {
		Visible = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		bg = "raised",
		stroke = { color = "line" },
		pad = { x = 8, y = 6 },
		ZIndex = 900,
		Parent = overlay,
	})
	local label = b.new("TextLabel", {
		Name = "Body",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		TextWrapped = true,
		fg = "text2",
		TextSize = a.metric.uiText,
		ZIndex = 901,
		Parent = tooltip,
	})
	b.new("UISizeConstraint", { MaxSize = Vector2.new(320, 400), Parent = label })
	return tooltip
end

-- `getText` may return a string or nil (to show nothing).
function b.tip(gui, getText)
	local myToken
	b.hover(gui, function()
		tooltipToken = tooltipToken + 1
		myToken = tooltipToken
		local token = myToken
		task.delay(0.45, function()
			if token ~= tooltipToken then return end
			local text = type(getText) == "function" and getText() or getText
			if not text or text == "" then return end
			local frame = ensureTooltip()
			if not frame then return end
			frame.Body.Text = text
			frame.Visible = true
			local mouse = overlay:FindFirstAncestorWhichIsA("PluginGui")
			local at = mouse and mouse:GetRelativeMousePosition() or Vector2.new(0, 0)
			local width = math.min(320, frame.AbsoluteSize.X)
			frame.Position = UDim2.fromOffset(
				math.max(8, math.min(at.X + 14, overlay.AbsoluteSize.X - width - 8)),
				at.Y + 20)
		end)
	end, function()
		tooltipToken = tooltipToken + 1
		if tooltip then tooltip.Visible = false end
	end)
	return gui
end

function b.hideTip()
	tooltipToken = tooltipToken + 1
	if tooltip then tooltip.Visible = false end
end

--=============================================================================
-- misc
--=============================================================================

function b.clear(gui)
	for _, child in ipairs(gui:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding")
			and not child:IsA("UICorner") and not child:IsA("UIStroke")
			and not child:IsA("UIGridLayout") and not child:IsA("UISizeConstraint")
			and not child:IsA("UIScale") then
			child:Destroy()
		end
	end
end

-- Keeps a scrolling frame's canvas the height of its list layout.
function b.autoCanvas(scroll, layout, extra)
	local function update()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + (extra or 8))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
	update()
	return update
end

function b.truncate(text, limit)
	if #text <= limit then return text end
	return string.sub(text, 1, limit - 1) .. "\u{2026}"
end

--=============================================================================
-- gestures
--
-- Studio does not route input that lands on a plugin widget through
-- UserInputService: that service only hears the game view.  Asking it whether
-- the mouse button is down therefore always answers "no" while the pointer is
-- over our window, which is enough to make every press-and-hold gesture in the
-- plugin do nothing at all.  The widget's own input events do fire, so the
-- button and key state we need is tracked from those instead.
--=============================================================================

local buttonsDown = {}
local keysDown = {}
local watched = setmetatable({}, { __mode = "k" })
local keyHandlers = {}

-- A press that is released off the edge of the widget never reports its
-- release, so anything still marked down when the window loses focus is
-- forgotten rather than left stuck.
local function forgetAll()
	table.clear(buttonsDown)
	table.clear(keysDown)
end

function b.watchInput(gui)
	if not gui or watched[gui] then return end
	watched[gui] = true

	gui.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			keysDown[input.KeyCode] = true
			for _, handler in ipairs(keyHandlers) do
				handler(input)
			end
		else
			buttonsDown[input.UserInputType] = true
		end
	end)
	gui.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			keysDown[input.KeyCode] = nil
		else
			buttonsDown[input.UserInputType] = nil
		end
	end)
	gui.WindowFocusReleased:Connect(forgetAll)
end

-- Called when a gesture starts from a control that swallowed the press before
-- the widget saw it, so the loop that follows knows the button is down.
function b.noteDown(inputType)
	buttonsDown[inputType] = true
end

function b.keyDown(keyCode)
	return keysDown[keyCode] == true
end

function b.onKey(handler)
	keyHandlers[#keyHandlers + 1] = handler
end

-- Whether the press that started a gesture is still going.  The InputObject
-- handed to InputBegan reaches the End state on release wherever the pointer
-- has wandered to, which makes it the more trustworthy half of this answer;
-- the tracked state covers gestures that were started without one.
function b.pressing(input, inputType)
	if input then
		if input.UserInputState == Enum.UserInputState.End then return false end
		if input.UserInputType then
			inputType = input.UserInputType
		end
	end
	return buttonsDown[inputType or Enum.UserInputType.MouseButton1] == true
end

function b.typing()
	return typingIn ~= nil and typingIn.Parent ~= nil
end

function b.forgetInput()
	forgetAll()
end

return b
