--!nonstrict
-- e  ·  code generator
--
-- Walks the document and writes Luau.  Two things make the output feel
-- hand-written rather than machine-stamped:
--
--   * services are hoisted -- blocks declare what they need ("Players",
--     "TweenService") and one tidy preamble appears at the top, skipping any
--     service you already declared yourself;
--   * `if` blocks nested in an `otherwise` slot collapse back into `elseif`,
--     so a five-way branch does not march off the right edge of the screen.
--
--   local code, meta = e.generate(doc)
--   meta.blockOfLine[12] -- which block wrote line 12

local c = require(script.Parent.c)
local d = require(script.Parent.d)
local g = require(script.Parent.g)

local e = {}

local INDENT = "\t"

local Writer = {}
Writer.__index = Writer

local function newWriter()
	return setmetatable({
		lines = {},
		owners = {},
		depth = 0,
		needs = {},
		declared = {},
		declaredFunctions = {},
		helpers = {},
	}, Writer)
end

function Writer:line(text, owner)
	local body = text or ""
	if body == "" then
		self.lines[#self.lines + 1] = ""
	else
		self.lines[#self.lines + 1] = string.rep(INDENT, self.depth) .. body
	end
	self.owners[#self.lines] = owner
	-- Notice services the author declared by hand so the preamble stays quiet.
	local name = string.match(body, '^local%s+([%a_][%w_]*)%s*=%s*game:GetService')
	if name then self.declared[name] = true end
	-- Same for functions: a custom block's helper is not written twice if the
	-- document already defines one by that name.
	local fn = string.match(body, "^local%s+function%s+([%a_][%w_]*)")
	if fn then self.declaredFunctions[fn] = true end
	return #self.lines
end

-- Template lines may start with tabs to nest inside their own block.
function Writer:tpl(text, owner)
	local extra = 0
	local body = text
	while string.sub(body, 1, 1) == INDENT do
		extra = extra + 1
		body = string.sub(body, 2)
	end
	self.depth = self.depth + extra
	local at = self:line(body, owner)
	self.depth = self.depth - extra
	return at
end

function Writer:push(levels) self.depth = self.depth + (levels or 1) end
function Writer:pop(levels) self.depth = math.max(0, self.depth - (levels or 1)) end

--=============================================================================

local emitStack

local function fillLine(def, block, template)
	return c.fill(c.parseTemplate(template), def, block)
end

-- `if a then ... otherwise (single if) ...` -> `if a then ... elseif b then ...`
-- Writes the chain without its closing `end`; the caller owns that, so the
-- recursion cannot lose it.
local function emitIfChain(w, doc, block, keyword)
	local def = c.get(block.k)
	w:tpl(string.gsub(fillLine(def, block, def.codeLines[1]), "^if", keyword, 1), block.id)
	w:push()
	emitStack(w, doc, d.children(doc, block, "body"))
	w:pop()

	local els = d.children(doc, block, "els")
	if #els == 1 and (els[1].k == "if" or els[1].k == "ifelse") then
		emitIfChain(w, doc, els[1], "elseif")
		return
	end
	if #els > 0 then
		w:line("else", block.id)
		w:push()
		emitStack(w, doc, els)
		w:pop()
	end
end

local function emitBlock(w, doc, block)
	local def = c.get(block.k)
	if not def then
		w:line("-- [ABlocks] unknown block '" .. tostring(block.k) .. "'", block.id)
		return
	end

	for _, service in ipairs(def.needs or {}) do
		w.needs[service] = true
	end

	if def.raw then
		local source = c.fieldValue(def, block, "code")
		if source == "" then return end
		for piece in string.gmatch(source .. "\n", "([^\n]*)\n") do
			w:line(piece, block.id)
		end
		return
	end

	-- Custom blocks with no slots compile to one function at the top and a
	-- call here; ones with slots fall through and inline, because what goes
	-- inside them changes from use to use.
	local custom = def.custom
	if custom and (custom.helper or custom.returnsHelper) then
		local args = {}
		for _, key in ipairs(custom.params) do
			args[#args + 1] = c.fieldValue(def, block, key)
		end
		local call = custom.fn .. "(" .. table.concat(args, ", ") .. ")"
		w.helpers[custom.fn] = custom
		if custom.returnsHelper then
			w:line("local " .. c.fieldValue(def, block, custom.out) .. " = " .. call,
				block.id)
		else
			w:line(call, block.id)
		end
		return
	end

	if def.elseifCollapse then
		emitIfChain(w, doc, block, "if")
		w:line("end", block.id)
		return
	end

	for _, template in ipairs(def.codeLines) do
		w:tpl(fillLine(def, block, template), block.id)
	end

	for _, slot in ipairs(def.slots) do
		local lead = slot.codePreLines or (slot.codePre and { slot.codePre })
		if lead then
			local at = slot.codeIndent or (def.bodyIndent - 1)
			w:push(at)
			for _, line in ipairs(lead) do
				w:tpl(fillLine(def, block, line), block.id)
			end
			w:pop(at)
		end
		w:push(def.bodyIndent)
		emitStack(w, doc, d.children(doc, block, slot.key))
		w:pop(def.bodyIndent)
	end

	for _, template in ipairs(def.codeTailLines or {}) do
		w:tpl(fillLine(def, block, template), block.id)
	end
end

function emitStack(w, doc, blocks)
	for _, block in ipairs(blocks) do
		emitBlock(w, doc, block)
	end
end

--=============================================================================

local SERVICE_ORDER = {
	Players = 1, RunService = 2, ReplicatedStorage = 3, ServerStorage = 4,
	TweenService = 5, UserInputService = 6, CollectionService = 7, Debris = 8,
}

-- Generates the script for a document.
-- opts.header = false turns off the two-line banner.
function e.generate(doc, opts)
	opts = opts or {}
	local w = newWriter()

	for index, stack in ipairs(d.sortedStacks(doc)) do
		if index > 1 then w:line("") end
		emitStack(w, doc, d.stackBlocks(doc, stack))
	end

	local preamble = {}
	local pending = {}
	for service in pairs(w.needs) do
		if not w.declared[service] then pending[#pending + 1] = service end
	end
	table.sort(pending, function(a, b)
		local ra, rb = SERVICE_ORDER[a] or 50, SERVICE_ORDER[b] or 50
		if ra ~= rb then return ra < rb end
		return a < b
	end)
	for _, service in ipairs(pending) do
		preamble[#preamble + 1] =
			string.format('local %s = game:GetService("%s")', service, service)
	end

	-- helper functions for the custom blocks that were used
	local helperNames = {}
	for name in pairs(w.helpers) do
		if not w.declaredFunctions[name] then helperNames[#helperNames + 1] = name end
	end
	table.sort(helperNames)

	local helpers = {}
	for _, name in ipairs(helperNames) do
		local custom = w.helpers[name]
		helpers[#helpers + 1] = string.format("local function %s(%s)", name,
			table.concat(custom.params, ", "))
		for _, line in ipairs(custom.body) do
			-- inside the helper the placeholders are simply its parameters
			local filled = string.gsub(line, "{([%a_][%w_]*)}", "%1")
			helpers[#helpers + 1] = filled == "" and "" or ("\t" .. filled)
		end
		if custom.returns then
			-- a value-producing block's body is the expression to hand back
			helpers[#helpers] = nil
			local body = {}
			for _, line in ipairs(custom.body) do
				body[#body + 1] = (string.gsub(line, "{([%a_][%w_]*)}", "%1"))
			end
			helpers[#helpers + 1] = "\treturn " .. table.concat(body, " ")
		end
		helpers[#helpers + 1] = "end"
		helpers[#helpers + 1] = ""
	end

	local head = {}
	if opts.header ~= false then
		head[#head + 1] = "-- " .. (doc.name or "Untitled")
		head[#head + 1] = "-- built with ABlocks -- edits here do not travel back to the blocks"
		head[#head + 1] = ""
	end
	if #preamble > 0 then
		for _, line in ipairs(preamble) do head[#head + 1] = line end
		head[#head + 1] = ""
	end
	for _, line in ipairs(helpers) do head[#head + 1] = line end

	local out = {}
	local blockOfLine = {}
	local lineOfBlock = {}
	for _, line in ipairs(head) do out[#out + 1] = line end
	local offset = #out
	for index, line in ipairs(w.lines) do
		out[#out + 1] = line
		local owner = w.owners[index]
		if owner then
			blockOfLine[index + offset] = owner
			if not lineOfBlock[owner] then lineOfBlock[owner] = index + offset end
		end
	end

	while #out > 0 and out[#out] == "" do out[#out] = nil end
	if #out == 0 then
		out[1] = "-- Nothing on the canvas yet."
		out[2] = "-- Drag a block out of the palette on the left to start."
	end

	return table.concat(out, "\n"), {
		blockOfLine = blockOfLine,
		lineOfBlock = lineOfBlock,
		services = pending,
		lineCount = #out,
	}
end

--=============================================================================
-- advice
--
-- The three script kinds do not run in the same place or at the same time, and
-- most beginner bugs are a script in the wrong one.  These checks are plain
-- text searches on the generated code: cheap, and honest about being rules of
-- thumb rather than analysis.
--=============================================================================

local CLIENT_ONLY = {
	{ "Players.LocalPlayer", "LocalPlayer only exists on the client" },
	{ "UserInputService", "UserInputService only hears input on the client" },
	{ "RenderStepped", "RenderStepped only fires on the client" },
	{ ":GetMouse()", "GetMouse only exists on the client" },
	{ "CurrentCamera", "the camera belongs to one client" },
}

local SERVER_ONLY = {
	{ "ServerStorage", "ServerStorage is invisible to the client" },
	{ "ServerScriptService", "ServerScriptService is invisible to the client" },
	{ "DataStoreService", "data stores can only be reached from the server" },
	{ ":Kick(", "only the server can remove a player" },
	{ ":LoadCharacter()", "only the server can respawn a character" },
}

local function mentions(code, needle)
	return string.find(code, needle, 1, true) ~= nil
end

-- Returns { { level = "warn" | "note", text = "..." }, ... }
function e.advise(code, kind)
	local notes = {}

	if kind == "ModuleScript" then
		local chunk = g.parse(code)
		local last = chunk and chunk.body[#chunk.body]
		if chunk and (not last or last.k ~= "return") then
			notes[#notes + 1] = {
				level = "warn",
				text = "A ModuleScript has to hand something back. End with a " ..
					"`give back` block, or nothing that requires this will get " ..
					"anything.",
			}
		end
	end

	if kind == "LocalScript" then
		for _, rule in ipairs(SERVER_ONLY) do
			if mentions(code, rule[1]) then
				notes[#notes + 1] = { level = "warn",
					text = "This is a LocalScript, but " .. rule[2] .. "." }
			end
		end
	elseif kind == "Script" then
		for _, rule in ipairs(CLIENT_ONLY) do
			if mentions(code, rule[1]) then
				notes[#notes + 1] = { level = "warn",
					text = "This is a server Script, but " .. rule[2] .. "." }
			end
		end
	end

	return notes
end

-- Just the code for one block and its children, used by tutorials and tooltips.
function e.snippet(doc, block)
	local w = newWriter()
	emitBlock(w, doc, block)
	return table.concat(w.lines, "\n")
end

return e
