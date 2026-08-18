--!nonstrict
-- f  ·  Luau lexer
--
-- Turns source text into a flat token list.  Every token carries the byte range
-- it came from (`s`..`e`) so later stages can slice the original source back out
-- verbatim -- that is how the importer keeps expressions byte-perfect instead of
-- trying to pretty-print them again.
--
--   local tok, err = f.tokenize(src)
--   tok[1] = { t = "name", v = "print", s = 1, e = 5, line = 1, col = 1 }
--
-- Token kinds: name · number · string · kw · sym · eof
-- Comments are not returned inline; they land in `tok.comments` so the parser
-- never has to step over them but the importer can still recover them.

local f = {}

local KEYWORDS = {}
for word in string.gmatch(
	"and break do else elseif end false for function if in local nil not or " ..
	"repeat return then true until while", "%S+") do
	KEYWORDS[word] = true
end
f.KEYWORDS = KEYWORDS

-- Contextual keywords: real identifiers to the language, but highlighted and
-- treated as statement heads when they appear in the right position.
f.SOFT = { continue = true, type = true, export = true }

local SYM3 = { ["..."] = true, ["//="] = true, ["..="] = true }
local SYM2 = {
	["=="] = true, ["~="] = true, ["<="] = true, [">="] = true, [".."] = true,
	["::"] = true, ["->"] = true, ["+="] = true, ["-="] = true, ["*="] = true,
	["/="] = true, ["%="] = true, ["^="] = true, ["//"] = true,
}
local SYM1 = {}
for ch in string.gmatch("+-*/%^#<>=(){}[];:,.?&|", ".") do SYM1[ch] = true end

local function isDigit(c) return c >= "0" and c <= "9" end
local function isHex(c)
	return isDigit(c) or (c >= "a" and c <= "f") or (c >= "A" and c <= "F")
end
local function isAlpha(c)
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")
end
local function isAlnum(c) return isAlpha(c) or isDigit(c) end

-- Reads the `[==[` opener at `i`. Returns the level and the index just past the
-- opening bracket, or nil when `i` is not a long-bracket start.
local function longOpen(src, i)
	if string.sub(src, i, i) ~= "[" then return nil end
	local j = i + 1
	local level = 0
	while string.sub(src, j, j) == "=" do
		level = level + 1
		j = j + 1
	end
	if string.sub(src, j, j) ~= "[" then return nil end
	return level, j + 1
end

local function longClose(src, i, level)
	local close = "]" .. string.rep("=", level) .. "]"
	local a, b = string.find(src, close, i, true)
	if not a then return nil end
	return a, b
end

function f.tokenize(src)
	local tokens = {}
	local comments = {}
	local i = 1
	local n = #src
	local line = 1
	local lineStart = 1
	local err = nil

	local function fail(msg, at)
		err = { msg = msg, line = line, col = at - lineStart + 1, pos = at }
	end

	local function push(t, v, s, e)
		tokens[#tokens + 1] = {
			t = t, v = v, s = s, e = e, line = line, col = s - lineStart + 1,
		}
	end

	-- Advances `line`/`lineStart` across a span that may contain newlines.
	local function consumeSpan(from, to)
		local j = from
		while j <= to do
			local c = string.sub(src, j, j)
			if c == "\n" then
				line = line + 1
				lineStart = j + 1
			end
			j = j + 1
		end
	end

	while i <= n and not err do
		local c = string.sub(src, i, i)

		if c == "\n" then
			line = line + 1
			i = i + 1
			lineStart = i
		elseif c == " " or c == "\t" or c == "\r" then
			i = i + 1
		elseif c == "-" and string.sub(src, i + 1, i + 1) == "-" then
			local start = i
			local startLine = line
			local level, after = longOpen(src, i + 2)
			if level then
				local a, b = longClose(src, after, level)
				if not a then
					fail("unfinished long comment", start)
					break
				end
				consumeSpan(start, b)
				comments[#comments + 1] = {
					s = start, e = b, line = startLine, long = true,
					text = string.sub(src, after, a - 1),
				}
				i = b + 1
			else
				local stop = string.find(src, "\n", i, true) or (n + 1)
				comments[#comments + 1] = {
					s = start, e = stop - 1, line = startLine, long = false,
					text = string.sub(src, i + 2, stop - 1),
				}
				i = stop
			end
		elseif isAlpha(c) then
			local s = i
			while i <= n and isAlnum(string.sub(src, i, i)) do i = i + 1 end
			local word = string.sub(src, s, i - 1)
			push(KEYWORDS[word] and "kw" or "name", word, s, i - 1)
		elseif isDigit(c) or (c == "." and isDigit(string.sub(src, i + 1, i + 1))) then
			local s = i
			local two = string.lower(string.sub(src, i, i + 1))
			if two == "0x" then
				i = i + 2
				while i <= n and (isHex(string.sub(src, i, i)) or string.sub(src, i, i) == "_") do
					i = i + 1
				end
			elseif two == "0b" then
				i = i + 2
				while i <= n and string.find(string.sub(src, i, i), "[01_]") do
					i = i + 1
				end
			else
				local seenDot, seenExp = false, false
				while i <= n do
					local d = string.sub(src, i, i)
					if isDigit(d) or d == "_" then
						i = i + 1
					elseif d == "." and not seenDot and not seenExp then
						seenDot = true
						i = i + 1
					elseif (d == "e" or d == "E") and not seenExp then
						seenExp = true
						i = i + 1
						local sign = string.sub(src, i, i)
						if sign == "+" or sign == "-" then i = i + 1 end
					else
						break
					end
				end
			end
			push("number", string.sub(src, s, i - 1), s, i - 1)
		elseif c == '"' or c == "'" then
			local quote = c
			local s = i
			i = i + 1
			local closed = false
			while i <= n do
				local d = string.sub(src, i, i)
				if d == "\\" then
					if string.sub(src, i + 1, i + 1) == "\n" then
						line = line + 1
						lineStart = i + 2
					end
					i = i + 2
				elseif d == quote then
					closed = true
					i = i + 1
					break
				elseif d == "\n" then
					break
				else
					i = i + 1
				end
			end
			if not closed then
				fail("unfinished string", s)
				break
			end
			push("string", string.sub(src, s, i - 1), s, i - 1)
		elseif c == "`" then
			-- Interpolated string. Kept as one token: the importer only ever
			-- copies it back out as source text.
			local s = i
			i = i + 1
			local depth = 0
			local closed = false
			while i <= n do
				local d = string.sub(src, i, i)
				if d == "\\" then
					i = i + 2
				elseif d == "{" then
					depth = depth + 1
					i = i + 1
				elseif d == "}" then
					if depth > 0 then depth = depth - 1 end
					i = i + 1
				elseif d == "`" and depth == 0 then
					closed = true
					i = i + 1
					break
				else
					if d == "\n" then
						line = line + 1
						lineStart = i + 1
					end
					i = i + 1
				end
			end
			if not closed then
				fail("unfinished interpolated string", s)
				break
			end
			push("string", string.sub(src, s, i - 1), s, i - 1)
		elseif c == "[" and longOpen(src, i) then
			local s = i
			local startLine = line
			local level, after = longOpen(src, i)
			local a, b = longClose(src, after, level)
			if not a then
				fail("unfinished long string", s)
				break
			end
			local text = string.sub(src, s, b)
			consumeSpan(s, b)
			tokens[#tokens + 1] = {
				t = "string", v = text, s = s, e = b,
				line = startLine, col = s - lineStart + 1,
			}
			i = b + 1
		else
			local three = string.sub(src, i, i + 2)
			local two = string.sub(src, i, i + 1)
			if SYM3[three] then
				push("sym", three, i, i + 2)
				i = i + 3
			elseif SYM2[two] then
				push("sym", two, i, i + 1)
				i = i + 2
			elseif SYM1[c] then
				push("sym", c, i, i)
				i = i + 1
			else
				fail("unexpected character '" .. c .. "'", i)
				break
			end
		end
	end

	if err then return nil, err end

	tokens[#tokens + 1] = {
		t = "eof", v = "<eof>", s = n + 1, e = n, line = line, col = n + 1 - lineStart + 1,
	}
	tokens.comments = comments
	return tokens, nil
end

-- Convenience for the syntax highlighter: a lossy pass that never fails and
-- keeps comments in document order alongside everything else.
function f.scan(src)
	local tokens = f.tokenize(src)
	if not tokens then
		-- Highlighting must survive half-typed code, so retry line by line and
		-- keep whatever lexes cleanly.
		tokens = { comments = {} }
		local offset = 0
		for lineText in string.gmatch(src .. "\n", "([^\n]*)\n") do
			local got = f.tokenize(lineText)
			if got then
				for _, tk in ipairs(got) do
					if tk.t ~= "eof" then
						tokens[#tokens + 1] = {
							t = tk.t, v = tk.v, s = tk.s + offset, e = tk.e + offset,
						}
					end
				end
				for _, cm in ipairs(got.comments) do
					tokens.comments[#tokens.comments + 1] = {
						s = cm.s + offset, e = cm.e + offset,
					}
				end
			end
			offset = offset + #lineText + 1
		end
	end

	local merged = {}
	for _, tk in ipairs(tokens) do
		if tk.t ~= "eof" then merged[#merged + 1] = tk end
	end
	for _, cm in ipairs(tokens.comments) do
		merged[#merged + 1] = { t = "comment", v = "", s = cm.s, e = cm.e }
	end
	table.sort(merged, function(x, y) return x.s < y.s end)
	return merged
end

return f
