-- Lexer + parser coverage.
local f = require(script.Parent.f)
local g = require(script.Parent.g)

local function mustParse(label, src)
	local chunk, err = g.parse(src)
	if not chunk then
		check(label, false, string.format("line %d col %d: %s", err.line, err.col, err.msg))
		return nil
	end
	TESTS_RUN = TESTS_RUN + 1
	return chunk
end

local function mustFail(label, src)
	local chunk, err = g.parse(src)
	check(label, chunk == nil and err ~= nil, "expected a parse error")
end

-- lexer ----------------------------------------------------------------------
local tk = f.tokenize('local a = 0x1F + 1e-3 .. "hi\\n" -- trailing')
eq("lexer: token count", #tk, 9)
eq("lexer: hex literal", tk[4].v, "0x1F")
eq("lexer: exponent literal", tk[6].v, "1e-3")
eq("lexer: comment captured", #tk.comments, 1)
eq("lexer: comment text", tk.comments[1].text, " trailing")

local longTk = f.tokenize("local s = [==[\nmulti ]] line\n]==]\nprint(s)")
eq("lexer: long string is one token", longTk[4].t, "string")
eq("lexer: line advanced past long string", longTk[5].line, 4)

local interp = f.tokenize("local s = `hp: {math.floor(h)}/{max}`")
eq("lexer: interpolated string is one token", interp[4].t, "string")

local badStr = select(2, f.tokenize('local s = "oops'))
eq("lexer: unfinished string reported", badStr.msg, "unfinished string")

-- statements -----------------------------------------------------------------
local chunk = mustParse("parse: locals", "local a, b: number = 1, 2")
eq("local: names", #chunk.body[1].names, 2)
eq("local: annotation kept as text", chunk.body[1].names[2].type, "number")

chunk = mustParse("parse: if/elseif/else", [[
if a then
	print(1)
elseif b then
	print(2)
else
	print(3)
end
]])
eq("if: clause count", #chunk.body[1].clauses, 2)
eq("if: else present", #chunk.body[1].els, 1)

chunk = mustParse("parse: numeric for", "for i = 1, 10, 2 do print(i) end")
eq("fornum: variable", chunk.body[1].var, "i")
eq("fornum: step present", chunk.body[1].step.value, "2")

chunk = mustParse("parse: generic for", "for i, v in ipairs(t) do print(v) end")
eq("forin: names", table.concat(chunk.body[1].names, ","), "i,v")

chunk = mustParse("parse: while/repeat", "while true do end repeat print(1) until done")
eq("while: kind", chunk.body[1].k, "while")
eq("repeat: kind", chunk.body[2].k, "repeat")

chunk = mustParse("parse: method definition", "function Cls:go(a: number): boolean return true end")
eq("func: dotted/colon name", chunk.body[1].name, "Cls:go")
check("func: flagged as method", chunk.body[1].isMethod)

chunk = mustParse("parse: compound assignment", "score += 10")
eq("compound: operator", chunk.body[1].op, "+")

chunk = mustParse("parse: continue", "for i = 1, 3 do continue end")
eq("continue: recognised in loop", chunk.body[1].body[1].k, "continue")

chunk = mustParse("parse: continue as a name", "local continue = 5 print(continue)")
eq("continue: still usable as an identifier", chunk.body[1].k, "local")

chunk = mustParse("parse: type alias", "type Point = { x: number, y: number }\nlocal p = 1")
eq("typedef: skipped cleanly", chunk.body[1].k, "typedef")
eq("typedef: next statement intact", chunk.body[2].k, "local")

chunk = mustParse("parse: exported alias", "export type Id = string | number\nreturn nil")
eq("typedef: export form", chunk.body[1].k, "typedef")

chunk = mustParse("parse: generic function", "local function id<T>(v: T): T return v end")
eq("localfunc: name", chunk.body[1].name, "id")

-- expressions ----------------------------------------------------------------
local function exprOf(src)
	local c = g.parse(src)
	return c and c.body[1].exprs[1]
end

local e = exprOf("local x = 1 + 2 * 3")
eq("precedence: * binds tighter than +", e.op, "+")
eq("precedence: right side is the product", e.right.op, "*")

e = exprOf('local x = "a" .. "b" .. "c"')
eq("concat: right associative", e.right.op, "..")

e = exprOf("local x = -a ^ 2")
eq("power: binds tighter than unary minus", e.k, "unop")
eq("power: operand is the exponent", e.operand.op, "^")

e = exprOf("local x = part.Position.Y")
eq("index: path flattening", g.pathOf(e), "part.Position.Y")

e = exprOf('local x = game:GetService("Players")')
eq("call: method name", e.method, "GetService")
eq("call: callee path", g.pathOf(e.fn), "game")

e = exprOf("local x = f{1, 2}")
eq("call: table-call sugar", e.k, "call")
e = exprOf('local x = require "thing"')
eq("call: string-call sugar", e.k, "call")

e = exprOf("local x = if a then 1 else 2")
eq("ifexp: recognised", e.k, "ifexp")

e = exprOf("local x = (v :: any).Name")
eq("typeassert: allows suffixes afterwards", e.k, "index")

e = exprOf("local t = { [1] = 'a', name = 'b', 'c' }")
eq("table: field kinds", e.fields[1].kind .. "," .. e.fields[2].kind .. "," .. e.fields[3].kind,
	"index,named,array")

-- source spans ---------------------------------------------------------------
local src = "local speed = walk * 2 + boost"
chunk = mustParse("parse: span source", src)
local value = chunk.body[1].exprs[1]
eq("span: expression slices back verbatim",
	string.sub(src, value.s, value.e), "walk * 2 + boost")

src = "part.Touched:Connect(function(hit)\n\tprint(hit)\nend)"
chunk = mustParse("parse: connect call", src)
local call = chunk.body[1].call
eq("span: whole statement slices back", string.sub(src, call.s, call.e), src)
eq("connect: last argument is a function", call.args[1].k, "func")
eq("connect: parameter name", call.args[1].params[1].name, "hit")

-- error handling --------------------------------------------------------------
mustFail("error: unbalanced end", "if a then print(1)")
mustFail("error: bare expression", "1 + 1")
mustFail("error: stray operator", "local = 5")

local _, err = g.parse("local a = 1\nlocal b = = 2")
eq("error: reports the offending line", err.line, 2)

-- a longer realistic script ----------------------------------------------------
chunk = mustParse("parse: full script", [[
--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local COOLDOWN = 1.5
local lastHit: { [Player]: number } = {}

type Damage = { amount: number, source: Instance? }

local function applyDamage(player: Player, dmg: Damage)
	local char = player.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health -= dmg.amount
		lastHit[player] = os.clock()
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid").Died:Connect(function()
			print(`{player.Name} died`)
		end)
	end)
end)

RunService.Heartbeat:Connect(function(dt)
	for player, at in pairs(lastHit) do
		if os.clock() - at > COOLDOWN then
			lastHit[player] = nil
		end
	end
end)

return { applyDamage = applyDamage }
]])
eq("full script: statement count", #chunk.body, 9)
eq("full script: ends with a return", chunk.body[9].k, "return")

-- awkward but legal Luau, and the emitted code for each ------------------------
local cases = {
	"local t = {} :: any",
	"local x = a and b or c",
	'local part = game:GetService("Workspace"):FindFirstChild("Baseplate")',
	"local f = function() end",
	"local a, b = table.unpack(t)",
	"for a, b, c in next, t, nil do end",
	"local n = #t + 1",
	"local n = -x^2",
	'local t = { [1] = "a"; y = 2, }',
	'local s = "a\\"b"',
	"local s = 'it\\'s'",
	"--[==[ long ]==]\nlocal x = 1",
	"type X<T> = { [string]: T }\nlocal y = 1",
	"local x: {[string]: number} = {}",
	"if a then elseif b then end",
	"function t.a.b.c:d() end",
	"local function f(...) return ... end",
	'print(("x"):rep(3))',
	"local s = [[multi\nline]]",
	"local x = y // 2",
	"for i = 1, 3 do for j = 1, 3 do continue end end",
	"export type Id = string\nreturn nil",
	"local n = 0b1010 + 1_000 + .5",
	"@native\nlocal function fast() return 1 end",
	"local ok = if a then 1 else 2",
	"local v = vec3.X",
	"t[#t + 1] = 5",
	"local s = `hi {name}, you have {n} coins`",
	"while true do task.wait() end",
	"local m = setmetatable({}, { __index = function(_, k) return k end })",
	"local co = coroutine.wrap(function() coroutine.yield(1) end)",
	"local r = workspace:Raycast(origin, direction, params)",
	"script.Parent.Changed:Connect(print)",
	"local n: number? = nil",
	"local fn: (number, string) -> boolean = f",
	"do end",
	"local a = (function() return 1 end)()",
	"return",
}
for _, source in ipairs(cases) do
	local label = string.gsub(source, "\n", " / ")
	local chunk, err = g.parse(source)
	check("parses: " .. label, chunk ~= nil,
		err and string.format("line %d: %s", err.line, err.msg) or nil)
end

-- forms Luau itself rejects must be rejected here too -----------------------------
for _, source in ipairs({
	"local x = a?.b",
	"local = 5",
	"if a then",
	"for i = 1 do end",
	"function() end",
	"local x = ",
}) do
	check("rejects: " .. source, (g.parse(source)) == nil)
end

report("parser")
if TESTS_FAILED > 0 then error("test failures", 0) end
