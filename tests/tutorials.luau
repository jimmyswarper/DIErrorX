-- The tutorials are content, but they still have to hold together: every
-- example must import, every block they name must exist, and the counts the
-- plugin advertises must be real.
local j = require(script.Parent.j)
local c = require(script.Parent.c)
local h = require(script.Parent.h)
local e = require(script.Parent.e)
local g = require(script.Parent.g)

eq("tutorials: at least twenty-five lessons", j.count() >= 25, true)
eq("tutorials: exactly ten category lessons", #j.categories(), 10)
check("tutorials: the rest are tips and technique", #j.tips() >= 15,
	#j.tips() .. " tips")

-- one lesson per teaching category, and no orphans ----------------------------
local covered = {}
for _, entry in ipairs(j.categories()) do
	check("category lesson names a real category: " .. entry.id,
		c.catById[entry.cat] ~= nil, entry.cat)
	check("only one lesson per category: " .. tostring(entry.cat), not covered[entry.cat])
	covered[entry.cat] = true
end
for _, cat in ipairs(c.cats) do
	if not cat.extra then
		check("every teaching category has a lesson: " .. cat.id, covered[cat.id] == true)
	end
end

-- shape ------------------------------------------------------------------------
local ids = {}
for _, entry in ipairs(j.tutorials) do
	local label = entry.id
	check("unique id: " .. label, not ids[label])
	ids[label] = true

	check("has a title: " .. label, entry.title and #entry.title > 5)
	check("has a blurb: " .. label, entry.blurb and #entry.blurb > 20)
	check("has a reading time: " .. label, type(entry.minutes) == "number"
		and entry.minutes > 0)
	check("has a level: " .. label, entry.level == "start" or entry.level == "build"
		or entry.level == "deep")
	check("has real content: " .. label, #entry.steps >= 5,
		#entry.steps .. " steps")

	local words = j.words(entry)
	check("is substantial: " .. label, words >= 180, words .. " words")

	-- Reading time is prose at 140 words a minute, plus time spent looking at
	-- each code sample, plus a minute for loading and reading the example.
	local codeSamples = 0
	for _, step in ipairs(entry.steps) do
		if step.code then codeSamples = codeSamples + 1 end
	end
	local expected = words / 140 + codeSamples * 0.6 + (entry.example and 1 or 0)
	check("advertised minutes are honest: " .. label,
		math.abs(entry.minutes - expected) <= 2.5,
		string.format("%d minutes advertised, %.1f estimated (%d words, %d samples)",
			entry.minutes, expected, words, codeSamples))

	local kinds = {}
	for _, step in ipairs(entry.steps) do
		local seen = false
		for _, key in ipairs({ "p", "h", "code", "blocks", "note", "warn", "list", "try" }) do
			if step[key] ~= nil then
				seen = true
				kinds[key] = true
			end
		end
		check("every step is a known kind: " .. label, seen)
	end
	check("mixes prose with something else: " .. label,
		kinds.p and (kinds.code or kinds.list or kinds.blocks))
end

-- named blocks exist ---------------------------------------------------------------
for _, entry in ipairs(j.tutorials) do
	for _, step in ipairs(entry.steps) do
		if step.blocks then
			for id in string.gmatch(step.blocks, "[^,]+") do
				check("lesson " .. entry.id .. " names a real block: " .. id,
					c.get(id) ~= nil)
			end
		end
	end
end

-- inline code parses ----------------------------------------------------------------
for _, entry in ipairs(j.tutorials) do
	for index, step in ipairs(entry.steps) do
		if step.code and not step.partial then
			-- snippets are fragments, so give them a home a fragment can live in
			local wrapped = "local function __snippet(...)\n" .. step.code .. "\nend"
			local chunk, err = g.parse(wrapped)
			check("code sample parses: " .. entry.id .. " step " .. index,
				chunk ~= nil, err and (err.msg .. "\n" .. step.code) or nil)
		end
	end
end

-- examples import, convert and survive a round trip -----------------------------------
local withExamples = 0
for _, entry in ipairs(j.tutorials) do
	if entry.example then
		withExamples = withExamples + 1
		local doc, report, err = h.fromCode(entry.example, entry.title)
		check("example imports: " .. entry.id, doc ~= nil,
			err and string.format("line %d: %s", err.line, err.msg) or nil)
		if doc then
			check("example produces blocks: " .. entry.id, report.total >= 3,
				report.total .. " statements")
			local code = e.generate(doc, { header = false })
			local again = e.generate(h.fromCode(code), { header = false })
			eq("example round-trips: " .. entry.id, again, code)
			-- an example full of raw blocks would teach nothing
			check("example mostly converts to real blocks: " .. entry.id,
				report.raw <= report.total / 4,
				report.raw .. " raw of " .. report.total)
		end
	end
end
check("most lessons carry a runnable example", withExamples >= 12,
	withExamples .. " examples")

-- search -----------------------------------------------------------------------------
check("search: finds by title", #j.search("leaderboard") > 0)
check("search: finds by body text", #j.search("magnitude") > 0)
eq("search: empty query returns everything", #j.search(""), j.count())
eq("search: nonsense returns nothing", #j.search("qzzxvv"), 0)
check("search: title matches rank first",
	j.search("shortcuts")[1].id == "tip-shortcuts")

-- house style --------------------------------------------------------------------------
for _, entry in ipairs(j.tutorials) do
	local text = entry.title .. " " .. entry.blurb
	for _, step in ipairs(entry.steps) do
		text = text .. " " .. (step.p or step.h or step.note or step.warn or step.try or "")
	end
	-- `!=` may be quoted when explaining that Luau does not use it
	local shouty = string.gsub(text, "!=", "")
	check("no exclamation marks: " .. entry.id, not string.find(shouty, "!", 1, true))
	check("no emoji: " .. entry.id, not string.find(text, "[\240-\244]"))
end

report("tutorials")
if TESTS_FAILED > 0 then error("test failures", 0) end
