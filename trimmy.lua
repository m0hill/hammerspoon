local SETTINGS_PREFIX = "trimmy."
local POLL_INTERVAL = 0.15

local settings = {
	aggressiveness = hs.settings.get(SETTINGS_PREFIX .. "aggressiveness") or "normal",
	preserveBlankLines = hs.settings.get(SETTINGS_PREFIX .. "preserveBlankLines") or false,
	autoTrimEnabled = hs.settings.get(SETTINGS_PREFIX .. "autoTrimEnabled") or true,
}

local lastChangeCount = hs.pasteboard.changeCount()
local lastSummary = "No trims yet"
local clipboardWatcher = nil
local menubar = nil

local function saveSetting(key, value)
	hs.settings.set(SETTINGS_PREFIX .. key, value)
end

local function getScoreThreshold()
	if settings.aggressiveness == "low" then
		return 3
	elseif settings.aggressiveness == "high" then
		return 1
	else
		return 2
	end
end

local function isLikelyCommandLine(line)
	local trimmed = line:match("^%s*(.-)%s*$")
	if trimmed == "" then
		return false
	end
	if trimmed:sub(-1) == "." then
		return false
	end
	return trimmed:match("^sudo%s+[A-Za-z0-9./~_-]+") ~= nil or trimmed:match("^[A-Za-z0-9./~_-]+") ~= nil
end

local function flatten(text)
	local result = text
	local placeholder = "__BLANK_SEP__"

	if settings.preserveBlankLines then
		result = result:gsub("\n%s*\n", placeholder)
	end

	result = result:gsub("([A-Z0-9_.-])%s*\n%s*([A-Z0-9_.-])", "%1%2")
	result = result:gsub("\\%s*\n", " ")
	result = result:gsub("\n+", " ")
	result = result:gsub("%s+", " ")

	if settings.preserveBlankLines then
		result = result:gsub(placeholder, "\n\n")
	end

	return result:match("^%s*(.-)%s*$")
end

local function transformIfCommand(text)
	if not text or text == "" then
		return nil
	end
	if not text:find("\n") then
		return nil
	end

	local lines = {}
	for line in text:gmatch("[^\n]+") do
		table.insert(lines, line)
	end

	if #lines < 2 then
		return nil
	end
	if #lines > 10 then
		return nil
	end

	local score = 0

	if text:find("\\\n") then
		score = score + 1
	end
	if text:find("[|&][|&]?") then
		score = score + 1
	end
	if text:find("^%s*$") or text:find("\n%s*$") then
		score = score + 1
	end

	local allLikeCommands = true
	for _, line in ipairs(lines) do
		if not line:match("^%s*$") and not isLikelyCommandLine(line) then
			allLikeCommands = false
			break
		end
	end
	if allLikeCommands then
		score = score + 1
	end

	if text:find("^%s*sudo%s+") or text:find("\n%s*sudo%s+") or text:find("^%s*[A-Za-z0-9./~_-]+") then
		score = score + 1
	end

	if text:find("[-/]") then
		score = score + 1
	end

	if score < getScoreThreshold() then
		return nil
	end

	local flattened = flatten(text)
	if flattened == text then
		return nil
	end

	return flattened
end

local function trimClipboardIfNeeded(force)
	force = force or false

	local currentCount = hs.pasteboard.changeCount()
	if not force and currentCount == lastChangeCount then
		return false
	end

	local text = hs.pasteboard.getContents()
	if not text then
		return false
	end

	if not settings.autoTrimEnabled and not force then
		return false
	end

	local transformed
	if force then
		transformed = transformIfCommand(text) or text
		if transformed == text and not text:find("\\\n") and not text:find("\n") then
			return false
		end
	else
		transformed = transformIfCommand(text)
		if not transformed then
			return false
		end
	end

	hs.pasteboard.setContents(transformed)
	lastChangeCount = hs.pasteboard.changeCount()
	lastSummary = transformed:gsub("\n", " "):sub(1, 70)

	if force then
		hs.notify
			.new({
				title = "Trimmy",
				informativeText = "Clipboard trimmed",
				withdrawAfter = 2,
			})
			:send()
	end

	return true
end

local function clipboardChanged()
	local currentCount = hs.pasteboard.changeCount()
	if currentCount ~= lastChangeCount then
		local observed = currentCount
		hs.timer.doAfter(0.08, function()
			if hs.pasteboard.changeCount() == observed then
				trimClipboardIfNeeded(false)
				lastChangeCount = hs.pasteboard.changeCount()
			end
		end)
	end
end

local function updateMenu()
	if not menubar then
		return
	end

	menubar:setMenu({
		{
			title = "Auto-Trim: " .. (settings.autoTrimEnabled and "✓ On" or "✗ Off"),
			fn = function()
				settings.autoTrimEnabled = not settings.autoTrimEnabled
				saveSetting("autoTrimEnabled", settings.autoTrimEnabled)
				updateMenu()
			end,
		},
		{ title = "-" },
		{
			title = "Trim Clipboard Now",
			fn = function()
				trimClipboardIfNeeded(true)
			end,
		},
		{
			title = "Last: " .. lastSummary,
			disabled = true,
		},
		{ title = "-" },
		{
			title = "Aggressiveness",
			menu = {
				{
					title = (settings.aggressiveness == "low" and "✓ " or "") .. "Low (safer)",
					fn = function()
						settings.aggressiveness = "low"
						saveSetting("aggressiveness", "low")
						updateMenu()
					end,
				},
				{
					title = (settings.aggressiveness == "normal" and "✓ " or "") .. "Normal",
					fn = function()
						settings.aggressiveness = "normal"
						saveSetting("aggressiveness", "normal")
						updateMenu()
					end,
				},
				{
					title = (settings.aggressiveness == "high" and "✓ " or "") .. "High (more eager)",
					fn = function()
						settings.aggressiveness = "high"
						saveSetting("aggressiveness", "high")
						updateMenu()
					end,
				},
			},
		},
		{
			title = (settings.preserveBlankLines and "✓ " or "") .. "Keep blank lines",
			fn = function()
				settings.preserveBlankLines = not settings.preserveBlankLines
				saveSetting("preserveBlankLines", settings.preserveBlankLines)
				updateMenu()
			end,
		},
	})
end

local function init()
	menubar = hs.menubar.new()
	menubar:setIcon(hs.image.imageFromName("NSActionTemplate"))
	menubar:setTooltip("Trimmy - Clipboard command flattener")
	updateMenu()

	if clipboardWatcher then
		clipboardWatcher:stop()
	end
	clipboardWatcher = hs.timer.new(POLL_INTERVAL, clipboardChanged)
	clipboardWatcher:start()

	lastChangeCount = hs.pasteboard.changeCount()

	print("Trimmy started - watching clipboard")
end

init()
