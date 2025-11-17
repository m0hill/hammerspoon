local M = {}

local SETTINGS_KEY = "menubar.config"
local DEFAULT_CONFIG = nil

local consolidatedMenubar = nil
local moduleMenubars = {}
local moduleMenuItems = {}
local moduleIcons = {}
local moduleTooltips = {}

local updateConsolidatedMenu

function M.init(config)
	DEFAULT_CONFIG = config
end

local function getConfig()
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

local function saveConfig(config)
	hs.settings.set(SETTINGS_KEY, config)
end

local function setMode(mode)
	local config = getConfig()
	config.mode = mode
	saveConfig(config)
end

local function setModuleDisplay(moduleName, display)
	local config = getConfig()
	if config.modules[moduleName] then
		config.modules[moduleName].display = display
	end
	saveConfig(config)
end

local function getDisplayMode(moduleName)
	local config = getConfig()
	local moduleConfig = config.modules[moduleName]

	if not moduleConfig or not moduleConfig.enabled then
		return "none"
	end

	if config.mode == "consolidated" then
		return "consolidated"
	end

	return moduleConfig.display or "individual"
end

local function createConsolidatedMenubar()
	if not consolidatedMenubar then
		consolidatedMenubar = hs.menubar.new()
		consolidatedMenubar:setIcon(hs.image.imageFromName("NSActionTemplate"))
		consolidatedMenubar:setTooltip("Hammerspoon Modules")
	end
	return consolidatedMenubar
end

local function createIndividualMenubar(moduleName)
	if not moduleMenubars[moduleName] then
		moduleMenubars[moduleName] = hs.menubar.new()
	end
	return moduleMenubars[moduleName]
end

local function destroyIndividualMenubar(moduleName)
	if moduleMenubars[moduleName] then
		moduleMenubars[moduleName]:delete()
		moduleMenubars[moduleName] = nil
	end
end

local function destroyConsolidatedMenubar()
	if consolidatedMenubar then
		consolidatedMenubar:delete()
		consolidatedMenubar = nil
	end
end

local function needsConsolidatedMenubar()
	local config = getConfig()
	if config.mode == "consolidated" then
		return true
	end

	for moduleName, _ in pairs(moduleMenuItems) do
		if getDisplayMode(moduleName) == "consolidated" then
			return true
		end
	end

	return false
end

updateConsolidatedMenu = function()
	if not consolidatedMenubar then
		return
	end

	local menu = {}
	local config = getConfig()

	for moduleName, items in pairs(moduleMenuItems) do
		if getDisplayMode(moduleName) == "consolidated" then
			table.insert(menu, {
				title = moduleName:gsub("^%l", string.upper),
				menu = items,
			})
		end
	end

	if #menu > 0 then
		table.insert(menu, { title = "-" })
	end

	table.insert(menu, {
		title = "Display Mode",
		menu = {
			{
				title = "Individual Icons",
				fn = function()
					setMode("individual")
					M.refresh()
				end,
				checked = config.mode == "individual",
			},
			{
				title = "Consolidated Menu",
				fn = function()
					setMode("consolidated")
					M.refresh()
				end,
				checked = config.mode == "consolidated",
			},
		},
	})

	if config.mode == "individual" then
		table.insert(menu, { title = "-" })
		table.insert(menu, { title = "Module Display Settings", disabled = true })

		for moduleName, _ in pairs(moduleMenuItems) do
			local moduleConfig = config.modules[moduleName]
			if moduleConfig then
				table.insert(menu, {
					title = moduleName:gsub("^%l", string.upper),
					menu = {
						{
							title = "Individual Icon",
							fn = function()
								setModuleDisplay(moduleName, "individual")
								M.refresh()
							end,
							checked = moduleConfig.display == "individual",
						},
						{
							title = "In Consolidated Menu",
							fn = function()
								setModuleDisplay(moduleName, "consolidated")
								M.refresh()
							end,
							checked = moduleConfig.display == "consolidated",
						},
					},
				})
			end
		end
	end

	consolidatedMenubar:setMenu(menu)
end

function M.registerModule(moduleName, menuItems, icon, tooltip)
	moduleMenuItems[moduleName] = menuItems
	moduleIcons[moduleName] = icon
	moduleTooltips[moduleName] = tooltip or moduleName

	M.refresh()
end

function M.updateModule(moduleName, menuItems, icon, tooltip)
	if moduleMenuItems[moduleName] then
		moduleMenuItems[moduleName] = menuItems

		if icon then
			moduleIcons[moduleName] = icon
		end
		if tooltip then
			moduleTooltips[moduleName] = tooltip
		end

		local displayMode = getDisplayMode(moduleName)

		if displayMode == "individual" and moduleMenubars[moduleName] then
			moduleMenubars[moduleName]:setMenu(menuItems)
			if icon then
				moduleMenubars[moduleName]:setIcon(icon)
			end
			if tooltip then
				moduleMenubars[moduleName]:setTooltip(tooltip)
			end
		elseif displayMode == "consolidated" then
			updateConsolidatedMenu()
		end
	end
end

function M.unregisterModule(moduleName)
	moduleMenuItems[moduleName] = nil
	moduleIcons[moduleName] = nil
	moduleTooltips[moduleName] = nil

	destroyIndividualMenubar(moduleName)

	M.refresh()
end

function M.refresh()
	local needsConsolidated = needsConsolidatedMenubar()

	if needsConsolidated then
		createConsolidatedMenubar()
		updateConsolidatedMenu()
	else
		destroyConsolidatedMenubar()
	end

	for moduleName, items in pairs(moduleMenuItems) do
		local displayMode = getDisplayMode(moduleName)

		if displayMode == "individual" then
			local menubar = createIndividualMenubar(moduleName)
			menubar:setMenu(items)

			local icon = moduleIcons[moduleName]
			if icon then
				menubar:setIcon(icon)
			end

			local tooltip = moduleTooltips[moduleName]
			if tooltip then
				menubar:setTooltip(tooltip)
			end
		elseif displayMode == "consolidated" then
			destroyIndividualMenubar(moduleName)
		elseif displayMode == "none" then
			destroyIndividualMenubar(moduleName)
		end
	end
end

function M.getConfig()
	return getConfig()
end

return M
