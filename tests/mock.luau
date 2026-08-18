-- A small Roblox stand-in, enough to mount the whole plugin headlessly under
-- the Luau CLI.  It is deliberately strict about property names: assigning a
-- property Roblox does not have raises, which turns the UI suite into a
-- spell-checker for every Instance the plugin builds.

--=============================================================================
-- value types
--=============================================================================

local Vector2mt = {}
Vector2mt.__index = function(self, key)
	if key == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y) end
	if key == "Unit" then
		local length = math.max(self.Magnitude, 1e-9)
		return Vector2.new(self.X / length, self.Y / length)
	end
	return rawget(Vector2mt, key)
end
Vector2mt.__add = function(x, y) return Vector2.new(x.X + y.X, x.Y + y.Y) end
Vector2mt.__sub = function(x, y) return Vector2.new(x.X - y.X, x.Y - y.Y) end
Vector2mt.__unm = function(v) return Vector2.new(-v.X, -v.Y) end
Vector2mt.__eq = function(x, y) return x.X == y.X and x.Y == y.Y end
Vector2mt.__tostring = function(v) return string.format("(%g, %g)", v.X, v.Y) end
Vector2mt.__mul = function(x, y)
	if type(y) == "number" then return Vector2.new(x.X * y, x.Y * y) end
	if type(x) == "number" then return Vector2.new(y.X * x, y.Y * x) end
	return Vector2.new(x.X * y.X, x.Y * y.Y)
end
Vector2mt.__div = function(x, y)
	if type(y) == "number" then return Vector2.new(x.X / y, x.Y / y) end
	return Vector2.new(x.X / y.X, x.Y / y.Y)
end

Vector2 = {}
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, Vector2mt)
end

local Color3mt = {}
Color3mt.__index = function(self, key)
	if key == "Lerp" then
		return function(from, to, alpha)
			return Color3.new(
				from.R + (to.R - from.R) * alpha,
				from.G + (to.G - from.G) * alpha,
				from.B + (to.B - from.B) * alpha)
		end
	end
	return nil
end
Color3mt.__eq = function(x, y) return x.R == y.R and x.G == y.G and x.B == y.B end

Color3 = {}
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3mt)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v) return Color3.new(h, s, v) end

UDim = {}
function UDim.new(scale, offset)
	return { Scale = scale or 0, Offset = offset or 0 }
end

UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }
end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end

local enumFamilies = {}
Enum = setmetatable({}, {
	__index = function(_, family)
		if not enumFamilies[family] then
			enumFamilies[family] = setmetatable({}, {
				__index = function(items, item)
					local value = { Name = item, EnumType = family, Value = 0 }
					rawset(items, item, value)
					return value
				end,
			})
		end
		return enumFamilies[family]
	end,
})

--=============================================================================
-- signals
--=============================================================================

local Signal = {}
Signal.__index = Signal

local function newSignal()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(handler)
	self.handlers[#self.handlers + 1] = handler
	local connection = { Connected = true }
	function connection:Disconnect()
		connection.Connected = false
		for index, entry in ipairs(self.handlers or {}) do
			if entry == handler then table.remove(self.handlers, index) return end
		end
	end
	connection.handlers = self.handlers
	return connection
end

Signal.Once = Signal.Connect

function Signal:Wait() return nil end

function Signal:Fire(...)
	for _, handler in ipairs(table.clone(self.handlers)) do
		local ok, err = pcall(handler, ...)
		if not ok then
			MOCK_ERRORS[#MOCK_ERRORS + 1] = tostring(err)
		end
	end
end

MOCK_ERRORS = {}

--=============================================================================
-- instances
--=============================================================================

local HIERARCHY = {
	Instance = nil,
	GuiBase2d = "Instance",
	GuiObject = "GuiBase2d",
	Frame = "GuiObject",
	ScrollingFrame = "GuiObject",
	TextLabel = "GuiObject",
	TextButton = "GuiObject",
	TextBox = "GuiObject",
	ImageLabel = "GuiObject",
	ImageButton = "GuiObject",
	UIComponent = "Instance",
	UIListLayout = "UIComponent",
	UIGridLayout = "UIComponent",
	UIPadding = "UIComponent",
	UICorner = "UIComponent",
	UIStroke = "UIComponent",
	UIScale = "UIComponent",
	UISizeConstraint = "UIComponent",
	LayerCollector = "GuiBase2d",
	PluginGui = "LayerCollector",
	DockWidgetPluginGui = "PluginGui",
	ScreenGui = "LayerCollector",
	Script = "Instance",
	LocalScript = "Instance",
	ModuleScript = "Instance",
	Folder = "Instance",
}

-- Properties the plugin is allowed to set.  Anything else is a typo.
local PROPERTIES = {}
for word in string.gmatch([[
	Name Parent Archivable ClassName
	Size Position AnchorPoint Rotation Visible ZIndex LayoutOrder
	BackgroundColor3 BackgroundTransparency BorderSizePixel BorderColor3
	ClipsDescendants AutomaticSize Active Selectable
	Text TextColor3 TextSize TextTransparency TextWrapped TextTruncate
	TextXAlignment TextYAlignment TextEditable TextScaled RichText LineHeight
	Font FontFace PlaceholderText PlaceholderColor3 ClearTextOnFocus MultiLine
	CursorPosition SelectionStart AutoButtonColor Image ImageColor3
	CanvasSize CanvasPosition ScrollBarThickness ScrollBarImageColor3
	ScrollBarImageTransparency AutomaticCanvasSize ScrollingDirection
	ElasticBehavior VerticalScrollBarInset
	FillDirection Padding SortOrder HorizontalAlignment VerticalAlignment
	CellSize CellPadding FillDirectionMaxCells StartCorner
	PaddingLeft PaddingRight PaddingTop PaddingBottom
	CornerRadius Thickness Color Transparency ApplyStrokeMode LineJoinMode
	Scale MinSize MaxSize
	Title Enabled ZIndexBehavior
	Source Disabled RunContext Value
]], "%S+") do
	PROPERTIES[word] = true
end

local READONLY = {
	AbsolutePosition = true, AbsoluteSize = true, AbsoluteContentSize = true,
	ClassName = true, AbsoluteRotation = true,
}

local EVENTS = {
	MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true,
	MouseButton2Click = true, MouseEnter = true, MouseLeave = true,
	InputBegan = true, InputEnded = true, InputChanged = true,
	Focused = true, FocusLost = true, Changed = true, Destroying = true,
	ChildAdded = true, ChildRemoved = true, Activated = true,
	WindowFocused = true, WindowFocusReleased = true, Click = true,
	Unloading = true, Heartbeat = true, RenderStepped = true,
}

-- Roblox hands back a value for every property whether or not it was set.
local DEFAULTS = {
	ZIndex = 1, LayoutOrder = 0, Visible = true, Rotation = 0,
	Text = "", TextTransparency = 0, BackgroundTransparency = 0,
	Transparency = 0, Thickness = 1, Scale = 1, CursorPosition = -1,
	SelectionStart = -1, TextSize = 14, BorderSizePixel = 1,
	Archivable = true, Enabled = false, Active = false,
}

local proxyData = setmetatable({}, { __mode = "k" })

local instanceMt = {}

local function isA(className, wanted)
	local current = className
	while current do
		if current == wanted then return true end
		current = HIERARCHY[current]
	end
	return false
end

local function fireChanged(self, property)
	local data = proxyData[self]
	local signal = data.propertySignals[property]
	if signal then signal:Fire() end
	data.events.Changed:Fire(property)
end

local METHODS = {}

function METHODS:IsA(wanted)
	return isA(proxyData[self].className, wanted)
end

function METHODS:GetChildren()
	return table.clone(proxyData[self].children)
end

function METHODS:GetDescendants()
	local out = {}
	local function walk(node)
		for _, child in ipairs(proxyData[node].children) do
			out[#out + 1] = child
			walk(child)
		end
	end
	walk(self)
	return out
end

function METHODS:FindFirstChild(name)
	for _, child in ipairs(proxyData[self].children) do
		if proxyData[child].properties.Name == name then return child end
	end
	return nil
end

function METHODS:FindFirstChildWhichIsA(className)
	for _, child in ipairs(proxyData[self].children) do
		if child:IsA(className) then return child end
	end
	return nil
end

METHODS.FindFirstChildOfClass = METHODS.FindFirstChildWhichIsA

function METHODS:FindFirstAncestorWhichIsA(className)
	local parent = proxyData[self].properties.Parent
	while parent do
		if parent:IsA(className) then return parent end
		parent = proxyData[parent].properties.Parent
	end
	return nil
end

function METHODS:GetPropertyChangedSignal(property)
	local data = proxyData[self]
	if not data.propertySignals[property] then
		data.propertySignals[property] = newSignal()
	end
	return data.propertySignals[property]
end

function METHODS:Destroy()
	local data = proxyData[self]
	data.events.Destroying:Fire()
	for _, child in ipairs(table.clone(data.children)) do
		child:Destroy()
	end
	self.Parent = nil
	data.destroyed = true
end

function METHODS:ClearAllChildren()
	for _, child in ipairs(table.clone(proxyData[self].children)) do
		child:Destroy()
	end
end

function METHODS:SetAttribute(name, value)
	proxyData[self].attributes[name] = value
end

function METHODS:GetAttribute(name)
	return proxyData[self].attributes[name]
end

function METHODS:CaptureFocus()
	proxyData[self].focused = true
	proxyData[self].events.Focused:Fire()
end

function METHODS:ReleaseFocus(enterPressed)
	proxyData[self].focused = false
	proxyData[self].events.FocusLost:Fire(enterPressed or false)
end

function METHODS:IsFocused()
	return proxyData[self].focused == true
end

function METHODS:GetRelativeMousePosition()
	return MOCK_MOUSE
end

function METHODS:IsDescendantOf(other)
	local parent = proxyData[self].properties.Parent
	while parent do
		if parent == other then return true end
		parent = proxyData[parent].properties.Parent
	end
	return false
end

MOCK_MOUSE = Vector2.new(0, 0)

instanceMt.__index = function(self, key)
	local data = proxyData[self]
	if METHODS[key] then return METHODS[key] end
	if data.events[key] then return data.events[key] end
	if EVENTS[key] then
		data.events[key] = newSignal()
		return data.events[key]
	end
	local value = data.properties[key]
	if value ~= nil then return value end
	if key == "ClassName" then return data.className end
	local default = DEFAULTS[key]
	if default ~= nil then return default end
	if key == "AbsolutePosition" or key == "AbsoluteSize"
		or key == "AbsoluteContentSize" then
		return data.absolute[key] or Vector2.new(0, 0)
	end
	-- reading a child by name, the way Roblox allows
	local child = METHODS.FindFirstChild(self, key)
	if child then return child end
	return nil
end

instanceMt.__newindex = function(self, key, value)
	local data = proxyData[self]
	if key == "Parent" then
		local old = data.properties.Parent
		if old then
			local siblings = proxyData[old].children
			for index, entry in ipairs(siblings) do
				if entry == self then
					table.remove(siblings, index)
					break
				end
			end
			proxyData[old].events.ChildRemoved:Fire(self)
		end
		data.properties.Parent = value
		if value then
			local siblings = proxyData[value].children
			siblings[#siblings + 1] = self
			proxyData[value].events.ChildAdded:Fire(self)
		end
		fireChanged(self, "Parent")
		return
	end

	if READONLY[key] then
		data.absolute[key] = value
		fireChanged(self, key)
		return
	end

	if not PROPERTIES[key] then
		error(string.format("%s has no property '%s'", data.className, tostring(key)), 2)
	end

	data.properties[key] = value
	if key == "Text" and data.focused then
		data.properties.CursorPosition = #tostring(value) + 1
	end
	fireChanged(self, key)
end

instanceMt.__tostring = function(self)
	return proxyData[self].properties.Name or proxyData[self].className
end

local function makeInstance(className, name)
	local proxy = newproxy(true)
	local meta = getmetatable(proxy)
	meta.__index = instanceMt.__index
	meta.__newindex = instanceMt.__newindex
	meta.__tostring = instanceMt.__tostring

	proxyData[proxy] = {
		className = className,
		properties = { Name = name or className, Parent = nil },
		children = {},
		attributes = {},
		absolute = {},
		propertySignals = {},
		events = setmetatable({}, {
			__index = function(events, key)
				if EVENTS[key] then
					local signal = newSignal()
					rawset(events, key, signal)
					return signal
				end
				return nil
			end,
		}),
	}
	-- events referenced eagerly by the plugin
	for _, event in ipairs({ "Changed", "Destroying", "ChildAdded", "ChildRemoved" }) do
		proxyData[proxy].events[event] = newSignal()
	end
	return proxy
end

Instance = {}
function Instance.new(className, parent)
	if not HIERARCHY[className] and className ~= "Instance" then
		HIERARCHY[className] = "Instance"
	end
	local made = makeInstance(className)
	if parent then made.Parent = parent end
	return made
end

MOCK = {}
MOCK.data = proxyData
MOCK.newSignal = newSignal

function MOCK.fire(instance, event, ...)
	local data = proxyData[instance]
	if not data then error("not a mock instance", 2) end
	if event == "Focused" and instance:IsA("TextBox") then
		data.focused = true
		data.properties.CursorPosition = #tostring(instance.Text) + 1
		MOCK_FOCUSED_BOX = instance
	elseif event == "FocusLost" and instance:IsA("TextBox") then
		data.focused = false
		if MOCK_FOCUSED_BOX == instance then MOCK_FOCUSED_BOX = nil end
	end
	local signal = data.events[event]
	if not signal then return false end
	signal:Fire(...)
	return true
end

function MOCK.className(instance)
	return proxyData[instance] and proxyData[instance].className or nil
end

function MOCK.setAbsolute(instance, position, size)
	proxyData[instance].absolute.AbsolutePosition = position
	proxyData[instance].absolute.AbsoluteSize = size
end

-- Every descendant, for assertions.
function MOCK.descendants(root)
	return root:GetDescendants()
end

function MOCK.findText(root, text)
	for _, node in ipairs(root:GetDescendants()) do
		local value = proxyData[node].properties.Text
		if value and string.find(tostring(value), text, 1, true) then return node end
	end
	return nil
end

function MOCK.countClass(root, className)
	local total = 0
	for _, node in ipairs(root:GetDescendants()) do
		if node:IsA(className) then total = total + 1 end
	end
	return total
end

--=============================================================================
-- task, services, plugin
--=============================================================================

local pending = {}

task = {
	spawn = function(callback, ...)
		local ok, err = pcall(callback, ...)
		if not ok then MOCK_ERRORS[#MOCK_ERRORS + 1] = tostring(err) end
	end,
	defer = function(callback, ...)
		pending[#pending + 1] = { callback = callback, args = table.pack(...) }
	end,
	delay = function(_, callback, ...)
		pending[#pending + 1] = { callback = callback, args = table.pack(...) }
	end,
	wait = function() return 0 end,
	cancel = function() end,
}

-- Runs whatever was deferred, the way a frame boundary would.
function MOCK.flush(rounds)
	for _ = 1, rounds or 3 do
		local queue = pending
		pending = {}
		for _, entry in ipairs(queue) do
			local ok, err = pcall(entry.callback, table.unpack(entry.args, 1, entry.args.n))
			if not ok then MOCK_ERRORS[#MOCK_ERRORS + 1] = tostring(err) end
		end
	end
end

function warn(...)
	local pieces = {}
	for index = 1, select("#", ...) do
		pieces[index] = tostring(select(index, ...))
	end
	MOCK_WARNINGS[#MOCK_WARNINGS + 1] = table.concat(pieces, " ")
end
MOCK_WARNINGS = {}

--=============================================================================
-- JSON, since HttpService does the real thing
--=============================================================================

local function encodeValue(value, out)
	local kind = type(value)
	if kind == "nil" then
		out[#out + 1] = "null"
	elseif kind == "boolean" then
		out[#out + 1] = tostring(value)
	elseif kind == "number" then
		out[#out + 1] = string.format("%.14g", value)
	elseif kind == "string" then
		local escaped = string.gsub(value, '[%c"\\]', function(ch)
			local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n",
				["\r"] = "\\r", ["\t"] = "\\t" }
			return map[ch] or string.format("\\u%04x", string.byte(ch))
		end)
		out[#out + 1] = '"' .. escaped .. '"'
	elseif kind == "table" then
		local isArray = true
		local count = 0
		for key in pairs(value) do
			count = count + 1
			if type(key) ~= "number" then isArray = false end
		end
		if count == 0 then
			out[#out + 1] = "[]"
		elseif isArray and count == #value then
			out[#out + 1] = "["
			for index, item in ipairs(value) do
				if index > 1 then out[#out + 1] = "," end
				encodeValue(item, out)
			end
			out[#out + 1] = "]"
		else
			out[#out + 1] = "{"
			local keys = {}
			for key in pairs(value) do keys[#keys + 1] = tostring(key) end
			table.sort(keys)
			for index, key in ipairs(keys) do
				if index > 1 then out[#out + 1] = "," end
				encodeValue(key, out)
				out[#out + 1] = ":"
				encodeValue(value[key] ~= nil and value[key] or value[tonumber(key)], out)
			end
			out[#out + 1] = "}"
		end
	else
		error("cannot encode " .. kind)
	end
end

local function decodeJson(text)
	local at = 1
	local function skip()
		while at <= #text and string.find(string.sub(text, at, at), "%s") do
			at = at + 1
		end
	end
	local parseValue

	local function parseString()
		at = at + 1
		local out = {}
		while at <= #text do
			local ch = string.sub(text, at, at)
			if ch == '"' then
				at = at + 1
				return table.concat(out)
			elseif ch == "\\" then
				local escape = string.sub(text, at + 1, at + 1)
				local map = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\",
					["/"] = "/", b = "\b", f = "\f" }
				if escape == "u" then
					local hex = string.sub(text, at + 2, at + 5)
					out[#out + 1] = string.char(tonumber(hex, 16) % 256)
					at = at + 6
				else
					out[#out + 1] = map[escape] or escape
					at = at + 2
				end
			else
				out[#out + 1] = ch
				at = at + 1
			end
		end
		error("unfinished string in json")
	end

	function parseValue()
		skip()
		local ch = string.sub(text, at, at)
		if ch == "{" then
			at = at + 1
			local out = {}
			skip()
			if string.sub(text, at, at) == "}" then at = at + 1 return out end
			while true do
				skip()
				local key = parseString()
				skip()
				at = at + 1 -- ':'
				out[key] = parseValue()
				skip()
				local sep = string.sub(text, at, at)
				at = at + 1
				if sep == "}" then return out end
			end
		elseif ch == "[" then
			at = at + 1
			local out = {}
			skip()
			if string.sub(text, at, at) == "]" then at = at + 1 return out end
			while true do
				out[#out + 1] = parseValue()
				skip()
				local sep = string.sub(text, at, at)
				at = at + 1
				if sep == "]" then return out end
			end
		elseif ch == '"' then
			return parseString()
		elseif string.sub(text, at, at + 3) == "true" then
			at = at + 4
			return true
		elseif string.sub(text, at, at + 4) == "false" then
			at = at + 5
			return false
		elseif string.sub(text, at, at + 3) == "null" then
			at = at + 4
			return nil
		else
			local number = string.match(text, "^-?%d+%.?%d*[eE]?[-+]?%d*", at)
			if not number then error("unexpected json at " .. at) end
			at = at + #number
			return tonumber(number)
		end
	end

	local value = parseValue()
	return value
end

--=============================================================================
-- services and the plugin object
--=============================================================================

local services = {}

local function service(name, members)
	local instance = makeInstance(name, name)
	for key, value in pairs(members or {}) do
		rawset(proxyData[instance], key, value)
	end
	services[name] = instance
	return instance
end

local HttpService = service("HttpService")
proxyData[HttpService].jsonEncode = true
METHODS.JSONEncode = function(_, value)
	local out = {}
	encodeValue(value, out)
	return table.concat(out)
end
METHODS.JSONDecode = function(_, text)
	return decodeJson(text)
end

local RunService = service("RunService")
service("ChangeHistoryService")
METHODS.TryBeginRecording = function() return "recording" end
METHODS.FinishRecording = function() return true end
METHODS.SetWaypoint = function() end

service("Selection")
METHODS.Set = function() end

local UserInputService = service("UserInputService")
METHODS.GetFocusedTextBox = function()
	return MOCK_FOCUSED_BOX
end
MOCK_FOCUSED_BOX = nil
METHODS.IsKeyDown = function(_, keyCode)
	return MOCK_KEYS[keyCode and keyCode.Name] == true
end
METHODS.IsMouseButtonPressed = function() return MOCK_MOUSE_DOWN end
MOCK_KEYS = {}
MOCK_MOUSE_DOWN = false

service("Players")
service("ServerScriptService")
service("ReplicatedStorage")
service("Workspace")
service("StarterGui")
service("TextService")
METHODS.GetTextSize = function(_, text, size)
	return Vector2.new(#tostring(text) * size * 0.55, size)
end

game = makeInstance("DataModel", "game")
METHODS.GetService = function(_, name)
	if not services[name] then service(name) end
	return services[name]
end
for name, instance in pairs(services) do
	instance.Parent = game
end
workspace = services.Workspace

DockWidgetPluginGuiInfo = {}
function DockWidgetPluginGuiInfo.new(...)
	return { args = table.pack(...) }
end

function MOCK.newPlugin()
	local pluginInstance = makeInstance("Plugin", "DIErrorX")
	local settings = {}
	local widgets = {}

	METHODS.CreateToolbar = function(_, name)
		local toolbar = makeInstance("PluginToolbar", name)
		METHODS.CreateButton = function(_, buttonName)
			local button = makeInstance("PluginToolbarButton", buttonName)
			METHODS.SetActive = function() end
			button.ClickableWhenViewportHidden = true
			return button
		end
		return toolbar
	end
	METHODS.CreateDockWidgetPluginGui = function(_, id)
		local widget = makeInstance("DockWidgetPluginGui", id)
		widget.Enabled = false
		widgets[id] = widget
		MOCK.setAbsolute(widget, Vector2.new(0, 0), Vector2.new(1240, 760))
		return widget
	end
	METHODS.GetSetting = function(_, key) return settings[key] end
	METHODS.SetSetting = function(_, key, value) settings[key] = value end

	MOCK.settings = settings
	return pluginInstance
end

PROPERTIES.ClickableWhenViewportHidden = true
