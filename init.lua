local menubarManager = require("menubar_manager")

local whisper = require("whisper")
local lyrics = require("lyrics")
local gemini = require("gemini")
local trimmy = require("trimmy")

whisper.init(menubarManager)
lyrics.init(menubarManager)
gemini.init(menubarManager)
trimmy.init(menubarManager)

lyrics.start()
