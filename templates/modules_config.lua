-- GENERATED FILE - managed by hs-pm

local M = {}

M.MENUBAR_CONFIG = {
	mode = "individual", -- "individual" or "consolidated"
	modules = {
		whisper = {
			enabled = { { WHISPER_ENABLED } },
			display = "individual", -- "individual" or "consolidated"
		},
		lyrics = {
			enabled = { { LYRICS_ENABLED } },
			display = "individual",
		},
		gemini = {
			enabled = { { GEMINI_ENABLED } },
			display = "individual",
		},
		trimmy = {
			enabled = { { TRIMMY_ENABLED } },
			display = "individual",
		},
	},
}

return M
