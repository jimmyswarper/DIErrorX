# ABlocks

A block coding plugin for Roblox Studio. Drag blocks, read the Luau they write
in the panel beside them, and take the script with you when you outgrow them.

It also runs backwards: select a Script, LocalScript or ModuleScript in the
Explorer and the Import tab turns it into an editable canvas — then writes your
changes straight back into that same script.

```
┌──────────────────────────────────────────────────────────────────────┐
│ ≡ ABlocks   BUILD  LEARN  IMPORT  SETUP              First project  ◑│
├──────────────┬───────────────────────────────┬───────────────────────┤
│ / search     │  ╭─╨──────────────────────╮   │ Script      12 lines  │
│ fits Script  │  │ when (script.Parent)   │   │ ───────────────────── │
│              │  │ is touched by (hit)    │   │ 1  script.Parent      │
│ STARRED      │  │  ╭─╨─────────────────╮ │   │ 2    .Touched:Connect │
│ ╭─╨────────╮ │  │  │ make (hum) = the  │ │   │ 3    local hum = hit  │
│ │ print    │ │  │  │ humanoid of (hit) │ │   │ 4    if not hum then  │
│ ╰─╥────────╯ │  │  ╰─┬─────────────────╯ │   │ 5      return         │
│              │  │  ╭─╨─────────────────╮ │   │ 6    end              │
│ E Events  31 │  │  │ stop unless (hum) │ │   │ 7    hum:TakeDamage(9)│
│ C Control 30 │  │  ╰─┬─────────────────╯ │   │ 8  end)               │
│ U Interfa 69 │  ╰─┬──────────────────────╯   │ 9                     │
├──────────────┴───────────────────────────────┴───────────────────────┤
│ undo redo tidy 100% save            Script   copy   Update Trap      │
├──────────────────────────────────────────────────────────────────────┤
│ converted Trap                     14 blocks  3 stacks  saved 14:02  │
└──────────────────────────────────────────────────────────────────────┘
```

## Installing

**Without any tooling.** `dist/ABlocks.rbxmx` is committed, ready to install.
In Studio: **Plugins → Plugins Folder**, copy the file in, and restart Studio.
(Or drag it into Studio, right-click the model in the Explorer, and choose
*Save as Local Plugin*.)

To rebuild it after changing anything in `src/`:

```sh
python3 tools/build.py          # rewrites dist/ABlocks.rbxmx
```

`tools/test.sh` fails if that file has drifted from the source.

**With [Rojo](https://rojo.space).** The repository is a Rojo project already:

```sh
rojo build -o ABlocks.rbxmx    # same file, via Rojo
rojo serve                      # or live-sync while working on it
```

A toolbar button called **Blocks** appears under an **ABlocks** tab. The window
is a dock widget, so it can float or snap anywhere in Studio.

The first time you convert a script or write one out, Studio will ask whether
the plugin may read and edit script source. It needs that permission for both
directions; nothing else in the plugin touches your game.

## What is in it

**680 blocks across 27 categories.** Ten teach the language — events, control,
logic, math, text, variables, functions, instances, players, data — and fifteen
cover the systems you reach for next: interface, camera and light, sound,
saving, networking, shop, places, physics, animation, NPCs, terrain, lists and
sorting, text patterns, space and angles, debug and timing. Then a category of
your own blocks, and an escape hatch for raw Luau. Every block declares what it
looks like and what it compiles to on the same line, so the canvas and the code
can never drift apart.

**Blocks you make yourself.** A block of yours is Luau with `{holes}` in it —
each hole becomes a field, and a hole alone on a line becomes a slot you can
drop other blocks into. Write one by hand, or point at a stack on the canvas, a
`define` block, or a whole ModuleScript and get blocks back. See
[below](#making-your-own-blocks).

**32 tutorials**: one for each of the ten teaching categories, five for the
bigger systems, and seventeen on technique — snapping, reading the code panel,
server versus client, loops that do not freeze the game, error messages
translated, tags and attributes, and how to tell when you have outgrown blocks.
Most carry a runnable example that the lesson can rebuild on your canvas in one
click.

**IntelliSense** in every expression field. It knows the difference between `.`
and `:`, resolves types through property chains, reads your own variables out of
the document — a `make door = a new Part` block above teaches it that `door.`
should offer `Anchored` — completes class names inside `Instance.new("`, offers
the functions your own blocks compile to, and shows signature help while the
caret is inside a call. Matching is fuzzy, so `ffc` finds `FindFirstChild`.

**A Luau importer** that handles the whole language: types, string
interpolation, `+=`, `continue`, nested closures. Two rules keep it honest —
nothing is ever discarded (unrecognised statements are preserved verbatim in raw
blocks), and a pattern is only matched when the block writes back exactly the
same code. Import then export is stable, which is checked by tests.

## Working from a script you already have

The Import tab watches your Explorer selection. Click a script and it shows the
name, its full path, its kind and how long it is; one button converts it.

Converting **ties the project to that script**. The button in the bottom bar
changes from *Insert Script* to *Update Trap*, and writes the code back into the
same script rather than leaving a second copy beside it. Select, convert,
rearrange, update.

A project with no origin goes wherever its kind belongs:

| kind | goes to |
|---|---|
| `Script` | `ServerScriptService` |
| `LocalScript` | `StarterPlayer.StarterPlayerScripts` |
| `ModuleScript` | `ReplicatedStorage` |

Those are defaults, changeable per kind on the Setup tab. Picking a kind by hand
unties the project from the script it was read from, since it cannot be both.

The code panel also checks the code against the kind it is headed for: a
ModuleScript that never returns anything, a LocalScript reaching for
ServerStorage, a server Script asking for `Players.LocalPlayer`. Rules of thumb
rather than analysis, but they catch the mistake that costs beginners an
afternoon.

## Making your own blocks

Everything above is the language and the API. The part that is yours — award
coins, respawn at a checkpoint, fade a label out and back — becomes a block of
your own.

A custom block has exactly one representation: **Luau with holes in it.**

```lua
{who}.Humanoid.Health += {amount}
```

That is a block reading `Heal someone {who} {amount}` with two fields on it. A
placeholder that sits *alone on a line* is the one special case — it becomes a
slot, a mouth the block opens so other blocks can go inside:

```lua
if {who}:GetAttribute("Admin") then
	{body}
end
```

Four ways to get one, all landing in the same editor with a live preview:

| route | where |
|---|---|
| write the Luau yourself | **New block**, in the palette or on Setup |
| a stack already on the canvas | right-click → **Make into a block** |
| a `define` block in the project | right-click it → **Make into a block** |
| every function a ModuleScript exports | select it → **Load from a ModuleScript** |

**What it costs in the generated script.** A block with no slots is written out
once, as a real `local function`, however many times you use it — ten uses cost
one function and ten short calls. A block *with* slots is inlined at each use,
because the blocks you dropped inside it differ every time.

You can also open one of your blocks **as a canvas** and edit its insides with
blocks, then save it back; the placeholders travel as ordinary names while you
are in there. This works because the importer is stable — the same property
that makes converting a script safe makes editing a block safe.

Your library lives in your Studio settings, and projects carry a copy of every
block they use, so opening someone else's project adds their blocks rather than
breaking. When a library is worth keeping, **Setup → your blocks → Save to a
ModuleScript** writes the whole thing out as a plain Luau table you can commit,
share or drop into another game — and **Load from a ModuleScript** reads it
back. The reader uses the plugin's own parser and accepts only constants, so
loading someone's library cannot run their code.

## How the blocks look and move

Blocks are filled slabs of their category's colour with a notch bitten out of
the top edge. What fills that notch is whatever the block is sitting on: the
canvas when nothing is above it, so the cut is visible, or the block above it,
so the joint reads as interlocked. Every run ends with the matching tab. A
container block is a C — an arm down the left, and the canvas showing through
its mouth.

**A block is picked up by holding the left button on it**, not by clicking and
dragging. It lifts after a moment, casts a shadow, and follows the mouse; a
quick click just selects, so you can read your way down a stack without pulling
it apart. While you are carrying one, an amber socket — a bar with a tab
standing on it — shows exactly where it will fit.

The wording on a block is set in the interface face because it is a sentence;
the fields are monospace pills because they are Luau. Category colours are
darkened until pale writing on them clears 4.5:1, by rule rather than by hand,
which is checked for all 27 categories in both themes by the UI suite.

## A design decision worth knowing about

Statements are blocks; expressions are typed into fields.

Most block editors make expressions into blocks too, so `hp <= 0` is three
nested puzzle pieces. That looks tidy in a screenshot and is miserable to edit,
and it means any expression the editor does not model cannot be written at all.

Here, `hp <= 0` is text in a field with completion behind it. The cost is that
you type; the return is that every Luau expression is expressible, imported code
round-trips byte-for-byte, and IntelliSense has somewhere useful to live. The
structure that actually matters for learning — what runs when, what is nested
inside what — is still blocks.

## The code

Twenty-three modules, one letter each, in `src/`:

| | |
|---|---|
| `a` | theme: colours, type, spacing, ink/paper switching |
| `b` | interface primitives over `Instance.new` |
| `c` | the block registry — mechanics, categories, and the core blocks |
| `d` | the document model: blocks, slots, stacks, save format |
| `e` | code generation, service hoisting, `elseif` collapsing |
| `f` | Luau lexer (also drives syntax highlighting) |
| `g` | Luau parser, recording byte spans |
| `h` | Luau → blocks importer |
| `i` | IntelliSense: API surface, type resolution, fuzzy matching |
| `j` | the 32 tutorials |
| `k` | tutorials tab |
| `l` | palette |
| `m` | canvas: block shapes, dragging, snapping, zoom, field editing |
| `n` | code panel, import tab, settings |
| `o` | application state, undo, projects, saving |
| `p` | the window: top tabs, bottom action bar, keyboard |
| `q` | custom blocks: shape, compilation, the four creation routes, sharing |
| `r` | the block editor, and the banner shown while editing one as a canvas |
| `s`–`w` | the other 553 block definitions, grouped by subject |

`src/init.server.luau` is the plugin script itself and does nothing but make the
toolbar button and hand over to `p`.

### Adding a block

One entry in `src/c.luau` (or in `s`–`w`, whichever subject fits):

```lua
D{ id = "shout", cat = "text", label = "shout",
	head = 'shout "{msg}"', code = 'print(string.upper("{msg}"))',
	fields = { msg = "str|hello|message" },
	doc = "Prints in capitals, for when print is not loud enough.",
	tags = "print upper loud" }
```

`head` is what appears on the canvas, `code` is what it compiles to, and
`{msg}` refers to the field declared below. Slots (`slots = {{key="body"}}`)
make it a container; `tail = "end"` closes it. `group` puts it under a
sub-heading inside its category, and `side = "server"` or `"client"` lets the
palette filter it out when the project is heading for the wrong kind of script.
That is the whole extension point — the palette, search, tooltips, code
generation and tests all pick it up from there.

### Teaching the importer a new pattern

`src/h.luau` maps AST shapes onto blocks. Only add a mapping when the block
emits exactly what it matched, or the round-trip test will say so.

### Writing a lesson

One entry in `src/j.luau`, with `steps` made of tagged tables (`p`, `h`, `code`,
`list`, `note`, `warn`, `try`, `blocks`) and an optional `example` of real Luau.
The tests check that examples import, round-trip, and mostly convert to real
blocks rather than raw ones.

## Tests

Everything here runs against the standalone
[Luau CLI](https://github.com/luau-lang/luau/releases) — no Studio needed:

```sh
tools/test.sh                # or LUAU=/path/to/luau tools/test.sh
```

```
syntax
  ok    24 modules compile
suites
  ok    blocks (4403 checks)         every block emits valid Luau
  ok    custom blocks (61 checks)    making, compiling, sharing your own
  ok    intellisense (46 checks)     contexts, type resolution, ranking
  ok    parser (109 checks)          lexer and parser against real scripts
  ok    roundtrip (21 checks)        code → blocks → code is stable
  ok    tutorials (1051 checks)      examples import; prose claims hold up
  ok    ui (480 checks)              the whole plugin, mounted headlessly
```

The UI suite is the unusual one. `tests/mock.luau` is a small Roblox stand-in —
instances, signals, services, a real JSON implementation — strict enough to
reject any property name Roblox does not have. The suite mounts the entire
plugin against it, renders all 680 blocks and all 32 lessons, drags a block into
a loop, imports a script, makes a block of its own and uses it, saves the
library out to a ModuleScript and reads it back, undoes it all and switches
themes. It has found ten real bugs so far, including one that would have
crashed Studio on the first click.

`tools/bundle.py` stitches the modules together for the CLI, since Roblox's
`require(script.Parent.x)` has no meaning outside Studio.
