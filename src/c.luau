--!nonstrict
-- c  ·  block registry
--
-- Every block is declared once, here, with two templates:
--
--   head = "change {var} by {n}"     -- what you read on the canvas
--   code = "{var} += {n}"            -- what it compiles to
--
-- Keeping both on the same line is the whole trick: the canvas and the emitted
-- Luau can never drift apart, and a new block is four lines rather than four
-- files.  `{name}` refers to a field declared in `fields`, written in the
-- shorthand  "kind|default|placeholder|options".
--
-- Field kinds: expr · name · str · num · choice · params · multiline
-- A field may carry a `hint` (after the kind, e.g. "str:class") which tells the
-- IntelliSense engine what sort of value belongs there.

local c = {}

--=============================================================================
-- categories
--=============================================================================

c.cats = {
	-- the ten fundamentals, one lesson each
	{ id = "events", name = "Events", glyph = "E", tier = "core",
	  blurb = "Code that waits for something to happen." },
	{ id = "control", name = "Control", glyph = "C", tier = "core",
	  blurb = "Choose what runs, and how many times." },
	{ id = "logic", name = "Logic", glyph = "?", tier = "core",
	  blurb = "Ask true-or-false questions about your world." },
	{ id = "math", name = "Math", glyph = "N", tier = "core",
	  blurb = "Numbers, randomness and measurement." },
	{ id = "text", name = "Text", glyph = "T", tier = "core",
	  blurb = "Build, cut and search strings." },
	{ id = "vars", name = "Variables", glyph = "x", tier = "core",
	  blurb = "Name a value so you can use it later." },
	{ id = "funcs", name = "Functions", glyph = "f", tier = "core",
	  blurb = "Package steps up and reuse them." },
	{ id = "inst", name = "Instances", glyph = "I", tier = "core",
	  blurb = "Make, change and delete objects in the game." },
	{ id = "player", name = "Players", glyph = "P", tier = "core",
	  blurb = "Characters, humanoids and leaderboards." },
	{ id = "data", name = "Data", glyph = "D", tier = "core",
	  blurb = "Lists and dictionaries that hold many values." },

	-- subsystems
	{ id = "ui", name = "Interface", glyph = "U", tier = "system",
	  blurb = "Screens, text, buttons and everything a player looks at." },
	{ id = "camera", name = "Camera & light", glyph = "K", tier = "system",
	  blurb = "Where the view is, and how the world is lit." },
	{ id = "sound", name = "Sound", glyph = "A", tier = "system",
	  blurb = "Music, effects, volume and where a sound comes from." },
	{ id = "save", name = "Saving", glyph = "S", tier = "system",
	  blurb = "Keeping a player's progress between visits." },
	{ id = "net", name = "Networking", glyph = "R", tier = "system",
	  blurb = "The server and the client talking to each other." },
	{ id = "shop", name = "Shop", glyph = "$", tier = "system",
	  blurb = "Passes, products, badges and what a player owns." },
	{ id = "place", name = "Places", glyph = "G", tier = "system",
	  blurb = "Sending players to other places and servers." },
	{ id = "phys", name = "Physics", glyph = "F", tier = "system",
	  blurb = "Forces, joints, collisions and rays." },
	{ id = "anim", name = "Animation", glyph = "M", tier = "system",
	  blurb = "Playing animations and driving humanoid states." },
	{ id = "npc", name = "NPCs", glyph = "W", tier = "system",
	  blurb = "Characters the computer walks around for you." },
	{ id = "terrain", name = "Terrain", glyph = "Y", tier = "system",
	  blurb = "Ground, water and building the world in code." },
	{ id = "algo", name = "Lists & sorting", glyph = "L", tier = "system",
	  blurb = "Doing something useful to every item at once." },
	{ id = "pattern", name = "Text patterns", glyph = "Q", tier = "system",
	  blurb = "Finding and reshaping text that follows a shape." },
	{ id = "vec", name = "Space & angles", glyph = "3", tier = "system",
	  blurb = "Directions, rotations and the maths of moving things." },
	{ id = "debug", name = "Debug & timing", glyph = "B", tier = "system",
	  blurb = "Finding out what is happening, and how often." },

	-- everything else
	{ id = "custom", name = "My blocks", glyph = "+", tier = "special",
	  blurb = "Blocks you made yourself, out of blocks or out of Luau." },
	{ id = "special", name = "Escape hatch", glyph = "*", tier = "special",
	  blurb = "Hand-written Luau and comments, for when blocks run out." },
}

c.catById = {}
for index, cat in ipairs(c.cats) do
	cat.index = index
	cat.tier = cat.tier or "system"
	cat.extra = cat.tier ~= "core"
	c.catById[cat.id] = cat
end

-- The ten categories that have a lesson of their own.
function c.coreCats()
	local list = {}
	for _, cat in ipairs(c.cats) do
		if cat.tier == "core" then list[#list + 1] = cat end
	end
	return list
end

--=============================================================================
-- template + field parsing
--=============================================================================

local FIELD_PATTERN = "{([%a_][%w_]*)}"

-- "set {a} to {b}"  ->  { {t="text",v="set "}, {t="field",k="a"}, ... }
local function parseTemplate(text)
	local parts = {}
	local i = 1
	while true do
		local a, b, key = string.find(text, FIELD_PATTERN, i)
		if not a then break end
		if a > i then
			parts[#parts + 1] = { t = "text", v = string.sub(text, i, a - 1) }
		end
		parts[#parts + 1] = { t = "field", k = key }
		i = b + 1
	end
	if i <= #text then
		parts[#parts + 1] = { t = "text", v = string.sub(text, i) }
	end
	return parts
end
c.parseTemplate = parseTemplate

local function split(text, sep)
	local out = {}
	local start = 1
	while true do
		local at = string.find(text, sep, start, true)
		if not at then
			out[#out + 1] = string.sub(text, start)
			return out
		end
		out[#out + 1] = string.sub(text, start, at - 1)
		start = at + #sep
	end
end

-- "choice|==|comparison|== ~= < > <= >="
local function parseField(key, spec)
	if type(spec) == "table" then
		spec.key = key
		return spec
	end
	local bits = split(spec, "|")
	local kindPart = bits[1] or "expr"
	local kind, hint = string.match(kindPart, "^(%w+):(%w+)$")
	kind = kind or kindPart
	local field = {
		key = key,
		kind = kind,
		hint = hint,
		default = bits[2] or "",
		placeholder = (bits[3] ~= "" and bits[3]) or key,
	}
	if bits[4] and bits[4] ~= "" then
		field.options = {}
		for option in string.gmatch(bits[4], "[^,]+") do
			field.options[#field.options + 1] = option
		end
	end
	return field
end

--=============================================================================
-- registration
--=============================================================================

c.defs = {}
c.order = {}

-- Value of a field on a block, falling back to the declared default.
function c.fieldValue(def, block, key)
	local raw = block.f and block.f[key]
	if raw == nil or raw == "" then
		local field = def.fields[key]
		return field and field.default or ""
	end
	return raw
end

-- Fills a template with a block's field values.
function c.fill(parts, def, block)
	local out = {}
	for _, part in ipairs(parts) do
		if part.t == "text" then
			out[#out + 1] = part.v
		else
			out[#out + 1] = c.fieldValue(def, block, part.k)
		end
	end
	return table.concat(out)
end


local function asLines(value)
	if value == nil then return nil end
	if type(value) == "string" then return { value } end
	return value
end

local function D(def)
	assert(def.id and not c.defs[def.id], "duplicate block id: " .. tostring(def.id))
	assert(c.catById[def.cat], "unknown category on " .. def.id)

	local fields = {}
	for key, spec in pairs(def.fields or {}) do
		fields[key] = parseField(key, spec)
	end
	def.fields = fields

	def.headLines = asLines(def.head) or { def.label or def.id }
	def.codeLines = asLines(def.code) or def.headLines
	def.tailLines = asLines(def.tail)
	def.codeTailLines = asLines(def.codeTail) or def.tailLines
	def.slots = def.slots or {}
	def.bodyIndent = def.bodyIndent or 1
	def.label = def.label or def.id
	-- Subgroup inside the category, so a category of seventy blocks reads as
	-- five short lists rather than one long one.
	def.group = def.group or "General"

	def.headTpl = {}
	for index, line in ipairs(def.headLines) do
		def.headTpl[index] = parseTemplate(line)
	end
	for _, slot in ipairs(def.slots) do
		if slot.pre then slot.preTpl = parseTemplate(slot.pre) end
		slot.codePre = slot.codePre or slot.pre
	end
	def.tailTpl = def.tailLines and parseTemplate(def.tailLines[1]) or nil

	-- Search text: label + templates + doc, lowercased once at load.
	def.searchText = string.lower(table.concat({
		def.label, def.id, def.cat, def.group,
		table.concat(def.headLines, " "),
		table.concat(def.codeLines, " "),
		def.doc or "", def.tags or "",
	}, " "))

	-- The exact Luau this block writes, with its defaults filled in.  Shown in
	-- every tooltip, so nothing about a block is hidden behind its wording.
	local sample = {}
	local blank = { f = {} }
	for _, line in ipairs(def.codeLines) do
		sample[#sample + 1] = (string.gsub(c.fill(parseTemplate(line), def, blank), "^\t", ""))
	end
	if #def.slots > 0 then sample[#sample + 1] = "\t..." end
	for _, line in ipairs(def.codeTailLines or {}) do
		sample[#sample + 1] = (string.gsub(c.fill(parseTemplate(line), def, blank), "^\t", ""))
	end
	def.sample = table.concat(sample, "\n")

	c.defs[def.id] = def
	c.order[#c.order + 1] = def
	return def
end

c.define = D

--=============================================================================
-- EVENTS
--=============================================================================

D{ id = "onTouch", cat = "events", label = "on touched",
	head = "when {part} is touched by {hit}",
	code = "{part}.Touched:Connect(function({hit})", tail = "end)",
	fields = { part = "expr|script.Parent|part", hit = "name|hit|hit" },
	slots = { { key = "body" } },
	doc = "Runs when any part bumps into this one. `hit` is the part that " ..
		"touched it -- its Parent is usually the character.",
	tags = "collide hit contact" }

D{ id = "onClick", cat = "events", label = "on clicked",
	head = "when {part} is clicked by {player}",
	code = '{part}:WaitForChild("ClickDetector").MouseClick:Connect(function({player})',
	tail = "end)",
	fields = { part = "expr|script.Parent|part", player = "name|player|player" },
	slots = { { key = "body" } },
	doc = "Needs a ClickDetector inside the part. Gives you the player who clicked.",
	tags = "mouse press button" }

D{ id = "onSignal", cat = "events", label = "on event",
	head = "when {sig} happens with {args}",
	code = "{sig}:Connect(function({args})", tail = "end)",
	fields = { sig = "expr|script.Parent.Changed|event", args = "params||arguments" },
	slots = { { key = "body" } },
	doc = "The general form: connect to any event in the game and run the " ..
		"blocks inside every time it fires.",
	tags = "connect listen signal" }

D{ id = "onSignalOnce", cat = "events", label = "on event, once",
	head = "the first time {sig} happens with {args}",
	code = "{sig}:Once(function({args})", tail = "end)",
	fields = { sig = "expr|script.Parent.Changed|event", args = "params||arguments" },
	slots = { { key = "body" } },
	doc = "Same as `on event`, but disconnects itself after the first fire.",
	tags = "connect once single" }

D{ id = "onPlayerAdded", cat = "events", label = "on player joined",
	head = "when {player} joins the game",
	code = "Players.PlayerAdded:Connect(function({player})", tail = "end)",
	fields = { player = "name|player|player" },
	slots = { { key = "body" } }, needs = { "Players" },
	doc = "Fires once per player, as they enter. Server scripts only.",
	tags = "join enter playeradded" }

D{ id = "onPlayerRemoving", cat = "events", label = "on player leaving",
	head = "when {player} leaves the game",
	code = "Players.PlayerRemoving:Connect(function({player})", tail = "end)",
	fields = { player = "name|player|player" },
	slots = { { key = "body" } }, needs = { "Players" },
	doc = "Your last chance to save that player's data before they are gone.",
	tags = "leave quit save" }

D{ id = "onCharacterAdded", cat = "events", label = "on character spawned",
	head = "when {player} spawns as {char}",
	code = "{player}.CharacterAdded:Connect(function({char})", tail = "end)",
	fields = { player = "expr|player|player", char = "name|char|character" },
	slots = { { key = "body" } },
	doc = "Runs on every spawn and respawn, not just the first one.",
	tags = "respawn character spawn" }

D{ id = "onDied", cat = "events", label = "on died",
	head = "when {hum} dies",
	code = "{hum}.Died:Connect(function()", tail = "end)",
	fields = { hum = "expr|humanoid|humanoid" },
	slots = { { key = "body" } },
	doc = "Fires when a Humanoid's health reaches zero.",
	tags = "death kill humanoid" }

D{ id = "onHeartbeat", cat = "events", label = "every frame",
	head = "every frame, {dt} seconds since the last one",
	code = "RunService.Heartbeat:Connect(function({dt})", tail = "end)",
	fields = { dt = "name|dt|delta" },
	slots = { { key = "body" } }, needs = { "RunService" },
	doc = "About 60 times a second. Multiply movement by `dt` so it feels the " ..
		"same on every machine.",
	tags = "loop update tick heartbeat" }

D{ id = "onRender", cat = "events", label = "every render frame",
	head = "every render frame, {dt} seconds since the last one",
	code = "RunService.RenderStepped:Connect(function({dt})", tail = "end)",
	fields = { dt = "name|dt|delta" },
	slots = { { key = "body" } }, needs = { "RunService" },
	doc = "Client only, and runs before the camera draws. Use it for camera " ..
		"work, nothing heavier.",
	tags = "render camera client" }

D{ id = "onKey", cat = "events", label = "on key pressed",
	head = "when the {key} key is pressed",
	code = {
		"UserInputService.InputBegan:Connect(function(input, typing)",
		"\tif typing then return end",
		"\tif input.KeyCode == Enum.KeyCode.{key} then",
	},
	codeTail = { "\tend", "end)" }, tail = "end",
	bodyIndent = 2,
	fields = { key = "choice:keycode|E|key|E,F,Q,R,T,Space,LeftShift,LeftControl,One,Two,Three,Four,Five" },
	slots = { { key = "body" } }, needs = { "UserInputService" },
	doc = "Client only. The `typing` guard stops your keybind firing while the " ..
		"player is using the chat box.",
	tags = "input keyboard press bind" }

D{ id = "onTagAdded", cat = "events", label = "on tagged instance",
	head = 'when an instance tagged "{tag}" appears as {inst}',
	code = 'CollectionService:GetInstanceAddedSignal("{tag}"):Connect(function({inst})',
	tail = "end)",
	fields = { tag = "str|Coin|tag", inst = "name|inst|instance" },
	slots = { { key = "body" } }, needs = { "CollectionService" },
	doc = "Tags let one script handle every coin, door or trap in the place at once.",
	tags = "collectionservice tag group" }

D{ id = "onPropertyChanged", cat = "events", label = "on property changed",
	head = "when {prop} of {obj} changes",
	code = '{obj}:GetPropertyChangedSignal("{prop}"):Connect(function()',
	tail = "end)",
	fields = { obj = "expr|script.Parent|object", prop = "str:prop|Value|property" },
	slots = { { key = "body" } },
	doc = "Watches one property only, which is far cheaper than watching Changed.",
	tags = "changed watch observe property" }

--=============================================================================
-- CONTROL
--=============================================================================

D{ id = "if", cat = "control", label = "if",
	head = "if {cond} then", tail = "end",
	fields = { cond = "expr|true|condition" },
	slots = { { key = "body" } },
	doc = "Runs the blocks inside only when the condition is true.",
	tags = "when condition branch" }

D{ id = "ifelse", cat = "control", label = "if / else",
	head = "if {cond} then", tail = "end",
	fields = { cond = "expr|true|condition" },
	slots = { { key = "body" }, { key = "els", pre = "otherwise", codePre = "else" } },
	elseifCollapse = true,
	doc = "Two paths, one of which always runs. Drop another if/else into the " ..
		"`otherwise` slot to build an elseif chain.",
	tags = "when condition branch otherwise" }

D{ id = "while", cat = "control", label = "while",
	head = "keep going while {cond}", code = "while {cond} do", tail = "end",
	fields = { cond = "expr|true|condition" },
	slots = { { key = "body" } },
	doc = "Repeats until the condition turns false. Always put a wait inside, " ..
		"or the script will freeze.",
	tags = "loop repeat until" }

D{ id = "repeat", cat = "control", label = "repeat until",
	head = "repeat", tail = "until {cond}",
	fields = { cond = "expr|false|condition" },
	slots = { { key = "body" } },
	doc = "Like `while`, but the body always runs at least once.",
	tags = "loop do until" }

D{ id = "repeatN", cat = "control", label = "repeat n times",
	head = "repeat {n} times", code = "for _ = 1, {n} do", tail = "end",
	fields = { n = "num|10|times" },
	slots = { { key = "body" } },
	doc = "A counted loop when you do not care about the counter's value.",
	tags = "loop for times" }

D{ id = "for", cat = "control", label = "count from / to",
	head = "count {var} from {from} to {to}", code = "for {var} = {from}, {to} do",
	tail = "end",
	fields = { var = "name|i|name", from = "num|1|from", to = "num|10|to" },
	slots = { { key = "body" } },
	doc = "Counts up one at a time, including both ends.",
	tags = "loop numeric for" }

D{ id = "forstep", cat = "control", label = "count by step",
	head = "count {var} from {from} to {to} by {step}",
	code = "for {var} = {from}, {to}, {step} do", tail = "end",
	fields = { var = "name|i|name", from = "num|10|from", to = "num|1|to",
		step = "num|-1|step" },
	slots = { { key = "body" } },
	doc = "A negative step counts down. Handy for countdowns.",
	tags = "loop step backwards countdown" }

D{ id = "foripairs", cat = "control", label = "for each item",
	head = "for each {i}, {v} in the list {tbl}",
	code = "for {i}, {v} in ipairs({tbl}) do", tail = "end",
	fields = { i = "name|i|index", v = "name|item|item", tbl = "expr|list|list" },
	slots = { { key = "body" } },
	doc = "Walks an array in order, 1 upward, stopping at the first gap.",
	tags = "loop array list iterate" }

D{ id = "forpairs", cat = "control", label = "for each key",
	head = "for each {k}, {v} in the table {tbl}",
	code = "for {k}, {v} in pairs({tbl}) do", tail = "end",
	fields = { k = "name|key|key", v = "name|value|value", tbl = "expr|data|table" },
	slots = { { key = "body" } },
	doc = "Walks every key of a dictionary. The order is not guaranteed.",
	tags = "loop dictionary keys iterate" }

D{ id = "forin", cat = "control", label = "for each, custom",
	head = "for each {names} from {iter}", code = "for {names} in {iter} do",
	tail = "end",
	fields = { names = "params|index, value|names", iter = "expr|pairs(data)|iterator" },
	slots = { { key = "body" } },
	doc = "The raw form of a for-each loop, for iterators that are not pairs " ..
		"or ipairs.",
	tags = "loop iterator generic for in" }

D{ id = "doblock", cat = "control", label = "do block",
	head = "as a group", code = "do", tail = "end",
	slots = { { key = "body" } },
	doc = "Groups blocks and keeps any variables made inside from leaking out.",
	tags = "scope group block" }

D{ id = "wait", cat = "control", label = "wait",
	head = "wait {n} seconds", code = "task.wait({n})",
	fields = { n = "num|1|seconds" },
	doc = "Pauses this script only. Everything else in the game keeps running.",
	tags = "delay sleep pause yield" }

D{ id = "spawn", cat = "control", label = "at the same time",
	head = "at the same time", code = "task.spawn(function()", tail = "end)",
	slots = { { key = "body" } },
	doc = "Starts the blocks inside on their own thread, so a wait in there " ..
		"will not hold up the rest of the script.",
	tags = "thread parallel async coroutine" }

D{ id = "delay", cat = "control", label = "after a delay",
	head = "after {n} seconds", code = "task.delay({n}, function()", tail = "end)",
	fields = { n = "num|3|seconds" },
	slots = { { key = "body" } },
	doc = "Schedules the blocks inside for later without pausing this script.",
	tags = "later timer schedule" }

D{ id = "break", cat = "control", label = "stop the loop",
	head = "stop the loop", code = "break",
	doc = "Leaves the loop it is inside immediately.",
	tags = "break exit loop" }

D{ id = "continue", cat = "control", label = "skip to next",
	head = "skip to the next turn", code = "continue",
	doc = "Abandons this pass of the loop and starts the next one.",
	tags = "continue next skip" }

--=============================================================================
-- LOGIC
--=============================================================================

D{ id = "ifCompare", cat = "logic", label = "if a ? b",
	head = "if {a} {op} {b} then", tail = "end",
	fields = { a = "expr|score|first", op = "choice|==|comparison|==,~=,<,>,<=,>=",
		b = "expr|10|second" },
	slots = { { key = "body" } },
	doc = "One block for all six comparisons. `~=` means 'is not equal to'.",
	tags = "compare equals greater less condition" }

D{ id = "ifBoth", cat = "logic", label = "if both",
	head = "if {a} and also {b} then", code = "if {a} and {b} then", tail = "end",
	fields = { a = "expr|ready|first", b = "expr|alive|second" },
	slots = { { key = "body" } },
	doc = "Needs both to be true. If the first is false the second is never " ..
		"even looked at, which is a cheap way to avoid nil errors.",
	tags = "and both condition" }

D{ id = "ifEither", cat = "logic", label = "if either",
	head = "if {a} or else {b} then", code = "if {a} or {b} then", tail = "end",
	fields = { a = "expr|ready|first", b = "expr|alive|second" },
	slots = { { key = "body" } },
	doc = "Runs when at least one side is true.",
	tags = "or either condition" }

D{ id = "ifNot", cat = "logic", label = "if not",
	head = "if {cond} is not true then", code = "if not {cond} then", tail = "end",
	fields = { cond = "expr|ready|condition" },
	slots = { { key = "body" } },
	doc = "Flips a condition. Reads best when the name is a question, like " ..
		"`isOpen`.",
	tags = "not invert negate" }

D{ id = "ifExists", cat = "logic", label = "if it exists",
	head = "if {value} exists then", code = "if {value} then", tail = "end",
	fields = { value = "expr|part|value" },
	slots = { { key = "body" } },
	doc = "In Luau only `nil` and `false` are falsy, so this is the standard " ..
		"nil check before touching an object.",
	tags = "nil exists check guard" }

D{ id = "guard", cat = "logic", label = "stop unless",
	head = "stop here unless {cond}", code = "if not {cond} then return end",
	fields = { cond = "expr|done|condition" },
	doc = "Leaves the function early when the condition fails. Guards at the " ..
		"top keep the rest of a function from drifting right.",
	tags = "guard early return bail" }

D{ id = "earlyReturnIf", cat = "logic", label = "leave if",
	head = "leave this function if {cond}", code = "if {cond} then return end",
	fields = { cond = "expr|ready|condition" },
	doc = "A one-line exit. Reads well at the very top of a function, where you " ..
		"are ruling cases out.",
	tags = "return early exit guard if" }

D{ id = "assert", cat = "logic", label = "insist",
	head = 'insist that {cond}, or complain "{msg}"',
	code = 'assert({cond}, "{msg}")',
	fields = { cond = "expr|part ~= nil|condition", msg = "str|that should never happen|message" },
	doc = "Stops the script with your message when the condition is false. " ..
		"Use it for mistakes you want to hear about loudly.",
	tags = "assert error check" }

D{ id = "ifIsA", cat = "logic", label = "if it is a",
	head = "if {inst} is a {class} then", code = 'if {inst}:IsA("{class}") then',
	tail = "end",
	fields = { inst = "expr|part|instance", class = "str:class|BasePart|class" },
	slots = { { key = "body" } },
	doc = "Checks an object's class, including inherited ones -- a Part counts " ..
		"as a BasePart.",
	tags = "isa class type instance" }

D{ id = "ifType", cat = "logic", label = "if type is",
	head = "if {value} is a {type} then", code = 'if typeof({value}) == "{type}" then',
	tail = "end",
	fields = { value = "expr|value|value",
		type = "choice|string|type|string,number,boolean,table,function,Instance,Vector3,CFrame,Color3" },
	slots = { { key = "body" } },
	doc = "`typeof` knows Roblox types too, which plain `type` does not.",
	tags = "typeof kind check" }

D{ id = "ifHasTag", cat = "logic", label = "if tagged",
	head = 'if {inst} is tagged "{tag}" then',
	code = 'if CollectionService:HasTag({inst}, "{tag}") then', tail = "end",
	fields = { inst = "expr|part|instance", tag = "str|Coin|tag" },
	slots = { { key = "body" } }, needs = { "CollectionService" },
	doc = "Ask whether an object carries a tag before acting on it.",
	tags = "tag collectionservice check" }

D{ id = "flip", cat = "logic", label = "flip",
	head = "flip {var}", code = "{var} = not {var}",
	fields = { var = "expr|isOpen|variable" },
	doc = "Turns true into false and back. A one-block toggle.",
	tags = "toggle not boolean switch" }

--=============================================================================
-- MATH
--=============================================================================

D{ id = "changeBy", cat = "math", label = "change by",
	head = "change {var} by {n}", code = "{var} += {n}",
	fields = { var = "expr|score|variable", n = "expr|1|amount" },
	doc = "Adds to whatever is already there. A negative amount subtracts.",
	tags = "add increment plus score" }

D{ id = "mathOp", cat = "math", label = "arithmetic",
	head = "set {var} to {a} {op} {b}", code = "{var} = {a} {op} {b}",
	fields = { var = "expr|result|variable", a = "expr|1|first",
		op = "choice|+|operator|+,-,*,/,//,%,^", b = "expr|1|second" },
	doc = "`//` divides and throws away the remainder; `%` keeps only the " ..
		"remainder; `^` is a power.",
	tags = "add subtract multiply divide modulo power" }

D{ id = "clamp", cat = "math", label = "clamp",
	head = "set {var} to {value} kept between {min} and {max}",
	code = "{var} = math.clamp({value}, {min}, {max})",
	fields = { var = "expr|health|variable", value = "expr|health|value",
		min = "expr|0|min", max = "expr|100|max" },
	doc = "Pins a number inside a range. The usual cure for health bars that " ..
		"go past 100.",
	tags = "clamp limit range min max" }

D{ id = "randomInt", cat = "math", label = "random whole number",
	head = "set {var} to a random whole number from {min} to {max}",
	code = "{var} = math.random({min}, {max})",
	fields = { var = "expr|roll|variable", min = "num|1|min", max = "num|6|max" },
	doc = "Both ends can come up. `math.random(1, 6)` really is a dice roll.",
	tags = "random dice chance number" }

D{ id = "randomFloat", cat = "math", label = "random decimal",
	head = "set {var} to a random decimal from {min} to {max}",
	code = "{var} = {min} + math.random() * ({max} - {min})",
	fields = { var = "expr|amount|variable", min = "num|0|min", max = "num|1|max" },
	doc = "For smooth values -- speeds, sizes, wait times.",
	tags = "random float decimal range" }

D{ id = "roundTo", cat = "math", label = "round",
	head = "set {var} to {value} {mode}",
	code = "{var} = math.{mode}({value})",
	fields = { var = "expr|n|variable", value = "expr|n|value",
		mode = "choice|round|mode|round,floor,ceil,abs,sqrt,sign" },
	doc = "`floor` always goes down, `ceil` always goes up, `round` goes to " ..
		"the nearest.",
	tags = "round floor ceil abs sqrt sign" }

D{ id = "minmax", cat = "math", label = "smallest / largest",
	head = "set {var} to the {mode} of {a} and {b}",
	code = "{var} = math.{mode}({a}, {b})",
	fields = { var = "expr|n|variable", mode = "choice|min|mode|min,max",
		a = "expr|a|first", b = "expr|b|second" },
	doc = "Picks one of two numbers without an if block.",
	tags = "min max smallest largest" }

D{ id = "lerp", cat = "math", label = "blend",
	head = "set {var} to {a} blended toward {b} by {t}",
	code = "{var} = {a} + ({b} - {a}) * {t}",
	fields = { var = "expr|value|variable", a = "expr|0|from", b = "expr|1|to",
		t = "expr|0.5|amount" },
	doc = "An amount of 0 gives the first number, 1 gives the second, 0.5 the " ..
		"midpoint. This is how smooth motion is built.",
	tags = "lerp interpolate blend smooth ease" }

D{ id = "vector3", cat = "math", label = "position value",
	head = "set {var} to the position ({x}, {y}, {z})",
	code = "{var} = Vector3.new({x}, {y}, {z})",
	fields = { var = "expr|spot|variable", x = "expr|0|x", y = "expr|10|y",
		z = "expr|0|z" },
	doc = "In Roblox, Y is up. Positions, sizes and directions are all Vector3.",
	tags = "vector3 position point coordinates" }

D{ id = "distance", cat = "math", label = "distance between",
	head = "set {var} to the distance from {a} to {b}",
	code = "{var} = ({a} - {b}).Magnitude",
	fields = { var = "expr|dist|variable", a = "expr|part.Position|first position",
		b = "expr|target.Position|second position" },
	doc = "Subtracting two positions gives the arrow between them; `.Magnitude` " ..
		"is its length in studs.",
	tags = "distance magnitude range near" }

D{ id = "clockNow", cat = "math", label = "clock",
	head = "set {var} to the clock time", code = "{var} = os.clock()",
	fields = { var = "expr|now|variable" },
	doc = "Seconds since the game started, as a decimal. Subtract two readings " ..
		"to time something.",
	tags = "time clock stopwatch cooldown" }

--=============================================================================
-- TEXT
--=============================================================================

D{ id = "printValue", cat = "text", label = "print",
	head = "print {value}", code = "print({value})",
	fields = { value = "expr|\"hello\"|value" },
	doc = "Writes to the Output window. The single most useful debugging block " ..
		"there is.",
	tags = "print output debug log" }

D{ id = "printText", cat = "text", label = "print words",
	head = 'print "{msg}"', code = 'print("{msg}")',
	fields = { msg = "str|hello world|message" },
	doc = "Prints plain words, no quotes needed in the field.",
	tags = "print message output" }

D{ id = "warnText", cat = "text", label = "warn",
	head = 'warn "{msg}"', code = 'warn("{msg}")',
	fields = { msg = "str|something looks wrong|message" },
	doc = "Like print, but orange in the Output window and easier to spot.",
	tags = "warn output orange debug" }

D{ id = "joinText", cat = "text", label = "join",
	head = "set {var} to {a} joined with {b}", code = "{var} = {a} .. {b}",
	fields = { var = "expr|message|variable", a = "expr|\"score: \"|first", b = "expr|score|second" },
	doc = "`..` glues strings together. Numbers join fine; other values need " ..
		"`tostring` first.",
	tags = "concat join glue string" }

D{ id = "formatText", cat = "text", label = "format",
	head = 'set {var} to "{fmt}" filled with {args}',
	code = '{var} = string.format("{fmt}", {args})',
	fields = { var = "expr|label|variable", fmt = "str|Score: %d|format",
		args = "expr|score|values" },
	doc = "`%d` takes a whole number, `%s` a string, `%.1f` a decimal with one " ..
		"place. Cleaner than a pile of `..`.",
	tags = "format string printf number" }

D{ id = "caseText", cat = "text", label = "change case",
	head = "set {var} to {value} in {mode}",
	code = "{var} = string.{mode}({value})",
	fields = { var = "expr|text|variable", value = "expr|text|text",
		mode = "choice|upper|case|upper,lower,reverse" },
	doc = "Handy for comparing player input without worrying about capitals.",
	tags = "upper lower case string" }

D{ id = "subText", cat = "text", label = "part of text",
	head = "set {var} to letters {from} to {to} of {value}",
	code = "{var} = string.sub({value}, {from}, {to})",
	fields = { var = "expr|piece|variable", value = "expr|text|text", from = "num|1|from",
		to = "num|5|to" },
	doc = "Counting starts at 1, and -1 means 'the last letter'.",
	tags = "substring slice cut string" }

D{ id = "splitText", cat = "text", label = "split",
	head = 'set {var} to {value} split by "{sep}"',
	code = '{var} = string.split({value}, "{sep}")',
	fields = { var = "expr|parts|variable", value = "expr|text|text", sep = "str|,|separator" },
	doc = "Turns one string into a list of pieces.",
	tags = "split separate list string" }

D{ id = "lenText", cat = "text", label = "length of",
	head = "set {var} to the length of {value}", code = "{var} = #{value}",
	fields = { var = "expr|count|variable", value = "expr|text|text or list" },
	doc = "`#` counts letters in a string, or items in a list.",
	tags = "length count size hash" }

D{ id = "containsText", cat = "text", label = "if it contains",
	head = 'if {value} contains "{needle}" then',
	code = 'if string.find({value}, "{needle}", 1, true) then', tail = "end",
	fields = { value = "expr|text|text", needle = "str|hello|search for" },
	slots = { { key = "body" } },
	doc = "The `true` at the end means a plain search, so punctuation in your " ..
		"search text behaves normally.",
	tags = "find contains search string" }

D{ id = "replaceText", cat = "text", label = "replace",
	head = 'set {var} to {value} with "{a}" replaced by "{b}"',
	code = '{var} = string.gsub({value}, "{a}", "{b}")',
	fields = { var = "expr|text|variable", value = "expr|text|text", a = "str|old|find",
		b = "str|new|replace with" },
	doc = "Replaces every match it finds.",
	tags = "replace gsub substitute string" }

D{ id = "toNumber", cat = "text", label = "text to number",
	head = "set {var} to {value} as a number", code = "{var} = tonumber({value})",
	fields = { var = "expr|n|variable", value = "expr|text|text" },
	doc = "Gives back `nil` when the text is not a number, so check it before " ..
		"you use it.",
	tags = "tonumber parse convert" }

D{ id = "toText", cat = "text", label = "value to text",
	head = "set {var} to {value} as text", code = "{var} = tostring({value})",
	fields = { var = "expr|text|variable", value = "expr|value|value" },
	doc = "Makes anything printable or joinable.",
	tags = "tostring convert string" }

--=============================================================================
-- VARIABLES
--=============================================================================

D{ id = "local", cat = "vars", label = "make",
	head = "make {name} = {value}", code = "local {name} = {value}",
	fields = { name = "name|value|name", value = "expr|0|value" },
	doc = "Creates a new name that only exists inside the block it is written " ..
		"in. Start here for almost every value you need.",
	tags = "local variable declare make new" }

D{ id = "localTyped", cat = "vars", label = "make, typed",
	head = "make {name} (a {type}) = {value}",
	code = "local {name}: {type} = {value}",
	fields = { name = "name|value|name", type = "str:type|number|type",
		value = "expr|0|value" },
	doc = "The same as `make`, but you say what kind of value it holds so " ..
		"Studio can warn you when something else sneaks in.",
	tags = "local typed annotation declare" }

D{ id = "set", cat = "vars", label = "set",
	head = "set {name} to {value}", code = "{name} = {value}",
	fields = { name = "expr|value|name", value = "expr|0|value" },
	doc = "Changes a name that already exists. Use `make` the first time, " ..
		"`set` every time after.",
	tags = "assign set change variable" }

D{ id = "setMany", cat = "vars", label = "make several",
	head = "make {names} = {values}", code = "local {names} = {values}",
	fields = { names = "params|a, b|names", values = "expr|1, 2|values" },
	doc = "Takes several names at once, which is how you catch a function that " ..
		"returns more than one value.",
	tags = "multiple local tuple" }

D{ id = "svc", cat = "vars", label = "use service",
	head = "use the {name} service", code = 'local {name} = game:GetService("{name}")',
	fields = { name = "choice:service|Players|service|Players,RunService,ReplicatedStorage,ServerStorage,ServerScriptService,TweenService,UserInputService,CollectionService,Debris,SoundService,Lighting,PathfindingService,MarketplaceService,DataStoreService,TeleportService,HttpService,Workspace" },
	doc = "The proper way to reach a Roblox service. The name becomes a " ..
		"variable you can use anywhere below.",
	tags = "getservice service players replicatedstorage" }

D{ id = "scriptParent", cat = "vars", label = "this script's object",
	head = "make {name} = the object this script is in",
	code = "local {name} = script.Parent",
	fields = { name = "name|part|name" },
	doc = "A script inside a part reaches that part with `script.Parent`.",
	tags = "script parent self part" }

D{ id = "clearVar", cat = "vars", label = "forget",
	head = "forget {name}", code = "{name} = nil",
	fields = { name = "expr|value|name" },
	doc = "Sets a name back to nothing. Also how you drop a key from a table.",
	tags = "nil clear delete unset" }

D{ id = "setAttr", cat = "vars", label = "set attribute",
	head = 'set attribute "{attr}" of {inst} to {value}',
	code = '{inst}:SetAttribute("{attr}", {value})',
	fields = { inst = "expr|script.Parent|instance", attr = "str|Speed|attribute",
		value = "expr|16|value" },
	doc = "Attributes are custom properties that live on the object itself, " ..
		"visible in the Properties window and shared with every script.",
	tags = "attribute setattribute custom property" }

D{ id = "getAttr", cat = "vars", label = "get attribute",
	head = 'make {name} = attribute "{attr}" of {inst}',
	code = 'local {name} = {inst}:GetAttribute("{attr}")',
	fields = { name = "name|speed|name", inst = "expr|script.Parent|instance",
		attr = "str|Speed|attribute" },
	doc = "Reads an attribute back. Gives `nil` when it was never set.",
	tags = "attribute getattribute read" }

D{ id = "onAttrChanged", cat = "vars", label = "on attribute changed",
	head = 'when attribute "{attr}" of {inst} changes',
	code = '{inst}:GetAttributeChangedSignal("{attr}"):Connect(function()',
	tail = "end)",
	fields = { inst = "expr|script.Parent|instance", attr = "str|Speed|attribute" },
	slots = { { key = "body" } },
	doc = "Reacts the moment an attribute is edited, by a script or by you in " ..
		"the Properties window.",
	tags = "attribute changed watch" }

--=============================================================================
-- FUNCTIONS
--=============================================================================

D{ id = "def", cat = "funcs", label = "define",
	head = "to {name} with {params}:", code = "local function {name}({params})",
	tail = "end",
	fields = { name = "name|doThing|name", params = "params||inputs" },
	slots = { { key = "body" } },
	doc = "Names a set of steps so you can run them from anywhere. Define it " ..
		"above the first place you use it.",
	tags = "function define declare local" }

D{ id = "defMethod", cat = "funcs", label = "define method",
	head = "to {name} of {obj} with {params}:",
	code = "function {obj}:{name}({params})", tail = "end",
	fields = { obj = "expr|Module|object", name = "name|doThing|name",
		params = "params||inputs" },
	slots = { { key = "body" } },
	doc = "A function attached to a table. Inside it, `self` is the table it " ..
		"was called on.",
	tags = "method self oop module" }

D{ id = "call", cat = "funcs", label = "run",
	head = "run {name} with {args}", code = "{name}({args})",
	fields = { name = "expr|doThing|name", args = "expr||inputs" },
	doc = "Runs a function you defined and throws the result away.",
	tags = "call run invoke function" }

D{ id = "callSave", cat = "funcs", label = "run and keep",
	head = "make {var} = {name} run with {args}", code = "local {var} = {name}({args})",
	fields = { var = "name|result|name", name = "expr|doThing|function",
		args = "expr||inputs" },
	doc = "Runs a function and keeps what it hands back.",
	tags = "call result return capture" }

D{ id = "return", cat = "funcs", label = "give back",
	head = "give back {value}", code = "return {value}",
	fields = { value = "expr|result|value" },
	doc = "Hands a value to whoever called this function and leaves it " ..
		"immediately.",
	tags = "return result give output" }

D{ id = "returnNone", cat = "funcs", label = "leave now",
	head = "leave this function", code = "return",
	doc = "Stops the function early without giving anything back.",
	tags = "return exit early leave" }

D{ id = "pcall", cat = "funcs", label = "try safely",
	head = "try, and put the outcome in {ok} and {err}:",
	code = "local {ok}, {err} = pcall(function()", tail = "end)",
	fields = { ok = "name|ok|ok", err = "name|err|error" },
	slots = { { key = "body" } },
	doc = "Runs risky work -- data stores, HTTP, anything that touches the " ..
		"outside world -- without letting an error kill the whole script.",
	tags = "pcall error protect try catch safe" }

D{ id = "require", cat = "funcs", label = "use module",
	head = "make {name} = the module {path}", code = "local {name} = require({path})",
	fields = { name = "name|Module|name",
		path = "expr|game.ReplicatedStorage.Module|path" },
	doc = "Loads a ModuleScript and gives you whatever it returns. Loaded once " ..
		"and shared from then on.",
	tags = "require module import load" }

D{ id = "disconnect", cat = "funcs", label = "stop listening",
	head = "stop listening with {conn}", code = "{conn}:Disconnect()",
	fields = { conn = "expr|connection|connection" },
	doc = "Ends a connection you saved earlier. Forgetting this is the most " ..
		"common cause of a slow game.",
	tags = "disconnect connection cleanup memory" }

D{ id = "moduleStart", cat = "funcs", label = "module table",
	head = "start a module called {name}", code = "local {name} = {}",
	fields = { name = "name|Module|name" },
	doc = "The first line of nearly every ModuleScript. Pair it with `give " ..
		"back {name}` at the very bottom.",
	tags = "module table start pattern" }

--=============================================================================
-- INSTANCES
--=============================================================================

D{ id = "create", cat = "inst", label = "make a new",
	head = "make {name} = a new {class}",
	code = 'local {name} = Instance.new("{class}")',
	fields = { name = "name|part|name",
		class = "choice:class|Part|class|Part,WedgePart,SpawnLocation,Model,Folder,Attachment,ClickDetector,ProximityPrompt,Sound,PointLight,SurfaceGui,BillboardGui,TextLabel,IntValue,StringValue,BoolValue,ObjectValue,Highlight,ParticleEmitter,Beam,Humanoid,Tool" },
	doc = "Builds an object in memory. It appears in the game only once you " ..
		"give it a parent.",
	tags = "instance new create spawn object" }

D{ id = "setProp", cat = "inst", label = "set property",
	head = "set {prop} of {obj} to {value}", code = "{obj}.{prop} = {value}",
	fields = { obj = "expr|part|object", prop = "str:prop|Transparency|property",
		value = "expr|0.5|value" },
	doc = "Changes any property you can see in the Properties window.",
	tags = "property set change transparency color" }

D{ id = "setParent", cat = "inst", label = "put inside",
	head = "put {obj} inside {parent}", code = "{obj}.Parent = {parent}",
	fields = { obj = "expr|part|object", parent = "expr|workspace|parent" },
	doc = "Setting the parent is what actually puts an object into the game. " ..
		"Do it last, after the other properties are set.",
	tags = "parent workspace add attach" }

D{ id = "destroy", cat = "inst", label = "remove",
	head = "remove {obj}", code = "{obj}:Destroy()",
	fields = { obj = "expr|part|object" },
	doc = "Deletes the object and everything inside it, for good.",
	tags = "destroy delete remove kill" }

D{ id = "clone", cat = "inst", label = "copy",
	head = "make {name} = a copy of {obj}", code = "local {name} = {obj}:Clone()",
	fields = { name = "name|copy|name", obj = "expr|template|object" },
	doc = "Copies an object and everything inside it. The copy has no parent " ..
		"until you give it one.",
	tags = "clone copy duplicate template" }

D{ id = "findChild", cat = "inst", label = "find child",
	head = 'make {name} = the child "{child}" of {obj}',
	code = 'local {name} = {obj}:FindFirstChild("{child}")',
	fields = { name = "name|found|name", obj = "expr|workspace|parent",
		child = "str|Part|child name" },
	doc = "Gives `nil` when there is no such child, so check it before using it.",
	tags = "find child search nil" }

D{ id = "waitChild", cat = "inst", label = "wait for child",
	head = 'make {name} = the child "{child}" of {obj}, once it exists',
	code = 'local {name} = {obj}:WaitForChild("{child}")',
	fields = { name = "name|found|name", obj = "expr|script.Parent|parent",
		child = "str|Humanoid|child name" },
	doc = "Pauses until the child turns up. The right choice in LocalScripts, " ..
		"where things stream in late.",
	tags = "waitforchild yield client load" }

D{ id = "moveTo", cat = "inst", label = "move to",
	head = "move {obj} to ({x}, {y}, {z})",
	code = "{obj}.Position = Vector3.new({x}, {y}, {z})",
	fields = { obj = "expr|part|object", x = "expr|0|x", y = "expr|10|y",
		z = "expr|0|z" },
	doc = "Teleports a single part. For a model or character use `place` instead.",
	tags = "position move teleport vector3" }

D{ id = "pivotTo", cat = "inst", label = "place model",
	head = "place {obj} at {cf}", code = "{obj}:PivotTo({cf})",
	fields = { obj = "expr|model|model", cf = "expr|CFrame.new(0, 10, 0)|cframe" },
	doc = "Moves a whole model or character in one go, keeping its parts " ..
		"together.",
	tags = "pivot cframe model move teleport" }

D{ id = "paint", cat = "inst", label = "paint",
	head = "paint {obj} red {r} green {g} blue {b}",
	code = "{obj}.Color = Color3.fromRGB({r}, {g}, {b})",
	fields = { obj = "expr|part|object", r = "num|255|red", g = "num|170|green",
		b = "num|60|blue" },
	doc = "Each channel runs 0 to 255, the same numbers the colour picker shows.",
	tags = "color paint rgb colour" }

D{ id = "anchor", cat = "inst", label = "anchor",
	head = "set {obj} anchored to {value}", code = "{obj}.Anchored = {value}",
	fields = { obj = "expr|part|object", value = "choice|true|value|true,false" },
	doc = "Anchored parts ignore gravity and stay exactly where you put them.",
	tags = "anchor physics gravity freeze" }

D{ id = "tween", cat = "inst", label = "tween",
	head = "smoothly change {obj} to {goal} over {time} seconds",
	code = "TweenService:Create({obj}, TweenInfo.new({time}), {goal}):Play()",
	fields = { obj = "expr|part|object",
		goal = "expr|{ Transparency = 1 }|goal properties", time = "num|0.5|seconds" },
	needs = { "TweenService" },
	doc = "The goal is a table of properties and their end values. Roblox fills " ..
		"in every frame between.",
	tags = "tween animate smooth transition" }

D{ id = "addTag", cat = "inst", label = "tag",
	head = 'tag {obj} as "{tag}"', code = 'CollectionService:AddTag({obj}, "{tag}")',
	fields = { obj = "expr|part|object", tag = "str|Coin|tag" },
	needs = { "CollectionService" },
	doc = "Marks an object so one script can find every object like it.",
	tags = "tag collectionservice group label" }

D{ id = "cleanupAfter", cat = "inst", label = "remove later",
	head = "remove {obj} after {time} seconds",
	code = "Debris:AddItem({obj}, {time})",
	fields = { obj = "expr|part|object", time = "num|5|seconds" },
	needs = { "Debris" },
	doc = "Schedules a deletion without holding up your script.",
	tags = "debris cleanup delete timer" }

--=============================================================================
-- PLAYERS
--=============================================================================

D{ id = "localPlayer", cat = "player", label = "this player",
	head = "make {name} = the player at this screen",
	code = "local {name} = Players.LocalPlayer",
	fields = { name = "name|player|name" }, needs = { "Players" },
	doc = "LocalScripts only. On the server there is no single player, because " ..
		"the server runs for everyone at once.",
	tags = "localplayer client me" }

D{ id = "eachPlayer", cat = "player", label = "for each player",
	head = "for each {player} in the game",
	code = "for _, {player} in ipairs(Players:GetPlayers()) do", tail = "end",
	fields = { player = "name|player|player" },
	slots = { { key = "body" } }, needs = { "Players" },
	doc = "Walks everyone currently connected.",
	tags = "players loop everyone all" }

D{ id = "charOf", cat = "player", label = "character of",
	head = "make {name} = the character of {player}",
	code = "local {name} = {player}.Character",
	fields = { name = "name|char|name", player = "expr|player|player" },
	doc = "The model in the workspace. It is `nil` between dying and respawning.",
	tags = "character model body" }

D{ id = "humanoidOf", cat = "player", label = "humanoid of",
	head = "make {name} = the humanoid of {char}",
	code = 'local {name} = {char}:FindFirstChildOfClass("Humanoid")',
	fields = { name = "name|hum|name", char = "expr|char|character" },
	doc = "The Humanoid holds health, walk speed and jump power.",
	tags = "humanoid health character" }

D{ id = "walkSpeed", cat = "player", label = "set walk speed",
	head = "set the walk speed of {hum} to {n}", code = "{hum}.WalkSpeed = {n}",
	fields = { hum = "expr|hum|humanoid", n = "num|16|speed" },
	doc = "16 is the Roblox default. 0 freezes the player in place.",
	tags = "walkspeed run fast slow" }

D{ id = "jumpPower", cat = "player", label = "set jump power",
	head = "set the jump power of {hum} to {n}",
	code = { "{hum}.UseJumpPower = true", "{hum}.JumpPower = {n}" },
	fields = { hum = "expr|hum|humanoid", n = "num|50|power" },
	doc = "50 is the default. The first line makes sure jump height is being " ..
		"driven by power rather than height.",
	tags = "jump power height" }

D{ id = "damage", cat = "player", label = "damage",
	head = "damage {hum} by {n}", code = "{hum}:TakeDamage({n})",
	fields = { hum = "expr|hum|humanoid", n = "num|10|amount" },
	doc = "Respects ForceFields, which subtracting from Health directly does not.",
	tags = "damage hurt health hit" }

D{ id = "heal", cat = "player", label = "heal",
	head = "heal {hum} by {n}",
	code = "{hum}.Health = math.min({hum}.Health + {n}, {hum}.MaxHealth)",
	fields = { hum = "expr|hum|humanoid", n = "num|10|amount" },
	doc = "The `math.min` keeps healing from pushing health over the maximum.",
	tags = "heal health restore" }

D{ id = "teleportChar", cat = "player", label = "teleport character",
	head = "teleport {char} to ({x}, {y}, {z})",
	code = "{char}:PivotTo(CFrame.new({x}, {y}, {z}))",
	fields = { char = "expr|char|character", x = "expr|0|x", y = "expr|10|y",
		z = "expr|0|z" },
	doc = "Aim a few studs above the floor, or the character lands inside it.",
	tags = "teleport move character spawn" }

D{ id = "leaderstat", cat = "player", label = "give leaderboard stat",
	head = 'give {player} a leaderboard stat "{stat}" starting at {value}',
	code = {
		"do",
		'\tlocal folder = {player}:FindFirstChild("leaderstats") or Instance.new("Folder")',
		'\tfolder.Name = "leaderstats"',
		"\tfolder.Parent = {player}",
		'\tlocal stat = Instance.new("IntValue")',
		'\tstat.Name = "{stat}"',
		"\tstat.Value = {value}",
		"\tstat.Parent = folder",
		"end",
	},
	fields = { player = "expr|player|player", stat = "str|Coins|stat name",
		value = "num|0|starting value" },
	doc = "A folder named exactly `leaderstats` inside a player is what draws " ..
		"the player list on the right of the screen.",
	tags = "leaderstats leaderboard score points" }

D{ id = "addStat", cat = "player", label = "change leaderboard stat",
	head = 'change {player}\'s "{stat}" by {n}',
	code = {
		"do",
		'\tlocal stat = {player}.leaderstats:FindFirstChild("{stat}")',
		"\tif stat then",
		"\t\tstat.Value += {n}",
		"\tend",
		"end",
	},
	fields = { player = "expr|player|player", stat = "str|Coins|stat name",
		n = "num|1|amount" },
	doc = "Adds to a stat you already created, and quietly does nothing if it " ..
		"is missing.",
	tags = "leaderstats score add points" }

D{ id = "respawn", cat = "player", label = "respawn",
	head = "respawn {player}", code = "{player}:LoadCharacter()",
	fields = { player = "expr|player|player" },
	doc = "Server only. Gives the player a fresh character right away.",
	tags = "respawn reset loadcharacter" }

--=============================================================================
-- DATA
--=============================================================================

D{ id = "newList", cat = "data", label = "empty list",
	head = "make {name} = an empty list", code = "local {name} = {}",
	fields = { name = "name|list|name" },
	doc = "In Luau one table type covers lists and dictionaries both.",
	tags = "table list array empty new" }

D{ id = "listOf", cat = "data", label = "list of",
	head = "make {name} = the list {items}", code = "local {name} = { {items} }",
	fields = { name = "name|list|name", items = "expr|1, 2, 3|items" },
	doc = "Items are numbered from 1, not 0.",
	tags = "array list literal items" }

D{ id = "dictOf", cat = "data", label = "dictionary of",
	head = "make {name} = the record { {pairs} }",
	code = "local {name} = { {pairs} }",
	fields = { name = "name|record|name",
		pairs = "expr|name = \"coin\", value = 5|key = value pairs" },
	doc = "Give values names instead of numbers when the order does not matter.",
	tags = "dictionary table record map keys" }

D{ id = "push", cat = "data", label = "add to list",
	head = "add {value} to {list}", code = "table.insert({list}, {value})",
	fields = { list = "expr|list|list", value = "expr|item|value" },
	doc = "Puts the value on the end and grows the list by one.",
	tags = "insert append add push" }

D{ id = "insertAt", cat = "data", label = "insert at",
	head = "insert {value} into {list} at position {index}",
	code = "table.insert({list}, {index}, {value})",
	fields = { list = "expr|list|list", index = "num|1|position", value = "expr|item|value" },
	doc = "Everything from that position onward shifts up one.",
	tags = "insert position index shift" }

D{ id = "removeAt", cat = "data", label = "remove at",
	head = "remove item {index} from {list}", code = "table.remove({list}, {index})",
	fields = { list = "expr|list|list", index = "num|1|position" },
	doc = "Removing while looping forward skips items -- count backwards instead.",
	tags = "remove delete index pop" }

D{ id = "removeValue", cat = "data", label = "remove value",
	head = "remove {value} from {list}",
	code = {
		"do",
		"\tlocal index = table.find({list}, {value})",
		"\tif index then",
		"\t\ttable.remove({list}, index)",
		"\tend",
		"end",
	},
	fields = { list = "expr|list|list", value = "expr|item|value" },
	doc = "Finds the value first, then removes it, and shrugs if it was never " ..
		"there.",
	tags = "remove find value delete" }

D{ id = "setKey", cat = "data", label = "set key",
	head = "set {key} of {tbl} to {value}", code = "{tbl}[{key}] = {value}",
	fields = { tbl = "expr|record|table", key = "expr|\"name\"|key", value = "expr|value|value" },
	doc = "Square brackets take any key -- a string, a number, even an instance.",
	tags = "key index assign dictionary" }

D{ id = "getKey", cat = "data", label = "get key",
	head = "make {name} = {key} of {tbl}", code = "local {name} = {tbl}[{key}]",
	fields = { name = "name|value|name", tbl = "expr|record|table",
		key = "expr|\"name\"|key" },
	doc = "Missing keys give `nil` rather than an error.",
	tags = "key index read lookup" }

D{ id = "countList", cat = "data", label = "count",
	head = "make {name} = how many items are in {list}",
	code = "local {name} = #{list}",
	fields = { name = "name|count|name", list = "expr|list|list" },
	doc = "`#` counts a numbered list. It cannot count a dictionary -- loop and " ..
		"tally for that.",
	tags = "count length size how many" }

D{ id = "containsValue", cat = "data", label = "if list contains",
	head = "if {list} contains {value} then",
	code = "if table.find({list}, {value}) then", tail = "end",
	fields = { list = "expr|list|list", value = "expr|item|value" },
	slots = { { key = "body" } },
	doc = "`table.find` gives the position, or nil when the value is absent.",
	tags = "find contains search list" }

D{ id = "sortList", cat = "data", label = "sort",
	head = "sort {list}", code = "table.sort({list})",
	fields = { list = "expr|list|list" },
	doc = "Sorts numbers and strings in place. Everything else needs a rule of " ..
		"your own.",
	tags = "sort order arrange" }

D{ id = "clearList", cat = "data", label = "empty out",
	head = "empty out {list}", code = "table.clear({list})",
	fields = { list = "expr|list|list" },
	doc = "Keeps the same table but drops everything in it, so other code " ..
		"holding the table sees the change.",
	tags = "clear empty wipe reset" }

D{ id = "concatList", cat = "data", label = "join list into text",
	head = 'make {name} = {list} joined with "{sep}"',
	code = 'local {name} = table.concat({list}, "{sep}")',
	fields = { name = "name|text|name", list = "expr|list|list", sep = "str|, |separator" },
	doc = "Turns a list of strings or numbers into one string.",
	tags = "concat join text list" }

--=============================================================================
-- ESCAPE HATCH
--=============================================================================

D{ id = "raw", cat = "special", label = "raw Luau",
	head = "{code}", code = "{code}",
	fields = { code = "multiline|-- your Luau here|Luau" },
	raw = true,
	doc = "Anything you type here is emitted exactly as written. This is also " ..
		"where imported code lands when no block matches it.",
	tags = "raw luau code escape custom" }

D{ id = "comment", cat = "special", label = "note",
	head = "-- {text}", code = "-- {text}",
	fields = { text = "str|note to self|note" },
	doc = "A note for humans. Roblox ignores it entirely.",
	tags = "comment note remark todo" }

--=============================================================================
-- the rest of the definitions
--
-- Split across files so no single one is unreadable.  Each returns a function
-- taking the define helper, which is what keeps them from having to require
-- this module back and make a cycle.
--=============================================================================

for _, load in ipairs({
	require(script.Parent.s),
	require(script.Parent.t),
	require(script.Parent.u),
	require(script.Parent.v),
	require(script.Parent.w),
}) do
	load(D)
end

--=============================================================================
-- lookups
--=============================================================================

function c.get(id)
	return c.defs[id]
end

-- Custom blocks come and go as they are edited, so the registry has to be able
-- to forget one.
function c.undefine(id)
	if not c.defs[id] then return false end
	c.defs[id] = nil
	for index, def in ipairs(c.order) do
		if def.id == id then
			table.remove(c.order, index)
			break
		end
	end
	return true
end

function c.byCat(catId)
	local out = {}
	for _, def in ipairs(c.order) do
		if def.cat == catId then out[#out + 1] = def end
	end
	return out
end

function c.count()
	return #c.order
end

-- Every field key a definition actually uses, in the order they are read.
function c.fieldOrder(def)
	local seen, order = {}, {}
	local function scan(parts)
		for _, part in ipairs(parts) do
			if part.t == "field" and not seen[part.k] then
				seen[part.k] = true
				order[#order + 1] = part.k
			end
		end
	end
	for _, line in ipairs(def.headTpl) do scan(line) end
	for _, slot in ipairs(def.slots) do
		if slot.preTpl then scan(slot.preTpl) end
	end
	if def.tailTpl then scan(def.tailTpl) end
	return order
end

-- Sanity pass used by the test suite: every `{key}` must have a field, and
-- every field must be referenced by a template.
function c.validate()
	local problems = {}
	for _, def in ipairs(c.order) do
		local used = {}
		local function scan(text, where)
			for key in string.gmatch(text, FIELD_PATTERN) do
				used[key] = true
				if not def.fields[key] then
					problems[#problems + 1] = def.id .. ": " .. where ..
						" uses undeclared field {" .. key .. "}"
				end
			end
		end
		for _, line in ipairs(def.headLines) do scan(line, "head") end
		for _, line in ipairs(def.codeLines) do scan(line, "code") end
		for _, line in ipairs(def.tailLines or {}) do scan(line, "tail") end
		for _, line in ipairs(def.codeTailLines or {}) do scan(line, "codeTail") end
		for _, slot in ipairs(def.slots) do
			if slot.pre then scan(slot.pre, "slot pre") end
			if slot.codePre then scan(slot.codePre, "slot code") end
		end
		for key in pairs(def.fields) do
			if not used[key] then
				problems[#problems + 1] = def.id .. ": field {" .. key ..
					"} is declared but never used"
			end
		end
		if not def.doc or #def.doc < 20 then
			problems[#problems + 1] = def.id .. ": missing or thin documentation"
		end
	end
	return problems
end

return c
