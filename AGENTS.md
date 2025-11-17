# Agent Guidelines for Hammerspoon Configuration

## Build/Test/Lint Commands
- **Reload config**: Open Hammerspoon console and click "Reload Config" or run `hs.reload()`
- **Test script**: `hs /Users/mohil/.hammerspoon/init.lua` (or specific module file)
- **No formal tests**: This is a config-based project; test manually via Hammerspoon console

## Code Style

### Language & Structure
- Language: Lua 5.3+ (Hammerspoon's embedded runtime)
- Each module is self-contained in its own `.lua` file
- Modules return a table `M` with public functions when needed, or run `init()` directly

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
