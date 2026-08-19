--!nonstrict
-- h  ·  Luau -> blocks
--
-- Reads a script and rebuilds it on the canvas.  Two rules keep this honest:
--
--   1. Nothing is ever thrown away.  A statement no block matches becomes a
--      `raw Luau` block holding the exact source text, so importing a file you
--      do not fully understand still gives you a working, editable program.
--   2. Patterns are only matched when the block would emit the same code back.
--      `hum.WalkSpeed = 24` becomes a walk-speed block because that block
--      writes exactly that line; `hum.JumpPower = 50` stays raw because the
--      jump-power block writes two lines.  Import then export is stable.
--
-- Blank lines at the top level split the program into separate stacks, which is
-- also how the canvas ends up looking like the script you started with.

local c = require(script.Parent.c)
local d = require(script.Parent.d)
local g = require(script.Parent.g)

local h = {}

--=============================================================================
-- small helpers over the AST
--=============================================================================

local function slice(ctx, node)
	if not node then return "" end
	return string.sub(ctx.src, node.s, node.e)
end

local function argsText(ctx, args, from)
	from = from or 1
	if #args < from then return "" end
	return string.sub(ctx.src, args[from].s, args[#args].e)
end

-- A double-quoted string with nothing that needs escaping, unwrapped.
local function plainString(node)
	if not node or node.k ~= "str" then return nil end
	local inner = string.match(node.value, '^"([^"\\]*)"$')
	return inner
end

local function isCallTo(node, path)
	return node and node.k == "call" and not node.method and g.pathOf(node.fn) == path
end

local function isMethodCall(node, method)
	return node and node.k == "call" and node.method == method
end

local function isFunc(node)
	return node and node.k == "func"
end

local function paramText(params)
	local names = {}
	for _, param in ipairs(params or {}) do
		names[#names + 1] = param.name
	end
	return table.concat(names, ", ")
end

-- The callee written the way the `run` block wants it: `obj:Method` or `path`.
local function calleeText(ctx, node)
	if node.method then
		return slice(ctx, node.fn) .. ":" .. node.method
	end
	return slice(ctx, node.fn)
end

local function lineAt(ctx, offset)
	local lo, hi = 1, #ctx.lineStarts
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if ctx.lineStarts[mid] <= offset then lo = mid else hi = mid - 1 end
	end
	return lo
end

--=============================================================================
-- block construction
--=============================================================================

local function mk(ctx, kind, fields)
	local block = d.create(ctx.doc, kind)
	for key, value in pairs(fields or {}) do
		block.f[key] = value
	end
	ctx.matched = ctx.matched + 1
	return block
end

local function fill(ctx, block, slotKey, children)
	for _, child in ipairs(children) do
		d.attachToSlot(ctx.doc, child, block, slotKey, nil, {})
	end
	return block
end

local function rawBlock(ctx, node, why)
	local text = string.sub(ctx.src, node.s, node.e)

	-- Re-indent relative to the statement's own line so the block re-emits at
	-- whatever depth it is dropped into.
	local lineStart = ctx.lineStarts[lineAt(ctx, node.s)]
	local baseIndent = string.match(string.sub(ctx.src, lineStart, node.s - 1), "^[\t ]*") or ""
	if baseIndent ~= "" then
		text = string.gsub(text, "\n" .. baseIndent, "\n")
	end

	local block = d.create(ctx.doc, "raw")
	block.f.code = text
	ctx.raw = ctx.raw + 1
	if why then
		ctx.notes[#ctx.notes + 1] = {
			line = node.line or lineAt(ctx, node.s),
			text = why,
		}
	end
	return block
end

local convertList

--=============================================================================
-- statement conversion
--=============================================================================

-- `X.Touched:Connect(function(hit) ... end)` and friends.
local function convertConnect(ctx, call, verb)
	local handler = call.args[1]
	local params = paramText(handler.params)
	local signal = call.fn
	local body = convertList(ctx, handler.body)

	local kind, fields
	local path = g.pathOf(signal)
	local first = handler.params[1] and handler.params[1].name or ""

	if verb == "Connect" then
		if signal.k == "index" and signal.dot then
			local objText = slice(ctx, signal.obj)
			local event = signal.name
			if event == "Touched" then
				kind, fields = "onTouch", { part = objText, hit = first ~= "" and first or "hit" }
			elseif event == "PlayerAdded" and objText == "Players" then
				kind, fields = "onPlayerAdded", { player = first }
			elseif event == "PlayerRemoving" and objText == "Players" then
				kind, fields = "onPlayerRemoving", { player = first }
			elseif event == "CharacterAdded" then
				kind, fields = "onCharacterAdded", { player = objText, char = first }
			elseif event == "Died" then
				kind, fields = "onDied", { hum = objText }
			elseif event == "Heartbeat" and objText == "RunService" then
				kind, fields = "onHeartbeat", { dt = first }
			elseif event == "RenderStepped" and objText == "RunService" then
				kind, fields = "onRender", { dt = first }
			end
		elseif signal.k == "call" and signal.method then
			local objText = slice(ctx, signal.fn)
			local key = plainString(signal.args[1])
			if key then
				if signal.method == "GetPropertyChangedSignal" then
					kind, fields = "onPropertyChanged", { obj = objText, prop = key }
				elseif signal.method == "GetAttributeChangedSignal" then
					kind, fields = "onAttrChanged", { inst = objText, attr = key }
				elseif signal.method == "GetInstanceAddedSignal"
					and objText == "CollectionService" then
					kind, fields = "onTagAdded", { tag = key, inst = first }
				end
			end
		end
	end

	if not kind then
		kind = verb == "Once" and "onSignalOnce" or "onSignal"
		fields = { sig = slice(ctx, signal), args = params }
	end

	return fill(ctx, mk(ctx, kind, fields), "body", body)
end

-- Custom blocks compile to a call to a named helper, so a call to one of those
-- names rebuilds the block rather than arriving as a plain call.
local function customByFunctionName()
	local map = {}
	for _, def in ipairs(c.order) do
		if def.custom and def.custom.fn then map[def.custom.fn] = def end
	end
	return map
end

local function convertCustomCall(ctx, call, path, wanted)
	if not path then return nil end
	local def = customByFunctionName()[path]
	if not def then return nil end
	if def.custom.returnsHelper ~= (wanted == "value") then return nil end
	if #call.args ~= #def.custom.params then return nil end

	local fields = {}
	for index, key in ipairs(def.custom.params) do
		fields[key] = slice(ctx, call.args[index])
	end
	return def, fields
end

local function convertCallStatement(ctx, stmt)
	local call = stmt.call
	local args = call.args
	local path = not call.method and g.pathOf(call.fn) or nil

	local customDef, customFields = convertCustomCall(ctx, call, path, "statement")
	if customDef then
		return mk(ctx, customDef.id, customFields)
	end

	-- event connections
	if (call.method == "Connect" or call.method == "Once")
		and #args == 1 and isFunc(args[1]) then
		return convertConnect(ctx, call, call.method)
	end

	-- deferred work
	if isCallTo(call, "task.spawn") and #args == 1 and isFunc(args[1])
		and #args[1].params == 0 then
		return fill(ctx, mk(ctx, "spawn", {}), "body", convertList(ctx, args[1].body))
	end
	if isCallTo(call, "task.delay") and #args == 2 and isFunc(args[2])
		and #args[2].params == 0 then
		return fill(ctx, mk(ctx, "delay", { n = slice(ctx, args[1]) }), "body",
			convertList(ctx, args[2].body))
	end

	if path then
		local one = args[1] and slice(ctx, args[1]) or ""
		local two = args[2] and slice(ctx, args[2]) or ""
		local three = args[3] and slice(ctx, args[3]) or ""

		if path == "task.wait" and #args <= 1 then
			return mk(ctx, "wait", { n = one })
		elseif path == "print" and #args == 1 then
			local text = plainString(args[1])
			if text then return mk(ctx, "printText", { msg = text }) end
			return mk(ctx, "printValue", { value = one })
		elseif path == "warn" and #args == 1 then
			local text = plainString(args[1])
			if text then return mk(ctx, "warnText", { msg = text }) end
		elseif path == "assert" and #args == 2 then
			local text = plainString(args[2])
			if text then return mk(ctx, "assert", { cond = one, msg = text }) end
		elseif path == "table.insert" then
			if #args == 2 then
				return mk(ctx, "push", { list = one, value = two })
			elseif #args == 3 then
				return mk(ctx, "insertAt", { list = one, index = two, value = three })
			end
		elseif path == "table.remove" and #args == 2 then
			return mk(ctx, "removeAt", { list = one, index = two })
		elseif path == "table.sort" and #args == 1 then
			return mk(ctx, "sortList", { list = one })
		elseif path == "table.clear" and #args == 1 then
			return mk(ctx, "clearList", { list = one })
		end
	end

	if call.method then
		local objText = slice(ctx, call.fn)
		local one = args[1] and slice(ctx, args[1]) or ""
		local two = args[2] and slice(ctx, args[2]) or ""
		local method = call.method

		if method == "Destroy" and #args == 0 then
			return mk(ctx, "destroy", { obj = objText })
		elseif method == "Disconnect" and #args == 0 then
			return mk(ctx, "disconnect", { conn = objText })
		elseif method == "LoadCharacter" and #args == 0 then
			return mk(ctx, "respawn", { player = objText })
		elseif method == "PivotTo" and #args == 1 then
			local cf = args[1]
			if isCallTo(cf, "CFrame.new") and #cf.args == 3 then
				return mk(ctx, "teleportChar", {
					char = objText,
					x = slice(ctx, cf.args[1]), y = slice(ctx, cf.args[2]),
					z = slice(ctx, cf.args[3]),
				})
			end
			return mk(ctx, "pivotTo", { obj = objText, cf = one })
		elseif method == "TakeDamage" and #args == 1 then
			return mk(ctx, "damage", { hum = objText, n = one })
		elseif method == "SetAttribute" and #args == 2 then
			local key = plainString(args[1])
			if key then
				return mk(ctx, "setAttr", { inst = objText, attr = key, value = two })
			end
		elseif method == "AddTag" and objText == "CollectionService" and #args == 2 then
			local tag = plainString(args[2])
			if tag then return mk(ctx, "addTag", { obj = one, tag = tag }) end
		elseif method == "AddItem" and objText == "Debris" and #args == 2 then
			return mk(ctx, "cleanupAfter", { obj = one, time = two })
		elseif method == "Play" and #args == 0 and isMethodCall(call.fn, "Create") then
			local create = call.fn
			local info = create.args[2]
			if g.pathOf(create.fn) == "TweenService" and #create.args == 3
				and isCallTo(info, "TweenInfo.new") and #info.args == 1 then
				return mk(ctx, "tween", {
					obj = slice(ctx, create.args[1]),
					time = slice(ctx, info.args[1]),
					goal = slice(ctx, create.args[3]),
				})
			end
		end
	end

	return mk(ctx, "call", {
		name = calleeText(ctx, call),
		args = argsText(ctx, args),
	})
end

local function convertLocal(ctx, stmt)
	local names, exprs = stmt.names, stmt.exprs

	-- local ok, err = pcall(function() ... end)
	if #names == 2 and #exprs == 1 and isCallTo(exprs[1], "pcall")
		and #exprs[1].args == 1 and isFunc(exprs[1].args[1])
		and #exprs[1].args[1].params == 0 then
		local block = mk(ctx, "pcall", { ok = names[1].name, err = names[2].name })
		return fill(ctx, block, "body", convertList(ctx, exprs[1].args[1].body))
	end

	if #names == 1 and #exprs == 1 and not names[1].type then
		local name = names[1].name
		local value = exprs[1]
		local valueText = slice(ctx, value)

		if value.k == "call" then
			local customDef, customFields = convertCustomCall(ctx, value,
				not value.method and g.pathOf(value.fn) or nil, "value")
			if customDef then
				customFields.out = name
				return mk(ctx, customDef.id, customFields)
			end
		end

		if isCallTo(value, "Instance.new") and #value.args == 1 then
			local class = plainString(value.args[1])
			if class then return mk(ctx, "create", { name = name, class = class }) end
		end
		if isMethodCall(value, "GetService") and g.pathOf(value.fn) == "game" then
			local service = plainString(value.args[1])
			if service == name then return mk(ctx, "svc", { name = name }) end
		end
		if isCallTo(value, "require") and #value.args == 1 then
			return mk(ctx, "require", { name = name, path = slice(ctx, value.args[1]) })
		end
		if isMethodCall(value, "Clone") and #value.args == 0 then
			return mk(ctx, "clone", { name = name, obj = slice(ctx, value.fn) })
		end
		if isMethodCall(value, "FindFirstChild") and #value.args == 1 then
			local child = plainString(value.args[1])
			if child then
				return mk(ctx, "findChild",
					{ name = name, obj = slice(ctx, value.fn), child = child })
			end
		end
		if isMethodCall(value, "WaitForChild") and #value.args == 1 then
			local child = plainString(value.args[1])
			if child then
				return mk(ctx, "waitChild",
					{ name = name, obj = slice(ctx, value.fn), child = child })
			end
		end
		if isMethodCall(value, "FindFirstChildOfClass") and #value.args == 1
			and plainString(value.args[1]) == "Humanoid" then
			return mk(ctx, "humanoidOf", { name = name, char = slice(ctx, value.fn) })
		end
		if value.k == "table" and #value.fields == 0 then
			return mk(ctx, "newList", { name = name })
		end
		if valueText == "script.Parent" then
			return mk(ctx, "scriptParent", { name = name })
		end
		if valueText == "Players.LocalPlayer" then
			return mk(ctx, "localPlayer", { name = name })
		end
		if value.k == "index" and value.dot and value.name == "Character" then
			return mk(ctx, "charOf", { name = name, player = slice(ctx, value.obj) })
		end
		if value.k == "unop" and value.op == "#" then
			return mk(ctx, "countList", { name = name, list = slice(ctx, value.operand) })
		end
		if value.k == "table" then
			return mk(ctx, "listOf", { name = name,
				items = string.match(valueText, "^{%s*(.-)%s*}$") or valueText })
		end
		return mk(ctx, "local", { name = name, value = valueText })
	end

	if #names == 1 and #exprs == 1 and names[1].type then
		return mk(ctx, "localTyped", {
			name = names[1].name, type = names[1].type, value = slice(ctx, exprs[1]),
		})
	end

	if #names > 1 and #exprs > 0 then
		local list = {}
		for _, entry in ipairs(names) do list[#list + 1] = entry.name end
		return mk(ctx, "setMany", {
			names = table.concat(list, ", "),
			values = string.sub(ctx.src, exprs[1].s, exprs[#exprs].e),
		})
	end

	return nil
end

local function convertAssign(ctx, stmt)
	if #stmt.targets ~= 1 or #stmt.exprs ~= 1 then return nil end
	local target, value = stmt.targets[1], stmt.exprs[1]
	local targetText, valueText = slice(ctx, target), slice(ctx, value)

	-- x = not x
	if value.k == "unop" and value.op == "not" and slice(ctx, value.operand) == targetText then
		return mk(ctx, "flip", { var = targetText })
	end

	if target.k == "index" and target.dot then
		local objText = slice(ctx, target.obj)
		local prop = target.name

		if prop == "Parent" then
			return mk(ctx, "setParent", { obj = objText, parent = valueText })
		elseif prop == "Anchored" and value.k == "bool" then
			return mk(ctx, "anchor", { obj = objText, value = valueText })
		elseif prop == "WalkSpeed" then
			return mk(ctx, "walkSpeed", { hum = objText, n = valueText })
		elseif prop == "Position" and isCallTo(value, "Vector3.new") and #value.args == 3 then
			return mk(ctx, "moveTo", {
				obj = objText,
				x = slice(ctx, value.args[1]), y = slice(ctx, value.args[2]),
				z = slice(ctx, value.args[3]),
			})
		elseif prop == "Color" and isCallTo(value, "Color3.fromRGB") and #value.args == 3 then
			return mk(ctx, "paint", {
				obj = objText,
				r = slice(ctx, value.args[1]), g = slice(ctx, value.args[2]),
				b = slice(ctx, value.args[3]),
			})
		end
		return mk(ctx, "setProp", { obj = objText, prop = prop, value = valueText })
	end

	if target.k == "index" and target.key then
		return mk(ctx, "setKey", {
			tbl = slice(ctx, target.obj),
			key = slice(ctx, target.key),
			value = valueText,
		})
	end

	if valueText == "nil" then
		return mk(ctx, "clearVar", { name = targetText })
	end

	return mk(ctx, "set", { name = targetText, value = valueText })
end

-- Conditions get their own block when one reads better than a bare `if`.
local function conditionBlock(ctx, cond)
	if cond.k == "binop" then
		local op = cond.op
		local left, right = cond.left, cond.right
		if op == "and" then
			return "ifBoth", { a = slice(ctx, left), b = slice(ctx, right) }
		elseif op == "or" then
			return "ifEither", { a = slice(ctx, left), b = slice(ctx, right) }
		elseif op == "==" or op == "~=" or op == "<" or op == ">"
			or op == "<=" or op == ">=" then
			if op == "==" and isCallTo(left, "typeof") and #left.args == 1 then
				local kind = plainString(right)
				if kind then
					return "ifType", { value = slice(ctx, left.args[1]), type = kind }
				end
			end
			return "ifCompare", { a = slice(ctx, left), op = op, b = slice(ctx, right) }
		end
	elseif cond.k == "unop" and cond.op == "not" then
		return "ifNot", { cond = slice(ctx, cond.operand) }
	elseif cond.k == "call" then
		if isMethodCall(cond, "IsA") and #cond.args == 1 then
			local class = plainString(cond.args[1])
			if class then
				return "ifIsA", { inst = slice(ctx, cond.fn), class = class }
			end
		end
		if isMethodCall(cond, "HasTag") and g.pathOf(cond.fn) == "CollectionService"
			and #cond.args == 2 then
			local tag = plainString(cond.args[2])
			if tag then
				return "ifHasTag", { inst = slice(ctx, cond.args[1]), tag = tag }
			end
		end
		if isCallTo(cond, "table.find") and #cond.args == 2 then
			return "containsValue", {
				list = slice(ctx, cond.args[1]), value = slice(ctx, cond.args[2]),
			}
		end
		if isCallTo(cond, "string.find") and #cond.args == 4
			and cond.args[4].k == "bool" and cond.args[4].value
			and slice(ctx, cond.args[3]) == "1" then
			local needle = plainString(cond.args[2])
			if needle then
				return "containsText", { value = slice(ctx, cond.args[1]), needle = needle }
			end
		end
	end
	return "ifExists", { value = slice(ctx, cond) }
end

local function convertIf(ctx, stmt, clauseIndex)
	clauseIndex = clauseIndex or 1
	local clause = stmt.clauses[clauseIndex]
	local more = stmt.clauses[clauseIndex + 1] ~= nil
	local hasElse = more or (stmt.els ~= nil)

	-- if <cond> then return end  ->  a single-line exit block
	if not hasElse and #clause.body == 1 and clause.body[1].k == "return"
		and #clause.body[1].exprs == 0 then
		local cond = clause.cond
		if cond.k == "unop" and cond.op == "not" then
			return mk(ctx, "guard", { cond = slice(ctx, cond.operand) })
		end
		return mk(ctx, "earlyReturnIf", { cond = slice(ctx, cond) })
	end

	local kind, fields = conditionBlock(ctx, clause.cond)
	local block
	if hasElse then
		-- Only the plain if/else block carries an `otherwise` slot, so a
		-- decorated condition falls back to it with the condition inline.
		local condText = slice(ctx, clause.cond)
		block = mk(ctx, "ifelse", { cond = condText })
		fill(ctx, block, "body", convertList(ctx, clause.body))
		if more then
			fill(ctx, block, "els", { convertIf(ctx, stmt, clauseIndex + 1) })
		else
			fill(ctx, block, "els", convertList(ctx, stmt.els))
		end
		return block
	end

	block = mk(ctx, kind, fields)
	return fill(ctx, block, "body", convertList(ctx, clause.body))
end

local function convertForIn(ctx, stmt)
	local names, exprs = stmt.names, stmt.exprs
	local body = convertList(ctx, stmt.body)

	if #exprs == 1 and #names == 2 then
		local iter = exprs[1]
		if isCallTo(iter, "ipairs") and #iter.args == 1 then
			local listText = slice(ctx, iter.args[1])
			if names[1] == "_" and isMethodCall(iter.args[1], "GetPlayers")
				and g.pathOf(iter.args[1].fn) == "Players" then
				return fill(ctx, mk(ctx, "eachPlayer", { player = names[2] }), "body", body)
			end
			return fill(ctx, mk(ctx, "foripairs",
				{ i = names[1], v = names[2], tbl = listText }), "body", body)
		end
		if isCallTo(iter, "pairs") and #iter.args == 1 then
			return fill(ctx, mk(ctx, "forpairs",
				{ k = names[1], v = names[2], tbl = slice(ctx, iter.args[1]) }), "body", body)
		end
	end

	return fill(ctx, mk(ctx, "forin", {
		names = table.concat(names, ", "),
		iter = string.sub(ctx.src, exprs[1].s, exprs[#exprs].e),
	}), "body", body)
end

local function convertStatement(ctx, stmt)
	local kind = stmt.k

	if kind == "local" then
		return convertLocal(ctx, stmt) or rawBlock(ctx, stmt, "an unusual `local` line")
	elseif kind == "assign" then
		return convertAssign(ctx, stmt) or rawBlock(ctx, stmt, "a multiple assignment")
	elseif kind == "compound" then
		if stmt.op == "+" then
			return mk(ctx, "changeBy", {
				var = slice(ctx, stmt.target), n = slice(ctx, stmt.value),
			})
		end
		return rawBlock(ctx, stmt)
	elseif kind == "call" then
		return convertCallStatement(ctx, stmt)
	elseif kind == "if" then
		return convertIf(ctx, stmt)
	elseif kind == "while" then
		return fill(ctx, mk(ctx, "while", { cond = slice(ctx, stmt.cond) }), "body",
			convertList(ctx, stmt.body))
	elseif kind == "repeat" then
		return fill(ctx, mk(ctx, "repeat", { cond = slice(ctx, stmt.cond) }), "body",
			convertList(ctx, stmt.body))
	elseif kind == "fornum" then
		local body = convertList(ctx, stmt.body)
		if stmt.step then
			return fill(ctx, mk(ctx, "forstep", {
				var = stmt.var, from = slice(ctx, stmt.from),
				to = slice(ctx, stmt.to), step = slice(ctx, stmt.step),
			}), "body", body)
		end
		if stmt.var == "_" and slice(ctx, stmt.from) == "1" then
			return fill(ctx, mk(ctx, "repeatN", { n = slice(ctx, stmt.to) }), "body", body)
		end
		return fill(ctx, mk(ctx, "for", {
			var = stmt.var, from = slice(ctx, stmt.from), to = slice(ctx, stmt.to),
		}), "body", body)
	elseif kind == "forin" then
		return convertForIn(ctx, stmt)
	elseif kind == "do" then
		return fill(ctx, mk(ctx, "doblock", {}), "body", convertList(ctx, stmt.body))
	elseif kind == "localfunc" then
		return fill(ctx, mk(ctx, "def", {
			name = stmt.name, params = paramText(stmt.fn.params),
		}), "body", convertList(ctx, stmt.fn.body))
	elseif kind == "func" then
		local object, method = string.match(stmt.name, "^(.+):([%w_]+)$")
		if object then
			return fill(ctx, mk(ctx, "defMethod", {
				obj = object, name = method, params = paramText(stmt.fn.params),
			}), "body", convertList(ctx, stmt.fn.body))
		end
		return rawBlock(ctx, stmt, "a global function definition")
	elseif kind == "return" then
		if #stmt.exprs == 0 then return mk(ctx, "returnNone", {}) end
		return mk(ctx, "return", {
			value = string.sub(ctx.src, stmt.exprs[1].s, stmt.exprs[#stmt.exprs].e),
		})
	elseif kind == "break" then
		return mk(ctx, "break", {})
	elseif kind == "continue" then
		return mk(ctx, "continue", {})
	elseif kind == "typedef" then
		return rawBlock(ctx, stmt)
	end

	return rawBlock(ctx, stmt, "a statement with no matching block")
end

--=============================================================================
-- comments and lists
--=============================================================================

-- Emits any comments that appear before `limit`, as note blocks.
local function flushComments(ctx, limit, out)
	while ctx.commentAt <= #ctx.comments do
		local comment = ctx.comments[ctx.commentAt]
		if comment.s >= limit then break end
		ctx.commentAt = ctx.commentAt + 1
		if comment.long then
			local block = d.create(ctx.doc, "raw")
			block.f.code = string.sub(ctx.src, comment.s, comment.e)
			out[#out + 1] = block
		else
			local block = d.create(ctx.doc, "comment")
			block.f.text = (string.gsub(comment.text, "^%s", ""))
			out[#out + 1] = block
		end
	end
end

function convertList(ctx, statements)
	local out = {}
	for _, stmt in ipairs(statements or {}) do
		flushComments(ctx, stmt.s, out)
		out[#out + 1] = convertStatement(ctx, stmt)
	end
	if statements and #statements > 0 then
		local last = statements[#statements]
		flushComments(ctx, last.e, out)
	end
	return out
end

--=============================================================================
-- entry point
--=============================================================================

local BANNER = "built with ABlocks"

-- Drops the two-line banner this plugin writes, so re-importing your own
-- exported script does not stack up headers.
local function skipOwnBanner(ctx)
	local first = ctx.comments[1]
	local second = ctx.comments[2]
	if first and second and second.line <= 3
		and string.find(second.text, BANNER, 1, true) then
		ctx.commentAt = 3
		return string.match(first.text, "^%s*(.-)%s*$")
	end
	return nil
end

-- src -> document.  Returns doc, report  (or nil, nil, err on a parse failure).
function h.fromCode(src, name)
	src = string.gsub(src, "\r\n", "\n")
	local chunk, err = g.parse(src)
	if not chunk then
		return nil, nil, err
	end

	local lineStarts = { 1 }
	for offset in string.gmatch(src, "()\n") do
		lineStarts[#lineStarts + 1] = offset + 1
	end

	local doc = d.newDoc(name or "Imported")
	local ctx = {
		src = src, doc = doc, lineStarts = lineStarts,
		comments = chunk.comments, commentAt = 1,
		matched = 0, raw = 0, notes = {},
	}

	local banner = skipOwnBanner(ctx)
	if banner and banner ~= "" and not name then doc.name = banner end

	-- Top level splits into stacks wherever the source left a blank line.
	local groups = {}
	local current = nil
	local previousEnd = nil
	for _, stmt in ipairs(chunk.body) do
		local startLine = stmt.line
		local comment = ctx.comments[ctx.commentAt]
		if comment and comment.s < stmt.s then startLine = comment.line end
		if not current or (previousEnd and startLine > previousEnd + 1) then
			current = {}
			groups[#groups + 1] = current
		end
		current[#current + 1] = stmt
		previousEnd = lineAt(ctx, stmt.e)
	end

	local y = 24
	for _, group in ipairs(groups) do
		local blocks = convertList(ctx, group)
		if #blocks > 0 then
			local stack = d.newStack(doc, 24, y)
			for _, block in ipairs(blocks) do
				d.attachToStack(doc, block, stack, nil, {})
			end
			y = y + 40 * (#blocks + 1)
		end
	end

	-- Trailing comments after the last statement.
	local tail = {}
	flushComments(ctx, #src + 1, tail)
	if #tail > 0 then
		local stack = d.newStack(doc, 24, y)
		for _, block in ipairs(tail) do
			d.attachToStack(doc, block, stack, nil, {})
		end
	end

	return doc, {
		matched = ctx.matched,
		raw = ctx.raw,
		total = ctx.matched + ctx.raw,
		notes = ctx.notes,
		stacks = #doc.stacks,
	}
end

return h
