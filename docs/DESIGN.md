# Design notes

Why the plugin looks and works the way it does. Useful if you are extending it
and want the additions to feel like they belong.

## The look: a drafting table, not a toybox

Block editors tend to look like toys — rounded jelly-bean shapes, saturated
primaries, a lot of gradient. That reads as "this is not real programming",
which is exactly the wrong message for a tool whose whole point is that the
Luau it writes is real.

So the reference here is technical drafting and printed manuals:

- **Ink or paper.** Two themes, both low-chroma: a deep blue-black board or a
  warm off-white sheet. Nothing glows.
- **Hairlines, not cards.** Structure comes from 1px rules and negative space.
  There is exactly one drop shadow in the plugin, on a lifted drag, and it is a
  hard offset like paper off a table rather than a soft blur.
- **Sharp corners.** 2px radius on things you click, 0 everywhere else.
- **One accent.** Ochre. It marks the current thing and nothing else — the
  active tab, the selected block, the drop indicator, the primary button.
- **Printing inks for categories.** A dozen muted hues, all roughly equal in
  weight, so a full canvas reads as a document rather than a bag of sweets.
  Twenty-seven categories share them rather than each getting one, because
  twenty-seven distinguishable colours do not exist at this chroma and a
  category is already named in the palette. A category shows as a 3px spine on
  the left edge of a block; that is all.
- **Monospace where it is code.** Block wording, fields, the code panel and the
  status bar are all `Enum.Font.Code`. Chrome — buttons, tabs, headings — is
  Gotham. The split tells you at a glance which text is yours and which is the
  application's.
- **A dot-free grid.** The canvas is ruled like graph paper, minor lines every
  20 studs of canvas space and a stronger line every fifth, drawn as offset
  frames repositioned on pan so the count stays constant.
- **No emoji, anywhere.** Icons are drawn from primitives: the chevron is two
  rotated hairlines, the category chip is a letter, the wordmark is three
  bars. Nothing depends on a font having a particular glyph.
- **Tabs on top, verbs on the bottom.** Tabs are text with a 2px accent rule
  under the active one — no pills, no filled shapes. The bottom bar holds the
  two things you actually do (undo, and write the script out), so they stay put
  whichever tab you are on, and a thin status strip runs beneath it.

Everything sits on a 4px grid; block rows are 26px so a stack lines up with the
canvas grid at 100% zoom.

### Six hundred and eighty blocks in a list you can still read

A palette of 680 is a different problem from a palette of 127, and the answer is
four cuts rather than one long list:

- **Categories collapse.** One is open at a time; the rest are one line each.
- **Subgroups inside them.** A category declares a `group` per block, so
  Interface arrives as *screens · boxes · text · buttons · images · layout ·
  motion · input*, not sixty-nine rows in a row.
- **Starred and recent, above everything.** Star what you use; the last dozen
  blocks you placed sit under it. In practice this is the palette most of the
  time, and the categories are for finding something new.
- **A side filter.** Blocks declare `side = "server"` or `"client"` where it
  matters. Set the filter to *fits* and a project heading for a LocalScript
  stops offering DataStore blocks. It is off by default, because a filter you
  did not ask for looks like a bug.

Search cuts across all of it and groups its hits by category, so a search for
"part" tells you which subject you are wandering into.

## The one structural decision

**Statements are blocks. Expressions are text fields with completion.**

The alternative — expression blocks all the way down — makes `hp <= 0` into
three nested puzzle pieces. It photographs well and it is miserable to edit,
and worse, anything the editor does not model cannot be expressed at all.

The cost of the hybrid is that you type. What it buys:

- every Luau expression is writable, so there is no ceiling;
- imported code round-trips byte for byte, because expressions are copied out
  of the source rather than re-modelled and re-printed;
- IntelliSense has somewhere to live, and becomes the main teaching surface;
- blocks stay small enough to read a whole stack at a glance.

The structure that matters pedagogically — what runs when, what is nested
inside what, what the shape of a program is — is still entirely blocks.

## Blocks made by the person using it

The registry is fixed at build time; a game is not. Somewhere past the two
hundredth block it stops being possible to guess what someone needs, and the
honest answer is to let them write it.

**One representation, not two.** A custom block is Luau with `{holes}` in it.
Not a visual builder, not a schema, not a second little language — the same
thing the built-in blocks are made of, written by hand. Everything else is
derived: the fields come from the holes, the wording defaults to the label plus
the holes, the tooltip shows the Luau with defaults filled in.

**One special case, and it pays for itself.** A placeholder alone on a line
becomes a *slot* rather than a field. That is the whole grammar for containers,
and it means `if {who}:GetAttribute("Admin") then / {body} / end` is a block you
can drop other blocks into.

**Slots decide how it compiles.** No slots means the body is fixed, so it is
hoisted into one `local function` and every use is a call. Slots mean the body
differs per use, so it is inlined. The writer notices when an imported script
already declares that function and does not write a second one — which is what
makes a script with custom blocks in it round-trip.

**Four routes, one editor.** Typed Luau, a stack on the canvas, a `define`
block, or every function a ModuleScript exports. They all produce the same
table and open the same editor, so there is one thing to learn and one thing to
test.

**Editing a block as blocks falls out of the importer.** `{x}` is rewritten to
`__x`, the result is imported like any other script, edited, exported, and
rewritten back. It needs no new machinery because the importer is already
stable — the property that makes converting a script trustworthy makes this
trustworthy too.

**Sharing is a ModuleScript, and reading one cannot run it.** The library
serialises to a plain Luau table, which is readable, diffable and hand-editable.
Reading it back goes through the plugin's own parser and a constant evaluator
that accepts strings, numbers, booleans and tables — never a call, never an
index. Loading someone's library is therefore safe in the way `loadstring` would
not have been.

## Rules the code follows

**One definition per block.** A definition holds the canvas wording and the
Luau on the same line. Anything derived from a block — palette entry, search
text, tooltip, code, the field editors, the tests — comes from that one entry.
`src/c.luau` owns the mechanics and the core categories; `s` through `w` are
nothing but definitions, split by subject to keep any one file openable. They
are passed the `define` function rather than requiring `c`, which is what keeps
that from being a cycle. Custom blocks compile to exactly the same shape, so
nothing downstream knows the difference — the code writer reads `def.custom`
rather than requiring the custom-block module, for the same reason.

**The importer only claims what it can give back.** A pattern is matched only
when the block emits exactly the code it matched. `hum.WalkSpeed = 24` becomes
a walk-speed block; `hum.JumpPower = 50` deliberately stays raw, because that
block writes two lines. This is what makes import-then-export stable, and it is
checked by `tests/roundtrip.luau`.

**Nothing is ever discarded.** Unrecognised statements become raw blocks with
the original source text. The worst case for an import is a canvas of raw
blocks that still runs perfectly.

**Layout belongs to Roblox.** Blocks are auto-sizing frames with list layouts,
so a field growing as you type widens its block and every parent, with no
measuring code. The only geometry the plugin computes itself is where the drop
indicator goes, because the engine cannot know that.

**Views never touch the document.** They go through `app:mutate`, which
snapshots for undo and emits one change event. That is why undo, autosave and
the live code panel are not each other's problem.

**Interactions that have already happened use `app:mark` and `app:commit`.**
Typing in a field and dragging a stack both change the document before the user
has finished; the snapshot is taken when the interaction starts and committed
when it ends, so one drag is one undo step.

## Testing something with no Studio

`tests/mock.luau` is a Roblox stand-in: instances with a real parent/child tree,
signals, services, a JSON implementation, and a property whitelist that rejects
any name Roblox does not have. `tests/ui.luau` mounts the whole plugin against
it and drives it.

It is not a substitute for opening Studio, but it catches the class of bug that
is otherwise only findable by opening Studio: a misspelled property, a nil
index during a rebuild, a listener that accumulates on every render, an
interaction that fires when it should not. Ten real bugs have come out of it so
far, including one where attaching a block to a fresh stack deleted that stack,
and one where a button passed a property Roblox does not have to `Instance.new`
— which would have thrown on the first click in Studio.

The mock is also why the whole custom-block path is tested end to end: opening
the editor, typing Luau into it, saving, placing the block, checking the helper
is written once, saving the library out to a ModuleScript and reading it back
are all ordinary assertions rather than something you have to go and try.

If you add a view, add it to the UI suite. If you add a block, the block suite
picks it up on its own.
