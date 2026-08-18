--!nonstrict
-- o  ·  application state, history and storage
--
-- One object holds the open document, the selection, the undo stack and the
-- saved projects.  Views never edit the document directly -- they go through
-- `app:mutate`, which snapshots for undo and tells everyone to redraw.  That is
-- the whole reason undo, autosave and the live code panel are not each other's
-- problem.

local d = require(script.Parent.d)
local c = require(script.Parent.c)

local HttpService = game:GetService("HttpService")

local o = {}

local KEY_PROJECTS = "ablocks.projects.v1"
local KEY_SETTINGS = "ablocks.settings.v1"
local KEY_CURRENT = "ablocks.current.v1"
local HISTORY_LIMIT = 50

-- Where each kind of script belongs.  The first entry is the default, and the
-- rest are what the Setup tab offers as alternatives.
o.DESTINATIONS = {
	Script = { "ServerScriptService", "Workspace", "ServerStorage" },
	LocalScript = { "StarterPlayer.StarterPlayerScripts", "StarterGui", "ReplicatedFirst" },
	ModuleScript = { "ReplicatedStorage", "ServerScriptService", "ServerStorage" },
}

o.KINDS = { "Script", "LocalScript", "ModuleScript" }

local DEFAULT_SETTINGS = {
	theme = "ink",
	zoom = 1,
	autoSave = true,
	scriptKind = "Script",
	destinations = {
		Script = "ServerScriptService",
		LocalScript = "StarterPlayer.StarterPlayerScripts",
		ModuleScript = "ReplicatedStorage",
	},
	showCode = true,
	banner = true,
	read = {},
}

local App = {}
App.__index = App

--=============================================================================
-- signals
--=============================================================================

function App:on(name, callback)
	local list = self.listeners[name]
	if not list then
		list = {}
		self.listeners[name] = list
	end
	list[#list + 1] = callback
	return function()
		for index, entry in ipairs(list) do
			if entry == callback then
				table.remove(list, index)
				return
			end
		end
	end
end

function App:emit(name, ...)
	for _, callback in ipairs(self.listeners[name] or {}) do
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[ABlocks] listener for '" .. name .. "' failed: " .. tostring(err))
		end
	end
end

--=============================================================================
-- storage helpers
--=============================================================================

local function readJson(plugin, key, fallback)
	local raw = plugin:GetSetting(key)
	if type(raw) ~= "string" or raw == "" then return fallback end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok then return fallback end
	return value
end

local function writeJson(plugin, key, value)
	local ok, raw = pcall(HttpService.JSONEncode, HttpService, value)
	if ok then plugin:SetSetting(key, raw) end
	return ok
end

--=============================================================================
-- construction
--=============================================================================

-- A canvas that shows what the thing does, for a first run.
local function starterDoc()
	local doc = d.newDoc("First project")
	local stack = d.newStack(doc, 32, 32)

	local note = d.create(doc, "comment")
	note.f.text = "touch this part to be sent back to the start"
	d.attachToStack(doc, note, stack, nil, {})

	local event = d.create(doc, "onTouch")
	event.f.part, event.f.hit = "script.Parent", "hit"
	d.attachToStack(doc, event, stack, nil, {})

	local find = d.create(doc, "humanoidOf")
	find.f.name, find.f.char = "hum", "hit.Parent"
	d.attachToSlot(doc, find, event, "body", nil, {})

	local guard = d.create(doc, "guard")
	guard.f.cond = "hum"
	d.attachToSlot(doc, guard, event, "body", nil, {})

	local move = d.create(doc, "teleportChar")
	move.f.char, move.f.x, move.f.y, move.f.z = "hit.Parent", "0", "10", "0"
	d.attachToSlot(doc, move, event, "body", nil, {})

	return doc
end

o.starterDoc = starterDoc

function o.newApp(plugin, widget)
	local app = setmetatable({
		plugin = plugin,
		widget = widget,
		listeners = {},
		undoStack = {},
		redoStack = {},
		selection = nil,
		hover = nil,
		tab = "build",
		dirty = false,
		lastSaved = nil,
		status = "",
	}, App)

	app.settings = {}
	local saved = readJson(plugin, KEY_SETTINGS, {})
	for key, value in pairs(DEFAULT_SETTINGS) do
		local stored = saved[key]
		if stored ~= nil and type(stored) == type(value) then
			app.settings[key] = stored
		else
			app.settings[key] = value
		end
	end

	app.projects = readJson(plugin, KEY_PROJECTS, nil)
	if type(app.projects) ~= "table" then app.projects = {} end

	local currentId = plugin:GetSetting(KEY_CURRENT)
	local project = nil
	for _, entry in ipairs(app.projects) do
		if entry.id == currentId then project = entry end
	end
	project = project or app.projects[1]

	if project then
		local restored = d.fromSave(project.doc)
		app.doc = restored or starterDoc()
		app.projectId = project.id
	else
		app.doc = starterDoc()
		app.projectId = nil
	end

	return app
end

--=============================================================================
-- editing
--=============================================================================

local function snapshot(app)
	return d.toSave(app.doc)
end

-- Runs `edit`, having first stored a snapshot for undo.  Returns whatever the
-- edit returned, so callers can chain.
function App:mutate(label, edit)
	local before = snapshot(self)
	local ok, result = pcall(edit, self.doc)
	if not ok then
		warn("[ABlocks] edit '" .. tostring(label) .. "' failed: " .. tostring(result))
		local restored = d.fromSave(before)
		if restored then self.doc = restored end
		self:emit("doc")
		return nil
	end

	self.undoStack[#self.undoStack + 1] = { label = label, save = before }
	if #self.undoStack > HISTORY_LIMIT then table.remove(self.undoStack, 1) end
	self.redoStack = {}
	self.dirty = true
	self:emit("doc")
	self:scheduleSave()
	return result
end

local function swapTo(app, save, otherStack, label)
	local current = snapshot(app)
	local restored = d.fromSave(save)
	if not restored then return false end
	restored.name = app.doc.name
	app.doc = restored
	otherStack[#otherStack + 1] = { label = label, save = current }
	if app.selection and not app.doc.blocks[app.selection] then
		app.selection = nil
		app:emit("select")
	end
	app.dirty = true
	app:emit("doc")
	app:scheduleSave()
	return true
end

function App:undo()
	local entry = table.remove(self.undoStack)
	if not entry then
		self:setStatus("nothing to undo")
		return false
	end
	swapTo(self, entry.save, self.redoStack, entry.label)
	self:setStatus("undid " .. (entry.label or "that"))
	return true
end

function App:redo()
	local entry = table.remove(self.redoStack)
	if not entry then
		self:setStatus("nothing to redo")
		return false
	end
	swapTo(self, entry.save, self.undoStack, entry.label)
	self:setStatus("redid " .. (entry.label or "that"))
	return true
end

-- For edits that have already happened -- typing in a field, dragging a block --
-- where the snapshot was taken before the interaction began.
function App:commit(label, beforeSave)
	if not beforeSave then return end
	self.undoStack[#self.undoStack + 1] = { label = label, save = beforeSave }
	if #self.undoStack > HISTORY_LIMIT then table.remove(self.undoStack, 1) end
	self.redoStack = {}
	self.dirty = true
	self:emit("doc")
	self:scheduleSave()
end

-- A snapshot to hand back to `commit` later.
function App:mark()
	return snapshot(self)
end

function App:canUndo() return #self.undoStack > 0 end
function App:canRedo() return #self.redoStack > 0 end

function App:select(blockId)
	if self.selection == blockId then return end
	self.selection = blockId
	self:emit("select", blockId)
end

function App:selected()
	return self.selection and self.doc.blocks[self.selection] or nil
end

function App:setStatus(text)
	self.status = text or ""
	self:emit("status", self.status)
end

--=============================================================================
-- documents
--=============================================================================

function App:setDoc(doc, label)
	self.undoStack[#self.undoStack + 1] = { label = label or "replace", save = snapshot(self) }
	if #self.undoStack > HISTORY_LIMIT then table.remove(self.undoStack, 1) end
	self.redoStack = {}
	self.doc = doc
	self.selection = nil
	self.dirty = true
	self:emit("select")
	self:emit("doc")
	self:scheduleSave()
end

function App:rename(name)
	self.doc.name = name
	self.dirty = true
	self:emit("doc")
	self:save()
end

--=============================================================================
-- projects
--=============================================================================

local function newId()
	return string.format("p%d", math.floor(os.clock() * 1000) % 100000000)
end

function App:save()
	local entry = nil
	for _, project in ipairs(self.projects) do
		if project.id == self.projectId then entry = project end
	end
	if not entry then
		entry = { id = self.projectId or newId() }
		self.projects[#self.projects + 1] = entry
		self.projectId = entry.id
	end
	entry.name = self.doc.name
	entry.doc = snapshot(self)
	entry.savedAt = os.time()
	entry.blocks = d.count(self.doc)

	writeJson(self.plugin, KEY_PROJECTS, self.projects)
	self.plugin:SetSetting(KEY_CURRENT, self.projectId)
	self.dirty = false
	self.lastSaved = os.time()
	self:emit("projects")
	self:setStatus("saved " .. self.doc.name)
	return true
end

-- Debounced autosave, so a drag does not write settings sixty times.
function App:scheduleSave()
	if not self.settings.autoSave then return end
	self.saveToken = (self.saveToken or 0) + 1
	local token = self.saveToken
	task.delay(2.5, function()
		if token == self.saveToken and self.dirty then self:save() end
	end)
end

function App:newProject(name)
	if self.dirty then self:save() end
	local doc = d.newDoc(name or "Untitled")
	self.projectId = newId()
	self.undoStack, self.redoStack = {}, {}
	self.doc = doc
	self.selection = nil
	self:emit("select")
	self:emit("doc")
	self:save()
	return doc
end

function App:openProject(id)
	if self.dirty then self:save() end
	for _, project in ipairs(self.projects) do
		if project.id == id then
			local restored = d.fromSave(project.doc)
			if not restored then
				self:setStatus("could not open " .. tostring(project.name))
				return false
			end
			self.projectId = id
			self.doc = restored
			self.undoStack, self.redoStack = {}, {}
			self.selection = nil
			self.dirty = false
			self.plugin:SetSetting(KEY_CURRENT, id)
			self:emit("select")
			self:emit("doc")
			self:setStatus("opened " .. self.doc.name)
			return true
		end
	end
	return false
end

function App:duplicateProject()
	local copy = d.fromSave(snapshot(self))
	copy.name = self.doc.name .. " copy"
	if self.dirty then self:save() end
	self.projectId = newId()
	self.doc = copy
	self.undoStack, self.redoStack = {}, {}
	self:emit("doc")
	self:save()
	return copy
end

function App:deleteProject(id)
	for index, project in ipairs(self.projects) do
		if project.id == id then
			table.remove(self.projects, index)
			writeJson(self.plugin, KEY_PROJECTS, self.projects)
			if self.projectId == id then
				local next_ = self.projects[1]
				if next_ then
					self:openProject(next_.id)
				else
					self:newProject("Untitled")
				end
			end
			self:emit("projects")
			return true
		end
	end
	return false
end

function App:exportProject()
	local ok, raw = pcall(HttpService.JSONEncode, HttpService, snapshot(self))
	if not ok then return nil, "could not encode this project" end
	return raw
end

function App:importProject(raw)
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok then return false, "that is not valid JSON" end
	local doc, err = d.fromSave(decoded)
	if not doc then return false, err or "that is not a ABlocks project" end
	self:setDoc(doc, "import project")
	return true
end

--=============================================================================
-- settings
--=============================================================================

function App:setSetting(key, value)
	self.settings[key] = value
	writeJson(self.plugin, KEY_SETTINGS, self.settings)
	self:emit("settings", key, value)
end

--=============================================================================
-- the script this project belongs to
--=============================================================================

-- "ServerScriptService.Main" -> the instance, or nil if it has gone.
function o.resolvePath(path)
	if type(path) ~= "string" or path == "" then return nil end
	local target = game
	for piece in string.gmatch(path, "[^%.]+") do
		if piece ~= "game" then
			local ok, child = pcall(function()
				if target == game then
					return game:FindFirstChild(piece) or game:GetService(piece)
				end
				return target:FindFirstChild(piece)
			end)
			if not ok or not child then return nil end
			target = child
		end
	end
	return target ~= game and target or nil
end

-- Remembers which script in the place this project was read out of, so the
-- code can be written back to it instead of piling up new copies.
function App:setOrigin(instance)
	if not instance then
		self.doc.origin = nil
		self:emit("doc")
		return
	end
	self.doc.origin = {
		kind = instance.ClassName,
		path = instance:GetFullName(),
		name = instance.Name,
	}
	self.dirty = true
	-- the window's write-out button reads this, so it has to hear about it
	self:emit("doc")
end

-- The originating script, if it still exists and is still a script.
function App:originInstance()
	local origin = self.doc.origin
	if not origin then return nil end
	local instance = o.resolvePath(origin.path)
	if instance and instance:IsA("LuaSourceContainer") then return instance end
	return nil
end

-- What kind of script this project is heading for: whatever it came from, or
-- whatever was chosen by hand.
function App:scriptKind()
	local origin = self.doc.origin
	if origin and origin.kind then return origin.kind end
	return self.settings.scriptKind or "Script"
end

function App:setScriptKind(kind)
	-- Choosing a kind by hand means this is no longer tied to the script it was
	-- read from, so the two cannot disagree.
	if self.doc.origin and self.doc.origin.kind ~= kind then
		self.doc.origin = nil
	end
	self:setSetting("scriptKind", kind)
	self:emit("doc")
end

-- Where a script of this kind should be put.
function App:destinationFor(kind)
	kind = kind or self:scriptKind()
	local chosen = self.settings.destinations and self.settings.destinations[kind]
	local options = o.DESTINATIONS[kind] or o.DESTINATIONS.Script
	for _, option in ipairs(options) do
		if option == chosen then return chosen end
	end
	return options[1]
end

function App:setDestination(kind, path)
	local destinations = {}
	for key, value in pairs(self.settings.destinations or {}) do
		destinations[key] = value
	end
	destinations[kind] = path
	self:setSetting("destinations", destinations)
end

--=============================================================================
-- facts about the document, for the status bar
--=============================================================================

function App:stats()
	local blocks, stacks, raw = 0, #self.doc.stacks, 0
	local byCat = {}
	d.walk(self.doc, function(block)
		blocks = blocks + 1
		local def = c.get(block.k)
		if def then
			byCat[def.cat] = (byCat[def.cat] or 0) + 1
			if def.raw then raw = raw + 1 end
		end
	end)
	return { blocks = blocks, stacks = stacks, raw = raw, byCat = byCat }
end

return o
