--!nonstrict
-- j  ·  tutorial content
--
-- Twenty-six lessons: one per teaching category, then sixteen on the craft of
-- using the editor and of writing Roblox code that behaves.
--
-- A step is a small tagged table, rendered by `k`:
--   { p = "..." }        a paragraph
--   { h = "..." }        a sub-heading
--   { code = "..." }     Luau, syntax highlighted
--   { blocks = "a,b" }   the blocks this lesson uses, as chips
--   { note = "..." }     an aside worth knowing
--   { warn = "..." }     a mistake worth avoiding
--   { list = { ... } }   a numbered run of short lines
--   { try = "..." }      something to go and do
--
-- `example` is real Luau.  The lesson's "put this on my canvas" button runs it
-- through the importer, so every example is also a test of the converter.

local j = {}

j.tutorials = {}

local function T(entry)
	j.tutorials[#j.tutorials + 1] = entry
	return entry
end

--=============================================================================
-- category lessons
--=============================================================================

T{
	id = "cat-events", kind = "category", cat = "events", minutes = 5,
	level = "start",
	title = "Events: code that waits",
	blurb = "Nothing in a Roblox game runs because you asked nicely. Something has to happen first.",
	steps = {
		{ p = "A script that runs top to bottom and stops is not much of a game. Roblox games are built out of moments: a player joins, a part is touched, a key goes down, a frame is drawn. An event block is how you say 'when that moment comes, run these blocks'." },
		{ h = "The shape of an event" },
		{ p = "Every event block is a container. The blocks you drop inside it do not run when the script starts -- they sit there, waiting, and run each time the event fires. That is why the inside of an event block is indented: it belongs to the event, not to the script." },
		{ blocks = "onTouch,onPlayerAdded,onHeartbeat,onKey" },
		{ p = "Drag `when {part} is touched by {hit}` onto the canvas, put a `print` inside it, and look at the Luau panel:" },
		{ code = 'script.Parent.Touched:Connect(function(hit)\n\tprint(hit)\nend)' },
		{ p = "`Connect` is the important word. You are handing Roblox a function and asking it to hold on to it. Roblox calls it back later, once per touch, and hands you information about what happened -- here, the part that did the touching." },
		{ h = "The value the event gives you" },
		{ p = "That `hit` is a gift. A Touched event without it would only tell you that something happened; with it you can ask what happened. `hit.Parent` is usually the character model, which is how you get from 'a part was touched' to 'a player stepped on it'." },
		{ code = 'script.Parent.Touched:Connect(function(hit)\n\tlocal hum = hit.Parent:FindFirstChildOfClass("Humanoid")\n\tif hum then\n\t\thum:TakeDamage(10)\n\tend\nend)' },
		{ note = "Touched fires a lot -- once per limb, several times a second, for one player standing on a part. Every event block that fires often deserves a check inside it that gets out early." },
		{ h = "Events fire more than once" },
		{ p = "This surprises everyone at least once. `CharacterAdded` fires on every respawn, not just the first spawn. `Touched` fires again the moment a foot wobbles. If your code must only happen once, you have to say so -- with a variable that remembers, or with the `the first time ... happens` block, which disconnects itself after one fire." },
		{ warn = "If you connect an event inside another event, you create a new connection every time the outer one fires. Connect a Touched handler inside PlayerAdded for a hundred players and you have a hundred handlers on the same part." },
		{ try = "Build a part that damages a player once, waits three seconds, then can damage again. You will need an event block, a variable, and an if block." },
	},
	example = [[
local Players = game:GetService("Players")

local trap = script.Parent
local armed = true

trap.Touched:Connect(function(hit)
	if not armed then return end
	local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
	if hum then
		armed = false
		hum:TakeDamage(25)
		task.wait(3)
		armed = true
	end
end)

Players.PlayerAdded:Connect(function(player)
	print(player.Name)
end)
]],
}

T{
	id = "cat-control", kind = "category", cat = "control", minutes = 5,
	level = "start",
	title = "Control: choosing and repeating",
	blurb = "Two ideas -- do this only sometimes, and do this again -- cover most of what a program does.",
	steps = {
		{ p = "Control blocks decide which of your other blocks run, and how often. There are only a handful of them and you will use them constantly." },
		{ h = "Choosing" },
		{ p = "`if` runs the blocks inside only when its condition is true. `if / else` adds a second path that runs when it is not. Dropping another `if / else` into the `otherwise` slot builds a chain -- and the code panel writes that back as `elseif`, so a five-way choice stays flat instead of marching off the right of the screen." },
		{ blocks = "if,ifelse,while,for,foripairs,wait" },
		{ h = "Repeating" },
		{ p = "There are four ways to repeat, and picking the right one makes the rest of the code easier." },
		{ list = {
			"`count {i} from {a} to {b}` -- when you know how many times, and you want the number.",
			"`repeat {n} times` -- when you know how many times and do not care about the number.",
			"`for each item` -- when you have a list and want each thing in it.",
			"`keep going while {condition}` -- when you do not know how many times, only when to stop.",
		} },
		{ code = 'for i = 1, 10 do\n\tprint(i)\nend\n\nfor _, part in ipairs(workspace:GetChildren()) do\n\tprint(part.Name)\nend' },
		{ h = "The one rule about while" },
		{ p = "A `while` loop with no wait inside it never gives the rest of the game a turn. Roblox will freeze, and after a few seconds Studio will stop the script and tell you it was not responding. Put a `wait` block inside every `while` loop unless you can prove it finishes quickly." },
		{ warn = "`while true do ... end` with no wait is the single most common way to lock up a place. If your test freezes the moment you press Play, this is why." },
		{ h = "Stopping early" },
		{ p = "`stop the loop` leaves the loop it is inside straight away. `skip to the next turn` abandons this pass and starts the next one. Both only make sense inside a loop, and the editor will let you put them elsewhere -- Luau will not." },
		{ try = "Count down from 5 to 1 with a one-second wait between each, then print 'go'. Use `count by step` with a step of -1." },
	},
	example = [[
for i = 5, 1, -1 do
	print(i)
	task.wait(1)
end

print("go")

local coins = { "gold", "silver", "bronze" }

for index, coin in ipairs(coins) do
	print(index, coin)
end

local hunting = true

while hunting do
	task.wait(0.5)
	if #coins == 0 then
		hunting = false
	end
end
]],
}

T{
	id = "cat-logic", kind = "category", cat = "logic", minutes = 4,
	level = "start",
	title = "Logic: true or false",
	blurb = "Every branch in your game comes down to one question with a yes-or-no answer.",
	steps = {
		{ p = "A condition is any expression that comes out true or false. Logic blocks are the questions worth asking, written the way you would say them out loud." },
		{ blocks = "ifCompare,ifBoth,ifEither,ifNot,ifExists,guard,ifIsA" },
		{ h = "Comparing" },
		{ p = "The `if {a} {op} {b}` block covers all six comparisons in one block -- pick the operator from the dropdown. `==` asks whether two things are the same. `~=` asks whether they differ, and that squiggle catches everyone once; in Luau it is `~=`, not `!=`." },
		{ warn = "`=` and `==` are different. One `=` sets a value; two `==` compares. `if hp = 0` is not a question, it is a mistake, and Luau will refuse it." },
		{ h = "Combining" },
		{ p = "`and` needs both sides to be true. `or` needs at least one. Both are lazy: if the left side of an `and` is false, Luau never looks at the right side. That is not a detail, it is a tool -- it is what makes this safe:" },
		{ code = 'if hum and hum.Health > 0 then\n\tprint("alive")\nend' },
		{ p = "If `hum` is nil, the check stops there and never touches `.Health`, which would have thrown an error. Written the other way round it would crash." },
		{ h = "Truthiness" },
		{ p = "In Luau only two values are false: `false` and `nil`. Everything else is true -- including 0 and the empty string, which trip up people arriving from other languages. That is why `if {value} exists` is the standard way to check whether an object was found." },
		{ h = "Guards" },
		{ p = "`stop here unless {condition}` puts the check at the top and leaves early when it fails. Three guards at the top of a function are much easier to read than three nested ifs, because the real work stays at the left margin." },
		{ code = 'local function damage(player, amount)\n\tif not player then return end\n\tlocal char = player.Character\n\tif not char then return end\n\tlocal hum = char:FindFirstChildOfClass("Humanoid")\n\tif not hum then return end\n\thum:TakeDamage(amount)\nend' },
		{ try = "Take a deeply nested if from something you have written and turn the outer layers into guards. Count the indentation you got back." },
	},
	example = [[
local function damage(player, amount)
	if not player then return end
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum:TakeDamage(amount)
end

local hp = 100

if hp <= 0 then
	print("dead")
elseif hp < 25 then
	print("hurt")
else
	print("fine")
end
]],
}

T{
	id = "cat-math", kind = "category", cat = "math", minutes = 5,
	level = "build",
	title = "Math: numbers that move things",
	blurb = "Scores, speeds, positions, chances. Six or seven blocks cover nearly all of it.",
	steps = {
		{ p = "Most game maths is small: add some, keep it in range, pick a random one, measure how far apart two things are. The blocks are named after what you are trying to do rather than after the function they call." },
		{ blocks = "changeBy,mathOp,clamp,randomInt,lerp,distance,roundTo" },
		{ h = "Changing a number you already have" },
		{ p = "`change {var} by {n}` is the workhorse. It writes `score += 10`, which is Luau shorthand for `score = score + 10`. A negative amount subtracts, so one block covers both directions." },
		{ h = "Keeping a number sensible" },
		{ p = "`clamp` pins a value inside a range. It is the cure for health bars that creep past 100 and for cameras that end up under the floor." },
		{ code = 'hum.Health = math.clamp(hum.Health + 25, 0, hum.MaxHealth)' },
		{ h = "Randomness" },
		{ p = "`math.random(1, 6)` really is a dice roll -- both ends can come up. For smooth values, like a wait time or a speed, use the decimal version instead. Roll once and keep the result in a variable if you need to use it twice; rolling twice gives two different numbers." },
		{ h = "Blending" },
		{ p = "`blend` is the one people skip and then wish they had not. It gives you a value part way between two others: 0 gives the first, 1 gives the second, 0.35 gives just over a third of the way. Every smooth camera, health bar and colour fade is built on it." },
		{ code = 'local shown = shown + (target - shown) * 0.15' },
		{ p = "Run that every frame and `shown` chases `target` -- fast at first, slower as it arrives. Fifteen percent of the remaining distance, every frame." },
		{ h = "Measuring" },
		{ p = "Subtracting two positions gives the arrow between them, and `.Magnitude` is its length in studs. That is how you check whether a player is near enough to open a door." },
		{ code = 'local distance = (player.Character.PrimaryPart.Position - door.Position).Magnitude\n\nif distance < 10 then\n\tprint("close enough")\nend' },
		{ note = "Studs are Roblox's unit of length. A default character is about 5 studs tall, so 10 studs is roughly two body heights." },
		{ try = "Make a part that changes colour depending on how close the player is, using distance and blend together." },
	},
	example = [[
local score = 0

score += 10
score = math.clamp(score, 0, 999)

local roll = math.random(1, 6)

if roll >= 5 then
	score += 50
end

local shown = 0
local target = 100

shown = shown + (target - shown) * 0.15

print(score, roll, math.round(shown))
]],
}

T{
	id = "cat-text", kind = "category", cat = "text", minutes = 4,
	level = "build",
	title = "Text: words and strings",
	blurb = "Labels, messages, names, and the small art of gluing them together.",
	steps = {
		{ p = "A string is a run of characters in quotes. You will build them, cut them up, and search them -- mostly to put words on a screen." },
		{ blocks = "printText,joinText,formatText,containsText,splitText,toText" },
		{ h = "Joining" },
		{ p = "`..` glues two strings together. Numbers join fine on their own; anything else needs `tostring` first, which is what the `value to text` block is for." },
		{ code = 'print("Score: " .. score)' },
		{ h = "Formatting" },
		{ p = "Once you are joining three or four things, `string.format` reads better than a chain of dots. `%d` takes a whole number, `%s` a string, and `%.1f` a decimal rounded to one place." },
		{ code = 'local line = string.format("%s has %d coins (%.1f%% of the record)", player.Name, coins, share)' },
		{ note = "`%%` is how you write a literal percent sign inside a format string. A single `%` would be read as the start of another slot." },
		{ h = "Searching" },
		{ p = "`if {text} contains \"{word}\"` writes `string.find` with `plain` switched on. That last argument matters: without it, characters like `.` `-` `(` are read as pattern syntax rather than as themselves, and searching for \"3.5\" would also match \"345\"." },
		{ h = "Cutting up" },
		{ p = "`split` turns one string into a list of pieces, which is how you read comma-separated data. `part of text` takes a slice: counting starts at 1, and -1 means 'the last character'." },
		{ code = 'local parts = string.split("red,green,blue", ",")\nprint(parts[2])\n\nlocal last = string.sub(name, -1, -1)' },
		{ warn = "Text is compared exactly. \"Hello\" and \"hello\" are different strings. Put both sides through `in lower` before comparing player input." },
		{ try = "Take a player's name and print it back with the first letter alone: `string.sub(name, 1, 1)`." },
	},
	example = [[
local player = game.Players.LocalPlayer
local coins = 42

local line = string.format("%s has %d coins", player.Name, coins)

print(line)

local tags = string.split("fast,red,rare", ",")

for _, tag in ipairs(tags) do
	if string.find(tag, "red", 1, true) then
		print("found the colour tag")
	end
end
]],
}

T{
	id = "cat-vars", kind = "category", cat = "vars", minutes = 4,
	level = "start",
	title = "Variables: naming things",
	blurb = "A variable is a name you give a value so you can talk about it later.",
	steps = {
		{ p = "`make {name} = {value}` creates a name. `set {name} to {value}` changes one that already exists. Using `make` twice on the same name does not change the first one -- it creates a second, separate name that happens to look the same, and one of them will not be the one you meant." },
		{ blocks = "local,set,svc,scriptParent,setAttr,getAttr" },
		{ h = "Where a name lives" },
		{ p = "A name made inside a block only exists inside that block. Make it inside an `if` and it is gone at the `end`. This is called scope, and it is a feature: it stops the top of your script filling up with names that only mattered for three lines." },
		{ code = 'local total = 0\n\nfor i = 1, 10 do\n\tlocal double = i * 2\n\ttotal += double\nend\n\nprint(total)' },
		{ p = "`total` outlives the loop because it was made outside it. `double` does not. Move the `make` block inside or outside a loop and you change which of those two things you get." },
		{ h = "Services" },
		{ p = "`use the {name} service` writes `local Players = game:GetService(\"Players\")`. Services are the parts of Roblox that are not objects in your place -- the player list, the frame clock, the tween engine. Put these at the very top of the canvas, in their own stack." },
		{ note = "The code panel hoists services for you: if a block needs Players and you never added the service block, one appears at the top of the generated script anyway. Adding it yourself just means you can see it." },
		{ h = "Attributes" },
		{ p = "An attribute is a value stored on an object rather than in a script. Set `Speed` on a part and every script can read it, you can edit it in the Properties window while the game runs, and it survives being cloned. For anything a designer might want to tune, an attribute beats a variable." },
		{ code = 'door:SetAttribute("Locked", true)\n\nif door:GetAttribute("Locked") then\n\tprint("no entry")\nend' },
		{ warn = "Reading an attribute that was never set gives `nil`, not `false` and not `0`. Set a starting value somewhere, or check for nil before using it." },
		{ try = "Give a part an attribute called Speed, then read it in a script and print it. Change the value in Properties while the game runs and watch the print change." },
	},
	example = [[
local Players = game:GetService("Players")

local door = script.Parent
local openTime = 3

door:SetAttribute("Locked", false)

local total = 0

for i = 1, 10 do
	local double = i * 2
	total += double
end

print(total, openTime, door:GetAttribute("Locked"))
]],
}

T{
	id = "cat-funcs", kind = "category", cat = "funcs", minutes = 6,
	level = "build",
	title = "Functions: naming steps",
	blurb = "When the same five blocks show up in three places, they want a name.",
	steps = {
		{ p = "A function is a set of blocks with a name on it. Defining one does not run it -- it puts it on the shelf. Running it is a separate block." },
		{ blocks = "def,call,callSave,return,pcall,require" },
		{ code = 'local function heal(hum, amount)\n\thum.Health = math.min(hum.Health + amount, hum.MaxHealth)\nend\n\nheal(playerHum, 25)' },
		{ h = "Inputs" },
		{ p = "The names in the `with` field are parameters: fresh variables that exist only inside the function and get their values from whoever runs it. Naming them well is most of what makes a function readable." },
		{ h = "Outputs" },
		{ p = "`give back {value}` hands a value to whoever called the function and leaves immediately. Anything after it in the same branch never runs -- which is why `give back` doubles as an early exit." },
		{ code = 'local function biggest(a, b)\n\tif a > b then\n\t\treturn a\n\tend\n\treturn b\nend' },
		{ h = "Define before you use" },
		{ p = "Luau reads a script top to bottom. A function must be defined above the first line that calls it, or that line will find nothing there. If a call mysteriously reports 'attempt to call a nil value', check the order." },
		{ warn = "That is only true for `local function`. A function stored on a table -- like a module's -- is looked up when it runs, not when the script is read, so those can be defined in any order." },
		{ h = "Risky work" },
		{ p = "`try safely` wraps blocks in `pcall`. If anything inside errors, the script carries on and you get `false` plus the message instead of a dead script. Use it for data stores, HTTP, teleports -- anything that leaves your machine and might not come back." },
		{ code = 'local ok, err = pcall(function()\n\tstore:SetAsync(key, value)\nend)\n\nif not ok then\n\twarn("save failed: " .. tostring(err))\nend' },
		{ h = "Modules" },
		{ p = "A ModuleScript is a script that returns something -- usually a table of functions. `require` loads it once and hands the same result to everyone who asks. That is how you share code between scripts without copying it." },
		{ try = "Find something you have written twice with small changes. Turn it into one function with a parameter for the part that changed." },
	},
	example = [[
local Module = {}

local function heal(hum, amount)
	hum.Health = math.min(hum.Health + amount, hum.MaxHealth)
	return hum.Health
end

function Module:reset(player)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		heal(hum, hum.MaxHealth)
	end
end

local ok, err = pcall(function()
	Module:reset(nil)
end)

if not ok then
	warn(err)
end

return Module
]],
}

T{
	id = "cat-inst", kind = "category", cat = "inst", minutes = 6,
	level = "build",
	title = "Instances: building the world",
	blurb = "Every part, model, sound and label in your place is an instance, and scripts can make more.",
	steps = {
		{ p = "The Explorer window is a tree of instances. Anything you can click there, a script can make, change, move or delete." },
		{ blocks = "create,setProp,setParent,clone,destroy,findChild,waitChild,tween" },
		{ h = "Making one" },
		{ p = "`Instance.new` builds an object in memory. It is not in the game yet -- it appears the moment you give it a parent. Set the other properties first and the parent last, so nobody sees a grey unanchored part flash into place before it is ready." },
		{ code = 'local part = Instance.new("Part")\npart.Size = Vector3.new(4, 1, 4)\npart.Position = Vector3.new(0, 10, 0)\npart.Anchored = true\npart.Color = Color3.fromRGB(255, 170, 60)\npart.Parent = workspace' },
		{ h = "Finding one" },
		{ p = "`FindFirstChild` returns the child or `nil`, so you can check. Indexing directly -- `workspace.Door` -- errors when it is missing. `WaitForChild` pauses until it turns up, which is what you want on the client where objects stream in over the network." },
		{ list = {
			"Server script, object placed in Studio: plain indexing is fine.",
			"LocalScript, anything: `WaitForChild`.",
			"Might not exist at all: `FindFirstChild` and check for nil.",
		} },
		{ h = "Copying" },
		{ p = "Keep a template in ServerStorage, clone it, set the copy's position, then parent the copy. The original stays untouched and out of the workspace, so nobody can walk into it." },
		{ code = 'local copy = template:Clone()\ncopy:PivotTo(CFrame.new(0, 5, 0))\ncopy.Parent = workspace' },
		{ note = "Use `PivotTo` for models and characters -- it moves every part together. Setting `.Position` works on a single part but tears a model apart." },
		{ h = "Smooth changes" },
		{ p = "The tween block hands a table of end values to TweenService and Roblox fills in every frame between. Anything numeric can be tweened: transparency, position, size, colour." },
		{ code = 'TweenService:Create(door, TweenInfo.new(0.6), { Transparency = 1 }):Play()' },
		{ warn = "`Destroy` is final. The object and everything inside it are gone and no variable pointing at it will work again. If you might want it back, set `Parent = nil` instead and keep hold of it." },
		{ try = "Build a tower of ten parts with a loop, each one two studs above the last, each a slightly different colour." },
	},
	example = [[
local TweenService = game:GetService("TweenService")

for i = 1, 10 do
	local part = Instance.new("Part")
	part.Size = Vector3.new(4, 1, 4)
	part.Position = Vector3.new(0, i * 2, 0)
	part.Anchored = true
	part.Color = Color3.fromRGB(255, 170, 60)
	part.Parent = workspace
end

local door = workspace:FindFirstChild("Door")

if door then
	TweenService:Create(door, TweenInfo.new(0.6), { Transparency = 1 }):Play()
end
]],
}

T{
	id = "cat-player", kind = "category", cat = "player", minutes = 5,
	level = "build",
	title = "Players: characters and humanoids",
	blurb = "A player, a character and a humanoid are three different things, and mixing them up is the usual bug.",
	steps = {
		{ p = "Three objects, three jobs:" },
		{ list = {
			"The Player -- their account. Name, UserId, leaderstats. Exists from join to leave.",
			"The Character -- the model in the workspace. Replaced on every respawn.",
			"The Humanoid -- inside the character. Health, WalkSpeed, jumping, dying.",
		} },
		{ blocks = "onPlayerAdded,charOf,humanoidOf,walkSpeed,damage,leaderstat,eachPlayer" },
		{ h = "Getting from one to the other" },
		{ code = 'local char = player.Character\nlocal hum = char:FindFirstChildOfClass("Humanoid")\nhum.WalkSpeed = 24' },
		{ p = "That code is right and it will still break, because `player.Character` is `nil` between the moment a player dies and the moment they respawn -- and it is nil for a second right after they join. This is the single most common Roblox error." },
		{ code = 'local char = player.Character\n\nif not char then return end\n\nlocal hum = char:FindFirstChildOfClass("Humanoid")\n\nif not hum then return end\n\nhum.WalkSpeed = 24' },
		{ p = "Better still, do not go looking for the character at all -- wait for it to arrive, with the `when {player} spawns as {char}` block. Then it is handed to you and cannot be nil." },
		{ h = "Leaderboards" },
		{ p = "The list on the right of the screen is not a feature you switch on. It appears when a player contains a Folder named exactly `leaderstats`, and it shows one column per value inside. The `give leaderboard stat` block builds that folder for you." },
		{ code = 'local folder = Instance.new("Folder")\nfolder.Name = "leaderstats"\nfolder.Parent = player\n\nlocal coins = Instance.new("IntValue")\ncoins.Name = "Coins"\ncoins.Value = 0\ncoins.Parent = folder' },
		{ warn = "`Players.LocalPlayer` only exists in LocalScripts. On the server there is no single player, because one server is running for everyone at once. If your script is in ServerScriptService, LocalPlayer is nil." },
		{ h = "Health" },
		{ p = "`TakeDamage` respects force fields; subtracting from `Health` directly does not. Use TakeDamage for hazards, and set Health directly only when you mean to override everything -- like healing." },
		{ try = "Give every player who joins a Coins stat, and add one coin every ten seconds while they are in the game." },
	},
	example = [[
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = folder

	player.CharacterAdded:Connect(function(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		hum.WalkSpeed = 20
		hum.Died:Connect(function()
			print(player.Name)
		end)
	end)
end)

while true do
	task.wait(10)
	for _, player in ipairs(Players:GetPlayers()) do
		local stat = player.leaderstats:FindFirstChild("Coins")
		if stat then
			stat.Value += 1
		end
	end
end
]],
}

T{
	id = "cat-data", kind = "category", cat = "data", minutes = 5,
	level = "build",
	title = "Data: lists and records",
	blurb = "One table type does both jobs. Which one you have depends only on the keys you use.",
	steps = {
		{ p = "Luau has a single container: the table. Use whole numbers as keys and it behaves like a list. Use strings and it behaves like a record. Nothing stops you doing both at once, though you rarely want to." },
		{ blocks = "newList,listOf,push,removeAt,setKey,getKey,containsValue,foripairs" },
		{ h = "Lists" },
		{ code = 'local coins = {}\n\ntable.insert(coins, "gold")\ntable.insert(coins, "silver")\n\nprint(#coins)\nprint(coins[1])' },
		{ p = "Lists count from 1, not 0. `#coins` is how many there are. `table.insert` puts one on the end; `table.remove` takes one out and closes the gap behind it." },
		{ h = "Records" },
		{ code = 'local settings = {\n\tspeed = 24,\n\tcolour = "red",\n\tlocked = false,\n}\n\nprint(settings.speed)\nprint(settings["speed"])' },
		{ p = "Those last two lines do the same thing. Dots are neater; brackets are what you need when the key is in a variable, or is not a plain word." },
		{ h = "Walking a table" },
		{ p = "`ipairs` walks a list in order, 1 upward, and stops at the first gap. `pairs` walks every key of a record, in no order you can rely on. Reach for ipairs when order matters, which for lists it usually does." },
		{ warn = "Removing items while looping forward skips things: take out item 3 and what was item 4 slides into slot 3, but the loop has already moved past. Count backwards with a negative step, or collect what to remove and do it afterwards." },
		{ code = 'for index = #coins, 1, -1 do\n\tif coins[index] == "silver" then\n\t\ttable.remove(coins, index)\n\tend\nend' },
		{ h = "Tables are shared, not copied" },
		{ p = "Passing a table to a function does not copy it. Both names point at the same table, and a change through one is visible through the other. That is efficient, and occasionally surprising. `table.clone` gives you a shallow copy when you want one." },
		{ try = "Keep a list of every part a player has touched, and refuse to score the same part twice." },
	},
	example = [[
local coins = {}

table.insert(coins, "gold")
table.insert(coins, "silver")
table.insert(coins, "bronze")

for index = #coins, 1, -1 do
	if coins[index] == "silver" then
		table.remove(coins, index)
	end
end

local settings = { speed = 24, colour = "red" }

settings["locked"] = false

for key, value in pairs(settings) do
	print(key, value)
end

if table.find(coins, "gold") then
	print("still have the gold one")
end
]],
}

--=============================================================================
-- tips and technique
--=============================================================================

T{
	id = "tip-snap", kind = "tip", minutes = 3, level = "start",
	title = "Dragging, dropping and snapping",
	blurb = "How blocks join up, and what the amber line is telling you.",
	steps = {
		{ p = "Drag a block by any part of it that is not a field. As you move, a thin amber line appears wherever the block would land if you let go. No line means no join -- the block will sit loose on the canvas as a stack of its own, which is perfectly legal." },
		{ h = "You are always dragging a run" },
		{ p = "Picking up a block picks up everything below it in the same run. That is deliberate: the blocks under it are the rest of that thought. To move one block on its own, drag it out, drop it somewhere empty, then drag the others back." },
		{ h = "Dropping into a slot" },
		{ p = "Container blocks -- if, loops, events, functions -- have an indented slot. Drop near the top of the empty space inside one and the amber line appears indented, meaning 'inside'. Drop just below the block's last line and the line appears at the outer level, meaning 'after'. The indentation of the amber line is the whole answer." },
		{ note = "A stack cannot be dropped inside itself. The editor refuses the drop rather than eating your program." },
		{ h = "Getting around" },
		{ list = {
			"Scroll to pan up and down; hold Shift to pan sideways.",
			"Ctrl and scroll to zoom. Ctrl+0 puts it back to 100%.",
			"Drag with the middle mouse button, or hold Space and drag, to pan anywhere.",
			"Ctrl+L tidies every stack into a column.",
		} },
		{ h = "Getting rid of things" },
		{ p = "Select a block and press Delete, or drag it onto the palette on the left -- the palette lights up to say it will take it. Ctrl+Z brings back anything you regret, and the history is fifty deep." },
		{ try = "Build a stack of four blocks, then drag the second one out and drop it inside an if block. Watch where the amber line goes as you move." },
	},
}

T{
	id = "tip-code-panel", kind = "tip", minutes = 3, level = "start",
	title = "Reading the code panel",
	blurb = "The panel on the right is not decoration. It is the thing you are actually making.",
	steps = {
		{ p = "Every edit rewrites the panel on the right immediately. This is the fastest way to learn to read Luau there is: change one block, watch one line change." },
		{ h = "Hover to connect the two" },
		{ p = "Hover a block on the canvas and the lines it produced light up in the panel. Hover a line in the panel and the block that wrote it is outlined on the canvas. When you cannot find which block is causing something, this is how you find it." },
		{ h = "The header and the preamble" },
		{ p = "The first two lines are a banner with your project name. Below that, any services your blocks need appear as `local Players = game:GetService(\"Players\")` -- hoisted automatically, deduplicated, and skipped entirely if you added the service block yourself." },
		{ h = "Getting the code out" },
		{ list = {
			"`Insert script` puts a real Script into the game, at the parent you choose, and registers a waypoint so Ctrl+Z in Studio undoes it.",
			"`Copy` opens the script as selectable text, ready for Ctrl+C. Studio gives plugins no clipboard of their own, so nothing here pretends otherwise.",
			"The script it inserts is ordinary Luau with no dependency on this plugin.",
		} },
		{ warn = "Editing the inserted script does not edit your blocks. The arrow only points one way -- blocks to code. If you change the script and then insert again, your edits are overwritten. Edit the blocks, or move to text for good." },
		{ h = "Reading indentation" },
		{ p = "Indentation in the panel is exactly the nesting on your canvas. If a line is further right than you expected, the block is inside something you did not mean it to be inside. That is usually the bug." },
	},
}

T{
	id = "tip-import", kind = "tip", minutes = 4, level = "build",
	title = "Turning Luau into blocks",
	blurb = "Paste a script into the Import tab and get a canvas back.",
	steps = {
		{ p = "The Import tab takes Luau -- yours, a friend's, something from a tutorial -- and rebuilds it as blocks. It handles the whole language, including types, string interpolation, `+=`, `continue`, and nested functions." },
		{ h = "What you get back" },
		{ list = {
			"Events, loops, branches and function definitions become the matching blocks.",
			"Expressions stay exactly as you wrote them, inside the fields.",
			"Comments become note blocks, in the same places.",
			"Anything else becomes a raw Luau block holding the original text.",
		} },
		{ h = "Nothing is thrown away" },
		{ p = "When a statement has no matching block, it becomes a `raw Luau` block holding the exact source text. Your program still works, still exports byte-for-byte, and you can edit the parts that did convert. A metatable or a coroutine will come through as raw; a touch event will come through as a touch block." },
		{ p = "The report under the button tells you how many statements were matched and how many landed in raw blocks, with the line numbers, so you can see at a glance how well it went." },
		{ h = "Blank lines become stacks" },
		{ p = "The importer treats a blank line at the top level as a break between stacks, so an imported script arrives as a column of separate groups rather than one enormous tower. That is usually the shape you wanted anyway." },
		{ h = "Round tripping" },
		{ p = "Import then export gives back the same code -- that is a rule the importer is built around. A pattern is only matched when the block writes exactly the same line back. `hum.WalkSpeed = 24` becomes a walk-speed block; `hum.JumpPower = 50` deliberately does not, because that block writes two lines." },
		{ note = "Comments survive. A line comment becomes a note block in the same place; a long comment stays raw." },
		{ warn = "Importing replaces the canvas. Save your project first if it has anything worth keeping." },
		{ try = "Paste in a script you already have and see how much of it comes back as real blocks." },
	},
	example = [[
local Players = game:GetService("Players")

local COOLDOWN = 1.5
local lastHit = {}

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		hum.WalkSpeed = 20
	end)
end)

script.Parent.Touched:Connect(function(hit)
	local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum:TakeDamage(10)
end)
]],
}

T{
	id = "tip-intellisense", kind = "tip", minutes = 4, level = "build",
	title = "Getting the most out of IntelliSense",
	blurb = "The completion list knows your document, not just Roblox.",
	steps = {
		{ p = "Click into any expression field and a list appears. It is not a fixed word list -- it works out what you are asking for from what you have typed and from what your blocks have already declared." },
		{ h = "Type less than you think" },
		{ p = "Matching is fuzzy and subsequence-based. `ffc` finds FindFirstChild. `gsv` finds GetService. `wsp` finds WalkSpeed. You almost never need more than three characters." },
		{ h = "Dots and colons ask different questions" },
		{ p = "After a dot you get properties, methods and events. After a colon you get only the things you can call -- properties are hidden, because `part:Anchored` is not a thing. The list is filtered by the type of what is on the left." },
		{ h = "It reads your canvas" },
		{ p = "A `make door = a new Part` block above teaches the completer that `door` is a Part, so `door.` offers Anchored, CanCollide and Transparency. A `use the TweenService service` block teaches it that TweenService has a Create method. Your own names appear at the top of the list, above the built-ins." },
		{ code = 'local door = Instance.new("Part")\ndoor.Anch', partial = true },
		{ h = "Strings get completed too" },
		{ p = "Inside the quotes of `Instance.new(\"` you get class names. Inside `game:GetService(\"` you get services. Fields that want a class, a property or a key name know what belongs there without you typing quotes at all." },
		{ h = "Signature help" },
		{ p = "Once the caret is inside a call's brackets, the line under the field shows what that function takes and highlights the argument you are on. It works for the Roblox API and for the standard libraries." },
		{ list = {
			"Up and Down move through the list.",
			"Tab or Enter accepts. Clicking works too.",
			"Escape dismisses it. Ctrl+Space brings it back.",
		} },
		{ note = "The completer knows a few conventional names as a last resort -- `hum` is probably a Humanoid, `plr` probably a Player. Declare the variable with a block and it stops guessing." },
	},
}

T{
	id = "tip-shortcuts", kind = "tip", minutes = 2, level = "start",
	title = "Keyboard shortcuts",
	blurb = "The dozen keys that make this feel like a tool rather than a toy.",
	steps = {
		{ p = "Everything here can be done with the mouse, and everything here is faster with the keyboard. These are worth learning in the order they appear -- undo first, because it makes everything else safe to try." },
		{ h = "Editing" },
		{ list = {
			"Ctrl+Z -- undo. Ctrl+Y or Ctrl+Shift+Z -- redo. Fifty steps of history.",
			"Delete or Backspace -- remove the selected block and everything under it.",
			"Ctrl+D -- duplicate the selected block, children and all.",
			"Escape -- dismiss the completion list, or clear the selection.",
		} },
		{ h = "Moving around" },
		{ list = {
			"Ctrl+F -- jump to the palette search box.",
			"Scroll -- pan. Shift+scroll -- pan sideways. Ctrl+scroll -- zoom.",
			"Ctrl+0 -- back to 100%. Ctrl+L -- tidy the stacks into a column.",
			"Middle-drag, or hold Space and drag -- pan freely.",
		} },
		{ h = "Getting work out" },
		{ list = {
			"Ctrl+S -- save the project.",
			"Ctrl+Enter -- insert the generated script into the game.",
			"Ctrl+Space -- force the completion list open in a field.",
		} },
		{ p = "The palette search box deserves a mention of its own. Ctrl+F, three letters, Enter -- the matching block lands on the canvas without your hands leaving the keyboard. Searching matches the block's wording, the Luau it writes, and its description, so `connect` finds the event blocks even though none of them say connect on the front." },
		{ note = "Shortcuts need the plugin window focused. Click once inside it after using Studio's viewport, or the keys go to Studio instead." },
	},
}

T{
	id = "tip-naming", kind = "tip", minutes = 3, level = "build",
	title = "Naming things so the code reads",
	blurb = "The generated script is only as clear as the names you typed into the fields.",
	steps = {
		{ p = "Blocks give you the structure for free. The names are still yours, and they are what somebody reads six months later -- including you." },
		{ h = "Say what it is, not what type it is" },
		{ p = "`part` tells you nothing you could not see. `door`, `checkpoint`, `killBrick` tell you why it is there. Reserve short names for short lives: `i` in a three-line loop is fine, `i` spanning forty lines is not." },
		{ h = "Booleans read as questions" },
		{ p = "Name a true-or-false value so that `if` plus the name is a sentence. `if isOpen`, `if hasKey`, `if canJump`. Then `if not isOpen` still reads properly, which `if not open` does not." },
		{ h = "Constants shout" },
		{ p = "A value fixed when the script starts and never changed is written in capitals with underscores -- `MAX_HEALTH`, `SPAWN_DELAY`. It is only a convention, but it tells a reader instantly that they will not find that name on the left of an assignment anywhere." },
		{ code = 'local MAX_HEALTH = 100\nlocal SPAWN_DELAY = 3\n\nlocal isOpen = false\nlocal checkpoint = workspace.Checkpoints.First' },
		{ h = "Match the language" },
		{ p = "Roblox properties are PascalCase -- `WalkSpeed`, `BrickColor`. Luau code conventionally uses camelCase for variables -- `walkSpeed`, `lastHit`. Following that split makes it obvious at a glance which is yours and which is Roblox's." },
		{ warn = "Do not name a variable after something built in. A variable called `print` or `workspace` will shadow the real one for the rest of that scope, and the error you get will not mention it." },
	},
}

T{
	id = "tip-loops", kind = "tip", minutes = 4, level = "build",
	title = "Loops that do not freeze the game",
	blurb = "Why your test hangs the moment you press Play, and the two-block fix.",
	steps = {
		{ p = "Luau runs your script on one thread. While a loop is going round, nothing else in that script happens -- and if the loop never pauses, Roblox never gets its turn back either." },
		{ code = 'while true do\n\tprint("hello")\nend' },
		{ p = "That runs millions of times a second, fills the output, and locks up the place. Studio will stop it after a few seconds and complain about a script timeout." },
		{ h = "The fix" },
		{ code = 'while true do\n\ttask.wait(1)\n\tprint("hello")\nend' },
		{ p = "`task.wait` pauses this thread and lets everything else run. One wait inside every `while` is the rule. Put it at the top rather than the bottom and the loop cannot race away even if a later block errors." },
		{ h = "Prefer an event to a loop" },
		{ p = "Loops that poll -- 'check every frame whether the player is near' -- are usually an event in disguise. Touched, ProximityPrompt.Triggered and GetPropertyChangedSignal all cost nothing while nothing is happening, whereas a loop costs the same whether anything happens or not." },
		{ h = "The frame loop is different" },
		{ p = "`every frame` is not a `while` loop -- it is an event that Roblox fires once per frame, and it never needs a wait. But whatever you put inside runs sixty times a second, so keep it small: move something, read something, and get out." },
		{ warn = "`task.wait(0)` does not mean 'no wait'. It means 'let everything else have a turn, then carry on next frame'. That is often exactly what you want, but it is not free." },
		{ try = "Take a while loop you have written and see whether an event could do the same job with no loop at all." },
	},
	example = [[
local RunService = game:GetService("RunService")

while true do
	task.wait(1)
	print("tick")
end

RunService.Heartbeat:Connect(function(dt)
	part.Position = part.Position + Vector3.new(0, dt, 0)
end)
]],
}

T{
	id = "tip-debug", kind = "tip", minutes = 4, level = "build",
	title = "When nothing happens",
	blurb = "A short list, in order, for the moment your blocks look right and do nothing.",
	steps = {
		{ p = "Nothing happening is more common than a crash, and it is worth having a routine rather than a stare." },
		{ h = "1. Open the Output window" },
		{ p = "View, then Output, in Studio. Almost every silent failure has already written you a message there. If the window is empty, your script may not be running at all -- which is its own answer." },
		{ h = "2. Print at the top" },
		{ p = "Put a `print` as the very first block. If it does not appear, the script never ran: wrong parent, wrong script kind, or disabled. If it does appear, the problem is further in." },
		{ h = "3. Print inside the event" },
		{ p = "Put a print as the first block inside the event. If the top one prints and this one does not, the event is not firing. Check the object it is connected to actually exists, and that you are on the right side -- a server script cannot hear a key press." },
		{ h = "4. Print the value you are testing" },
		{ code = 'print("hum is", hum)\nprint("health is", hum and hum.Health)' },
		{ p = "`print` takes as many values as you like and puts tabs between them. Printing the value next to a label tells you far more than printing the value alone. Nine times in ten the answer is that something is `nil`." },
		{ h = "5. Check where the script lives" },
		{ p = "A Script in ReplicatedStorage does not run. A LocalScript in ServerScriptService does not run. A Script inside a Tool runs only once the tool is in a character. Placement is behaviour." },
		{ note = "`warn` prints in orange, which makes your own messages easy to pick out of a busy output window. Use warn for the ones you are actively hunting." },
	},
}

T{
	id = "tip-where", kind = "tip", minutes = 4, level = "deep",
	title = "Server or client: where does this script go?",
	blurb = "Half of all Roblox bugs are a script in the wrong place.",
	steps = {
		{ p = "A Roblox game runs in two places at once. One server holds the truth about the world; every player's device runs its own copy for drawing and input. Code runs on one side or the other, never both, and they see different things." },
		{ h = "The short version" },
		{ list = {
			"Server (a Script in ServerScriptService): scores, damage, spawning, saving, anything cheatable.",
			"Client (a LocalScript in StarterPlayerScripts or StarterGui): key presses, the camera, interface, sounds only that player should hear.",
		} },
		{ h = "What only exists on one side" },
		{ p = "`Players.LocalPlayer` is a client thing -- on the server it is nil, because the server is not any one player. `UserInputService` and `RenderStepped` are client-only for the same reason: a server has no keyboard and draws no frames. Meanwhile DataStores and `player:Kick()` only work on the server." },
		{ warn = "A part created on the client exists only for that player. Nobody else sees it, and the server does not know about it. That is occasionally what you want, and usually the bug." },
		{ h = "Talking across the gap" },
		{ p = "The two sides talk through RemoteEvents and RemoteFunctions -- objects you put in ReplicatedStorage. The client fires, the server listens, or the other way round. Use a raw Luau block for these until you are comfortable; the pattern is short." },
		{ code = 'local remote = game.ReplicatedStorage.BuyItem\n\nremote.OnServerEvent:Connect(function(player, itemName)\n\tprint(player.Name, itemName)\nend)' },
		{ p = "Note the first argument: on the server, `OnServerEvent` always hands you the player who sent it, and Roblox fills that in -- the client cannot lie about who they are." },
		{ warn = "Never trust anything else the client sends. A client saying 'give me 500 coins' must be checked on the server, because a determined player can send whatever they like." },
		{ note = "In Studio, use Test then Start with two players to see both sides at once. The Client/Server dropdown in the toolbar switches which one your Output is showing." },
	},
}

T{
	id = "tip-perf", kind = "tip", minutes = 4, level = "deep",
	title = "Keeping every-frame code cheap",
	blurb = "Sixty times a second multiplies any mistake by sixty.",
	steps = {
		{ p = "Code in a frame event gets a budget of a few milliseconds. Everything you do in there is done again before the next frame is drawn, so small waste turns into stutter." },
		{ h = "Look things up once" },
		{ code = 'local hum = char:FindFirstChildOfClass("Humanoid")\n\nRunService.Heartbeat:Connect(function(dt)\n\thum.WalkSpeed = 16 + math.sin(os.clock()) * 4\nend)' },
		{ p = "Find the humanoid once, outside. A `FindFirstChild` inside a frame event searches the children of that object every single frame, for a result that has not changed." },
		{ h = "Multiply by delta time" },
		{ p = "The frame event hands you the seconds since the last frame. Multiply movement by it and your game runs at the same speed on a slow laptop and a fast desktop. Without it, everything is tied to frame rate." },
		{ code = 'part.Position = part.Position + Vector3.new(0, 5 * dt, 0)' },
		{ h = "Use a tween instead" },
		{ p = "Moving something from A to B over two seconds does not need a frame loop at all. TweenService does it in the engine, in C, without waking your script up at all. Reach for a frame event only when the value genuinely depends on something changing every frame." },
		{ h = "Disconnect what you are done with" },
		{ p = "A connection you never disconnect stays alive, holding on to everything it mentions. Connect something for each of a hundred parts and forget them and you have a hundred handlers running forever. Keep the connection in a variable and use `stop listening` when the work is over." },
		{ code = 'local connection\n\nconnection = RunService.Heartbeat:Connect(function(dt)\n\tif done then\n\t\tconnection:Disconnect()\n\tend\nend)' },
		{ note = "Studio's MicroProfiler (Ctrl+F6 while playing) shows which scripts are eating the frame. It is worth a look before optimising anything by guesswork." },
	},
}

T{
	id = "tip-raw", kind = "tip", minutes = 3, level = "deep",
	title = "The escape hatch",
	blurb = "One block that takes any Luau at all, for when the palette runs out.",
	steps = {
		{ p = "There are 127 blocks. There are considerably more than 127 things you might want to write. The `raw Luau` block takes whatever you type and puts it in the output untouched, at the right indentation." },
		{ blocks = "raw,comment" },
		{ h = "What it is for" },
		{ list = {
			"RemoteEvents and RemoteFunctions.",
			"DataStores, HTTP requests, anything asynchronous and fiddly.",
			"Metatables, coroutines, and other things that do not want to be a block.",
			"A line you already know how to write and do not want to assemble.",
		} },
		{ h = "It is a real editor" },
		{ p = "The raw block is multi-line and gets the same IntelliSense as every other expression field. Nesting still works: put a raw block inside a loop and it is indented by the loop, as you would expect." },
		{ h = "It is where imports land" },
		{ p = "Anything the importer does not recognise arrives as a raw block holding the exact original text. This is why importing a script never loses anything: the worst case is that your program is a stack of raw blocks that still runs perfectly." },
		{ warn = "The generated script is only checked by Luau when you insert it. A typo in a raw block will not stop the code panel from showing it -- but it will stop the script from running." },
		{ note = "Use the note block for comments. It writes `-- your text` and costs nothing at runtime. A canvas with a note above each stack is far easier to come back to." },
	},
}

T{
	id = "tip-organise", kind = "tip", minutes = 3, level = "build",
	title = "Organising a canvas you can still read",
	blurb = "Twenty blocks in one tower is a wall. The same twenty in five stacks is a program.",
	steps = {
		{ p = "A stack is a group. Use them: one stack for services, one per event, one per function. Ctrl+L tidies them into a single column in the order they will run." },
		{ h = "Top to bottom is the running order" },
		{ p = "Stacks are read top to bottom, then left to right, and that is the order they appear in the generated script. Moving a stack up the canvas genuinely moves it earlier in the script -- which matters, because a function must be defined above the first place it is used." },
		{ list = {
			"One stack for services, at the top left.",
			"One stack per event -- that is usually the natural unit of a Roblox script.",
			"One stack per function definition, above the first thing that calls it.",
			"Loose experiments off to the right, where they are obviously not part of the program.",
		} },
		{ h = "Label everything" },
		{ p = "Put a note block at the top of each stack saying what it does. It becomes a comment in the output, so the tidiness follows the code out of the plugin." },
		{ h = "Pull repeated work into a function" },
		{ p = "Three copies of the same four blocks is a function waiting to be named. Define it in its own stack near the top and call it from wherever. The canvas gets smaller and the intent gets clearer." },
		{ h = "Split the script itself" },
		{ p = "When a project grows past a screen or two, it probably wants to be two scripts rather than one. Save the project, start a new one, and let each handle one job -- one for the shop, one for the round timer. Small scripts are easier to fix." },
		{ note = "Zooming out with Ctrl+scroll is a good way to see the shape of a program. If it looks lopsided -- one enormous stack and four tiny ones -- it usually is." },
	},
}

T{
	id = "tip-save", kind = "tip", minutes = 3, level = "start",
	title = "Saving, sharing and keeping versions",
	blurb = "Where your blocks live, and how to get them onto someone else's machine.",
	steps = {
		{ p = "Your project is saved with the plugin, in Studio's plugin settings -- not inside the place file. It survives closing Studio and opening a different place." },
		{ h = "Saving" },
		{ p = "Ctrl+S, or the Save button. The canvas also saves itself when you close the window and when you switch tabs, so a crash costs you very little. The status bar shows when the last save happened." },
		{ h = "Several projects" },
		{ p = "The project menu at the top left lists everything you have saved, and lets you start a new one or copy the current one. Names are yours to choose; give them the name of the thing they build rather than 'test2'." },
		{ list = {
			"Ctrl+S saves. The status bar shows the time of the last save.",
			"Switching tabs or closing the window saves too.",
			"The project menu holds as many projects as you like.",
			"Export and import move a whole project as JSON text.",
		} },
		{ h = "Sharing" },
		{ p = "`Export as text` on the Setup tab shows the whole document as JSON, selected and ready to copy. Anyone with this plugin can paste it into `Import project` and get an identical canvas -- positions, fields, everything." },
		{ note = "The JSON is plain text, so it goes in a Discord message, a gist, or a version-controlled file just as well." },
		{ h = "Versions" },
		{ p = "Before a big change, copy the project and give the copy a new name. It costs one click and it is the cheapest insurance there is. Undo is fifty steps deep, but it does not survive closing the window." },
		{ warn = "Inserting the generated script into your place is what actually makes the game work. Saving the project saves the blocks, not the script." },
	},
}

T{
	id = "tip-errors", kind = "tip", minutes = 4, level = "build",
	title = "Error messages, translated",
	blurb = "The five you will actually meet, and what each one is really telling you.",
	steps = {
		{ h = "attempt to index nil with 'Something'" },
		{ p = "You asked for a property of something that does not exist. Read the name in quotes: whatever is on the left of it is nil. Usually a child that has not loaded, or a character that is between respawns. Check for nil first, or use `WaitForChild`." },
		{ code = 'local hum = char:FindFirstChildOfClass("Humanoid")\n\nif not hum then return end\n\nhum.WalkSpeed = 24' },
		{ h = "attempt to call a nil value" },
		{ p = "You ran something that is not a function. Either the name is misspelled, or the function is defined below the line that calls it, or you meant a dot and typed a colon. Colons are for methods -- `part:Destroy()` -- and dots for everything else." },
		{ h = "attempt to perform arithmetic on a string value" },
		{ p = "Something you thought was a number is text. Values from TextBoxes and attributes are a common source. `tonumber` converts, and gives nil when it cannot -- so check the result before using it." },
		{ h = "Script timeout: exhausted allowed execution time" },
		{ p = "A loop with no wait in it. See the loops lesson; the fix is one block." },
		{ h = "Unable to cast value to Object" },
		{ p = "You gave a property the wrong kind of value -- a number where a Vector3 was wanted, or a string where an Instance was. Look at the property in the Properties window to see what type it expects." },
		{ note = "Every error in the Output window is clickable. It takes you to the line in the script -- and with the code panel open you can find the block that wrote that line by hovering it." },
		{ h = "Warnings are worth reading" },
		{ p = "Orange lines are not errors, but they are Roblox telling you that something is deprecated or about to bite. `wait()` and `spawn()` are the usual culprits; `task.wait` and `task.spawn` are the modern replacements, and the blocks use those already." },
	},
}

T{
	id = "tip-tags", kind = "tip", minutes = 4, level = "deep",
	title = "Tags and attributes: one script for many objects",
	blurb = "Stop putting a copy of the same script inside forty coins.",
	steps = {
		{ p = "The beginner pattern is a script inside every coin. It works, and it means forty copies of the same code, forty chances to fix a bug in thirty-nine places. Tags fix this." },
		{ h = "Tagging" },
		{ p = "A tag is a label on an object. Add it in code, or with Studio's Tag Editor (View, then Tag Editor), select forty coins and tag them all at once. Then one script handles every object that carries the tag." },
		{ code = 'local CollectionService = game:GetService("CollectionService")\n\nfor _, coin in ipairs(CollectionService:GetTagged("Coin")) do\n\tsetUpCoin(coin)\nend\n\nCollectionService:GetInstanceAddedSignal("Coin"):Connect(setUpCoin)' },
		{ p = "The loop handles the coins already in the place; the signal handles every coin added later, including ones your own code clones. Between them they cover the whole lifetime of the game." },
		{ h = "Attributes carry the differences" },
		{ p = "Tags say what kind of thing it is. Attributes say what is different about this one. A `Coin` tag plus a `Value` attribute of 5 or 25 gives you one script and as many kinds of coin as you like -- and the values are editable in Properties without touching code." },
		{ code = 'local value = coin:GetAttribute("Value") or 1' },
		{ p = "That `or 1` is worth copying: attributes that were never set come back nil, and `or` supplies a default in one short line." },
		{ note = "Together, tags and attributes are how larger Roblox projects avoid script sprawl. It is worth learning early -- the habit scales, and copying scripts does not." },
		{ try = "Tag three parts as Hazard, give each a Damage attribute, and write one script that hurts anyone who touches any of them." },
	},
	example = [[
local CollectionService = game:GetService("CollectionService")

local function setUpHazard(part)
	local damage = part:GetAttribute("Damage") or 10
	part.Touched:Connect(function(hit)
		local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		hum:TakeDamage(damage)
	end)
end

for _, part in ipairs(CollectionService:GetTagged("Hazard")) do
	setUpHazard(part)
end

CollectionService:GetInstanceAddedSignal("Hazard"):Connect(setUpHazard)
]],
}

T{
	id = "tip-graduate", kind = "tip", minutes = 4, level = "deep",
	title = "Growing out of blocks",
	blurb = "The point of this plugin is to become unnecessary. Here is how to tell when.",
	steps = {
		{ p = "Blocks are good at structure and bad at density. When you find yourself fighting the canvas rather than the problem, that is the signal -- and the way out is already in your hands." },
		{ h = "The signs" },
		{ list = {
			"You reach for raw Luau blocks more often than real ones.",
			"You know what to type and the dragging is just slower.",
			"You want two files that talk to each other.",
			"You want to search and replace across a program.",
		} },
		{ h = "The move" },
		{ p = "Press Insert script. That is a real Script, ordinary Luau, with no dependency on this plugin. Open it and keep going in text. Nothing is lost and nothing has to be rewritten." },
		{ h = "What carries over" },
		{ p = "Everything you learned here is Luau, not block-speak. `if`, `for`, `local`, events, functions, tables -- the blocks were labels on the real thing the whole time. The code panel has been showing you the destination since the first block you dragged." },
		{ h = "What to learn next" },
		{ list = {
			"ModuleScripts, properly -- how to split a project across files.",
			"RemoteEvents -- the client and server talking safely.",
			"Types -- `local x: number` and what Studio does with it.",
			"The Roblox Creator Documentation, which is genuinely good and searchable.",
		} },
		{ note = "You can come back. Import takes text Luau and gives you blocks again, so if a bit of a project is easier to think about visually, paste it in, rearrange, and take the code back out." },
	},
}

--=============================================================================
-- lookups
--=============================================================================

j.byId = {}
for index, entry in ipairs(j.tutorials) do
	entry.index = index
	j.byId[entry.id] = entry
end

function j.count()
	return #j.tutorials
end

function j.categories()
	local list = {}
	for _, entry in ipairs(j.tutorials) do
		if entry.kind == "category" then list[#list + 1] = entry end
	end
	return list
end

function j.tips()
	local list = {}
	for _, entry in ipairs(j.tutorials) do
		if entry.kind == "tip" then list[#list + 1] = entry end
	end
	return list
end

function j.forCategory(catId)
	for _, entry in ipairs(j.tutorials) do
		if entry.cat == catId then return entry end
	end
	return nil
end

-- Plain-text haystack for the search box, built once.
local haystacks = {}
for _, entry in ipairs(j.tutorials) do
	local parts = { entry.title, entry.blurb, entry.level, entry.kind }
	for _, step in ipairs(entry.steps) do
		parts[#parts + 1] = step.p or step.h or step.note or step.warn
			or step.try or step.blocks or ""
		for _, line in ipairs(step.list or {}) do parts[#parts + 1] = line end
	end
	haystacks[entry.id] = string.lower(table.concat(parts, " "))
end

function j.search(query)
	query = string.lower(string.match(query or "", "^%s*(.-)%s*$"))
	if query == "" then return j.tutorials end
	local hits = {}
	for _, entry in ipairs(j.tutorials) do
		local haystack = haystacks[entry.id]
		local score = nil
		if string.find(string.lower(entry.title), query, 1, true) then
			score = 3
		elseif string.find(string.lower(entry.blurb), query, 1, true) then
			score = 2
		elseif string.find(haystack, query, 1, true) then
			score = 1
		end
		if score then hits[#hits + 1] = { entry = entry, score = score } end
	end
	table.sort(hits, function(x, y)
		if x.score ~= y.score then return x.score > y.score end
		return x.entry.index < y.entry.index
	end)
	local out = {}
	for _, hit in ipairs(hits) do out[#out + 1] = hit.entry end
	return out
end

-- Rough reading time, so the listed minutes stay honest as text is edited.
function j.words(entry)
	local total = 0
	for _, step in ipairs(entry.steps) do
		for _, key in ipairs({ "p", "h", "note", "warn", "try" }) do
			for _ in string.gmatch(step[key] or "", "%S+") do total = total + 1 end
		end
		for _, line in ipairs(step.list or {}) do
			for _ in string.gmatch(line, "%S+") do total = total + 1 end
		end
	end
	return total
end

return j
