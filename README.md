# 🚀 Power Spoons

> A curated collection of powerful Hammerspoon productivity tools with a built-in package manager

Replace bloated Electron apps with lightweight, native macOS automation using Lua scripts. Power Spoons brings you professional-grade productivity tools that integrate seamlessly with macOS.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ✨ Features

- **📦 Package Manager**: Simple CLI tool (`hs-pm`) to install and manage spoons
- **🎯 Zero Config**: One-liner installation with interactive setup
- **🔧 Modular**: Enable only the spoons you need
- **💾 Lightweight**: Native macOS integration, no Electron bloat
- **🔐 Secure**: API keys stored locally in `.env` file

---

## 🎁 Available Spoons

### 🎙️ Whisper Transcription
Real-time speech-to-text using OpenAI's Whisper via Groq API.

- **Hotkey**: `Option+/` - Hold to record, release to transcribe
- **Auto-paste**: Transcribed text inserted automatically
- **Multi-language**: 13+ languages with auto-detection
- **Visual feedback**: On-screen recording indicators
- **Requires**: sox (auto-installed), GROQ_API_KEY

---

### 📸 Gemini OCR
Screenshot-based text extraction with Google's Gemini AI.

- **Hotkey**: `Cmd+Shift+S` - Screenshot area with text
- **AI-powered**: Gemini Flash for accurate OCR
- **Auto-translate**: Non-English text to English
- **Smart formatting**: Clean, organized output
- **Requires**: GEMINI_API_KEY

---

### 🎵 Spotify Lyrics
Floating synchronized lyrics overlay for Spotify.

- **Auto-sync**: Real-time lyrics synchronized with playback
- **Draggable**: Position overlay anywhere on screen
- **Persistent**: Remembers position and visibility
- **No config needed**: Works out of the box
- **Requires**: Spotify app

---

### ✂️ Trimmy
Automatically flatten multi-line shell commands in clipboard.

- **Auto-detect**: Recognizes shell commands automatically
- **Smart parsing**: Handles backslashes, pipes, flags
- **Configurable**: Low/Normal/High aggressiveness levels
- **Manual override**: Force-trim via menubar
- **No dependencies**: Pure Hammerspoon implementation

---

## 📥 Installation

### New Users (Recommended)

One-liner installation:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/m0hill/power-spoons/main/scripts/install.sh)"
```

Then run the interactive installer:

```bash
hs-pm init
```

This will:
1. ✅ Install Hammerspoon (if needed)
2. ✅ Install sox and other dependencies (if needed)
3. ✅ Let you choose which spoons to enable
4. ✅ Prompt for API keys
5. ✅ Set up your `~/.hammerspoon` configuration

### Existing Hammerspoon Users

If you already use Hammerspoon and want to keep your existing config:

```bash
# Clone the repository
git clone https://github.com/m0hill/power-spoons.git ~/.power-spoons

# Add hs-pm to your PATH
echo 'export PATH="$HOME/.power-spoons/scripts:$PATH"' >> ~/.zshrc
source ~/.zshrc

# View available spoons
hs-pm available

# Add specific spoons to your config
hs-pm add whisper
hs-pm add lyrics
```

**Manual Integration**: Add this to your existing `~/.hammerspoon/init.lua`:

```lua
-- Add power-spoons to package path
package.path = package.path .. ";/Users/" .. os.getenv("USER") .. "/.power-spoons/core/?.lua"

-- Load power-spoons
local menubar = require("lib.menubar")
local whisper = require("spoons.whisper")

menubar.init({mode = "individual", modules = {whisper = {enabled = true, display = "individual"}}})
whisper.init(menubar)
```

---

## 🎮 Usage

### Managing Spoons

```bash
# List all available spoons
hs-pm available

# List installed/enabled spoons
hs-pm list

# Add and enable a spoon
hs-pm add whisper

# Remove/disable a spoon
hs-pm remove lyrics

# Update power-spoons to latest version
hs-pm update
```

### Configuration

Your Hammerspoon config lives at `~/.hammerspoon/`:

```
~/.hammerspoon/
├── init.lua              # Auto-generated, loads enabled spoons
├── modules_config.lua    # Your spoon selections (managed by hs-pm)
├── .env                  # API keys (never committed)
├── lib/                  # Core libraries (auto-updated)
└── spoons/               # Spoon modules (auto-updated)
```

**API Keys**: Edit `~/.hammerspoon/.env`:

```bash
# Get from: https://console.groq.com/keys
GROQ_API_KEY=your_groq_api_key_here

# Get from: https://aistudio.google.com/app/apikey
GEMINI_API_KEY=your_gemini_api_key_here
```

After any changes, reload Hammerspoon (Cmd+Ctrl+R).

---

## 📦 Project Structure

```
power-spoons/
├── core/                 # Core runtime files
│   ├── lib/             # Utility libraries
│   │   ├── env.lua      # Environment variable loader
│   │   └── menubar.lua  # Menubar manager
│   └── spoons/          # Spoon modules
│       ├── whisper.lua
│       ├── gemini.lua
│       ├── lyrics.lua
│       └── trimmy.lua
├── manifests/
│   └── spoons.json      # Spoon metadata and dependencies
├── templates/           # Installation templates
│   ├── init.lua
│   ├── modules_config.lua
│   └── .env.example
└── scripts/
    ├── hs-pm            # Package manager CLI (Python)
    └── install.sh       # One-liner installer
```

---

## 🎨 Menubar Management

All spoons integrate with a flexible menubar system:

**Display Modes:**
- **Individual Icons**: Each spoon has its own menubar icon (default)
- **Consolidated Menu**: All spoons grouped under one icon

**Per-Module Control:**
- Choose individual or consolidated display per spoon
- Settings persist across reloads
- Managed via menubar or `modules_config.lua`

---

## 🔑 API Keys

### Groq API (for Whisper)
1. Sign up at [console.groq.com](https://console.groq.com)
2. Navigate to [API Keys](https://console.groq.com/keys)
3. Create a new API key
4. Add to `~/.hammerspoon/.env`: `GROQ_API_KEY=...`

**Pricing**: Whisper Large v3 Turbo is $0.04/hour of audio

### Gemini API (for OCR)
1. Get a key from [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Add to `~/.hammerspoon/.env`: `GEMINI_API_KEY=...`

**Pricing**: Gemini Flash Lite has a generous free tier

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Adding a New Spoon

1. **Create the spoon** in `core/spoons/yourspoon.lua`:

```lua
local M = {}

function M.init(menubar)
    -- Initialize your spoon
    menubar.registerModule("yourspoon", getMenuItems(), getIcon(), "Tooltip")
end

function M.start()
    -- Optional: start timers, watchers, etc.
end

function M.stop()
    -- Optional: cleanup
end

return M
```

2. **Add metadata** to `manifests/spoons.json`:

```json
{
  "id": "yourspoon",
  "name": "Your Spoon Name",
  "description": "What it does",
  "dependencies": {
    "brew": ["package"],
    "env": ["API_KEY"]
  },
  "defaultEnabled": true,
  "category": "productivity",
  "hotkey": "Cmd+Shift+X"
}
```

3. **Update template** in `templates/modules_config.lua`:
   - Add your spoon to the modules list

4. **Test it**:
```bash
hs-pm add yourspoon
```

5. **Submit a PR** with:
   - Your spoon code
   - Updated manifest
   - README documentation
   - Example usage

### Code Style

See [AGENTS.md](AGENTS.md) for detailed coding guidelines:
- `SCREAMING_SNAKE_CASE` for constants
- `camelCase` for functions
- `snake_case` for module state
- Prefix settings with module name

---

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙏 Credits

- **Trimmy** spoon inspired by [@steipete](https://github.com/steipete)'s [native Trimmy app](https://github.com/steipete/Trimmy)
- **Hammerspoon** - [www.hammerspoon.org](https://www.hammerspoon.org/)
- **Groq** - Lightning-fast Whisper API
- **Google Gemini** - Powerful multimodal AI
- **lrclib.net** - Free lyrics API

---

## 🐛 Issues & Support

- 🐞 Found a bug? [Open an issue](https://github.com/m0hill/power-spoons/issues)
- 💡 Feature request? [Start a discussion](https://github.com/m0hill/power-spoons/discussions)
- 📖 Documentation unclear? PRs welcome!

---

**Made with ❤️ for the Hammerspoon community**
