--!nonstrict
-- g  ·  Luau parser
--
-- Recursive descent over the token list from `f`.  The tree is deliberately
-- shallow: every node records the byte range it spans, and the importer copies
-- expressions straight out of the source with `src:sub(node.s, node.e)` instead
-- of re-printing them.  That is why round-tripping code through the block editor
-- never mangles an expression it did not understand.
--
--   local chunk, err = g.parse(src)
--   chunk.body -- array of statement nodes
--
-- Type annotations are parsed (so they cannot desync the statement stream) and
-- kept as source text, never as structure.

local f = require(script.Parent.f)

local g = {}

local BINPRI = {
	["or"] = { 1, 1 }, ["and"] = { 2, 2 },
	["<"] = { 3, 3 }, [">"] = { 3, 3 }, ["<="] = { 3, 3 },
	[">="] = { 3, 3 }, ["~="] = { 3, 3 }, ["=="] = { 3, 3 },
	[".."] = { 9, 8 },
	["+"] = { 10, 10 }, ["-"] = { 10, 10 },
	["*"] = { 11, 11 }, ["/"] = { 11, 11 }, ["//"] = { 11, 11 }, ["%"] = { 11, 11 },
	["^"] = { 14, 13 },
}
local UNARY_PRI = 12

local BLOCK_END = {
	["end"] = true, ["else"] = true, ["elseif"] = true, ["until"] = true,
}

local Parser = {}
Parser.__index = Parser

local function new(src, tokens)
	return setmetatable({ src = src, tk = tokens, i = 1 }, Parser)
end

function Parser:peek(offset)
	return self.tk[self.i + (offset or 0)]
end

function Parser:next()
	local t = self.tk[self.i]
	self.i = self.i + 1
	return t
end

function Parser:is(kind, value)
	local t = self.tk[self.i]
	return t.t == kind and (value == nil or t.v == value)
end

function Parser:accept(kind, value)
	if self:is(kind, value) then return self:next() end
	return nil
end

function Parser:fail(msg, token)
	token = token or self:peek()
	error({ __parse = true, msg = msg, line = token.line, col = token.col }, 0)
end

function Parser:expect(kind, value, what)
	local t = self:accept(kind, value)
	if not t then
		local got = self:peek()
		self:fail("expected " .. (what or ("'" .. tostring(value) .. "'")) ..
			" but found '" .. tostring(got.v) .. "'")
	end
	return t
end

function Parser:slice(a, b)
	return string.sub(self.src, a, b)
end

--=============================================================================
-- Types.  Parsed only so they cannot throw the statement stream off; the result
-- is the source text of the annotation.
--=============================================================================

function Parser:typeParams()
	-- '<' ... '>' with nesting, used for both generic declarations and args.
	local open = self:expect("sym", "<", "'<'")
	local depth = 1
	while depth > 0 do
		local t = self:peek()
		if t.t == "eof" then self:fail("unfinished type parameters", open) end
		if t.t == "sym" and t.v == "<" then
			depth = depth + 1
		elseif t.t == "sym" and t.v == ">" then
			depth = depth - 1
		elseif t.t == "sym" and t.v == ">=" then
			-- '>>' style closing shows up as '>=' only in odd code; treat the
			-- '>' half as a close and leave '=' behind is not representable, so
			-- bail out rather than silently mis-parse.
			self:fail("unexpected '>=' inside type parameters", t)
		end
		self:next()
	end
	return true
end

function Parser:typeTable()
	local open = self:expect("sym", "{", "'{'")
	while not self:is("sym", "}") do
		if self:is("eof") then self:fail("unfinished table type", open) end
		if self:accept("sym", "[") then
			self:parseType()
			self:expect("sym", "]", "']'")
			self:expect("sym", ":", "':'")
			self:parseType()
		elseif (self:is("name") or self:is("kw")) and self:peek(1).t == "sym"
			and self:peek(1).v == ":" then
			self:next()
			self:next()
			self:parseType()
		else
			self:parseType()
		end
		if not (self:accept("sym", ",") or self:accept("sym", ";")) then break end
	end
	self:expect("sym", "}", "'}'")
end

function Parser:typeSimple()
	if self:is("sym", "(") then
		local open = self:next()
		while not self:is("sym", ")") do
			if self:is("eof") then self:fail("unfinished type", open) end
			if (self:is("name") or self:is("sym", "...")) and self:peek(1).t == "sym"
				and self:peek(1).v == ":" then
				self:next()
				self:next()
			end
			self:parseType()
			if not self:accept("sym", ",") then break end
		end
		self:expect("sym", ")", "')'")
		if self:accept("sym", "->") then self:parseType() end
		return
	end
	if self:is("sym", "{") then
		self:typeTable()
		return
	end
	if self:is("sym", "<") then
		self:typeParams()
		self:typeSimple()
		return
	end
	if self:is("string") or self:is("kw", "nil") or self:is("kw", "true")
		or self:is("kw", "false") then
		self:next()
		return
	end
	if self:is("sym", "...") then
		self:next()
		self:parseType()
		return
	end
	if self:is("name", "typeof") and self:peek(1).t == "sym" and self:peek(1).v == "(" then
		self:next()
		self:next()
		self:expression()
		self:expect("sym", ")", "')'")
		return
	end
	if self:is("name") or self:is("kw", "function") then
		self:next()
		while self:is("sym", ".") and self:peek(1).t == "name" do
			self:next()
			self:next()
		end
		if self:is("sym", "<") then self:typeParams() end
		return
	end
	self:fail("expected a type but found '" .. tostring(self:peek().v) .. "'")
end

-- Returns the annotation's source text.
function Parser:parseType()
	local start = self:peek().s
	self:accept("sym", "?")
	self:typeSimple()
	while true do
		if self:accept("sym", "?") then
			-- optional marker, keep going
		elseif self:is("sym", "|") or self:is("sym", "&") then
			self:next()
			self:typeSimple()
		elseif self:accept("sym", "->") then
			self:typeSimple()
		else
			break
		end
	end
	return self:slice(start, self.tk[self.i - 1].e)
end

--=============================================================================
-- Expressions
--=============================================================================

function Parser:tableCons()
	local open = self:expect("sym", "{", "'{'")
	local fields = {}
	while not self:is("sym", "}") do
		if self:is("eof") then self:fail("unfinished table", open) end
		if self:is("sym", "[") then
			self:next()
			local key = self:expression()
			self:expect("sym", "]", "']'")
			self:expect("sym", "=", "'='")
			fields[#fields + 1] = { key = key, value = self:expression(), kind = "index" }
		elseif self:is("name") and self:peek(1).t == "sym" and self:peek(1).v == "=" then
			local name = self:next()
			self:next()
			fields[#fields + 1] = { name = name.v, value = self:expression(), kind = "named" }
		else
			fields[#fields + 1] = { value = self:expression(), kind = "array" }
		end
		if not (self:accept("sym", ",") or self:accept("sym", ";")) then break end
	end
	local close = self:expect("sym", "}", "'}'")
	return { k = "table", fields = fields, s = open.s, e = close.e }
end

-- '(' params ')' [':' type] block 'end'
function Parser:funcBody(startToken, nameInfo)
	if self:is("sym", "<") then self:typeParams() end
	self:expect("sym", "(", "'('")
	local params = {}
	while not self:is("sym", ")") do
		if self:accept("sym", "...") then
			if self:accept("sym", ":") then self:parseType() end
			params[#params + 1] = { name = "...", vararg = true }
		else
			local nameTok = self:expect("name", nil, "a parameter name")
			local ty = nil
			if self:accept("sym", ":") then ty = self:parseType() end
			params[#params + 1] = { name = nameTok.v, type = ty }
		end
		if not self:accept("sym", ",") then break end
	end
	self:expect("sym", ")", "')'")
	local retType = nil
	if self:accept("sym", ":") then retType = self:parseType() end
	local body = self:block()
	local last = self:expect("kw", "end", "'end'")
	return {
		k = "func", params = params, body = body, retType = retType,
		name = nameInfo and nameInfo.name or nil,
		isMethod = nameInfo and nameInfo.isMethod or false,
		s = startToken.s, e = last.e,
	}
end

function Parser:primary()
	local t = self:peek()
	if t.t == "name" then
		self:next()
		return { k = "name", name = t.v, s = t.s, e = t.e }
	end
	if t.t == "sym" and t.v == "(" then
		self:next()
		local inner = self:expression()
		local close = self:expect("sym", ")", "')'")
		return { k = "paren", inner = inner, s = t.s, e = close.e }
	end
	self:fail("unexpected '" .. tostring(t.v) .. "'")
	return nil
end

function Parser:callArgs(callee, startTok)
	local t = self:peek()
	if t.t == "string" then
		self:next()
		return { { k = "str", value = t.v, s = t.s, e = t.e } }, t.e
	end
	if t.t == "sym" and t.v == "{" then
		local tbl = self:tableCons()
		return { tbl }, tbl.e
	end
	self:expect("sym", "(", "'('")
	local args = {}
	while not self:is("sym", ")") do
		args[#args + 1] = self:expression()
		if not self:accept("sym", ",") then break end
	end
	local close = self:expect("sym", ")", "')'")
	return args, close.e
end

function Parser:suffixed()
	local node = self:primary()
	while true do
		local t = self:peek()
		if t.t == "sym" and t.v == "." and self:peek(1).t ~= "sym" then
			self:next()
			local nameTok = self:peek()
			if nameTok.t ~= "name" and nameTok.t ~= "kw" then
				self:fail("expected a field name after '.'")
			end
			self:next()
			node = {
				k = "index", obj = node, name = nameTok.v, dot = true,
				s = node.s, e = nameTok.e,
			}
		elseif t.t == "sym" and t.v == "[" then
			self:next()
			local key = self:expression()
			local close = self:expect("sym", "]", "']'")
			node = { k = "index", obj = node, key = key, s = node.s, e = close.e }
		elseif t.t == "sym" and t.v == ":" then
			local nameTok = self:peek(1)
			if nameTok.t ~= "name" then break end
			self:next()
			self:next()
			local args, endPos = self:callArgs()
			node = {
				k = "call", fn = node, method = nameTok.v, args = args,
				s = node.s, e = endPos,
			}
		elseif (t.t == "sym" and (t.v == "(" or t.v == "{")) or t.t == "string" then
			local args, endPos = self:callArgs()
			node = { k = "call", fn = node, args = args, s = node.s, e = endPos }
		else
			break
		end
	end
	return node
end

function Parser:simpleExpr()
	local t = self:peek()
	if t.t == "number" then
		self:next()
		return { k = "num", value = t.v, s = t.s, e = t.e }
	end
	if t.t == "string" then
		self:next()
		return { k = "str", value = t.v, s = t.s, e = t.e }
	end
	if t.t == "kw" and (t.v == "true" or t.v == "false") then
		self:next()
		return { k = "bool", value = t.v == "true", s = t.s, e = t.e }
	end
	if t.t == "kw" and t.v == "nil" then
		self:next()
		return { k = "nil", s = t.s, e = t.e }
	end
	if t.t == "sym" and t.v == "..." then
		self:next()
		return { k = "vararg", s = t.s, e = t.e }
	end
	if t.t == "sym" and t.v == "{" then
		return self:tableCons()
	end
	if t.t == "kw" and t.v == "function" then
		self:next()
		return self:funcBody(t, nil)
	end
	if t.t == "kw" and t.v == "if" then
		-- Luau's `if a then b else c` expression form.
		self:next()
		local cond = self:expression()
		self:expect("kw", "then", "'then'")
		local yes = self:expression()
		local clauses = { { cond = cond, value = yes } }
		while self:is("kw", "elseif") do
			self:next()
			local c = self:expression()
			self:expect("kw", "then", "'then'")
			clauses[#clauses + 1] = { cond = c, value = self:expression() }
		end
		self:expect("kw", "else", "'else'")
		local els = self:expression()
		return { k = "ifexp", clauses = clauses, els = els, s = t.s, e = els.e }
	end
	return self:suffixed()
end

function Parser:subExpr(limit)
	local node
	local t = self:peek()
	if (t.t == "kw" and t.v == "not") or (t.t == "sym" and (t.v == "-" or t.v == "#")) then
		self:next()
		local operand = self:subExpr(UNARY_PRI)
		node = { k = "unop", op = t.v, operand = operand, s = t.s, e = operand.e }
	else
		node = self:simpleExpr()
	end

	while true do
		local op = self:peek()
		local key = nil
		if op.t == "sym" or op.t == "kw" then key = op.v end
		local pri = key and BINPRI[key]
		if not pri or pri[1] <= limit then break end
		self:next()
		local rhs = self:subExpr(pri[2])
		node = { k = "binop", op = key, left = node, right = rhs, s = node.s, e = rhs.e }
	end

	while self:is("sym", "::") do
		self:next()
		local ty = self:parseType()
		node = {
			k = "typeassert", inner = node, type = ty,
			s = node.s, e = self.tk[self.i - 1].e,
		}
	end
	return node
end

function Parser:expression()
	return self:subExpr(0)
end

--=============================================================================
-- Statements
--=============================================================================

function Parser:block()
	local body = {}
	while true do
		local t = self:peek()
		if t.t == "eof" then break end
		if t.t == "kw" and BLOCK_END[t.v] then break end
		if t.t == "kw" and t.v == "return" then
			body[#body + 1] = self:returnStat()
			self:accept("sym", ";")
			break
		end
		local stat = self:statement()
		if stat then body[#body + 1] = stat end
	end
	return body
end

function Parser:returnStat()
	local kw = self:next()
	local exprs = {}
	local t = self:peek()
	local ends = t.t == "eof" or (t.t == "kw" and BLOCK_END[t.v])
		or (t.t == "sym" and t.v == ";")
	if not ends then
		repeat
			exprs[#exprs + 1] = self:expression()
		until not self:accept("sym", ",")
	end
	local last = self.tk[self.i - 1]
	return { k = "return", exprs = exprs, s = kw.s, e = last.e, line = kw.line }
end

-- `continue` and `type` are ordinary identifiers unless they start a statement
-- and are not being used as a value.
function Parser:softKeywordStat()
	local t = self:peek()
	local after = self:peek(1)
	if t.v == "continue" then
		local blocksIt = after.t == "sym" and (after.v == "=" or after.v == "," or
			after.v == "." or after.v == ":" or after.v == "[" or after.v == "(" or
			after.v == "{")
		if not blocksIt and after.t ~= "string" then
			self:next()
			return { k = "continue", s = t.s, e = t.e, line = t.line }
		end
	elseif t.v == "type" or t.v == "export" then
		local head = t.v == "export" and self:peek(1) or t
		local nameTok = t.v == "export" and self:peek(2) or self:peek(1)
		local follow = t.v == "export" and self:peek(3) or self:peek(2)
		if head.t == "name" and head.v == "type" and nameTok.t == "name"
			and follow.t == "sym" and (follow.v == "=" or follow.v == "<") then
			self:next()
			if t.v == "export" then self:next() end
			self:next()
			if self:is("sym", "<") then self:typeParams() end
			self:expect("sym", "=", "'='")
			self:parseType()
			local last = self.tk[self.i - 1]
			return { k = "typedef", s = t.s, e = last.e, line = t.line }
		end
	end
	return nil
end

local COMPOUND = {
	["+="] = "+", ["-="] = "-", ["*="] = "*", ["/="] = "/",
	["%="] = "%", ["^="] = "^", ["..="] = "..", ["//="] = "//",
}

function Parser:statement()
	local t = self:peek()

	if t.t == "sym" and t.v == ";" then
		self:next()
		return nil
	end

	-- Function attributes such as `@native`.
	if t.t == "sym" and t.v == "@" then
		self:next()
		self:expect("name", nil, "an attribute name")
		return self:statement()
	end

	if t.t == "kw" then
		local v = t.v
		if v == "local" then
			self:next()
			if self:is("kw", "function") then
				local fnKw = self:next()
				local nameTok = self:expect("name", nil, "a function name")
				local fn = self:funcBody(fnKw, { name = nameTok.v })
				return {
					k = "localfunc", name = nameTok.v, fn = fn,
					s = t.s, e = fn.e, line = t.line,
				}
			end
			local names = {}
			repeat
				local nameTok = self:expect("name", nil, "a variable name")
				local ty = nil
				if self:accept("sym", ":") then ty = self:parseType() end
				names[#names + 1] = { name = nameTok.v, type = ty }
			until not self:accept("sym", ",")
			local exprs = {}
			if self:accept("sym", "=") then
				repeat
					exprs[#exprs + 1] = self:expression()
				until not self:accept("sym", ",")
			end
			local last = self.tk[self.i - 1]
			return {
				k = "local", names = names, exprs = exprs,
				s = t.s, e = last.e, line = t.line,
			}
		elseif v == "function" then
			self:next()
			local nameTok = self:expect("name", nil, "a function name")
			local isMethod = false
			local parts = { nameTok.v }
			while true do
				if self:accept("sym", ".") then
					parts[#parts + 1] = "." .. self:expect("name", nil, "a name").v
				elseif self:is("sym", ":") and self:peek(1).t == "name" then
					self:next()
					parts[#parts + 1] = ":" .. self:next().v
					isMethod = true
					break
				else
					break
				end
			end
			local fullName = table.concat(parts)
			local fn = self:funcBody(t, { name = fullName, isMethod = isMethod })
			return {
				k = "func", name = fullName, isMethod = isMethod, fn = fn,
				s = t.s, e = fn.e, line = t.line,
			}
		elseif v == "do" then
			self:next()
			local body = self:block()
			local last = self:expect("kw", "end", "'end'")
			return { k = "do", body = body, s = t.s, e = last.e, line = t.line }
		elseif v == "while" then
			self:next()
			local cond = self:expression()
			self:expect("kw", "do", "'do'")
			local body = self:block()
			local last = self:expect("kw", "end", "'end'")
			return {
				k = "while", cond = cond, body = body,
				s = t.s, e = last.e, line = t.line,
			}
		elseif v == "repeat" then
			self:next()
			local body = self:block()
			self:expect("kw", "until", "'until'")
			local cond = self:expression()
			return {
				k = "repeat", cond = cond, body = body,
				s = t.s, e = cond.e, line = t.line,
			}
		elseif v == "if" then
			self:next()
			local clauses = {}
			local cond = self:expression()
			self:expect("kw", "then", "'then'")
			clauses[1] = { cond = cond, body = self:block() }
			while self:is("kw", "elseif") do
				self:next()
				local c = self:expression()
				self:expect("kw", "then", "'then'")
				clauses[#clauses + 1] = { cond = c, body = self:block() }
			end
			local els = nil
			if self:accept("kw", "else") then els = self:block() end
			local last = self:expect("kw", "end", "'end'")
			return {
				k = "if", clauses = clauses, els = els,
				s = t.s, e = last.e, line = t.line,
			}
		elseif v == "for" then
			self:next()
			local firstName = self:expect("name", nil, "a loop variable")
			if self:accept("sym", ":") then self:parseType() end
			if self:accept("sym", "=") then
				local from = self:expression()
				self:expect("sym", ",", "','")
				local to = self:expression()
				local step = nil
				if self:accept("sym", ",") then step = self:expression() end
				self:expect("kw", "do", "'do'")
				local body = self:block()
				local last = self:expect("kw", "end", "'end'")
				return {
					k = "fornum", var = firstName.v, from = from, to = to, step = step,
					body = body, s = t.s, e = last.e, line = t.line,
				}
			end
			local names = { firstName.v }
			while self:accept("sym", ",") do
				names[#names + 1] = self:expect("name", nil, "a loop variable").v
				if self:accept("sym", ":") then self:parseType() end
			end
			self:expect("kw", "in", "'in'")
			local exprs = {}
			repeat
				exprs[#exprs + 1] = self:expression()
			until not self:accept("sym", ",")
			self:expect("kw", "do", "'do'")
			local body = self:block()
			local last = self:expect("kw", "end", "'end'")
			return {
				k = "forin", names = names, exprs = exprs, body = body,
				s = t.s, e = last.e, line = t.line,
			}
		elseif v == "break" then
			self:next()
			return { k = "break", s = t.s, e = t.e, line = t.line }
		elseif v == "return" then
			return self:returnStat()
		end
		self:fail("unexpected '" .. v .. "'")
	end

	if t.t == "name" and (t.v == "continue" or t.v == "type" or t.v == "export") then
		local soft = self:softKeywordStat()
		if soft then return soft end
	end

	-- Expression statement: either a call or an assignment.
	local first = self:suffixed()
	local nextTok = self:peek()

	if nextTok.t == "sym" and COMPOUND[nextTok.v] then
		self:next()
		local value = self:expression()
		return {
			k = "compound", op = COMPOUND[nextTok.v], target = first, value = value,
			s = t.s, e = value.e, line = t.line,
		}
	end

	if nextTok.t == "sym" and (nextTok.v == "=" or nextTok.v == ",") then
		local targets = { first }
		while self:accept("sym", ",") do
			targets[#targets + 1] = self:suffixed()
		end
		self:expect("sym", "=", "'='")
		local exprs = {}
		repeat
			exprs[#exprs + 1] = self:expression()
		until not self:accept("sym", ",")
		local last = self.tk[self.i - 1]
		return {
			k = "assign", targets = targets, exprs = exprs,
			s = t.s, e = last.e, line = t.line,
		}
	end

	if first.k ~= "call" then
		self:fail("this line is not a statement -- did you mean to assign to it?", t)
	end
	return { k = "call", call = first, s = first.s, e = first.e, line = t.line }
end

--=============================================================================

-- Returns `chunk, nil` or `nil, err` where err = { msg, line, col }.
function g.parse(src)
	local tokens, lexErr = f.tokenize(src)
	if not tokens then return nil, lexErr end

	local p = new(src, tokens)
	local ok, result = pcall(function()
		local body = p:block()
		if not p:is("eof") then
			p:fail("unexpected '" .. tostring(p:peek().v) .. "'")
		end
		return body
	end)

	if not ok then
		if type(result) == "table" and result.__parse then
			return nil, { msg = result.msg, line = result.line, col = result.col }
		end
		return nil, { msg = tostring(result), line = 1, col = 1 }
	end

	return { body = result, comments = tokens.comments, src = src }, nil
end

-- Flattens `a.b.c` / `a:b` chains into text, or nil when the expression is not a
-- plain path.  Used by the importer to recognise things like `Players.PlayerAdded`.
function g.pathOf(node)
	if not node then return nil end
	if node.k == "name" then return node.name end
	if node.k == "index" and node.dot then
		local base = g.pathOf(node.obj)
		if not base then return nil end
		return base .. "." .. node.name
	end
	return nil
end

return g
