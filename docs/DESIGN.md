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
- **Printing inks for categories.** Ten muted hues, all roughly equal in
  weight, so a full canvas reads as a document rather than a bag of sweets.
  A category shows as a 3px spine on the left edge of a block; that is all.
- **Monospace where it is code.** Block wording, fields, the code panel and the
  status bar are all `Enum.Font.Code`. Chrome — buttons, tabs, headings — is
  Gotham. The split tells you at a glance which text is yours and which is the
  application's.
- **A dot-free grid.** The canvas is ruled like graph paper, minor lines every
  20 studs of canvas space and a stronger line every fifth, drawn as offset
  frames repositioned on pan so the count stays constant.
- **No emoji, anywhere.** Icons are drawn from primitives: the chevron is two
  rotated hairlines, the category chip is a letter, the rail mark is three
  bars. Nothing depends on a font having a particular glyph.
- **Vertical rail labels.** Rotated -90°, which gives the window a silhouette
  you can recognise across a Studio full of horizontal tab strips.

Everything sits on a 4px grid; block rows are 26px so a stack lines up with the
canvas grid at 100% zoom.

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

## Rules the code follows

**One definition per block.** `src/c.luau` holds the canvas wording and the
Luau on the same line. Anything derived from a block — palette entry, search
text, tooltip, code, the field editors, the tests — comes from that one entry.

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
interaction that fires when it should not. Three real bugs came out of writing
it, including one where attaching a block to a fresh stack deleted that stack.

If you add a view, add it to the UI suite. If you add a block, the block suite
picks it up on its own.
