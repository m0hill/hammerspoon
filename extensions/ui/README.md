# hs.ui

`hs.ui` is an experimental native AppKit UI toolkit for Hammerspoon. It exposes a small set of reusable native controls to Lua; it is **not** a full AppKit bridge.

The first version is aimed at launcher/search-panel style UI: a native panel, search field, list, stack layout, and images.

```lua
local ui = require("hs.ui")
```

## Quick example

```lua
local ui = require("hs.ui")

local search = ui.textField.new({
  search = true,
  placeholder = "Search apps, files, clipboard",
  fontSize = 24,
})

local list = ui.list.new({ rowHeight = 54 })

list:rows({
  {
    id = "safari",
    title = "Safari",
    subtitle = "App • /Applications/Safari.app",
    path = "/Applications/Safari.app",
    iconForFile = true,
  },
  {
    id = "clip",
    title = "hello from clipboard",
    subtitle = "Clipboard",
    systemImage = "doc.on.clipboard",
  },
})

local stack = ui.stack.new({
  orientation = "vertical",
  spacing = 10,
  padding = { top = 20, left = 20, bottom = 20, right = 20 },
  views = { search, list },
})

local panel = ui.panel.new({
  frame = { x = 0, y = 0, w = 720, h = 620 },
  style = "borderless",
  level = "floating",
  material = "hud",
  cornerRadius = 18,
  shadow = true,
  closeOnBlur = true,
  escapeCloses = true,
})

panel:setContent(stack)
panel:centerNearMouse()
panel:show()
search:focus()

search:on("change", function(text)
  print("query:", text)
end)

list:on("confirm", function(row, index)
  print("selected:", row.id, index)
  panel:hide()
end)
```

## Shared conventions

### Layout keys

Most views accept these optional layout keys:

```lua
{
  width = 300,
  height = 40,
  minWidth = 100,
  minHeight = 40,
  grow = true,
}
```

`hs.ui.list` defaults to `grow = true`, which makes it fill remaining space in vertical stacks.

### Callbacks

Callbacks use a single-listener setter:

```lua
object:on("event", fn)   -- set/replace callback
object:on("event", nil)  -- clear callback
```

Callback setters return the object for chaining.

`keyDown` callbacks receive a table like:

```lua
{
  keyCode = 36,
  characters = "\r",
  charactersIgnoringModifiers = "\r",
  modifiers = {
    cmd = false,
    shift = false,
    alt = false,
    ctrl = false,
    fn = false,
  },
}
```

If a `keyDown`, `submit`, or `escape` callback returns `true`, the event is consumed and default routing is skipped.

### Indexes

Lua-facing list indexes are 1-based:

```lua
list:selectedRow(1)
print(list:selectedRow()) -- 1, 2, ... or nil
```

Callbacks also receive 1-based indexes.

## `hs.ui.panel`

Backed by `NSPanel`.

### Constructor

```lua
local panel = ui.panel.new({
  frame = { x = 0, y = 0, w = 720, h = 620 },
  style = "borderless", -- "titled" or "borderless"
  level = "floating",   -- "normal", "floating", "modalPanel", "screenSaver"
  material = "hud",     -- nil, "hud", "popover", "sidebar", "window"
  cornerRadius = 18,
  shadow = true,
  movable = true,
  closeOnBlur = true,
  escapeCloses = true,
})
```

`frame` uses Hammerspoon-style screen coordinates.

### Methods

```lua
panel:setContent(view)       -- set root hs.ui view
panel:show()                 -- show and focus panel
panel:hide()                 -- hide without teardown
panel:delete()               -- release callbacks and tear down
panel:frame()                -- get frame table
panel:frame(rect)            -- set frame, returns panel
panel:centerOnScreen()       -- returns panel
panel:centerNearMouse()      -- returns panel
panel:focus()                -- returns panel
panel:on(event, fnOrNil)     -- events: "close", "blur", "keyDown"
```

Blur, Escape, and window close hide the panel. Only `delete()` tears it down.

## `hs.ui.stack`

Backed by `NSStackView`.

### Constructor

```lua
local stack = ui.stack.new({
  orientation = "vertical", -- or "horizontal"
  spacing = 8,
  padding = { top = 12, left = 12, bottom = 12, right = 12 },
  views = { view1, view2 },
})
```

### Methods

```lua
stack:addView(view)
stack:removeView(view)
stack:spacing()     -- get spacing
stack:spacing(12)   -- set spacing, returns stack
```

## `hs.ui.textField`

Backed by `NSSearchField` when `search = true`, otherwise `NSTextField`.

### Constructor

```lua
local field = ui.textField.new({
  placeholder = "Search",
  search = true,
  fontSize = 24,
})
```

### Methods

```lua
field:value()              -- get text
field:value("abc")        -- set text, returns field
field:placeholder()        -- get placeholder
field:placeholder("...")  -- set placeholder, returns field
field:focus()              -- focus field, returns field
field:on(event, fnOrNil)   -- events: "change", "submit", "escape", "keyDown"
```

`submit` receives the current text. `change` receives the current text. `escape` receives no arguments.

## `hs.ui.list`

Backed by `NSTableView` in an `NSScrollView`. Version 1 uses a fixed single-column row template with optional icon, title, subtitle, and disabled state.

### Constructor

```lua
local list = ui.list.new({
  rowHeight = 54,
  allowsEmptySelection = false,
})
```

### Rows

```lua
list:rows({
  {
    id = "safari",
    title = "Safari",
    subtitle = "App • /Applications/Safari.app",
    path = "/Applications/Safari.app",
    iconForFile = true,
    disabled = false,
  },
  {
    id = "clip-1",
    title = "Clipboard text",
    subtitle = "Clipboard",
    systemImage = "doc.on.clipboard",
  },
})
```

Rows are data-only tables. Avoid storing userdata or functions in row tables; use `id` to map back to richer Lua state.

### Methods

```lua
list:rows(rows)             -- replace rows, returns list
list:selectedRow()          -- 1-based index or nil
list:selectedRow(index)     -- select 1-based index, returns list
list:selectedId()           -- id of selected row or nil
list:selectNext()           -- returns list
list:selectPrevious()       -- returns list
list:on(event, fnOrNil)     -- events: "select", "confirm", "keyDown"
```

Callbacks:

```lua
list:on("select", function(row, index) end)
list:on("confirm", function(row, index) end)
```

`confirm` fires on double-click or Return via panel default routing.

## `hs.ui.image`

Backed by `NSImageView`.

### Constructor

```lua
local appIcon = ui.image.new({
  path = "/Applications/Safari.app",
  iconForFile = true,
  size = 32,
})

local symbol = ui.image.new({
  systemSymbol = "magnifyingglass",
  size = 18,
})
```

## Default keyboard routing

When a text field/list are inside the same panel:

- Up/Down selects previous/next list row
- Return confirms the selected list row
- Escape hides the panel, unless consumed by a callback

A callback returning `true` consumes the event and prevents the default routing.

## Notes and limitations

- Experimental/private-fork API.
- Not a full AppKit bridge.
- The list renderer is intentionally fixed in v1.
- AppKit work is dispatched onto the main thread internally.
- Uses semantic AppKit colors and native controls for light/dark mode behavior.
