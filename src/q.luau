--!nonstrict
-- q  ·  custom blocks
--
-- A custom block is stored as Luau with placeholders:
--
--     {player}.leaderstats.Coins.Value += {amount}
--
-- A placeholder written inline is an input field.  A placeholder alone on its
-- own line is a slot you can drop blocks into:
--
--     if {player}.Team == teamA then
--         {body}
--     end
--
-- Everything reduces to that one shape, which is what lets all four ways of
-- making a block -- from the canvas, from typed Luau, from a function block,
-- from a ModuleScript -- share a single code path, and lets the same block be
-- edited as text or reopened as a canvas.
--
-- How it compiles is decided here rather than by the author: a block with no
-- slots becomes one `local function` at the top and a call at each use, the
-- way you would factor it by hand.  A block with slots has to be inlined,
-- because what goes inside changes from use to use.

local c = require(script.Parent.c)
local d = require(script.Parent.d)
local e = require(script.Parent.e)
local g = require(script.Parent.g)
local h = require(script.Parent.h)

local q = {}

q.FORMAT = 1

-- every custom block currently registered, by id
q.all = {}

--=============================================================================
-- helpers
--=============================================================================

local function trim(text)
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

local function lines(text)
	local out = {}
	for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
		out[#out + 1] = line
	end
	while #out > 0 and trim(out[#out]) == "" do
		out[#out] = nil
	end
	return out
end

-- "Give a coin" -> "giveACoin", always a legal identifier
function q.functionName(label, taken)
	local pieces = {}
	for word in string.gmatch(label, "[%a%d]+") do
		pieces[#pieces + 1] = word
	end
	if #pieces == 0 then pieces = { "block" } end
	local name = string.lower(string.sub(pieces[1], 1, 1)) .. string.sub(pieces[1], 2)
	for index = 2, #pieces do
		name = name .. string.upper(string.sub(pieces[index], 1, 1)) ..
			string.sub(pieces[index], 2)
	end
	if string.match(name, "^%d") then name = "block" .. name end

	if taken then
		local base, suffix = name, 2
		while taken[name] do
			name = base .. suffix
			suffix = suffix + 1
		end
	end
	return name
end

-- Reads the placeholders out of the Luau: inline ones are fields, ones alone on
-- a line are slots.
function q.readShape(luau)
	local fields, slots = {}, {}
	local seenField, seenSlot = {}, {}

	for _, line in ipairs(lines(luau)) do
		local bare = string.match(trim(line), "^{([%a_][%w_]*)}$")
		if bare then
			if not seenSlot[bare] then
				seenSlot[bare] = true
				slots[#slots + 1] = bare
			end
		else
			for key in string.gmatch(line, "{([%a_][%w_]*)}") do
				if not seenField[key] then
					seenField[key] = true
					fields[#fields + 1] = key
				end
			end
		end
	end

	return fields, slots
end

--=============================================================================
-- making one
--=============================================================================

local nextId = 1

local function freshId()
	local id = "cb" .. nextId .. "_" .. (math.floor(os.clock() * 1000) % 100000)
	nextId = nextId + 1
	return id
end

-- The blank a new custom block starts from.
function q.new(label, luau)
	label = label or "My block"
	luau = luau or "-- what this block should do"
	local fieldKeys, slotKeys = q.readShape(luau)

	local fields = {}
	for _, key in ipairs(fieldKeys) do
		fields[#fields + 1] = { key = key, kind = "expr", default = "", label = key }
	end
	local slots = {}
	for _, key in ipairs(slotKeys) do
		slots[#slots + 1] = { key = key, label = key }
	end

	return {
		id = freshId(),
		label = label,
		group = "Mine",
		colour = "vars",
		doc = "",
		wording = nil,       -- nil means build one from the label and fields
		luau = luau,
		fields = fields,
		slots = slots,
		returns = false,
		shared = true,
	}
end

-- Wording defaults to the label followed by each field, which reads acceptably
-- and can be replaced with anything using the same placeholders.
function q.wordingOf(custom)
	if custom.wording and trim(custom.wording) ~= "" then return custom.wording end
	local parts = { custom.label }
	for _, field in ipairs(custom.fields) do
		parts[#parts + 1] = "{" .. field.key .. "}"
	end
	return table.concat(parts, " ")
end

-- Keeps fields and slots in step with the Luau after it has been edited.
function q.refresh(custom)
	local fieldKeys, slotKeys = q.readShape(custom.luau)

	local existing = {}
	for _, field in ipairs(custom.fields) do existing[field.key] = field end
	local fields = {}
	for _, key in ipairs(fieldKeys) do
		fields[#fields + 1] = existing[key]
			or { key = key, kind = "expr", default = "", label = key }
	end
	custom.fields = fields

	local hadSlot = {}
	for _, slot in ipairs(custom.slots) do hadSlot[slot.key] = slot end
	local slots = {}
	for _, key in ipairs(slotKeys) do
		slots[#slots + 1] = hadSlot[key] or { key = key, label = key }
	end
	custom.slots = slots
	return custom
end

--=============================================================================
-- compiling into a real block
--=============================================================================

local OUT_FIELD = "out"

-- Splits the Luau around its slot markers into head lines, the lead-in lines
-- for each slot, and tail lines -- the shape the registry wants.
local function split(custom)
	local head, slots = {}, {}
	local collected = {}
	local seenMarker = false

	for _, line in ipairs(lines(custom.luau)) do
		local bare = string.match(trim(line), "^{([%a_][%w_]*)}$")
		if bare then
			-- whatever was gathered since the last marker leads into this one
			slots[#slots + 1] = { key = bare, pre = seenMarker and collected or nil }
			collected = {}
			seenMarker = true
		elseif seenMarker then
			collected[#collected + 1] = line
		else
			head[#head + 1] = line
		end
	end

	return { head = head, slots = slots, tail = collected }
end

-- A block with no slots compiles to a function; one with slots must inline.
function q.isHelper(custom)
	return #custom.slots == 0
end

-- Turns a custom block into a registry definition.
function q.compile(custom)
	local parts = split(custom)
	local wording = q.wordingOf(custom)

	local fields = {}
	for _, field in ipairs(custom.fields) do
		fields[field.key] = {
			key = field.key,
			kind = field.kind or "expr",
			default = field.default or "",
			placeholder = field.label or field.key,
			options = field.options,
		}
	end

	local head, code, tail, codeTail
	local slots = {}

	if custom.returns then
		-- a value-producing block reads as "make x = ..." and assigns
		fields[OUT_FIELD] = { key = OUT_FIELD, kind = "name", default = "value",
			placeholder = "name" }
		head = "make {" .. OUT_FIELD .. "} = " .. wording
		code = "local {" .. OUT_FIELD .. "} = " .. trim(table.concat(parts.head, " "))
	else
		head = wording
		code = parts.head
		if #code == 0 then code = { "-- " .. custom.label } end
		if #parts.slots > 0 then
			for index, slot in ipairs(parts.slots) do
				slots[index] = {
					key = slot.key,
					label = slot.label or slot.key,
					codePreLines = index > 1 and slot.pre or nil,
				}
			end
			tail = "end"
			codeTail = parts.tail
			if #codeTail == 0 then codeTail = nil end
		end
	end

	local def = c.define{
		id = "custom_" .. custom.id,
		cat = "custom",
		group = custom.group or "Mine",
		label = custom.label,
		head = head,
		code = code,
		tail = tail,
		codeTail = codeTail,
		fields = fields,
		slots = slots,
		doc = (custom.doc and trim(custom.doc) ~= "" and custom.doc)
			or ("One of your own blocks. It writes the Luau you gave it, with " ..
				"whatever you type in its fields."),
		tags = "custom mine " .. string.lower(custom.label),
	}

	-- What the code writer needs, without it having to know about this module.
	local params = {}
	for _, field in ipairs(custom.fields) do
		params[#params + 1] = field.key
	end
	def.custom = {
		cid = custom.id,
		helper = q.isHelper(custom) and not custom.returns,
		returnsHelper = q.isHelper(custom) and custom.returns,
		fn = custom.fn,
		params = params,
		body = parts.head,
		returns = custom.returns,
		out = OUT_FIELD,
	}
	return def
end

--=============================================================================
-- the library
--=============================================================================

local function reserveNames()
	local taken = {}
	for _, custom in pairs(q.all) do
		if custom.fn then taken[custom.fn] = true end
	end
	return taken
end

function q.register(custom)
	q.unregister(custom.id)
	custom.fn = custom.fn or q.functionName(custom.label, reserveNames())
	q.all[custom.id] = custom
	local ok, err = pcall(q.compile, custom)
	if not ok then
		q.all[custom.id] = nil
		return nil, tostring(err)
	end
	return custom
end

function q.unregister(id)
	if not id then return end
	q.all[id] = nil
	c.undefine("custom_" .. id)
end

function q.get(id)
	return q.all[id]
end

function q.list()
	local out = {}
	for _, custom in pairs(q.all) do
		out[#out + 1] = custom
	end
	table.sort(out, function(a, b)
		if a.group ~= b.group then return a.group < b.group end
		return a.label < b.label
	end)
	return out
end

function q.groups()
	local seen, out = {}, {}
	for _, custom in pairs(q.all) do
		local group = custom.group or "Mine"
		if not seen[group] then
			seen[group] = true
			out[#out + 1] = group
		end
	end
	table.sort(out)
	return out
end

-- Plain tables in, plain tables out, so the whole library fits in one setting.
function q.toSave(custom)
	return {
		id = custom.id, label = custom.label, group = custom.group,
		colour = custom.colour, doc = custom.doc, wording = custom.wording,
		luau = custom.luau, returns = custom.returns, fn = custom.fn,
		shared = custom.shared, fields = custom.fields, slots = custom.slots,
	}
end

function q.fromSave(saved)
	if type(saved) ~= "table" or type(saved.luau) ~= "string" then return nil end
	local custom = {
		id = saved.id or freshId(),
		label = saved.label or "My block",
		group = saved.group or "Mine",
		colour = saved.colour or "vars",
		doc = saved.doc or "",
		wording = saved.wording,
		luau = saved.luau,
		returns = saved.returns == true,
		fn = saved.fn,
		shared = saved.shared ~= false,
		fields = saved.fields or {},
		slots = saved.slots or {},
	}
	return q.refresh(custom)
end

--=============================================================================
-- the four ways of making one
--=============================================================================

-- 1. from typed Luau
function q.fromLuau(label, luau)
	return q.new(label, luau)
end

-- 2. from a stack of blocks on the canvas: the block and everything under it
function q.fromBlocks(doc, block)
	local pieces = {}
	local list = d.listOf(doc, block)
	local reached = false
	for _, id in ipairs(list or {}) do
		if id == block.id then reached = true end
		if reached then
			local sibling = doc.blocks[id]
			if sibling then pieces[#pieces + 1] = e.snippet(doc, sibling) end
		end
	end
	if #pieces == 0 then pieces[1] = e.snippet(doc, block) end

	local custom = q.new("My block", table.concat(pieces, "\n"))
	custom.doc = "Built from blocks on the canvas."
	return custom
end

-- 3. from a `define` block already in the project
function q.fromFunctionBlock(doc, block)
	local def = c.get(block.k)
	if not def then return nil, "that is not a block" end
	local name = c.fieldValue(def, block, "name")
	local params = c.fieldValue(def, block, "params")

	local holes = {}
	for word in string.gmatch(params, "[%a_][%w_]*") do
		holes[#holes + 1] = "{" .. word .. "}"
	end
	local call = name .. "(" .. table.concat(holes, ", ") .. ")"
	local custom = q.new(name, call)
	custom.doc = "Runs the `" .. name .. "` function defined in this project."
	return custom
end

-- 4. from a ModuleScript in the place: one block per function it defines
function q.fromModule(instance, path)
	local ok, source = pcall(function() return instance.Source end)
	if not ok or not source then
		return nil, "Studio would not let the plugin read that script"
	end
	local chunk, err = g.parse(source)
	if not chunk then
		return nil, string.format("line %d: %s", err.line, err.msg)
	end

	local made = {}
	for _, statement in ipairs(chunk.body) do
		if statement.k == "func" and not statement.isMethod then
			local owner, name = string.match(statement.name, "^([%a_][%w_]*)%.([%a_][%w_]*)$")
			if owner and name then
				local holes = {}
				for _, param in ipairs(statement.fn.params) do
					if not param.vararg then
						holes[#holes + 1] = "{" .. param.name .. "}"
					end
				end
				local call = string.format("require(%s).%s(%s)", path, name,
					table.concat(holes, ", "))
				local custom = q.new(name, call)
				custom.group = instance.Name
				custom.doc = "Calls `" .. name .. "` from the " .. instance.Name ..
					" module."
				made[#made + 1] = custom
			end
		end
	end

	if #made == 0 then
		return nil, "no module functions found in " .. instance.Name
	end
	return made
end

--=============================================================================
-- editing one as a canvas
--=============================================================================

-- Turns the stored Luau into blocks, with the placeholders standing in as
-- ordinary names so they survive the round trip.
function q.toCanvas(custom)
	local readable = string.gsub(custom.luau, "{([%a_][%w_]*)}", "__%1")
	local doc, report, err = h.fromCode(readable, custom.label)
	if not doc then return nil, err end
	doc.customEdit = custom.id
	return doc, report
end

-- And back again after editing.
function q.fromCanvas(custom, doc)
	local code = e.generate(doc, { header = false })
	custom.luau = (string.gsub(code, "__([%a_][%w_]*)", "{%1}"))
	return q.refresh(custom)
end

--=============================================================================
-- the library as a ModuleScript
--
-- Sharing a library by hand is the one thing plugin settings cannot do: they
-- live in one person's Studio.  A ModuleScript can be committed, dragged into
-- a model, or handed to someone in a place file, so that is what the library
-- saves to.  It is written as a plain Luau table and read back with the same
-- parser the importer uses -- no loadstring, no JSON blob, and you can edit
-- the file by hand without breaking it.
--=============================================================================

local function quote(text)
	return (string.format("%q", tostring(text)):gsub("\\\n", "\\n"))
end

-- Long-bracket form for the code itself, choosing a level of `=` no closing
-- bracket in the body can collide with.
local function longString(text)
	local level = 0
	while string.find(text, "]" .. string.rep("=", level) .. "]", 1, true)
		or string.find(text, "[" .. string.rep("=", level) .. "[", 1, true) do
		level += 1
	end
	local pad = string.rep("=", level)
	return "[" .. pad .. "[\n" .. text .. "\n]" .. pad .. "]"
end

local function writeEntry(custom, indent)
	local out = {}
	local pad = string.rep("\t", indent)
	local inner = string.rep("\t", indent + 1)
	out[#out + 1] = pad .. "{"
	out[#out + 1] = inner .. "label = " .. quote(custom.label) .. ","
	out[#out + 1] = inner .. "group = " .. quote(custom.group or "Mine") .. ","
	if custom.doc and trim(custom.doc) ~= "" then
		out[#out + 1] = inner .. "doc = " .. quote(custom.doc) .. ","
	end
	if custom.wording and trim(custom.wording) ~= "" then
		out[#out + 1] = inner .. "wording = " .. quote(custom.wording) .. ","
	end
	if custom.returns then out[#out + 1] = inner .. "returns = true," end
	out[#out + 1] = inner .. "luau = " ..
		longString((string.gsub(custom.luau, "%s+$", ""))) .. ","

	if #custom.fields > 0 then
		out[#out + 1] = inner .. "fields = {"
		for _, field in ipairs(custom.fields) do
			local parts = {
				"key = " .. quote(field.key),
				"kind = " .. quote(field.kind or "expr"),
				"default = " .. quote(field.default or ""),
				"label = " .. quote(field.label or field.key),
			}
			if field.options then
				parts[#parts + 1] = "options = " .. quote(field.options)
			end
			out[#out + 1] = inner .. "\t{ " .. table.concat(parts, ", ") .. " },"
		end
		out[#out + 1] = inner .. "},"
	end

	if #custom.slots > 0 then
		out[#out + 1] = inner .. "slots = {"
		for _, slot in ipairs(custom.slots) do
			out[#out + 1] = inner .. "\t{ key = " .. quote(slot.key) ..
				", label = " .. quote(slot.label or slot.key) .. " },"
		end
		out[#out + 1] = inner .. "},"
	end

	out[#out + 1] = pad .. "},"
	return table.concat(out, "\n")
end

-- `list` defaults to the whole library.
function q.toModuleSource(list, projectName)
	list = list or q.list()
	local out = {
		"-- Blocks made in ABlocks.",
		"--",
		"-- Every entry below is one block: `luau` is what it writes, and each",
		"-- {placeholder} in it becomes a field you fill in on the block.  Edit",
		"-- this file by hand if you like -- ABlocks reads it back the same way.",
		"--",
		"-- To use these: open ABlocks, go to setup, select this ModuleScript in",
		"-- the Explorer and press \"Load from a ModuleScript\".",
	}
	if projectName then
		out[#out + 1] = "-- Saved from the project " .. projectName .. "."
	end
	out[#out + 1] = ""
	out[#out + 1] = "return {"
	for _, custom in ipairs(list) do
		out[#out + 1] = writeEntry(custom, 1)
	end
	out[#out + 1] = "}"
	out[#out + 1] = ""
	return table.concat(out, "\n")
end

-- The lexer keeps strings as written, delimiters and all, because everything
-- else in the plugin copies source text around rather than reading it.  Here
-- the actual text is wanted, so this is the one place that decodes one.
local ESCAPES = {
	n = "\n", t = "\t", r = "\r", a = "\a", b = "\b", f = "\f", v = "\v",
	["\\"] = "\\", ["\""] = "\"", ["'"] = "'", ["\n"] = "\n",
}

local function decodeString(raw)
	if type(raw) ~= "string" then return nil end

	local pad = string.match(raw, "^%[(=*)%[")
	if pad then
		local body = string.sub(raw, #pad + 3, -(#pad + 3))
		-- Luau drops a newline that comes straight after the opening bracket
		return (string.gsub(body, "^\n", ""))
	end

	local quoteChar = string.sub(raw, 1, 1)
	if quoteChar ~= "\"" and quoteChar ~= "'" then return nil end

	local body = string.sub(raw, 2, -2)
	local out, i = {}, 1
	while i <= #body do
		local ch = string.sub(body, i, i)
		if ch == "\\" then
			local nextCh = string.sub(body, i + 1, i + 1)
			local digits = string.match(body, "^%d%d?%d?", i + 1)
			local hex = string.match(body, "^x(%x%x)", i + 1)
			if hex then
				out[#out + 1] = string.char(tonumber(hex, 16))
				i += 4
			elseif digits then
				out[#out + 1] = string.char(tonumber(digits))
				i += 1 + #digits
			elseif nextCh == "z" then
				-- \z eats the whitespace that follows it
				local _, stop = string.find(body, "^%s*", i + 2)
				i = (stop or i + 1) + 1
			else
				out[#out + 1] = ESCAPES[nextCh] or nextCh
				i += 2
			end
		else
			out[#out + 1] = ch
			i += 1
		end
	end
	return table.concat(out)
end

-- Reads a constant expression out of the parsed module: strings, numbers,
-- booleans and tables of them.  Anything cleverer is refused rather than
-- guessed at, because a library file should not be able to run code.
local function constant(node)
	if not node then return nil end
	if node.k == "str" then return decodeString(node.value) end
	if node.k == "num" then return tonumber(node.value) end
	if node.k == "bool" then return node.value end
	if node.k == "nil" then return nil end
	if node.k == "table" then
		local out = {}
		for _, field in ipairs(node.fields) do
			if field.kind == "array" then
				out[#out + 1] = constant(field.value)
			elseif field.kind == "named" then
				out[field.name] = constant(field.value)
			elseif field.kind == "index" then
				local key = constant(field.key)
				if type(key) == "string" or type(key) == "number" then
					out[key] = constant(field.value)
				end
			end
		end
		return out
	end
	return nil, "only plain values belong in a block library"
end

function q.fromModuleSource(source)
	local chunk, err = g.parse(source)
	if not chunk then
		return nil, string.format("line %d: %s", err.line, err.msg)
	end

	local returned
	for _, statement in ipairs(chunk.body) do
		if statement.k == "return" then returned = statement.exprs[1] end
	end
	if not returned then
		return nil, "that module does not return anything"
	end

	local value = constant(returned)
	if type(value) ~= "table" then
		return nil, "that module does not return a list of blocks"
	end

	local made, skipped = {}, 0
	for _, entry in ipairs(value) do
		if type(entry) == "table" and type(entry.luau) == "string" then
			entry.luau = (string.gsub(entry.luau, "%s+$", ""))
		end
		local custom = type(entry) == "table" and type(entry.luau) == "string"
			and q.fromSave(entry) or nil
		if custom then
			-- names and ids are earned on the way in, so loading someone
			-- else's library never collides with a block you already have
			custom.id = freshId()
			custom.fn = nil
			made[#made + 1] = custom
		else
			skipped += 1
		end
	end

	if #made == 0 then
		return nil, "no blocks in that module"
	end
	return made, skipped
end

--=============================================================================
-- which ones a document uses
--=============================================================================

function q.usedIn(doc)
	local used = {}
	d.walk(doc, function(block)
		local def = c.get(block.k)
		if def and def.custom then
			local custom = q.all[def.custom.cid]
			if custom then used[custom.id] = custom end
		end
	end)
	local out = {}
	for _, custom in pairs(used) do out[#out + 1] = custom end
	table.sort(out, function(a, b) return a.id < b.id end)
	return out
end

-- Projects carry a copy of every custom block they use, so opening someone
-- else's project adds their blocks rather than breaking.
function q.embed(doc)
	local saved = {}
	for _, custom in ipairs(q.usedIn(doc)) do
		saved[#saved + 1] = q.toSave(custom)
	end
	return saved
end

function q.adopt(list)
	local added = 0
	for _, saved in ipairs(list or {}) do
		local custom = q.fromSave(saved)
		if custom and not q.all[custom.id] then
			if q.register(custom) then added = added + 1 end
		end
	end
	return added
end

return q
