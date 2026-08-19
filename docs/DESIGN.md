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
- **Printing inks for categories.** Twenty-seven of them, one each, and a block
  is filled with its category's ink rather than merely marked by it. The ink a
  chip is drawn in and the colour a whole block is painted are not the same
  job, so `a.blockColor` takes the category ink and darkens it — by binary
  search on WCAG luminance — until pale writing on it clears 4.5:1. Doing that
  by rule rather than by hand is what stops the twenty-eighth category from
  being the one nobody can read, and it has the side effect the look wants
  anyway: twenty-seven inks of equal weight.
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

Everything sits on a 4px grid.

### Blocks that fit together

A block is a filled slab with a notch bitten out of its top edge, a mouth if it
holds other blocks, and a tab at the bottom of every run. Two properties fall
out of doing it this way rather than by drawing puzzle shapes:

**The joint is the block above, showing through.** What fills a block's notch is
not a decoration the block owns — it is the colour of whatever the block is
sitting on. Nothing above it means the canvas shows through, which reads as a
real cut; the block above means that block's colour carries on down into it,
which reads as interlocked. One rule, both states, no third case to keep in
sync, and a run stays correct however it is rearranged because every re-render
recomputes it from the run it is now in.

**Nothing measures anything.** The notch and the tab are fixed-size rows in the
same list layout as the wording, so no child is ever sized from the parent it
would then resize. That constraint is why they are rows rather than shapes
hanging off an edge, and the UI suite fails the build if any child of a block
acquires a scale-sized axis.

The rest follows the same reasoning:

- **A C block is padding, not a shape.** A container's slot is a wrapper with
  14px of left padding — the arm — around a mouth painted in the canvas colour.
  The block's own fill shows through the padding, so the C draws itself.
- **Blocks in a run touch.** The list gap is zero; the notch is the only thing
  between two blocks, which is the point.
- **Wording is prose, fields are code.** The label on a block is set in the
  interface face, because "when this is touched by" is a sentence. The fields
  are monospace pale pills, because they are Luau. The two typefaces are the
  fastest way to see what you can type into and what you cannot.
- **Picked up, not clicked.** A block lifts after the button has been held on
  it, and casts a shadow when it does. A click selects and nothing more, so
  reading your way down a stack cannot pull it apart, and the drop target is
  drawn as the silhouette of a block's top edge rather than as a line.

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

**Input comes from the widget, never from `UserInputService`.** Studio routes
input that lands on a plugin widget to that widget alone; the service only
hears the game view. Asking it whether the mouse button is down therefore
always answers "no" while the pointer is over our window. Every gesture here —
picking a block up, panning, carrying one out of the palette, every keyboard
shortcut — is driven from the widget's own `InputBegan` and `InputEnded`
through the small tracker in `b.luau`, and a press-and-hold loop keeps going
while `b.pressing` says so: the `InputObject` from `InputBegan` reaches its End
state on release wherever the pointer has wandered to, and the tracked button
state covers a gesture handed on without one. A release off the edge of the
window never reports itself, so the tracker forgets everything when the window
loses focus rather than leaving a button stuck down. The mock models this
blindness deliberately — `IsMouseButtonPressed` there returns false, as it does
in Studio — so a gesture built on the service fails the suite instead of
failing the person using the plugin.

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
interaction that fires when it should not. Eleven real bugs have come out of it so
far, including one where every drag in the plugin did nothing at all because
the gesture loops asked a service that cannot see a plugin widget, one where
attaching a block to a fresh stack deleted that stack,
and one where a button passed a property Roblox does not have to `Instance.new`
— which would have thrown on the first click in Studio.

The mock is also why the whole custom-block path is tested end to end: opening
the editor, typing Luau into it, saving, placing the block, checking the helper
is written once, saving the library out to a ModuleScript and reading it back
are all ordinary assertions rather than something you have to go and try.

If you add a view, add it to the UI suite. If you add a block, the block suite
picks it up on its own.
