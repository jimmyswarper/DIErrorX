--!nonstrict
-- w  ·  block definitions: more of the original ten categories
--
-- The ten teaching categories keep their lessons and their first, simplest
-- blocks in c.luau.  This file deepens them: the same subjects, more of the
-- things people actually reach for once they are past the first hour.

return function(D)

--=============================================================================
-- EVENTS
--=============================================================================

D{ id = "onPrompt", cat = "events", group = "In the world", label = "on a prompt used",
	head = "when {prompt} is used by {player}",
	code = "{prompt}.Triggered:Connect(function({player})", tail = "end)",
	fields = { prompt = "expr|script.Parent.ProximityPrompt|prompt", player = "name|player|player" },
	slots = { { key = "body" } },
	doc = "A ProximityPrompt is the hold-E popup. It handles the distance, " ..
		"the key and the mobile button for you.",
	tags = "proximityprompt triggered interact use e key" }

D{ id = "onSeat", cat = "events", group = "In the world", label = "on someone sitting",
	head = "when someone sits in {seat}, as {hum}",
	code = {
		"{seat}:GetPropertyChangedSignal(\"Occupant\"):Connect(function()",
		"\tlocal {hum} = {seat}.Occupant",
		"\tif {hum} then",
	},
	codeTail = { "\tend", "end)" }, tail = "end",
	bodyIndent = 2,
	fields = { seat = "expr|script.Parent|seat", hum = "name|hum|humanoid" },
	slots = { { key = "body" } },
	doc = "Occupant is the Humanoid sitting there, or nil when they get up, " ..
		"which is why this checks before running.",
	tags = "seat occupant sit vehicle chair" }

D{ id = "onTouchEnded", cat = "events", group = "In the world", label = "on stopped touching",
	head = "when {part} stops being touched by {hit}",
	code = "{part}.TouchEnded:Connect(function({hit})", tail = "end)",
	fields = { part = "expr|script.Parent|part", hit = "name|hit|what left" },
	slots = { { key = "body" } },
	doc = "The other half of Touched. Leaving a zone fires this, though it " ..
		"can be missed if the part is destroyed first.",
	tags = "touchended leave zone exit" }

D{ id = "onChildAdded", cat = "events", group = "Objects", label = "on something added",
	head = "when something is added to {parent}, as {child}",
	code = "{parent}.ChildAdded:Connect(function({child})", tail = "end)",
	fields = { parent = "expr|workspace|parent", child = "name|child|what was added" },
	slots = { { key = "body" } },
	doc = "Only one level down. Use the descendant version to catch things " ..
		"added deeper inside.",
	tags = "childadded added parent watch" }

D{ id = "onChildRemoved", cat = "events", group = "Objects", label = "on something removed",
	head = "when something is removed from {parent}, as {child}",
	code = "{parent}.ChildRemoved:Connect(function({child})", tail = "end)",
	fields = { parent = "expr|workspace|parent", child = "name|child|what was removed" },
	slots = { { key = "body" } },
	doc = "Fires when a child is destroyed or reparented away.",
	tags = "childremoved removed parent watch" }

D{ id = "onDescendantAdded", cat = "events", group = "Objects", label = "on anything added below",
	head = "when anything is added anywhere inside {parent}, as {thing}",
	code = "{parent}.DescendantAdded:Connect(function({thing})", tail = "end)",
	fields = { parent = "expr|workspace|parent", thing = "name|thing|what was added" },
	slots = { { key = "body" } },
	doc = "Catches things added at any depth, which is how you apply a rule " ..
		"to every part that ever appears.",
	tags = "descendantadded deep watch anywhere" }

D{ id = "onDestroying", cat = "events", group = "Objects", label = "on being destroyed",
	head = "just before {obj} is destroyed",
	code = "{obj}.Destroying:Connect(function()", tail = "end)",
	fields = { obj = "expr|part|object" },
	slots = { { key = "body" } },
	doc = "Your last chance to clean up connections or save something about " ..
		"an object before it goes.",
	tags = "destroying cleanup before removed" }

D{ id = "onAttributeChanged", cat = "events", group = "Objects", label = "on any attribute changed",
	head = "when any attribute of {obj} changes, as {which}",
	code = "{obj}.AttributeChanged:Connect(function({which})", tail = "end)",
	fields = { obj = "expr|part|object", which = "name|attribute|which one" },
	slots = { { key = "body" } },
	doc = "Hands you the name of whichever attribute changed, so one handler " ..
		"can cover them all.",
	tags = "attributechanged attribute watch any" }

D{ id = "onChat", cat = "events", group = "Players", label = "on a player chatting",
	head = "when {player} says something, as {message}",
	code = "{player}.Chatted:Connect(function({message})", tail = "end)",
	fields = { player = "expr|player|player", message = "name|message|what they said" },
	slots = { { key = "body" } },
	side = "server",
	doc = "The simplest way to add chat commands. Anything you show to other " ..
		"players from here has to be filtered first.",
	tags = "chatted chat message command say" }

D{ id = "onIdle", cat = "events", group = "Players", label = "on a player going idle",
	head = "when {player} has been still for a while, as {seconds}",
	code = "{player}.Idled:Connect(function({seconds})", tail = "end)",
	fields = { player = "expr|player|player", seconds = "name|idleFor|seconds idle" },
	slots = { { key = "body" } },
	doc = "Fires after about twenty minutes of no input, and again every so " ..
		"often after that.",
	tags = "idled afk away inactive" }

D{ id = "onKeyUp", cat = "events", group = "Input", label = "on a key released",
	head = "when the {key} key is let go",
	code = {
		"UserInputService.InputEnded:Connect(function(input)",
		"\tif input.KeyCode == Enum.KeyCode.{key} then",
	},
	codeTail = { "\tend", "end)" }, tail = "end",
	bodyIndent = 2,
	fields = { key = "choice:keycode|E|key|E,F,Q,R,T,Space,LeftShift,LeftControl,One,Two,Three" },
	slots = { { key = "body" } },
	needs = { "UserInputService" }, side = "client",
	doc = "The release half of a key press, for anything held down like " ..
		"sprinting or aiming.",
	tags = "inputended key release let go client" }

D{ id = "onClick3D", cat = "events", group = "Input", label = "on a mouse click in the world",
	head = "when the player clicks, as {where}",
	code = {
		"UserInputService.InputBegan:Connect(function(input, typing)",
		"\tif typing then return end",
		"\tif input.UserInputType == Enum.UserInputType.MouseButton1 then",
		"\t\tlocal {where} = UserInputService:GetMouseLocation()",
	},
	codeTail = { "\t\tend", "end)" }, tail = "end",
	bodyIndent = 2,
	fields = { where = "name|at|screen position" },
	slots = { { key = "body" } },
	needs = { "UserInputService" }, side = "client",
	doc = "Gives the click position on screen. Turn it into a world position " ..
		"with a camera ray if you need what was clicked.",
	tags = "click mouse input world position client" }

D{ id = "onStepped", cat = "events", group = "Input", label = "before physics each frame",
	head = "before physics each frame, {dt} seconds later",
	code = "RunService.Stepped:Connect(function(_, {dt})", tail = "end)",
	fields = { dt = "name|dt|delta" },
	slots = { { key = "body" } },
	needs = { "RunService" },
	doc = "Runs just before the physics step, which is where a force should " ..
		"be applied so it takes effect the same frame.",
	tags = "stepped physics before frame runservice" }

--=============================================================================
-- CONTROL
--=============================================================================

D{ id = "forEachChild", cat = "control", group = "Over objects", label = "for each child",
	head = "for each {child} inside {parent}",
	code = "for _, {child} in ipairs({parent}:GetChildren()) do", tail = "end",
	fields = { parent = "expr|workspace|parent", child = "name|child|each" },
	slots = { { key = "body" } },
	doc = "One level down only. The most common loop in Roblox code after " ..
		"the player one.",
	tags = "getchildren loop children each" }

D{ id = "forEachDescendant", cat = "control", group = "Over objects", label = "for each thing inside",
	head = "for each {thing} anywhere inside {parent}",
	code = "for _, {thing} in ipairs({parent}:GetDescendants()) do", tail = "end",
	fields = { parent = "expr|model|parent", thing = "name|thing|each" },
	slots = { { key = "body" } },
	doc = "Every depth, which on a big model can be thousands of objects. " ..
		"Worth filtering inside with an `if it is a` block.",
	tags = "getdescendants loop deep every" }

D{ id = "forEachPart", cat = "control", group = "Over objects", label = "for each part inside",
	head = "for each part {part} inside {parent}",
	code = {
		"for _, {part} in ipairs({parent}:GetDescendants()) do",
		'\tif {part}:IsA("BasePart") then',
	},
	codeTail = { "\tend", "end" }, tail = "end",
	bodyIndent = 2,
	fields = { parent = "expr|model|parent", part = "name|part|each part" },
	slots = { { key = "body" } },
	doc = "The filtered version, which is what you nearly always meant. " ..
		"Skips scripts, values and everything else that is not a part.",
	tags = "parts loop basepart filter descendants" }

D{ id = "repeatForSeconds", cat = "control", group = "Timing", label = "repeat for a while",
	head = "keep doing this for {seconds} seconds",
	code = {
		"do",
		"\tlocal stopAt = os.clock() + {seconds}",
		"\twhile os.clock() < stopAt do",
	},
	codeTail = { "\t\ttask.wait()", "\tend", "end" }, tail = "end",
	bodyIndent = 2,
	fields = { seconds = "num|3|seconds" },
	slots = { { key = "body" } },
	doc = "A loop with a built-in end and a built-in wait, so it can never " ..
		"run away with itself.",
	tags = "loop duration seconds timed while" }

D{ id = "waitFrame", cat = "control", group = "Timing", label = "wait one frame",
	head = "wait for the next frame",
	code = "task.wait()",
	doc = "Lets everything else have a turn and carries on next frame. Not " ..
		"free, but the shortest possible pause.",
	tags = "wait frame yield next tick" }

D{ id = "waitFrames", cat = "control", group = "Timing", label = "wait several frames",
	head = "wait for {n} frames",
	code = {
		"for _ = 1, {n} do",
		"\ttask.wait()",
		"end",
	},
	fields = { n = "num|3|frames" },
	doc = "Sometimes something needs a moment to settle -- a character to " ..
		"load, a part to fall -- and a fixed wait is too blunt.",
	tags = "wait frames pause settle" }

D{ id = "forGrid", cat = "control", group = "Counting", label = "for each square of a grid",
	head = "for each square {x} across and {y} down, up to {width} by {height}",
	code = {
		"for {x} = 1, {width} do",
		"\tfor {y} = 1, {height} do",
	},
	codeTail = { "\tend", "end" }, tail = "end",
	bodyIndent = 2,
	fields = { x = "name|x|across", y = "name|y|down", width = "num|8|width", height = "num|8|height" },
	slots = { { key = "body" } },
	doc = "A loop inside a loop. Building a floor, a chessboard or an " ..
		"inventory grid all start here.",
	tags = "nested loop grid rows columns two dimensional" }

D{ id = "forBackwards", cat = "control", group = "Counting", label = "count backwards",
	head = "count {var} down from {from} to {to}",
	code = "for {var} = {from}, {to}, -1 do", tail = "end",
	fields = { var = "name|i|name", from = "num|10|from", to = "num|1|to" },
	slots = { { key = "body" } },
	doc = "The only safe direction when you are removing items from a list " ..
		"as you go.",
	tags = "loop backwards countdown reverse for" }

D{ id = "breakIf", cat = "control", group = "Counting", label = "stop the loop if",
	head = "stop the loop if {condition}",
	code = {
		"if {condition} then",
		"\tbreak",
		"end",
	},
	fields = { condition = "expr|found|condition" },
	doc = "Leaves the loop the moment the condition is true, rather than " ..
		"finishing every remaining pass.",
	tags = "break stop loop early exit condition" }

D{ id = "skipIf", cat = "control", group = "Counting", label = "skip this turn if",
	head = "skip to the next turn if {condition}",
	code = {
		"if {condition} then",
		"\tcontinue",
		"end",
	},
	fields = { condition = "expr|not part.CanCollide|condition" },
	doc = "A filter inside a loop, and flatter to read than wrapping the " ..
		"whole body in an if block.",
	tags = "continue skip filter loop guard" }

D{ id = "doInOrder", cat = "control", group = "Timing", label = "do these one at a time",
	head = "do these blocks with {gap} seconds between each",
	code = {
		"do",
		"\tlocal gap = {gap}",
	},
	codeTail = { "end" }, tail = "end",
	fields = { gap = "num|1|seconds" },
	slots = { { key = "body" } },
	doc = "Names the gap once so the waits inside can all use it. Put a " ..
		"`wait gap seconds` block between the steps.",
	tags = "sequence order steps timing group" }

--=============================================================================
-- LOGIC
--=============================================================================

D{ id = "ifBetween", cat = "logic", group = "Ranges", label = "if between",
	head = "if {value} is between {low} and {high} then",
	code = "if {value} >= {low} and {value} <= {high} then", tail = "end",
	fields = { value = "expr|health|value", low = "expr|1|low", high = "expr|50|high" },
	slots = { { key = "body" } },
	doc = "Both ends count. Two comparisons joined with `and`, which Luau has " ..
		"no shorter way to write.",
	tags = "between range within bounds compare" }

D{ id = "ifOutside", cat = "logic", group = "Ranges", label = "if outside",
	head = "if {value} is outside {low} to {high} then",
	code = "if {value} < {low} or {value} > {high} then", tail = "end",
	fields = { value = "expr|position.Y|value", low = "expr|0|low", high = "expr|100|high" },
	slots = { { key = "body" } },
	doc = "The opposite test. Catching a player who has fallen out of the " ..
		"world is this with a low bound.",
	tags = "outside range bounds fell out check" }

D{ id = "ifOneOf", cat = "logic", group = "Ranges", label = "if it is one of",
	head = "if {value} is one of {list} then",
	code = "if table.find({list}, {value}) then", tail = "end",
	fields = { value = "expr|material|value", list = "expr|allowed|list" },
	slots = { { key = "body" } },
	doc = "Beats a chain of `or` comparisons, and the list can be changed " ..
		"without touching the check.",
	tags = "oneof list find allowed whitelist" }

D{ id = "ifNothing", cat = "logic", group = "Nothing", label = "if it is nothing",
	head = "if {value} is nothing then",
	code = "if {value} == nil then", tail = "end",
	fields = { value = "expr|found|value" },
	slots = { { key = "body" } },
	doc = "Explicitly nil, rather than false. Worth being exact when false " ..
		"is a value you might legitimately store.",
	tags = "nil nothing missing check empty" }

D{ id = "ifEmptyText", cat = "logic", group = "Nothing", label = "if the text is empty",
	head = "if {text} is empty then",
	code = 'if {text} == nil or {text} == "" then', tail = "end",
	fields = { text = "expr|typed|text" },
	slots = { { key = "body" } },
	doc = "Covers both nothing at all and an empty string, which is what " ..
		"an untouched typing box gives you.",
	tags = "empty blank string check input" }

D{ id = "ifSame", cat = "logic", group = "Nothing", label = "if it is the same object",
	head = "if {a} is the same object as {b} then",
	code = "if {a} == {b} then", tail = "end",
	fields = { a = "expr|hit.Parent|first", b = "expr|character|second" },
	slots = { { key = "body" } },
	doc = "Instances compare by identity, not by name, so this is true only " ..
		"for the very same object.",
	tags = "same identity equal instance compare" }

D{ id = "ifDivisible", cat = "logic", group = "Numbers", label = "if it divides evenly",
	head = "if {value} divides evenly by {n} then",
	code = "if {value} % {n} == 0 then", tail = "end",
	fields = { value = "expr|count|value", n = "expr|2|divisor" },
	slots = { { key = "body" } },
	doc = "The remainder being zero means it divides exactly. With 2 this is " ..
		"an even-number check.",
	tags = "modulo divisible even remainder multiple" }

D{ id = "ifBoth3", cat = "logic", group = "Combining", label = "if all three",
	head = "if {a}, {b} and {c} are all true then",
	code = "if {a} and {b} and {c} then", tail = "end",
	fields = { a = "expr|alive|first", b = "expr|ready|second", c = "expr|inRange|third" },
	slots = { { key = "body" } },
	doc = "Three conditions without nesting three if blocks. They are checked " ..
		"left to right and stop at the first false.",
	tags = "and three all conditions combine" }

D{ id = "ifNeither", cat = "logic", group = "Combining", label = "if neither",
	head = "if neither {a} nor {b} then",
	code = "if not {a} and not {b} then", tail = "end",
	fields = { a = "expr|busy|first", b = "expr|dead|second" },
	slots = { { key = "body" } },
	doc = "True only when both are false. Reads better than the alternative, " ..
		"`not (a or b)`.",
	tags = "neither nor not both false" }

D{ id = "pickValue", cat = "logic", group = "Combining", label = "pick a value",
	head = "make {name} = {a} if {condition}, otherwise {b}",
	code = "local {name} = {condition} and {a} or {b}",
	fields = { name = "name|chosen|name", condition = "expr|isNight|condition",
		a = "expr|0.8|if true", b = "expr|0.1|if false" },
	doc = "Luau's shorthand for a small choice. The catch: it fails if the " ..
		"true value is itself false or nil, so keep it to real values.",
	tags = "ternary and or choose conditional value" }

D{ id = "valueOrDefault", cat = "logic", group = "Combining", label = "value or a default",
	head = "make {name} = {value}, or {fallback} if there is none",
	code = "local {name} = {value} or {fallback}",
	fields = { name = "name|setting|name", value = "expr|part:GetAttribute(\"Speed\")|value",
		fallback = "expr|16|fallback" },
	doc = "`or` hands back the first thing that is not nil or false. The " ..
		"standard way to give a missing value a default.",
	tags = "or default fallback nil attribute" }

--=============================================================================
-- MATH
--=============================================================================

D{ id = "mathPercentOf", cat = "math", group = "Portions", label = "percent of",
	head = "make {var} = {percent} percent of {value}",
	code = "{var} = {value} * {percent} / 100",
	fields = { var = "expr|part|variable", percent = "expr|25|percent", value = "expr|total|value" },
	doc = "A quarter of something, without working out the decimal yourself.",
	tags = "percent portion fraction of" }

D{ id = "mathAsPercent", cat = "math", group = "Portions", label = "as a percentage",
	head = "make {var} = {value} as a percentage of {total}",
	code = "{var} = math.floor({value} / {total} * 100)",
	fields = { var = "expr|percent|variable", value = "expr|health|value", total = "expr|maxHealth|total" },
	doc = "For showing a fraction to a player. Flooring keeps it a whole " ..
		"number so it does not read as 99.99999.",
	tags = "percentage progress ratio display" }

D{ id = "mathChangeByPercent", cat = "math", group = "Portions", label = "change by a percentage",
	head = "change {var} by {percent} percent",
	code = "{var} = {var} * (1 + {percent} / 100)",
	fields = { var = "expr|price|variable", percent = "expr|10|percent" },
	doc = "A negative percentage reduces it. Compounding prices and growing " ..
		"difficulty are this line in a loop.",
	tags = "percent increase decrease multiply scale" }

D{ id = "mathRoundStep", cat = "math", group = "Rounding", label = "round to the nearest",
	head = "make {var} = {value} rounded to the nearest {step}",
	code = "{var} = math.round({value} / {step}) * {step}",
	fields = { var = "expr|snapped|variable", value = "expr|position.X|value", step = "expr|4|step" },
	doc = "Rounding to 4 gives 0, 4, 8 and so on. The whole of grid snapping " ..
		"and of rounding money to five.",
	tags = "round nearest step snap grid multiple" }

D{ id = "mathWholeNumber", cat = "math", group = "Rounding", label = "make it a whole number",
	head = "make {var} = {value} with the decimals dropped",
	code = "{var} = math.floor({value})",
	fields = { var = "expr|whole|variable", value = "expr|amount|value" },
	doc = "Always downward, even for negative numbers. Use round instead if " ..
		"you want the nearest.",
	tags = "floor whole integer truncate round down" }

D{ id = "mathWrap", cat = "math", group = "Rounding", label = "wrap a number round",
	head = "make {var} = {value} wrapped to between 0 and {limit}",
	code = "{var} = {value} % {limit}",
	fields = { var = "expr|index|variable", value = "expr|counter|value", limit = "expr|4|limit" },
	doc = "The remainder loops back to zero when it reaches the limit, which " ..
		"is how you cycle through a list forever.",
	tags = "modulo wrap cycle loop remainder" }

D{ id = "mathSquare", cat = "math", group = "Working out", label = "square a number",
	head = "make {var} = {value} squared",
	code = "{var} = {value} ^ 2",
	fields = { var = "expr|area|variable", value = "expr|side|value" },
	doc = "`^` is the power operator. Squaring is often faster than a square " ..
		"root when you only need to compare two distances.",
	tags = "square power exponent multiply" }

D{ id = "mathHypotenuse", cat = "math", group = "Working out", label = "diagonal length",
	head = "make {var} = the diagonal across {a} by {b}",
	code = "{var} = math.sqrt({a} ^ 2 + {b} ^ 2)",
	fields = { var = "expr|diagonal|variable", a = "expr|width|first side", b = "expr|height|second side" },
	doc = "Pythagoras. The straight-line distance across a rectangle of those " ..
		"two sides.",
	tags = "pythagoras hypotenuse diagonal distance sqrt" }

D{ id = "mathAverageTwo", cat = "math", group = "Working out", label = "average of two",
	head = "make {var} = the average of {a} and {b}",
	code = "{var} = ({a} + {b}) / 2",
	fields = { var = "expr|middle|variable", a = "expr|low|first", b = "expr|high|second" },
	doc = "The midpoint. The brackets matter -- without them only the second " ..
		"number would be halved.",
	tags = "average mean midpoint two brackets" }

D{ id = "mathDifference", cat = "math", group = "Working out", label = "difference between",
	head = "make {var} = how far apart {a} and {b} are",
	code = "{var} = math.abs({a} - {b})",
	fields = { var = "expr|gap|variable", a = "expr|score|first", b = "expr|target|second" },
	doc = "Always a positive number, whichever way round they are.",
	tags = "difference abs gap distance apart" }

D{ id = "mathCountUpTo", cat = "math", group = "Working out", label = "step towards a number",
	head = "move {var} towards {target} by at most {step}",
	code = {
		"if math.abs({target} - {var}) <= {step} then",
		"\t{var} = {target}",
		"else",
		"\t{var} = {var} + ({target} > {var} and {step} or -{step})",
		"end",
	},
	fields = { var = "expr|shown|variable", target = "expr|actual|target", step = "expr|1|most to move" },
	doc = "Lands exactly on the target instead of creeping towards it. A " ..
		"score counter ticking up uses this.",
	tags = "approach step towards counter animate" }

D{ id = "mathSignOf", cat = "math", group = "Working out", label = "which way",
	head = "make {var} = which way {value} points",
	code = "{var} = math.sign({value})",
	fields = { var = "expr|way|variable", value = "expr|difference|value" },
	doc = "Gives -1, 0 or 1. Useful for turning a difference into a " ..
		"direction without caring how big it is.",
	tags = "sign direction positive negative" }

--=============================================================================
-- TEXT
--=============================================================================

D{ id = "textJoinThree", cat = "text", group = "Building", label = "join three",
	head = "make {var} = {a}, {b} and {c} joined together",
	code = "{var} = tostring({a}) .. tostring({b}) .. tostring({c})",
	fields = { var = "expr|line|variable", a = "expr|\"Score: \"|first", b = "expr|score|second",
		c = "expr|\" points\"|third" },
	doc = "`tostring` round each part means numbers and other values join " ..
		"without complaint.",
	tags = "join concat three tostring build" }

D{ id = "textLetterAt", cat = "text", group = "Reading", label = "the letter at",
	head = "make {var} = letter {n} of {text}",
	code = "{var} = string.sub({text}, {n}, {n})",
	fields = { var = "expr|letter|variable", text = "expr|word|text", n = "expr|1|position" },
	doc = "Counting starts at 1. Asking past the end gives an empty string " ..
		"rather than an error.",
	tags = "letter character position sub index" }

D{ id = "textFirstWord", cat = "text", group = "Reading", label = "the first word",
	head = "make {var} = the first word of {text}",
	code = '{var} = string.match({text}, "%S+")',
	fields = { var = "expr|first|variable", text = "expr|message|text" },
	doc = "Reading the command out of a chat message starts here.",
	tags = "first word command match split" }

D{ id = "textAfterFirstWord", cat = "text", group = "Reading", label = "everything after the first word",
	head = "make {var} = everything after the first word of {text}",
	code = '{var} = string.match({text}, "%S+%s+(.*)") or ""',
	fields = { var = "expr|rest|variable", text = "expr|message|text" },
	doc = "The other half of a chat command: the argument. The `or \"\"` " ..
		"covers a message with only one word in it.",
	tags = "rest arguments command after split" }

D{ id = "textNoSpaces", cat = "text", group = "Reading", label = "without spaces",
	head = "make {var} = {text} with the spaces taken out",
	code = '{var} = string.gsub({text}, "%s", "")',
	fields = { var = "expr|tight|variable", text = "expr|typed|text" },
	doc = "Every space, not just the ends. Useful before comparing something " ..
		"a player typed.",
	tags = "spaces remove strip whitespace" }

D{ id = "textSameIgnoringCase", cat = "text", group = "Comparing", label = "if the same, ignoring case",
	head = "if {a} is the same as {b}, ignoring capitals, then",
	code = "if string.lower({a}) == string.lower({b}) then", tail = "end",
	fields = { a = "expr|typed|first", b = "expr|\"yes\"|second" },
	slots = { { key = "body" } },
	doc = "Comparing anything a player typed should nearly always ignore " ..
		"case, or `Yes` will not match `yes`.",
	tags = "lower compare case insensitive input" }

D{ id = "textHowLong", cat = "text", group = "Comparing", label = "if it is too long",
	head = "if {text} is longer than {n} characters then",
	code = "if #{text} > {n} then", tail = "end",
	fields = { text = "expr|typed|text", n = "num|20|length" },
	slots = { { key = "body" } },
	doc = "Worth checking before showing anything a player typed, or a very " ..
		"long name will break your layout.",
	tags = "length limit long check input" }

D{ id = "textAsTrueFalse", cat = "text", group = "Converting", label = "text to true or false",
	head = "make {var} = whether {text} means yes",
	code = '{var} = string.lower({text}) == "true" or string.lower({text}) == "yes"',
	fields = { var = "expr|agreed|variable", text = "expr|typed|text" },
	doc = "There is no built-in conversion from text to a true-or-false " ..
		"value, so this decides what counts as yes.",
	tags = "boolean parse yes true convert input" }

D{ id = "textDefault", cat = "text", group = "Converting", label = "text or a default",
	head = 'make {var} = {text}, or "{fallback}" if it is empty',
	code = '{var} = ({text} ~= nil and {text} ~= "") and {text} or "{fallback}"',
	fields = { var = "expr|shown|variable", text = "expr|typed|text", fallback = "str|Anonymous|fallback" },
	doc = "Plain `or` would not catch an empty string, only nil, so this " ..
		"checks for both.",
	tags = "default fallback empty placeholder text" }

D{ id = "textLineCount", cat = "text", group = "Converting", label = "count the lines",
	head = "make {var} = how many lines are in {text}",
	code = {
		"{var} = 1",
		'for _ in string.gmatch({text}, "\\n") do',
		"\t{var} = {var} + 1",
		"end",
	},
	fields = { var = "expr|lines|variable", text = "expr|text|text" },
	doc = "One more than the number of newlines, since the last line has no " ..
		"newline after it.",
	tags = "lines count newline text measure" }

--=============================================================================
-- VARIABLES
--=============================================================================

D{ id = "makeNumber", cat = "vars", group = "Making", label = "make a number",
	head = "make {name} = the number {value}",
	code = "local {name} = {value}",
	fields = { name = "name|count|name", value = "num|0|value" },
	doc = "The same as `make`, worded so it is obvious a number is what " ..
		"belongs in the field.",
	tags = "number local make variable" }

D{ id = "makeText", cat = "vars", group = "Making", label = "make some text",
	head = 'make {name} = the text "{value}"',
	code = 'local {name} = "{value}"',
	fields = { name = "name|title|name", value = "str|hello|value" },
	doc = "No quotes to type: the field is the words themselves.",
	tags = "string text local make variable" }

D{ id = "makeTrueFalse", cat = "vars", group = "Making", label = "make a yes or no",
	head = "make {name} = {value}",
	code = "local {name} = {value}",
	fields = { name = "name|isOpen|name", value = "choice|false|value|true,false" },
	doc = "Name these so `if` plus the name reads as a sentence: `isOpen`, " ..
		"`hasKey`, `canJump`.",
	tags = "boolean true false flag variable" }

D{ id = "makeConstant", cat = "vars", group = "Making", label = "make a fixed value",
	head = "make the fixed value {name} = {value}",
	code = "local {name} = {value}",
	fields = { name = "name|MAX_HEALTH|name", value = "expr|100|value" },
	doc = "Capitals with underscores is the convention for a value that " ..
		"never changes. It tells a reader not to look for it being set.",
	tags = "constant fixed uppercase convention settings" }

D{ id = "makeCounter", cat = "vars", group = "Making", label = "make a counter",
	head = "make the counter {name}, starting at {value}",
	code = "local {name} = {value}",
	fields = { name = "name|count|name", value = "num|0|start" },
	doc = "Make it outside whatever loop or event changes it, or it will " ..
		"reset to nothing every time.",
	tags = "counter tally count variable scope" }

D{ id = "makeFromOther", cat = "vars", group = "Making", label = "copy a value",
	head = "make {name} = whatever {other} is now",
	code = "local {name} = {other}",
	fields = { name = "name|previous|name", other = "expr|current|other value" },
	doc = "For numbers and text this makes a real copy. For tables and " ..
		"instances it is a second name for the same thing.",
	tags = "copy snapshot previous value assign" }

D{ id = "setIfNothing", cat = "vars", group = "Changing", label = "set only if empty",
	head = "set {name} to {value} only if it has nothing",
	code = {
		"if {name} == nil then",
		"\t{name} = {value}",
		"end",
	},
	fields = { name = "expr|choice|name", value = "expr|\"default\"|value" },
	doc = "Fills a gap without overwriting a value that is already there.",
	tags = "default nil set once fill" }

D{ id = "swapValues", cat = "vars", group = "Changing", label = "swap two values",
	head = "swap {a} and {b}",
	code = "{a}, {b} = {b}, {a}",
	fields = { a = "expr|first|first", b = "expr|second|second" },
	doc = "Luau works out the right side first, so no temporary variable is " ..
		"needed.",
	tags = "swap exchange values assign" }

D{ id = "attrOrDefault", cat = "vars", group = "Attributes", label = "attribute or a default",
	head = 'make {name} = attribute "{attr}" of {inst}, or {fallback}',
	code = 'local {name} = {inst}:GetAttribute("{attr}") or {fallback}',
	fields = { name = "name|speed|name", inst = "expr|script.Parent|instance",
		attr = "str|Speed|attribute", fallback = "expr|16|fallback" },
	doc = "The pattern that makes attributes pleasant: never set means the " ..
		"default applies, and setting it in Properties overrides it.",
	tags = "attribute default fallback settings tunable" }

D{ id = "attrCopyAll", cat = "vars", group = "Attributes", label = "copy every attribute",
	head = "copy every attribute from {from} to {to}",
	code = {
		"for key, value in pairs({from}:GetAttributes()) do",
		"\t{to}:SetAttribute(key, value)",
		"end",
	},
	fields = { from = "expr|template|from", to = "expr|copy|to" },
	doc = "Cloning copies attributes already, so this is for when the two " ..
		"objects are not copies of each other.",
	tags = "attributes copy all transfer getattributes" }

--=============================================================================
-- FUNCTIONS
--=============================================================================

D{ id = "defReturning", cat = "funcs", group = "Defining", label = "define that gives back",
	head = "to work out {name} from {params}:",
	code = "local function {name}({params})", tail = "end",
	fields = { name = "name|workOut|name", params = "params|a, b|inputs" },
	slots = { { key = "body" } },
	doc = "The same as `define`, worded for a function whose whole point is " ..
		"the value it gives back.",
	tags = "function define return value calculate" }

D{ id = "defOnTable", cat = "funcs", group = "Defining", label = "define inside a module",
	head = "to {name} of the module {module} with {params}:",
	code = "function {module}.{name}({params})", tail = "end",
	fields = { module = "expr|Module|module", name = "name|doThing|name", params = "params||inputs" },
	slots = { { key = "body" } },
	doc = "A dot rather than a colon, so there is no hidden `self`. This is " ..
		"how most module functions are written.",
	tags = "module function dot define library" }

D{ id = "defAnonymous", cat = "funcs", group = "Defining", label = "define a function value",
	head = "make {name} = a function taking {params}",
	code = "local {name} = function({params})", tail = "end",
	fields = { name = "name|handler|name", params = "params|value|inputs" },
	slots = { { key = "body" } },
	doc = "A function kept in a variable, which can then be passed to " ..
		"something else or stored in a table.",
	tags = "anonymous function value callback handler" }

D{ id = "callMethod", cat = "funcs", group = "Running", label = "run a method",
	head = "run {name} on {obj} with {args}",
	code = "{obj}:{name}({args})",
	fields = { obj = "expr|thing|object", name = "name|doThing|method", args = "expr||inputs" },
	doc = "The colon passes the object itself as a hidden first input, which " ..
		"is what makes it a method rather than a plain function.",
	tags = "method colon call self invoke" }

D{ id = "callIfThere", cat = "funcs", group = "Running", label = "run it if it exists",
	head = "run {name} with {args}, if there is one",
	code = {
		"if {name} then",
		"\t{name}({args})",
		"end",
	},
	fields = { name = "expr|onFinished|function", args = "expr||inputs" },
	doc = "Optional callbacks are common: a function is handed in or it is " ..
		"not, and this covers both.",
	tags = "optional callback nil check call" }

D{ id = "returnTwo", cat = "funcs", group = "Running", label = "give back two things",
	head = "give back {a} and {b}",
	code = "return {a}, {b}",
	fields = { a = "expr|true|first", b = "expr|result|second" },
	doc = "Luau functions can hand back several values. Catching them takes " ..
		"a `make several` block.",
	tags = "return multiple two values tuple" }

D{ id = "paramDefault", cat = "funcs", group = "Running", label = "give an input a default",
	head = "make {name} default to {fallback} if it was not given",
	code = "{name} = {name} or {fallback}",
	fields = { name = "expr|amount|input name", fallback = "expr|1|default" },
	doc = "The first line of many functions. A missing input arrives as nil, " ..
		"which `or` replaces.",
	tags = "default optional parameter argument or" }

D{ id = "funcOnce", cat = "funcs", group = "Running", label = "run it later, once",
	head = "run {name} after {seconds} seconds",
	code = "task.delay({seconds}, {name})",
	fields = { name = "expr|cleanUp|function", seconds = "num|3|seconds" },
	doc = "Passing the function itself rather than calling it is the point: " ..
		"no brackets, or it would run immediately.",
	tags = "delay later schedule callback timer" }

D{ id = "moduleReturn", cat = "funcs", group = "Modules", label = "hand the module back",
	head = "hand the module {name} back",
	code = "return {name}",
	fields = { name = "expr|Module|module" },
	doc = "The last line of every ModuleScript. Without it, everything that " ..
		"requires this file gets nothing.",
	tags = "return module end require table" }

D{ id = "requireChild", cat = "funcs", group = "Modules", label = "use a module beside this one",
	head = 'make {name} = the module "{child}" next to this script',
	code = 'local {name} = require(script.Parent:WaitForChild("{child}"))',
	fields = { name = "name|Helper|name", child = "str|Helper|module name" },
	doc = "Waiting for the child first means this works on the client too, " ..
		"where things arrive over the network in their own time.",
	tags = "require module sibling waitforchild import" }

--=============================================================================
-- INSTANCES
--=============================================================================

D{ id = "instRename", cat = "inst", group = "Basics", label = "rename",
	head = 'rename {obj} to "{name}"',
	code = '{obj}.Name = "{name}"',
	fields = { obj = "expr|part|object", name = "str|Door|new name" },
	doc = "Names need not be unique, which is why FindFirstChild gives you " ..
		"the first one rather than the one.",
	tags = "name rename label object" }

D{ id = "instResize", cat = "inst", group = "Basics", label = "resize a part",
	head = "resize {obj} to {x} by {y} by {z} studs",
	code = "{obj}.Size = Vector3.new({x}, {y}, {z})",
	fields = { obj = "expr|part|part", x = "expr|4|width", y = "expr|1|height", z = "expr|4|depth" },
	doc = "Parts resize around their centre, so a part on the floor will " ..
		"sink into it when it grows.",
	tags = "size resize scale part dimensions" }

D{ id = "instFade", cat = "inst", group = "Basics", label = "set see-through",
	head = "set how see-through {obj} is to {value}",
	code = "{obj}.Transparency = {value}",
	fields = { obj = "expr|part|part", value = "num|0.5|amount" },
	doc = "1 is fully invisible but still solid. Turn off CanCollide as well " ..
		"if it should be walked through.",
	tags = "transparency invisible fade part" }

D{ id = "instMaterial", cat = "inst", group = "Basics", label = "set the material",
	head = "make {obj} out of {material}",
	code = "{obj}.Material = Enum.Material.{material}",
	fields = { obj = "expr|part|part",
		material = "choice|Plastic|material|Plastic,SmoothPlastic,Neon,Glass,Wood,WoodPlanks,Metal,DiamondPlate,Concrete,Brick,Grass,Sand,Ice,Marble,Slate,ForceField" },
	doc = "Material changes the look and, for terrain-like materials, some " ..
		"of the physics feel too.",
	tags = "material texture look neon glass wood" }

D{ id = "instNudge", cat = "inst", group = "Moving", label = "nudge",
	head = "nudge {obj} by ({x}, {y}, {z})",
	code = "{obj}.Position = {obj}.Position + Vector3.new({x}, {y}, {z})",
	fields = { obj = "expr|part|part", x = "expr|0|x", y = "expr|1|y", z = "expr|0|z" },
	doc = "Relative to where it already is, rather than an absolute place.",
	tags = "move offset nudge relative position" }

D{ id = "instMoveModel", cat = "inst", group = "Moving", label = "nudge a model",
	head = "nudge {model} by ({x}, {y}, {z})",
	code = "{model}:PivotTo({model}:GetPivot() * CFrame.new({x}, {y}, {z}))",
	fields = { model = "expr|model|model", x = "expr|0|x", y = "expr|5|y", z = "expr|0|z" },
	doc = "Takes where the model is, offsets it, and puts it back. The only " ..
		"safe way to move a model without pulling it apart.",
	tags = "pivotto move model offset relative" }

D{ id = "instTurn", cat = "inst", group = "Moving", label = "turn a part",
	head = "turn {obj} by {n} degrees",
	code = "{obj}.CFrame = {obj}.CFrame * CFrame.Angles(0, math.rad({n}), 0)",
	fields = { obj = "expr|part|part", n = "expr|90|degrees" },
	doc = "Turns it on the spot around its own upright axis.",
	tags = "rotate turn cframe angles degrees" }

D{ id = "instFaceTowards", cat = "inst", group = "Moving", label = "point a part at",
	head = "point {obj} at {target}",
	code = "{obj}.CFrame = CFrame.lookAt({obj}.Position, {target})",
	fields = { obj = "expr|turret|part", target = "expr|player.Character.PrimaryPart.Position|target" },
	doc = "Keeps it where it is and swings it round to face something. " ..
		"Turrets and signs use this.",
	tags = "lookat face point aim turret" }

D{ id = "instFindDeep", cat = "inst", group = "Finding", label = "find anywhere inside",
	head = 'make {name} = the first "{child}" anywhere inside {obj}',
	code = 'local {name} = {obj}:FindFirstChild("{child}", true)',
	fields = { name = "name|found|name", obj = "expr|model|where to look", child = "str|Handle|name" },
	doc = "The `true` makes it search all the way down rather than one level. " ..
		"Slower, so do it once and keep the result.",
	tags = "findfirstchild recursive deep search nested" }

D{ id = "instFindByClass", cat = "inst", group = "Finding", label = "find by kind",
	head = "make {name} = the first {class} inside {obj}",
	code = 'local {name} = {obj}:FindFirstChildOfClass("{class}")',
	fields = { name = "name|found|name", obj = "expr|character|where to look",
		class = "choice:class|Humanoid|class|Humanoid,BasePart,Part,Model,Sound,Tool,Animator,ClickDetector,ProximityPrompt" },
	doc = "By kind rather than by name, which is more reliable when you did " ..
		"not choose the names.",
	tags = "findfirstchildofclass class kind find" }

D{ id = "instParentOf", cat = "inst", group = "Finding", label = "what it is inside",
	head = "make {name} = what {obj} is inside",
	code = "local {name} = {obj}.Parent",
	fields = { name = "name|holder|name", obj = "expr|hit|object" },
	doc = "For a limb hit by a Touched event, the parent is the character " ..
		"model. That single step is most of hit detection.",
	tags = "parent holder container hit character" }

D{ id = "instRemoveChildren", cat = "inst", group = "Finding", label = "empty something out",
	head = "remove everything inside {obj}",
	code = "{obj}:ClearAllChildren()",
	fields = { obj = "expr|folder|object" },
	doc = "Destroys every child but keeps the object itself. Clearing a " ..
		"folder between rounds is one line.",
	tags = "clearallchildren empty clear reset folder" }

D{ id = "instCountChildren", cat = "inst", group = "Finding", label = "count what is inside",
	head = "make {name} = how many things are inside {obj}",
	code = "local {name} = #{obj}:GetChildren()",
	fields = { name = "name|count|name", obj = "expr|folder|object" },
	doc = "One level only. Use descendants for everything at any depth.",
	tags = "count children how many folder" }

D{ id = "instMakeIn", cat = "inst", group = "Basics", label = "make a new one inside",
	head = "make {name} = a new {class} inside {parent}",
	code = {
		'local {name} = Instance.new("{class}")',
		"{name}.Parent = {parent}",
	},
	fields = { name = "name|made|name", parent = "expr|script.Parent|parent",
		class = "choice:class|Folder|class|Folder,IntValue,StringValue,BoolValue,NumberValue,ObjectValue,Attachment,Highlight,ProximityPrompt,ClickDetector,Sound" },
	doc = "Making and parenting in one block, for the small helper objects " ..
		"where there is nothing to set in between.",
	tags = "instance new parent create shortcut" }

--=============================================================================
-- PLAYERS
--=============================================================================

D{ id = "playerFromPart", cat = "player", group = "Finding", label = "the player from a part",
	head = "make {name} = the player that {part} belongs to",
	code = "local {name} = Players:GetPlayerFromCharacter({part}.Parent)",
	fields = { name = "name|who|name", part = "expr|hit|part" },
	needs = { "Players" },
	doc = "Turns a limb from a Touched event back into a player. Nil when it " ..
		"was scenery or an NPC rather than a person.",
	tags = "getplayerfromcharacter hit touched player who" }

D{ id = "playerRoot", cat = "player", group = "Finding", label = "the middle of a character",
	head = "make {name} = the middle part of {char}",
	code = 'local {name} = {char}:FindFirstChild("HumanoidRootPart")',
	fields = { name = "name|root|name", char = "expr|char|character" },
	doc = "The HumanoidRootPart is the invisible part everything else hangs " ..
		"off. Measure distances and move characters from here.",
	tags = "humanoidrootpart root position character middle" }

D{ id = "playerIsAlive", cat = "player", group = "Finding", label = "if they are alive",
	head = "if {player} is alive then",
	code = {
		"local char = {player}.Character",
		'local hum = char and char:FindFirstChildOfClass("Humanoid")',
		"if hum and hum.Health > 0 then",
	},
	codeTail = { "end" }, tail = "end",
	fields = { player = "expr|player|player" },
	slots = { { key = "body" } },
	doc = "The full check in one block: they have a body, it has a Humanoid, " ..
		"and it has health left.",
	tags = "alive health check character humanoid" }

D{ id = "playerHealthFraction", cat = "player", group = "Finding", label = "health as a fraction",
	head = "make {name} = the health of {hum} as a fraction",
	code = "local {name} = {hum}.Health / {hum}.MaxHealth",
	fields = { name = "name|fraction|name", hum = "expr|hum|humanoid" },
	doc = "A number from 0 to 1, which is exactly what a health bar wants.",
	tags = "health fraction bar percentage humanoid" }

D{ id = "playerSetMaxHealth", cat = "player", group = "Changing", label = "set the maximum health",
	head = "set the maximum health of {hum} to {n}",
	code = { "{hum}.MaxHealth = {n}", "{hum}.Health = {n}" },
	fields = { hum = "expr|hum|humanoid", n = "num|200|health" },
	doc = "Raising the maximum alone leaves them short of full, so this " ..
		"tops them up as well.",
	tags = "maxhealth health humanoid upgrade" }

D{ id = "playerFreeze", cat = "player", group = "Changing", label = "freeze a player",
	head = "freeze {hum}",
	code = { "{hum}.WalkSpeed = 0", "{hum}.JumpPower = 0", "{hum}.UseJumpPower = true" },
	fields = { hum = "expr|hum|humanoid" },
	doc = "Stops them walking and jumping without any of the strangeness of " ..
		"anchoring a character.",
	tags = "freeze stop walkspeed jump cutscene" }

D{ id = "playerUnfreeze", cat = "player", group = "Changing", label = "unfreeze a player",
	head = "unfreeze {hum}",
	code = { "{hum}.WalkSpeed = 16", "{hum}.JumpPower = 50" },
	fields = { hum = "expr|hum|humanoid" },
	doc = "Puts them back to Roblox's defaults. Store the old numbers first " ..
		"if you changed them.",
	tags = "unfreeze restore walkspeed jump defaults" }

D{ id = "playerForceField", cat = "player", group = "Changing", label = "protect a player",
	head = "protect {char} for {seconds} seconds",
	code = {
		"do",
		'\tlocal shield = Instance.new("ForceField")',
		"\tshield.Visible = {visible}",
		"\tshield.Parent = {char}",
		"\tDebris:AddItem(shield, {seconds})",
		"end",
	},
	fields = { char = "expr|char|character", seconds = "num|5|seconds",
		visible = "choice|true|visible|true,false" },
	needs = { "Debris" },
	doc = "A ForceField blocks TakeDamage entirely. Debris removes it after " ..
		"the time is up without a wait of your own.",
	tags = "forcefield spawn protection invulnerable shield" }

D{ id = "playerTeam", cat = "player", group = "Teams", label = "put on a team",
	head = 'put {player} on the team "{team}"',
	code = 'local team = game:GetService("Teams"):FindFirstChild("{team}")\n' ..
		"if team then\n\t{player}.Team = team\nend",
	fields = { player = "expr|player|player", team = "str|Red|team name" },
	side = "server",
	doc = "Teams live in the Teams service. Checking it exists first means a " ..
		"typo does not kill the script.",
	tags = "team teams assign side red blue" }

D{ id = "playerSameTeam", cat = "player", group = "Teams", label = "if on the same team",
	head = "if {a} and {b} are on the same team then",
	code = "if {a}.Team == {b}.Team then", tail = "end",
	fields = { a = "expr|player|first", b = "expr|other|second" },
	slots = { { key = "body" } },
	doc = "Stopping friendly fire is this check in front of the damage.",
	tags = "team same friendly fire check" }

D{ id = "playerEachOnTeam", cat = "player", group = "Teams", label = "for each player on a team",
	head = 'for each {player} on the team "{team}"',
	code = {
		"for _, {player} in ipairs(Players:GetPlayers()) do",
		'\tif {player}.Team and {player}.Team.Name == "{team}" then',
	},
	codeTail = { "\tend", "end" }, tail = "end",
	bodyIndent = 2,
	fields = { player = "name|player|player", team = "str|Red|team name" },
	slots = { { key = "body" } },
	needs = { "Players" },
	doc = "Walks everyone and skips anyone not on that team. Checking the " ..
		"team exists first covers players who have not been assigned one.",
	tags = "team players loop each side" }

D{ id = "playerStatValue", cat = "player", group = "Leaderboard", label = "read a leaderboard stat",
	head = 'make {name} = the "{stat}" of {player}',
	code = {
		"local {name} = 0",
		"do",
		'\tlocal folder = {player}:FindFirstChild("leaderstats")',
		'\tlocal stat = folder and folder:FindFirstChild("{stat}")',
		"\tif stat then",
		"\t\t{name} = stat.Value",
		"\tend",
		"end",
	},
	fields = { name = "name|coins|name", player = "expr|player|player", stat = "str|Coins|stat name" },
	doc = "Checks each step, so a player without leaderstats yet reads as " ..
		"zero rather than erroring.",
	tags = "leaderstats read value stat safe" }

D{ id = "playerSetStat", cat = "player", group = "Leaderboard", label = "set a leaderboard stat",
	head = 'set the "{stat}" of {player} to {value}',
	code = {
		"do",
		'\tlocal folder = {player}:FindFirstChild("leaderstats")',
		'\tlocal stat = folder and folder:FindFirstChild("{stat}")',
		"\tif stat then",
		"\t\tstat.Value = {value}",
		"\tend",
		"end",
	},
	fields = { player = "expr|player|player", stat = "str|Coins|stat name", value = "expr|0|value" },
	side = "server",
	doc = "Setting outright rather than adding. Only the server should touch " ..
		"these, or the change will not stick.",
	tags = "leaderstats set value stat server" }

--=============================================================================
-- DATA
--=============================================================================

D{ id = "dataNestedGet", cat = "data", group = "Nesting", label = "read a nested value",
	head = "make {name} = {key} of {sub} of {tbl}",
	code = "local {name} = {tbl}[{sub}] and {tbl}[{sub}][{key}] or nil",
	fields = { name = "name|value|name", tbl = "expr|data|table", sub = "expr|player|first key",
		key = "expr|\"coins\"|second key" },
	doc = "Checking the middle step first stops the whole thing erroring when " ..
		"the outer key is missing.",
	tags = "nested table deep read safe index" }

D{ id = "dataNestedSet", cat = "data", group = "Nesting", label = "write a nested value",
	head = "set {key} of {sub} of {tbl} to {value}",
	code = {
		"if {tbl}[{sub}] == nil then",
		"\t{tbl}[{sub}] = {}",
		"end",
		"{tbl}[{sub}][{key}] = {value}",
	},
	fields = { tbl = "expr|data|table", sub = "expr|player|first key", key = "expr|\"coins\"|second key",
		value = "expr|0|value" },
	doc = "Makes the inner table if it is not there yet, which is what stops " ..
		"the write failing the first time.",
	tags = "nested table write create deep" }

D{ id = "dataHasKey", cat = "data", group = "Nesting", label = "if a key is there",
	head = "if {tbl} has {key} then",
	code = "if {tbl}[{key}] ~= nil then", tail = "end",
	fields = { tbl = "expr|record|table", key = "expr|\"name\"|key" },
	slots = { { key = "body" } },
	doc = "Comparing to nil rather than testing truth, so a key holding " ..
		"`false` still counts as present.",
	tags = "haskey contains nil check dictionary" }

D{ id = "dataChangeKey", cat = "data", group = "Nesting", label = "change a number in a table",
	head = "change {key} of {tbl} by {amount}",
	code = "{tbl}[{key}] = ({tbl}[{key}] or 0) + {amount}",
	fields = { tbl = "expr|scores|table", key = "expr|player|key", amount = "expr|1|amount" },
	doc = "The `or 0` covers the first time, so there is no need to set it " ..
		"up beforehand.",
	tags = "increment tally counter table key" }

D{ id = "dataPushUnique", cat = "data", group = "Lists", label = "add if not already there",
	head = "add {value} to {list} if it is not there already",
	code = {
		"if not table.find({list}, {value}) then",
		"\ttable.insert({list}, {value})",
		"end",
	},
	fields = { list = "expr|list|list", value = "expr|item|value" },
	doc = "Keeps a list free of duplicates without a separate check every " ..
		"time you add to it.",
	tags = "unique insert duplicate once list" }

D{ id = "dataToText", cat = "data", group = "Saving", label = "table to text",
	head = "make {name} = {tbl} written as text",
	code = "local {name} = HttpService:JSONEncode({tbl})",
	fields = { name = "name|text|name", tbl = "expr|data|table" },
	needs = { "HttpService" },
	doc = "Turns a table into a single string, which is how you save " ..
		"something complicated in one value.",
	tags = "json encode text save serialise" }

D{ id = "dataFromText", cat = "data", group = "Saving", label = "text to table",
	head = "make {name} = the table inside {text}",
	code = {
		"local {name} = nil",
		"do",
		"\tlocal ok, decoded = pcall(function()",
		"\t\treturn HttpService:JSONDecode({text})",
		"\tend)",
		"\tif ok then",
		"\t\t{name} = decoded",
		"\tend",
		"end",
	},
	fields = { name = "name|data|name", text = "expr|saved|text" },
	needs = { "HttpService" },
	doc = "Wrapped, because text that is not valid JSON throws rather than " ..
		"handing back nil.",
	tags = "json decode parse load safe" }

D{ id = "dataListOfNames", cat = "data", group = "Lists", label = "list of names",
	head = "make {name} = the names of everything in {list}",
	code = {
		"local {name} = {}",
		"for _, thing in ipairs({list}) do",
		"\ttable.insert({name}, thing.Name)",
		"end",
	},
	fields = { name = "name|names|name", list = "expr|players|list" },
	doc = "Turning a list of players or parts into a list of names, which is " ..
		"what you want before joining them into a sentence.",
	tags = "names list map players parts" }

--=============================================================================
-- ODDS AND ENDS
--=============================================================================

D{ id = "onToolUsed", cat = "events", group = "Tools", label = "on a tool used",
	head = "when {tool} is used",
	code = "{tool}.Activated:Connect(function()", tail = "end)",
	fields = { tool = "expr|script.Parent|tool" },
	slots = { { key = "body" } },
	doc = "Fires when the player clicks while holding it. The whole of a " ..
		"sword swing or a gun shot starts here.",
	tags = "tool activated click use swing" }

D{ id = "onToolHeld", cat = "events", group = "Tools", label = "on a tool taken out",
	head = "when {tool} is taken out, with {char}",
	code = {
		"{tool}.Equipped:Connect(function()",
		"\tlocal {char} = {tool}.Parent",
	},
	codeTail = { "end)" }, tail = "end",
	fields = { tool = "expr|script.Parent|tool", char = "name|char|character" },
	slots = { { key = "body" } },
	doc = "While a tool is held its parent is the character, which is how it " ..
		"finds out whose hands it is in.",
	tags = "tool equipped hold character take out" }

D{ id = "onToolAway", cat = "events", group = "Tools", label = "on a tool put away",
	head = "when {tool} is put away",
	code = "{tool}.Unequipped:Connect(function()", tail = "end)",
	fields = { tool = "expr|script.Parent|tool" },
	slots = { { key = "body" } },
	doc = "Stop any looping effects here, or a holstered tool keeps running.",
	tags = "tool unequipped away holster stop" }

D{ id = "onFirstSpawn", cat = "events", group = "Players", label = "on their first spawn only",
	head = "when {player} spawns for the first time, as {char}",
	code = "{player}.CharacterAdded:Once(function({char})", tail = "end)",
	fields = { player = "expr|player|player", char = "name|char|character" },
	slots = { { key = "body" } },
	doc = "`Once` disconnects itself, so this skips every respawn after the " ..
		"first. Good for a welcome message.",
	tags = "once first spawn characteradded welcome" }

D{ id = "onZoneEnter", cat = "events", group = "In the world", label = "on a player entering",
	head = "when a player walks into {part}, as {player}",
	code = {
		"{part}.Touched:Connect(function(hit)",
		"\tlocal {player} = Players:GetPlayerFromCharacter(hit.Parent)",
		"\tif {player} then",
	},
	codeTail = { "\tend", "end)" }, tail = "end",
	bodyIndent = 2,
	fields = { part = "expr|script.Parent|part", player = "name|player|player" },
	slots = { { key = "body" } },
	needs = { "Players" }, side = "server",
	doc = "Touched plus the player lookup plus the check, which is the shape " ..
		"nearly every zone needs. Add a debounce inside.",
	tags = "zone touched player enter trigger area" }

D{ id = "ctrlDoNothing", cat = "control", group = "Timing", label = "do nothing",
	head = "do nothing",
	code = "-- nothing to do here",
	doc = "A placeholder for a branch you have not written yet, so the shape " ..
		"of the program is visible before the details are.",
	tags = "nothing placeholder empty todo stub" }

D{ id = "ctrlWaitRandom", cat = "control", group = "Timing", label = "wait a random time",
	head = "wait between {low} and {high} seconds",
	code = "task.wait({low} + math.random() * ({high} - {low}))",
	fields = { low = "num|1|shortest", high = "num|3|longest" },
	doc = "Staggering waits stops fifty NPCs all acting on exactly the same " ..
		"frame, which both looks wrong and costs more.",
	tags = "wait random stagger delay vary" }

D{ id = "ctrlEachCharacter", cat = "control", group = "Over objects", label = "for each character",
	head = "for each spawned character {char}",
	code = {
		"for _, player in ipairs(Players:GetPlayers()) do",
		"\tlocal {char} = player.Character",
		"\tif {char} then",
	},
	codeTail = { "\tend", "end" }, tail = "end",
	bodyIndent = 2,
	fields = { char = "name|char|character" },
	slots = { { key = "body" } },
	needs = { "Players" },
	doc = "Skips anyone who is dead or still loading, which a plain player " ..
		"loop would not.",
	tags = "characters loop players spawned each" }

D{ id = "logicOnGround", cat = "logic", group = "Characters", label = "if standing on the ground",
	head = "if {hum} is on the ground then",
	code = "if {hum}.FloorMaterial ~= Enum.Material.Air then", tail = "end",
	fields = { hum = "expr|hum|humanoid" },
	slots = { { key = "body" } },
	doc = "FloorMaterial is Air when nothing is underfoot, which is a more " ..
		"reliable ground check than watching for jump states.",
	tags = "floormaterial ground grounded jump check" }

D{ id = "logicMoving", cat = "logic", group = "Characters", label = "if moving",
	head = "if {hum} is moving then",
	code = "if {hum}.MoveDirection.Magnitude > 0 then", tail = "end",
	fields = { hum = "expr|hum|humanoid" },
	slots = { { key = "body" } },
	doc = "MoveDirection is which way they are trying to go. Length zero " ..
		"means standing still.",
	tags = "movedirection moving walking still check" }

D{ id = "logicHoldingTool", cat = "logic", group = "Characters", label = "if holding a tool",
	head = "if {char} is holding a tool then",
	code = 'if {char}:FindFirstChildOfClass("Tool") then', tail = "end",
	fields = { char = "expr|char|character" },
	slots = { { key = "body" } },
	doc = "A held tool sits inside the character. In the backpack it is not " ..
		"held, so it will not be found here.",
	tags = "tool holding equipped check character" }

D{ id = "mathSpeedOf", cat = "math", group = "Working out", label = "how fast something is going",
	head = "make {var} = how fast {part} is going",
	code = "{var} = {part}.AssemblyLinearVelocity.Magnitude",
	fields = { var = "expr|speed|variable", part = "expr|part|part" },
	doc = "The length of its velocity, in studs per second. A walking " ..
		"character is about 16.",
	tags = "speed velocity magnitude fast measure" }

D{ id = "mathFlatDistance", cat = "math", group = "Working out", label = "distance on the flat",
	head = "make {var} = how far {a} is from {b} on the flat",
	code = {
		"do",
		"\tlocal gap = {a} - {b}",
		"\t{var} = Vector3.new(gap.X, 0, gap.Z).Magnitude",
		"end",
	},
	fields = { var = "expr|gap|variable", a = "expr|part.Position|first", b = "expr|target.Position|second" },
	doc = "Ignores height, so somebody on a balcony still counts as near " ..
		"what is below them.",
	tags = "distance flat horizontal ignore height" }

D{ id = "textList", cat = "text", group = "Building", label = "join a list nicely",
	head = 'make {var} = {list} joined with commas and "and"',
	code = {
		"if #{list} <= 1 then",
		'\t{var} = {list}[1] or ""',
		"else",
		'\t{var} = table.concat({list}, ", ", 1, #{list} - 1) .. " and " .. {list}[#{list}]',
		"end",
	},
	fields = { var = "expr|sentence|variable", list = "expr|names|list" },
	doc = "Gives `Ana, Ben and Cara` rather than `Ana, Ben, Cara`. Small " ..
		"touch, and it makes generated text read like writing.",
	tags = "join list and commas sentence readable" }

D{ id = "instShape", cat = "inst", group = "Basics", label = "set the shape",
	head = "make {obj} a {shape}",
	code = "{obj}.Shape = Enum.PartType.{shape}",
	fields = { obj = "expr|part|part",
		shape = "choice|Ball|shape|Block,Ball,Cylinder,Wedge,CornerWedge" },
	doc = "Only works on a plain Part. MeshParts and unions have their shape " ..
		"baked in.",
	tags = "shape parttype ball cylinder wedge" }

D{ id = "instPlaceExactly", cat = "inst", group = "Moving", label = "place with a facing",
	head = "place {obj} at {cf}",
	code = "{obj}.CFrame = {cf}",
	fields = { obj = "expr|part|part", cf = "expr|CFrame.new(0, 10, 0)|place" },
	doc = "Sets position and facing together. Anything built out of `a place " ..
		"looking at` ends up here.",
	tags = "cframe place position facing set" }

D{ id = "instToggleAnchor", cat = "inst", group = "Basics", label = "flip anchored",
	head = "flip whether {obj} is anchored",
	code = "{obj}.Anchored = not {obj}.Anchored",
	fields = { obj = "expr|part|part" },
	doc = "Turns it into the opposite of whatever it is now, which is what a " ..
		"switch or a lever wants.",
	tags = "anchor toggle flip physics switch" }

D{ id = "playerBoostSpeed", cat = "player", group = "Changing", label = "boost speed for a while",
	head = "give {hum} {n} walk speed for {seconds} seconds",
	code = {
		"do",
		"\tlocal was = {hum}.WalkSpeed",
		"\t{hum}.WalkSpeed = {n}",
		"\ttask.delay({seconds}, function()",
		"\t\tif {hum}.Parent then",
		"\t\t\t{hum}.WalkSpeed = was",
		"\t\tend",
		"\tend)",
		"end",
	},
	fields = { hum = "expr|hum|humanoid", n = "num|32|speed", seconds = "num|10|seconds" },
	doc = "Remembers the old speed rather than assuming 16, so two boosts " ..
		"cannot leave someone permanently slow.",
	tags = "speed boost powerup temporary restore" }

D{ id = "playerRespawnAfter", cat = "player", group = "Changing", label = "respawn after a delay",
	head = "respawn {player} after {seconds} seconds",
	code = {
		"task.delay({seconds}, function()",
		"\tif {player}.Parent then",
		"\t\t{player}:LoadCharacter()",
		"\tend",
		"end)",
	},
	fields = { player = "expr|player|player", seconds = "num|5|seconds" },
	side = "server",
	doc = "Checking they are still in the game first avoids an error when " ..
		"somebody leaves during the wait.",
	tags = "respawn delay loadcharacter death timer" }

D{ id = "dataRandomKey", cat = "data", group = "Nesting", label = "a random key",
	head = "make {name} = a random key from {record}",
	code = {
		"local {name} = nil",
		"do",
		"\tlocal keys = {}",
		"\tfor key in pairs({record}) do",
		"\t\ttable.insert(keys, key)",
		"\tend",
		"\tif #keys > 0 then",
		"\t\t{name} = keys[math.random(1, #keys)]",
		"\tend",
		"end",
	},
	fields = { name = "name|picked|name", record = "expr|record|record" },
	doc = "Dictionaries cannot be indexed by number, so picking at random " ..
		"means listing the keys first.",
	tags = "random key dictionary pick choose" }

D{ id = "sectionNote", cat = "special", group = "Notes", label = "section heading",
	head = "-- {text} --",
	code = { "", "-- {text}" },
	fields = { text = "str|set up|heading" },
	doc = "A blank line and a comment, for breaking a long script into parts " ..
		"a reader can scan.",
	tags = "comment section heading divider organise" }

D{ id = "todoNote", cat = "special", group = "Notes", label = "to do",
	head = "to do: {text}",
	code = "-- TODO: {text}",
	fields = { text = "str|handle the empty case|what to do" },
	doc = "Marks something unfinished. Studio's script analysis can list " ..
		"every TODO in your place.",
	tags = "todo comment unfinished note reminder" }

D{ id = "rawMultiline", cat = "special", group = "Notes", label = "long comment",
	head = "long note: {text}",
	code = { "--[[", "\t{text}", "]]" },
	fields = { text = "multiline|Explain the tricky bit here.|note" },
	doc = "A comment spanning several lines, for explaining something that " ..
		"needs more than one.",
	tags = "comment long block multiline explain" }

end
