-- Menubar Configuration
-- mode: "individual" = each module has its own icon, "consolidated" = all in one menu
-- display: "individual" = show as separate icon, "consolidated" = show in consolidated menu
local MENUBAR_CONFIG = {
	mode = "individual", -- "individual" or "consolidated"
	modules = {
		lyrics = {
			enabled = true,
			display = "individual",
		},
		whisper = {
			enabled = true,
			display = "individual",
		},
		trimmy = {
			enabled = true,
			display = "individual",
		},
		gemini = {
			enabled = true,
			display = "individual",
		},
	},
}

local menubar = require("lib.menubar")
menubar.init(MENUBAR_CONFIG)

local whisper = require("spoons.whisper")
local lyrics = require("spoons.lyrics")
local gemini = require("spoons.gemini")
local trimmy = require("spoons.trimmy")

whisper.init(menubar)
lyrics.init(menubar)
gemini.init(menubar)
trimmy.init(menubar)

lyrics.start()
