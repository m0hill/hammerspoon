local menubar = require("lib.menubar")
local modulesConfig = require("modules_config")

local MENUBAR_CONFIG = modulesConfig.MENUBAR_CONFIG
menubar.init(MENUBAR_CONFIG)

for name, cfg in pairs(MENUBAR_CONFIG.modules) do
	if cfg.enabled then
		local ok, mod = pcall(require, "spoons." .. name)
		if ok and mod and mod.init then
			mod.init(menubar)
			if mod.start then
				mod.start()
			end
		else
			print(string.format("[power-spoons] Failed to load module '%s'", name))
		end
	end
end

print("[power-spoons] Initialization complete")
