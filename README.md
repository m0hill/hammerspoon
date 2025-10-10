# Hammerspoon Whisper Transcription

A Hammerspoon script that enables real-time speech-to-text transcription using OpenAI's Whisper model via Groq API.

## Features

- **Hotkey Recording**: Hold Option+/ to record audio, release to transcribe
- **Automatic Pasting**: Transcribed text is automatically pasted into the active application
- **Visual Indicators**: On-screen indicators show recording and transcription status
- **Configurable Settings**: Change language, model, notifications, and sounds via menubar
- **Multi-language Support**: Supports various languages including auto-detection

## Requirements

- [Hammerspoon](https://www.hammerspoon.org/)
- [sox](https://sox.sourceforge.net/) (install with `brew install sox`)
- Groq API key (set as environment variable `GROQ_API_KEY`)

## Installation

1. Clone or download this repository
2. Place `whisper.lua` in your Hammerspoon config directory (`~/.hammerspoon/`)
3. Ensure `init.lua` loads the script: `require("whisper")`
4. Set your Groq API key: `launchctl setenv GROQ_API_KEY your_key_here`

## Usage

- **Record**: Hold Option+/ to start recording
- **Transcribe**: Release the hotkey to stop and transcribe
- **Settings**: Click the menubar icon (🎤) to access settings and about info

## Configuration

Edit the `CONFIG` table in `whisper.lua` to customize:
- Hotkey combination
- Whisper model (whisper-large-v3 or whisper-large-v3-turbo)
- Default language
- Notification and sound preferences
- Recording parameters (sample rate, timeouts, etc.)