--!nonstrict
-- v  ·  block definitions: lists and sorting, text patterns, space and angles,
--       debug and timing
--
-- The programming-craft half of the palette: things that are not about Roblox
-- at all, but about getting a job done in Luau.

return function(D)

--=============================================================================
-- LISTS AND SORTING
--=============================================================================

D{ id = "algoRepeatValue", cat = "algo", group = "Building", label = "list of copies",
	head = "make {name} = a list of {n} copies of {value}",
	code = "local {name} = table.create({n}, {value})",
	fields = { name = "name|list|name", n = "num|10|how many", value = "expr|0|value" },
	doc = "`table.create` makes the list at its final size in one go, which " ..
		"is faster than inserting one at a time.",
	tags = "table create fill repeat prefill" }

D{ id = "algoRange", cat = "algo", group = "Building", label = "list of numbers",
	head = "make {name} = the numbers from {a} to {b}",
	code = {
		"local {name} = {}",
		"for value = {a}, {b} do",
		"\ttable.insert({name}, value)",
		"end",
	},
	fields = { name = "name|numbers|name", a = "num|1|from", b = "num|10|to" },
	doc = "A list you can shuffle or pick from, which a plain loop cannot do.",
	tags = "range numbers sequence list build" }

D{ id = "algoCopy", cat = "algo", group = "Building", label = "copy a list",
	head = "make {name} = a copy of {list}",
	code = "local {name} = table.clone({list})",
	fields = { name = "name|copy|name", list = "expr|list|list" },
	doc = "Without this you get a second name for the same table, and " ..
		"changing one changes both.",
	tags = "clone copy duplicate table shallow" }

D{ id = "algoDeepCopy", cat = "algo", group = "Building", label = "copy a list of tables",
	head = "make {name} = a copy of {source}, one level deep",
	code = {
		"local {name} = {}",
		"for key, value in pairs({source}) do",
		'\tif typeof(value) == "table" then',
		"\t\t{name}[key] = table.clone(value)",
		"\telse",
		"\t\t{name}[key] = value",
		"\tend",
		"end",
	},
	fields = { name = "name|copy|name", source = "expr|source|source" },
	doc = "Copies the tables one layer down as well. Tables inside those are " ..
		"still shared, which is enough for most saved data.",
	tags = "deep copy clone nested table" }

D{ id = "algoAppendAll", cat = "algo", group = "Building", label = "add a whole list",
	head = "add everything in {source} to {target}",
	code = {
		"for _, item in ipairs({source}) do",
		"\ttable.insert({target}, item)",
		"end",
	},
	fields = { target = "expr|all|list to grow", source = "expr|more|list to add" },
	doc = "Joins two lists end to end, leaving the source untouched.",
	tags = "append concat join extend list" }

D{ id = "algoMerge", cat = "algo", group = "Building", label = "merge records",
	head = "copy everything from {source} into {target}",
	code = {
		"for key, value in pairs({source}) do",
		"\t{target}[key] = value",
		"end",
	},
	fields = { target = "expr|settings|record to fill", source = "expr|overrides|record to copy" },
	doc = "Later values win. This is how a settings table takes overrides on " ..
		"top of its defaults.",
	tags = "merge record dictionary settings override" }

D{ id = "algoSlice", cat = "algo", group = "Building", label = "part of a list",
	head = "make {name} = items {from} to {to} of {list}",
	code = "local {name} = table.move({list}, {from}, {to}, 1, {})",
	fields = { name = "name|part|name", list = "expr|list|list", from = "num|1|from",
		to = "num|5|to" },
	doc = "`table.move` copies a run of items into a fresh list. Handy for " ..
		"showing one page of a long list.",
	tags = "slice sublist page move range" }

D{ id = "algoReverse", cat = "algo", group = "Building", label = "reverse a list",
	head = "reverse {list}",
	code = {
		"for index = 1, math.floor(#{list} / 2) do",
		"\t{list}[index], {list}[#{list} - index + 1] = {list}[#{list} - index + 1], {list}[index]",
		"end",
	},
	fields = { list = "expr|list|list" },
	doc = "Swaps the ends inward until they meet. Reverses in place rather " ..
		"than making a new list.",
	tags = "reverse flip order list swap" }

D{ id = "algoShuffle", cat = "algo", group = "Building", label = "shuffle a list",
	head = "shuffle {list}",
	code = {
		"for index = #{list}, 2, -1 do",
		"\tlocal swap = math.random(1, index)",
		"\t{list}[index], {list}[swap] = {list}[swap], {list}[index]",
		"end",
	},
	fields = { list = "expr|deck|list" },
	doc = "The proper shuffle: walk backwards swapping each item with a " ..
		"random earlier one. Every order comes up equally often.",
	tags = "shuffle random order deck fisher yates" }

D{ id = "algoUnique", cat = "algo", group = "Building", label = "remove duplicates",
	head = "make {name} = {list} with duplicates removed",
	code = {
		"local {name} = {}",
		"do",
		"\tlocal seen = {}",
		"\tfor _, item in ipairs({list}) do",
		"\t\tif not seen[item] then",
		"\t\t\tseen[item] = true",
		"\t\t\ttable.insert({name}, item)",
		"\t\tend",
		"\tend",
		"end",
	},
	fields = { name = "name|unique|name", list = "expr|list|list" },
	doc = "Keeps the first of each value and the original order. The `seen` " ..
		"table is what makes it fast rather than a search per item.",
	tags = "unique duplicates distinct set list" }

-- searching -------------------------------------------------------------------------
D{ id = "algoWhere", cat = "algo", group = "Searching", label = "where a value is",
	head = "make {name} = where {value} is in {list}",
	code = "local {name} = table.find({list}, {value})",
	fields = { name = "name|at|name", list = "expr|list|list", value = "expr|item|value" },
	doc = "Gives the position, or nil when it is not there. Works on any kind " ..
		"of value, including instances.",
	tags = "find index position search list" }

D{ id = "algoFirst", cat = "algo", group = "Searching", label = "the first item",
	head = "make {name} = the first item of {list}",
	code = "local {name} = {list}[1]",
	fields = { name = "name|first|name", list = "expr|list|list" },
	doc = "Nil when the list is empty, so check before using it.",
	tags = "first head front item list" }

D{ id = "algoLast", cat = "algo", group = "Searching", label = "the last item",
	head = "make {name} = the last item of {list}",
	code = "local {name} = {list}[#{list}]",
	fields = { name = "name|last|name", list = "expr|list|list" },
	doc = "`#list` is the position of the last item, so this reads the end " ..
		"without knowing how long it is.",
	tags = "last end back item list" }

D{ id = "algoRandomItem", cat = "algo", group = "Searching", label = "a random item",
	head = "make {name} = a random item from {list}",
	code = "local {name} = {list}[math.random(1, #{list})]",
	fields = { name = "name|picked|name", list = "expr|list|list" },
	doc = "Errors on an empty list, because `math.random(1, 0)` is not a " ..
		"range. Check the length first if it might be empty.",
	tags = "random pick choose item list" }

D{ id = "algoWeightedPick", cat = "algo", group = "Searching", label = "a weighted random pick",
	head = "make {name} = a random key from {weights}, by weight",
	code = {
		"local {name} = nil",
		"do",
		"\tlocal total = 0",
		"\tfor _, weight in pairs({weights}) do",
		"\t\ttotal = total + weight",
		"\tend",
		"\tlocal roll = math.random() * total",
		"\tfor key, weight in pairs({weights}) do",
		"\t\troll = roll - weight",
		"\t\tif roll <= 0 then",
		"\t\t\t{name} = key",
		"\t\t\tbreak",
		"\t\tend",
		"\tend",
		"end",
	},
	fields = { name = "name|prize|name",
		weights = "expr|{ common = 70, rare = 25, legendary = 5 }|weights" },
	doc = "Loot tables in one block. The weights need not add up to a hundred " ..
		"-- they are shares of the total, whatever it is.",
	tags = "weighted random loot chance drop rarity" }

D{ id = "algoCountIf", cat = "algo", group = "Searching", label = "count matching items",
	head = "make {name} = how many {item} in {list} have {test}",
	code = {
		"local {name} = 0",
		"for _, {item} in ipairs({list}) do",
		"\tif {test} then",
		"\t\t{name} = {name} + 1",
		"\tend",
		"end",
	},
	fields = { name = "name|matches|name", list = "expr|list|list", item = "name|item|each",
		test = "expr|item.alive|condition" },
	doc = "The condition can mention the name you gave each item, so `count " ..
		"how many item have item.health > 0` reads as you would say it.",
	tags = "count filter condition tally list" }

D{ id = "algoFilter", cat = "algo", group = "Searching", label = "keep matching items",
	head = "make {name} = every {item} in {list} where {test}",
	code = {
		"local {name} = {}",
		"for _, {item} in ipairs({list}) do",
		"\tif {test} then",
		"\t\ttable.insert({name}, {item})",
		"\tend",
		"end",
	},
	fields = { name = "name|kept|name", list = "expr|list|list", item = "name|item|each",
		test = "expr|item.alive|condition" },
	doc = "Builds a new list of the ones that pass, leaving the original " ..
		"alone.",
	tags = "filter where keep select list" }

D{ id = "algoMap", cat = "algo", group = "Searching", label = "change every item",
	head = "make {name} = every {item} in {list} turned into {value}",
	code = {
		"local {name} = {}",
		"for _, {item} in ipairs({list}) do",
		"\ttable.insert({name}, {value})",
		"end",
	},
	fields = { name = "name|changed|name", list = "expr|players|list", item = "name|item|each",
		value = "expr|item.Name|new value" },
	doc = "One in, one out. Turning a list of players into a list of their " ..
		"names is a line of this.",
	tags = "map transform convert list each" }

D{ id = "algoBestBy", cat = "algo", group = "Searching", label = "the best item",
	head = "make {name} = the {item} in {list} with the {mode} {value}",
	code = {
		"local {name} = nil",
		"do",
		"\tlocal best = nil",
		"\tfor _, {item} in ipairs({list}) do",
		"\t\tlocal score = {value}",
		"\t\tif best == nil or score {compare} best then",
		"\t\t\tbest = score",
		"\t\t\t{name} = {item}",
		"\t\tend",
		"\tend",
		"end",
	},
	fields = { name = "name|winner|name", list = "expr|players|list", item = "name|item|each",
		value = "expr|item.score|value", mode = "choice|highest|mode|highest,lowest",
		compare = "choice|>|comparison|>,<" },
	doc = "One pass, keeping whichever is best so far. Set the comparison to " ..
		"match the wording -- `>` for highest, `<` for lowest.",
	tags = "max min best highest lowest winner" }

D{ id = "algoSum", cat = "algo", group = "Searching", label = "add a list up",
	head = "make {name} = the total of {list}",
	code = {
		"local {name} = 0",
		"for _, value in ipairs({list}) do",
		"\t{name} = {name} + value",
		"end",
	},
	fields = { name = "name|total|name", list = "expr|scores|list" },
	doc = "Only works on a list of numbers -- add a check inside if the list " ..
		"might hold anything else.",
	tags = "sum total add numbers list" }

D{ id = "algoAverage", cat = "algo", group = "Searching", label = "average a list",
	head = "make {name} = the average of {list}",
	code = {
		"local {name} = 0",
		"if #{list} > 0 then",
		"\tlocal total = 0",
		"\tfor _, value in ipairs({list}) do",
		"\t\ttotal = total + value",
		"\tend",
		"\t{name} = total / #{list}",
		"end",
	},
	fields = { name = "name|mean|name", list = "expr|scores|list" },
	doc = "Guards against an empty list, which would otherwise divide by " ..
		"zero and give you a very strange number.",
	tags = "average mean total numbers list" }

-- changing ---------------------------------------------------------------------------
D{ id = "algoRemoveIf", cat = "algo", group = "Changing", label = "remove matching items",
	head = "remove every {item} from {list} where {test}",
	code = {
		"for index = #{list}, 1, -1 do",
		"\tlocal {item} = {list}[index]",
		"\tif {test} then",
		"\t\ttable.remove({list}, index)",
		"\tend",
		"end",
	},
	fields = { list = "expr|list|list", item = "name|item|each", test = "expr|item.dead|condition" },
	doc = "Counts backwards, which is the only safe way to remove while " ..
		"looping -- forwards, removing one makes the loop skip the next.",
	tags = "remove filter delete backwards list" }

D{ id = "algoSwapItems", cat = "algo", group = "Changing", label = "swap two items",
	head = "swap items {a} and {b} of {list}",
	code = "{list}[{a}], {list}[{b}] = {list}[{b}], {list}[{a}]",
	fields = { list = "expr|list|list", a = "num|1|first", b = "num|2|second" },
	doc = "Luau assigns both sides at once, so no temporary variable is " ..
		"needed.",
	tags = "swap exchange positions list" }

D{ id = "algoPopFirst", cat = "algo", group = "Changing", label = "take the first item",
	head = "make {name} = the first item taken off {list}",
	code = "local {name} = table.remove({list}, 1)",
	fields = { name = "name|next|name", list = "expr|queue|list" },
	doc = "Removes and hands back the front item, which is what makes a " ..
		"queue. Everything else shuffles down one.",
	tags = "queue pop shift first remove" }

D{ id = "algoPopLast", cat = "algo", group = "Changing", label = "take the last item",
	head = "make {name} = the last item taken off {list}",
	code = "local {name} = table.remove({list})",
	fields = { name = "name|top|name", list = "expr|stack|list" },
	doc = "Removes and hands back the end item, which is what makes a stack. " ..
		"Faster than taking from the front, since nothing has to shuffle.",
	tags = "stack pop last remove undo" }

D{ id = "algoEmptyCheck", cat = "algo", group = "Changing", label = "if a list is empty",
	head = "if {list} is empty then",
	code = "if #{list} == 0 then", tail = "end",
	fields = { list = "expr|list|list" },
	slots = { { key = "body" } },
	doc = "Checks the length rather than comparing to an empty table, which " ..
		"would never be equal.",
	tags = "empty length check zero list" }

D{ id = "algoFreeze", cat = "algo", group = "Changing", label = "lock a table",
	head = "lock {table} so nothing can change it",
	code = "table.freeze({table})",
	fields = { table = "expr|SETTINGS|table" },
	doc = "Any later attempt to change it errors instead of silently " ..
		"succeeding. Worth doing to a table of constants.",
	tags = "freeze constant readonly immutable" }

-- order ---------------------------------------------------------------------------------
D{ id = "algoSortNumbers", cat = "algo", group = "Order", label = "sort numbers",
	head = "sort {list} {order}",
	code = {
		"table.sort({list}, function(a, b)",
		"\treturn a {compare} b",
		"end)",
	},
	fields = { list = "expr|scores|list", order = "choice|lowest first|order|lowest first,highest first",
		compare = "choice|<|comparison|<,>" },
	doc = "Sorting rearranges the list itself. Set the comparison to match " ..
		"the wording: `<` puts the smallest first.",
	tags = "sort order numbers ascending descending" }

D{ id = "algoSortBy", cat = "algo", group = "Order", label = "sort by a field",
	head = "sort {list} by each item's {field}, {order}",
	code = {
		"table.sort({list}, function(a, b)",
		"\treturn a.{field} {compare} b.{field}",
		"end)",
	},
	fields = { list = "expr|players|list", field = "str|score|field name",
		order = "choice|highest first|order|highest first,lowest first",
		compare = "choice|>|comparison|>,<" },
	doc = "For a list of records. Sorting players by score before showing a " ..
		"leaderboard is exactly this.",
	tags = "sort field record leaderboard order" }

D{ id = "algoSortText", cat = "algo", group = "Order", label = "sort text",
	head = "sort {list} into alphabetical order",
	code = {
		"table.sort({list}, function(a, b)",
		"\treturn string.lower(a) < string.lower(b)",
		"end)",
	},
	fields = { list = "expr|names|list" },
	doc = "Lowercasing both sides first stops every capitalised word sorting " ..
		"ahead of every lowercase one.",
	tags = "sort alphabetical text names order" }

-- records --------------------------------------------------------------------------------
D{ id = "algoKeys", cat = "algo", group = "Records", label = "list the keys",
	head = "make {name} = the keys of {record}",
	code = {
		"local {name} = {}",
		"for key in pairs({record}) do",
		"\ttable.insert({name}, key)",
		"end",
	},
	fields = { name = "name|keys|name", record = "expr|record|record" },
	doc = "Turns a dictionary into a list you can sort or count. The order " ..
		"they come out in is not guaranteed.",
	tags = "keys dictionary record list pairs" }

D{ id = "algoValues", cat = "algo", group = "Records", label = "list the values",
	head = "make {name} = the values of {record}",
	code = {
		"local {name} = {}",
		"for _, value in pairs({record}) do",
		"\ttable.insert({name}, value)",
		"end",
	},
	fields = { name = "name|values|name", record = "expr|record|record" },
	doc = "The other half of the pair. Useful when you care what is in a " ..
		"dictionary but not what it is filed under.",
	tags = "values dictionary record list pairs" }

D{ id = "algoCountKeys", cat = "algo", group = "Records", label = "count the entries",
	head = "make {name} = how many entries {record} has",
	code = {
		"local {name} = 0",
		"for _ in pairs({record}) do",
		"\t{name} = {name} + 1",
		"end",
	},
	fields = { name = "name|entries|name", record = "expr|record|record" },
	doc = "`#` cannot count a dictionary -- it only works on numbered lists " ..
		"-- so counting means walking it.",
	tags = "count size dictionary record entries" }

D{ id = "algoTally", cat = "algo", group = "Records", label = "tally up",
	head = "make {name} = how many times each item appears in {list}",
	code = {
		"local {name} = {}",
		"for _, item in ipairs({list}) do",
		"\t{name}[item] = ({name}[item] or 0) + 1",
		"end",
	},
	fields = { name = "name|counts|name", list = "expr|list|list" },
	doc = "The `or 0` handles the first time each value is seen. Counting " ..
		"votes and inventory stacks are both this.",
	tags = "tally count occurrences histogram inventory" }

D{ id = "algoSetAdd", cat = "algo", group = "Records", label = "mark as seen",
	head = "mark {value} as present in {set}",
	code = "{set}[{value}] = true",
	fields = { set = "expr|seen|set", value = "expr|item|value" },
	doc = "A table used as a set: the value is the key. Checking membership " ..
		"is then instant, however many items there are.",
	tags = "set add mark seen membership" }

D{ id = "algoSetHas", cat = "algo", group = "Records", label = "if it has been seen",
	head = "if {set} contains {value} then",
	code = "if {set}[{value}] then", tail = "end",
	fields = { set = "expr|seen|set", value = "expr|item|value" },
	slots = { { key = "body" } },
	doc = "Far faster than searching a list, and the reason sets are worth " ..
		"the odd-looking table.",
	tags = "set contains check membership fast" }

D{ id = "algoSetRemove", cat = "algo", group = "Records", label = "unmark",
	head = "unmark {value} in {set}",
	code = "{set}[{value}] = nil",
	fields = { set = "expr|seen|set", value = "expr|item|value" },
	doc = "Setting a key to nil is how you delete it. There is no separate " ..
		"remove for dictionaries.",
	tags = "set remove delete nil unmark" }

--=============================================================================
-- TEXT PATTERNS
--=============================================================================

D{ id = "patMatches", cat = "pattern", group = "Finding", label = "if it matches a pattern",
	head = 'if {text} matches "{pattern}" then',
	code = 'if string.match({text}, "{pattern}") then', tail = "end",
	fields = { text = "expr|text|text", pattern = "str|%d+|pattern" },
	slots = { { key = "body" } },
	doc = "In a Luau pattern `%d` is a digit, `%a` a letter, `%s` a space and " ..
		"`+` means one or more. `%d+` finds any run of digits.",
	tags = "match pattern regex find check" }

D{ id = "patPull", cat = "pattern", group = "Finding", label = "pull a piece out",
	head = 'make {name} = the "{pattern}" inside {text}',
	code = 'local {name} = string.match({text}, "{pattern}")',
	fields = { name = "name|found|name", text = "expr|text|text", pattern = "str|%d+|pattern" },
	doc = "Brackets in the pattern say which part you want back. Nil when " ..
		"nothing matches.",
	tags = "match capture extract pattern pull" }

D{ id = "patPullTwo", cat = "pattern", group = "Finding", label = "pull two pieces out",
	head = 'make {a} and {b} = the two parts of "{pattern}" in {text}',
	code = 'local {a}, {b} = string.match({text}, "{pattern}")',
	fields = { a = "name|first|first name", b = "name|second|second name",
		text = "expr|text|text", pattern = "str|(%a+)=(%d+)|pattern" },
	doc = "Two sets of brackets give two answers. `(%a+)=(%d+)` splits " ..
		"`speed=20` into its name and its number.",
	tags = "match captures two extract pattern" }

D{ id = "patEach", cat = "pattern", group = "Finding", label = "for each match",
	head = 'for each "{pattern}" found in {text} as {item}',
	code = 'for {item} in string.gmatch({text}, "{pattern}") do', tail = "end",
	fields = { text = "expr|text|text", pattern = "str|%a+|pattern", item = "name|word|each" },
	slots = { { key = "body" } },
	doc = "Walks every match rather than just the first. `%a+` gives you each " ..
		"word in turn.",
	tags = "gmatch each loop pattern words" }

D{ id = "patWords", cat = "pattern", group = "Finding", label = "for each word",
	head = "for each word {word} in {text}",
	code = 'for {word} in string.gmatch({text}, "%S+") do', tail = "end",
	fields = { text = "expr|message|text", word = "name|word|each word" },
	slots = { { key = "body" } },
	doc = "`%S+` means a run of anything that is not a space, which is a " ..
		"good enough definition of a word for most purposes.",
	tags = "words split gmatch loop text" }

D{ id = "patLines", cat = "pattern", group = "Finding", label = "for each line",
	head = "for each line {line} in {text}",
	code = 'for {line} in string.gmatch({text}, "[^\\n]+") do', tail = "end",
	fields = { text = "expr|text|text", line = "name|line|each line" },
	slots = { { key = "body" } },
	doc = "`[^\\n]+` means a run of anything that is not a newline. Blank " ..
		"lines are skipped.",
	tags = "lines split newline gmatch loop" }

D{ id = "patCount", cat = "pattern", group = "Finding", label = "count matches",
	head = 'make {name} = how many "{pattern}" are in {text}',
	code = {
		"local {name} = 0",
		'for _ in string.gmatch({text}, "{pattern}") do',
		"\t{name} = {name} + 1",
		"end",
	},
	fields = { name = "name|found|name", text = "expr|text|text", pattern = "str|%a+|pattern" },
	doc = "Counting words in a message, or commas in a line of data.",
	tags = "count matches gmatch tally pattern" }

D{ id = "patStartsWith", cat = "pattern", group = "Finding", label = "if it starts with",
	head = 'if {text} starts with "{start}" then',
	code = 'if string.sub({text}, 1, #"{start}") == "{start}" then', tail = "end",
	fields = { text = "expr|text|text", start = "str|/|beginning" },
	slots = { { key = "body" } },
	doc = "Comparing the first characters is safer than a pattern, because " ..
		"punctuation in the text means nothing special here.",
	tags = "startswith prefix begins command check" }

D{ id = "patEndsWith", cat = "pattern", group = "Finding", label = "if it ends with",
	head = 'if {text} ends with "{ending}" then',
	code = 'if string.sub({text}, -#"{ending}") == "{ending}" then', tail = "end",
	fields = { text = "expr|filename|text", ending = "str|.png|ending" },
	slots = { { key = "body" } },
	doc = "A negative position counts back from the end, so this compares " ..
		"just the last few characters.",
	tags = "endswith suffix extension check" }

-- changing -------------------------------------------------------------------------------
D{ id = "patReplace", cat = "pattern", group = "Changing", label = "replace a pattern",
	head = 'make {name} = {text} with "{pattern}" replaced by "{with}"',
	code = 'local {name} = string.gsub({text}, "{pattern}", "{with}")',
	fields = { name = "name|cleaned|name", text = "expr|text|text",
		pattern = "str|%s+|pattern", with = "str| |replacement" },
	doc = "Replaces every match. In the replacement, `%1` stands for the " ..
		"first bracketed piece of the pattern.",
	tags = "gsub replace substitute pattern clean" }

D{ id = "patReplaceSome", cat = "pattern", group = "Changing", label = "replace the first few",
	head = 'make {name} = {text} with the first {count} "{pattern}" replaced by "{with}"',
	code = 'local {name} = string.gsub({text}, "{pattern}", "{with}", {count})',
	fields = { name = "name|changed|name", text = "expr|text|text", pattern = "str|a|pattern",
		with = "str|b|replacement", count = "num|1|how many" },
	doc = "The last number caps how many are replaced, which is how you " ..
		"change only the first occurrence.",
	tags = "gsub replace limit first pattern" }

D{ id = "patTrim", cat = "pattern", group = "Changing", label = "trim the spaces",
	head = "make {name} = {text} with the spaces trimmed off each end",
	code = 'local {name} = string.match({text}, "^%s*(.-)%s*$")',
	fields = { name = "name|trimmed|name", text = "expr|typed|text" },
	doc = "Anything a player types is worth trimming. `.-` means as little " ..
		"as possible, which is what stops it eating the middle.",
	tags = "trim strip whitespace clean input" }

D{ id = "patPad", cat = "pattern", group = "Changing", label = "pad to a width",
	head = "make {name} = {text} padded to {width} characters on the {side}",
	code = {
		"local {name} = tostring({text})",
		"if #{name} < {width} then",
		'\tlocal gap = string.rep(" ", {width} - #{name})',
		'\tif "{side}" == "left" then',
		"\t\t{name} = gap .. {name}",
		"\telse",
		"\t\t{name} = {name} .. gap",
		"\tend",
		"end",
	},
	fields = { name = "name|padded|name", text = "expr|score|text", width = "num|8|width",
		side = "choice|left|side|left,right" },
	doc = "A minus sign pads on the right, nothing pads on the left. Lining " ..
		"up columns of text in the output window needs this.",
	tags = "pad align columns format width" }

D{ id = "patRepeat", cat = "pattern", group = "Changing", label = "repeat text",
	head = "make {name} = \"{text}\" repeated {count} times",
	code = 'local {name} = string.rep("{text}", {count})',
	fields = { name = "name|bar|name", text = "str|=|text", count = "num|20|times" },
	doc = "Drawing a bar out of characters, or indenting by a level, is one " ..
		"of these.",
	tags = "rep repeat string bar indent" }

D{ id = "patCapitalise", cat = "pattern", group = "Changing", label = "capitalise",
	head = "make {name} = {text} with its first letter capitalised",
	code = "local {name} = string.upper(string.sub({text}, 1, 1)) .. string.sub({text}, 2)",
	fields = { name = "name|proper|name", text = "expr|word|text" },
	doc = "Upper-cases the first character and glues the rest back on " ..
		"unchanged.",
	tags = "capitalise upper first letter proper" }

D{ id = "patTitleCase", cat = "pattern", group = "Changing", label = "capitalise every word",
	head = "make {name} = {text} with every word capitalised",
	code = 'local {name} = string.gsub({text}, "(%a)([%w]*)", function(first, rest)\n' ..
		"\treturn string.upper(first) .. string.lower(rest)\n" ..
		"end)",
	fields = { name = "name|title|name", text = "expr|text|text" },
	doc = "Handing gsub a function lets you decide the replacement per match, " ..
		"which is far more powerful than a fixed string.",
	tags = "title case capitalise words gsub function" }

D{ id = "patShorten", cat = "pattern", group = "Changing", label = "shorten with dots",
	head = "make {name} = {text} shortened to {width} characters",
	code = {
		"local {name} = {text}",
		"if #{name} > {width} then",
		'\t{name} = string.sub({name}, 1, {width} - 3) .. "..."',
		"end",
	},
	fields = { name = "name|short|name", text = "expr|title|text", width = "num|20|width" },
	doc = "Cuts long names down to fit a button, leaving room for the dots so " ..
		"the result is never longer than asked for.",
	tags = "truncate shorten ellipsis fit label" }

D{ id = "patEscape", cat = "pattern", group = "Changing", label = "make text safe as a pattern",
	head = "make {name} = {text} made safe to use as a pattern",
	code = 'local {name} = string.gsub({text}, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")',
	fields = { name = "name|safe|name", text = "expr|typed|text" },
	doc = "Characters like `.` and `-` mean something special in a pattern. " ..
		"Escaping them first lets you search for text a player typed.",
	tags = "escape pattern magic characters safe search" }

-- cleaning up ----------------------------------------------------------------------------
D{ id = "patDigitsOnly", cat = "pattern", group = "Cleaning", label = "keep only digits",
	head = "make {name} = only the digits in {text}",
	code = 'local {name} = string.gsub({text}, "%D", "")',
	fields = { name = "name|digits|name", text = "expr|typed|text" },
	doc = "`%D` means anything that is not a digit. Replacing them with " ..
		"nothing leaves the number.",
	tags = "digits numbers strip clean filter" }

D{ id = "patLettersOnly", cat = "pattern", group = "Cleaning", label = "keep only letters",
	head = "make {name} = only the letters and spaces in {text}",
	code = 'local {name} = string.gsub({text}, "[^%a%s]", "")',
	fields = { name = "name|clean|name", text = "expr|typed|text" },
	doc = "Strips punctuation and numbers. A rough way to tidy up anything " ..
		"typed by a player.",
	tags = "letters strip punctuation clean filter" }

D{ id = "patIsNumber", cat = "pattern", group = "Cleaning", label = "if it is a number",
	head = "if {text} is a number then",
	code = "if tonumber({text}) then", tail = "end",
	fields = { text = "expr|typed|text" },
	slots = { { key = "body" } },
	doc = "`tonumber` gives nil for anything that is not one, which makes it " ..
		"the check as well as the conversion.",
	tags = "tonumber check number valid input" }

D{ id = "patFilterText", cat = "pattern", group = "Cleaning", label = "filter for safety",
	head = "make {name} = {text} filtered for {player}",
	code = {
		"local {name} = \"\"",
		"do",
		"\tlocal ok, filtered = pcall(function()",
		"\t\treturn TextService:FilterStringAsync({text}, {player}.UserId)",
		"\tend)",
		"\tif ok then",
		"\t\t{name} = filtered:GetNonChatStringForBroadcastAsync()",
		"\tend",
		"end",
	},
	fields = { name = "name|safe|name", text = "expr|typed|text", player = "expr|player|who wrote it" },
	needs = { "TextService" }, side = "server",
	doc = "Any text one player typed that another will see has to go through " ..
		"this. It is a rule, not a suggestion, and it only works on the server.",
	tags = "filterstringasync filter safety chat moderation" }

-- numbers and dates ---------------------------------------------------------------------------
D{ id = "patCommas", cat = "pattern", group = "Numbers", label = "add thousands separators",
	head = "make {name} = {n} with commas between the thousands",
	code = {
		"local {name} = tostring(math.floor({n}))",
		"while true do",
		"\tlocal replaced",
		'\t{name}, replaced = string.gsub({name}, "^(-?%d+)(%d%d%d)", "%1,%2")',
		"\tif replaced == 0 then",
		"\t\tbreak",
		"\tend",
		"end",
	},
	fields = { name = "name|pretty|name", n = "expr|coins|number" },
	doc = "Works from the right in threes until there is nothing left to " ..
		"split. 1234567 becomes 1,234,567.",
	tags = "commas thousands format number pretty" }

D{ id = "patShortNumber", cat = "pattern", group = "Numbers", label = "shorten a big number",
	head = "make {name} = {n} written short",
	code = {
		"local {name}",
		"do",
		"\tlocal value = {n}",
		"\tif value >= 1000000 then",
		'\t\t{name} = string.format("%.1fM", value / 1000000)',
		"\telseif value >= 1000 then",
		'\t\t{name} = string.format("%.1fK", value / 1000)',
		"\telse",
		"\t\t{name} = tostring(math.floor(value))",
		"\tend",
		"end",
	},
	fields = { name = "name|short|name", n = "expr|coins|number" },
	doc = "1500 becomes 1.5K and 2400000 becomes 2.4M, which is how most " ..
		"games show big numbers on a button.",
	tags = "abbreviate short number k m suffix" }

D{ id = "patClock", cat = "pattern", group = "Numbers", label = "seconds as a clock",
	head = "make {name} = {seconds} written as minutes and seconds",
	code = 'local {name} = string.format("%d:%02d", math.floor({seconds} / 60), ' ..
		"math.floor({seconds} % 60))",
	fields = { name = "name|clock|name", seconds = "expr|timeLeft|seconds" },
	doc = "`%02d` pads to two digits, which is what stops 3:5 appearing " ..
		"instead of 3:05.",
	tags = "time clock minutes seconds format countdown" }

D{ id = "patLongClock", cat = "pattern", group = "Numbers", label = "seconds as hours",
	head = "make {name} = {seconds} written as hours, minutes and seconds",
	code = 'local {name} = string.format("%d:%02d:%02d", math.floor({seconds} / 3600), ' ..
		"math.floor({seconds} % 3600 / 60), math.floor({seconds} % 60))",
	fields = { name = "name|clock|name", seconds = "expr|played|seconds" },
	doc = "For play time and long timers. Same idea as the shorter version, " ..
		"with hours in front.",
	tags = "time hours clock format playtime" }

D{ id = "patPlural", cat = "pattern", group = "Numbers", label = "pluralise",
	head = 'make {name} = {n} and "{word}", made plural if needed',
	code = 'local {name} = {n} .. " {word}" .. ({n} == 1 and "" or "s")',
	fields = { name = "name|label|name", n = "expr|count|number", word = "str|coin|word" },
	doc = "`1 coin` and `2 coins` without an if block. Only works for words " ..
		"that pluralise with an s.",
	tags = "plural singular grammar count label" }

D{ id = "patDate", cat = "pattern", group = "Numbers", label = "today's date",
	head = "make {name} = today's date as text",
	code = 'local {name} = os.date("{format}")',
	fields = { name = "name|today|name", format = "str|%d %B %Y|format" },
	doc = "`%d` is the day, `%B` the month name, `%Y` the year. Uses the " ..
		"server's clock, which is always UTC.",
	tags = "date time os format today" }

D{ id = "patRandomId", cat = "pattern", group = "Numbers", label = "a random code",
	head = "make {name} = a random {length} letter code",
	code = {
		"local {name} = \"\"",
		"for _ = 1, {length} do",
		'\t{name} = {name} .. string.char(math.random(65, 90))',
		"end",
	},
	fields = { name = "name|code|name", length = "num|6|length" },
	doc = "Character codes 65 to 90 are the capital letters. Good enough for " ..
		"a party code; not good enough for anything secret.",
	tags = "random code id letters generate party" }

--=============================================================================
-- SPACE AND ANGLES
--=============================================================================

D{ id = "vecTowards", cat = "vec", group = "Directions", label = "direction towards",
	head = "make {name} = the direction from {from} to {to}",
	code = "local {name} = ({to} - {from}).Unit",
	fields = { name = "name|way|name", from = "expr|part.Position|from", to = "expr|target.Position|to" },
	doc = "Subtracting gives the arrow between them; `.Unit` shortens it to " ..
		"length one so it is purely a direction.",
	tags = "direction unit normalise towards aim" }

D{ id = "vecFlatDistance", cat = "vec", group = "Directions", label = "distance ignoring height",
	head = "make {name} = how far {a} is from {b}, ignoring height",
	code = {
		"local {name}",
		"do",
		"\tlocal gap = {a} - {b}",
		"\t{name} = Vector3.new(gap.X, 0, gap.Z).Magnitude",
		"end",
	},
	fields = { name = "name|gap|name", a = "expr|part.Position|first", b = "expr|target.Position|second" },
	doc = "Flattening the height first is what stops a player on a tower " ..
		"counting as far away from something directly below them.",
	tags = "distance flat horizontal ignore height" }

D{ id = "vecLength", cat = "vec", group = "Directions", label = "length of a direction",
	head = "make {name} = the length of {vector}",
	code = "local {name} = {vector}.Magnitude",
	fields = { name = "name|length|name", vector = "expr|velocity|vector" },
	doc = "The length of a velocity is the speed. The length of the gap " ..
		"between two positions is the distance.",
	tags = "magnitude length speed size vector" }

D{ id = "vecShorten", cat = "vec", group = "Directions", label = "shorten to length one",
	head = "make {name} = {vector} shortened to length one",
	code = "local {name} = {vector}.Unit",
	fields = { name = "name|way|name", vector = "expr|direction|vector" },
	doc = "Keeps the direction and throws away the distance, which is what " ..
		"you want before multiplying by a speed.",
	tags = "unit normalise direction length one" }

D{ id = "vecCapLength", cat = "vec", group = "Directions", label = "cap a length",
	head = "make {name} = {vector} capped at {max} long",
	code = {
		"local {name} = {vector}",
		"if {name}.Magnitude > {max} then",
		"\t{name} = {name}.Unit * {max}",
		"end",
	},
	fields = { name = "name|capped|name", vector = "expr|push|vector", max = "num|50|maximum" },
	doc = "Stops a knockback becoming absurd when something is very close. " ..
		"Directions under the cap are left alone.",
	tags = "clamp cap magnitude limit speed" }

D{ id = "vecBlend", cat = "vec", group = "Directions", label = "blend two positions",
	head = "make {name} = {a} moved {t} of the way to {b}",
	code = "local {name} = {a}:Lerp({b}, {t})",
	fields = { name = "name|between|name", a = "expr|start|from", b = "expr|finish|to",
		t = "expr|0.5|amount" },
	doc = "0 gives the first, 1 the second, 0.5 the midpoint. Running it " ..
		"every frame with a small amount is how smooth following is done.",
	tags = "lerp blend interpolate between smooth" }

D{ id = "vecDot", cat = "vec", group = "Directions", label = "how much two agree",
	head = "make {name} = how much {a} and {b} point the same way",
	code = "local {name} = {a}.Unit:Dot({b}.Unit)",
	fields = { name = "name|agreement|name", a = "expr|lookVector|first", b = "expr|toTarget|second" },
	doc = "1 means the same direction, 0 means at right angles, -1 means " ..
		"opposite. Checking something is in front is `> 0`.",
	tags = "dot product angle facing infront behind" }

D{ id = "vecCross", cat = "vec", group = "Directions", label = "the perpendicular",
	head = "make {name} = the direction at right angles to both {a} and {b}",
	code = "local {name} = {a}:Cross({b})",
	fields = { name = "name|sideways|name", a = "expr|forward|first", b = "expr|Vector3.yAxis|second" },
	doc = "Crossing a forward direction with straight up gives the sideways " ..
		"direction, which is how strafing is worked out.",
	tags = "cross product perpendicular sideways right" }

D{ id = "vecFacing", cat = "vec", group = "Directions", label = "which way it faces",
	head = "make {name} = the direction {part} is facing",
	code = "local {name} = {part}.CFrame.LookVector",
	fields = { name = "name|forward|name", part = "expr|part|part" },
	doc = "LookVector is straight ahead, RightVector is to its right, " ..
		"UpVector is out of its top.",
	tags = "lookvector forward facing direction cframe" }

D{ id = "vecInFront", cat = "vec", group = "Directions", label = "a spot in front",
	head = "make {name} = the spot {n} studs in front of {part}",
	code = "local {name} = {part}.Position + {part}.CFrame.LookVector * {n}",
	fields = { name = "name|ahead|name", part = "expr|part|part", n = "num|10|studs" },
	doc = "Spawning a projectile, or checking what is ahead, starts here. " ..
		"Multiply by a negative number for behind.",
	tags = "front ahead lookvector offset spawn" }

-- rotations -------------------------------------------------------------------------------
D{ id = "cfAt", cat = "vec", group = "Rotations", label = "a place",
	head = "make {name} = the place ({x}, {y}, {z})",
	code = "local {name} = CFrame.new({x}, {y}, {z})",
	fields = { name = "name|spot|name", x = "expr|0|x", y = "expr|5|y", z = "expr|0|z" },
	doc = "A CFrame is a position and a facing together. This one faces the " ..
		"default direction.",
	tags = "cframe position place new" }

D{ id = "cfLooking", cat = "vec", group = "Rotations", label = "a place looking at",
	head = "make {name} = standing at {from} looking at {to}",
	code = "local {name} = CFrame.lookAt({from}, {to})",
	fields = { name = "name|view|name", from = "expr|Vector3.new(0, 10, 0)|from",
		to = "expr|target.Position|looking at" },
	doc = "Works out the facing for you. Almost always easier than building " ..
		"a rotation out of angles.",
	tags = "lookat cframe facing aim camera" }

D{ id = "cfTurned", cat = "vec", group = "Rotations", label = "a rotation in degrees",
	head = "make {name} = a rotation of {x}, {y}, {z} degrees",
	code = "local {name} = CFrame.Angles(math.rad({x}), math.rad({y}), math.rad({z}))",
	fields = { name = "name|turn|name", x = "expr|0|x", y = "expr|90|y", z = "expr|0|z" },
	doc = "CFrame.Angles wants radians, so the degrees are converted. Y is " ..
		"the one that spins a thing on the spot.",
	tags = "cframe angles rotation degrees radians turn" }

D{ id = "cfCombine", cat = "vec", group = "Rotations", label = "move relative to something",
	head = "make {name} = {cf} moved {x}, {y}, {z} in its own directions",
	code = "local {name} = {cf} * CFrame.new({x}, {y}, {z})",
	fields = { name = "name|moved|name", cf = "expr|part.CFrame|starting place",
		x = "expr|0|right", y = "expr|0|up", z = "expr|-5|forward" },
	doc = "Multiplying applies the second as an offset in the first's own " ..
		"directions. Negative Z is forward, which catches everyone out once.",
	tags = "cframe multiply relative offset local forward" }

D{ id = "cfSpin", cat = "vec", group = "Rotations", label = "turn something on the spot",
	head = "make {name} = {cf} turned {n} degrees",
	code = "local {name} = {cf} * CFrame.Angles(0, math.rad({n}), 0)",
	fields = { name = "name|turned|name", cf = "expr|part.CFrame|starting place", n = "expr|90|degrees" },
	doc = "Turns around its own upright axis, keeping it where it is. Run it " ..
		"every frame with a small angle to spin something.",
	tags = "rotate spin turn cframe angles y" }

D{ id = "cfBlend", cat = "vec", group = "Rotations", label = "blend two places",
	head = "make {name} = {a} moved {t} of the way to {b}",
	code = "local {name} = {a}:Lerp({b}, {t})",
	fields = { name = "name|between|name", a = "expr|part.CFrame|from", b = "expr|goal|to",
		t = "expr|0.1|amount" },
	doc = "Blends the position and the facing together, so a camera swinging " ..
		"round to look at something takes one line.",
	tags = "cframe lerp blend smooth camera interpolate" }

D{ id = "cfPositionOf", cat = "vec", group = "Rotations", label = "the position part",
	head = "make {name} = just the position of {cf}",
	code = "local {name} = {cf}.Position",
	fields = { name = "name|spot|name", cf = "expr|part.CFrame|place" },
	doc = "Throws the facing away and keeps the point in space.",
	tags = "cframe position extract point" }

D{ id = "cfWithoutTilt", cat = "vec", group = "Rotations", label = "level it out",
	head = "make {name} = {cf} with its tilt removed",
	code = {
		"local {name}",
		"do",
		"\tlocal look = {cf}.LookVector",
		"\t{name} = CFrame.lookAt({cf}.Position,",
		"\t\t{cf}.Position + Vector3.new(look.X, 0, look.Z))",
		"end",
	},
	fields = { name = "name|level|name", cf = "expr|part.CFrame|place" },
	doc = "Keeps which way it faces but stands it upright. Stops NPCs and " ..
		"cameras leaning over when they look up or down.",
	tags = "level upright tilt flatten cframe" }

-- angles -------------------------------------------------------------------------------------
D{ id = "angBetween", cat = "vec", group = "Angles", label = "angle between",
	head = "make {name} = the angle in degrees between {a} and {b}",
	code = "local {name} = math.deg(math.acos(math.clamp({a}.Unit:Dot({b}.Unit), -1, 1)))",
	fields = { name = "name|angle|name", a = "expr|lookVector|first", b = "expr|toTarget|second" },
	doc = "The clamp guards against tiny rounding errors pushing the value " ..
		"outside what acos accepts, which would give you a nan.",
	tags = "angle between degrees acos dot facing" }

D{ id = "angCompass", cat = "vec", group = "Angles", label = "compass angle",
	head = "make {name} = the compass angle from {a} to {b}",
	code = {
		"local {name}",
		"do",
		"\tlocal gap = {b} - {a}",
		"\t{name} = math.deg(math.atan2(gap.X, gap.Z))",
		"end",
	},
	fields = { name = "name|bearing|name", a = "expr|part.Position|from", b = "expr|target.Position|to" },
	doc = "`atan2` turns an X and Z gap into an angle all the way round, " ..
		"which plain trigonometry cannot do without extra cases.",
	tags = "atan2 bearing compass angle direction minimap" }

D{ id = "angWrap", cat = "vec", group = "Angles", label = "wrap an angle",
	head = "make {name} = {angle} wrapped to between -180 and 180",
	code = "local {name} = ({angle} + 180) % 360 - 180",
	fields = { name = "name|wrapped|name", angle = "expr|turn|degrees" },
	doc = "Stops an angle growing forever, and makes turning the short way " ..
		"round possible: 350 degrees becomes -10.",
	tags = "wrap angle modulo shortest turn" }

D{ id = "angToRadians", cat = "vec", group = "Angles", label = "degrees to radians",
	head = "make {name} = {angle} degrees in radians",
	code = "local {name} = math.rad({angle})",
	fields = { name = "name|radians|name", angle = "expr|90|degrees" },
	doc = "Every Roblox rotation function wants radians. Degrees are for " ..
		"people; radians are for the maths.",
	tags = "rad degrees radians convert angle" }

D{ id = "angToDegrees", cat = "vec", group = "Angles", label = "radians to degrees",
	head = "make {name} = {angle} radians in degrees",
	code = "local {name} = math.deg({angle})",
	fields = { name = "name|degrees|name", angle = "expr|angle|radians" },
	doc = "The way back, for showing an angle to a person.",
	tags = "deg radians degrees convert angle" }

-- curves and easing ------------------------------------------------------------------------------
D{ id = "curveEase", cat = "vec", group = "Curves", label = "ease a fraction",
	head = "make {name} = {t} eased with {style}",
	code = "local {name} = TweenService:GetValue(math.clamp({t}, 0, 1), " ..
		"Enum.EasingStyle.{style}, Enum.EasingDirection.{direction})",
	fields = { name = "name|eased|name", t = "expr|progress|fraction",
		style = "choice|Quad|style|Linear,Quad,Cubic,Quart,Sine,Back,Bounce,Elastic,Exponential,Circular",
		direction = "choice|Out|direction|In,Out,InOut" },
	needs = { "TweenService" },
	doc = "Borrows the tween engine's curves for your own maths, so hand " ..
		"animation can feel the same as a tween.",
	tags = "easing getvalue curve tween interpolate" }

D{ id = "curveMap", cat = "vec", group = "Curves", label = "map one range to another",
	head = "make {name} = {value} mapped from {a} to {b} onto {c} to {d}",
	code = "local {name} = {c} + (({value} - {a}) / ({b} - {a})) * ({d} - {c})",
	fields = { name = "name|mapped|name", value = "expr|health|value", a = "expr|0|from low",
		b = "expr|100|from high", c = "expr|0|to low", d = "expr|1|to high" },
	doc = "Turning health out of 100 into a bar fraction out of 1, or a " ..
		"slider into a volume, is this one line.",
	tags = "map range remap scale normalise convert" }

D{ id = "curveHowFar", cat = "vec", group = "Curves", label = "how far between",
	head = "make {name} = how far {value} is between {a} and {b}",
	code = "local {name} = math.clamp(({value} - {a}) / ({b} - {a}), 0, 1)",
	fields = { name = "name|fraction|name", value = "expr|health|value", a = "expr|0|low",
		b = "expr|100|high" },
	doc = "The opposite of blending: given a value, work out the fraction. " ..
		"Clamped, so values outside the range give 0 or 1.",
	tags = "inverse lerp fraction progress normalise" }

D{ id = "curveApproach", cat = "vec", group = "Curves", label = "step towards",
	head = "make {name} = {current} moved towards {target} by at most {step}",
	code = {
		"local {name} = {current}",
		"do",
		"\tlocal gap = {target} - {current}",
		"\tif math.abs(gap) <= {step} then",
		"\t\t{name} = {target}",
		"\telse",
		"\t\t{name} = {current} + (gap > 0 and {step} or -{step})",
		"\tend",
		"end",
	},
	fields = { name = "name|moved|name", current = "expr|shown|current", target = "expr|actual|target",
		step = "expr|1|most to move" },
	doc = "Moves at a steady rate and lands exactly on the target rather " ..
		"than creeping up on it forever, which blending does.",
	tags = "approach movetowards step steady lerp" }

D{ id = "curveBezier", cat = "vec", group = "Curves", label = "a point on a curve",
	head = "make {name} = the point {t} along the curve from {a} through {control} to {b}",
	code = {
		"local {name}",
		"do",
		"\tlocal first = {a}:Lerp({control}, {t})",
		"\tlocal second = {control}:Lerp({b}, {t})",
		"\t{name} = first:Lerp(second, {t})",
		"end",
	},
	fields = { name = "name|point|name", a = "expr|start|start", control = "expr|midAir|control point",
		b = "expr|finish|end", t = "expr|progress|fraction" },
	doc = "Three blends make a curved path. Putting the control point high " ..
		"above the two ends gives a lobbed arc.",
	tags = "bezier curve arc lob projectile path" }

-- randomness --------------------------------------------------------------------------------------
D{ id = "randDirection", cat = "vec", group = "Randomness", label = "a random direction",
	head = "make {name} = a random direction",
	code = "local {name} = Vector3.new(math.random() - 0.5, math.random() - 0.5, " ..
		"math.random() - 0.5).Unit",
	fields = { name = "name|way|name" },
	doc = "Any direction at all, including up and down. Zero the Y part " ..
		"first if you want it flat.",
	tags = "random direction vector scatter unit" }

D{ id = "randInCircle", cat = "vec", group = "Randomness", label = "a random spot in a circle",
	head = "make {name} = a random spot within {radius} studs of {centre}",
	code = {
		"local {name}",
		"do",
		"\tlocal angle = math.random() * math.pi * 2",
		"\tlocal away = math.sqrt(math.random()) * {radius}",
		"\t{name} = {centre} + Vector3.new(math.cos(angle) * away, 0, " ..
			"math.sin(angle) * away)",
		"end",
	},
	fields = { name = "name|spot|name", centre = "expr|middle|centre", radius = "num|30|radius" },
	doc = "The square root is what stops everything bunching up in the " ..
		"middle -- without it, a circle of spawns looks wrong.",
	tags = "random circle spawn scatter disc even" }

D{ id = "randSeeded", cat = "vec", group = "Randomness", label = "a repeatable randomiser",
	head = "make {name} = a randomiser seeded with {seed}",
	code = "local {name} = Random.new({seed})",
	fields = { name = "name|rolls|name", seed = "expr|12345|seed" },
	doc = "The same seed always gives the same sequence, so a generated world " ..
		"can be rebuilt exactly. Use `{name}:NextNumber()` to draw from it.",
	tags = "random seed repeatable procedural generation" }

D{ id = "randChance", cat = "vec", group = "Randomness", label = "if a chance comes up",
	head = "if a {percent} percent chance comes up then",
	code = "if math.random() * 100 < {percent} then", tail = "end",
	fields = { percent = "expr|25|percent" },
	slots = { { key = "body" } },
	doc = "Reads exactly as it means. `math.random()` gives a decimal from 0 " ..
		"up to 1, so scaling it by 100 gives a percentage.",
	tags = "chance percent random probability drop" }

D{ id = "randNoise", cat = "vec", group = "Randomness", label = "smooth noise",
	head = "make {name} = smooth noise at ({x}, {y}), zoomed out by {scale}",
	code = "local {name} = math.noise({x} / {scale}, {y} / {scale})",
	fields = { name = "name|value|name", x = "expr|position.X|x", y = "expr|position.Z|y",
		scale = "num|50|zoom" },
	doc = "Unlike random, nearby inputs give nearby results, which is what " ..
		"makes rolling hills instead of static. Gives roughly -0.5 to 0.5.",
	tags = "noise perlin terrain smooth procedural hills" }

D{ id = "randNoiseHeight", cat = "vec", group = "Randomness", label = "a noise height",
	head = "make {name} = a hill height at ({x}, {z}), up to {height} studs",
	code = "local {name} = math.noise({x} / {scale}, {z} / {scale}) * {height}",
	fields = { name = "name|height|name", x = "expr|x|x", z = "expr|z|z",
		height = "num|30|maximum", scale = "num|60|zoom" },
	doc = "Multiply noise by a height and you have terrain. A bigger zoom " ..
		"makes wider, gentler hills.",
	tags = "noise terrain height hills procedural world" }

--=============================================================================
-- DEBUG AND TIMING
--=============================================================================

D{ id = "dbgLabelled", cat = "debug", group = "Looking", label = "print with a label",
	head = 'print "{label}" and {value}',
	code = 'print("{label}", {value})',
	fields = { label = "str|health|label", value = "expr|hum.Health|value" },
	doc = "Print takes as many values as you like and tabs between them. A " ..
		"label next to the value is worth ten prints without one.",
	tags = "print debug label value output" }

D{ id = "dbgTable", cat = "debug", group = "Looking", label = "print a table",
	head = "print everything inside {table}",
	code = {
		"for key, value in pairs({table}) do",
		'\tprint(key, "=", value)',
		"end",
	},
	fields = { table = "expr|data|table" },
	doc = "Printing a table itself only shows its address. This shows what " ..
		"is actually in it, one line per entry.",
	tags = "print table dump inspect debug" }

D{ id = "dbgType", cat = "debug", group = "Looking", label = "print what something is",
	head = "print what {value} is",
	code = 'print(typeof({value}), {value})',
	fields = { value = "expr|value|value" },
	doc = "When something behaves oddly, the first question is usually what " ..
		"type it actually is rather than what you assumed.",
	tags = "typeof type print debug inspect" }

D{ id = "dbgWhere", cat = "debug", group = "Looking", label = "print the full path",
	head = "print where {obj} is in the game",
	code = "print({obj}:GetFullName())",
	fields = { obj = "expr|part|object" },
	doc = "Gives the full path, like `Workspace.Model.Part`, which settles " ..
		"any argument about which object you actually have.",
	tags = "getfullname path print locate debug" }

D{ id = "dbgChildren", cat = "debug", group = "Looking", label = "print the children",
	head = "print everything inside {obj}",
	code = {
		"for _, child in ipairs({obj}:GetChildren()) do",
		"\tprint(child.Name, child.ClassName)",
		"end",
	},
	fields = { obj = "expr|model|object" },
	doc = "Names and classes of everything one level down, which is usually " ..
		"enough to find the thing you cannot find.",
	tags = "children print list explore debug" }

D{ id = "dbgTrace", cat = "debug", group = "Looking", label = "print how we got here",
	head = "print how the code got here",
	code = "print(debug.traceback())",
	doc = "Prints the chain of function calls leading to this line. The way " ..
		"to find out who is calling something unexpectedly.",
	tags = "traceback stack callers debug trace" }

D{ id = "dbgWarnIf", cat = "debug", group = "Looking", label = "warn when",
	head = 'warn "{message}" if {condition}',
	code = {
		"if {condition} then",
		'\twarn("{message}")',
		"end",
	},
	fields = { message = "str|that should not happen|message", condition = "expr|health < 0|condition" },
	doc = "A warning is orange in the output window, which makes your own " ..
		"messages findable in a busy log.",
	tags = "warn condition orange debug check" }

D{ id = "dbgMemory", cat = "debug", group = "Looking", label = "print memory used",
	head = "print how much memory is being used",
	code = 'print(string.format("%.1f MB", Stats:GetTotalMemoryUsageMb()))',
	needs = { "Stats" },
	doc = "A number that keeps climbing while nothing new is happening means " ..
		"something is being kept alive that should not be.",
	tags = "memory stats leak performance debug" }

-- timing --------------------------------------------------------------------------------------
D{ id = "dbgTimeThis", cat = "debug", group = "Timing", label = "time these blocks",
	head = 'time these blocks and print it as "{label}"',
	code = {
		"do",
		"\tlocal started = os.clock()",
	},
	codeTail = {
		'\tprint(string.format("{label} took %.3f seconds", os.clock() - started))',
		"end",
	},
	tail = "end",
	bodyIndent = 1,
	fields = { label = "str|that bit|label" },
	slots = { { key = "body" } },
	doc = "Wraps anything and reports how long it took. Measuring beats " ..
		"guessing which part is slow.",
	tags = "timing profile measure clock performance" }

D{ id = "dbgSince", cat = "debug", group = "Timing", label = "seconds since",
	head = "make {name} = the seconds since {start}",
	code = "local {name} = os.clock() - {start}",
	fields = { name = "name|elapsed|name", start = "expr|startedAt|start time" },
	doc = "`os.clock` is a precise stopwatch. Subtracting two readings gives " ..
		"the gap; the numbers themselves mean nothing on their own.",
	tags = "elapsed clock stopwatch timing since" }

D{ id = "dbgEverySeconds", cat = "debug", group = "Timing", label = "every few seconds",
	head = "every {seconds} seconds, forever",
	code = {
		"task.spawn(function()",
		"\twhile true do",
		"\t\ttask.wait({seconds})",
	},
	codeTail = { "\tend", "end)" }, tail = "end",
	bodyIndent = 2,
	fields = { seconds = "num|5|seconds" },
	slots = { { key = "body" } },
	doc = "Runs on its own thread, so a wait in here does not hold up the " ..
		"rest of the script.",
	tags = "loop timer repeat interval spawn" }

D{ id = "dbgWaitUntil", cat = "debug", group = "Timing", label = "wait until",
	head = "wait until {condition}, checking every {seconds} seconds",
	code = {
		"while not ({condition}) do",
		"\ttask.wait({seconds})",
		"end",
	},
	fields = { condition = "expr|ready|condition", seconds = "num|0.2|seconds" },
	doc = "The brackets round the condition matter: without them `not` would " ..
		"only apply to the first part of a longer test.",
	tags = "wait until poll condition loop" }

D{ id = "dbgWaitUpTo", cat = "debug", group = "Timing", label = "wait, but give up",
	head = "wait up to {seconds} seconds for {condition}",
	code = {
		"do",
		"\tlocal giveUpAt = os.clock() + {seconds}",
		"\twhile not ({condition}) and os.clock() < giveUpAt do",
		"\t\ttask.wait(0.1)",
		"\tend",
		"end",
	},
	fields = { condition = "expr|loaded|condition", seconds = "num|10|seconds" },
	doc = "A wait with no way out is how a script hangs forever. This one " ..
		"always finishes, whether or not the thing happened.",
	tags = "wait timeout give up condition safety" }

D{ id = "dbgCountdown", cat = "debug", group = "Timing", label = "count down",
	head = "count down from {n}, printing each second",
	code = {
		"for remaining = {n}, 1, -1 do",
		"\tprint(remaining)",
		"\ttask.wait(1)",
		"end",
	},
	fields = { n = "num|10|from" },
	doc = "A round timer in four lines. Swap the print for a label update to " ..
		"put it on screen.",
	tags = "countdown timer round seconds loop" }

-- guarding ----------------------------------------------------------------------------------------
D{ id = "dbgDebounce", cat = "debug", group = "Guarding", label = "stop repeat firing",
	head = "stop this repeating within {seconds} seconds, using {flag}",
	code = {
		"if {flag} then return end",
		"{flag} = true",
		"task.delay({seconds}, function()",
		"\t{flag} = false",
		"end)",
	},
	fields = { flag = "expr|busy|flag variable", seconds = "num|1|seconds" },
	doc = "A debounce. Touched fires many times a second, so without one of " ..
		"these a single step collects the coin ten times.",
	tags = "debounce cooldown repeat touched guard" }

D{ id = "dbgCooldownPer", cat = "debug", group = "Guarding", label = "a cooldown per player",
	head = "stop {player} repeating within {seconds} seconds, tracked in {times}",
	code = {
		"do",
		"\tlocal now = os.clock()",
		"\tif {times}[{player}] and now - {times}[{player}] < {seconds} then",
		"\t\treturn",
		"\tend",
		"\t{times}[{player}] = now",
		"end",
	},
	fields = { player = "expr|player|player", times = "expr|lastUsed|times table",
		seconds = "num|3|seconds" },
	doc = "One shared flag would let one player's cooldown block everybody. " ..
		"A table keyed by player gives each their own.",
	tags = "cooldown per player table debounce fair" }

D{ id = "dbgOnlyOnce", cat = "debug", group = "Guarding", label = "only the first time",
	head = "only do this the first time, using {flag}",
	code = {
		"if {flag} then return end",
		"{flag} = true",
	},
	fields = { flag = "expr|done|flag variable" },
	doc = "Never resets, so whatever follows happens exactly once however " ..
		"often the event fires.",
	tags = "once flag guard first time" }

D{ id = "dbgEveryNth", cat = "debug", group = "Guarding", label = "every few times",
	head = "only do this every {n} times, counting in {counter}",
	code = {
		"{counter} = {counter} + 1",
		"if {counter} % {n} ~= 0 then return end",
	},
	fields = { counter = "expr|ticks|counter variable", n = "num|10|every" },
	doc = "Thins out something that runs every frame. Checking distance ten " ..
		"times a second instead of sixty is rarely noticeable.",
	tags = "throttle every nth counter modulo performance" }

D{ id = "dbgTryThese", cat = "debug", group = "Guarding", label = "try these and report",
	head = "try these blocks, printing any error",
	code = {
		"do",
		"\tlocal ok, err = pcall(function()",
	},
	codeTail = {
		"\tend)",
		"\tif not ok then",
		'\t\twarn("failed: " .. tostring(err))',
		"\tend",
		"end",
	},
	tail = "end",
	bodyIndent = 2,
	slots = { { key = "body" } },
	doc = "Like `try safely`, but it complains rather than swallowing the " ..
		"problem silently. What you want while building.",
	tags = "pcall try error report debug safe" }

D{ id = "dbgRetryThese", cat = "debug", group = "Guarding", label = "try these a few times",
	head = "try these blocks up to {tries} times",
	code = {
		"for attempt = 1, {tries} do",
		"\tlocal ok = pcall(function()",
	},
	codeTail = {
		"\tend)",
		"\tif ok then",
		"\t\tbreak",
		"\tend",
		"\ttask.wait(attempt)",
		"end",
	},
	tail = "end",
	bodyIndent = 2,
	fields = { tries = "num|3|tries" },
	slots = { { key = "body" } },
	doc = "Stops as soon as it works, and waits a little longer after each " ..
		"failure. Anything touching the network wants this.",
	tags = "retry pcall backoff network reliability" }

D{ id = "dbgFrameRate", cat = "debug", group = "Guarding", label = "frames per second",
	head = "make {name} = the current frames per second, from {dt}",
	code = "local {name} = math.floor(1 / math.max({dt}, 0.0001))",
	fields = { name = "name|fps|name", dt = "expr|dt|seconds since last frame" },
	doc = "One divided by the time a frame took. The max guards against " ..
		"dividing by zero on a very fast frame.",
	tags = "fps framerate performance delta debug" }

D{ id = "dbgProfileStart", cat = "debug", group = "Guarding", label = "mark for the profiler",
	head = 'mark these blocks as "{label}" in the profiler',
	code = { 'debug.profilebegin("{label}")' },
	codeTail = { "debug.profileend()" }, tail = "end",
	fields = { label = "str|my work|label" },
	slots = { { key = "body" } },
	doc = "Names a section so it shows up in Studio's MicroProfiler (Ctrl+F6 " ..
		"while playing) rather than being lumped in with everything else.",
	tags = "profilebegin microprofiler performance measure" }

end
