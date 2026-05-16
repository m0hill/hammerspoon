--- === hs.ui ===
---
--- Experimental native AppKit UI toolkit for Hammerspoon.
---
--- This private-fork module is intentionally small and unstable. It exposes a
--- handful of reusable native controls rather than a full AppKit bridge.
---
--- Notes:
---  * Experimental API: names and behavior may change.
---  * v1 focuses on native panel, stack, text field/search field, list, and image views.

--- === hs.ui.panel ===
---
--- Experimental native panel object backed by `NSPanel`.

--- hs.ui.panel.new(options) -> panel
--- Constructor
--- Creates a native AppKit panel.
---
--- Parameters:
---  * options - A table. Common keys include `frame`, `style`, `level`, `material`, `cornerRadius`, `shadow`, `movable`, `closeOnBlur`, and `escapeCloses`.
---
--- Returns:
---  * An `hs.ui.panel` object.

--- hs.ui.panel:setContent(view) -> panel
--- Method
--- Sets the root hs.ui view displayed by the panel.
---
--- Parameters:
---  * view - An `hs.ui` view object, such as a stack, text field, list, or image.
---
--- Returns:
---  * The `hs.ui.panel` object.

--- === hs.ui.stack ===
---
--- Experimental native stack object backed by `NSStackView`.

--- hs.ui.stack.new(options) -> stack
--- Constructor
--- Creates a native AppKit stack view.
---
--- Parameters:
---  * options - A table. Common keys include `orientation`, `spacing`, `padding`, `views`, and layout keys such as `grow`, `width`, `height`, `minWidth`, and `minHeight`.
---
--- Returns:
---  * An `hs.ui.stack` object.

--- === hs.ui.textField ===
---
--- Experimental native text field object backed by `NSTextField` or `NSSearchField`.

--- hs.ui.textField.new(options) -> textField
--- Constructor
--- Creates a native text field, or an `NSSearchField` when `search = true`.
---
--- Parameters:
---  * options - A table. Common keys include `placeholder`, `search`, `fontSize`, and layout keys.
---
--- Returns:
---  * An `hs.ui.textField` object.

--- === hs.ui.list ===
---
--- Experimental native list object backed by `NSTableView`.

--- hs.ui.list.new(options) -> list
--- Constructor
--- Creates a native single-column list backed by `NSTableView`.
---
--- Parameters:
---  * options - A table. Common keys include `rowHeight`, `allowsEmptySelection`, and layout keys.
---
--- Returns:
---  * An `hs.ui.list` object.

--- === hs.ui.image ===
---
--- Experimental native image object backed by `NSImageView`.

--- hs.ui.image.new(options) -> image
--- Constructor
--- Creates a native image view backed by `NSImageView`.
---
--- Parameters:
---  * options - A table. Common keys include `path`, `iconForFile`, `systemSymbol`, `size`, and layout keys.
---
--- Returns:
---  * An `hs.ui.image` object.

local ui = require("hs.libui")

return ui
