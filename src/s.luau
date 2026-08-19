--!nonstrict
-- s  ·  block definitions: interface, camera and light, sound
--
-- Returns a function taking the registry's define helper, so this file never
-- has to require `c` back.  See the bottom of c.luau for the loader.

return function(D)

--=============================================================================
-- INTERFACE
--=============================================================================

-- screens ---------------------------------------------------------------------
D{ id = "uiScreen", cat = "ui", group = "Screens", label = "make a screen",
	head = "make {name} = a screen inside {parent}",
	code = {
		'local {name} = Instance.new("ScreenGui")',
		"{name}.ResetOnSpawn = false",
		"{name}.Parent = {parent}",
	},
	fields = { name = "name|screen|name", parent = "expr|player.PlayerGui|parent" },
	side = "client",
	doc = "A ScreenGui is the sheet everything else is drawn on. Keeping " ..
		"ResetOnSpawn off means it survives the player dying.",
	tags = "screengui gui interface hud screen" }

D{ id = "uiPlayerGui", cat = "ui", group = "Screens", label = "the player's screen holder",
	head = "make {name} = the screen holder of {player}",
	code = 'local {name} = {player}:WaitForChild("PlayerGui")',
	fields = { name = "name|gui|name", player = "expr|player|player" },
	doc = "Everything a player sees lives inside their PlayerGui. Waiting for " ..
		"it matters, because it arrives a moment after they do.",
	tags = "playergui screen holder wait" }

D{ id = "uiShow", cat = "ui", group = "Screens", label = "show or hide a screen",
	head = "set the screen {gui} showing to {value}",
	code = "{gui}.Enabled = {value}",
	fields = { gui = "expr|screen|screen", value = "choice|true|value|true,false" },
	doc = "Turns a whole screen on or off in one line, leaving everything " ..
		"inside it as it was.",
	tags = "enabled show hide screen visible" }

D{ id = "uiTopOfScreen", cat = "ui", group = "Screens", label = "use the very top",
	head = "let {gui} use the very top of the screen",
	code = "{gui}.IgnoreGuiInset = true",
	fields = { gui = "expr|screen|screen" },
	doc = "By default Roblox keeps a strip clear at the top for its own bar. " ..
		"This lets your screen draw there too.",
	tags = "inset topbar fullscreen offset" }

D{ id = "uiDrawOrder", cat = "ui", group = "Screens", label = "draw a screen in front",
	head = "draw {gui} in front of other screens, at level {order}",
	code = "{gui}.DisplayOrder = {order}",
	fields = { gui = "expr|screen|screen", order = "num|10|level" },
	doc = "Higher numbers are drawn later, so they sit on top. Use it to keep " ..
		"a pause menu above the rest of the interface.",
	tags = "displayorder layer front above" }

D{ id = "uiKeepOnRespawn", cat = "ui", group = "Screens", label = "keep on respawn",
	head = "keep {gui} when the player respawns",
	code = "{gui}.ResetOnSpawn = false",
	fields = { gui = "expr|screen|screen" },
	doc = "Screens are thrown away and rebuilt on every respawn unless you say " ..
		"otherwise. Anything holding state wants this.",
	tags = "resetonspawn respawn keep persist" }

D{ id = "uiBillboard", cat = "ui", group = "Screens", label = "floating label",
	head = "make {name} = a label floating over {adornee}",
	code = {
		'local {name} = Instance.new("BillboardGui")',
		"{name}.Size = UDim2.fromOffset(200, 50)",
		"{name}.StudsOffset = Vector3.new(0, {height}, 0)",
		"{name}.AlwaysOnTop = true",
		"{name}.Adornee = {adornee}",
		"{name}.Parent = {adornee}",
	},
	fields = { name = "name|tag|name", adornee = "expr|part|object",
		height = "num|3|studs above" },
	doc = "A BillboardGui hangs in the world but always faces the camera. " ..
		"Name tags and damage numbers are made of these.",
	tags = "billboard floating nametag world label" }

D{ id = "uiSurface", cat = "ui", group = "Screens", label = "screen on a part",
	head = "make {name} = a screen on the {face} face of {part}",
	code = {
		'local {name} = Instance.new("SurfaceGui")',
		"{name}.Face = Enum.NormalId.{face}",
		"{name}.Adornee = {part}",
		"{name}.Parent = {part}",
	},
	fields = { name = "name|sign|name", part = "expr|part|part",
		face = "choice|Front|face|Front,Back,Top,Bottom,Left,Right" },
	doc = "Draws interface flat onto a part, which is how signs, screens and " ..
		"arcade cabinets are made.",
	tags = "surfacegui sign screen part face" }

-- boxes -----------------------------------------------------------------------
D{ id = "uiBox", cat = "ui", group = "Boxes", label = "make a box",
	head = "make {name} = a box inside {parent}",
	code = {
		'local {name} = Instance.new("Frame")',
		"{name}.Size = UDim2.fromScale({w}, {h})",
		"{name}.Position = UDim2.fromScale({x}, {y})",
		"{name}.BackgroundColor3 = Color3.fromRGB(30, 32, 40)",
		"{name}.Parent = {parent}",
	},
	fields = { name = "name|panel|name", parent = "expr|screen|parent",
		w = "num|0.3|width", h = "num|0.2|height", x = "num|0.35|x", y = "num|0.4|y" },
	doc = "A Frame is a plain rectangle. Everything else is built by putting " ..
		"things inside one. Sizes are fractions of the parent.",
	tags = "frame box panel rectangle container" }

D{ id = "uiScrollBox", cat = "ui", group = "Boxes", label = "make a scrolling box",
	head = "make {name} = a scrolling box inside {parent}",
	code = {
		'local {name} = Instance.new("ScrollingFrame")',
		"{name}.Size = UDim2.fromScale({w}, {h})",
		"{name}.BackgroundTransparency = 1",
		"{name}.AutomaticCanvasSize = Enum.AutomaticSize.Y",
		"{name}.CanvasSize = UDim2.new()",
		"{name}.ScrollBarThickness = 6",
		"{name}.Parent = {parent}",
	},
	fields = { name = "name|list|name", parent = "expr|screen|parent",
		w = "num|0.4|width", h = "num|0.6|height" },
	doc = "Automatic canvas size means the scrollable area grows to fit " ..
		"whatever you put inside, so you never set it by hand.",
	tags = "scrollingframe scroll list inventory" }

D{ id = "uiSize", cat = "ui", group = "Boxes", label = "set size in fractions",
	head = "set the size of {gui} to {w} by {h} of its parent",
	code = "{gui}.Size = UDim2.fromScale({w}, {h})",
	fields = { gui = "expr|panel|object", w = "num|0.5|width", h = "num|0.25|height" },
	doc = "Fractions keep the interface the same shape on a phone and a " ..
		"monitor. 1 means the full width of the parent.",
	tags = "size scale fraction udim2 resize" }

D{ id = "uiSizePixels", cat = "ui", group = "Boxes", label = "set size in pixels",
	head = "set the size of {gui} to {w} by {h} pixels",
	code = "{gui}.Size = UDim2.fromOffset({w}, {h})",
	fields = { gui = "expr|panel|object", w = "num|200|width", h = "num|50|height" },
	doc = "Pixels stay the same size whatever the screen, which is right for " ..
		"icons and borders and wrong for whole panels.",
	tags = "size pixels offset udim2" }

D{ id = "uiPos", cat = "ui", group = "Boxes", label = "put at fractions",
	head = "put {gui} at {x}, {y} of its parent",
	code = "{gui}.Position = UDim2.fromScale({x}, {y})",
	fields = { gui = "expr|panel|object", x = "num|0.5|x", y = "num|0.5|y" },
	doc = "0, 0 is the top left and 1, 1 is the bottom right. Pair it with an " ..
		"anchor point of 0.5, 0.5 to centre something properly.",
	tags = "position place scale move udim2" }

D{ id = "uiPosPixels", cat = "ui", group = "Boxes", label = "put at pixels",
	head = "put {gui} at {x}, {y} pixels",
	code = "{gui}.Position = UDim2.fromOffset({x}, {y})",
	fields = { gui = "expr|panel|object", x = "num|20|x", y = "num|20|y" },
	doc = "Measured from the top left corner of the parent, in screen pixels.",
	tags = "position pixels offset move" }

D{ id = "uiAnchor", cat = "ui", group = "Boxes", label = "set the anchor point",
	head = "measure {gui} from the point {x}, {y} of itself",
	code = "{gui}.AnchorPoint = Vector2.new({x}, {y})",
	fields = { gui = "expr|panel|object", x = "num|0.5|x", y = "num|0.5|y" },
	doc = "The anchor point says which part of the object its position refers " ..
		"to. 0.5, 0.5 means the middle, which is what centring needs.",
	tags = "anchorpoint centre middle align pivot" }

D{ id = "uiPaint", cat = "ui", group = "Boxes", label = "paint",
	head = "paint {gui} red {r} green {g} blue {b}",
	code = "{gui}.BackgroundColor3 = Color3.fromRGB({r}, {g}, {b})",
	fields = { gui = "expr|panel|object", r = "num|40|red", g = "num|44|green",
		b = "num|56|blue" },
	doc = "Each channel runs 0 to 255, the same numbers the colour picker shows.",
	tags = "colour color background paint rgb" }

D{ id = "uiSeeThrough", cat = "ui", group = "Boxes", label = "set see-through",
	head = "set how see-through {gui} is to {value}",
	code = "{gui}.BackgroundTransparency = {value}",
	fields = { gui = "expr|panel|object", value = "num|0.5|amount" },
	doc = "0 is solid and 1 is invisible. The things inside stay visible " ..
		"either way -- only the background fades.",
	tags = "transparency alpha fade background" }

D{ id = "uiVisible", cat = "ui", group = "Boxes", label = "show or hide",
	head = "set {gui} showing to {value}",
	code = "{gui}.Visible = {value}",
	fields = { gui = "expr|panel|object", value = "choice|true|value|true,false" },
	doc = "Hiding an object hides everything inside it, and hidden things " ..
		"stop receiving clicks.",
	tags = "visible show hide toggle" }

D{ id = "uiRoundCorners", cat = "ui", group = "Boxes", label = "round the corners",
	head = "round the corners of {gui} by {radius} pixels",
	code = {
		"do",
		'\tlocal corner = Instance.new("UICorner")',
		"\tcorner.CornerRadius = UDim.new(0, {radius})",
		"\tcorner.Parent = {gui}",
		"end",
	},
	fields = { gui = "expr|panel|object", radius = "num|8|radius" },
	doc = "Adds a UICorner. One per object -- adding a second does nothing.",
	tags = "uicorner rounded radius corners" }

D{ id = "uiOutline", cat = "ui", group = "Boxes", label = "outline",
	head = "outline {gui} with a {thickness} pixel line, red {r} green {g} blue {b}",
	code = {
		"do",
		'\tlocal stroke = Instance.new("UIStroke")',
		"\tstroke.Thickness = {thickness}",
		"\tstroke.Color = Color3.fromRGB({r}, {g}, {b})",
		"\tstroke.Parent = {gui}",
		"end",
	},
	fields = { gui = "expr|panel|object", thickness = "num|2|thickness",
		r = "num|255|red", g = "num|255|green", b = "num|255|blue" },
	doc = "A UIStroke draws a border that follows rounded corners properly, " ..
		"which the old BorderSizePixel never did.",
	tags = "uistroke border outline edge" }

D{ id = "uiPadding", cat = "ui", group = "Boxes", label = "add padding",
	head = "leave {n} pixels of space inside the edges of {gui}",
	code = {
		"do",
		'\tlocal padding = Instance.new("UIPadding")',
		"\tpadding.PaddingLeft = UDim.new(0, {n})",
		"\tpadding.PaddingRight = UDim.new(0, {n})",
		"\tpadding.PaddingTop = UDim.new(0, {n})",
		"\tpadding.PaddingBottom = UDim.new(0, {n})",
		"\tpadding.Parent = {gui}",
		"end",
	},
	fields = { gui = "expr|panel|object", n = "num|8|pixels" },
	doc = "Padding pushes the contents inward without changing the size of " ..
		"the object itself.",
	tags = "uipadding padding margin space inset" }

D{ id = "uiKeepShape", cat = "ui", group = "Boxes", label = "keep a shape",
	head = "keep {gui} {ratio} times as wide as it is tall",
	code = {
		"do",
		'\tlocal shape = Instance.new("UIAspectRatioConstraint")',
		"\tshape.AspectRatio = {ratio}",
		"\tshape.Parent = {gui}",
		"end",
	},
	fields = { gui = "expr|panel|object", ratio = "num|1|ratio" },
	doc = "Stops an object stretching oddly on wide or tall screens. 1 keeps " ..
		"it square.",
	tags = "aspect ratio square shape constraint" }

D{ id = "uiInFront", cat = "ui", group = "Boxes", label = "draw in front",
	head = "draw {gui} in front of its neighbours, at level {order}",
	code = "{gui}.ZIndex = {order}",
	fields = { gui = "expr|panel|object", order = "num|2|level" },
	doc = "Among things in the same screen, higher numbers are drawn on top.",
	tags = "zindex layer front behind order" }

D{ id = "uiClip", cat = "ui", group = "Boxes", label = "clip the overflow",
	head = "hide anything sticking out of {gui}",
	code = "{gui}.ClipsDescendants = true",
	fields = { gui = "expr|panel|object" },
	doc = "Anything inside that reaches past the edges is cut off. How " ..
		"progress bars and masked images are made.",
	tags = "clip overflow mask crop" }

D{ id = "uiGradient", cat = "ui", group = "Boxes", label = "add a gradient",
	head = "fade {gui} from red {r1} green {g1} blue {b1} to red {r2} green {g2} blue {b2}",
	code = {
		"do",
		'\tlocal gradient = Instance.new("UIGradient")',
		"\tgradient.Color = ColorSequence.new(",
		"\t\tColor3.fromRGB({r1}, {g1}, {b1}), Color3.fromRGB({r2}, {g2}, {b2}))",
		"\tgradient.Rotation = {angle}",
		"\tgradient.Parent = {gui}",
		"end",
	},
	fields = { gui = "expr|panel|object", r1 = "num|60|from red", g1 = "num|70|from green",
		b1 = "num|110|from blue", r2 = "num|20|to red", g2 = "num|24|to green",
		b2 = "num|36|to blue", angle = "num|90|angle" },
	doc = "A UIGradient tints whatever is behind it. An angle of 90 runs top " ..
		"to bottom, 0 runs left to right.",
	tags = "uigradient gradient fade colour sequence" }

-- words -----------------------------------------------------------------------
D{ id = "uiLabel", cat = "ui", group = "Words", label = "make a label",
	head = 'make {name} = a label saying "{text}" inside {parent}',
	code = {
		'local {name} = Instance.new("TextLabel")',
		"{name}.Size = UDim2.fromScale(1, 0.2)",
		"{name}.BackgroundTransparency = 1",
		'{name}.Text = "{text}"',
		"{name}.TextColor3 = Color3.fromRGB(255, 255, 255)",
		"{name}.TextScaled = true",
		"{name}.Parent = {parent}",
	},
	fields = { name = "name|label|name", text = "str|Hello|words",
		parent = "expr|panel|parent" },
	doc = "A TextLabel shows words and nothing else. Scaled text grows and " ..
		"shrinks to fill the label, which is usually what you want.",
	tags = "textlabel label text words caption" }

D{ id = "uiSetWords", cat = "ui", group = "Words", label = "set the words",
	head = "set the words of {gui} to {value}",
	code = "{gui}.Text = {value}",
	fields = { gui = "expr|label|label", value = "expr|score|value" },
	doc = "Anything can go in as long as it is text. Numbers convert on their " ..
		"own; other values need `value to text` first.",
	tags = "text set words change label" }

D{ id = "uiSetWordsText", cat = "ui", group = "Words", label = "set the words to",
	head = 'set the words of {gui} to "{text}"',
	code = '{gui}.Text = "{text}"',
	fields = { gui = "expr|label|label", text = "str|Ready|words" },
	doc = "For fixed wording, with no quotes to type in the field.",
	tags = "text set words literal" }

D{ id = "uiCountUp", cat = "ui", group = "Words", label = "show a number",
	head = "show {value} in {gui} with {places} decimal places",
	code = '{gui}.Text = string.format("%.{places}f", {value})',
	fields = { gui = "expr|label|label", value = "expr|health|value",
		places = "num|0|places" },
	doc = "Rounds a number for display without changing the number itself. " ..
		"Zero places gives a whole number.",
	tags = "format number decimal round display" }

D{ id = "uiWordColour", cat = "ui", group = "Words", label = "colour the words",
	head = "colour the words in {gui} red {r} green {g} blue {b}",
	code = "{gui}.TextColor3 = Color3.fromRGB({r}, {g}, {b})",
	fields = { gui = "expr|label|label", r = "num|255|red", g = "num|255|green",
		b = "num|255|blue" },
	doc = "Only the letters change colour. The background is separate.",
	tags = "textcolor colour words text" }

D{ id = "uiWordSize", cat = "ui", group = "Words", label = "set letter height",
	head = "set the letter height in {gui} to {size} pixels",
	code = { "{gui}.TextScaled = false", "{gui}.TextSize = {size}" },
	fields = { gui = "expr|label|label", size = "num|18|height" },
	doc = "A fixed height, which needs scaling switched off first or it will " ..
		"be ignored.",
	tags = "textsize letter height font size" }

D{ id = "uiWordsFit", cat = "ui", group = "Words", label = "let the words fit",
	head = "let the words in {gui} shrink to fit",
	code = "{gui}.TextScaled = true",
	fields = { gui = "expr|label|label" },
	doc = "The text grows or shrinks so it always fills the label. Simplest " ..
		"way to make an interface work on every screen.",
	tags = "textscaled fit shrink responsive" }

D{ id = "uiWordsWrap", cat = "ui", group = "Words", label = "wrap long words",
	head = "let long text in {gui} wrap onto the next line",
	code = "{gui}.TextWrapped = true",
	fields = { gui = "expr|label|label" },
	doc = "Without this, a long sentence runs off the side and is cut off.",
	tags = "textwrapped wrap lines multiline" }

D{ id = "uiTypeface", cat = "ui", group = "Words", label = "set the typeface",
	head = "set the typeface of {gui} to {font}",
	code = "{gui}.FontFace = Font.fromEnum(Enum.Font.{font})",
	fields = { gui = "expr|label|label",
		font = "choice|GothamMedium|typeface|Gotham,GothamMedium,GothamBold,SourceSans,SourceSansBold,Code,Fantasy,Cartoon,Arcade" },
	doc = "FontFace is the current way to set a typeface, and it accepts " ..
		"weights the old Font property could not.",
	tags = "font typeface fontface style" }

D{ id = "uiAlignWords", cat = "ui", group = "Words", label = "line the words up",
	head = "line the words in {gui} up to the {side}",
	code = "{gui}.TextXAlignment = Enum.TextXAlignment.{side}",
	fields = { gui = "expr|label|label", side = "choice|Center|side|Left,Center,Right" },
	doc = "Where the text sits inside its label, left to right.",
	tags = "alignment align left right centre" }

D{ id = "uiTags", cat = "ui", group = "Words", label = "allow bold and colour tags",
	head = "let {gui} use bold and colour tags",
	code = "{gui}.RichText = true",
	fields = { gui = "expr|label|label" },
	doc = "Turns on tags inside the text itself, so `<b>go</b>` renders bold " ..
		"and `<font color='#ff0000'>` colours part of a line.",
	tags = "richtext bold italic colour markup" }

D{ id = "uiWordOutline", cat = "ui", group = "Words", label = "outline the words",
	head = "outline the words in {gui} in black",
	code = {
		"{gui}.TextStrokeTransparency = 0",
		"{gui}.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)",
	},
	fields = { gui = "expr|label|label" },
	doc = "A dark edge round the letters, which keeps text readable over a " ..
		"busy background.",
	tags = "textstroke outline readable shadow" }

-- buttons ---------------------------------------------------------------------
D{ id = "uiButton", cat = "ui", group = "Buttons", label = "make a button",
	head = 'make {name} = a button saying "{text}" inside {parent}',
	code = {
		'local {name} = Instance.new("TextButton")',
		"{name}.Size = UDim2.fromScale({w}, {h})",
		"{name}.BackgroundColor3 = Color3.fromRGB(70, 90, 140)",
		'{name}.Text = "{text}"',
		"{name}.TextColor3 = Color3.fromRGB(255, 255, 255)",
		"{name}.TextScaled = true",
		"{name}.Parent = {parent}",
	},
	fields = { name = "name|button|name", text = "str|Play|words",
		parent = "expr|panel|parent", w = "num|0.4|width", h = "num|0.15|height" },
	doc = "A TextButton is a label that can be clicked. Everything a label " ..
		"can do, it can do too.",
	tags = "textbutton button click press" }

D{ id = "uiImageButton", cat = "ui", group = "Buttons", label = "make a picture button",
	head = "make {name} = a button showing {asset} inside {parent}",
	code = {
		'local {name} = Instance.new("ImageButton")',
		"{name}.Size = UDim2.fromOffset(64, 64)",
		"{name}.BackgroundTransparency = 1",
		"{name}.Image = {asset}",
		"{name}.Parent = {parent}",
	},
	fields = { name = "name|button|name", asset = "expr|\"rbxassetid://0\"|image id",
		parent = "expr|panel|parent" },
	doc = "A clickable picture. Asset ids look like `rbxassetid://123456`.",
	tags = "imagebutton icon picture button" }

D{ id = "uiOnClick", cat = "ui", group = "Buttons", label = "on button clicked",
	head = "when {button} is clicked",
	code = "{button}.Activated:Connect(function()", tail = "end)",
	fields = { button = "expr|button|button" },
	slots = { { key = "body" } },
	doc = "Activated covers mouse, touch and gamepad in one event, which is " ..
		"why it is better than MouseButton1Click.",
	tags = "activated click press button tap" }

D{ id = "uiOnHover", cat = "ui", group = "Buttons", label = "on pointer over",
	head = "when the pointer moves onto {button}",
	code = "{button}.MouseEnter:Connect(function()", tail = "end)",
	fields = { button = "expr|button|button" },
	slots = { { key = "body" } },
	side = "client",
	doc = "Hover effects only make sense on a mouse, so give touch players a " ..
		"different clue as well.",
	tags = "mouseenter hover over highlight" }

D{ id = "uiOnLeave", cat = "ui", group = "Buttons", label = "on pointer away",
	head = "when the pointer leaves {button}",
	code = "{button}.MouseLeave:Connect(function()", tail = "end)",
	fields = { button = "expr|button|button" },
	slots = { { key = "body" } },
	side = "client",
	doc = "Pairs with `on pointer over` to put a hover effect back how it was.",
	tags = "mouseleave hover out reset" }

D{ id = "uiClickable", cat = "ui", group = "Buttons", label = "set clickable",
	head = "set {button} clickable to {value}",
	code = { "{button}.Active = {value}", "{button}.AutoButtonColor = {value}" },
	fields = { button = "expr|button|button", value = "choice|true|value|true,false" },
	doc = "Switches a button off without hiding it, and stops it lighting up " ..
		"when the pointer is over it.",
	tags = "active disable enable clickable" }

D{ id = "uiHideOnClick", cat = "ui", group = "Buttons", label = "close on click",
	head = "hide {gui} when {button} is clicked",
	code = {
		"{button}.Activated:Connect(function()",
		"\t{gui}.Visible = false",
		"end)",
	},
	fields = { button = "expr|closeButton|button", gui = "expr|panel|what to hide" },
	doc = "The whole of a close button, in one block.",
	tags = "close hide button dismiss" }

D{ id = "uiToggleOnClick", cat = "ui", group = "Buttons", label = "toggle on click",
	head = "show or hide {gui} when {button} is clicked",
	code = {
		"{button}.Activated:Connect(function()",
		"\t{gui}.Visible = not {gui}.Visible",
		"end)",
	},
	fields = { button = "expr|menuButton|button", gui = "expr|panel|what to toggle" },
	doc = "Opens a panel if it is shut and shuts it if it is open.",
	tags = "toggle open close menu button" }

-- pictures ---------------------------------------------------------------------
D{ id = "uiImage", cat = "ui", group = "Pictures", label = "make a picture",
	head = "make {name} = a picture of {asset} inside {parent}",
	code = {
		'local {name} = Instance.new("ImageLabel")',
		"{name}.Size = UDim2.fromOffset(64, 64)",
		"{name}.BackgroundTransparency = 1",
		"{name}.Image = {asset}",
		"{name}.Parent = {parent}",
	},
	fields = { name = "name|icon|name", asset = "expr|\"rbxassetid://0\"|image id",
		parent = "expr|panel|parent" },
	doc = "Shows an uploaded image. Upload yours in the Asset Manager to get " ..
		"an id.",
	tags = "imagelabel picture icon image" }

D{ id = "uiSetImage", cat = "ui", group = "Pictures", label = "change the picture",
	head = "set the picture in {gui} to {asset}",
	code = "{gui}.Image = {asset}",
	fields = { gui = "expr|icon|picture", asset = "expr|\"rbxassetid://0\"|image id" },
	doc = "Swapping the id swaps the picture, which is how icons change state.",
	tags = "image change swap icon" }

D{ id = "uiTintImage", cat = "ui", group = "Pictures", label = "tint the picture",
	head = "tint the picture in {gui} red {r} green {g} blue {b}",
	code = "{gui}.ImageColor3 = Color3.fromRGB({r}, {g}, {b})",
	fields = { gui = "expr|icon|picture", r = "num|255|red", g = "num|255|green",
		b = "num|255|blue" },
	doc = "Multiplies the picture by a colour, so a white icon can be any " ..
		"colour without uploading it again.",
	tags = "imagecolor tint colour icon" }

D{ id = "uiFadeImage", cat = "ui", group = "Pictures", label = "fade the picture",
	head = "set how see-through the picture in {gui} is to {value}",
	code = "{gui}.ImageTransparency = {value}",
	fields = { gui = "expr|icon|picture", value = "num|0.5|amount" },
	doc = "Separate from the background transparency, so a picture can fade " ..
		"while its panel stays.",
	tags = "imagetransparency fade alpha picture" }

D{ id = "uiImageFit", cat = "ui", group = "Pictures", label = "set how it fits",
	head = "make the picture in {gui} {mode}",
	code = "{gui}.ScaleType = Enum.ScaleType.{mode}",
	fields = { gui = "expr|icon|picture",
		mode = "choice|Fit|fit|Fit,Stretch,Crop,Tile,Slice" },
	doc = "Fit keeps the shape and leaves gaps, Stretch distorts, Crop fills " ..
		"and cuts. Slice is for stretchy panel borders.",
	tags = "scaletype fit stretch crop tile" }

-- layout ------------------------------------------------------------------------
D{ id = "uiStack", cat = "ui", group = "Layout", label = "stack the contents",
	head = "stack everything inside {gui} {dir}, {gap} pixels apart",
	code = {
		"do",
		'\tlocal layout = Instance.new("UIListLayout")',
		"\tlayout.FillDirection = Enum.FillDirection.{dir}",
		"\tlayout.Padding = UDim.new(0, {gap})",
		"\tlayout.SortOrder = Enum.SortOrder.LayoutOrder",
		"\tlayout.Parent = {gui}",
		"end",
	},
	fields = { gui = "expr|panel|object", dir = "choice|Vertical|direction|Vertical,Horizontal",
		gap = "num|6|gap" },
	doc = "A UIListLayout puts children in a row or a column automatically, " ..
		"so you never set their positions by hand again.",
	tags = "uilistlayout stack list row column layout" }

D{ id = "uiGrid", cat = "ui", group = "Layout", label = "arrange in a grid",
	head = "arrange everything inside {gui} in a grid of {w} by {h} pixel cells",
	code = {
		"do",
		'\tlocal grid = Instance.new("UIGridLayout")',
		"\tgrid.CellSize = UDim2.fromOffset({w}, {h})",
		"\tgrid.CellPadding = UDim2.fromOffset({gap}, {gap})",
		"\tgrid.SortOrder = Enum.SortOrder.LayoutOrder",
		"\tgrid.Parent = {gui}",
		"end",
	},
	fields = { gui = "expr|panel|object", w = "num|80|cell width",
		h = "num|80|cell height", gap = "num|6|gap" },
	doc = "Inventories and shop windows are grids. Cells wrap onto the next " ..
		"row on their own.",
	tags = "uigridlayout grid inventory cells" }

D{ id = "uiOrder", cat = "ui", group = "Layout", label = "set the order in a layout",
	head = "put {gui} at position {order} in its layout",
	code = "{gui}.LayoutOrder = {order}",
	fields = { gui = "expr|panel|object", order = "num|1|position" },
	doc = "Lower numbers come first. Only matters inside a list or grid " ..
		"layout that is sorting by order.",
	tags = "layoutorder order sort position" }

D{ id = "uiCentreContents", cat = "ui", group = "Layout", label = "centre the contents",
	head = "centre everything inside {gui}",
	code = {
		"do",
		'\tlocal layout = {gui}:FindFirstChildOfClass("UIListLayout")',
		"\tif layout then",
		"\t\tlayout.HorizontalAlignment = Enum.HorizontalAlignment.Center",
		"\t\tlayout.VerticalAlignment = Enum.VerticalAlignment.Center",
		"\tend",
		"end",
	},
	fields = { gui = "expr|panel|object" },
	doc = "Centres the children of an object that already has a list layout, " ..
		"and quietly does nothing if it has not.",
	tags = "centre align middle layout" }

D{ id = "uiSizeLimit", cat = "ui", group = "Layout", label = "limit the size",
	head = "keep {gui} between {min} and {max} pixels wide",
	code = {
		"do",
		'\tlocal limit = Instance.new("UISizeConstraint")',
		"\tlimit.MinSize = Vector2.new({min}, 0)",
		"\tlimit.MaxSize = Vector2.new({max}, math.huge)",
		"\tlimit.Parent = {gui}",
		"end",
	},
	fields = { gui = "expr|panel|object", min = "num|120|smallest", max = "num|480|largest" },
	doc = "Stops a fraction-sized panel becoming unreadably small on a phone " ..
		"or absurdly wide on a monitor.",
	tags = "uisizeconstraint min max width limit" }

D{ id = "uiScaleContents", cat = "ui", group = "Layout", label = "scale the contents",
	head = "scale everything inside {gui} by {factor}",
	code = {
		"do",
		'\tlocal scale = Instance.new("UIScale")',
		"\tscale.Scale = {factor}",
		"\tscale.Parent = {gui}",
		"end",
	},
	fields = { gui = "expr|panel|object", factor = "num|1|factor" },
	doc = "Multiplies the size of everything inside at once. Useful for a " ..
		"whole-interface zoom or a press-down effect.",
	tags = "uiscale zoom scale shrink grow" }

-- motion --------------------------------------------------------------------------
D{ id = "uiSlideTo", cat = "ui", group = "Motion", label = "slide to",
	head = "slide {gui} to {x}, {y} over {time} seconds",
	code = "TweenService:Create({gui}, TweenInfo.new({time}), " ..
		"{ Position = UDim2.fromScale({x}, {y}) }):Play()",
	fields = { gui = "expr|panel|object", x = "num|0.5|x", y = "num|0.5|y",
		time = "num|0.3|seconds" },
	needs = { "TweenService" },
	doc = "Roblox fills in every frame between. Sliding a menu in beats " ..
		"making it appear.",
	tags = "tween slide move animate position" }

D{ id = "uiGrowTo", cat = "ui", group = "Motion", label = "grow to",
	head = "grow {gui} to {w} by {h} over {time} seconds",
	code = "TweenService:Create({gui}, TweenInfo.new({time}), " ..
		"{ Size = UDim2.fromScale({w}, {h}) }):Play()",
	fields = { gui = "expr|panel|object", w = "num|0.5|width", h = "num|0.3|height",
		time = "num|0.3|seconds" },
	needs = { "TweenService" },
	doc = "Animates a size change rather than snapping to it.",
	tags = "tween size grow shrink animate" }

D{ id = "uiFadeOut", cat = "ui", group = "Motion", label = "fade out",
	head = "fade {gui} out over {time} seconds",
	code = "TweenService:Create({gui}, TweenInfo.new({time}), " ..
		"{ BackgroundTransparency = 1 }):Play()",
	fields = { gui = "expr|panel|object", time = "num|0.4|seconds" },
	needs = { "TweenService" },
	doc = "Fades the background only. Text and pictures have their own " ..
		"transparency, so fade those too if you want the whole thing gone.",
	tags = "tween fade out transparency hide" }

D{ id = "uiFadeIn", cat = "ui", group = "Motion", label = "fade in",
	head = "fade {gui} in over {time} seconds",
	code = {
		"{gui}.BackgroundTransparency = 1",
		"{gui}.Visible = true",
		"TweenService:Create({gui}, TweenInfo.new({time}), " ..
			"{ BackgroundTransparency = {to} }):Play()",
	},
	fields = { gui = "expr|panel|object", time = "num|0.4|seconds", to = "num|0|end amount" },
	needs = { "TweenService" },
	doc = "Makes it visible first, then fades it up from nothing.",
	tags = "tween fade in appear show" }

D{ id = "uiPopIn", cat = "ui", group = "Motion", label = "pop in",
	head = "pop {gui} in over {time} seconds",
	code = {
		"{gui}.Size = UDim2.fromScale(0, 0)",
		"{gui}.Visible = true",
		"TweenService:Create({gui}, TweenInfo.new({time}, Enum.EasingStyle.Back, " ..
			"Enum.EasingDirection.Out), { Size = UDim2.fromScale({w}, {h}) }):Play()",
	},
	fields = { gui = "expr|panel|object", time = "num|0.35|seconds",
		w = "num|0.4|width", h = "num|0.3|height" },
	needs = { "TweenService" },
	doc = "Grows from nothing with a slight overshoot. The Back easing style " ..
		"is what makes it feel springy.",
	tags = "tween pop scale bounce appear" }

D{ id = "uiSetBar", cat = "ui", group = "Motion", label = "set a bar",
	head = "fill the bar {gui} to {fraction} of the way",
	code = "{gui}.Size = UDim2.fromScale(math.clamp({fraction}, 0, 1), 1)",
	fields = { gui = "expr|fill|bar", fraction = "expr|health / maxHealth|fraction" },
	doc = "A bar is one box inside another with the outer one clipping. The " ..
		"clamp keeps it from overshooting when health goes past its maximum.",
	tags = "bar progress health fill meter" }

D{ id = "uiSlideBar", cat = "ui", group = "Motion", label = "slide a bar",
	head = "slide the bar {gui} to {fraction} over {time} seconds",
	code = "TweenService:Create({gui}, TweenInfo.new({time}), " ..
		"{ Size = UDim2.fromScale(math.clamp({fraction}, 0, 1), 1) }):Play()",
	fields = { gui = "expr|fill|bar", fraction = "expr|health / maxHealth|fraction",
		time = "num|0.25|seconds" },
	needs = { "TweenService" },
	doc = "The same as setting a bar, but it slides. Damage feels heavier " ..
		"when the bar catches up a moment later.",
	tags = "bar progress tween health smooth" }

-- typing --------------------------------------------------------------------------
D{ id = "uiTextBox", cat = "ui", group = "Typing", label = "make a typing box",
	head = 'make {name} = a typing box inside {parent}, showing "{hint}" when empty',
	code = {
		'local {name} = Instance.new("TextBox")',
		"{name}.Size = UDim2.fromScale(0.6, 0.1)",
		"{name}.ClearTextOnFocus = false",
		'{name}.PlaceholderText = "{hint}"',
		'{name}.Text = ""',
		"{name}.Parent = {parent}",
	},
	fields = { name = "name|box|name", parent = "expr|panel|parent",
		hint = "str|type here|hint" },
	doc = "A TextBox is a label the player can type into. Clearing on focus " ..
		"is usually annoying, so it is off here.",
	tags = "textbox input typing entry field" }

D{ id = "uiOnTyped", cat = "ui", group = "Typing", label = "on finished typing",
	head = "when the player finishes typing in {box}, with {entered}",
	code = "{box}.FocusLost:Connect(function({entered})", tail = "end)",
	fields = { box = "expr|box|box", entered = "name|enterPressed|entered" },
	slots = { { key = "body" } },
	doc = "Fires when they click away or press Enter. The value tells you " ..
		"which of the two it was, so you can ignore a stray click.",
	tags = "focuslost typing enter submit input" }

D{ id = "uiGetTyped", cat = "ui", group = "Typing", label = "what was typed",
	head = "make {name} = what was typed in {box}",
	code = "local {name} = {box}.Text",
	fields = { name = "name|typed|name", box = "expr|box|box" },
	doc = "Always text, even when it looks like a number -- put it through " ..
		"`text to number` before doing maths with it.",
	tags = "text read input typed value" }

D{ id = "uiClearBox", cat = "ui", group = "Typing", label = "empty a typing box",
	head = "empty the typing box {box}",
	code = '{box}.Text = ""',
	fields = { box = "expr|box|box" },
	doc = "Clears whatever was typed, usually just after you have read it.",
	tags = "clear empty reset input" }

-- roblox's own interface -------------------------------------------------------------
D{ id = "uiHideCore", cat = "ui", group = "Roblox's own", label = "hide part of Roblox's interface",
	head = "hide the {part} that Roblox draws",
	code = "StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.{part}, false)",
	fields = { part = "choice|PlayerList|part|PlayerList,Backpack,Chat,Health,EmotesMenu,All" },
	needs = { "StarterGui" },
	side = "client",
	doc = "Turns off the built-in player list, backpack, chat or health bar " ..
		"so your own interface can take over.",
	tags = "coregui hide playerlist backpack chat health" }

D{ id = "uiNotify", cat = "ui", group = "Roblox's own", label = "send a notification",
	head = 'show a notification titled "{title}" saying "{text}"',
	code = {
		'StarterGui:SetCore("SendNotification", {',
		'\tTitle = "{title}",',
		'\tText = "{text}",',
		"\tDuration = {seconds},",
		"})",
	},
	fields = { title = "str|Well done|title", text = "str|You found a coin|message",
		seconds = "num|4|seconds" },
	needs = { "StarterGui" },
	side = "client",
	doc = "Uses Roblox's own notification popup, which needs no interface of " ..
		"your own at all.",
	tags = "notification popup message toast alert" }

--=============================================================================
-- CAMERA AND LIGHT
--=============================================================================

D{ id = "camGet", cat = "camera", group = "The camera", label = "the camera",
	head = "make {name} = the camera",
	code = "local {name} = workspace.CurrentCamera",
	fields = { name = "name|camera|name" },
	side = "client",
	doc = "Every player has their own camera, so this only means anything in " ..
		"a LocalScript.",
	tags = "camera currentcamera view" }

D{ id = "camTakeOver", cat = "camera", group = "The camera", label = "take control",
	head = "take control of the camera",
	code = "workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable",
	side = "client",
	doc = "Stops Roblox moving the camera so your own code can. Nothing else " ..
		"you do to the camera sticks until you have done this.",
	tags = "scriptable camera control cutscene" }

D{ id = "camGiveBack", cat = "camera", group = "The camera", label = "give the camera back",
	head = "give the camera back to the player",
	code = "workspace.CurrentCamera.CameraType = Enum.CameraType.Custom",
	side = "client",
	doc = "Returns to the normal follow-the-character camera. Always do this " ..
		"at the end of a cutscene.",
	tags = "camera custom restore normal" }

D{ id = "camPutAt", cat = "camera", group = "The camera", label = "put the camera at",
	head = "put the camera at ({x}, {y}, {z})",
	code = "workspace.CurrentCamera.CFrame = CFrame.new({x}, {y}, {z})",
	fields = { x = "expr|0|x", y = "expr|20|y", z = "expr|0|z" },
	side = "client",
	doc = "Moves the camera without turning it. Needs control taken first.",
	tags = "camera position move place" }

D{ id = "camLookAt", cat = "camera", group = "The camera", label = "look at",
	head = "put the camera at ({x}, {y}, {z}) looking at {target}",
	code = "workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new({x}, {y}, {z}), {target})",
	fields = { x = "expr|0|x", y = "expr|20|y", z = "expr|20|z",
		target = "expr|part.Position|target position" },
	side = "client",
	doc = "`CFrame.lookAt` builds a position and a facing in one go, which is " ..
		"far easier than working out the angles.",
	tags = "camera lookat aim face target" }

D{ id = "camFollow", cat = "camera", group = "The camera", label = "follow something",
	head = "make the camera follow {subject}",
	code = "workspace.CurrentCamera.CameraSubject = {subject}",
	fields = { subject = "expr|humanoid|subject" },
	side = "client",
	doc = "Normally the player's own Humanoid. Point it at another one to " ..
		"watch someone else, or at a part for a fixed view.",
	tags = "camerasubject follow spectate watch" }

D{ id = "camWideness", cat = "camera", group = "The camera", label = "set how wide it sees",
	head = "set how wide the camera sees to {n} degrees",
	code = "workspace.CurrentCamera.FieldOfView = {n}",
	fields = { n = "num|70|degrees" },
	side = "client",
	doc = "70 is normal. Higher feels fast and fish-eyed; lower feels zoomed " ..
		"in and tense.",
	tags = "fieldofview fov zoom wide" }

D{ id = "camZoomLimits", cat = "camera", group = "The camera", label = "limit the zoom",
	head = "keep the camera between {min} and {max} studs from {player}",
	code = {
		"{player}.CameraMinZoomDistance = {min}",
		"{player}.CameraMaxZoomDistance = {max}",
	},
	fields = { player = "expr|player|player", min = "num|8|closest", max = "num|30|furthest" },
	doc = "Setting both to the same number locks the zoom exactly there.",
	tags = "zoom distance camera limit" }

D{ id = "camFirstPerson", cat = "camera", group = "The camera", label = "lock to first person",
	head = "lock {player} into first person",
	code = "{player}.CameraMode = Enum.CameraMode.LockFirstPerson",
	fields = { player = "expr|player|player" },
	doc = "The player can no longer zoom out. Pair it with hiding their own " ..
		"body parts if you do not want to see them.",
	tags = "firstperson camera mode lock" }

D{ id = "camThirdPerson", cat = "camera", group = "The camera", label = "allow third person",
	head = "let {player} zoom out again",
	code = "{player}.CameraMode = Enum.CameraMode.Classic",
	fields = { player = "expr|player|player" },
	doc = "Undoes a first person lock.",
	tags = "thirdperson camera classic zoom" }

D{ id = "camGlideTo", cat = "camera", group = "Camera motion", label = "glide the camera",
	head = "glide the camera to ({x}, {y}, {z}) over {time} seconds",
	code = "TweenService:Create(workspace.CurrentCamera, TweenInfo.new({time}, " ..
		"Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), " ..
		"{ CFrame = CFrame.new({x}, {y}, {z}) }):Play()",
	fields = { x = "expr|0|x", y = "expr|20|y", z = "expr|0|z", time = "num|2|seconds" },
	needs = { "TweenService" },
	side = "client",
	doc = "The backbone of a cutscene: take control, glide somewhere, wait, " ..
		"glide back, give the camera back.",
	tags = "camera tween cutscene glide smooth" }

D{ id = "camShake", cat = "camera", group = "Camera motion", label = "shake the camera",
	head = "shake the camera for {time} seconds, {strength} strong",
	code = {
		"do",
		"\tlocal camera = workspace.CurrentCamera",
		"\tlocal until_ = os.clock() + {time}",
		"\twhile os.clock() < until_ do",
		"\t\tlocal nudge = Vector3.new(",
		"\t\t\t(math.random() - 0.5) * {strength},",
		"\t\t\t(math.random() - 0.5) * {strength}, 0)",
		"\t\tcamera.CFrame = camera.CFrame * CFrame.new(nudge)",
		"\t\ttask.wait()",
		"\tend",
		"end",
	},
	fields = { time = "num|0.4|seconds", strength = "num|0.5|strength" },
	side = "client",
	doc = "Nudges the camera about for a moment. Small numbers go a long way " ..
		"-- 0.5 is already a hard hit.",
	tags = "shake camera impact explosion feedback" }

-- lighting ---------------------------------------------------------------------
D{ id = "lightBright", cat = "camera", group = "Lighting", label = "set the brightness",
	head = "set how bright the sun is to {n}",
	code = "Lighting.Brightness = {n}",
	fields = { n = "num|2|brightness" },
	needs = { "Lighting" },
	doc = "How strong direct sunlight is. 2 is the default; 0 leaves only " ..
		"ambient light.",
	tags = "brightness sun light lighting" }

D{ id = "lightTime", cat = "camera", group = "Lighting", label = "set the time of day",
	head = "set the time of day to {n} o'clock",
	code = "Lighting.ClockTime = {n}",
	fields = { n = "num|14|hour" },
	needs = { "Lighting" },
	doc = "0 to 24, and decimals work -- 6.5 is half past six. 12 is noon, " ..
		"0 is midnight.",
	tags = "clocktime day night time sun" }

D{ id = "lightShadowColour", cat = "camera", group = "Lighting", label = "set the shadow colour",
	head = "set the colour of shadows to red {r} green {g} blue {b}",
	code = "Lighting.Ambient = Color3.fromRGB({r}, {g}, {b})",
	fields = { r = "num|60|red", g = "num|60|green", b = "num|80|blue" },
	needs = { "Lighting" },
	doc = "Ambient is the light that reaches places the sun does not. Cool " ..
		"blues read as night, warm browns as indoors.",
	tags = "ambient shadow colour mood lighting" }

D{ id = "lightOutdoor", cat = "camera", group = "Lighting", label = "set the outdoor light",
	head = "set the outdoor light to red {r} green {g} blue {b}",
	code = "Lighting.OutdoorAmbient = Color3.fromRGB({r}, {g}, {b})",
	fields = { r = "num|130|red", g = "num|140|green", b = "num|160|blue" },
	needs = { "Lighting" },
	doc = "The same idea as ambient, but only where the sky can be seen.",
	tags = "outdoorambient sky ambient lighting" }

D{ id = "lightFog", cat = "camera", group = "Lighting", label = "set the fog",
	head = "make fog start {a} studs away and be solid by {b}",
	code = { "Lighting.FogStart = {a}", "Lighting.FogEnd = {b}" },
	fields = { a = "num|50|start", b = "num|300|end" },
	needs = { "Lighting" },
	doc = "Hides distance, which sets a mood and can help a big place run " ..
		"faster.",
	tags = "fog distance mist atmosphere" }

D{ id = "lightFogColour", cat = "camera", group = "Lighting", label = "set the fog colour",
	head = "colour the fog red {r} green {g} blue {b}",
	code = "Lighting.FogColor = Color3.fromRGB({r}, {g}, {b})",
	fields = { r = "num|200|red", g = "num|205|green", b = "num|215|blue" },
	needs = { "Lighting" },
	doc = "Match it roughly to the sky, or the horizon will look like a wall.",
	tags = "fogcolor fog colour horizon" }

D{ id = "lightShadows", cat = "camera", group = "Lighting", label = "turn shadows on or off",
	head = "set shadows to {value}",
	code = "Lighting.GlobalShadows = {value}",
	fields = { value = "choice|true|value|true,false" },
	needs = { "Lighting" },
	doc = "Shadows cost performance. Turning them off is a blunt but " ..
		"effective way to help weaker devices.",
	tags = "shadows globalshadows performance lighting" }

D{ id = "lightExposure", cat = "camera", group = "Lighting", label = "set the exposure",
	head = "set the exposure to {n}",
	code = "Lighting.ExposureCompensation = {n}",
	fields = { n = "num|0|exposure" },
	needs = { "Lighting" },
	doc = "Brightens or darkens the whole picture after everything else is " ..
		"drawn, the way a camera's exposure does.",
	tags = "exposure brightness tone lighting" }

D{ id = "lightDayCycle", cat = "camera", group = "Lighting", label = "run a day cycle",
	head = "run a day and night cycle taking {minutes} minutes",
	code = {
		"task.spawn(function()",
		"\twhile true do",
		"\t\ttask.wait(1)",
		"\t\tLighting.ClockTime = (Lighting.ClockTime + 24 / ({minutes} * 60)) % 24",
		"\tend",
		"end)",
	},
	fields = { minutes = "num|10|minutes" },
	needs = { "Lighting" },
	doc = "Advances the clock a little every second, wrapping round at " ..
		"midnight. Run it on the server so everyone sees the same sky.",
	tags = "day night cycle time lighting loop" }

-- effects -----------------------------------------------------------------------
D{ id = "fxBlur", cat = "camera", group = "Effects", label = "blur the screen",
	head = "blur the screen by {n}",
	code = {
		"do",
		'\tlocal blur = Lighting:FindFirstChild("ScreenBlur") or Instance.new("BlurEffect")',
		'\tblur.Name = "ScreenBlur"',
		"\tblur.Size = {n}",
		"\tblur.Parent = Lighting",
		"end",
	},
	fields = { n = "num|12|amount" },
	needs = { "Lighting" },
	doc = "Finds the blur if it is already there and makes one if it is not, " ..
		"so calling it twice does not stack up effects. 0 turns it off.",
	tags = "blur effect pause menu focus" }

D{ id = "fxGlow", cat = "camera", group = "Effects", label = "make bright things glow",
	head = "make bright things glow, {n} strong",
	code = {
		"do",
		'\tlocal bloom = Lighting:FindFirstChild("ScreenBloom") or Instance.new("BloomEffect")',
		'\tbloom.Name = "ScreenBloom"',
		"\tbloom.Intensity = {n}",
		"\tbloom.Threshold = {threshold}",
		"\tbloom.Parent = Lighting",
		"end",
	},
	fields = { n = "num|1|strength", threshold = "num|0.9|threshold" },
	needs = { "Lighting" },
	doc = "Bloom spills light out of bright areas. The threshold decides how " ..
		"bright something has to be before it glows.",
	tags = "bloom glow bright effect neon" }

D{ id = "fxTint", cat = "camera", group = "Effects", label = "tint the screen",
	head = "tint the whole screen red {r} green {g} blue {b}",
	code = {
		"do",
		'\tlocal tint = Lighting:FindFirstChild("ScreenTint") or Instance.new("ColorCorrectionEffect")',
		'\ttint.Name = "ScreenTint"',
		"\ttint.TintColor = Color3.fromRGB({r}, {g}, {b})",
		"\ttint.Parent = Lighting",
		"end",
	},
	fields = { r = "num|255|red", g = "num|230|green", b = "num|210|blue" },
	needs = { "Lighting" },
	doc = "Colours everything on screen. A red tint for damage and a green " ..
		"one for poison cost nothing to add.",
	tags = "colorcorrection tint screen damage effect" }

D{ id = "fxSaturation", cat = "camera", group = "Effects", label = "set the colourfulness",
	head = "set how colourful the screen is to {n}",
	code = {
		"do",
		'\tlocal grade = Lighting:FindFirstChild("ScreenTint") or Instance.new("ColorCorrectionEffect")',
		'\tgrade.Name = "ScreenTint"',
		"\tgrade.Saturation = {n}",
		"\tgrade.Parent = Lighting",
		"end",
	},
	fields = { n = "num|0|amount" },
	needs = { "Lighting" },
	doc = "0 leaves it alone, -1 is black and white, 1 is garish. Draining " ..
		"the colour is a cheap way to show a player is hurt.",
	tags = "saturation colour grade greyscale effect" }

D{ id = "fxSunRays", cat = "camera", group = "Effects", label = "add sun rays",
	head = "add sun rays, {n} strong",
	code = {
		"do",
		'\tlocal rays = Lighting:FindFirstChild("SunRays") or Instance.new("SunRaysEffect")',
		'\trays.Name = "SunRays"',
		"\trays.Intensity = {n}",
		"\trays.Parent = Lighting",
		"end",
	},
	fields = { n = "num|0.25|strength" },
	needs = { "Lighting" },
	doc = "Light shafts spilling from the sun when you look towards it.",
	tags = "sunrays godrays light shafts effect" }

D{ id = "fxDepthOfField", cat = "camera", group = "Effects", label = "blur the distance",
	head = "blur anything past {distance} studs",
	code = {
		"do",
		'\tlocal dof = Lighting:FindFirstChild("Distance") or Instance.new("DepthOfFieldEffect")',
		'\tdof.Name = "Distance"',
		"\tdof.FarIntensity = {n}",
		"\tdof.FocusDistance = {distance}",
		"\tdof.Parent = Lighting",
		"end",
	},
	fields = { distance = "num|60|studs", n = "num|0.5|strength" },
	needs = { "Lighting" },
	doc = "Keeps what is near sharp and softens the rest, the way a real " ..
		"lens does.",
	tags = "depthoffield blur distance focus effect" }

D{ id = "fxHaze", cat = "camera", group = "Effects", label = "set the haze",
	head = "set the air haze to {n}",
	code = {
		"do",
		'\tlocal air = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")',
		"\tair.Haze = {n}",
		"\tair.Density = {density}",
		"\tair.Parent = Lighting",
		"end",
	},
	fields = { n = "num|1|haze", density = "num|0.35|density" },
	needs = { "Lighting" },
	doc = "Atmosphere is the modern replacement for fog and looks far better " ..
		"at a distance. Haze is how milky the air is.",
	tags = "atmosphere haze density air fog" }

-- glow ---------------------------------------------------------------------------
D{ id = "glowOutline", cat = "camera", group = "Glow", label = "outline an object",
	head = "outline {obj} in red {r} green {g} blue {b}",
	code = {
		"do",
		'\tlocal glow = Instance.new("Highlight")',
		"\t\tglow.FillColor = Color3.fromRGB({r}, {g}, {b})",
		"\tglow.OutlineColor = Color3.fromRGB({r}, {g}, {b})",
		"\tglow.FillTransparency = {fill}",
		"\tglow.Adornee = {obj}",
		"\tglow.Parent = {obj}",
		"end",
	},
	fields = { obj = "expr|part|object", r = "num|255|red", g = "num|200|green",
		b = "num|80|blue", fill = "num|0.7|fill see-through" },
	doc = "A Highlight draws through walls, which makes it the right way to " ..
		"show a quest target or a held object.",
	tags = "highlight outline glow selection through walls" }

D{ id = "glowRemove", cat = "camera", group = "Glow", label = "remove an outline",
	head = "remove any outline from {obj}",
	code = {
		"do",
		'\tlocal glow = {obj}:FindFirstChildOfClass("Highlight")',
		"\tif glow then",
		"\t\tglow:Destroy()",
		"\tend",
		"end",
	},
	fields = { obj = "expr|part|object" },
	doc = "Takes the highlight off again, and shrugs if there was not one.",
	tags = "highlight remove clear outline" }

D{ id = "glowLight", cat = "camera", group = "Glow", label = "put a light inside",
	head = "put a light inside {obj}, {range} studs of red {r} green {g} blue {b}",
	code = {
		"do",
		'\tlocal light = Instance.new("PointLight")',
		"\tlight.Range = {range}",
		"\tlight.Brightness = {brightness}",
		"\tlight.Color = Color3.fromRGB({r}, {g}, {b})",
		"\tlight.Parent = {obj}",
		"end",
	},
	fields = { obj = "expr|part|object", range = "num|16|range", brightness = "num|2|brightness",
		r = "num|255|red", g = "num|220|green", b = "num|170|blue" },
	doc = "A PointLight shines in every direction from the middle of the part.",
	tags = "pointlight lamp light glow torch" }

D{ id = "glowSpot", cat = "camera", group = "Glow", label = "put a spotlight inside",
	head = "put a spotlight inside {obj}, {range} studs at {angle} degrees",
	code = {
		"do",
		'\tlocal light = Instance.new("SpotLight")',
		"\tlight.Range = {range}",
		"\tlight.Angle = {angle}",
		"\tlight.Face = Enum.NormalId.{face}",
		"\tlight.Parent = {obj}",
		"end",
	},
	fields = { obj = "expr|part|object", range = "num|24|range", angle = "num|60|angle",
		face = "choice|Front|face|Front,Back,Top,Bottom,Left,Right" },
	doc = "A cone of light pointing out of one face. Torches and street " ..
		"lamps are spotlights.",
	tags = "spotlight cone torch lamp light" }

D{ id = "glowNeon", cat = "camera", group = "Glow", label = "make it glow",
	head = "make {obj} glow",
	code = "{obj}.Material = Enum.Material.Neon",
	fields = { obj = "expr|part|object" },
	doc = "Neon parts light themselves up. Combined with bloom they are how " ..
		"most glowing things in Roblox are made.",
	tags = "neon material glow bright" }

D{ id = "particleMake", cat = "camera", group = "Glow", label = "add particles",
	head = "make {name} = particles on {obj}, {rate} a second",
	code = {
		'local {name} = Instance.new("ParticleEmitter")',
		"{name}.Rate = {rate}",
		"{name}.Lifetime = NumberRange.new(0.4, 1)",
		"{name}.Speed = NumberRange.new(3, 6)",
		"{name}.Parent = {obj}",
	},
	fields = { name = "name|sparks|name", obj = "expr|part|object", rate = "num|20|per second" },
	doc = "Particles pour out of the part they are inside. A rate of 0 means " ..
		"none until you ask for a burst.",
	tags = "particleemitter particles sparks effect" }

D{ id = "particleBurst", cat = "camera", group = "Glow", label = "burst particles",
	head = "fire {n} particles from {emitter} right now",
	code = "{emitter}:Emit({n})",
	fields = { emitter = "expr|sparks|emitter", n = "num|30|how many" },
	doc = "One burst, whatever the rate is set to. Perfect for an impact or " ..
		"a pickup.",
	tags = "emit burst particles impact" }

D{ id = "particleSwitch", cat = "camera", group = "Glow", label = "turn particles on or off",
	head = "set {emitter} running to {value}",
	code = "{emitter}.Enabled = {value}",
	fields = { emitter = "expr|sparks|emitter", value = "choice|true|value|true,false" },
	doc = "Stops new particles without removing the ones already in the air.",
	tags = "enabled particles stop start" }

D{ id = "beamBetween", cat = "camera", group = "Glow", label = "draw a beam",
	head = "draw a beam from {a} to {b}",
	code = {
		"do",
		'\tlocal from = Instance.new("Attachment")',
		"\tfrom.Parent = {a}",
		'\tlocal to = Instance.new("Attachment")',
		"\tto.Parent = {b}",
		'\tlocal beam = Instance.new("Beam")',
		"\tbeam.Attachment0 = from",
		"\tbeam.Attachment1 = to",
		"\tbeam.Width0 = {width}",
		"\tbeam.Width1 = {width}",
		"\tbeam.Parent = {a}",
		"end",
	},
	fields = { a = "expr|partA|from", b = "expr|partB|to", width = "num|0.4|width" },
	doc = "Beams stretch between two attachments, so both parts get one. " ..
		"Lasers, ziplines and tethers are all beams.",
	tags = "beam laser link attachment line" }

D{ id = "trailBehind", cat = "camera", group = "Glow", label = "leave a trail",
	head = "leave a trail behind {obj} lasting {time} seconds",
	code = {
		"do",
		'\tlocal top = Instance.new("Attachment")',
		"\ttop.Position = Vector3.new(0, {spread}, 0)",
		"\ttop.Parent = {obj}",
		'\tlocal bottom = Instance.new("Attachment")',
		"\tbottom.Position = Vector3.new(0, -{spread}, 0)",
		"\tbottom.Parent = {obj}",
		'\tlocal trail = Instance.new("Trail")',
		"\ttrail.Attachment0 = top",
		"\ttrail.Attachment1 = bottom",
		"\ttrail.Lifetime = {time}",
		"\ttrail.Parent = {obj}",
		"end",
	},
	fields = { obj = "expr|part|object", time = "num|0.5|seconds", spread = "num|1|width" },
	doc = "A Trail needs two attachments to know how wide the ribbon is. " ..
		"Swords and fast-moving parts wear these.",
	tags = "trail ribbon motion streak attachment" }

--=============================================================================
-- SOUND
--=============================================================================

D{ id = "soundMake", cat = "sound", group = "Playing", label = "make a sound",
	head = "make {name} = a sound of {asset} inside {parent}",
	code = {
		'local {name} = Instance.new("Sound")',
		"{name}.SoundId = {asset}",
		"{name}.Volume = {volume}",
		"{name}.Parent = {parent}",
	},
	fields = { name = "name|sound|name", asset = "expr|\"rbxassetid://0\"|sound id",
		parent = "expr|script.Parent|parent", volume = "num|0.5|volume" },
	doc = "Where a sound lives decides who hears it: inside a part it comes " ..
		"from that place in the world, inside SoundService everyone hears it flat.",
	tags = "sound audio make new soundid" }

D{ id = "soundPlay", cat = "sound", group = "Playing", label = "play",
	head = "play {sound}",
	code = "{sound}:Play()",
	fields = { sound = "expr|sound|sound" },
	doc = "Starts from the beginning, or from wherever you left it if it was " ..
		"paused.",
	tags = "play start sound audio" }

D{ id = "soundStop", cat = "sound", group = "Playing", label = "stop",
	head = "stop {sound}",
	code = "{sound}:Stop()",
	fields = { sound = "expr|sound|sound" },
	doc = "Stops and rewinds to the start.",
	tags = "stop end sound audio" }

D{ id = "soundPause", cat = "sound", group = "Playing", label = "pause",
	head = "pause {sound}",
	code = "{sound}:Pause()",
	fields = { sound = "expr|sound|sound" },
	doc = "Holds it where it is, so playing again carries on from there.",
	tags = "pause hold sound audio" }

D{ id = "soundResume", cat = "sound", group = "Playing", label = "carry on",
	head = "carry on playing {sound}",
	code = "{sound}:Resume()",
	fields = { sound = "expr|sound|sound" },
	doc = "Continues a paused sound without starting it over.",
	tags = "resume continue sound audio" }

D{ id = "soundOneShot", cat = "sound", group = "Playing", label = "play once and tidy up",
	head = "play {asset} once from {parent}",
	code = {
		"do",
		'\tlocal sound = Instance.new("Sound")',
		"\tsound.SoundId = {asset}",
		"\tsound.Volume = {volume}",
		"\tsound.Parent = {parent}",
		"\tsound:Play()",
		"\tsound.Ended:Connect(function()",
		"\t\tsound:Destroy()",
		"\tend)",
		"end",
	},
	fields = { asset = "expr|\"rbxassetid://0\"|sound id", parent = "expr|script.Parent|parent",
		volume = "num|0.5|volume" },
	doc = "Makes the sound, plays it, and removes it when it finishes. The " ..
		"right way to do hit noises and pickups without littering.",
	tags = "oneshot play once destroy cleanup sound" }

D{ id = "soundRandom", cat = "sound", group = "Playing", label = "play a random one",
	head = "play a random sound from {list} on {parent}",
	code = {
		"do",
		'\tlocal sound = Instance.new("Sound")',
		"\tsound.SoundId = {list}[math.random(1, #{list})]",
		"\tsound.Parent = {parent}",
		"\tsound:Play()",
		"\tsound.Ended:Connect(function()",
		"\t\tsound:Destroy()",
		"\tend)",
		"end",
	},
	fields = { list = "expr|footsteps|list of ids", parent = "expr|script.Parent|parent" },
	doc = "Picking from a handful of takes stops a repeated noise sounding " ..
		"mechanical. Footsteps and hits want this.",
	tags = "random variation sound list footsteps" }

D{ id = "soundOnEnded", cat = "sound", group = "Playing", label = "on sound finished",
	head = "when {sound} finishes",
	code = "{sound}.Ended:Connect(function()", tail = "end)",
	fields = { sound = "expr|sound|sound" },
	slots = { { key = "body" } },
	doc = "Only fires when it reaches the end on its own, not when you stop " ..
		"it yourself.",
	tags = "ended finished sound event" }

D{ id = "soundWaitEnd", cat = "sound", group = "Playing", label = "wait for the end",
	head = "wait until {sound} finishes",
	code = "{sound}.Ended:Wait()",
	fields = { sound = "expr|sound|sound" },
	doc = "Pauses this script until the sound is done, which is how you play " ..
		"a queue of them in order.",
	tags = "wait ended sequence sound" }

D{ id = "soundIfPlaying", cat = "sound", group = "Playing", label = "if it is playing",
	head = "if {sound} is playing then",
	code = "if {sound}.IsPlaying then", tail = "end",
	fields = { sound = "expr|sound|sound" },
	slots = { { key = "body" } },
	doc = "Stops you starting a sound that is already going, which would cut " ..
		"it off and restart it.",
	tags = "isplaying check sound condition" }

-- adjusting ----------------------------------------------------------------------
D{ id = "soundVolume", cat = "sound", group = "Adjusting", label = "set the volume",
	head = "set the volume of {sound} to {n}",
	code = "{sound}.Volume = {n}",
	fields = { sound = "expr|sound|sound", n = "num|0.5|volume" },
	doc = "0.5 is a sensible full volume. Anything above 1 tends to distort.",
	tags = "volume loud quiet sound" }

D{ id = "soundSpeed", cat = "sound", group = "Adjusting", label = "set the speed",
	head = "set the speed of {sound} to {n}",
	code = "{sound}.PlaybackSpeed = {n}",
	fields = { sound = "expr|sound|sound", n = "num|1|speed" },
	doc = "1 is normal. Higher is faster and higher pitched -- a cheap way to " ..
		"make one sound into several.",
	tags = "playbackspeed pitch speed sound" }

D{ id = "soundLoop", cat = "sound", group = "Adjusting", label = "set repeating",
	head = "set {sound} to repeat: {value}",
	code = "{sound}.Looped = {value}",
	fields = { sound = "expr|sound|sound", value = "choice|true|value|true,false" },
	doc = "Looped sounds start again the moment they end. Music and engines " ..
		"want this; gunshots do not.",
	tags = "looped repeat music loop" }

D{ id = "soundSkipTo", cat = "sound", group = "Adjusting", label = "skip to",
	head = "skip {sound} to {n} seconds in",
	code = "{sound}.TimePosition = {n}",
	fields = { sound = "expr|sound|sound", n = "num|0|seconds" },
	doc = "Jumps to a point in the sound. Works while it plays or before you " ..
		"start it.",
	tags = "timeposition skip seek scrub" }

D{ id = "soundLeft", cat = "sound", group = "Adjusting", label = "how much is left",
	head = "make {name} = how many seconds of {sound} are left",
	code = "local {name} = {sound}.TimeLength - {sound}.TimePosition",
	fields = { name = "name|remaining|name", sound = "expr|sound|sound" },
	doc = "TimeLength is zero until the sound has loaded, so this can read " ..
		"oddly on the very first frame.",
	tags = "timelength remaining duration sound" }

D{ id = "soundFadeOut", cat = "sound", group = "Adjusting", label = "fade out",
	head = "fade {sound} out over {time} seconds",
	code = "TweenService:Create({sound}, TweenInfo.new({time}), { Volume = 0 }):Play()",
	fields = { sound = "expr|music|sound", time = "num|2|seconds" },
	needs = { "TweenService" },
	doc = "Slides the volume down to nothing. Stop it afterwards if you want " ..
		"it to actually end.",
	tags = "fade out volume tween music" }

D{ id = "soundFadeIn", cat = "sound", group = "Adjusting", label = "fade in",
	head = "fade {sound} in to {n} over {time} seconds",
	code = {
		"{sound}.Volume = 0",
		"{sound}:Play()",
		"TweenService:Create({sound}, TweenInfo.new({time}), { Volume = {n} }):Play()",
	},
	fields = { sound = "expr|music|sound", n = "num|0.5|volume", time = "num|2|seconds" },
	needs = { "TweenService" },
	doc = "Starts silent and rises. Much kinder than music appearing at full " ..
		"volume.",
	tags = "fade in volume tween music" }

-- where it comes from ---------------------------------------------------------------
D{ id = "soundRange", cat = "sound", group = "Where from", label = "set how far it carries",
	head = "let {sound} be heard up to {n} studs away",
	code = { "{sound}.RollOffMaxDistance = {n}", "{sound}.RollOffMinDistance = {near}" },
	fields = { sound = "expr|sound|sound", n = "num|60|studs", near = "num|10|full volume within" },
	doc = "A sound inside a part fades with distance. These two say where it " ..
		"is at full volume and where it disappears.",
	tags = "rolloff distance 3d spatial range" }

D{ id = "soundLocal", cat = "sound", group = "Where from", label = "play for this player only",
	head = "play {sound} for this player only",
	code = "SoundService:PlayLocalSound({sound})",
	fields = { sound = "expr|sound|sound" },
	needs = { "SoundService" },
	side = "client",
	doc = "Ignores where the sound is in the world and plays it flat, for " ..
		"this client alone. Interface noises want this.",
	tags = "playlocalsound client ui local sound" }

D{ id = "soundGroup", cat = "sound", group = "Where from", label = "make a sound group",
	head = 'make {name} = a sound group called "{label}"',
	code = {
		'local {name} = Instance.new("SoundGroup")',
		'{name}.Name = "{label}"',
		"{name}.Volume = {volume}",
		"{name}.Parent = SoundService",
	},
	fields = { name = "name|musicGroup|name", label = "str|Music|group name",
		volume = "num|1|volume" },
	needs = { "SoundService" },
	doc = "Groups let one slider control every sound in a category, which is " ..
		"how music and effects volumes are done properly.",
	tags = "soundgroup mixer volume category" }

D{ id = "soundJoinGroup", cat = "sound", group = "Where from", label = "put a sound in a group",
	head = "put {sound} in the group {group}",
	code = "{sound}.SoundGroup = {group}",
	fields = { sound = "expr|sound|sound", group = "expr|musicGroup|group" },
	doc = "The sound's own volume is multiplied by the group's, so both still " ..
		"work.",
	tags = "soundgroup assign mixer volume" }

D{ id = "soundGroupVolume", cat = "sound", group = "Where from", label = "set a group's volume",
	head = "set the volume of the group {group} to {n}",
	code = "{group}.Volume = {n}",
	fields = { group = "expr|musicGroup|group", n = "num|0.5|volume" },
	doc = "One line behind a whole volume slider.",
	tags = "soundgroup volume slider settings" }

D{ id = "soundEcho", cat = "sound", group = "Where from", label = "set the echo",
	head = "make the world sound like {place}",
	code = "SoundService.AmbientReverb = Enum.ReverbType.{place}",
	fields = { place = "choice|Cave|place|NoReverb,Room,Cave,Arena,Hangar,Forest,Underwater,Sewer,Mountains" },
	needs = { "SoundService" },
	doc = "Adds echo to everything at once. Switching it as a player walks " ..
		"into a cave costs nothing and sells the space.",
	tags = "reverb echo ambience cave underwater" }

D{ id = "soundStopAll", cat = "sound", group = "Where from", label = "stop every sound",
	head = "stop every sound inside {parent}",
	code = {
		"for _, sound in ipairs({parent}:GetDescendants()) do",
		'\tif sound:IsA("Sound") then',
		"\t\tsound:Stop()",
		"\tend",
		"end",
	},
	fields = { parent = "expr|workspace|where to look" },
	doc = "Walks everything below and silences any sound it finds. Handy " ..
		"between rounds.",
	tags = "stop all silence sounds descendants" }

D{ id = "soundPreload", cat = "sound", group = "Where from", label = "load before playing",
	head = "wait until {asset} has loaded",
	code = "ContentProvider:PreloadAsync({ {asset} })",
	fields = { asset = "expr|sound|what to load" },
	needs = { "ContentProvider" },
	doc = "Sounds and images stutter the first time they are used. Loading " ..
		"them during a loading screen avoids that.",
	tags = "preload contentprovider loading stutter" }

D{ id = "soundPlaylist", cat = "sound", group = "Where from", label = "play a playlist",
	head = "play the songs in {list} one after another on {sound}",
	code = {
		"task.spawn(function()",
		"\twhile true do",
		"\t\tfor _, id in ipairs({list}) do",
		"\t\t\t{sound}.SoundId = id",
		"\t\t\t{sound}:Play()",
		"\t\t\t{sound}.Ended:Wait()",
		"\t\tend",
		"\tend",
		"end)",
	},
	fields = { list = "expr|songs|list of ids", sound = "expr|music|sound to use" },
	doc = "Runs on its own thread so the rest of the script carries on, and " ..
		"starts the list again when it reaches the end.",
	tags = "playlist music queue loop songs" }

end
