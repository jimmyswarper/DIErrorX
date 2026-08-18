--!nonstrict
-- DIErrorX  ·  block coding for Roblox Studio
--
-- Drag blocks, read the Luau they write, and take the script with you.
--
-- This file is only the doorway: it makes the toolbar button and the dock
-- widget, then hands over to the modules beside it.
--
--   a theme          b interface pieces   c block registry   d document model
--   e code writer    f lexer              g parser           h Luau importer
--   i IntelliSense   j tutorials          k tutorials tab    l palette
--   m canvas         n code and import    o state and saving p window
--
-- Start with `c` if you want to add a block, `h` if you want the converter to
-- recognise more Luau, and `j` to write a lesson.

local o = require(script.o)
local p = require(script.p)

local TITLE = "DIErrorX"

local toolbar = plugin:CreateToolbar(TITLE)
local button = toolbar:CreateButton(
	"Blocks",
	"Build Roblox scripts out of blocks, and read the Luau as you go",
	"")
button.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false, -- starts closed; the button opens it
	false,
	1240, 760, -- preferred size
	920, 520)  -- minimum size

local widget = plugin:CreateDockWidgetPluginGui("DIErrorXMain", widgetInfo)
widget.Title = TITLE .. " -- blocks in, Luau out"
widget.Name = "DIErrorX"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local app = nil

-- Building the window costs a moment, so it waits until the plugin is opened
-- for the first time rather than on every Studio launch.
local function ensureMounted()
	if app then return app end
	app = o.newApp(plugin, widget)
	p.mount(app, widget)
	return app
end

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	button:SetActive(widget.Enabled)
	if widget.Enabled then
		ensureMounted()
	elseif app and app.dirty then
		app:save()
	end
end)

if widget.Enabled then
	ensureMounted()
end

plugin.Unloading:Connect(function()
	if app and app.dirty then
		pcall(function() app:save() end)
	end
end)
