local env = require("env")

local CONFIG = {
	HOTKEY_MODS = { "cmd", "shift" },
	HOTKEY_KEY = "s",
	MODEL = "gemini-flash-lite-latest",
	MIME_TYPE = "image/png",
	PROMPT = table.concat({
		"Extract all text from this image. If the text is in a non-english language. Traslate it to English.",
		"Format it in a clear, organized way with proper spacing and line breaks.",
		"Use only these symbols: hyphens (-), commas (,), numbers (1, 2, 3), and spaces for indentation.",
		"When separating information, use a hyphen (-) or comma (,) or space or new line (whatever is appropriate).",
		"Do not use bullets or bullet symbols like •. Do not use asterisks.",
		"Put your entire answer inside a code block using three backticks (```).",
	}, " "),
	SCREENSHOT_PATH_TEMPLATE = "gemini_capture_%d.png",
	SCREENSHOT_TIMEOUT = 60,
	INDICATOR_COLOR = { red = 0.4, green = 0.8, blue = 0.2, alpha = 0.9 },
	ENABLE_NOTIFY = true,
	ENABLE_SOUND = true,
}

local MODELS = {
	{ text = "Gemini Flash", value = "gemini-flash-latest" },
	{ text = "Gemini Flash Lite", value = "gemini-flash-lite-latest" },
}

local state = {
	captureTask = nil,
	busy = false,
	timer = nil,
	indicator = nil,
	indicatorTimer = nil,
	pulseTimer = nil,
	pulseDirection = 1,
	pulseAlpha = 0.3,
}

local menubarManager = nil

local function playSound(type)
	if not CONFIG.ENABLE_SOUND then
		return
	end

	local sounds = {
		capture = "Tink",
		process = "Purr",
		success = "Glass",
		error = "Basso",
		cancel = "Funk",
	}

	if sounds[type] then
		hs.sound.getByName(sounds[type]):play()
	end
end

local function notify(title, text, sound)
	if not CONFIG.ENABLE_NOTIFY then
		return
	end
	local notification = hs.notify.new({ title = title, informativeText = text or "", withdrawAfter = 4 })
	if sound and CONFIG.ENABLE_SOUND then
		notification:soundName(sound)
	end
	notification:send()
end

local function cleanUp(path)
	if path and hs.fs.attributes(path) then
		os.remove(path)
	end
end

local function cleanupIndicator()
	if state.indicatorTimer then
		state.indicatorTimer:stop()
		state.indicatorTimer = nil
	end

	if state.pulseTimer then
		state.pulseTimer:stop()
		state.pulseTimer = nil
	end

	if state.indicator then
		state.indicator:delete()
		state.indicator = nil
	end

	state.pulseAlpha = 0.3
	state.pulseDirection = 1
end

local function reset(path)
	state.busy = false
	if state.captureTask then
		state.captureTask = nil
	end
	if state.timer then
		state.timer:stop()
		state.timer = nil
	end
	cleanupIndicator()
	cleanUp(path)
end

local function createProcessingIndicator()
	local mousePos = hs.mouse.absolutePosition()
	state.indicator = hs.canvas.new({
		x = mousePos.x - 15,
		y = mousePos.y - 35,
		w = 30,
		h = 30,
	})

	state.indicator[1] = {
		type = "circle",
		action = "stroke",
		strokeColor = { red = 0.4, green = 0.8, blue = 0.2, alpha = state.pulseAlpha },
		strokeWidth = 3,
		center = { x = 15, y = 15 },
		radius = 12,
	}

	state.indicator[2] = {
		type = "circle",
		action = "fill",
		fillColor = CONFIG.INDICATOR_COLOR,
		center = { x = 15, y = 15 },
		radius = 6,
	}

	state.indicator:show()

	state.indicatorTimer = hs.timer.new(0.05, function()
		if state.indicator then
			local pos = hs.mouse.absolutePosition()
			state.indicator:topLeft({ x = pos.x - 15, y = pos.y - 35 })
		end
	end)
	state.indicatorTimer:start()

	state.pulseTimer = hs.timer.new(0.03, function()
		if state.indicator and state.indicator[1] then
			state.pulseAlpha = state.pulseAlpha + (state.pulseDirection * 0.02)
			if state.pulseAlpha >= 0.9 then
				state.pulseDirection = -1
			elseif state.pulseAlpha <= 0.3 then
				state.pulseDirection = 1
			end

			state.indicator[1] = {
				type = "circle",
				action = "stroke",
				strokeColor = { red = 0.4, green = 0.8, blue = 0.2, alpha = state.pulseAlpha },
				strokeWidth = 3,
				center = { x = 15, y = 15 },
				radius = 12,
			}
		end
	end)
	state.pulseTimer:start()
end

local function getModelDisplayName()
	for _, model in ipairs(MODELS) do
		if model.value == CONFIG.MODEL then
			return model.text
		end
	end
	return CONFIG.MODEL
end

local updateMenuBar

local function getMenuItems()
	local statusTitle = state.busy and "Processing..." or "Ready"

	local modelSubmenu = {}
	for _, model in ipairs(MODELS) do
		table.insert(modelSubmenu, {
			title = model.text,
			fn = function()
				CONFIG.MODEL = model.value
				notify("Model Changed", "Set to: " .. model.text, "Glass")
				updateMenuBar()
			end,
			checked = CONFIG.MODEL == model.value,
		})
	end

	return {
		{ title = "Gemini OCR - " .. statusTitle, disabled = true },
		{ title = "-" },
		{
			title = "Model: " .. getModelDisplayName(),
			menu = modelSubmenu,
		},
		{ title = "-" },
		{
			title = "Notifications",
			fn = function()
				CONFIG.ENABLE_NOTIFY = not CONFIG.ENABLE_NOTIFY
				local message = "Notifications " .. (CONFIG.ENABLE_NOTIFY and "enabled" or "disabled")
				if CONFIG.ENABLE_NOTIFY then
					notify("Settings", message, "Glass")
				end
				updateMenuBar()
			end,
			checked = CONFIG.ENABLE_NOTIFY,
		},
		{
			title = "Sounds",
			fn = function()
				CONFIG.ENABLE_SOUND = not CONFIG.ENABLE_SOUND
				local message = "Sounds " .. (CONFIG.ENABLE_SOUND and "enabled" or "disabled")
				if CONFIG.ENABLE_NOTIFY then
					hs.notify.new({ title = "Settings", informativeText = message }):send()
				end
				updateMenuBar()
			end,
			checked = CONFIG.ENABLE_SOUND,
		},
		{ title = "-" },
		{
			title = "Hotkey: " .. table.concat(CONFIG.HOTKEY_MODS, "+") .. "+" .. CONFIG.HOTKEY_KEY,
			disabled = true,
		},
	}
end

updateMenuBar = function()
	if menubarManager then
		menubarManager.updateModule(
			"gemini",
			getMenuItems(),
			hs.image.imageFromName("NSTouchBarTextListTemplate"),
			"Gemini OCR\n" .. table.concat(CONFIG.HOTKEY_MODS, "+") .. "+" .. CONFIG.HOTKEY_KEY .. " to capture"
		)
	end
end

local function extractTextFromResponse(body)
	if type(body) ~= "table" then
		return nil
	end

	local candidates = body.candidates
	if type(candidates) ~= "table" then
		return nil
	end

	for _, candidate in ipairs(candidates) do
		local content = candidate.content
		if type(content) == "table" then
			local parts = content.parts
			if type(parts) == "table" then
				for _, part in ipairs(parts) do
					if type(part.text) == "string" and part.text ~= "" then
						return part.text
					end
				end
			end
		end
	end

	return nil
end

local function postToGemini(path)
	local attrs = hs.fs.attributes(path)
	if not attrs or attrs.size == 0 then
		reset(path)
		notify("Gemini OCR", "No screenshot captured", "Funk")
		playSound("cancel")
		return
	end

	local apiKey = env.get("GEMINI_API_KEY")
	if not apiKey or apiKey == "" then
		reset(path)
		notify("Gemini OCR", "GEMINI_API_KEY is missing", "Basso")
		playSound("error")
		return
	end

	local file = io.open(path, "rb")
	if not file then
		reset(path)
		notify("Gemini OCR", "Unable to read screenshot", "Basso")
		playSound("error")
		return
	end

	local bytes = file:read("*all")
	file:close()

	local encoded = hs.base64.encode(bytes, false)
	local payload = {
		contents = {
			{
				parts = {
					{
						inline_data = {
							mime_type = CONFIG.MIME_TYPE,
							data = encoded,
						},
					},
					{
						text = CONFIG.PROMPT,
					},
				},
			},
		},
	}

	local body = hs.json.encode(payload)
	local headers = {
		["Content-Type"] = "application/json",
		["x-goog-api-key"] = apiKey,
	}

	local apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/" .. CONFIG.MODEL .. ":generateContent"

	playSound("process")
	createProcessingIndicator()
	updateMenuBar()

	hs.http.asyncPost(apiUrl, body, headers, function(status, responseData, responseHeaders)
		cleanupIndicator()
		local resultText = nil
		if status == 200 and type(responseData) == "string" then
			local ok, decoded = pcall(hs.json.decode, responseData)
			if ok then
				resultText = extractTextFromResponse(decoded)
			end
		end

		if not resultText or resultText == "" then
			reset(path)
			notify("Gemini OCR", "Failed to interpret API response", "Basso")
			playSound("error")
			updateMenuBar()
			return
		end

		local cleaned = resultText:gsub("^```[%w]*\n?", ""):gsub("\n?```$", "")

		hs.pasteboard.setContents(cleaned)

		local preview = cleaned
		if #preview > 150 then
			preview = preview:sub(1, 147) .. "..."
		end

		notify("Gemini OCR", preview, "Glass")
		playSound("success")
		reset(path)
		updateMenuBar()
	end)
end

local function onCaptureFinished(tmpPath)
	postToGemini(tmpPath)
end

local function startCapture()
	if state.busy then
		notify("Gemini OCR", "Please wait for the previous request", "Funk")
		return
	end

	local tmpDir = hs.fs.temporaryDirectory()
	local tmpPath = tmpDir .. string.format(CONFIG.SCREENSHOT_PATH_TEMPLATE, hs.timer.absoluteTime())
	state.busy = true

	state.timer = hs.timer.doAfter(CONFIG.SCREENSHOT_TIMEOUT, function()
		if state.captureTask then
			state.captureTask:terminate()
		end
		reset(tmpPath)
		notify("Gemini OCR", "Screenshot timed out", "Basso")
	end)

	state.captureTask = hs.task.new("/usr/sbin/screencapture", function(exitCode)
		if exitCode ~= 0 then
			reset(tmpPath)
			notify("Gemini OCR", "Capture cancelled", "Funk")
			playSound("cancel")
			updateMenuBar()
			return
		end

		if state.timer then
			state.timer:stop()
			state.timer = nil
		end

		playSound("capture")
		onCaptureFinished(tmpPath)
	end, { "-i", "-o", "-x", "-t", "png", tmpPath })

	if not state.captureTask:start() then
		reset(tmpPath)
		notify("Gemini OCR", "Unable to start screenshot", "Basso")
		playSound("error")
		updateMenuBar()
		return
	end
end

local M = {}

function M.init(manager)
	menubarManager = manager
	menubarManager.registerModule(
		"gemini",
		getMenuItems(),
		hs.image.imageFromName("NSTouchBarTextListTemplate"),
		"Gemini OCR\n" .. table.concat(CONFIG.HOTKEY_MODS, "+") .. "+" .. CONFIG.HOTKEY_KEY .. " to capture"
	)

	hs.hotkey.bind(CONFIG.HOTKEY_MODS, CONFIG.HOTKEY_KEY, startCapture)
end

function M.stop()
	if menubarManager then
		menubarManager.unregisterModule("gemini")
		menubarManager = nil
	end
end

return M
