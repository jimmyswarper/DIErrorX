--!nonstrict
-- t  ·  block definitions: saving, networking, shop, places
--
-- Everything here happens on one side of the client/server line and not the
-- other, so most of these blocks carry a `side`.

return function(D)

--=============================================================================
-- SAVING
--=============================================================================

D{ id = "saveStore", cat = "save", group = "Opening a store", label = "open a save file",
	head = 'make {name} = the save file called "{store}"',
	code = 'local {name} = DataStoreService:GetDataStore("{store}")',
	fields = { name = "name|store|name", store = "str|PlayerData|file name" },
	needs = { "DataStoreService" }, side = "server",
	doc = "A data store is a filing cabinet that survives the server closing. " ..
		"Open it once at the top of your script, not every time you save.",
	tags = "datastore getdatastore save open store" }

D{ id = "saveOrderedStore", cat = "save", group = "Opening a store", label = "open a leaderboard file",
	head = 'make {name} = the leaderboard file called "{store}"',
	code = 'local {name} = DataStoreService:GetOrderedDataStore("{store}")',
	fields = { name = "name|board|name", store = "str|HighScores|file name" },
	needs = { "DataStoreService" }, side = "server",
	doc = "An ordered store only holds numbers, but it can hand back the top " ..
		"ten in order, which a normal store cannot.",
	tags = "ordereddatastore leaderboard high scores ranking" }

D{ id = "saveKeyFor", cat = "save", group = "Opening a store", label = "the key for a player",
	head = "make {name} = the save key for {player}",
	code = 'local {name} = "player_" .. {player}.UserId',
	fields = { name = "name|key|name", player = "expr|player|player" },
	doc = "Keys have to be text and have to be unique. A UserId never changes " ..
		"and is never reused, which a username cannot promise.",
	tags = "key userid player unique save" }

D{ id = "saveEnabled", cat = "save", group = "Opening a store", label = "if saving is available",
	head = "if saving is switched on then",
	code = "if not game:GetService(\"RunService\"):IsStudio() then", tail = "end",
	slots = { { key = "body" } },
	side = "server",
	doc = "Data stores do not work in Studio unless you switch on API access " ..
		"in Game Settings. This lets a script skip saving while you test.",
	tags = "studio api access enabled check save" }

-- reading ------------------------------------------------------------------------
D{ id = "saveLoad", cat = "save", group = "Reading", label = "load a value",
	head = "make {name} = what {store} saved for {key}",
	code = {
		"local {name} = nil",
		"do",
		"\tlocal ok, saved = pcall(function()",
		"\t\treturn {store}:GetAsync({key})",
		"\tend)",
		"\tif ok then",
		"\t\t{name} = saved",
		"\telse",
		'\t\twarn("could not load: " .. tostring(saved))',
		"\tend",
		"end",
	},
	fields = { name = "name|saved|name", store = "expr|store|store", key = "expr|key|key" },
	side = "server",
	doc = "Loading talks to Roblox's servers and can fail, so it is wrapped " ..
		"in a pcall. A player who has never played gets nil, not an error.",
	tags = "getasync load read pcall datastore" }

D{ id = "saveLoadOr", cat = "save", group = "Reading", label = "load with a fallback",
	head = "make {name} = what {store} saved for {key}, or {fallback}",
	code = {
		"local {name} = {fallback}",
		"do",
		"\tlocal ok, saved = pcall(function()",
		"\t\treturn {store}:GetAsync({key})",
		"\tend)",
		"\tif ok and saved ~= nil then",
		"\t\t{name} = saved",
		"\tend",
		"end",
	},
	fields = { name = "name|coins|name", store = "expr|store|store", key = "expr|key|key",
		fallback = "expr|0|starting value" },
	side = "server",
	doc = "The usual shape: new players start at the fallback, and a failed " ..
		"load leaves them there rather than at nil.",
	tags = "getasync default fallback new player load" }

D{ id = "saveFillDefaults", cat = "save", group = "Reading", label = "fill in missing settings",
	head = "give {data} anything missing from {defaults}",
	code = {
		"for key, value in pairs({defaults}) do",
		"\tif {data}[key] == nil then",
		"\t\t{data}[key] = value",
		"\tend",
		"end",
	},
	fields = { data = "expr|saved|loaded data", defaults = "expr|DEFAULTS|defaults" },
	doc = "When you add a new setting, old saves will not have it. This fills " ..
		"the gaps without touching what players already had.",
	tags = "defaults migration missing merge save" }

D{ id = "saveBudget", cat = "save", group = "Reading", label = "how many requests are left",
	head = "make {name} = how many saves are left this minute",
	code = "local {name} = DataStoreService:GetRequestBudgetForRequestType(" ..
		"Enum.DataStoreRequestType.SetIncrementAsync)",
	fields = { name = "name|budget|name" },
	needs = { "DataStoreService" }, side = "server",
	doc = "Roblox limits how often you may save. Checking the budget before " ..
		"a burst of saves avoids being throttled.",
	tags = "budget throttle limit requests datastore" }

-- writing ---------------------------------------------------------------------------
D{ id = "saveSet", cat = "save", group = "Writing", label = "save a value",
	head = "save {value} in {store} under {key}",
	code = {
		"do",
		"\tlocal ok, err = pcall(function()",
		"\t\t{store}:SetAsync({key}, {value})",
		"\tend)",
		"\tif not ok then",
		'\t\twarn("could not save: " .. tostring(err))',
		"\tend",
		"end",
	},
	fields = { store = "expr|store|store", key = "expr|key|key", value = "expr|coins|value" },
	side = "server",
	doc = "Overwrites whatever was there. Saving can fail, so it is wrapped " ..
		"and complains rather than killing the script.",
	tags = "setasync save write pcall datastore" }

D{ id = "saveChange", cat = "save", group = "Writing", label = "change a saved number",
	head = "change what {store} saved for {key} by {amount}",
	code = {
		"{store}:UpdateAsync({key}, function(old)",
		"\treturn (old or 0) + {amount}",
		"end)",
	},
	fields = { store = "expr|store|store", key = "expr|key|key", amount = "expr|1|amount" },
	side = "server",
	doc = "UpdateAsync reads and writes as one step, so two servers changing " ..
		"the same value cannot lose each other's work. Safer than load-then-save.",
	tags = "updateasync increment safe concurrent save" }

D{ id = "saveWipe", cat = "save", group = "Writing", label = "delete a save",
	head = "delete what {store} saved for {key}",
	code = {
		"pcall(function()",
		"\t{store}:RemoveAsync({key})",
		"end)",
	},
	fields = { store = "expr|store|store", key = "expr|key|key" },
	side = "server",
	doc = "Wipes one player's save completely. Worth having behind a reset " ..
		"button, and worth confirming first.",
	tags = "removeasync delete wipe reset save" }

D{ id = "saveRetry", cat = "save", group = "Writing", label = "save, retrying",
	head = "try up to {tries} times to save {value} in {store} under {key}",
	code = {
		"for attempt = 1, {tries} do",
		"\tlocal ok = pcall(function()",
		"\t\t{store}:SetAsync({key}, {value})",
		"\tend)",
		"\tif ok then",
		"\t\tbreak",
		"\tend",
		"\ttask.wait(attempt)",
		"end",
	},
	fields = { store = "expr|store|store", key = "expr|key|key", value = "expr|data|value",
		tries = "num|3|tries" },
	side = "server",
	doc = "Waits a little longer after each failure. A brief outage then " ..
		"costs nobody their progress.",
	tags = "retry backoff save reliability pcall" }

-- the usual shapes ---------------------------------------------------------------------
D{ id = "saveTable", cat = "save", group = "Patterns", label = "table of everyone's data",
	head = "make {name} = a table holding everyone's data",
	code = "local {name} = {}",
	fields = { name = "name|sessions|name" },
	side = "server",
	doc = "Keep each player's loaded data in memory and only touch the data " ..
		"store when they join and leave. Saving on every coin is far too often.",
	tags = "session cache memory table save" }

D{ id = "saveOnJoin", cat = "save", group = "Patterns", label = "load when a player joins",
	head = "when {player} joins, load their data from {store} into {into}",
	code = {
		"Players.PlayerAdded:Connect(function({player})",
		'\tlocal key = "player_" .. {player}.UserId',
		"\tlocal ok, saved = pcall(function()",
		"\t\treturn {store}:GetAsync(key)",
		"\tend)",
		"\t{into}[{player}] = ok and saved or {}",
		"end)",
	},
	fields = { player = "name|player|player", store = "expr|store|store",
		into = "expr|sessions|table to fill" },
	needs = { "Players" }, side = "server",
	doc = "The join half of the pattern. Everything afterwards reads from " ..
		"memory rather than from the data store.",
	tags = "playeradded load join session save" }

D{ id = "saveOnLeave", cat = "save", group = "Patterns", label = "save when a player leaves",
	head = "when {player} leaves, save {from} into {store}",
	code = {
		"Players.PlayerRemoving:Connect(function({player})",
		'\tlocal key = "player_" .. {player}.UserId',
		"\tpcall(function()",
		"\t\t{store}:SetAsync(key, {from}[{player}])",
		"\tend)",
		"\t{from}[{player}] = nil",
		"end)",
	},
	fields = { player = "name|player|player", store = "expr|store|store",
		from = "expr|sessions|table to save from" },
	needs = { "Players" }, side = "server",
	doc = "The leave half. Clearing the entry afterwards stops the table " ..
		"growing forever on a busy server.",
	tags = "playerremoving save leave session cleanup" }

D{ id = "saveOnClose", cat = "save", group = "Patterns", label = "save before shutdown",
	head = "before the server closes, save {from} into {store}",
	code = {
		"game:BindToClose(function()",
		"\tfor player, data in pairs({from}) do",
		"\t\tpcall(function()",
		'\t\t\t{store}:SetAsync("player_" .. player.UserId, data)',
		"\t\tend)",
		"\tend",
		"end)",
	},
	fields = { store = "expr|store|store", from = "expr|sessions|table to save from" },
	side = "server",
	doc = "When Roblox shuts a server down it gives you a few seconds. " ..
		"Without this, everyone still playing loses whatever they did last.",
	tags = "bindtoclose shutdown save server close" }

D{ id = "saveAutosave", cat = "save", group = "Patterns", label = "autosave loop",
	head = "save {from} into {store} every {seconds} seconds",
	code = {
		"task.spawn(function()",
		"\twhile true do",
		"\t\ttask.wait({seconds})",
		"\t\tfor player, data in pairs({from}) do",
		"\t\t\tpcall(function()",
		'\t\t\t\t{store}:SetAsync("player_" .. player.UserId, data)',
		"\t\t\tend)",
		"\t\tend",
		"\tend",
		"end)",
	},
	fields = { store = "expr|store|store", from = "expr|sessions|table to save from",
		seconds = "num|120|seconds" },
	side = "server",
	doc = "Insurance against a crash. Every two minutes is plenty; every ten " ..
		"seconds will hit Roblox's limits.",
	tags = "autosave loop periodic backup save" }

-- leaderboards -----------------------------------------------------------------------
D{ id = "saveScore", cat = "save", group = "Leaderboards", label = "record a score",
	head = "record {score} for {key} on the leaderboard {board}",
	code = {
		"pcall(function()",
		"\t{board}:SetAsync({key}, {score})",
		"end)",
	},
	fields = { board = "expr|board|leaderboard", key = "expr|key|key", score = "expr|score|score" },
	side = "server",
	doc = "Ordered stores only take whole numbers, so round anything with a " ..
		"decimal before recording it.",
	tags = "ordered leaderboard score record save" }

D{ id = "saveTopScores", cat = "save", group = "Leaderboards", label = "read the top scores",
	head = "for each place {rank} and entry {entry} in the top {count} of {board}",
	code = {
		"do",
		"\tlocal pages = {board}:GetSortedAsync(false, {count})",
		"\tfor {rank}, {entry} in ipairs(pages:GetCurrentPage()) do",
	},
	codeTail = { "\tend", "end" }, tail = "end",
	bodyIndent = 2,
	fields = { board = "expr|board|leaderboard", rank = "name|rank|place",
		entry = "name|entry", count = "num|10|how many" },
	slots = { { key = "body" } },
	side = "server",
	doc = "Each entry has a `key` and a `value`. `false` means highest first; " ..
		"pass true for a lowest-first board like fastest times.",
	tags = "getsortedasync top ten leaderboard ranking" }

--=============================================================================
-- NETWORKING
--=============================================================================

D{ id = "netMakeEvent", cat = "net", group = "Setting up", label = "make a message channel",
	head = 'make {name} = a message channel called "{label}"',
	code = {
		'local {name} = Instance.new("RemoteEvent")',
		'{name}.Name = "{label}"',
		"{name}.Parent = ReplicatedStorage",
	},
	fields = { name = "name|remote|name", label = "str|CoinCollected|channel name" },
	needs = { "ReplicatedStorage" }, side = "server",
	doc = "A RemoteEvent is a pipe between the server and the clients. Make " ..
		"it on the server, in ReplicatedStorage so both sides can see it.",
	tags = "remoteevent remote channel network make" }

D{ id = "netGetEvent", cat = "net", group = "Setting up", label = "find a message channel",
	head = 'make {name} = the message channel "{label}"',
	code = 'local {name} = ReplicatedStorage:WaitForChild("{label}")',
	fields = { name = "name|remote|name", label = "str|CoinCollected|channel name" },
	needs = { "ReplicatedStorage" },
	doc = "Waiting matters on the client, where the remote may not have " ..
		"arrived over the network yet.",
	tags = "waitforchild remote find channel" }

D{ id = "netMakeFunction", cat = "net", group = "Setting up", label = "make a question channel",
	head = 'make {name} = a question channel called "{label}"',
	code = {
		'local {name} = Instance.new("RemoteFunction")',
		'{name}.Name = "{label}"',
		"{name}.Parent = ReplicatedStorage",
	},
	fields = { name = "name|question|name", label = "str|GetShopStock|channel name" },
	needs = { "ReplicatedStorage" }, side = "server",
	doc = "A RemoteFunction is a remote that answers back. The asking side " ..
		"waits for the reply, so keep the work behind it short.",
	tags = "remotefunction question ask reply network" }

-- server side ---------------------------------------------------------------------------
D{ id = "netOnClientMessage", cat = "net", group = "On the server", label = "on a message from a client",
	head = "when a client sends on {remote}, with {player} and {args}",
	code = "{remote}.OnServerEvent:Connect(function({player}, {args})", tail = "end)",
	fields = { remote = "expr|remote|channel", player = "name|player|player",
		args = "params|amount|what they sent" },
	slots = { { key = "body" } },
	side = "server",
	doc = "Roblox fills in who sent it, and a client cannot lie about that. " ..
		"Everything after the player is theirs, and must be checked.",
	tags = "onserverevent receive message client network" }

D{ id = "netCheckSender", cat = "net", group = "On the server", label = "check what a client sent",
	head = "ignore this message unless {value} is a {kind}",
	code = 'if typeof({value}) ~= "{kind}" then return end',
	fields = { value = "expr|amount|value",
		kind = "choice|number|kind|number,string,boolean,Instance,Vector3,table" },
	side = "server",
	doc = "A client can send anything at all, including nothing. One line of " ..
		"checking stops most of the trouble that follows.",
	tags = "validate typeof security exploit check" }

D{ id = "netRateLimit", cat = "net", group = "On the server", label = "limit how often",
	head = "ignore {player} if they sent something within {seconds} seconds, tracked in {times}",
	code = {
		"do",
		"\tlocal now = os.clock()",
		"\tif {times}[{player}] and now - {times}[{player}] < {seconds} then",
		"\t\treturn",
		"\tend",
		"\t{times}[{player}] = now",
		"end",
	},
	fields = { player = "expr|player|player", times = "expr|lastSent|times table",
		seconds = "num|0.5|seconds" },
	side = "server",
	doc = "Stops a client firing a remote hundreds of times a second. Keep " ..
		"the times table next to the handler.",
	tags = "ratelimit cooldown spam exploit security" }

D{ id = "netToOne", cat = "net", group = "On the server", label = "send to one player",
	head = "send {args} to {player} on {remote}",
	code = "{remote}:FireClient({player}, {args})",
	fields = { remote = "expr|remote|channel", player = "expr|player|player",
		args = "expr|amount|what to send" },
	side = "server",
	doc = "Only that player's client hears it. Right for anything personal, " ..
		"like their own inventory.",
	tags = "fireclient send one player network" }

D{ id = "netToAll", cat = "net", group = "On the server", label = "send to everyone",
	head = "send {args} to everyone on {remote}",
	code = "{remote}:FireAllClients({args})",
	fields = { remote = "expr|remote|channel", args = "expr|message|what to send" },
	side = "server",
	doc = "Every client hears it. Right for announcements and world events, " ..
		"wasteful for anything one player cares about.",
	tags = "fireallclients broadcast everyone network" }

D{ id = "netToOthers", cat = "net", group = "On the server", label = "send to everyone else",
	head = "send {args} to everyone except {player} on {remote}",
	code = {
		"for _, other in ipairs(Players:GetPlayers()) do",
		"\tif other ~= {player} then",
		"\t\t{remote}:FireClient(other, {args})",
		"\tend",
		"end",
	},
	fields = { remote = "expr|remote|channel", player = "expr|player|player",
		args = "expr|message|what to send" },
	needs = { "Players" }, side = "server",
	doc = "There is no built-in call for this, so it is a loop. Useful when " ..
		"the sender has already seen the result on their own screen.",
	tags = "fireclient except others broadcast" }

D{ id = "netAnswer", cat = "net", group = "On the server", label = "answer a question",
	head = "when a client asks on {remote}, with {player} and {args}",
	code = "{remote}.OnServerInvoke = function({player}, {args})", tail = "end",
	fields = { remote = "expr|question|channel", player = "name|player|player",
		args = "params||what they asked" },
	slots = { { key = "body" } },
	side = "server",
	doc = "Give back a value with a `give back` block. Note this is an " ..
		"assignment, not a connection -- only one answerer is allowed.",
	tags = "onserverinvoke answer question reply" }

-- client side ------------------------------------------------------------------------
D{ id = "netOnServerMessage", cat = "net", group = "On the client", label = "on a message from the server",
	head = "when the server sends on {remote}, with {args}",
	code = "{remote}.OnClientEvent:Connect(function({args})", tail = "end)",
	fields = { remote = "expr|remote|channel", args = "params|amount|what was sent" },
	slots = { { key = "body" } },
	side = "client",
	doc = "There is no player argument here, because there is only one player " ..
		"on a client.",
	tags = "onclientevent receive server message" }

D{ id = "netToServer", cat = "net", group = "On the client", label = "send to the server",
	head = "send {args} to the server on {remote}",
	code = "{remote}:FireServer({args})",
	fields = { remote = "expr|remote|channel", args = "expr|amount|what to send" },
	side = "client",
	doc = "Ask, never tell. Send `I pressed the buy button`, not `give me the " ..
		"sword` -- the server decides.",
	tags = "fireserver send request client" }

D{ id = "netAsk", cat = "net", group = "On the client", label = "ask the server",
	head = "make {name} = the server's answer to {args} on {remote}",
	code = "local {name} = {remote}:InvokeServer({args})",
	fields = { name = "name|answer|name", remote = "expr|question|channel",
		args = "expr||what to ask" },
	side = "client",
	doc = "This waits for the reply, so the rest of the script stops until " ..
		"the server answers. Never do it every frame.",
	tags = "invokeserver ask wait answer client" }

-- inside one side -----------------------------------------------------------------------
D{ id = "netBindable", cat = "net", group = "Same side", label = "make an in-house channel",
	head = 'make {name} = an in-house channel called "{label}"',
	code = {
		'local {name} = Instance.new("BindableEvent")',
		'{name}.Name = "{label}"',
		"{name}.Parent = {parent}",
	},
	fields = { name = "name|signal|name", label = "str|RoundStarted|channel name",
		parent = "expr|script.Parent|parent" },
	doc = "A BindableEvent connects two scripts on the same side. No network " ..
		"is involved, so it is instant and cannot be exploited.",
	tags = "bindableevent signal same side script" }

D{ id = "netBindableFire", cat = "net", group = "Same side", label = "fire an in-house channel",
	head = "fire {signal} with {args}",
	code = "{signal}:Fire({args})",
	fields = { signal = "expr|signal|channel", args = "expr||what to send" },
	doc = "Everything connected to it runs, in the order it connected.",
	tags = "bindable fire signal trigger" }

D{ id = "netBindableOn", cat = "net", group = "Same side", label = "on an in-house channel",
	head = "when {signal} fires with {args}",
	code = "{signal}.Event:Connect(function({args})", tail = "end)",
	fields = { signal = "expr|signal|channel", args = "params||what was sent" },
	slots = { { key = "body" } },
	doc = "Note the `.Event` -- a BindableEvent keeps its signal in a child " ..
		"property, unlike a RemoteEvent.",
	tags = "bindable event connect listen" }

D{ id = "netAmServer", cat = "net", group = "Same side", label = "if this is the server",
	head = "if this is running on the server then",
	code = "if RunService:IsServer() then", tail = "end",
	slots = { { key = "body" } },
	needs = { "RunService" },
	doc = "Lets one ModuleScript behave differently depending on which side " ..
		"required it.",
	tags = "isserver check side runservice" }

D{ id = "netAmClient", cat = "net", group = "Same side", label = "if this is a client",
	head = "if this is running on a client then",
	code = "if RunService:IsClient() then", tail = "end",
	slots = { { key = "body" } },
	needs = { "RunService" },
	doc = "The other half of the pair, for shared modules.",
	tags = "isclient check side runservice" }

--=============================================================================
-- SHOP
--=============================================================================

D{ id = "shopAskPass", cat = "shop", group = "Passes", label = "offer a pass",
	head = "ask {player} to buy pass {id}",
	code = "MarketplaceService:PromptGamePassPurchase({player}, {id})",
	fields = { player = "expr|player|player", id = "num|0|pass id" },
	needs = { "MarketplaceService" },
	doc = "Opens Roblox's own buy window. You never handle the money -- you " ..
		"only react afterwards.",
	tags = "gamepass prompt purchase buy shop" }

D{ id = "shopOwnsPass", cat = "shop", group = "Passes", label = "if they own a pass",
	head = "if {player} owns pass {id} then",
	code = "if MarketplaceService:UserOwnsGamePassAsync({player}.UserId, {id}) then",
	tail = "end",
	fields = { player = "expr|player|player", id = "num|0|pass id" },
	slots = { { key = "body" } },
	needs = { "MarketplaceService" }, side = "server",
	doc = "This asks Roblox and waits for the answer, so it can be slow and " ..
		"can fail. Check once when they join rather than every frame.",
	tags = "userownsgamepass owns pass check shop" }

D{ id = "shopOnPassBought", cat = "shop", group = "Passes", label = "on a pass bought",
	head = "when {player} finishes the pass window, with pass {id} and {bought}",
	code = "MarketplaceService.PromptGamePassPurchaseFinished:Connect(" ..
		"function({player}, {id}, {bought})",
	tail = "end)",
	fields = { player = "name|player|player", id = "name|passId|pass id",
		bought = "name|wasBought|did they buy" },
	slots = { { key = "body" } },
	needs = { "MarketplaceService" }, side = "server",
	doc = "Fires whether they bought it or closed the window, so check the " ..
		"last value before handing anything over.",
	tags = "promptgamepasspurchasefinished bought pass event" }

D{ id = "shopGrantForPass", cat = "shop", group = "Passes", label = "give something for a pass",
	head = "when {player} joins, if they own pass {id}",
	code = {
		"Players.PlayerAdded:Connect(function({player})",
		"\tlocal ok, owns = pcall(function()",
		"\t\treturn MarketplaceService:UserOwnsGamePassAsync({player}.UserId, {id})",
		"\tend)",
		"\tif ok and owns then",
	},
	codeTail = { "\tend", "end)" }, tail = "end",
	bodyIndent = 2,
	fields = { player = "name|player|player", id = "num|0|pass id" },
	slots = { { key = "body" } },
	needs = { "MarketplaceService", "Players" }, side = "server",
	doc = "The whole shape of a pass perk: check on join, wrapped so a " ..
		"network hiccup cannot kill the script.",
	tags = "gamepass perk join grant owns" }

D{ id = "shopAskProduct", cat = "shop", group = "Products", label = "offer a product",
	head = "ask {player} to buy product {id}",
	code = "MarketplaceService:PromptProductPurchase({player}, {id})",
	fields = { player = "expr|player|player", id = "num|0|product id" },
	needs = { "MarketplaceService" },
	doc = "Developer products can be bought over and over, unlike passes. " ..
		"Coins and revives are products.",
	tags = "developer product prompt purchase repeat" }

D{ id = "shopOnProductBought", cat = "shop", group = "Products", label = "on a product bought",
	head = "when a product is bought, as {receipt} by {player}",
	code = {
		"MarketplaceService.ProcessReceipt = function({receipt})",
		"\tlocal {player} = Players:GetPlayerByUserId({receipt}.PlayerId)",
		"\tif not {player} then",
		"\t\treturn Enum.ProductPurchaseDecision.NotProcessedYet",
		"\tend",
	},
	codeTail = { "\treturn Enum.ProductPurchaseDecision.PurchaseGranted", "end" },
	tail = "end",
	fields = { receipt = "name|receipt|receipt", player = "name|player|player" },
	slots = { { key = "body" } },
	needs = { "MarketplaceService", "Players" }, side = "server",
	doc = "Roblox keeps asking until you say the purchase was granted, so a " ..
		"player who leaves mid-purchase still gets their goods next time. " ..
		"`receipt.ProductId` says which product it was.",
	tags = "processreceipt product purchase receipt grant" }

D{ id = "shopWhichProduct", cat = "shop", group = "Products", label = "if it was this product",
	head = "if {receipt} is for product {id} then",
	code = "if {receipt}.ProductId == {id} then", tail = "end",
	fields = { receipt = "expr|receipt|receipt", id = "num|0|product id" },
	slots = { { key = "body" } },
	side = "server",
	doc = "Goes inside the product handler, one branch per product you sell.",
	tags = "productid receipt branch product" }

D{ id = "shopProductInfo", cat = "shop", group = "Prices", label = "look up an item",
	head = "make {name} = the details of {kind} {id}",
	code = "local {name} = MarketplaceService:GetProductInfo({id}, Enum.InfoType.{kind})",
	fields = { name = "name|info|name", id = "num|0|id",
		kind = "choice|GamePass|kind|GamePass,Product,Asset" },
	needs = { "MarketplaceService" },
	doc = "Gives back a table with `Name`, `Description` and `PriceInRobux`, " ..
		"so a shop can build itself from the ids alone.",
	tags = "getproductinfo price name description shop" }

D{ id = "shopPrice", cat = "shop", group = "Prices", label = "the price of something",
	head = "make {name} = the price of {kind} {id}",
	code = "local {name} = MarketplaceService:GetProductInfo({id}, " ..
		"Enum.InfoType.{kind}).PriceInRobux",
	fields = { name = "name|price|name", id = "num|0|id",
		kind = "choice|GamePass|kind|GamePass,Product,Asset" },
	needs = { "MarketplaceService" },
	doc = "Reading the price rather than typing it means your shop is never " ..
		"out of date with what Roblox charges.",
	tags = "price robux cost shop" }

D{ id = "shopOwnsAsset", cat = "shop", group = "Prices", label = "if they own an asset",
	head = "if {player} owns asset {id} then",
	code = "if MarketplaceService:PlayerOwnsAsset({player}, {id}) then", tail = "end",
	fields = { player = "expr|player|player", id = "num|0|asset id" },
	slots = { { key = "body" } },
	needs = { "MarketplaceService" }, side = "server",
	doc = "Covers shirts, hats and models rather than passes. Useful for " ..
		"rewarding people who own your merchandise.",
	tags = "playerownsasset owns asset merch check" }

D{ id = "shopIsPremium", cat = "shop", group = "Prices", label = "if they have Premium",
	head = "if {player} has Roblox Premium then",
	code = "if {player}.MembershipType == Enum.MembershipType.Premium then", tail = "end",
	fields = { player = "expr|player|player" },
	slots = { { key = "body" } },
	doc = "Reading their membership costs nothing and never fails, unlike " ..
		"asking about a pass.",
	tags = "premium membership check benefit" }

D{ id = "shopAskPremium", cat = "shop", group = "Prices", label = "offer Premium",
	head = "show {player} the Premium window",
	code = "MarketplaceService:PromptPremiumPurchase({player})",
	fields = { player = "expr|player|player" },
	needs = { "MarketplaceService" },
	doc = "Opens Roblox's Premium page. Worth offering only where a Premium " ..
		"perk is actually visible.",
	tags = "premium prompt purchase upsell" }

D{ id = "shopAwardBadge", cat = "shop", group = "Badges", label = "award a badge",
	head = "award badge {id} to {player}",
	code = {
		"pcall(function()",
		"\tBadgeService:AwardBadge({player}.UserId, {id})",
		"end)",
	},
	fields = { player = "expr|player|player", id = "num|0|badge id" },
	needs = { "BadgeService" }, side = "server",
	doc = "Badges are free to award and show on a player's profile. Awarding " ..
		"one they already have does nothing.",
	tags = "badge award achievement profile" }

D{ id = "shopHasBadge", cat = "shop", group = "Badges", label = "if they have a badge",
	head = "if {player} already has badge {id} then",
	code = "if BadgeService:UserHasBadgeAsync({player}.UserId, {id}) then", tail = "end",
	fields = { player = "expr|player|player", id = "num|0|badge id" },
	slots = { { key = "body" } },
	needs = { "BadgeService" }, side = "server",
	doc = "Waits for Roblox to answer, so check it once on join rather than " ..
		"in a loop.",
	tags = "badge check has achievement" }

--=============================================================================
-- PLACES
--=============================================================================

D{ id = "placeSend", cat = "place", group = "Going somewhere", label = "send to another place",
	head = "send {player} to place {id}",
	code = "TeleportService:Teleport({id}, {player})",
	fields = { player = "expr|player|player", id = "num|0|place id" },
	needs = { "TeleportService" }, side = "server",
	doc = "Place ids come from the URL of a place in your experience. The " ..
		"player sees a loading screen and arrives in the other place.",
	tags = "teleport place send travel" }

D{ id = "placeSendMany", cat = "place", group = "Going somewhere", label = "send a group together",
	head = "send {list} to place {id} together",
	code = "TeleportService:TeleportPartyAsync({id}, {list})",
	fields = { list = "expr|team|list of players", id = "num|0|place id" },
	needs = { "TeleportService" }, side = "server",
	doc = "Everyone in the list lands in the same server, which is how a " ..
		"party stays together through a lobby.",
	tags = "teleportparty group together lobby" }

D{ id = "placeSendWith", cat = "place", group = "Going somewhere", label = "send with a message",
	head = "send {player} to place {id} carrying {data}",
	code = {
		"do",
		'\tlocal options = Instance.new("TeleportOptions")',
		"\toptions:SetTeleportData({data})",
		"\tTeleportService:TeleportAsync({id}, { {player} }, options)",
		"end",
	},
	fields = { player = "expr|player|player", id = "num|0|place id",
		data = "expr|{ score = 10 }|data to carry" },
	needs = { "TeleportService" }, side = "server",
	doc = "Teleport data travels with the player, which is how a lobby tells " ..
		"the next place what they chose. Never send anything cheatable.",
	tags = "teleportdata options carry data lobby" }

D{ id = "placeArrivedWith", cat = "place", group = "Going somewhere", label = "what they arrived with",
	head = "make {name} = the data {player} arrived with",
	code = "local {name} = {player}:GetJoinData().TeleportData",
	fields = { name = "name|arrived|name", player = "expr|player|player" },
	side = "server",
	doc = "Nil for anyone who joined normally rather than through a teleport, " ..
		"so always check before using it.",
	tags = "getjoindata teleportdata arrive receive" }

D{ id = "placeReserve", cat = "place", group = "Private servers", label = "reserve a server",
	head = "make {name} = a fresh private server for place {id}",
	code = "local {name} = TeleportService:ReserveServer({id})",
	fields = { name = "name|code|name", id = "num|0|place id" },
	needs = { "TeleportService" }, side = "server",
	doc = "Gives back a code for a server nobody else can join by accident. " ..
		"Matches and dungeons are built on these.",
	tags = "reserveserver private match dungeon" }

D{ id = "placeSendToReserved", cat = "place", group = "Private servers", label = "send to a reserved server",
	head = "send {list} to the reserved server {code} of place {id}",
	code = "TeleportService:TeleportToPrivateServer({id}, {code}, {list})",
	fields = { list = "expr|team|list of players", code = "expr|code|server code",
		id = "num|0|place id" },
	needs = { "TeleportService" }, side = "server",
	doc = "Everyone given the same code lands in the same private server.",
	tags = "teleporttoprivateserver reserved match private" }

D{ id = "placeIsPrivate", cat = "place", group = "Private servers", label = "if this is private",
	head = "if this server is private then",
	code = 'if game.PrivateServerId ~= "" then', tail = "end",
	slots = { { key = "body" } },
	doc = "True in both reserved servers and in private servers a player " ..
		"paid for. Check the owner id to tell them apart.",
	tags = "privateserverid private reserved check" }

D{ id = "placeOnSendFailed", cat = "place", group = "Private servers", label = "on a teleport failing",
	head = "when a teleport fails, with {player}, {reason} and {message}",
	code = "TeleportService.TeleportInitFailed:Connect(function({player}, {reason}, {message})",
	tail = "end)",
	fields = { player = "name|player|player", reason = "name|reason|reason",
		message = "name|message|message" },
	slots = { { key = "body" } },
	needs = { "TeleportService" }, side = "server",
	doc = "Teleports fail more often than you would think -- full servers, " ..
		"flood checks. Without this the player is left standing there.",
	tags = "teleportinitfailed error retry failure" }

D{ id = "placeRetrySend", cat = "place", group = "Private servers", label = "send, retrying",
	head = "try up to {tries} times to send {player} to place {id}",
	code = {
		"for attempt = 1, {tries} do",
		"\tlocal ok = pcall(function()",
		"\t\tTeleportService:TeleportAsync({id}, { {player} })",
		"\tend)",
		"\tif ok then",
		"\t\tbreak",
		"\tend",
		"\ttask.wait(attempt * 2)",
		"end",
	},
	fields = { player = "expr|player|player", id = "num|0|place id", tries = "num|3|tries" },
	needs = { "TeleportService" }, side = "server",
	doc = "Waiting longer after each failure gets past Roblox's flood checks, " ..
		"which are the usual cause.",
	tags = "teleport retry backoff reliability" }

D{ id = "placeServerId", cat = "place", group = "This server", label = "this server's id",
	head = "make {name} = this server's id",
	code = "local {name} = game.JobId",
	fields = { name = "name|serverId|name" },
	doc = "Unique to this running server. Empty in Studio, which is a handy " ..
		"way to tell you are testing.",
	tags = "jobid server id unique" }

D{ id = "placeId", cat = "place", group = "This server", label = "this place's id",
	head = "make {name} = this place's id",
	code = "local {name} = game.PlaceId",
	fields = { name = "name|placeId|name" },
	doc = "The id of the place this server is running. Compare it to a " ..
		"teleport target to avoid sending someone where they already are.",
	tags = "placeid place id current" }

D{ id = "placeHowManyHere", cat = "place", group = "This server", label = "how many are here",
	head = "make {name} = how many players are here",
	code = "local {name} = #Players:GetPlayers()",
	fields = { name = "name|here|name" },
	needs = { "Players" },
	doc = "Counts everyone currently connected to this server, not to the " ..
		"whole experience.",
	tags = "count players server population" }

D{ id = "placeRoom", cat = "place", group = "This server", label = "how many can fit",
	head = "make {name} = how many players can fit here",
	code = "local {name} = Players.MaxPlayers",
	fields = { name = "name|room|name" },
	needs = { "Players" },
	doc = "The server's cap, set in Game Settings. Compare with the count to " ..
		"know whether there is room for a party.",
	tags = "maxplayers capacity room server" }

D{ id = "placeUptime", cat = "place", group = "This server", label = "how long this server has run",
	head = "make {name} = how many seconds this server has been running",
	code = "local {name} = workspace.DistributedGameTime",
	fields = { name = "name|uptime|name" },
	doc = "Counts from when the server started, and is the same number for " ..
		"everybody in it.",
	tags = "uptime distributedgametime server clock" }

D{ id = "placeShutdownWarning", cat = "place", group = "This server", label = "warn before shutdown",
	head = "before the server closes, tell everyone",
	code = {
		"game:BindToClose(function()",
		"\tfor _, player in ipairs(Players:GetPlayers()) do",
		"\t\tpcall(function()",
		'\t\t\tplayer:Kick("This server is shutting down. Rejoin to keep playing.")',
		"\t\tend)",
		"\tend",
		"\ttask.wait({seconds})",
		"end)",
	},
	fields = { seconds = "num|3|seconds to wait" },
	needs = { "Players" }, side = "server",
	doc = "Roblox gives a closing server a few seconds. Using them to explain " ..
		"beats a silent disconnect.",
	tags = "bindtoclose shutdown kick warn close" }

end
