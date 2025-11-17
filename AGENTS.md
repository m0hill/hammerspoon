# Agent Guidelines for Hammerspoon Configuration

## Project Structure
```
~/.hammerspoon/
├── init.lua              # Main config file (user-facing configuration)
├── spoons/               # Feature modules (whisper, lyrics, gemini, trimmy)
│   ├── whisper.lua
│   ├── lyrics.lua
│   ├── gemini.lua
│   └── trimmy.lua
└── lib/                  # Utility/infrastructure code
    ├── env.lua
    └── menubar.lua
```

## Build/Test/Lint Commands
- **Reload config**: Open Hammerspoon console and click "Reload Config" or run `hs.reload()`
- **Test script**: `hs /Users/mohil/.hammerspoon/init.lua` (or specific module file)
- **No formal tests**: This is a config-based project; test manually via Hammerspoon console

## Code Style

### Language & Structure
- Language: Lua 5.3+ (Hammerspoon's embedded runtime)
- **Spoons** (feature modules) live in `spoons/` directory
- **Libraries** (utilities) live in `lib/` directory
- Each module is self-contained in its own `.lua` file
- Modules return a table `M` with public functions (`init`, `start`, `stop`) and integrate with menubar
- Module pattern: return module table without auto-initialization

### Variables & Naming
- `SCREAMING_SNAKE_CASE` for constants and config tables (e.g., `CONFIG`, `MODELS`, `LANGUAGES`)
- `camelCase` for local functions (e.g., `createIndicator`, `updateMenuBar`, `formatTime`)
- `snake_case` for module-level state variables (e.g., `currentTrackId`, `pollTimer`, `menubar`)
- Prefix private settings keys with module name (e.g., `"lyrics.overlay.frame"`, `"trimmy.aggressiveness"`)

### Imports & Dependencies
- Use `require("spoons.module")` for spoon modules (e.g., `require("spoons.whisper")`)
- Use `require("lib.module")` for library modules (e.g., `require("lib.env")`)
- Access Hammerspoon APIs via `hs.*` namespace (e.g., `hs.hotkey`, `hs.notify`, `hs.canvas`)
- Load `.env` variables using `env.get("KEY_NAME")` helper from `lib.env`

### Error Handling
- Use `pcall()` for JSON parsing: `local ok, result = pcall(hs.json.decode, data)`
- Check dependencies at init time (e.g., check for `sox` binary and API keys)
- Validate state before operations (e.g., check if file exists with `hs.fs.attributes()`)
- Gracefully handle missing data with fallback messages in UI

### Environment Variables
- Store secrets in `.env` file (ignored by git)
- Reference `.env.example` for required keys (GROQ_API_KEY, GEMINI_API_KEY)
- Never hardcode API keys in source files
- Use `lib.env` module to load environment variables

### Menubar Integration
- All spoons integrate with the centralized menubar manager from `lib.menubar`
- Spoons receive menubar instance via `init(menubar)` function
- Register menubars with: `menubar.registerModule(name, menuItems, icon, tooltip)`
- Update menubars with: `menubar.updateModule(name, menuItems, icon, tooltip)`
- Unregister on cleanup with: `menubar.unregisterModule(name)`
- Menu items are plain tables, not menubar instances
- Keep `getMenuItems()`, `getIcon()`, and `getTooltip()` as separate functions for clarity
- Store menubar reference in module-level variable (e.g., `local menubar = nil`)
- Configuration is managed in `init.lua` via `MENUBAR_CONFIG` table with persistent settings
