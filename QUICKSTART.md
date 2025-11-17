# 🚀 Quick Start Guide

Get up and running with Power Spoons in 5 minutes!

## For New Users

### Step 1: Install Power Spoons

Run this one-liner in your terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/m0hill/power-spoons/main/scripts/install.sh)"
```

This will:
- Install Homebrew (if needed)
- Install Python 3 (if needed)
- Clone the power-spoons repository to `~/.power-spoons`
- Add `hs-pm` to your PATH

### Step 2: Reload Your Shell

```bash
source ~/.zshrc
# or restart your terminal
```

### Step 3: Initialize Hammerspoon

```bash
hs-pm init
```

This interactive installer will:
1. ✅ Check/install Hammerspoon
2. ✅ Let you choose which spoons to enable
3. ✅ Install dependencies (sox, etc.)
4. ✅ Prompt for API keys
5. ✅ Set up your configuration

### Step 4: Reload Hammerspoon

Click the Hammerspoon menubar icon → "Reload Config"

Or press: `Cmd+Ctrl+R` (if you have the default hotkey)

### Step 5: Start Using!

**Try Whisper:**
- Hold `Option+/` to record
- Speak into your microphone
- Release to transcribe and paste

**Try Gemini OCR:**
- Press `Cmd+Shift+S`
- Select area with text
- Text is copied to clipboard

**Try Lyrics:**
- Open Spotify
- Play a song
- Lyrics appear automatically

**Try Trimmy:**
- Copy a multi-line shell command
- It's automatically flattened
- Paste it in your terminal

---

## For Existing Hammerspoon Users

### Option 1: Full Integration (Recommended)

Backup your current config:
```bash
cp -r ~/.hammerspoon ~/.hammerspoon.backup
```

Install power-spoons:
```bash
git clone https://github.com/m0hill/power-spoons.git ~/.power-spoons
echo 'export PATH="$HOME/.power-spoons/scripts:$PATH"' >> ~/.zshrc
source ~/.zshrc
hs-pm init
```

This will replace your `~/.hammerspoon` with power-spoons config.

### Option 2: Partial Integration (Keep Your Config)

Install power-spoons:
```bash
git clone https://github.com/m0hill/power-spoons.git ~/.power-spoons
echo 'export PATH="$HOME/.power-spoons/scripts:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Add to your existing `~/.hammerspoon/init.lua`:

```lua
-- Add power-spoons to package path
package.path = package.path .. ";/Users/" .. os.getenv("USER") .. "/.power-spoons/core/?.lua"

-- Load the spoons you want
local menubar = require("lib.menubar")
local whisper = require("spoons.whisper")
local lyrics = require("spoons.lyrics")

-- Initialize menubar
menubar.init({
    mode = "individual",
    modules = {
        whisper = {enabled = true, display = "individual"},
        lyrics = {enabled = true, display = "individual"}
    }
})

-- Initialize spoons
whisper.init(menubar)
lyrics.init(menubar)

-- Start any spoons that need it
lyrics.start()
```

Create `~/.hammerspoon/.env` with your API keys:
```bash
GROQ_API_KEY=your_key_here
GEMINI_API_KEY=your_key_here
```

Install dependencies:
```bash
brew install sox  # for whisper
```

Reload Hammerspoon!

---

## Common Commands

```bash
# List available spoons
hs-pm available

# List what you have installed
hs-pm list

# Add a spoon
hs-pm add gemini

# Remove a spoon
hs-pm remove trimmy

# Update to latest version
hs-pm update
```

---

## Getting API Keys

### Groq API (for Whisper Transcription)

1. Go to [console.groq.com](https://console.groq.com)
2. Sign up/login (free account)
3. Navigate to [API Keys](https://console.groq.com/keys)
4. Click "Create API Key"
5. Copy the key
6. Add to `~/.hammerspoon/.env`:
   ```
   GROQ_API_KEY=gsk_...
   ```

**Cost**: $0.04 per hour of audio (very cheap!)

### Gemini API (for OCR)

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with Google account
3. Click "Create API Key"
4. Select your Google Cloud project (or create new)
5. Copy the key
6. Add to `~/.hammerspoon/.env`:
   ```
   GEMINI_API_KEY=AIza...
   ```

**Cost**: Free tier is very generous!

---

## Troubleshooting

### "hs-pm: command not found"

Reload your shell:
```bash
source ~/.zshrc
```

Or add to PATH manually:
```bash
export PATH="$HOME/.power-spoons/scripts:$PATH"
```

### "Hammerspoon not responding after reload"

Check Hammerspoon console for errors:
- Click Hammerspoon menubar icon → "Console"
- Look for red error messages

Common issues:
- Missing API key → Add to `.env`
- Missing dependency → Run `brew install sox`
- Typo in config → Check `~/.hammerspoon/modules_config.lua`

### "Whisper not working"

1. Check sox is installed:
   ```bash
   which rec
   ```
   If not found:
   ```bash
   brew install sox
   ```

2. Check API key in `~/.hammerspoon/.env`:
   ```bash
   cat ~/.hammerspoon/.env | grep GROQ
   ```

3. Check microphone permissions:
   - System Settings → Privacy & Security → Microphone
   - Ensure Hammerspoon is enabled

### "Lyrics not showing"

1. Make sure Spotify is running and playing
2. Check Hammerspoon console for API errors
3. Try clicking menubar icon → Show Lyrics

### "OCR not working"

1. Check API key:
   ```bash
   cat ~/.hammerspoon/.env | grep GEMINI
   ```

2. Check internet connection
3. Try a different screenshot with clear text

---

## Next Steps

1. **Customize hotkeys**: Edit spoon files in `~/.power-spoons/core/spoons/`
2. **Explore settings**: Click menubar icons for each spoon
3. **Read full docs**: Check out the main [README.md](README.md)
4. **Contribute**: Add your own spoons! See [Contributing](README.md#-contributing)

---

**Need help?** [Open an issue](https://github.com/m0hill/power-spoons/issues)
