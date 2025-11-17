local menubarConfig = require("menubar_config")

local M = {}

local consolidatedMenubar = nil
local moduleMenubars = {}
local moduleMenuItems = {}
local moduleIcons = {}
local moduleTooltips = {}

local updateConsolidatedMenu

local function getDisplayMode(moduleName)
	local config = menubarConfig.get()
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
	local config = menubarConfig.get()
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
	local config = menubarConfig.get()

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
					menubarConfig.setMode("individual")
					M.refresh()
				end,
				checked = config.mode == "individual",
			},
			{
				title = "Consolidated Menu",
				fn = function()
					menubarConfig.setMode("consolidated")
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
								menubarConfig.setModuleDisplay(moduleName, "individual")
								M.refresh()
							end,
							checked = moduleConfig.display == "individual",
						},
						{
							title = "In Consolidated Menu",
							fn = function()
								menubarConfig.setModuleDisplay(moduleName, "consolidated")
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
	return menubarConfig.get()
end

return M
