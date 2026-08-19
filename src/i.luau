--!nonstrict
-- i  ·  IntelliSense
--
-- Completion for the text fields inside blocks.  It knows three things a plain
-- word list does not:
--
--   * what you are typing against -- `part.` offers properties, `part:` offers
--     methods and events, and a field that wants a class name offers classes;
--   * what your own document declared -- a `make part = a new Part` block above
--     teaches it that `part` is a Part, so `part.` lists BasePart properties;
--   * how people actually type -- matching is fuzzy and subsequence-based, so
--     "ffc" finds FindFirstChild and "gsv" finds GetService.
--
--   local result = i.complete({ text = "part.Anch", cursor = 9, doc = doc })
--   result.items[1].name  --> "Anchored"

local d = require(script.Parent.d)
local q = require(script.Parent.q)

local i = {}

--=============================================================================
-- API surface
--
-- Members are written as  Name|detail|one-line doc  separated by ';'.
-- Keeping it as text costs one parse at load and keeps the table readable.
--=============================================================================

local function members(kind, text, into)
	for entry in string.gmatch(text or "", "[^;]+") do
		local name, detail, doc = string.match(entry, "^([^|]*)|([^|]*)|?(.*)$")
		if name and name ~= "" then
			into[#into + 1] = {
				name = name, kind = kind, detail = detail ~= "" and detail or nil,
				doc = doc ~= "" and doc or nil,
			}
		end
	end
	return into
end

local CLASSES = {
	Instance = {
		p = "Name|string|What the object is called;Parent|Instance|The object this one sits inside;ClassName|string|The kind of object this is;Archivable|boolean|Whether Clone copies it",
		m = "Destroy|()|Removes the object and everything in it, permanently;Clone|(): Instance|Copies the object and its children;FindFirstChild|(name, recursive?): Instance?|The child with that name, or nil;FindFirstChildOfClass|(class): Instance?|The first child of that class;FindFirstChildWhichIsA|(class): Instance?|The first child of that class or a subclass;FindFirstAncestor|(name): Instance?|Searches upward instead of down;WaitForChild|(name, timeout?): Instance|Pauses until the child exists;GetChildren|(): {Instance}|Everything one level down;GetDescendants|(): {Instance}|Everything below, at any depth;IsA|(class): boolean|True for the class and any it inherits;IsDescendantOf|(ancestor): boolean|True when it sits somewhere below;GetAttribute|(name): any|Reads a custom attribute;SetAttribute|(name, value)|Writes a custom attribute;GetAttributes|(): {[string]: any}|Every attribute at once;GetFullName|(): string|The full path, for printing",
		e = "Changed|(property)|Any property changed;ChildAdded|(child)|Something was parented in;ChildRemoved|(child)|Something was parented out;DescendantAdded|(descendant)|Something appeared below;Destroying|()|Fires just before the object goes",
	},
	PVInstance = { extends = "Instance",
		m = "GetPivot|(): CFrame|Where the object considers its centre;PivotTo|(cframe)|Moves the whole thing, keeping its parts together" },
	BasePart = { extends = "PVInstance",
		p = "Position|Vector3|Where the centre of the part is;Size|Vector3|How big it is, in studs;CFrame|CFrame|Position and rotation together;Orientation|Vector3|Rotation in degrees;Anchored|boolean|Ignores gravity and stays put;CanCollide|boolean|Whether other parts bump into it;CanTouch|boolean|Whether it fires Touched;Transparency|number|0 is solid, 1 is invisible;Color|Color3|Its colour;BrickColor|BrickColor|Its colour, the old way;Material|Enum.Material|Wood, Neon, Glass and so on;Reflectance|number|How mirror-like it looks;Massless|boolean|Whether it adds weight to an assembly;AssemblyLinearVelocity|Vector3|How fast it is moving",
		m = "ApplyImpulse|(force)|Shoves the part once;GetTouchingParts|(): {BasePart}|Everything currently overlapping it",
		e = "Touched|(otherPart)|Another part started touching this one;TouchEnded|(otherPart)|Another part stopped touching it" },
	Part = { extends = "BasePart", p = "Shape|Enum.PartType|Block, Ball, Cylinder or Wedge" },
	MeshPart = { extends = "BasePart", p = "MeshId|string|The mesh asset;TextureID|string|The texture asset" },
	SpawnLocation = { extends = "BasePart",
		p = "TeamColor|BrickColor|Which team spawns here;Neutral|boolean|Whether anyone may spawn here;Duration|number|Forcefield seconds after spawning" },
	Model = { extends = "PVInstance",
		p = "PrimaryPart|BasePart?|The part the model is measured from;WorldPivot|CFrame|The pivot used by PivotTo",
		m = "MoveTo|(position)|Moves the model, nudging it above anything in the way;GetExtentsSize|(): Vector3|How big the whole model is;ScaleTo|(scale)|Resizes the whole model;SetPrimaryPartCFrame|(cframe)|Older way to move a model" },
	Folder = { extends = "Instance" },
	Humanoid = { extends = "Instance",
		p = "Health|number|Current health;MaxHealth|number|Health when full;WalkSpeed|number|Studs per second, 16 by default;JumpPower|number|How hard it jumps, 50 by default;JumpHeight|number|How high it jumps, when UseJumpPower is off;UseJumpPower|boolean|Whether JumpPower or JumpHeight is in charge;AutoRotate|boolean|Whether the body turns to face movement;PlatformStand|boolean|Ragdoll-ish frozen state;DisplayName|string|The name shown above the head;RigType|Enum.HumanoidRigType|R6 or R15",
		m = "TakeDamage|(amount)|Subtracts health, respecting force fields;MoveTo|(position)|Walks the character toward a point;LoadAnimation|(animation): AnimationTrack|Prepares an animation to play;GetState|(): Enum.HumanoidStateType|What the character is doing;ChangeState|(state)|Forces a state, such as Jumping;EquipTool|(tool)|Puts a tool in hand;UnequipTools|()|Drops what is held",
		e = "Died|()|Health reached zero;Running|(speed)|Speed changed;Jumping|(active)|Started or stopped a jump;StateChanged|(old, new)|Moved between states;HealthChanged|(health)|Health went up or down" },
	Player = { extends = "Instance",
		p = "Character|Model?|The body in the workspace, nil while dead;CharacterAppearanceId|number|Whose look the avatar wears;DisplayName|string|The name other players see;UserId|number|Their permanent Roblox id;Team|Team?|Which team they are on;TeamColor|BrickColor|Their team's colour;AccountAge|number|Age of the account in days;CameraMode|Enum.CameraMode|First or third person",
		m = "LoadCharacter|()|Respawns them right away;Kick|(message?)|Removes them from the server;GetMouse|(): Mouse|Client only, the legacy mouse object;IsInGroup|(groupId): boolean|Group membership check;DistanceFromCharacter|(position): number|How far their body is from a point",
		e = "CharacterAdded|(character)|Their body spawned;CharacterRemoving|(character)|Their body is about to go;Chatted|(message)|They sent a chat message;Idled|(time)|They have been still a while" },
	Tool = { extends = "Model",
		p = "RequiresHandle|boolean|Whether it needs a part called Handle;CanBeDropped|boolean|Whether the player may drop it",
		e = "Activated|()|The player clicked while holding it;Deactivated|()|They let go;Equipped|(mouse)|It was taken out;Unequipped|()|It was put away" },
	Sound = { extends = "Instance",
		p = "SoundId|string|The audio asset;Volume|number|0 to 10;PlaybackSpeed|number|1 is normal;Looped|boolean|Whether it starts again at the end;TimePosition|number|Where in the sound it is;IsPlaying|boolean|Whether it is sounding now",
		m = "Play|()|Starts it;Stop|()|Stops it;Pause|()|Holds it where it is;Resume|()|Carries on",
		e = "Ended|(soundId)|It finished on its own;Played|(soundId)|It started" },
	ClickDetector = { extends = "Instance",
		p = "MaxActivationDistance|number|How close a player must be",
		e = "MouseClick|(player)|A player clicked the part;MouseHoverEnter|(player)|Their cursor arrived" },
	ProximityPrompt = { extends = "Instance",
		p = "ActionText|string|The line shown on the prompt;ObjectText|string|The smaller line under it;HoldDuration|number|Seconds the key must be held;MaxActivationDistance|number|How close a player must be;KeyboardKeyCode|Enum.KeyCode|Which key triggers it",
		e = "Triggered|(player)|A player completed the prompt;PromptShown|()|It became visible" },
	Attachment = { extends = "Instance", p = "WorldPosition|Vector3|Its position in world space;Axis|Vector3|Its forward direction" },
	Highlight = { extends = "Instance", p = "FillColor|Color3|The inside colour;OutlineColor|Color3|The edge colour;FillTransparency|number|How see-through the fill is;Adornee|Instance?|What it highlights" },
	ParticleEmitter = { extends = "Instance",
		p = "Rate|number|Particles per second;Lifetime|NumberRange|How long each lives;Speed|NumberRange|How fast they leave;Enabled|boolean|Whether it is emitting",
		m = "Emit|(count)|Fires a burst right now" },
	GuiObject = { extends = "Instance",
		p = "Position|UDim2|Where it sits;Size|UDim2|How big it is;AnchorPoint|Vector2|Which point of it Position refers to;BackgroundColor3|Color3|Its fill colour;BackgroundTransparency|number|0 is solid;Visible|boolean|Whether it draws;ZIndex|number|Draw order;Rotation|number|Degrees",
		e = "MouseEnter|()|The cursor arrived;MouseLeave|()|The cursor left;InputBegan|(input)|A press started on it" },
	TextLabel = { extends = "GuiObject",
		p = "Text|string|What it says;TextColor3|Color3|The colour of the words;TextSize|number|Height in pixels;Font|Enum.Font|Which typeface;TextScaled|boolean|Whether it shrinks to fit;TextWrapped|boolean|Whether long lines wrap;RichText|boolean|Whether tags like <b> are read" },
	TextButton = { extends = "TextLabel", e = "Activated|(input)|Clicked or tapped;MouseButton1Click|()|Clicked with the left button" },
	TextBox = { extends = "TextLabel",
		p = "PlaceholderText|string|Shown while empty;ClearTextOnFocus|boolean|Whether typing starts blank",
		e = "FocusLost|(enterPressed)|The player finished typing" },
	Frame = { extends = "GuiObject" },
	ScreenGui = { extends = "Instance", p = "Enabled|boolean|Whether it shows;ResetOnSpawn|boolean|Whether it survives respawning;IgnoreGuiInset|boolean|Whether it starts under the top bar" },
	BillboardGui = { extends = "Instance", p = "Adornee|Instance?|What it floats over;AlwaysOnTop|boolean|Whether walls hide it;Size|UDim2|How big it draws;StudsOffset|Vector3|How far it floats from the adornee" },
	IntValue = { extends = "Instance", p = "Value|number|The number it holds", e = "Changed|(value)|The value changed" },
	NumberValue = { extends = "Instance", p = "Value|number|The number it holds", e = "Changed|(value)|The value changed" },
	StringValue = { extends = "Instance", p = "Value|string|The text it holds", e = "Changed|(value)|The value changed" },
	BoolValue = { extends = "Instance", p = "Value|boolean|The true or false it holds", e = "Changed|(value)|The value changed" },
	ObjectValue = { extends = "Instance", p = "Value|Instance?|The object it points at" },
	Camera = { extends = "Instance", p = "CFrame|CFrame|Where the camera is and what it looks at;CameraType|Enum.CameraType|Who is in charge of it;CameraSubject|Instance?|What it follows;FieldOfView|number|How wide the view is" },
	Team = { extends = "Instance", p = "TeamColor|BrickColor|The team's colour;AutoAssignable|boolean|Whether joiners land here", m = "GetPlayers|(): {Player}|Everyone on this team" },
	Animation = { extends = "Instance", p = "AnimationId|string|The animation asset" },
	AnimationTrack = { extends = "Instance",
		p = "IsPlaying|boolean|Whether it is running;Speed|number|Playback rate;Looped|boolean|Whether it repeats",
		m = "Play|(fadeTime?, weight?, speed?)|Starts the animation;Stop|(fadeTime?)|Stops it;AdjustSpeed|(speed)|Changes the rate mid-play" },
	Workspace = { extends = "Instance",
		p = "Gravity|number|Studs per second squared, 196.2 by default;CurrentCamera|Camera|The camera on this client",
		m = "Raycast|(origin, direction, params?): RaycastResult?|Fires a ray and reports what it hit;GetPartBoundsInBox|(cframe, size, params?): {BasePart}|Everything inside a box;GetPartsInPart|(part, params?): {BasePart}|Everything overlapping a part" },
}

local SERVICES = {
	Players = { extends = "Instance",
		p = "LocalPlayer|Player|Client only: the player at this screen;RespawnTime|number|Seconds before a respawn;MaxPlayers|number|Server capacity",
		m = "GetPlayers|(): {Player}|Everyone connected right now;GetPlayerFromCharacter|(character): Player?|Turns a body back into a player;GetPlayerByUserId|(id): Player?|Finds a player by id;GetNameFromUserIdAsync|(id): string|Looks a username up",
		e = "PlayerAdded|(player)|Someone joined;PlayerRemoving|(player)|Someone is leaving" },
	RunService = { extends = "Instance",
		m = "IsClient|(): boolean|True in LocalScripts;IsServer|(): boolean|True in Scripts;IsStudio|(): boolean|True while testing in Studio",
		e = "Heartbeat|(deltaTime)|Every frame, after physics;RenderStepped|(deltaTime)|Client only, before drawing;Stepped|(time, deltaTime)|Every frame, before physics;PreRender|(deltaTime)|The modern name for RenderStepped" },
	ReplicatedStorage = { extends = "Instance" },
	ServerStorage = { extends = "Instance" },
	ServerScriptService = { extends = "Instance" },
	TweenService = { extends = "Instance",
		m = "Create|(instance, info, goals): Tween|Builds a tween you then Play;GetValue|(alpha, style, direction): number|The eased value at a point" },
	UserInputService = { extends = "Instance",
		p = "TouchEnabled|boolean|Whether this device has a touchscreen;KeyboardEnabled|boolean|Whether it has a keyboard;MouseBehavior|Enum.MouseBehavior|Free, locked to centre, or locked in place",
		m = "IsKeyDown|(keyCode): boolean|Whether a key is held right now;GetMouseLocation|(): Vector2|Where the cursor is",
		e = "InputBegan|(input, gameProcessed)|A key, button or touch went down;InputEnded|(input, gameProcessed)|It came back up;InputChanged|(input, gameProcessed)|The mouse or a stick moved" },
	CollectionService = { extends = "Instance",
		m = "AddTag|(instance, tag)|Marks an object;RemoveTag|(instance, tag)|Unmarks it;HasTag|(instance, tag): boolean|Asks whether it carries a tag;GetTagged|(tag): {Instance}|Everything carrying that tag;GetInstanceAddedSignal|(tag): Signal|Fires as new objects get the tag;GetInstanceRemovedSignal|(tag): Signal|Fires as objects lose it" },
	Debris = { extends = "Instance", m = "AddItem|(instance, lifetime)|Destroys the object after a delay" },
	SoundService = { extends = "Instance", m = "PlayLocalSound|(sound)|Plays a sound for this client only" },
	Lighting = { extends = "Instance",
		p = "ClockTime|number|Hour of the day, 0 to 24;Brightness|number|How strong the sun is;FogEnd|number|Where fog becomes solid;Ambient|Color3|Shadow colour;OutdoorAmbient|Color3|Outdoor shadow colour" },
	PathfindingService = { extends = "Instance", m = "CreatePath|(params?): Path|Makes a path you can compute and follow" },
	MarketplaceService = { extends = "Instance",
		m = "PromptPurchase|(player, assetId)|Opens the buy window;PromptProductPurchase|(player, productId)|Opens it for a developer product;UserOwnsGamePassAsync|(userId, passId): boolean|Whether they own a pass",
		e = "PromptGamePassPurchaseFinished|(player, passId, purchased)|The window closed" },
	DataStoreService = { extends = "Instance", m = "GetDataStore|(name, scope?): DataStore|Opens a store you can read and write" },
	TeleportService = { extends = "Instance", m = "Teleport|(placeId, player?)|Sends a player to another place" },
	HttpService = { extends = "Instance",
		m = "JSONEncode|(value): string|Turns a table into text;JSONDecode|(text): any|Turns text back into a table;GenerateGUID|(wrapped?): string|A unique id" },
	ContextActionService = { extends = "Instance",
		m = "BindAction|(name, handler, touchButton, ...)|Binds keys and a mobile button at once;UnbindAction|(name)|Removes the binding" },
	TextChatService = { extends = "Instance", m = "DisplaySystemMessage|(text)|Puts a line in the chat window" },
	StarterGui = { extends = "Instance", m = "SetCore|(name, value)|Toggles built-in interface pieces" },
}

-- Libraries and value types reachable from a bare name.
local LIBS = {
	math = { m = "floor|(n): number|Rounds down;ceil|(n): number|Rounds up;round|(n): number|Rounds to nearest;abs|(n): number|Drops the minus sign;clamp|(n, min, max): number|Keeps a number inside a range;min|(...): number|The smallest;max|(...): number|The largest;random|(m?, n?): number|A random number;sqrt|(n): number|Square root;sin|(rad): number|Sine, in radians;cos|(rad): number|Cosine, in radians;atan2|(y, x): number|The angle to a point;rad|(deg): number|Degrees to radians;deg|(rad): number|Radians to degrees;huge|number|Infinity;pi|number|3.14159...;sign|(n): number|-1, 0 or 1;fmod|(a, b): number|Remainder;noise|(x, y?, z?): number|Smooth random, good for terrain" },
	string = { m = "format|(fmt, ...): string|Fills %d, %s and %.2f;sub|(s, i, j?): string|A slice of the text;len|(s): number|How many characters;upper|(s): string|SHOUTING;lower|(s): string|quiet;rep|(s, n): string|Repeats the text;find|(s, pattern, init?, plain?)|Where a match starts;match|(s, pattern)|Pulls a piece out;gsub|(s, pattern, replacement): string|Replaces every match;split|(s, sep): {string}|Cuts text into a list;byte|(s, i?): number|Character code;char|(...): string|Codes back to text;reverse|(s): string|Backwards" },
	table = { m = "insert|(t, pos?, value)|Adds an item;remove|(t, pos?): any|Takes one out;find|(t, value): number?|Where a value sits;concat|(t, sep?): string|Joins a list into text;sort|(t, comparator?)|Puts a list in order;clear|(t)|Empties it, keeping the table;clone|(t): table|A shallow copy;freeze|(t): table|Makes it read-only;create|(count, value?): table|A pre-sized list;unpack|(t, i?, j?)|Spreads a list into arguments" },
	task = { m = "wait|(seconds?): number|Pauses this thread only;spawn|(fn, ...)|Runs something alongside;delay|(seconds, fn, ...)|Runs something later;defer|(fn, ...)|Runs it at the end of this frame;cancel|(thread)|Stops a scheduled thread" },
	os = { m = "time|(): number|Seconds since 1970;clock|(): number|A precise stopwatch reading;date|(format?, time?)|Formats a date" },
	coroutine = { m = "create|(fn): thread|Makes a coroutine;resume|(co, ...)|Runs it until it yields;yield|(...)|Hands control back;wrap|(fn): function|A coroutine as a plain function;status|(co): string|What it is doing" },
	Instance = { m = "new|(className, parent?): Instance|Builds a new object" },
	Vector3 = { m = "new|(x, y, z): Vector3|A point or direction;zero|Vector3|(0, 0, 0);one|Vector3|(1, 1, 1);xAxis|Vector3|(1, 0, 0);yAxis|Vector3|(0, 1, 0), which is up" },
	Vector2 = { m = "new|(x, y): Vector2|A flat point" },
	CFrame = { m = "new|(x, y, z): CFrame|A position, facing forward;lookAt|(from, to): CFrame|A position looking at something;Angles|(rx, ry, rz): CFrame|A rotation, in radians;fromEulerAnglesXYZ|(rx, ry, rz): CFrame|The same, spelled out;identity|CFrame|No move and no turn" },
	Color3 = { m = "fromRGB|(r, g, b): Color3|0 to 255 per channel;new|(r, g, b): Color3|0 to 1 per channel;fromHSV|(h, s, v): Color3|Hue, saturation, value;fromHex|(hex): Color3|From a string like \"#ff8800\"" },
	UDim2 = { m = "new|(xScale, xOffset, yScale, yOffset): UDim2|Scale and pixels together;fromScale|(x, y): UDim2|Fractions of the parent;fromOffset|(x, y): UDim2|Straight pixels" },
	UDim = { m = "new|(scale, offset): UDim|One axis of a UDim2" },
	TweenInfo = { m = "new|(time?, style?, direction?, repeatCount?, reverses?, delay?): TweenInfo|How a tween should move" },
	BrickColor = { m = "new|(name): BrickColor|A named colour;Random|(): BrickColor|Any colour at all" },
	Random = { m = "new|(seed?): Random|A repeatable random generator" },
	NumberRange = { m = "new|(min, max?): NumberRange|A low and high pair" },
	Ray = { m = "new|(origin, direction): Ray|A ray, mostly superseded by Raycast" },
}

local GLOBALS = {
	"game|DataModel|The root of everything in the place",
	"workspace|Workspace|Where the 3D world lives",
	"script|Instance|This script itself",
	"print|(...)|Writes to the Output window",
	"warn|(...)|Writes to Output in orange",
	"error|(message, level?)|Stops with a message",
	"assert|(condition, message?)|Errors when the condition is false",
	"pcall|(fn, ...)|Runs something and catches its error",
	"tostring|(value): string|Anything, as text",
	"tonumber|(value, base?): number?|Text as a number, or nil",
	"typeof|(value): string|The Roblox type name",
	"type|(value): string|The plain Luau type name",
	"ipairs|(t)|Loops a numbered list in order",
	"pairs|(t)|Loops every key of a table",
	"next|(t, key?)|One step of a table walk",
	"select|(n, ...)|Picks from a list of arguments",
	"require|(module)|Loads a ModuleScript",
	"tick|(): number|Seconds since 1970, as a decimal",
	"os|library|Time and date helpers",
	"math|library|Numbers",
	"string|library|Text",
	"table|library|Lists and dictionaries",
	"task|library|Waiting and threads",
	"coroutine|library|Threads, the long way round",
	"Instance|library|Instance.new lives here",
	"Vector3|library|Positions and directions",
	"Vector2|library|Flat positions",
	"CFrame|library|Position and rotation together",
	"Color3|library|Colours",
	"UDim2|library|Interface sizes and positions",
	"UDim|library|One axis of a UDim2",
	"TweenInfo|library|Tween settings",
	"BrickColor|library|Named colours",
	"Random|library|Repeatable randomness",
	"NumberRange|library|A low and high pair",
	"Enum|enum|Every fixed list Roblox knows",
}

local ENUMS = {
	KeyCode = "E;F;Q;R;T;Space;LeftShift;LeftControl;LeftAlt;Tab;Return;Escape;W;A;S;D;One;Two;Three;Four;Five;Up;Down;Left;Right;ButtonA;ButtonB;ButtonX;ButtonY",
	Material = "Plastic;SmoothPlastic;Neon;Glass;Wood;WoodPlanks;Metal;DiamondPlate;Concrete;Brick;Grass;Sand;Ice;Marble;Slate;ForceField",
	EasingStyle = "Linear;Sine;Quad;Cubic;Quart;Quint;Back;Bounce;Elastic;Exponential;Circular",
	EasingDirection = "In;Out;InOut",
	PartType = "Block;Ball;Cylinder;Wedge;CornerWedge",
	HumanoidStateType = "Running;Jumping;Freefall;Landed;Swimming;Climbing;Seated;Dead;GettingUp;PlatformStanding",
	UserInputType = "MouseButton1;MouseButton2;MouseMovement;MouseWheel;Keyboard;Touch;Gamepad1",
	Font = "SourceSans;SourceSansBold;Gotham;GothamMedium;GothamBold;Code;Arcade;Fantasy;Cartoon",
	CameraType = "Custom;Scriptable;Follow;Attach;Fixed;Track",
	NormalId = "Top;Bottom;Front;Back;Left;Right",
	RaycastFilterType = "Include;Exclude",
	AnimationPriority = "Core;Idle;Movement;Action;Action2",
}

local KEYWORDS = {
	"and", "break", "do", "else", "elseif", "end", "false", "for", "function",
	"if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
	"until", "while", "continue",
}

local SNIPPETS = {
	{ name = "Instance.new", insert = 'Instance.new("Part")', detail = "snippet",
	  doc = "Builds a new object. Remember to set its Parent." },
	{ name = "GetService", insert = 'game:GetService("Players")', detail = "snippet",
	  doc = "The proper way to reach a service." },
	{ name = "WaitForChild", insert = 'script.Parent:WaitForChild("Part")', detail = "snippet",
	  doc = "Waits for a child that may not have loaded yet." },
	{ name = "Vector3.new", insert = "Vector3.new(0, 10, 0)", detail = "snippet",
	  doc = "A position or direction. Y is up." },
	{ name = "CFrame.new", insert = "CFrame.new(0, 10, 0)", detail = "snippet",
	  doc = "A position with a rotation attached." },
	{ name = "Color3.fromRGB", insert = "Color3.fromRGB(255, 170, 60)", detail = "snippet",
	  doc = "A colour, 0 to 255 per channel." },
	{ name = "UDim2.fromScale", insert = "UDim2.fromScale(0.5, 0.5)", detail = "snippet",
	  doc = "An interface size or position as a fraction of its parent." },
	{ name = "TweenInfo.new", insert = "TweenInfo.new(0.5, Enum.EasingStyle.Quad)",
	  detail = "snippet", doc = "How long a tween takes and how it eases." },
	{ name = "math.random", insert = "math.random(1, 10)", detail = "snippet",
	  doc = "A random whole number, both ends included." },
	{ name = "os.clock", insert = "os.clock()", detail = "snippet",
	  doc = "A stopwatch reading, for timing and cooldowns." },
	{ name = "player.Character", insert = "player.Character", detail = "snippet",
	  doc = "The body in the workspace. Nil while they are dead." },
	{ name = "Humanoid", insert = 'char:FindFirstChildOfClass("Humanoid")',
	  detail = "snippet", doc = "The safe way to reach a character's Humanoid." },
}

-- Names people give things in Roblox often enough that guessing is a help
-- rather than a hazard.  Only consulted when the document says nothing.
local CONVENTIONS = {
	part = "Part", brick = "Part", block = "Part", door = "Part", coin = "Part",
	hum = "Humanoid", humanoid = "Humanoid",
	char = "Model", character = "Model", model = "Model", rig = "Model",
	player = "Player", plr = "Player", localPlayer = "Player",
	gui = "ScreenGui", label = "TextLabel", button = "TextButton",
	sound = "Sound", camera = "Camera", cam = "Camera", tool = "Tool",
	prompt = "ProximityPrompt", detector = "ClickDetector",
}

--=============================================================================
-- member lookup
--=============================================================================

local memberCache = {}

local function classEntry(name)
	return CLASSES[name] or SERVICES[name]
end

-- Every member of a class, walking up the inheritance chain.
function i.membersOf(className)
	if memberCache[className] then return memberCache[className] end
	local list = {}
	local seen = {}
	local current = className
	local guard = 0
	while current and guard < 12 do
		guard = guard + 1
		local entry = classEntry(current)
		if not entry then break end
		local gathered = {}
		members("property", entry.p, gathered)
		members("method", entry.m, gathered)
		members("event", entry.e, gathered)
		for _, member in ipairs(gathered) do
			if not seen[member.name] then
				seen[member.name] = true
				member.owner = current
				list[#list + 1] = member
			end
		end
		current = entry.extends
	end
	memberCache[className] = list
	return list
end

function i.libraryMembers(name)
	local entry = LIBS[name]
	if not entry then return nil end
	local key = "lib:" .. name
	if memberCache[key] then return memberCache[key] end
	local list = members("method", entry.m, {})
	for _, member in ipairs(list) do member.owner = name end
	memberCache[key] = list
	return list
end

function i.classNames()
	local list = {}
	for name in pairs(CLASSES) do list[#list + 1] = name end
	table.sort(list)
	return list
end

function i.serviceNames()
	local list = {}
	for name in pairs(SERVICES) do list[#list + 1] = name end
	table.sort(list)
	return list
end

function i.enumNames()
	local list = {}
	for name in pairs(ENUMS) do list[#list + 1] = name end
	table.sort(list)
	return list
end

function i.enumItems(family)
	local list = {}
	for item in string.gmatch(ENUMS[family] or "", "[^;]+") do
		list[#list + 1] = item
	end
	return list
end

-- Property names across every class, for fields that want a property name.
function i.propertyNames()
	if memberCache["*props"] then return memberCache["*props"] end
	local seen, list = {}, {}
	for className in pairs(CLASSES) do
		for _, member in ipairs(i.membersOf(className)) do
			if member.kind == "property" and not seen[member.name] then
				seen[member.name] = true
				list[#list + 1] = member
			end
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	memberCache["*props"] = list
	return list
end

--=============================================================================
-- fuzzy matching
--
-- Subsequence matching with the bonuses people expect: a prefix beats a hit in
-- the middle, and matching the capitals of a name ("ffc" -> FindFirstChild)
-- beats matching letters scattered through it.
--=============================================================================

local function isUpper(ch) return ch >= "A" and ch <= "Z" end
local function isWordChar(ch)
	return ch ~= "" and (ch == "_" or string.match(ch, "%w") ~= nil)
end

function i.score(query, candidate)
	if query == "" then return 1 end
	if #query > #candidate then return nil end

	local lowerQuery = string.lower(query)
	local lowerCandidate = string.lower(candidate)

	local total = 0
	local at = 1
	local lastHit = 0
	local firstHit = nil

	for index = 1, #lowerQuery do
		local wanted = string.sub(lowerQuery, index, index)
		local found = string.find(lowerCandidate, wanted, at, true)
		if not found then return nil end
		firstHit = firstHit or found

		local bonus = 0
		if found == lastHit + 1 then bonus = bonus + 8 end
		local before = string.sub(candidate, found - 1, found - 1)
		if found == 1 then
			bonus = bonus + 14
		elseif isUpper(string.sub(candidate, found, found)) then
			bonus = bonus + 10
		elseif not isWordChar(before) then
			bonus = bonus + 8
		end
		if string.sub(candidate, found, found) == string.sub(query, index, index) then
			bonus = bonus + 2
		end

		total = total + 6 + bonus
		lastHit = found
		at = found + 1
	end

	-- prefer short names and matches that start early
	total = total - math.min((firstHit or 1) - 1, 12)
	total = total - math.min(math.floor((#candidate - #query) / 2), 14)
	if lowerCandidate == lowerQuery then total = total + 40 end
	if string.sub(lowerCandidate, 1, #lowerQuery) == lowerQuery then total = total + 22 end
	return total
end

local KIND_RANK = {
	variable = 1, ["function"] = 1, parameter = 1, service = 2, property = 3,
	method = 3, event = 3, snippet = 4, library = 5, global = 5, class = 5,
	enum = 6, keyword = 8,
}

local function sortItems(items)
	table.sort(items, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		local ra = KIND_RANK[a.kind] or 9
		local rb = KIND_RANK[b.kind] or 9
		if ra ~= rb then return ra < rb end
		return a.name < b.name
	end)
end

--=============================================================================
-- type resolution
--=============================================================================

local function normaliseType(text)
	if not text then return nil end
	local name = string.match(text, "^([%a_][%w_]*)")
	if not name then return nil end
	if classEntry(name) then return name end
	return nil
end

local function findMember(className, memberName)
	for _, member in ipairs(i.membersOf(className)) do
		if member.name == memberName then return member end
	end
	return nil
end

-- What is `path` -- "Player", "Workspace", a library name, or nil?
-- `doc` may be nil; when given, names the document declares are consulted.
function i.resolveType(doc, path, depth)
	depth = (depth or 0) + 1
	if not path or path == "" or depth > 8 then return nil end

	local head, name = string.match(path, "^(.*)%.([%a_][%w_]*)$")
	if head and head ~= "" then
		local ownerType = i.resolveType(doc, head, depth)
		if ownerType == "game" then
			if SERVICES[name] then return name end
			return nil
		end
		if ownerType then
			local member = findMember(ownerType, name)
			if member and member.kind == "property" then
				return normaliseType(member.detail)
			end
		end
		-- `something.Parent` is always an Instance of some sort
		if name == "Parent" then return "Instance" end
		if name == "Character" then return "Model" end
		if name == "LocalPlayer" then return "Player" end
		if name == "Humanoid" then return "Humanoid" end
		return nil
	end

	if path == "game" then return "game" end
	if path == "workspace" or path == "Workspace" then return "Workspace" end
	if path == "script" then return "Instance" end
	if SERVICES[path] then return path end
	if CLASSES[path] then return path end
	if LIBS[path] then return "lib:" .. path end
	if path == "Enum" then return "enum" end

	if doc then
		for _, symbol in ipairs(d.symbols(doc)) do
			if symbol.name == path then
				if symbol.detail and classEntry(symbol.detail) then return symbol.detail end
				if symbol.kind == "service" then return symbol.name end
				break
			end
		end
	end

	return CONVENTIONS[path]
end

--=============================================================================
-- context detection
--=============================================================================

-- Is the caret inside a string literal, and if so where did it open?
local function stringContext(prefix)
	local quote, openedAt = nil, nil
	local index = 1
	while index <= #prefix do
		local ch = string.sub(prefix, index, index)
		if quote then
			if ch == "\\" then
				index = index + 1
			elseif ch == quote then
				quote, openedAt = nil, nil
			end
		elseif ch == '"' or ch == "'" then
			quote, openedAt = ch, index
		end
		index = index + 1
	end
	if quote then return openedAt end
	return nil
end

local STRING_HINTS = {
	{ pattern = "Instance%.new%($", hint = "class" },
	{ pattern = "GetService%($", hint = "service" },
	{ pattern = ":IsA%($", hint = "class" },
	{ pattern = "FindFirstChildOfClass%($", hint = "class" },
	{ pattern = "FindFirstChildWhichIsA%($", hint = "class" },
	{ pattern = "GetPropertyChangedSignal%($", hint = "prop" },
}

-- Works out what the caret is asking for.
function i.contextAt(text, cursor)
	local prefix = string.sub(text, 1, cursor - 1)

	local quoteAt = stringContext(prefix)
	if quoteAt then
		local before = string.sub(prefix, 1, quoteAt - 1)
		local hint = nil
		for _, rule in ipairs(STRING_HINTS) do
			if string.find(before, rule.pattern) then
				hint = rule.hint
				break
			end
		end
		return {
			kind = "string",
			query = string.sub(prefix, quoteAt + 1),
			from = quoteAt + 1,
			hint = hint,
		}
	end

	local word = string.match(prefix, "[%a_][%w_]*$") or ""
	local wordStart = #prefix - #word + 1
	local accessor = string.sub(prefix, wordStart - 1, wordStart - 1)

	if accessor == "." or accessor == ":" then
		local basePart = string.sub(prefix, 1, wordStart - 2)
		local base = string.match(basePart, "[%a_][%w_%.]*$")
		return {
			kind = "member",
			query = word,
			from = wordStart,
			base = base,
			accessor = accessor,
			unresolved = base == nil,
		}
	end

	return { kind = "word", query = word, from = wordStart }
end

--=============================================================================
-- candidate building
--=============================================================================

local function push(items, entry, query)
	local score = i.score(query, entry.name)
	if not score then return end
	entry.score = score
	items[#items + 1] = entry
end

local function memberInsert(member, accessor)
	if member.kind == "method" then
		local args = member.detail and string.match(member.detail, "^%((.*)%)") or ""
		if args == "" or string.match(member.detail or "", "^%(%)") then
			return member.name .. "()", nil
		end
		return member.name .. "()", #member.name + 1
	end
	return member.name, nil
end

local function addMembers(items, query, className, accessor)
	for _, member in ipairs(i.membersOf(className)) do
		local wanted = accessor ~= ":" or member.kind ~= "property"
		if wanted then
			local insert, caret = memberInsert(member, accessor)
			push(items, {
				name = member.name, kind = member.kind, detail = member.detail,
				doc = member.doc, owner = member.owner, insert = insert, caret = caret,
			}, query)
		end
	end
end

local function addLibrary(items, query, libName)
	for _, member in ipairs(i.libraryMembers(libName) or {}) do
		local isValue = member.detail and not string.match(member.detail, "^%(")
		push(items, {
			name = member.name,
			kind = isValue and "property" or "method",
			detail = member.detail, doc = member.doc, owner = libName,
			insert = isValue and member.name or (member.name .. "()"),
			caret = (not isValue) and (#member.name + 1) or nil,
		}, query)
	end
end

local function addGlobals(items, query)
	for _, line in ipairs(GLOBALS) do
		local name, detail, doc = string.match(line, "^([^|]*)|([^|]*)|(.*)$")
		local kind = "global"
		if detail == "library" then kind = "library" end
		if detail == "enum" then kind = "enum" end
		local insert = name
		local caret = nil
		if string.sub(detail, 1, 1) == "(" and detail ~= "(...)" then
			insert = name .. "()"
			caret = #name + 1
		elseif detail == "(...)" then
			insert = name .. "()"
			caret = #name + 1
		end
		push(items, {
			name = name, kind = kind, detail = detail, doc = doc,
			insert = insert, caret = caret,
		}, query)
	end
end

local function addDocSymbols(items, query, doc)
	if not doc then return end
	for _, symbol in ipairs(d.symbols(doc)) do
		push(items, {
			name = symbol.name, kind = symbol.kind,
			detail = symbol.detail or "from your blocks",
			doc = symbol.kind == "service" and "A service your blocks already opened."
				or "Declared by a block in this project.",
			insert = symbol.name,
		}, query)
	end
end

-- Blocks you made yourself that carry no slots become a real `local function`
-- in the generated script, so their names are worth completing: this is how
-- you call one of your own blocks from inside a field.
local function addCustomHelpers(items, query)
	for _, custom in ipairs(q.list()) do
		if q.isHelper(custom) and custom.fn then
			local names = {}
			for _, field in ipairs(custom.fields) do names[#names + 1] = field.key end
			local signature = custom.fn .. "(" .. table.concat(names, ", ") .. ")"
			push(items, {
				name = custom.fn,
				kind = "function",
				detail = signature,
				doc = "Your block \"" .. custom.label .. "\". It is written into " ..
					"the script as a function the first time you use it.",
				insert = custom.fn .. "(",
			}, query)
		end
	end
end

--=============================================================================
-- entry point
--=============================================================================

-- request = { text, cursor, doc, field }
--   field.kind / field.hint steer the list for non-expression fields.
-- Returns { items, from, kind, base } -- replace text[from .. cursor-1] with
-- the chosen item's `insert`.
function i.complete(request)
	local text = request.text or ""
	local cursor = math.clamp(request.cursor or (#text + 1), 1, #text + 1)
	local field = request.field or {}
	local doc = request.doc
	local items = {}

	-- Fields that are not Luau expressions have their own short lists.
	if field.kind == "choice" then
		for _, option in ipairs(field.options or {}) do
			push(items, { name = option, kind = "choice", insert = option }, text)
		end
		sortItems(items)
		return { items = items, from = 1, kind = "choice" }
	end

	if field.kind ~= "expr" and field.kind ~= "multiline" then
		local hint = field.hint
		if hint == "class" then
			for _, name in ipairs(i.classNames()) do
				push(items, { name = name, kind = "class", insert = name,
					doc = "A Roblox class." }, text)
			end
		elseif hint == "service" then
			for _, name in ipairs(i.serviceNames()) do
				push(items, { name = name, kind = "service", insert = name,
					doc = "A Roblox service." }, text)
			end
		elseif hint == "prop" then
			for _, member in ipairs(i.propertyNames()) do
				push(items, { name = member.name, kind = "property",
					detail = member.detail, doc = member.doc, owner = member.owner,
					insert = member.name }, text)
			end
		elseif hint == "keycode" then
			for _, item in ipairs(i.enumItems("KeyCode")) do
				push(items, { name = item, kind = "enum", insert = item }, text)
			end
		elseif hint == "type" then
			for _, name in ipairs({ "number", "string", "boolean", "any", "Instance",
				"BasePart", "Player", "Humanoid", "Vector3", "CFrame", "Color3",
				"{ number }", "{ string }", "{ [string]: any }" }) do
				push(items, { name = name, kind = "class", insert = name }, text)
			end
		end
		if #items == 0 then return { items = {}, from = 1, kind = "none" } end
		sortItems(items)
		return { items = items, from = 1, kind = "field" }
	end

	local context = i.contextAt(text, cursor)

	if context.kind == "string" then
		if context.hint == "class" then
			for _, name in ipairs(i.classNames()) do
				push(items, { name = name, kind = "class", insert = name }, context.query)
			end
		elseif context.hint == "service" then
			for _, name in ipairs(i.serviceNames()) do
				push(items, { name = name, kind = "service", insert = name }, context.query)
			end
		elseif context.hint == "prop" then
			for _, member in ipairs(i.propertyNames()) do
				push(items, { name = member.name, kind = "property",
					detail = member.detail, doc = member.doc, insert = member.name },
					context.query)
			end
		end
		sortItems(items)
		return { items = items, from = context.from, kind = "string" }
	end

	if context.kind == "member" then
		local resolved = context.base and i.resolveType(doc, context.base) or nil

		if resolved == "enum" then
			for _, name in ipairs(i.enumNames()) do
				push(items, { name = name, kind = "enum", insert = name,
					doc = "A fixed list Roblox understands." }, context.query)
			end
		elseif context.base and string.match(context.base, "^Enum%.([%a_][%w_]*)$") then
			local family = string.match(context.base, "^Enum%.([%a_][%w_]*)$")
			for _, item in ipairs(i.enumItems(family)) do
				push(items, { name = item, kind = "enum", insert = item,
					detail = "Enum." .. family }, context.query)
			end
		elseif resolved == "game" then
			for _, name in ipairs(i.serviceNames()) do
				push(items, { name = name, kind = "service", insert = name,
					doc = "Reachable from game, though GetService is safer." },
					context.query)
			end
			push(items, { name = "GetService", kind = "method", detail = "(name): Instance",
				doc = "The reliable way to reach a service.",
				insert = "GetService()", caret = 11 }, context.query)
		elseif resolved and string.sub(resolved, 1, 4) == "lib:" then
			addLibrary(items, context.query, string.sub(resolved, 5))
		elseif resolved then
			addMembers(items, context.query, resolved, context.accessor)
		else
			-- Unknown base: Instance members are the safest guess in Roblox code.
			addMembers(items, context.query, "Instance", context.accessor)
		end

		sortItems(items)
		return {
			items = items, from = context.from, kind = "member",
			base = context.base, resolved = resolved,
			accessor = context.accessor,
		}
	end

	addDocSymbols(items, context.query, doc)
	addCustomHelpers(items, context.query)
	addGlobals(items, context.query)
	for _, snippet in ipairs(SNIPPETS) do
		push(items, {
			name = snippet.name, kind = "snippet", detail = snippet.detail,
			doc = snippet.doc, insert = snippet.insert,
		}, context.query)
	end
	if #context.query > 0 then
		for _, word in ipairs(KEYWORDS) do
			push(items, { name = word, kind = "keyword", insert = word }, context.query)
		end
	end

	sortItems(items)
	return { items = items, from = context.from, kind = "word" }
end

--=============================================================================
-- signature help
--=============================================================================

-- Which call is the caret inside, and which argument is it on?
function i.signature(text, cursor, doc)
	local prefix = string.sub(text, 1, (cursor or (#text + 1)) - 1)
	local depth = 0
	local index = #prefix
	local commas = 0
	while index > 0 do
		local ch = string.sub(prefix, index, index)
		if ch == ")" or ch == "}" or ch == "]" then
			depth = depth + 1
		elseif ch == "(" then
			if depth == 0 then break end
			depth = depth - 1
		elseif ch == "{" or ch == "[" then
			if depth > 0 then depth = depth - 1 end
		elseif ch == "," and depth == 0 then
			commas = commas + 1
		end
		index = index - 1
	end
	if index <= 0 then return nil end

	local callee = string.match(string.sub(prefix, 1, index - 1), "([%a_][%w_%.:]*)$")
	if not callee then return nil end

	local head, sep, name = string.match(callee, "^(.*)([%.:])([%a_][%w_]*)$")
	local member = nil
	if head then
		local resolved = i.resolveType(doc, head)
		if resolved and string.sub(resolved, 1, 4) == "lib:" then
			for _, entry in ipairs(i.libraryMembers(string.sub(resolved, 5)) or {}) do
				if entry.name == name then member = entry end
			end
		elseif resolved and resolved ~= "game" and resolved ~= "enum" then
			member = findMember(resolved, name)
		end
	else
		for _, line in ipairs(GLOBALS) do
			local globalName, detail, docText = string.match(line, "^([^|]*)|([^|]*)|(.*)$")
			if globalName == callee and string.sub(detail, 1, 1) == "(" then
				member = { name = globalName, detail = detail, doc = docText }
			end
		end
	end

	if not member or not member.detail then return nil end
	return {
		label = member.name .. member.detail,
		doc = member.doc,
		argument = commas + 1,
	}
end

return i
