local SETTINGS_KEY = "menubar.config"

local DEFAULT_CONFIG = {
	mode = "individual", -- "individual" or "consolidated"
	modules = {
		lyrics = {
			enabled = true,
			display = "individual", -- "individual" or "consolidated"
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

local M = {}

function M.get()
	local saved = hs.settings.get(SETTINGS_KEY)
	if saved then
		local config = hs.fnutils.copy(DEFAULT_CONFIG)
		if saved.mode then
			config.mode = saved.mode
		end
		if saved.modules then
			for module, settings in pairs(saved.modules) do
				if config.modules[module] then
					config.modules[module] = hs.fnutils.copy(settings)
				end
			end
		end
		return config
	end
	return hs.fnutils.copy(DEFAULT_CONFIG)
end

function M.save(config)
	hs.settings.set(SETTINGS_KEY, config)
end

function M.setMode(mode)
	local config = M.get()
	config.mode = mode
	M.save(config)
end

function M.setModuleDisplay(moduleName, display)
	local config = M.get()
	if config.modules[moduleName] then
		config.modules[moduleName].display = display
	end
	M.save(config)
end

function M.setModuleEnabled(moduleName, enabled)
	local config = M.get()
	if config.modules[moduleName] then
		config.modules[moduleName].enabled = enabled
	end
	M.save(config)
end

function M.isModuleEnabled(moduleName)
	local config = M.get()
	return config.modules[moduleName] and config.modules[moduleName].enabled or false
end

function M.getModuleDisplay(moduleName)
	local config = M.get()
	return config.modules[moduleName] and config.modules[moduleName].display or "consolidated"
end

return M
