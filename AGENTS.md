# Agent Guidelines for Hammerspoon Configuration

## Build/Test/Lint Commands
- **Reload config**: Open Hammerspoon console and click "Reload Config" or run `hs.reload()`
- **Test script**: `hs /Users/mohil/.hammerspoon/init.lua` (or specific module file)
- **No formal tests**: This is a config-based project; test manually via Hammerspoon console

## Code Style

### Language & Structure
- Language: Lua 5.3+ (Hammerspoon's embedded runtime)
- Each module is self-contained in its own `.lua` file
- Modules return a table `M` with public functions (`init`, `start`, `stop`) and integrate with menubar manager
- Module pattern: return module table without auto-initialization (see whisper.lua:702, gemini.lua:414, lyrics.lua:501, trimmy.lua:290)

### Variables & Naming
- `SCREAMING_SNAKE_CASE` for constants and config tables (e.g., `CONFIG`, `MODELS`, `LANGUAGES`)
- `camelCase` for local functions (e.g., `createIndicator`, `updateMenuBar`, `formatTime`)
- `snake_case` for module-level state variables (e.g., `currentTrackId`, `pollTimer`, `menubar`)
- Prefix private settings keys with module name (e.g., `"lyrics.overlay.frame"`, `"trimmy.aggressiveness"`)

### Imports & Dependencies
- Use `require("module")` for custom modules (e.g., `require("env")`)
- Access Hammerspoon APIs via `hs.*` namespace (e.g., `hs.hotkey`, `hs.notify`, `hs.canvas`)
- Load `.env` variables using `env.get("KEY_NAME")` helper (see env.lua:41)

### Error Handling
- Use `pcall()` for JSON parsing: `local ok, result = pcall(hs.json.decode, data)`
- Check dependencies at init time (e.g., whisper.lua:172 checks for `sox` and API keys)
- Validate state before operations (e.g., check if file exists with `hs.fs.attributes()`)
- Gracefully handle missing data with fallback messages in UI

### Environment Variables
- Store secrets in `.env` file (ignored by git per .gitignore:2)
- Reference `.env.example` for required keys (GROQ_API_KEY, GEMINI_API_KEY)
- Never hardcode API keys in source files

### Menubar Integration
- All modules integrate with the centralized `menubar_manager` (see menubar_manager.lua:1)
- Modules receive manager instance via `init(manager)` function
- Register menubars with: `manager.registerModule(name, menuItems, icon, tooltip)`
- Update menubars with: `manager.updateModule(name, menuItems, icon, tooltip)`
- Unregister on cleanup with: `manager.unregisterModule(name)`
- Menu items are plain tables, not menubar instances (see whisper.lua:280, gemini.lua:194)
- Keep `getMenuItems()`, `getIcon()`, and `getTooltip()` as separate functions for clarity
- Store manager reference in module-level variable (e.g., `local menubarManager = nil`)
- Configuration managed by `menubar_config.lua` with persistent settings (see menubar_config.lua:1)
