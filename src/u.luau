--!nonstrict
-- u  ·  block definitions: physics, animation, NPCs, terrain
--
-- The movers here are the current ones -- LinearVelocity, AlignPosition,
-- VectorForce -- rather than the BodyVelocity family Roblox has retired.

return function(D)

--=============================================================================
-- PHYSICS
--=============================================================================

D{ id = "physPush", cat = "phys", group = "Moving things", label = "shove once",
	head = "shove {part} by ({x}, {y}, {z})",
	code = "{part}:ApplyImpulse(Vector3.new({x}, {y}, {z}))",
	fields = { part = "expr|part|part", x = "expr|0|x", y = "expr|50|y", z = "expr|0|z" },
	doc = "One instant kick, measured in mass times studs per second. Heavier " ..
		"parts need a bigger number for the same effect.",
	tags = "applyimpulse push launch knockback jump" }

D{ id = "physSpin", cat = "phys", group = "Moving things", label = "spin once",
	head = "spin {part} by ({x}, {y}, {z})",
	code = "{part}:ApplyAngularImpulse(Vector3.new({x}, {y}, {z}))",
	fields = { part = "expr|part|part", x = "expr|0|x", y = "expr|10|y", z = "expr|0|z" },
	doc = "The turning version of a shove. Each number is a spin around that " ..
		"axis.",
	tags = "angular impulse spin rotate torque" }

D{ id = "physSetSpeed", cat = "phys", group = "Moving things", label = "set the speed",
	head = "set the speed of {part} to ({x}, {y}, {z})",
	code = "{part}.AssemblyLinearVelocity = Vector3.new({x}, {y}, {z})",
	fields = { part = "expr|part|part", x = "expr|0|x", y = "expr|50|y", z = "expr|0|z" },
	doc = "Replaces whatever speed it had. Setting the upward part alone is " ..
		"how a jump pad works.",
	tags = "velocity speed assembly launch pad" }

D{ id = "physKeepMoving", cat = "phys", group = "Moving things", label = "keep it moving",
	head = "keep {part} moving at ({x}, {y}, {z})",
	code = {
		"do",
		'\tlocal spot = Instance.new("Attachment")',
		"\tspot.Parent = {part}",
		'\tlocal mover = Instance.new("LinearVelocity")',
		"\tmover.Attachment0 = spot",
		"\tmover.VectorVelocity = Vector3.new({x}, {y}, {z})",
		"\tmover.MaxForce = {force}",
		"\tmover.Parent = {part}",
		"end",
	},
	fields = { part = "expr|part|part", x = "expr|0|x", y = "expr|0|y", z = "expr|20|z",
		force = "num|100000|strength" },
	doc = "A LinearVelocity keeps pushing rather than kicking once. This is " ..
		"the modern replacement for BodyVelocity.",
	tags = "linearvelocity constant move conveyor mover" }

D{ id = "physKeepSpinning", cat = "phys", group = "Moving things", label = "keep it spinning",
	head = "keep {part} spinning at {speed} around its {axis} axis",
	code = {
		"do",
		'\tlocal spot = Instance.new("Attachment")',
		"\tspot.Parent = {part}",
		'\tlocal spin = Instance.new("AngularVelocity")',
		"\tspin.Attachment0 = spot",
		"\tspin.AngularVelocity = Vector3.{axis} * {speed}",
		"\tspin.MaxTorque = {force}",
		"\tspin.Parent = {part}",
		"end",
	},
	fields = { part = "expr|part|part", speed = "num|3|speed",
		axis = "choice|yAxis|axis|xAxis,yAxis,zAxis", force = "num|100000|strength" },
	doc = "Turntables, windmills and spinning traps. The Y axis is upright, " ..
		"so most things spin around that.",
	tags = "angularvelocity spin rotate turntable" }

D{ id = "physHoldAt", cat = "phys", group = "Moving things", label = "hold it in place",
	head = "hold {part} at ({x}, {y}, {z})",
	code = {
		"do",
		'\tlocal spot = Instance.new("Attachment")',
		"\tspot.Parent = {part}",
		'\tlocal hold = Instance.new("AlignPosition")',
		"\thold.Attachment0 = spot",
		"\thold.Mode = Enum.PositionAlignmentMode.OneAttachment",
		"\thold.Position = Vector3.new({x}, {y}, {z})",
		"\thold.MaxForce = {force}",
		"\thold.Responsiveness = {snap}",
		"\thold.Parent = {part}",
		"end",
	},
	fields = { part = "expr|part|part", x = "expr|0|x", y = "expr|10|y", z = "expr|0|z",
		force = "num|100000|strength", snap = "num|25|snappiness" },
	doc = "Pulls the part towards a point and keeps it there, still able to " ..
		"be knocked about. Higher snappiness is stiffer.",
	tags = "alignposition hold float hover follow" }

D{ id = "physFaceDirection", cat = "phys", group = "Moving things", label = "hold its facing",
	head = "keep {part} facing the same way",
	code = {
		"do",
		'\tlocal spot = Instance.new("Attachment")',
		"\tspot.Parent = {part}",
		'\tlocal face = Instance.new("AlignOrientation")',
		"\tface.Attachment0 = spot",
		"\tface.Mode = Enum.OrientationAlignmentMode.OneAttachment",
		"\tface.CFrame = {part}.CFrame",
		"\tface.MaxTorque = {force}",
		"\tface.Parent = {part}",
		"end",
	},
	fields = { part = "expr|part|part", force = "num|100000|strength" },
	doc = "Stops something tipping over without anchoring it, so it can still " ..
		"be pushed around.",
	tags = "alignorientation upright facing stable" }

D{ id = "physForce", cat = "phys", group = "Moving things", label = "apply a steady force",
	head = "push {part} steadily by ({x}, {y}, {z})",
	code = {
		"do",
		'\tlocal spot = Instance.new("Attachment")',
		"\tspot.Parent = {part}",
		'\tlocal push = Instance.new("VectorForce")',
		"\tpush.Attachment0 = spot",
		"\tpush.Force = Vector3.new({x}, {y}, {z})",
		"\tpush.RelativeTo = Enum.ActuatorRelativeTo.World",
		"\tpush.Parent = {part}",
		"end",
	},
	fields = { part = "expr|part|part", x = "expr|0|x", y = "expr|0|y", z = "expr|0|z" },
	doc = "A force fights gravity and friction rather than overriding them. " ..
		"To hover, the upward force must beat mass times gravity.",
	tags = "vectorforce force push thrust hover" }

D{ id = "physStop", cat = "phys", group = "Moving things", label = "stop it dead",
	head = "stop {part} moving",
	code = {
		"{part}.AssemblyLinearVelocity = Vector3.zero",
		"{part}.AssemblyAngularVelocity = Vector3.zero",
	},
	fields = { part = "expr|part|part" },
	doc = "Clears both the movement and the spin. Without the second line a " ..
		"stopped part can still be tumbling.",
	tags = "stop velocity zero halt freeze" }

-- joints ---------------------------------------------------------------------------
D{ id = "physWeld", cat = "phys", group = "Joints", label = "stick together",
	head = "stick {a} to {b}",
	code = {
		"do",
		'\tlocal weld = Instance.new("WeldConstraint")',
		"\tweld.Part0 = {a}",
		"\tweld.Part1 = {b}",
		"\tweld.Parent = {a}",
		"end",
	},
	fields = { a = "expr|partA|first", b = "expr|partB|second" },
	doc = "A WeldConstraint locks two parts together wherever they are when " ..
		"you make it. Move them into place first.",
	tags = "weldconstraint weld stick join attach" }

D{ id = "physUnweld", cat = "phys", group = "Joints", label = "unstick",
	head = "unstick everything welded to {part}",
	code = {
		"for _, joint in ipairs({part}:GetChildren()) do",
		'\tif joint:IsA("WeldConstraint") then',
		"\t\tjoint:Destroy()",
		"\tend",
		"end",
	},
	fields = { part = "expr|part|part" },
	doc = "Removes the welds this part is holding, letting whatever was stuck " ..
		"to it fall away.",
	tags = "unweld break destroy joint separate" }

D{ id = "physHinge", cat = "phys", group = "Joints", label = "make a hinge",
	head = "hinge {a} to {b}",
	code = {
		"do",
		'\tlocal one = Instance.new("Attachment")',
		"\tone.Parent = {a}",
		'\tlocal two = Instance.new("Attachment")',
		"\ttwo.Parent = {b}",
		'\tlocal hinge = Instance.new("HingeConstraint")',
		"\thinge.Attachment0 = one",
		"\thinge.Attachment1 = two",
		"\thinge.Parent = {a}",
		"end",
	},
	fields = { a = "expr|door|first", b = "expr|frame|second" },
	doc = "Lets one part swing around a line through both attachments. Doors " ..
		"and levers are hinges.",
	tags = "hingeconstraint hinge door swing pivot" }

D{ id = "physMotor", cat = "phys", group = "Joints", label = "make a powered hinge",
	head = "hinge {a} to {b} and drive it at {speed}",
	code = {
		"do",
		'\tlocal one = Instance.new("Attachment")',
		"\tone.Parent = {a}",
		'\tlocal two = Instance.new("Attachment")',
		"\ttwo.Parent = {b}",
		'\tlocal motor = Instance.new("HingeConstraint")',
		"\tmotor.Attachment0 = one",
		"\tmotor.Attachment1 = two",
		"\tmotor.ActuatorType = Enum.ActuatorType.Motor",
		"\tmotor.AngularVelocity = {speed}",
		"\tmotor.MotorMaxTorque = {force}",
		"\tmotor.Parent = {a}",
		"end",
	},
	fields = { a = "expr|wheel|first", b = "expr|axle|second", speed = "num|5|speed",
		force = "num|10000|strength" },
	doc = "A hinge with a motor in it. Wheels, conveyor rollers and automatic " ..
		"doors all run on these.",
	tags = "motor hinge wheel drive powered" }

D{ id = "physRope", cat = "phys", group = "Joints", label = "tie a rope",
	head = "tie {a} to {b} with a rope {length} studs long",
	code = {
		"do",
		'\tlocal one = Instance.new("Attachment")',
		"\tone.Parent = {a}",
		'\tlocal two = Instance.new("Attachment")',
		"\ttwo.Parent = {b}",
		'\tlocal rope = Instance.new("RopeConstraint")',
		"\trope.Attachment0 = one",
		"\trope.Attachment1 = two",
		"\trope.Length = {length}",
		"\trope.Visible = true",
		"\trope.Parent = {a}",
		"end",
	},
	fields = { a = "expr|anchor|first", b = "expr|weight|second", length = "num|10|length" },
	doc = "A rope stops the parts drifting further apart than its length, but " ..
		"lets them come closer. Swings and tows are ropes.",
	tags = "ropeconstraint rope tether swing tow" }

D{ id = "physSpring", cat = "phys", group = "Joints", label = "add a spring",
	head = "spring {a} to {b}, {length} studs at rest",
	code = {
		"do",
		'\tlocal one = Instance.new("Attachment")',
		"\tone.Parent = {a}",
		'\tlocal two = Instance.new("Attachment")',
		"\ttwo.Parent = {b}",
		'\tlocal spring = Instance.new("SpringConstraint")',
		"\tspring.Attachment0 = one",
		"\tspring.Attachment1 = two",
		"\tspring.FreeLength = {length}",
		"\tspring.Stiffness = {stiffness}",
		"\tspring.Damping = {damping}",
		"\tspring.Parent = {a}",
		"end",
	},
	fields = { a = "expr|body|first", b = "expr|wheel|second", length = "num|4|rest length",
		stiffness = "num|2000|stiffness", damping = "num|100|damping" },
	doc = "Pulls back towards its rest length from either direction. Damping " ..
		"stops it bouncing forever -- without it, nothing settles.",
	tags = "springconstraint spring suspension bounce" }

-- collisions --------------------------------------------------------------------------
D{ id = "physSolid", cat = "phys", group = "Collisions", label = "set solid",
	head = "set {part} solid to {value}",
	code = "{part}.CanCollide = {value}",
	fields = { part = "expr|part|part", value = "choice|true|value|true,false" },
	doc = "A part that is not solid is walked straight through, but still " ..
		"fires Touched. That is how checkpoints and triggers work.",
	tags = "cancollide solid pass through trigger" }

D{ id = "physTouchable", cat = "phys", group = "Collisions", label = "set touchable",
	head = "set {part} touchable to {value}",
	code = "{part}.CanTouch = {value}",
	fields = { part = "expr|part|part", value = "choice|true|value|true,false" },
	doc = "Switching CanTouch off stops Touched firing at all, which is worth " ..
		"doing on scenery that nothing needs to react to.",
	tags = "cantouch touched performance trigger" }

D{ id = "physQueryable", cat = "phys", group = "Collisions", label = "set findable by rays",
	head = "set {part} findable by rays to {value}",
	code = "{part}.CanQuery = {value}",
	fields = { part = "expr|part|part", value = "choice|true|value|true,false" },
	doc = "Rays pass straight through a part with this off, which is how you " ..
		"stop an aim ray hitting your own character.",
	tags = "canquery raycast ignore invisible" }

D{ id = "physGroup", cat = "phys", group = "Collisions", label = "put in a collision group",
	head = 'put {part} in the collision group "{group}"',
	code = '{part}.CollisionGroup = "{group}"',
	fields = { part = "expr|part|part", group = "str|Players|group name" },
	doc = "Groups let whole sets of parts ignore each other. Set up which " ..
		"groups collide in Studio's Collision Groups editor first.",
	tags = "collisiongroup ignore group physics" }

D{ id = "physRegisterGroup", cat = "phys", group = "Collisions", label = "create a collision group",
	head = 'create the collision group "{group}"',
	code = 'PhysicsService:RegisterCollisionGroup("{group}")',
	fields = { group = "str|Players|group name" },
	needs = { "PhysicsService" }, side = "server",
	doc = "Makes the group in code rather than in the editor. Do it once, on " ..
		"the server, before anything is put in it.",
	tags = "physicsservice registercollisiongroup create" }

D{ id = "physGroupsIgnore", cat = "phys", group = "Collisions", label = "make two groups pass through",
	head = 'let "{a}" and "{b}" pass through each other',
	code = 'PhysicsService:CollisionGroupSetCollidable("{a}", "{b}", false)',
	fields = { a = "str|Players|first group", b = "str|Enemies|second group" },
	needs = { "PhysicsService" }, side = "server",
	doc = "How players walk through each other while still standing on the " ..
		"floor.",
	tags = "collisiongroupsetcollidable ignore pass through" }

D{ id = "physOverlaps", cat = "phys", group = "Collisions", label = "for each part overlapping",
	head = "for each {found} overlapping {part}",
	code = "for _, {found} in ipairs(workspace:GetPartsInPart({part})) do", tail = "end",
	fields = { part = "expr|zone|part", found = "name|found|part found" },
	slots = { { key = "body" } },
	doc = "Asks once what is inside a part, rather than waiting for Touched. " ..
		"Right for a zone you check now and then.",
	tags = "getpartsinpart overlap zone region check" }

D{ id = "physNearby", cat = "phys", group = "Collisions", label = "for each part in a box",
	head = "for each {found} inside a {size} stud box at {where}",
	code = {
		"for _, {found} in ipairs(workspace:GetPartBoundsInBox(",
		"\tCFrame.new({where}), Vector3.new({size}, {size}, {size}))) do",
	},
	codeTail = { "end" }, tail = "end",
	fields = { where = "expr|part.Position|centre", size = "num|20|size",
		found = "name|found|part found" },
	slots = { { key = "body" } },
	doc = "A box search around a point. Explosions and area effects use this " ..
		"rather than looping over everything in the workspace.",
	tags = "getpartboundsinbox area explosion nearby" }

-- rays -----------------------------------------------------------------------------------
D{ id = "physRay", cat = "phys", group = "Rays", label = "fire a ray",
	head = "make {name} = what a ray from {from} going {direction} hits",
	code = "local {name} = workspace:Raycast({from}, {direction})",
	fields = { name = "name|hit|name", from = "expr|part.Position|start",
		direction = "expr|Vector3.new(0, -50, 0)|direction and length" },
	doc = "The direction is also the length -- a 50 stud drop is " ..
		"`Vector3.new(0, -50, 0)`. Gives nil when it hits nothing.",
	tags = "raycast ray hit trace line" }

D{ id = "physRayIgnoring", cat = "phys", group = "Rays", label = "fire a ray ignoring things",
	head = "make {name} = what a ray from {from} going {direction} hits, ignoring {ignore}",
	code = {
		"local {name}",
		"do",
		'\tlocal rules = RaycastParams.new()',
		"\trules.FilterType = Enum.RaycastFilterType.Exclude",
		"\trules.FilterDescendantsInstances = {ignore}",
		"\t{name} = workspace:Raycast({from}, {direction}, rules)",
		"end",
	},
	fields = { name = "name|hit|name", from = "expr|origin|start",
		direction = "expr|Vector3.new(0, -50, 0)|direction and length",
		ignore = "expr|{ character }|what to ignore" },
	doc = "Nearly every aiming ray needs to ignore the character firing it, " ..
		"or it hits their own chest.",
	tags = "raycastparams exclude ignore filter ray" }

D{ id = "physRayHitPart", cat = "phys", group = "Rays", label = "what the ray hit",
	head = "make {name} = the part {hit} found",
	code = "local {name} = {hit} and {hit}.Instance or nil",
	fields = { name = "name|target|name", hit = "expr|hit|ray result" },
	doc = "A ray result holds `Instance`, `Position`, `Normal` and `Material`. " ..
		"The `and ... or nil` guards against the ray having hit nothing.",
	tags = "raycastresult instance hit part" }

D{ id = "physRayHitWhere", cat = "phys", group = "Rays", label = "where the ray landed",
	head = "make {name} = where {hit} landed",
	code = "local {name} = {hit} and {hit}.Position or nil",
	fields = { name = "name|spot|name", hit = "expr|hit|ray result" },
	doc = "The exact point on the surface. Where you would put a bullet hole " ..
		"or a teleport marker.",
	tags = "raycastresult position point surface" }

D{ id = "physIfRayHit", cat = "phys", group = "Rays", label = "if the ray hit something",
	head = "if {hit} found something then",
	code = "if {hit} then", tail = "end",
	fields = { hit = "expr|hit|ray result" },
	slots = { { key = "body" } },
	doc = "Always check before reading anything out of a ray result.",
	tags = "raycast check nil hit condition" }

D{ id = "physGroundBelow", cat = "phys", group = "Rays", label = "find the ground below",
	head = "make {name} = how far the ground is below {part}",
	code = {
		"local {name} = nil",
		"do",
		"\tlocal found = workspace:Raycast({part}.Position, Vector3.new(0, -{depth}, 0))",
		"\tif found then",
		"\t\t{name} = ({part}.Position - found.Position).Magnitude",
		"\tend",
		"end",
	},
	fields = { name = "name|drop|name", part = "expr|part|part", depth = "num|100|how far to look" },
	doc = "Fires a ray straight down and measures the gap. Nil means nothing " ..
		"was found within range.",
	tags = "ground below raycast height drop" }

-- properties -----------------------------------------------------------------------------
D{ id = "physMass", cat = "phys", group = "Properties", label = "how heavy it is",
	head = "make {name} = how heavy {part} is",
	code = "local {name} = {part}.AssemblyMass",
	fields = { name = "name|mass|name", part = "expr|part|part" },
	doc = "The mass of everything welded to it, not just the one part. That " ..
		"is what forces actually push against.",
	tags = "mass weight assembly heavy" }

D{ id = "physMaterialFeel", cat = "phys", group = "Properties", label = "set how it feels",
	head = "make {part} {density} dense, with {friction} grip and {bounce} bounce",
	code = "{part}.CustomPhysicalProperties = PhysicalProperties.new({density}, " ..
		"{friction}, {bounce})",
	fields = { part = "expr|part|part", density = "num|0.7|density",
		friction = "num|0.3|grip", bounce = "num|0.5|bounce" },
	doc = "Overrides what the material would give. High bounce and low grip " ..
		"makes ice; the reverse makes rubber.",
	tags = "physicalproperties density friction bounce elasticity" }

D{ id = "physGravity", cat = "phys", group = "Properties", label = "set the world gravity",
	head = "set gravity to {n}",
	code = "workspace.Gravity = {n}",
	fields = { n = "num|196.2|gravity" },
	doc = "196.2 is Roblox's normal. Halve it for a moon feel; zero it for " ..
		"space, though characters then float away.",
	tags = "gravity workspace physics moon space" }

D{ id = "physOwner", cat = "phys", group = "Properties", label = "give physics control",
	head = "let {player} control the physics of {part}",
	code = "{part}:SetNetworkOwner({player})",
	fields = { part = "expr|part|part", player = "expr|player|player" },
	side = "server",
	doc = "Whoever owns a part simulates it, so giving a player their own " ..
		"vehicle makes it feel instant instead of laggy.",
	tags = "setnetworkowner ownership lag vehicle physics" }

D{ id = "physServerOwns", cat = "phys", group = "Properties", label = "take physics control back",
	head = "let the server control the physics of {part}",
	code = "{part}:SetNetworkOwner(nil)",
	fields = { part = "expr|part|part" },
	side = "server",
	doc = "The server simulates it instead. Slower to respond, but a player " ..
		"cannot cheat it.",
	tags = "setnetworkowner server physics anticheat" }

D{ id = "physSleepy", cat = "phys", group = "Properties", label = "stop it being pushed",
	head = "stop {part} being pushed around",
	code = "{part}.Massless = true",
	fields = { part = "expr|part|part" },
	doc = "A massless part adds no weight to whatever it is welded to. Right " ..
		"for decorations on a vehicle.",
	tags = "massless weight decoration vehicle" }

--=============================================================================
-- ANIMATION
--=============================================================================

D{ id = "animLoad", cat = "anim", group = "Playing", label = "load an animation",
	head = "make {name} = animation {id} loaded onto {hum}",
	code = {
		'local {name} = Instance.new("Animation")',
		'{name}.AnimationId = "rbxassetid://{id}"',
		"{name} = {hum}:FindFirstChildOfClass(\"Animator\"):LoadAnimation({name})",
	},
	fields = { name = "name|track|name", id = "num|0|animation id", hum = "expr|hum|humanoid" },
	doc = "Animations are loaded through the Animator inside the Humanoid, " ..
		"which is the current way to do it. Load once, play many times.",
	tags = "animation loadanimation animator track load" }

D{ id = "animPlay", cat = "anim", group = "Playing", label = "play an animation",
	head = "play {track}",
	code = "{track}:Play()",
	fields = { track = "expr|track|track" },
	doc = "Starts from the beginning and blends in over a moment.",
	tags = "play animation track start" }

D{ id = "animStop", cat = "anim", group = "Playing", label = "stop an animation",
	head = "stop {track} over {fade} seconds",
	code = "{track}:Stop({fade})",
	fields = { track = "expr|track|track", fade = "num|0.2|fade seconds" },
	doc = "Fading out rather than cutting stops the character snapping back " ..
		"to its pose.",
	tags = "stop animation fade blend" }

D{ id = "animSpeed", cat = "anim", group = "Playing", label = "set animation speed",
	head = "set the speed of {track} to {n}",
	code = "{track}:AdjustSpeed({n})",
	fields = { track = "expr|track|track", n = "num|1|speed" },
	doc = "1 is normal, 2 is double time, 0 freezes it on the current frame. " ..
		"Matching a run animation to walk speed uses this.",
	tags = "adjustspeed animation faster slower" }

D{ id = "animLoop", cat = "anim", group = "Playing", label = "set an animation looping",
	head = "set {track} to repeat: {value}",
	code = "{track}.Looped = {value}",
	fields = { track = "expr|track|track", value = "choice|true|value|true,false" },
	doc = "Idle and walk animations loop; a wave or a swing should not.",
	tags = "looped repeat animation idle" }

D{ id = "animPriority", cat = "anim", group = "Playing", label = "set animation priority",
	head = "set the priority of {track} to {level}",
	code = "{track}.Priority = Enum.AnimationPriority.{level}",
	fields = { track = "expr|track|track",
		level = "choice|Action|level|Core,Idle,Movement,Action,Action2,Action3" },
	doc = "When two animations both move an arm, the higher priority wins. " ..
		"An attack should be Action so it beats walking.",
	tags = "priority animation blend override action" }

D{ id = "animIfPlaying", cat = "anim", group = "Playing", label = "if an animation is playing",
	head = "if {track} is playing then",
	code = "if {track}.IsPlaying then", tail = "end",
	fields = { track = "expr|track|track" },
	slots = { { key = "body" } },
	doc = "Stops you restarting an animation that has not finished, which " ..
		"would make it stutter.",
	tags = "isplaying animation check" }

D{ id = "animOnEnded", cat = "anim", group = "Playing", label = "on an animation finishing",
	head = "when {track} finishes",
	code = "{track}.Stopped:Connect(function()", tail = "end)",
	fields = { track = "expr|track|track" },
	slots = { { key = "body" } },
	doc = "Fires when it stops for any reason, including being stopped by " ..
		"you. Good for chaining a combo.",
	tags = "stopped ended animation event combo" }

D{ id = "animOnMarker", cat = "anim", group = "Playing", label = "on an animation marker",
	head = 'when {track} reaches the marker "{marker}"',
	code = '{track}:GetMarkerReachedSignal("{marker}"):Connect(function()', tail = "end)",
	fields = { track = "expr|track|track", marker = "str|hit|marker name" },
	slots = { { key = "body" } },
	doc = "Markers are set in the animation editor. This is how a sword deals " ..
		"damage exactly when it connects rather than when the swing starts.",
	tags = "marker keyframe animation timing hit" }

D{ id = "animStopAll", cat = "anim", group = "Playing", label = "stop every animation",
	head = "stop every animation on {hum}",
	code = {
		'for _, track in ipairs({hum}:FindFirstChildOfClass("Animator"):GetPlayingAnimationTracks()) do',
		"\ttrack:Stop()",
		"end",
	},
	fields = { hum = "expr|hum|humanoid" },
	doc = "Clears everything at once, which is the simplest way to reset a " ..
		"character that has got into a strange pose.",
	tags = "stop all animations reset tracks" }

-- humanoid states -------------------------------------------------------------------------
D{ id = "animSit", cat = "anim", group = "States", label = "sit down",
	head = "make {hum} sit",
	code = "{hum}.Sit = true",
	fields = { hum = "expr|hum|humanoid" },
	doc = "Sits the character where it is. Setting it back to false stands " ..
		"them up again.",
	tags = "sit humanoid seat pose" }

D{ id = "animJump", cat = "anim", group = "States", label = "jump",
	head = "make {hum} jump",
	code = "{hum}.Jump = true",
	fields = { hum = "expr|hum|humanoid" },
	doc = "The same as the player pressing space. It only works if they are " ..
		"actually on the ground.",
	tags = "jump humanoid hop" }

D{ id = "animRagdoll", cat = "anim", group = "States", label = "go limp",
	head = "make {hum} go limp",
	code = "{hum}.PlatformStand = true",
	fields = { hum = "expr|hum|humanoid" },
	doc = "The character stops holding itself up and flops about. Setting it " ..
		"back to false stands them up.",
	tags = "platformstand ragdoll limp knocked down" }

D{ id = "animState", cat = "anim", group = "States", label = "force a state",
	head = "put {hum} into the {state} state",
	code = "{hum}:ChangeState(Enum.HumanoidStateType.{state})",
	fields = { hum = "expr|hum|humanoid",
		state = "choice|Jumping|state|Jumping,Freefall,Landed,Swimming,Climbing,Seated,GettingUp,Dead,Running" },
	doc = "Forces the character into a state rather than waiting for physics " ..
		"to put it there.",
	tags = "changestate humanoidstate force jump swim" }

D{ id = "animOnStateChange", cat = "anim", group = "States", label = "on a state change",
	head = "when {hum} changes state, from {old} to {new}",
	code = "{hum}.StateChanged:Connect(function({old}, {new})", tail = "end)",
	fields = { hum = "expr|hum|humanoid", old = "name|old|from", new = "name|new|to" },
	slots = { { key = "body" } },
	doc = "Fires on every landing, jump and fall. Compare the new state " ..
		"against `Enum.HumanoidStateType.Landed` for a landing thump.",
	tags = "statechanged humanoid landed jump event" }

D{ id = "animDisableState", cat = "anim", group = "States", label = "forbid a state",
	head = "stop {hum} being able to {state}",
	code = "{hum}:SetStateEnabled(Enum.HumanoidStateType.{state}, false)",
	fields = { hum = "expr|hum|humanoid",
		state = "choice|Jumping|state|Jumping,Climbing,Swimming,GettingUp,Seated,Dead" },
	doc = "Turning off Jumping is how you make a no-jump zone. Turning off " ..
		"GettingUp is how a ragdoll stays down.",
	tags = "setstateenabled forbid disable jump climb" }

D{ id = "animAutoRotate", cat = "anim", group = "States", label = "set turning to face movement",
	head = "set {hum} turning to face where it walks: {value}",
	code = "{hum}.AutoRotate = {value}",
	fields = { hum = "expr|hum|humanoid", value = "choice|true|value|true,false" },
	doc = "Off means the character keeps facing one way while strafing, which " ..
		"is what a shooter usually wants.",
	tags = "autorotate turn facing strafe" }

-- character bits -----------------------------------------------------------------------------
D{ id = "animGiveTool", cat = "anim", group = "Character", label = "give a tool",
	head = "give {tool} to {player}",
	code = "{tool}.Parent = {player}.Backpack",
	fields = { tool = "expr|tool|tool", player = "expr|player|player" },
	doc = "A tool in the Backpack appears in their hotbar. Put it in the " ..
		"character instead to force it into their hands.",
	tags = "tool backpack give item equip" }

D{ id = "animEquipTool", cat = "anim", group = "Character", label = "put a tool in their hands",
	head = "make {hum} hold {tool}",
	code = "{hum}:EquipTool({tool})",
	fields = { hum = "expr|hum|humanoid", tool = "expr|tool|tool" },
	doc = "Equips it immediately, whether or not they chose it.",
	tags = "equiptool hold equip tool hands" }

D{ id = "animUnequip", cat = "anim", group = "Character", label = "empty their hands",
	head = "make {hum} put everything away",
	code = "{hum}:UnequipTools()",
	fields = { hum = "expr|hum|humanoid" },
	doc = "Everything they were holding goes back to the backpack.",
	tags = "unequiptools drop hands empty" }

D{ id = "animAddHat", cat = "anim", group = "Character", label = "put an accessory on",
	head = "put the accessory {accessory} on {hum}",
	code = "{hum}:AddAccessory({accessory})",
	fields = { hum = "expr|hum|humanoid", accessory = "expr|hat|accessory" },
	doc = "Attaches it to the right place on the head or body on its own, " ..
		"using the attachment inside the accessory.",
	tags = "addaccessory hat accessory wear cosmetic" }

D{ id = "animScale", cat = "anim", group = "Character", label = "resize a character",
	head = "scale {hum} to {n} times its size",
	code = {
		"do",
		'\tlocal scale = {hum}:FindFirstChild("BodyHeightScale")',
		"\tif scale then",
		"\t\tscale.Value = {n}",
		"\tend",
		"end",
	},
	fields = { hum = "expr|hum|humanoid", n = "num|1.2|scale" },
	doc = "R15 characters carry scale values inside the Humanoid. R6 ones do " ..
		"not, which is why this checks first.",
	tags = "scale size r15 height character" }

D{ id = "animRigType", cat = "anim", group = "Character", label = "if it is an R15 character",
	head = "if {hum} is an R15 character then",
	code = "if {hum}.RigType == Enum.HumanoidRigType.R15 then", tail = "end",
	fields = { hum = "expr|hum|humanoid" },
	slots = { { key = "body" } },
	doc = "R6 and R15 have different body parts, so anything that reaches for " ..
		"a limb by name needs to know which it is dealing with.",
	tags = "rigtype r6 r15 character limbs" }

--=============================================================================
-- NPCs
--=============================================================================

D{ id = "npcPath", cat = "npc", group = "Paths", label = "make a path finder",
	head = "make {name} = a path finder",
	code = "local {name} = PathfindingService:CreatePath()",
	fields = { name = "name|path|name" },
	needs = { "PathfindingService" }, side = "server",
	doc = "A Path works out a route round obstacles. Make one and reuse it " ..
		"rather than making a new one every step.",
	tags = "pathfindingservice createpath route navigation" }

D{ id = "npcPathSized", cat = "npc", group = "Paths", label = "make a path finder for a size",
	head = "make {name} = a path finder for something {radius} wide and {height} tall",
	code = {
		"local {name} = PathfindingService:CreatePath({",
		"\tAgentRadius = {radius},",
		"\tAgentHeight = {height},",
		"\tAgentCanJump = {jump},",
		"})",
	},
	fields = { name = "name|path|name", radius = "num|2|radius", height = "num|5|height",
		jump = "choice|true|can jump|true,false" },
	needs = { "PathfindingService" }, side = "server",
	doc = "Telling it the size stops a big NPC routing through a gap it " ..
		"cannot fit through.",
	tags = "agentradius agentheight path size jump" }

D{ id = "npcWorkOutPath", cat = "npc", group = "Paths", label = "work out a route",
	head = "work out a route on {path} from {from} to {to}",
	code = {
		"pcall(function()",
		"\t{path}:ComputeAsync({from}, {to})",
		"end)",
	},
	fields = { path = "expr|path|path", from = "expr|npc.PrimaryPart.Position|from",
		to = "expr|target.Position|to" },
	side = "server",
	doc = "Computing takes a moment and can fail if either end is inside a " ..
		"wall, so it is wrapped.",
	tags = "computeasync path route calculate" }

D{ id = "npcPathWorked", cat = "npc", group = "Paths", label = "if the route worked",
	head = "if {path} found a route then",
	code = "if {path}.Status == Enum.PathStatus.Success then", tail = "end",
	fields = { path = "expr|path|path" },
	slots = { { key = "body" } },
	side = "server",
	doc = "Always check. Walking a failed path sends the NPC to the last " ..
		"place it managed to reach, which looks like a bug.",
	tags = "pathstatus success check route" }

D{ id = "npcEachStep", cat = "npc", group = "Paths", label = "for each step of a route",
	head = "for each step {point} of {path}",
	code = "for _, {point} in ipairs({path}:GetWaypoints()) do", tail = "end",
	fields = { path = "expr|path|path", point = "name|point|step" },
	slots = { { key = "body" } },
	side = "server",
	doc = "Each step has a `Position` and an `Action` saying whether the NPC " ..
		"has to jump to reach it.",
	tags = "getwaypoints waypoints steps path walk" }

D{ id = "npcStepNeedsJump", cat = "npc", group = "Paths", label = "if the step needs a jump",
	head = "if {point} needs a jump then",
	code = "if {point}.Action == Enum.PathWaypointAction.Jump then", tail = "end",
	fields = { point = "expr|point|step" },
	slots = { { key = "body" } },
	side = "server",
	doc = "Goes inside the step loop. Without it an NPC walks into ledges " ..
		"instead of hopping up them.",
	tags = "waypointaction jump path step" }

D{ id = "npcOnPathBlocked", cat = "npc", group = "Paths", label = "on the route being blocked",
	head = "when {path} is blocked, at step {at}",
	code = "{path}.Blocked:Connect(function({at})", tail = "end)",
	fields = { path = "expr|path|path", at = "name|blockedAt|step number" },
	slots = { { key = "body" } },
	side = "server",
	doc = "Fires when something moves into the route after it was worked out. " ..
		"The usual answer is to work the route out again.",
	tags = "blocked path obstacle recompute" }

D{ id = "npcWalkRoute", cat = "npc", group = "Paths", label = "walk a whole route",
	head = "walk {hum} along {path}",
	code = {
		"for _, point in ipairs({path}:GetWaypoints()) do",
		"\tif point.Action == Enum.PathWaypointAction.Jump then",
		"\t\t{hum}.Jump = true",
		"\tend",
		"\t{hum}:MoveTo(point.Position)",
		"\tlocal reached = {hum}.MoveToFinished:Wait()",
		"\tif not reached then",
		"\t\tbreak",
		"\tend",
		"end",
	},
	fields = { hum = "expr|hum|humanoid", path = "expr|path|path" },
	side = "server",
	doc = "The whole walk in one block: jump where needed, wait for each step, " ..
		"and give up if the NPC gets stuck.",
	tags = "movetofinished walk route follow path npc" }

-- following ---------------------------------------------------------------------------
D{ id = "npcWalkTo", cat = "npc", group = "Following", label = "walk to a point",
	head = "make {hum} walk to {where}",
	code = "{hum}:MoveTo({where})",
	fields = { hum = "expr|hum|humanoid", where = "expr|target.Position|where" },
	doc = "Walks in a straight line with no route finding, which is fine in " ..
		"open ground and useless in a maze.",
	tags = "moveto walk straight npc" }

D{ id = "npcWaitArrive", cat = "npc", group = "Following", label = "wait until it arrives",
	head = "make {name} = whether {hum} reached where it was going",
	code = "local {name} = {hum}.MoveToFinished:Wait()",
	fields = { name = "name|arrived|name", hum = "expr|hum|humanoid" },
	doc = "Waits, then says whether it actually got there. It gives up after " ..
		"eight seconds and hands back false.",
	tags = "movetofinished wait arrive timeout npc" }

D{ id = "npcStopWalking", cat = "npc", group = "Following", label = "stop walking",
	head = "make {hum} stop walking",
	code = "{hum}:Move(Vector3.zero)",
	fields = { hum = "expr|hum|humanoid" },
	doc = "Cancels whatever it was walking towards and leaves it standing.",
	tags = "move stop halt npc walk" }

D{ id = "npcNearestPlayer", cat = "npc", group = "Following", label = "the nearest player",
	head = "make {name} = the nearest player to {from}, within {range} studs",
	code = {
		"local {name} = nil",
		"do",
		"\tlocal best = {range}",
		"\tfor _, player in ipairs(Players:GetPlayers()) do",
		"\t\tlocal char = player.Character",
		"\t\tlocal root = char and char:FindFirstChild(\"HumanoidRootPart\")",
		"\t\tif root then",
		"\t\t\tlocal gap = (root.Position - {from}).Magnitude",
		"\t\t\tif gap < best then",
		"\t\t\t\tbest = gap",
		"\t\t\t\t{name} = player",
		"\t\t\tend",
		"\t\tend",
		"\tend",
		"end",
	},
	fields = { name = "name|nearest|name", from = "expr|npc.PrimaryPart.Position|from",
		range = "num|60|how far to look" },
	needs = { "Players" }, side = "server",
	doc = "Walks everyone, skips anyone without a body, and keeps the closest " ..
		"within range. Nil when nobody is near enough.",
	tags = "nearest closest player target range npc" }

D{ id = "npcChase", cat = "npc", group = "Following", label = "chase something",
	head = "make {hum} keep chasing {target} while it is within {range} studs",
	code = {
		"task.spawn(function()",
		"\twhile {target} and {target}.Parent do",
		"\t\tlocal gap = ({target}.Position - {hum}.Parent.PrimaryPart.Position).Magnitude",
		"\t\tif gap > {range} then",
		"\t\t\tbreak",
		"\t\tend",
		"\t\t{hum}:MoveTo({target}.Position)",
		"\t\ttask.wait(0.4)",
		"\tend",
		"end)",
	},
	fields = { hum = "expr|hum|humanoid", target = "expr|targetRoot|what to chase",
		range = "num|60|give up beyond" },
	side = "server",
	doc = "Re-aims a few times a second on its own thread. Cheaper and " ..
		"steadier than doing it every frame.",
	tags = "chase follow pursue npc loop" }

D{ id = "npcWander", cat = "npc", group = "Following", label = "wander about",
	head = "make {hum} wander within {range} studs of {home}",
	code = {
		"task.spawn(function()",
		"\twhile {hum}.Health > 0 do",
		"\t\tlocal spot = {home} + Vector3.new(",
		"\t\t\tmath.random(-{range}, {range}), 0, math.random(-{range}, {range}))",
		"\t\t{hum}:MoveTo(spot)",
		"\t\t{hum}.MoveToFinished:Wait()",
		"\t\ttask.wait(math.random({rest}, {rest} * 2))",
		"\tend",
		"end)",
	},
	fields = { hum = "expr|hum|humanoid", home = "expr|spawnPoint|home position",
		range = "num|20|range", rest = "num|2|pause seconds" },
	side = "server",
	doc = "Picks a random nearby spot, walks there, waits, and repeats until " ..
		"it dies. Idle villagers and animals are this block.",
	tags = "wander idle roam random walk npc" }

D{ id = "npcFace", cat = "npc", group = "Following", label = "turn to face",
	head = "turn {model} to face {target}",
	code = {
		"do",
		"\tlocal from = {model}:GetPivot().Position",
		"\tlocal to = Vector3.new({target}.X, from.Y, {target}.Z)",
		"\t{model}:PivotTo(CFrame.lookAt(from, to))",
		"end",
	},
	fields = { model = "expr|npc|model", target = "expr|target.Position|target position" },
	doc = "Levelling the target's height first stops the NPC tipping over " ..
		"backwards to look up at something.",
	tags = "lookat face turn rotate npc" }

D{ id = "npcCanSee", cat = "npc", group = "Following", label = "if it can see something",
	head = "if {from} can see {to}, ignoring {ignore}, then",
	code = {
		"local canSee = false",
		"do",
		"\tlocal rules = RaycastParams.new()",
		"\trules.FilterType = Enum.RaycastFilterType.Exclude",
		"\trules.FilterDescendantsInstances = {ignore}",
		"\tlocal found = workspace:Raycast({from}, {to} - {from}, rules)",
		"\tcanSee = found == nil or found.Instance:IsDescendantOf({target})",
		"end",
		"if canSee then",
	},
	codeTail = { "end" }, tail = "end",
	fields = { from = "expr|npc.PrimaryPart.Position|from", to = "expr|target.Position|to",
		ignore = "expr|{ npc }|what to ignore", target = "expr|targetModel|the target model" },
	slots = { { key = "body" } },
	side = "server",
	doc = "Fires a ray at the target and calls it visible if nothing solid is " ..
		"in the way. The core of any NPC that should not see through walls.",
	tags = "line of sight raycast see vision npc" }

-- setting one up -------------------------------------------------------------------------
D{ id = "npcSpawn", cat = "npc", group = "Setting up", label = "spawn an NPC",
	head = "make {name} = a copy of {template} at ({x}, {y}, {z})",
	code = {
		"local {name} = {template}:Clone()",
		"{name}:PivotTo(CFrame.new({x}, {y}, {z}))",
		"{name}.Parent = workspace",
	},
	fields = { name = "name|npc|name", template = "expr|game.ServerStorage.Guard|template",
		x = "expr|0|x", y = "expr|5|y", z = "expr|0|z" },
	side = "server",
	doc = "Keep the original in ServerStorage so players never bump into it. " ..
		"PivotTo moves the whole model in one piece.",
	tags = "spawn clone npc enemy place" }

D{ id = "npcHumanoidOf", cat = "npc", group = "Setting up", label = "the humanoid of an NPC",
	head = "make {name} = the humanoid inside {model}",
	code = 'local {name} = {model}:FindFirstChildOfClass("Humanoid")',
	fields = { name = "name|hum|name", model = "expr|npc|model" },
	doc = "Everything an NPC does goes through its Humanoid, exactly as with " ..
		"a player's character.",
	tags = "humanoid npc find model" }

D{ id = "npcNoNameTag", cat = "npc", group = "Setting up", label = "hide the name and health",
	head = "hide the name and health bar over {hum}",
	code = "{hum}.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None",
	fields = { hum = "expr|hum|humanoid" },
	doc = "Stops Roblox drawing the default name plate, so your own floating " ..
		"label is the only one.",
	tags = "displaydistancetype nameplate hide health npc" }

D{ id = "npcOnDied", cat = "npc", group = "Setting up", label = "on an NPC dying",
	head = "when {hum} dies, remove it after {seconds} seconds",
	code = {
		"{hum}.Died:Connect(function()",
		"\ttask.delay({seconds}, function()",
		"\t\tif {hum}.Parent then",
		"\t\t\t{hum}.Parent:Destroy()",
		"\t\tend",
		"\tend)",
		"end)",
	},
	fields = { hum = "expr|hum|humanoid", seconds = "num|4|seconds" },
	side = "server",
	doc = "Leaves the body long enough to be seen, then clears it up. Without " ..
		"this a busy game fills with corpses.",
	tags = "died despawn cleanup corpse npc" }

--=============================================================================
-- TERRAIN AND BUILDING
--=============================================================================

D{ id = "terrainBlock", cat = "terrain", group = "Filling", label = "fill a block",
	head = "fill a {size} stud block of {material} at ({x}, {y}, {z})",
	code = "workspace.Terrain:FillBlock(CFrame.new({x}, {y}, {z}), " ..
		"Vector3.new({size}, {size}, {size}), Enum.Material.{material})",
	fields = { x = "expr|0|x", y = "expr|0|y", z = "expr|0|z", size = "num|16|size",
		material = "choice|Grass|material|Grass,Sand,Rock,Snow,Ice,Mud,Water,Air,Sandstone,Basalt,Asphalt,LeafyGrass" },
	doc = "Terrain is filled by shape rather than placed by part. A block of " ..
		"Air is how you dig a hole.",
	tags = "terrain fillblock material ground dig" }

D{ id = "terrainBall", cat = "terrain", group = "Filling", label = "fill a ball",
	head = "fill a ball of {material}, {radius} studs across, at ({x}, {y}, {z})",
	code = "workspace.Terrain:FillBall(Vector3.new({x}, {y}, {z}), {radius}, " ..
		"Enum.Material.{material})",
	fields = { x = "expr|0|x", y = "expr|0|y", z = "expr|0|z", radius = "num|10|radius",
		material = "choice|Rock|material|Grass,Sand,Rock,Snow,Ice,Mud,Water,Air,Sandstone,Basalt" },
	doc = "Balls make softer shapes than blocks. A ball of Air carves a cave.",
	tags = "terrain fillball sphere cave carve" }

D{ id = "terrainCylinder", cat = "terrain", group = "Filling", label = "fill a pillar",
	head = "fill a pillar of {material}, {radius} across and {height} tall, at ({x}, {y}, {z})",
	code = "workspace.Terrain:FillCylinder(CFrame.new({x}, {y}, {z}), {height}, " ..
		"{radius}, Enum.Material.{material})",
	fields = { x = "expr|0|x", y = "expr|0|y", z = "expr|0|z", radius = "num|6|radius",
		height = "num|20|height",
		material = "choice|Rock|material|Grass,Sand,Rock,Snow,Ice,Water,Air,Basalt" },
	doc = "Towers, wells and tree trunks. Fill with Air to bore a shaft.",
	tags = "terrain fillcylinder pillar tower shaft" }

D{ id = "terrainDig", cat = "terrain", group = "Filling", label = "dig a hole",
	head = "dig a ball {radius} studs across at ({x}, {y}, {z})",
	code = "workspace.Terrain:FillBall(Vector3.new({x}, {y}, {z}), {radius}, " ..
		"Enum.Material.Air)",
	fields = { x = "expr|0|x", y = "expr|0|y", z = "expr|0|z", radius = "num|8|radius" },
	doc = "Filling with Air removes terrain. This is the whole of a digging " ..
		"tool or an explosion crater.",
	tags = "dig air remove crater explosion terrain" }

D{ id = "terrainWater", cat = "terrain", group = "Filling", label = "add water",
	head = "fill a {size} stud block of water at ({x}, {y}, {z})",
	code = "workspace.Terrain:FillBlock(CFrame.new({x}, {y}, {z}), " ..
		"Vector3.new({size}, {size}, {size}), Enum.Material.Water)",
	fields = { x = "expr|0|x", y = "expr|-10|y", z = "expr|0|z", size = "num|64|size" },
	doc = "Water is terrain like any other material, and characters swim in " ..
		"it automatically.",
	tags = "water swim terrain sea lake" }

D{ id = "terrainClear", cat = "terrain", group = "Filling", label = "clear all terrain",
	head = "clear all terrain",
	code = "workspace.Terrain:Clear()",
	doc = "Removes every voxel in the place. There is no undo for this at " ..
		"runtime, so be sure.",
	tags = "clear terrain wipe empty reset" }

D{ id = "terrainSwap", cat = "terrain", group = "Filling", label = "swap a material",
	head = "turn all {from} within a {size} stud block at ({x}, {y}, {z}) into {to}",
	code = {
		"workspace.Terrain:ReplaceMaterial(",
		"\tRegion3.new(",
		"\t\tVector3.new({x} - {size}, {y} - {size}, {z} - {size}),",
		"\t\tVector3.new({x} + {size}, {y} + {size}, {z} + {size})),",
		"\t4, Enum.Material.{from}, Enum.Material.{to})",
	},
	fields = { x = "expr|0|x", y = "expr|0|y", z = "expr|0|z", size = "num|64|size",
		from = "choice|Grass|from|Grass,Sand,Rock,Snow,Ice,Mud,Water,LeafyGrass",
		to = "choice|Snow|to|Grass,Sand,Rock,Snow,Ice,Mud,Water,LeafyGrass" },
	doc = "Repaints terrain without changing its shape. Turning grass to snow " ..
		"is how a season change is done.",
	tags = "replacematerial region3 repaint season terrain" }

D{ id = "terrainColour", cat = "terrain", group = "Filling", label = "recolour a material",
	head = "colour all {material} terrain red {r} green {g} blue {b}",
	code = "workspace.Terrain:SetMaterialColor(Enum.Material.{material}, " ..
		"Color3.fromRGB({r}, {g}, {b}))",
	fields = { material = "choice|Grass|material|Grass,Sand,Rock,Snow,Ice,Mud,LeafyGrass",
		r = "num|120|red", g = "num|150|green", b = "num|90|blue" },
	doc = "Changes the tint of one material everywhere at once, which is the " ..
		"cheapest way to give a place its own look.",
	tags = "setmaterialcolor terrain tint colour style" }

-- building ---------------------------------------------------------------------------------
D{ id = "buildPlace", cat = "terrain", group = "Building", label = "place a copy",
	head = "make {name} = a copy of {template} at ({x}, {y}, {z})",
	code = {
		"local {name} = {template}:Clone()",
		"{name}:PivotTo(CFrame.new({x}, {y}, {z}))",
		"{name}.Parent = workspace",
	},
	fields = { name = "name|placed|name", template = "expr|game.ServerStorage.Tree|template",
		x = "expr|0|x", y = "expr|0|y", z = "expr|0|z" },
	doc = "Clone, move, then parent. Doing it in that order means nobody sees " ..
		"it appear at the origin first.",
	tags = "clone place model build spawn" }

D{ id = "buildSnap", cat = "terrain", group = "Building", label = "snap to a grid",
	head = "make {name} = {value} snapped to the nearest {grid} studs",
	code = "local {name} = math.round({value} / {grid}) * {grid}",
	fields = { name = "name|snapped|name", value = "expr|mouse.Hit.Position.X|value",
		grid = "num|4|grid size" },
	doc = "The whole of grid snapping. Divide, round, multiply back -- it " ..
		"works for any spacing.",
	tags = "snap grid round placement building" }

D{ id = "buildAnchorAll", cat = "terrain", group = "Building", label = "anchor a whole model",
	head = "anchor everything inside {model}",
	code = {
		"for _, part in ipairs({model}:GetDescendants()) do",
		'\tif part:IsA("BasePart") then',
		"\t\tpart.Anchored = true",
		"\tend",
		"end",
	},
	fields = { model = "expr|model|model" },
	doc = "One unanchored part is enough to make a whole building sag. This " ..
		"catches every one of them.",
	tags = "anchor model parts building stable" }

D{ id = "buildWeldAll", cat = "terrain", group = "Building", label = "weld a whole model",
	head = "weld everything inside {model} to {main}",
	code = {
		"for _, part in ipairs({model}:GetDescendants()) do",
		'\tif part:IsA("BasePart") and part ~= {main} then',
		'\t\tlocal weld = Instance.new("WeldConstraint")',
		"\t\tweld.Part0 = {main}",
		"\t\tweld.Part1 = part",
		"\t\tweld.Parent = {main}",
		"\t\tpart.Anchored = false",
		"\tend",
		"end",
	},
	fields = { model = "expr|model|model", main = "expr|model.PrimaryPart|main part" },
	doc = "Holds a model together so it moves as one object. Unanchoring the " ..
		"welded parts is what lets the main part carry them.",
	tags = "weld model together join vehicle" }

D{ id = "buildPaintAll", cat = "terrain", group = "Building", label = "paint a whole model",
	head = "paint everything inside {model} red {r} green {g} blue {b}",
	code = {
		"for _, part in ipairs({model}:GetDescendants()) do",
		'\tif part:IsA("BasePart") then',
		"\t\tpart.Color = Color3.fromRGB({r}, {g}, {b})",
		"\tend",
		"end",
	},
	fields = { model = "expr|model|model", r = "num|200|red", g = "num|60|green",
		b = "num|60|blue" },
	doc = "Recolours a whole build at once, which is how team-coloured bases " ..
		"are made from one template.",
	tags = "paint colour model team recolour" }

D{ id = "buildMainPart", cat = "terrain", group = "Building", label = "set the main part",
	head = "make {part} the main part of {model}",
	code = "{model}.PrimaryPart = {part}",
	fields = { model = "expr|model|model", part = "expr|model.Base|part" },
	doc = "The main part is what a model is measured and moved from. A model " ..
		"without one cannot be pivoted reliably.",
	tags = "primarypart model pivot main" }

D{ id = "buildResize", cat = "terrain", group = "Building", label = "resize a model",
	head = "scale {model} by {n}",
	code = "{model}:ScaleTo({n})",
	fields = { model = "expr|model|model", n = "num|2|scale" },
	doc = "Scales every part, weld and attachment together, which doing it by " ..
		"hand almost never gets right.",
	tags = "scaleto resize model grow shrink" }

D{ id = "buildSize", cat = "terrain", group = "Building", label = "how big a model is",
	head = "make {name} = how big {model} is",
	code = "local {name} = {model}:GetExtentsSize()",
	fields = { name = "name|size|name", model = "expr|model|model" },
	doc = "The size of the box that just contains the whole model, as a " ..
		"Vector3.",
	tags = "getextentssize bounds size model" }

D{ id = "buildCountParts", cat = "terrain", group = "Building", label = "count the parts",
	head = "make {name} = how many parts are inside {model}",
	code = {
		"local {name} = 0",
		"for _, part in ipairs({model}:GetDescendants()) do",
		'\tif part:IsA("BasePart") then',
		"\t\t{name} = {name} + 1",
		"\tend",
		"end",
	},
	fields = { name = "name|partCount|name", model = "expr|model|model" },
	doc = "Worth checking against a limit if players can build -- a thousand " ..
		"part house will hurt everyone in the server.",
	tags = "count parts model limit performance" }

D{ id = "buildRow", cat = "terrain", group = "Building", label = "place a row of copies",
	head = "place {count} copies of {template} in a row from ({x}, {y}, {z}), {gap} studs apart",
	code = {
		"for index = 1, {count} do",
		"\tlocal copy = {template}:Clone()",
		"\tcopy:PivotTo(CFrame.new({x} + (index - 1) * {gap}, {y}, {z}))",
		"\tcopy.Parent = workspace",
		"end",
	},
	fields = { template = "expr|game.ServerStorage.Fence|template", count = "num|10|how many",
		x = "expr|0|x", y = "expr|0|y", z = "expr|0|z", gap = "num|8|gap" },
	doc = "Fences, pillars and street lights. Change which coordinate the " ..
		"index is added to for a different direction.",
	tags = "row repeat place fence loop build" }

D{ id = "buildRandomSpot", cat = "terrain", group = "Building", label = "a random spot nearby",
	head = "make {name} = a random spot within {range} studs of {centre}",
	code = "local {name} = {centre} + Vector3.new(math.random(-{range}, {range}), " ..
		"0, math.random(-{range}, {range}))",
	fields = { name = "name|spot|name", centre = "expr|Vector3.new(0, 5, 0)|centre",
		range = "num|30|range" },
	doc = "Scatters things on the flat. Raycast downward from the result if " ..
		"you want it to sit on uneven ground.",
	tags = "random spot scatter spawn position" }

end
