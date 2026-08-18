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
function b.states(button, baseToken, hoverAmount)
	local function paint(mix)
		local base = type(baseToken) == "function" and baseToken() or a.c[baseToken]
		button.BackgroundColor3 = base:Lerp(a.c.accent, mix)
	end
	local repaint = a.onChange(function() paint(0) end)
	button.Destroying:Connect(repaint)
	b.hover(button, function() paint(hoverAmount or 0.12) end, function() paint(0) end)
	button.MouseButton1Down:Connect(function() paint((hoverAmount or 0.12) + 0.1) end)
	button.MouseButton1Up:Connect(function() paint(hoverAmount or 0.12) end)
	paint(0)
	return button
end

function b.button(props)
	props = props or {}
	local label = props.label
	local onClick = props.onClick
	props.label, props.onClick = nil, nil
	props.Size = props.Size or UDim2.new(0, 90, 0, 24)
	props.bg = props.bg or "raised"
	props.radius = props.radius ~= nil and props.radius or a.metric.radius

	local button = b.new("TextButton", props)
	local text = b.text({
		Text = label or "",
		Size = UDim2.new(1, 0, 1, 0),
		fg = props.labelColor or "text",
		Font = a.font.uiMedium,
		TextSize = a.metric.uiText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = button,
	})
	button:SetAttribute("label", label or "")
	b.states(button, props.bg, props.hoverAmount)
	if onClick then
		button.MouseButton1Click:Connect(function()
			if button:GetAttribute("disabled") then return end
			onClick()
		end)
	end
	return button, text
end

-- A flat button that only shows its edges on hover -- used in dense toolbars.
function b.quiet(props)
	props = props or {}
	props.bg = "panel"
	props.hoverAmount = 0.18
	return b.button(props)
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

-- Hard-offset shadow, like a sheet of paper lifted off the table.  Used only
-- for things that are genuinely floating.
function b.lift(gui, distance)
	distance = distance or 3
	local shadow = b.new("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.fromOffset(distance, distance),
		bg = "shadow",
		BackgroundTransparency = 0.72,
		ZIndex = (gui.ZIndex or 1) - 1,
		radius = 0,
	})
	shadow.Parent = gui.Parent
	local function follow()
		shadow.Position = UDim2.new(
			gui.Position.X.Scale, gui.Position.X.Offset + distance,
			gui.Position.Y.Scale, gui.Position.Y.Offset + distance)
		shadow.Size = gui.Size
	end
	gui:GetPropertyChangedSignal("Position"):Connect(follow)
	gui:GetPropertyChangedSignal("Size"):Connect(follow)
	gui.Destroying:Connect(function() shadow:Destroy() end)
	follow()
	return shadow
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

return b
