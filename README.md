# DIErrorX

A block coding plugin for Roblox Studio. Drag blocks, read the Luau they write
in the panel beside them, and take the script with you when you outgrow them.

It also runs backwards: paste an existing Luau script into the Import tab and
get an editable canvas back.

```
┌────┬───────────────────────────────────────────────────────────────────┐
│ B  │  First project            undo  redo  tidy  100%  save            │
│ U  ├──────────────┬──────────────────────────────┬─────────────────────┤
│ I  │  / search    │  ▏when script.Parent is      │  1  script.Parent   │
│ L  │              │  ▏  touched by hit           │  2    .Touched:Conn │
│ D  │  E Events  13│  ▏  ┌ make hum = the         │  3    local hum = h │
│    │  C Control 16│  ▏  │   humanoid of hit.Parent│  4    if not hum t │
│ L  │  ? Logic   12│  ▏  │ stop here unless hum   │  5      return     │
│ E  │  N Math    11│  ▏  └ teleport hit.Parent to │  6    end          │
│ A  │  T Text    13│  ▏    (0, 10, 0)             │  7    hit.Parent:P │
│ R  │  x Vars    10│                              │                     │
│ N  │  f Funcs    9│                              │  Insert script  Copy│
├────┴──────────────┴──────────────────────────────┴─────────────────────┤
│ ready                          14 blocks   3 stacks   saved            │
└────────────────────────────────────────────────────────────────────────┘
```

## Installing

**Without any tooling.** `dist/DIErrorX.rbxmx` is committed, ready to install.
In Studio: **Plugins → Plugins Folder**, copy the file in, and restart Studio.
(Or drag it into Studio, right-click the model in the Explorer, and choose
*Save as Local Plugin*.)

To rebuild it after changing anything in `src/`:

```sh
python3 tools/build.py          # rewrites dist/DIErrorX.rbxmx
```

`tools/test.sh` fails if that file has drifted from the source.

**With [Rojo](https://rojo.space).** The repository is a Rojo project already:

```sh
rojo build -o DIErrorX.rbxmx    # same file, via Rojo
rojo serve                      # or live-sync while working on it
```

A toolbar button called **Blocks** appears under a **DIErrorX** tab. The window
is a dock widget, so it can float or snap anywhere in Studio.

The first time you press *Insert script*, Studio will ask whether the plugin may
edit scripts. It needs that permission to write the generated code into your
place; nothing else in the plugin touches your game.

## What is in it

**127 blocks across ten categories** — events, control, logic, math, text,
variables, functions, instances, players and data — plus an escape hatch for raw
Luau. Every block declares what it looks like and what it compiles to on the
same line, so the canvas and the code can never drift apart.

**26 tutorials**, one per category and sixteen more on technique: snapping,
reading the code panel, server versus client, loops that do not freeze the game,
error messages translated, tags and attributes, and how to tell when you have
outgrown blocks. Most carry a runnable example that the lesson can rebuild on
your canvas in one click.

**IntelliSense** in every expression field. It knows the difference between `.`
and `:`, resolves types through property chains, reads your own variables out of
the document — a `make door = a new Part` block above teaches it that `door.`
should offer `Anchored` — completes class names inside `Instance.new("`, and
shows signature help while the caret is inside a call. Matching is fuzzy, so
`ffc` finds `FindFirstChild`.

**A Luau importer** that handles the whole language: types, string
interpolation, `+=`, `continue`, nested closures. Two rules keep it honest —
nothing is ever discarded (unrecognised statements are preserved verbatim in raw
blocks), and a pattern is only matched when the block writes back exactly the
same code. Import then export is stable, which is checked by tests.

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

Sixteen modules, one letter each, in `src/`:

| | |
|---|---|
| `a` | theme: colours, type, spacing, ink/paper switching |
| `b` | interface primitives over `Instance.new` |
| `c` | the block registry — 127 definitions, wording and Luau together |
| `d` | the document model: blocks, slots, stacks, save format |
| `e` | code generation, service hoisting, `elseif` collapsing |
| `f` | Luau lexer (also drives syntax highlighting) |
| `g` | Luau parser, recording byte spans |
| `h` | Luau → blocks importer |
| `i` | IntelliSense: API surface, type resolution, fuzzy matching |
| `j` | the 26 tutorials |
| `k` | tutorials tab |
| `l` | palette |
| `m` | canvas: rendering, dragging, snapping, zoom, field editing |
| `n` | code panel, import tab, settings |
| `o` | application state, undo, projects, saving |
| `p` | the window: rail, bars, tabs, keyboard |

`src/init.server.luau` is the plugin script itself and does nothing but make the
toolbar button and hand over to `p`.

### Adding a block

One entry in `src/c.luau`:

```lua
D{ id = "shout", cat = "text", label = "shout",
	head = 'shout "{msg}"', code = 'print(string.upper("{msg}"))',
	fields = { msg = "str|hello|message" },
	doc = "Prints in capitals, for when print is not loud enough.",
	tags = "print upper loud" }
```

`head` is what appears on the canvas, `code` is what it compiles to, and
`{msg}` refers to the field declared below. Slots (`slots = {{key="body"}}`)
make it a container; `tail = "end"` closes it. That is the whole extension
point — the palette, search, tooltips, code generation and tests all pick it up
from there.

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
  ok    17 modules compile
suites
  ok    blocks (816 checks)          every block emits valid Luau
  ok    intellisense (46 checks)     contexts, type resolution, ranking
  ok    parser (65 checks)           lexer and parser against real scripts
  ok    roundtrip (20 checks)        code → blocks → code is stable
  ok    tutorials (823 checks)       examples import; prose claims hold up
  ok    ui (102 checks)              the whole plugin, mounted headlessly
```

The UI suite is the unusual one. `tests/mock.luau` is a small Roblox stand-in —
instances, signals, services, a real JSON implementation — strict enough to
reject any property name Roblox does not have. The suite mounts the entire
plugin against it, renders all 127 blocks and all 26 lessons, drags a block into
a loop, imports a script, undoes it and switches themes. It found three real
bugs while it was being written.

`tools/bundle.py` stitches the modules together for the CLI, since Roblox's
`require(script.Parent.x)` has no meaning outside Studio.
