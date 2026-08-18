--!nonstrict
-- d  ·  document model
--
-- A program is a flat map of blocks plus a list of stacks.  A stack is a run of
-- blocks sitting at one spot on the canvas; slots inside a block hold runs too,
-- so every list of blocks in the editor -- top level or nested -- is the same
-- shape and the layout, drag and codegen passes only ever learn one structure.
--
--   block = {
--     id = "b7", k = "if",           -- k is a registry id from `c`
--     f = { cond = "hp <= 0" },      -- field values, always strings
--     s = { body = {"b8","b9"} },    -- slot name -> ordered child ids
--     p = "b3", ps = "body",         -- parent block + slot, when nested
--     st = "s1",                     -- owning stack, when top level
--   }
--   stack = { id = "s1", x = 40, y = 120, ids = {"b7","b12"} }

local c = require(script.Parent.c)

local d = {}

d.FORMAT = 1

function d.newDoc(name)
	return {
		format = d.FORMAT,
		name = name or "Untitled",
		nextId = 1,
		blocks = {},
		stacks = {},
	}
end

local function nextId(doc, prefix)
	local id = prefix .. doc.nextId
	doc.nextId = doc.nextId + 1
	return id
end

function d.newStack(doc, x, y)
	local stack = { id = nextId(doc, "s"), x = x or 24, y = y or 24, ids = {} }
	doc.stacks[#doc.stacks + 1] = stack
	return stack
end

function d.stack(doc, id)
	for _, stack in ipairs(doc.stacks) do
		if stack.id == id then return stack end
	end
	return nil
end

-- Creates a block with its slots ready, belonging to nothing yet.
function d.create(doc, kind)
	local def = c.get(kind)
	assert(def, "unknown block kind: " .. tostring(kind))
	local block = { id = nextId(doc, "b"), k = kind, f = {}, s = {} }
	for _, slot in ipairs(def.slots) do
		block.s[slot.key] = {}
	end
	doc.blocks[block.id] = block
	return block
end

function d.get(doc, id)
	return id and doc.blocks[id] or nil
end

function d.def(block)
	return block and c.get(block.k) or nil
end

-- The list a block lives in, plus its position in that list.
function d.listOf(doc, block)
	if block.p then
		local parent = doc.blocks[block.p]
		if not parent then return nil, nil end
		return parent.s[block.ps], parent
	end
	local stack = d.stack(doc, block.st)
	if not stack then return nil, nil end
	return stack.ids, stack
end

local function indexOf(list, value)
	for index, item in ipairs(list) do
		if item == value then return index end
	end
	return nil
end

function d.indexOf(doc, block)
	local list = d.listOf(doc, block)
	return list and indexOf(list, block.id) or nil
end

function d.children(doc, block, slotKey)
	local out = {}
	for _, id in ipairs((block.s and block.s[slotKey]) or {}) do
		local child = doc.blocks[id]
		if child then out[#out + 1] = child end
	end
	return out
end

-- Blocks in a stack, resolved.
function d.stackBlocks(doc, stack)
	local out = {}
	for _, id in ipairs(stack.ids) do
		local block = doc.blocks[id]
		if block then out[#out + 1] = block end
	end
	return out
end

-- Only ever prunes the stack a block just left.  Sweeping every empty stack
-- would also take the fresh one a block is on its way into.
local function dropIfEmpty(doc, owner)
	if not owner or not owner.ids or #owner.ids > 0 then return end
	for index, stack in ipairs(doc.stacks) do
		if stack == owner then
			table.remove(doc.stacks, index)
			return
		end
	end
end

-- Removes a block from its list without deleting it.  Returns the siblings that
-- followed it, which the caller may want to carry along.
local function unlink(doc, block, takeFollowing)
	local list, owner = d.listOf(doc, block)
	local following = {}
	if list then
		local at = indexOf(list, block.id)
		if at then
			if takeFollowing then
				for index = #list, at + 1, -1 do
					following[#following + 1] = doc.blocks[list[index]]
					table.remove(list, index)
				end
				-- collected back to front; put them back in reading order
				local flipped = {}
				for index = #following, 1, -1 do
					flipped[#flipped + 1] = following[index]
				end
				following = flipped
			end
			table.remove(list, at)
		end
	end
	block.p, block.ps, block.st = nil, nil, nil
	dropIfEmpty(doc, owner)
	return following
end

function d.isAncestor(doc, maybeAncestor, block)
	local walker = block
	while walker do
		if walker.id == maybeAncestor.id then return true end
		walker = walker.p and doc.blocks[walker.p] or nil
	end
	return false
end

-- Would dropping `block` here swallow the block itself?
function d.canDropIn(doc, block, parent)
	if not parent then return true end
	return not d.isAncestor(doc, block, parent)
end

local function place(doc, block, list, index, ownerFields)
	index = math.clamp(index or (#list + 1), 1, #list + 1)
	table.insert(list, index, block.id)
	block.p, block.ps, block.st = ownerFields.p, ownerFields.ps, ownerFields.st
	return index
end

-- Inserts `block` into a slot.  When `following` is omitted the blocks below it
-- come along, the way dragging works; pass an empty table to move it alone.
function d.attachToSlot(doc, block, parent, slotKey, index, following)
	if not d.canDropIn(doc, block, parent) then return false end
	if following then
		unlink(doc, block, false)
	else
		following = unlink(doc, block, true)
	end
	local list = parent.s[slotKey]
	if not list then
		list = {}
		parent.s[slotKey] = list
	end
	local at = place(doc, block, list, index, { p = parent.id, ps = slotKey })
	for offset, sibling in ipairs(following) do
		place(doc, sibling, list, at + offset, { p = parent.id, ps = slotKey })
	end
	return true
end

function d.attachToStack(doc, block, stack, index, following)
	if following then
		unlink(doc, block, false)
	else
		following = unlink(doc, block, true)
	end
	local at = place(doc, block, stack.ids, index, { st = stack.id })
	for offset, sibling in ipairs(following) do
		place(doc, sibling, stack.ids, at + offset, { st = stack.id })
	end
	return true
end

-- Pulls a block (and everything under it in its list) onto open canvas.
function d.detach(doc, block, x, y)
	local following = unlink(doc, block, true)
	local stack = d.newStack(doc, x, y)
	d.attachToStack(doc, block, stack, 1, following)
	return stack
end

function d.remove(doc, block)
	unlink(doc, block, false)
	local pending = { block }
	while #pending > 0 do
		local current = table.remove(pending)
		for _, ids in pairs(current.s or {}) do
			for _, id in ipairs(ids) do
				local child = doc.blocks[id]
				if child then pending[#pending + 1] = child end
			end
		end
		doc.blocks[current.id] = nil
	end
end

-- Deep copy onto the canvas at (x, y).
function d.duplicate(doc, block, x, y)
	local function copy(source)
		local made = { id = nextId(doc, "b"), k = source.k, f = {}, s = {} }
		for key, value in pairs(source.f or {}) do made.f[key] = value end
		doc.blocks[made.id] = made
		for slotKey, ids in pairs(source.s or {}) do
			local list = {}
			for _, id in ipairs(ids) do
				local child = doc.blocks[id]
				if child then
					local madeChild = copy(child)
					madeChild.p, madeChild.ps = made.id, slotKey
					list[#list + 1] = madeChild.id
				end
			end
			made.s[slotKey] = list
		end
		return made
	end

	local root = copy(block)
	local stack = d.newStack(doc, x, y)
	d.attachToStack(doc, root, stack, 1, {})
	return root, stack
end

-- Stacks read top-to-bottom, then left-to-right, the way a person would.
function d.sortedStacks(doc)
	local list = {}
	for _, stack in ipairs(doc.stacks) do
		if #stack.ids > 0 then list[#list + 1] = stack end
	end
	table.sort(list, function(a, b)
		if math.abs((a.y or 0) - (b.y or 0)) > 8 then return (a.y or 0) < (b.y or 0) end
		return (a.x or 0) < (b.x or 0)
	end)
	return list
end

function d.walk(doc, visit)
	local function step(block, depth)
		visit(block, depth)
		local def = c.get(block.k)
		for _, slot in ipairs(def and def.slots or {}) do
			for _, child in ipairs(d.children(doc, block, slot.key)) do
				step(child, depth + 1)
			end
		end
	end
	for _, stack in ipairs(d.sortedStacks(doc)) do
		for _, block in ipairs(d.stackBlocks(doc, stack)) do
			step(block, 0)
		end
	end
end

function d.count(doc)
	local total = 0
	d.walk(doc, function() total = total + 1 end)
	return total
end

-- Every name the document introduces, so IntelliSense can complete your own
-- variables next to the built-in ones.
function d.symbols(doc)
	local found = {}
	local function add(text, kind, detail)
		if not text or text == "" then return end
		for word in string.gmatch(text, "[%a_][%w_]*") do
			if not found[word] then
				found[word] = { name = word, kind = kind, detail = detail }
			end
		end
	end

	d.walk(doc, function(block)
		local def = c.get(block.k)
		if not def then return end
		if block.k == "svc" then
			local service = c.fieldValue(def, block, "name")
			found[service] = { name = service, kind = "service", detail = service }
			return
		end
		for key, field in pairs(def.fields) do
			local value = c.fieldValue(def, block, key)
			if field.kind == "name" then
				local detail
				if block.k == "create" then
					detail = c.fieldValue(def, block, "class")
				elseif block.k == "clone" then
					detail = "Instance"
				end
				add(value, block.k == "def" and "function" or "variable", detail)
			elseif field.kind == "params" then
				add(value, "parameter")
			end
		end
	end)

	local list = {}
	for _, entry in pairs(found) do list[#list + 1] = entry end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

--=============================================================================
-- storage
--=============================================================================

function d.toSave(doc)
	local blocks = {}
	for id, block in pairs(doc.blocks) do
		local slim = { id = id, k = block.k }
		for _ in pairs(block.f or {}) do
			slim.f = block.f
			break
		end
		for slotKey, ids in pairs(block.s or {}) do
			if #ids > 0 then
				slim.s = slim.s or {}
				slim.s[slotKey] = ids
			end
		end
		blocks[#blocks + 1] = slim
	end
	table.sort(blocks, function(a, b) return a.id < b.id end)

	local stacks = {}
	for _, stack in ipairs(doc.stacks) do
		if #stack.ids > 0 then
			stacks[#stacks + 1] = {
				id = stack.id,
				x = math.floor(stack.x or 0),
				y = math.floor(stack.y or 0),
				ids = stack.ids,
			}
		end
	end

	return {
		format = d.FORMAT,
		name = doc.name,
		nextId = doc.nextId,
		blocks = blocks,
		stacks = stacks,
	}
end

function d.fromSave(saved)
	if type(saved) ~= "table" or type(saved.blocks) ~= "table"
		or type(saved.stacks) ~= "table" then
		return nil, "that does not look like a DIErrorX project"
	end

	local doc = d.newDoc(saved.name)
	doc.nextId = saved.nextId or 1
	for _, slim in ipairs(saved.blocks) do
		if type(slim) == "table" and c.get(slim.k) then
			doc.blocks[slim.id] = {
				id = slim.id, k = slim.k, f = slim.f or {}, s = slim.s or {},
			}
		end
	end

	local claimed = {}
	for id, block in pairs(doc.blocks) do
		for slotKey, ids in pairs(block.s) do
			local kept = {}
			for _, childId in ipairs(ids) do
				local child = doc.blocks[childId]
				if child and not claimed[childId] then
					claimed[childId] = true
					child.p, child.ps = id, slotKey
					kept[#kept + 1] = childId
				end
			end
			block.s[slotKey] = kept
		end
	end

	for _, savedStack in ipairs(saved.stacks) do
		local stack = { id = savedStack.id, x = savedStack.x or 24,
			y = savedStack.y or 24, ids = {} }
		for _, id in ipairs(savedStack.ids or {}) do
			local block = doc.blocks[id]
			if block and not claimed[id] then
				claimed[id] = true
				block.st = stack.id
				stack.ids[#stack.ids + 1] = id
			end
		end
		if #stack.ids > 0 then doc.stacks[#doc.stacks + 1] = stack end
	end

	-- Anything a damaged file left stranded still shows up, off to one side,
	-- rather than silently disappearing.
	local stranded = {}
	for id, block in pairs(doc.blocks) do
		if not claimed[id] then stranded[#stranded + 1] = id end
	end
	table.sort(stranded)
	if #stranded > 0 then
		local stack = d.newStack(doc, 24, 24)
		for _, id in ipairs(stranded) do
			doc.blocks[id].st = stack.id
			stack.ids[#stack.ids + 1] = id
		end
	end

	return doc
end

return d
