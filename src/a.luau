--!nonstrict
-- a  ·  theme
--
-- The look is borrowed from technical drafting rather than from other block
-- editors: ink-on-paper colours, hairline rules instead of borders and drop
-- shadows, sharp corners, a single ochre accent, and monospace for anything
-- that is really code.  Category colours are printing inks -- muted, so a
-- canvas full of blocks reads as a document rather than a bag of sweets.  Every
-- category has its own; they are close together on purpose, because the spine
-- is a reminder of which subject a block came from rather than a label.
--
-- Instances register the token they are painted with, so switching between the
-- ink and paper themes repaints the whole plugin without rebuilding it.

local a = {}

local INK = {
	name = "ink",
	bg = Color3.fromRGB(20, 22, 28),
	panel = Color3.fromRGB(25, 28, 36),
	raised = Color3.fromRGB(30, 34, 43),
	sunken = Color3.fromRGB(16, 19, 24),
	line = Color3.fromRGB(38, 43, 54),
	lineSoft = Color3.fromRGB(31, 36, 45),
	text = Color3.fromRGB(228, 226, 220),
	text2 = Color3.fromRGB(166, 167, 159),
	text3 = Color3.fromRGB(110, 113, 120),
	accent = Color3.fromRGB(217, 160, 91),
	accentInk = Color3.fromRGB(26, 18, 6),
	accentSoft = Color3.fromRGB(72, 56, 34),
	select = Color3.fromRGB(58, 65, 82),
	ok = Color3.fromRGB(127, 168, 106),
	warn = Color3.fromRGB(217, 160, 91),
	err = Color3.fromRGB(196, 97, 79),
	grid = Color3.fromRGB(27, 31, 39),
	gridMajor = Color3.fromRGB(35, 40, 51),
	field = Color3.fromRGB(16, 19, 24),
	fieldLine = Color3.fromRGB(51, 58, 71),
	shadow = Color3.fromRGB(0, 0, 0),
	cats = {
		events = Color3.fromRGB(194, 91, 78),
		control = Color3.fromRGB(209, 145, 60),
		logic = Color3.fromRGB(126, 155, 79),
		math = Color3.fromRGB(63, 143, 134),
		text = Color3.fromRGB(76, 130, 176),
		vars = Color3.fromRGB(122, 109, 184),
		funcs = Color3.fromRGB(178, 106, 160),
		inst = Color3.fromRGB(154, 139, 106),
		player = Color3.fromRGB(200, 110, 140),
		data = Color3.fromRGB(107, 122, 143),

		ui = Color3.fromRGB(70, 150, 165),
		camera = Color3.fromRGB(196, 168, 92),
		sound = Color3.fromRGB(160, 118, 196),
		save = Color3.fromRGB(96, 148, 112),
		net = Color3.fromRGB(86, 152, 190),
		shop = Color3.fromRGB(204, 128, 70),
		place = Color3.fromRGB(92, 160, 140),
		phys = Color3.fromRGB(198, 108, 84),
		anim = Color3.fromRGB(190, 100, 150),
		npc = Color3.fromRGB(150, 156, 88),
		terrain = Color3.fromRGB(160, 128, 92),
		algo = Color3.fromRGB(108, 122, 196),
		pattern = Color3.fromRGB(170, 112, 178),
		vec = Color3.fromRGB(98, 138, 186),
		debug = Color3.fromRGB(128, 146, 138),

		custom = Color3.fromRGB(196, 174, 120),
		special = Color3.fromRGB(120, 124, 132),
	},
	syntax = {
		kw = Color3.fromRGB(200, 141, 196),
		str = Color3.fromRGB(158, 183, 118),
		num = Color3.fromRGB(214, 165, 106),
		comment = Color3.fromRGB(104, 110, 122),
		name = Color3.fromRGB(214, 214, 208),
		call = Color3.fromRGB(120, 168, 204),
		sym = Color3.fromRGB(150, 154, 162),
	},
}

local PAPER = {
	name = "paper",
	bg = Color3.fromRGB(233, 229, 220),
	panel = Color3.fromRGB(243, 240, 233),
	raised = Color3.fromRGB(252, 250, 245),
	sunken = Color3.fromRGB(225, 220, 209),
	line = Color3.fromRGB(206, 199, 185),
	lineSoft = Color3.fromRGB(219, 213, 201),
	text = Color3.fromRGB(32, 34, 40),
	text2 = Color3.fromRGB(90, 93, 102),
	text3 = Color3.fromRGB(138, 141, 149),
	accent = Color3.fromRGB(166, 104, 31),
	accentInk = Color3.fromRGB(252, 248, 240),
	accentSoft = Color3.fromRGB(232, 214, 186),
	select = Color3.fromRGB(214, 206, 190),
	ok = Color3.fromRGB(86, 124, 66),
	warn = Color3.fromRGB(166, 104, 31),
	err = Color3.fromRGB(165, 62, 46),
	grid = Color3.fromRGB(224, 219, 208),
	gridMajor = Color3.fromRGB(210, 204, 190),
	field = Color3.fromRGB(252, 250, 245),
	fieldLine = Color3.fromRGB(199, 191, 176),
	shadow = Color3.fromRGB(120, 112, 96),
	cats = {
		events = Color3.fromRGB(160, 62, 50),
		control = Color3.fromRGB(163, 104, 30),
		logic = Color3.fromRGB(89, 115, 48),
		math = Color3.fromRGB(32, 106, 99),
		text = Color3.fromRGB(43, 93, 138),
		vars = Color3.fromRGB(86, 72, 150),
		funcs = Color3.fromRGB(140, 68, 122),
		inst = Color3.fromRGB(116, 100, 62),
		player = Color3.fromRGB(163, 68, 100),
		data = Color3.fromRGB(70, 86, 110),

		ui = Color3.fromRGB(40, 118, 132),
		camera = Color3.fromRGB(150, 122, 42),
		sound = Color3.fromRGB(118, 78, 158),
		save = Color3.fromRGB(58, 110, 76),
		net = Color3.fromRGB(48, 112, 150),
		shop = Color3.fromRGB(160, 90, 34),
		place = Color3.fromRGB(52, 120, 100),
		phys = Color3.fromRGB(162, 74, 50),
		anim = Color3.fromRGB(150, 62, 112),
		npc = Color3.fromRGB(108, 114, 48),
		terrain = Color3.fromRGB(120, 90, 56),
		algo = Color3.fromRGB(70, 84, 158),
		pattern = Color3.fromRGB(130, 74, 140),
		vec = Color3.fromRGB(60, 100, 148),
		debug = Color3.fromRGB(86, 104, 96),

		custom = Color3.fromRGB(140, 118, 62),
		special = Color3.fromRGB(96, 100, 108),
	},
	syntax = {
		kw = Color3.fromRGB(140, 58, 132),
		str = Color3.fromRGB(74, 106, 44),
		num = Color3.fromRGB(150, 92, 26),
		comment = Color3.fromRGB(140, 138, 130),
		name = Color3.fromRGB(38, 40, 46),
		call = Color3.fromRGB(38, 92, 132),
		sym = Color3.fromRGB(104, 106, 112),
	},
}

a.themes = { ink = INK, paper = PAPER }
a.c = INK

-- typography -------------------------------------------------------------------
a.font = {
	mono = Enum.Font.Code,
	ui = Enum.Font.Gotham,
	uiMedium = Enum.Font.GothamMedium,
	uiBold = Enum.Font.GothamBold,
}

-- Sizes are on a 4px grid; blocks are 26px tall so a stack lines up with the
-- canvas grid at 100% zoom.
a.metric = {
	unit = 4,
	radius = 2,
	topBar = 44,
	actionBar = 38,
	statusBar = 20,
	row = 26,
	rowGap = 2,
	indent = 18,
	spine = 3,
	panelPad = 12,
	fieldPad = 6,
	blockText = 13,
	uiText = 12,
	microText = 10,
}

--=============================================================================
-- binding
--=============================================================================

local bindings = setmetatable({}, { __mode = "k" })
local listeners = {}

local function resolve(token)
	if type(token) == "function" then return token(a.c) end
	local value = a.c[token]
	if value ~= nil then return value end
	local group, key = string.match(token, "^(%w+)%.(%w+)$")
	if group and a.c[group] then return a.c[group][key] end
	return Color3.fromRGB(255, 0, 255)
end

-- Paints a property now and again whenever the theme changes.
function a.bind(instance, property, token)
	local list = bindings[instance]
	if not list then
		list = {}
		bindings[instance] = list
	end
	list[#list + 1] = { property = property, token = token }
	instance[property] = resolve(token)
	return instance
end

function a.catColor(catId)
	return a.c.cats[catId] or a.c.text2
end

-- Exposed so tests can prove listeners are being released rather than piling up
-- as the canvas re-renders.
function a.listenerCount()
	return #listeners
end

function a.onChange(callback)
	listeners[#listeners + 1] = callback
	return function()
		for index, entry in ipairs(listeners) do
			if entry == callback then
				table.remove(listeners, index)
				return
			end
		end
	end
end

function a.setTheme(name)
	local theme = a.themes[name]
	if not theme or theme == a.c then return end
	a.c = theme
	for instance, list in pairs(bindings) do
		if instance.Parent or instance:IsA("ScreenGui") or instance:IsA("PluginGui") then
			for _, entry in ipairs(list) do
				pcall(function() instance[entry.property] = resolve(entry.token) end)
			end
		end
	end
	for _, callback in ipairs(listeners) do
		task.spawn(callback, theme)
	end
end

function a.toggleTheme()
	a.setTheme(a.c.name == "ink" and "paper" or "ink")
	return a.c.name
end

return a
