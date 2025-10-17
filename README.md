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
- Groq API key (set as environment variable `GROQ_API_KEY`)

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

## Installation

1. Install [Hammerspoon](https://www.hammerspoon.org/)
2. Clone or download this repository to `~/.hammerspoon/`
3. Ensure `init.lua` loads the packages:
   ```lua
   require("whisper")
   require("lyrics")
   ```
4. For Whisper: Set your Groq API key:
   ```bash
   launchctl setenv GROQ_API_KEY your_key_here
   ```
5. Reload Hammerspoon configuration