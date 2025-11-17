# Hammerspoon Packages

A collection of Hammerspoon scripts for productivity and media control.

## Packages

### Whisper Transcription

Real-time speech-to-text transcription using OpenAI's Whisper model via Groq API.

**Features:**
- **Hotkey Recording**: Hold Option+/ to record audio, release to transcribe
- **Automatic Pasting**: Transcribed text is automatically pasted into the active application
- **Visual Indicators**: On-screen indicators show recording and transcription status
- **Configurable Settings**: Change language, model, notifications, and sounds via menubar
- **Multi-language Support**: Supports various languages including auto-detection

**Requirements:**
- [sox](https://sox.sourceforge.net/) (install with `brew install sox`)
- Groq API key (add to `.env` file)

**Usage:**
- **Record**: Hold Option+/ to start recording
- **Transcribe**: Release the hotkey to stop and transcribe
- **Settings**: Click the menubar icon to access settings and about info

**Configuration:**
Edit the `CONFIG` table in `whisper.lua` to customize:
- Hotkey combination
- Whisper model (whisper-large-v3 or whisper-large-v3-turbo)
- Default language
- Notification and sound preferences
- Recording parameters (sample rate, timeouts, etc.)

---

### Gemini OCR

Screenshot-based text extraction using Google's Gemini API with automatic translation.

**Features:**
- **Screenshot Capture**: Interactive screenshot selection with hotkey
- **AI-Powered OCR**: Extract text from images using Gemini Flash models
- **Auto-Translation**: Automatically translates non-English text to English
- **Visual Feedback**: Pulsing indicator shows processing status
- **Sound Effects**: Audio feedback for capture, processing, and completion
- **Menubar Control**: Access settings and model selection via menubar
- **Auto-Copy**: Extracted text automatically copied to clipboard

**Requirements:**
- Google Gemini API key (add to `.env` file)
- Active internet connection

**Usage:**
- **Capture**: Press Cmd+Shift+S to start screenshot selection
- **Select Area**: Click and drag to select area containing text
- **Wait**: Processing indicator appears while OCR is running
- **Result**: Text is automatically copied to clipboard and shown in notification

**Configuration:**
- **Model Selection**: Choose between Gemini Flash or Flash Lite
- **Notifications**: Toggle on/off via menubar
- **Sounds**: Toggle audio feedback via menubar
- **Hotkey**: Default is Cmd+Shift+S (customizable in code)

---

### Spotify Lyrics

Real-time synchronized lyrics display for Spotify with a draggable overlay.

**Features:**
- **Synced Lyrics**: Displays current and next lyrics synchronized with playback
- **Draggable Overlay**: Move the lyrics window anywhere on screen
- **Auto-fetch**: Automatically fetches lyrics from lrclib.net API
- **Persistent Position**: Remembers overlay position and visibility
- **Menubar Control**: Show/hide lyrics via menubar icon

**Requirements:**
- Spotify application
- Active internet connection for lyrics fetching

**Usage:**
- Lyrics automatically appear when Spotify is playing
- Drag the overlay to reposition it
- Click the menubar icon to show/hide lyrics
- Position and visibility preferences are saved

**How it works:**
- Polls Spotify every 0.5 seconds for playback state
- Fetches synced lyrics when a new track is detected
- Displays current line in bold with next line preview
- Shows track info, artist, playback position, and duration

---

### Trimmy

Automatically flattens multi-line shell commands copied to the clipboard, making them pasteable in one go.

**Features:**
- **Auto-Detection**: Automatically detects and flattens shell commands in clipboard
- **Aggressiveness Levels**: Low/Normal/High detection sensitivity
- **Backslash Handling**: Properly handles line continuations with `\`
- **Blank Line Preservation**: Optional preservation of intentional blank lines
- **Visual Feedback**: Menubar icon with last trimmed command preview
- **Manual Override**: Force-trim clipboard on demand
- **Persistent Settings**: All preferences saved automatically

**Requirements:**
- None - uses built-in Hammerspoon APIs

**Usage:**
- Copy multi-line shell commands - they're automatically flattened
- Use menubar to toggle auto-trim, set aggressiveness, or manually trim
- "Trim Clipboard Now" forces trimming regardless of auto-detection

**Configuration:**
- **Auto-Trim**: Enable/disable automatic clipboard processing
- **Aggressiveness**: 
  - Low (safer): Requires strong command indicators (≥3 signals)
  - Normal (default): Balanced detection (≥2 signals)
  - High (eager): Flattens most multi-line text (≥1 signal)
- **Keep blank lines**: Preserves intentional blank lines during flattening

**How it works:**
- Polls clipboard every 150ms for changes
- Scores text based on command-like patterns (pipes, flags, backslashes, sudo, etc.)
- Flattens qualifying text by removing line breaks and handling continuations
- Skips auto-processing for 10+ line copies (safety valve)
- Port of the native macOS [Trimmy app](https://github.com/steipete/Trimmy)

---

## Installation

1. Install [Hammerspoon](https://www.hammerspoon.org/)
2. Clone or download this repository to `~/.hammerspoon/`
3. Set up API keys:
   ```bash
   # Copy the example .env file
   cp .env.example .env
   
   # Edit .env and add your API keys
   # GROQ_API_KEY=your-groq-api-key-here
   # GEMINI_API_KEY=your-gemini-api-key-here
   ```
4. Install dependencies:
   ```bash
   # For Whisper Transcription
   brew install sox
   ```
5. Ensure `init.lua` loads the packages:
   ```lua
   require("gemini")
   require("whisper")
   require("lyrics")
   require("trimmy")
   ```
6. Reload Hammerspoon configuration

## Contributing

This is a collection of useful Hammerspoon scripts. Contributions are welcome!

**How to contribute:**
- Add new Hammerspoon scripts that solve real productivity problems
- Improve existing scripts with bug fixes or new features
- Update documentation to make scripts easier to use
- Share your own creative automation ideas

**Guidelines:**
- Each script should be self-contained in its own `.lua` file
- Follow the existing code style (see `AGENTS.md` for details)
- Include clear documentation in the README for your script
- Add any required API keys to `.env.example` (never commit actual keys)
- Test your script thoroughly before submitting a PR
- Keep dependencies minimal and document them clearly

**To add a new script:**
1. Create your script as a new `.lua` file (e.g., `myscript.lua`)
2. Add `require("myscript")` to `init.lua`
3. Document it in this README with features, requirements, and usage
4. Submit a pull request with a clear description

Feel free to open issues for bugs, feature requests, or questions!