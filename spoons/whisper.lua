local env = require("lib.env")

local CONFIG = {
	MODEL = "whisper-large-v3-turbo",
	SAMPLE_RATE = 16000,
	MIN_BYTES = 1000,
	MAX_HOLD_SECONDS = 300,
	ENABLE_NOTIFY = true,
	ENABLE_SOUND = true,
	RECORDING_INDICATOR_COLOR = { red = 1, green = 0, blue = 0, alpha = 0.9 },
	TRANSCRIBING_INDICATOR_COLOR = { red = 0, green = 0.8, blue = 1, alpha = 0.9 },
	API_TIMEOUT = 90,
	LANGUAGE = nil,
	RESPONSE_FORMAT = "json",
	HOTKEY_MODS = { "option" },
	HOTKEY_KEY = "/",
}

local LANGUAGES = {
	{ text = "Auto-detect", value = nil },
	{ text = "English", value = "en" },
	{ text = "Spanish", value = "es" },
	{ text = "French", value = "fr" },
	{ text = "German", value = "de" },
	{ text = "Italian", value = "it" },
	{ text = "Portuguese", value = "pt" },
	{ text = "Russian", value = "ru" },
	{ text = "Japanese", value = "ja" },
	{ text = "Korean", value = "ko" },
	{ text = "Chinese", value = "zh" },
	{ text = "Arabic", value = "ar" },
	{ text = "Hindi", value = "hi" },
}

local GROQ_API_KEY = env.get("GROQ_API_KEY")
local REC = nil
local menubarManager = nil
local isRecording = false
local isBusy = false
local recTask = nil
local stopTimer = nil
local wavPath = nil
local recordingIndicator = nil
local transcribingIndicator = nil
local indicatorTimer = nil
local pulseTimer = nil
local pulseDirection = 1
local pulseAlpha = 0.3
local telemetry = nil

local updateUI
local stopRecordingAndTranscribe

local function notify(title, text, sound)
	if not CONFIG.ENABLE_NOTIFY then
		return
	end
	local notification = hs.notify.new({
		title = title,
		informativeText = text or "",
		withdrawAfter = 3,
	})
	if sound and CONFIG.ENABLE_SOUND then
		notification:soundName(sound)
	end
	notification:send()
end

local function playSound(type)
	if not CONFIG.ENABLE_SOUND then
		return
	end

	local sounds = {
		start = "Ping",
		stop = "Purr",
		error = "Basso",
		success = "Glass",
	}

	if sounds[type] then
		hs.sound.getByName(sounds[type]):play()
	end
end

local function formatDuration(value)
	if not value or value <= 0 then
		return "n/a"
	end
	return string.format("%.2fs", value)
end

local function toNumber(value)
	if type(value) == "number" then
		return value
	elseif type(value) == "string" and value ~= "" then
		local parsed = tonumber(value)
		if parsed and parsed >= 0 then
			return parsed
		end
	end
	return nil
end

local function buildTelemetrySummary()
	if not telemetry then
		return nil
	end

	local metrics = telemetry.curlMetrics or {}
	local parts = {}

	if telemetry.recordingDuration then
		table.insert(parts, "record " .. formatDuration(telemetry.recordingDuration))
	end

	local upload = toNumber(metrics.time_upload)
	if upload and upload > 0 then
		table.insert(parts, "upload " .. formatDuration(upload))
	end

	local responseWait = nil
	local startTransfer = toNumber(metrics.time_starttransfer)
	local uploadRef = toNumber(metrics.time_upload)
	if startTransfer and uploadRef then
		responseWait = startTransfer - uploadRef
		if responseWait <= 0 then
			responseWait = nil
		end
	end
	if responseWait then
		table.insert(parts, "server " .. formatDuration(responseWait))
	end

	local download = toNumber(metrics.time_download)
	if download and download > 0 then
		table.insert(parts, "download " .. formatDuration(download))
	end

	local total = toNumber(metrics.time_total)
	if total and total > 0 then
		table.insert(parts, "api " .. formatDuration(total))
	end

	if telemetry.transcriptionStartedAt and telemetry.transcriptionFinishedAt and total and total > 0 then
		local measured = telemetry.transcriptionFinishedAt - telemetry.transcriptionStartedAt
		if measured and measured > total then
			local localTime = measured - total
			if localTime > 0 then
				table.insert(parts, "local " .. formatDuration(localTime))
			end
		end
	end

	if #parts > 0 then
		return "⏱ " .. table.concat(parts, " | ")
	end

	return nil
end

local function which(cmd)
	local out = hs.execute("command -v " .. cmd)
	out = (out or ""):gsub("%s+$", "")
	if out ~= "" then
		return out
	end

	local fallbacks = {
		"/opt/homebrew/bin/" .. cmd,
		"/usr/local/bin/" .. cmd,
		"/usr/bin/" .. cmd,
	}

	for _, p in ipairs(fallbacks) do
		if hs.fs.attributes(p, "mode") then
			return p
		end
	end

	return nil
end

local function tmpWavPath()
	local dir = os.getenv("TMPDIR") or "/tmp/"
	local name = string.format("hs-whisper-%d-%d.wav", os.time(), math.random(1000, 9999))
	return dir .. name
end

local function checkDependencies()
	REC = which("rec")
	if not REC then
		notify("Setup Error", "'sox' is not installed. Run: brew install sox", "Basso")
		return false
	end

	if not GROQ_API_KEY or GROQ_API_KEY == "" then
		notify("Setup Error", "GROQ_API_KEY is missing. Set environment variable.", "Basso")
		return false
	end

	return true
end

local function formatLanguageName(langCode)
	if not langCode then
		return "Auto-detect"
	end
	for _, lang in ipairs(LANGUAGES) do
		if lang.value == langCode then
			return lang.text
		end
	end
	return langCode
end

local function toggleNotifications()
	CONFIG.ENABLE_NOTIFY = not CONFIG.ENABLE_NOTIFY
	notify("Settings", "Notifications " .. (CONFIG.ENABLE_NOTIFY and "enabled" or "disabled"), "Glass")
	updateUI()
end

local function toggleSounds()
	CONFIG.ENABLE_SOUND = not CONFIG.ENABLE_SOUND
	local message = "Sounds " .. (CONFIG.ENABLE_SOUND and "enabled" or "disabled")
	if CONFIG.ENABLE_NOTIFY then
		hs.notify.new({ title = "Settings", informativeText = message }):send()
	end
	updateUI()
end

local function showAbout()
	local aboutText = string.format(
		[[Whisper Transcription v1.0

Model: %s
Language: %s
Hotkey: %s

Dependencies:
• sox: %s
• GROQ API Key: %s

Hold the hotkey to record speech, release to transcribe and paste.]],
		CONFIG.MODEL,
		formatLanguageName(CONFIG.LANGUAGE),
		table.concat(CONFIG.HOTKEY_MODS, "+") .. "+" .. CONFIG.HOTKEY_KEY,
		REC and "Installed" or "Missing",
		(GROQ_API_KEY and GROQ_API_KEY ~= "") and "Set" or "Missing"
	)

	hs.dialog.blockAlert("About Whisper Transcription", aboutText, "OK")
end

local function getMenuItems()
	if isRecording then
		return {
			{ title = "Recording...", disabled = true },
			{ title = "-" },
			{ title = "Stop Recording", fn = stopRecordingAndTranscribe },
		}
	elseif isBusy then
		return {
			{ title = "Transcribing...", disabled = true },
		}
	else
		local languageSubmenu = {}
		for _, lang in ipairs(LANGUAGES) do
			table.insert(languageSubmenu, {
				title = lang.text,
				fn = function()
					CONFIG.LANGUAGE = lang.value
					notify("Language Changed", "Set to: " .. lang.text, "Glass")
					updateUI()
				end,
				checked = CONFIG.LANGUAGE == lang.value,
			})
		end

		return {
			{ title = "Ready to Record", disabled = true },
			{ title = "-" },
			{
				title = "Language: " .. formatLanguageName(CONFIG.LANGUAGE),
				menu = languageSubmenu,
			},
			{
				title = "Model: " .. (CONFIG.MODEL == "whisper-large-v3" and "Large v3" or "Large v3 Turbo"),
				menu = {
					{
						title = "Whisper Large v3 ($0.111/hr)",
						fn = function()
							CONFIG.MODEL = "whisper-large-v3"
							notify("Model Changed", "Set to: Whisper Large v3", "Glass")
							updateUI()
						end,
						checked = CONFIG.MODEL == "whisper-large-v3",
					},
					{
						title = "Whisper Large v3 Turbo ($0.04/hr)",
						fn = function()
							CONFIG.MODEL = "whisper-large-v3-turbo"
							notify("Model Changed", "Set to: Whisper Large v3 Turbo", "Glass")
							updateUI()
						end,
						checked = CONFIG.MODEL == "whisper-large-v3-turbo",
					},
				},
			},
			{ title = "-" },
			{
				title = "Notifications",
				fn = toggleNotifications,
				checked = CONFIG.ENABLE_NOTIFY,
			},
			{
				title = "Sounds",
				fn = toggleSounds,
				checked = CONFIG.ENABLE_SOUND,
			},
			{ title = "-" },
			{
				title = "About",
				fn = showAbout,
			},
		}
	end
end

local function getIcon()
	if isRecording then
		return hs.image.imageFromName("NSStatusAvailable")
	elseif isBusy then
		return hs.image.imageFromName("NSStatusPartiallyAvailable")
	else
		return hs.image.imageFromName("NSTouchBarRecordStartTemplate")
	end
end

local function getTooltip()
	if isRecording then
		return "Recording audio... (Hold to continue)"
	elseif isBusy then
		return "Transcribing audio..."
	else
		return "Whisper Transcription Ready\nHold "
			.. table.concat(CONFIG.HOTKEY_MODS, "+")
			.. "+"
			.. CONFIG.HOTKEY_KEY
			.. " to record"
	end
end

updateUI = function()
	if menubarManager then
		menubarManager.updateModule("whisper", getMenuItems(), getIcon(), getTooltip())
	end
end

local function createRecordingIndicator()
	local mousePos = hs.mouse.absolutePosition()
	recordingIndicator = hs.canvas.new({
		x = mousePos.x - 15,
		y = mousePos.y - 35,
		w = 30,
		h = 30,
	})

	recordingIndicator[1] = {
		type = "circle",
		action = "stroke",
		strokeColor = CONFIG.RECORDING_INDICATOR_COLOR,
		strokeWidth = 2,
		center = { x = 15, y = 15 },
		radius = 12,
	}

	recordingIndicator[2] = {
		type = "circle",
		action = "fill",
		fillColor = CONFIG.RECORDING_INDICATOR_COLOR,
		center = { x = 15, y = 15 },
		radius = 8,
	}

	recordingIndicator:show()

	indicatorTimer = hs.timer.new(0.05, function()
		if recordingIndicator then
			local pos = hs.mouse.absolutePosition()
			recordingIndicator:topLeft({ x = pos.x - 15, y = pos.y - 35 })
		end
	end)
	indicatorTimer:start()
end

local function createTranscribingIndicator()
	local mousePos = hs.mouse.absolutePosition()
	transcribingIndicator = hs.canvas.new({
		x = mousePos.x - 15,
		y = mousePos.y - 35,
		w = 30,
		h = 30,
	})

	transcribingIndicator[1] = {
		type = "circle",
		action = "stroke",
		strokeColor = { red = 0, green = 0.8, blue = 1, alpha = pulseAlpha },
		strokeWidth = 3,
		center = { x = 15, y = 15 },
		radius = 12,
	}

	transcribingIndicator[2] = {
		type = "circle",
		action = "fill",
		fillColor = CONFIG.TRANSCRIBING_INDICATOR_COLOR,
		center = { x = 15, y = 15 },
		radius = 6,
	}

	transcribingIndicator:show()

	indicatorTimer = hs.timer.new(0.05, function()
		if transcribingIndicator then
			local pos = hs.mouse.absolutePosition()
			transcribingIndicator:topLeft({ x = pos.x - 15, y = pos.y - 35 })
		end
	end)
	indicatorTimer:start()

	pulseTimer = hs.timer.new(0.03, function()
		if transcribingIndicator and transcribingIndicator[1] then
			pulseAlpha = pulseAlpha + (pulseDirection * 0.02)
			if pulseAlpha >= 0.9 then
				pulseDirection = -1
			elseif pulseAlpha <= 0.3 then
				pulseDirection = 1
			end

			transcribingIndicator[1] = {
				type = "circle",
				action = "stroke",
				strokeColor = { red = 0, green = 0.8, blue = 1, alpha = pulseAlpha },
				strokeWidth = 3,
				center = { x = 15, y = 15 },
				radius = 12,
			}
		end
	end)
	pulseTimer:start()
end

local function cleanupIndicators()
	if indicatorTimer then
		indicatorTimer:stop()
		indicatorTimer = nil
	end

	if pulseTimer then
		pulseTimer:stop()
		pulseTimer = nil
	end

	if recordingIndicator then
		recordingIndicator:delete()
		recordingIndicator = nil
	end

	if transcribingIndicator then
		transcribingIndicator:delete()
		transcribingIndicator = nil
	end
end

local function cleanupRecording()
	if recTask and recTask:isRunning() then
		recTask:terminate()
	end

	if stopTimer then
		stopTimer:stop()
		stopTimer = nil
	end

	cleanupIndicators()
	isRecording = false
	updateUI()
end

local function transcribeAudio(path)
	isBusy = true
	updateUI()
	createTranscribingIndicator()

	if telemetry then
		telemetry.transcriptionStartedAt = hs.timer.secondsSinceEpoch()
	else
		telemetry = { transcriptionStartedAt = hs.timer.secondsSinceEpoch() }
	end

	local url = "https://api.groq.com/openai/v1/audio/transcriptions"
	local curlArgs = {
		"-sS",
		"-m",
		tostring(CONFIG.API_TIMEOUT),
		"-H",
		"Authorization: Bearer " .. GROQ_API_KEY,
		"-F",
		"file=@" .. path .. ";type=audio/wav",
		"-F",
		"model=" .. CONFIG.MODEL,
		"-F",
		"response_format=" .. CONFIG.RESPONSE_FORMAT,
	}

	if CONFIG.LANGUAGE then
		table.insert(curlArgs, "-F")
		table.insert(curlArgs, "language=" .. CONFIG.LANGUAGE)
	end

	table.insert(curlArgs, "-w")
	table.insert(
		curlArgs,
		'__CURL_TIMING__{"time_total":"%{time_total}","time_upload":"%{time_upload}","time_starttransfer":"%{time_starttransfer}","time_download":"%{time_download}"}'
	)

	table.insert(curlArgs, url)

	local curl = hs.task.new("/usr/bin/curl", function(exitCode, out, err)
		isBusy = false
		cleanupIndicators()

		if path then
			os.remove(path)
			wavPath = nil
		end
		updateUI()

		local metrics = nil
		if out and out:find("__CURL_TIMING__") then
			local bodyPart, metricsPart = out:match("^(.*)__CURL_TIMING__(%b{})$")
			if bodyPart then
				out = bodyPart
				local okMetrics, parsed = pcall(hs.json.decode, metricsPart)
				if okMetrics and type(parsed) == "table" then
					metrics = parsed
					if telemetry then
						telemetry.curlMetrics = parsed
					end
				end
			end
		end

		out = (out or ""):gsub("%s+$", "")

		if exitCode ~= 0 then
			notify("API Error", err or "Network request failed", "Basso")
			playSound("error")
			telemetry = nil
			return
		end

		local ok, body = pcall(hs.json.decode, out or "")
		if not ok or not body then
			notify("API Error", "Invalid response from server", "Basso")
			playSound("error")
			telemetry = nil
			return
		end

		if body.error then
			notify("Transcription Error", body.error.message or "Unknown API error", "Basso")
			playSound("error")
			telemetry = nil
			return
		end

		local text = (body.text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" then
			notify("No Speech", "No text was detected in the audio", "Funk")
			telemetry = nil
			return
		end

		local now = hs.timer.secondsSinceEpoch()
		if telemetry then
			telemetry.transcriptionFinishedAt = now
			if not telemetry.curlMetrics and metrics then
				telemetry.curlMetrics = metrics
			end
		end

		hs.pasteboard.setContents(text)
		hs.eventtap.keyStroke({ "cmd" }, "v", 0)
		local preview = '"' .. (text:len() > 50 and text:sub(1, 50) .. "..." or text) .. '"'
		local summary = buildTelemetrySummary()
		if summary then
			print("[whisper] " .. summary)
		end
		notify("Groq", preview, "Glass")
		playSound("success")
		telemetry = nil
	end, curlArgs)

	curl:start()
end

stopRecordingAndTranscribe = function()
	if not isRecording then
		return
	end

	local now = hs.timer.secondsSinceEpoch()
	if telemetry then
		if telemetry.recordingStartedAt then
			telemetry.recordingDuration = now - telemetry.recordingStartedAt
		end
		telemetry.recordingStoppedAt = now
	end

	cleanupRecording()
	playSound("stop")

	local attrs = wavPath and hs.fs.attributes(wavPath)
	if not attrs or (attrs.size or 0) < CONFIG.MIN_BYTES then
		notify("Recording Too Short", "Please speak for a longer duration", "Funk")
		if wavPath then
			os.remove(wavPath)
		end
		telemetry = nil
		return
	end

	transcribeAudio(wavPath)
end

local function startRecording()
	if isBusy or isRecording then
		notify("Busy", isBusy and "Please wait for transcription to complete" or "Already recording", "Funk")
		return
	end

	if not REC or not GROQ_API_KEY or GROQ_API_KEY == "" then
		if not checkDependencies() then
			return
		end
	end

	telemetry = { recordingStartedAt = hs.timer.secondsSinceEpoch() }

	isRecording = true
	wavPath = tmpWavPath()

	recTask = hs.task.new(REC, function(exitCode, stdOut, stdErr)
		recTask = nil
		stopRecordingAndTranscribe()
	end, {
		"-q",
		"-c",
		"1",
		"-r",
		tostring(CONFIG.SAMPLE_RATE),
		wavPath,
	})

	if not recTask:start() then
		isRecording = false
		notify("Recording Failed", "Could not start audio recording", "Basso")
		playSound("error")
		return
	end

	updateUI()
	createRecordingIndicator()
	playSound("start")

	stopTimer = hs.timer.doAfter(CONFIG.MAX_HOLD_SECONDS, stopRecordingAndTranscribe)
end

local M = {}

function M.init(manager)
	if not checkDependencies() then
		return
	end

	menubarManager = manager
	menubarManager.registerModule("whisper", getMenuItems(), getIcon(), getTooltip())

	hs.hotkey.bind(CONFIG.HOTKEY_MODS, CONFIG.HOTKEY_KEY, startRecording, stopRecordingAndTranscribe)
	notify(
		"Whisper Ready",
		"Hold " .. table.concat(CONFIG.HOTKEY_MODS, "+") .. "+" .. CONFIG.HOTKEY_KEY .. " to start recording",
		"Glass"
	)
end

return M
