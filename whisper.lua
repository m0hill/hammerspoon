
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
    HOTKEY_MODS = {"option"},
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

local GROQ_API_KEY = os.getenv("GROQ_API_KEY")
local REC = nil
local menubar = nil
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


local function notify(title, text, sound)
    if not CONFIG.ENABLE_NOTIFY then return end
    local notification = hs.notify.new({
        title = title,
        informativeText = text or "",
        withdrawAfter = 3
    })
    if sound and CONFIG.ENABLE_SOUND then
        notification:soundName(sound)
    end
    notification:send()
end

local function playSound(type)
    if not CONFIG.ENABLE_SOUND then return end

    local sounds = {
        start = "Ping",
        stop = "Purr",
        error = "Basso",
        success = "Glass"
    }

    if sounds[type] then
        hs.sound.getByName(sounds[type]):play()
    end
end

local function which(cmd)
    local out = hs.execute("command -v " .. cmd)
    out = (out or ""):gsub("%s+$", "")
    if out ~= "" then return out end

    local fallbacks = {
        "/opt/homebrew/bin/" .. cmd,
        "/usr/local/bin/" .. cmd,
        "/usr/bin/" .. cmd,
    }

    for _, p in ipairs(fallbacks) do
        if hs.fs.attributes(p, "mode") then return p end
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
    if not langCode then return "Auto-detect" end
    for _, lang in ipairs(LANGUAGES) do
        if lang.value == langCode then
            return lang.text
        end
    end
    return langCode
end


local function changeLanguage()
    print("changeLanguage called")
    local chooser = hs.chooser.new(function(choice)
        if not choice then return end
        CONFIG.LANGUAGE = choice.value
        notify("Language Changed", "Set to: " .. choice.text, "Glass")
        updateUI()
    end)

    chooser:choices(LANGUAGES)
    chooser:searchSubText(true)
    chooser:placeholderText("Select language for transcription...")
    chooser:show()
end

local function changeModel()
    print("changeModel called")
    local models = {
        { text = "Whisper Large v3 ($0.111/hr)", value = "whisper-large-v3" },
        { text = "Whisper Large v3 Turbo ($0.04/hr)", value = "whisper-large-v3-turbo" },
    }

    local chooser = hs.chooser.new(function(choice)
        if not choice then return end
        CONFIG.MODEL = choice.value
        notify("Model Changed", "Set to: " .. choice.text, "Glass")
        updateUI()
    end)

    chooser:choices(models)
    chooser:placeholderText("Select Whisper model...")
    chooser:show()
end

local function toggleNotifications()
    print("toggleNotifications called")
    CONFIG.ENABLE_NOTIFY = not CONFIG.ENABLE_NOTIFY
    notify("Settings", "Notifications " .. (CONFIG.ENABLE_NOTIFY and "enabled" or "disabled"), "Glass")
    updateUI()
end

local function toggleSounds()
    print("toggleSounds called")
    CONFIG.ENABLE_SOUND = not CONFIG.ENABLE_SOUND
    local message = "Sounds " .. (CONFIG.ENABLE_SOUND and "enabled" or "disabled")
    if CONFIG.ENABLE_NOTIFY then
        hs.notify.new({ title = "Settings", informativeText = message }):send()
    end
    updateUI()
end

local function showSettings()
    print("showSettings called")

    local settingsChoices = {
        {
            text = "🌐 Language: " .. formatLanguageName(CONFIG.LANGUAGE),
            subText = "Change transcription language",
            action = "language"
        },
        {
            text = "🤖 Model: " .. CONFIG.MODEL,
            subText = "Change Whisper model",
            action = "model"
        },
        {
            text = "🔔 Notifications: " .. (CONFIG.ENABLE_NOTIFY and "ON" or "OFF"),
            subText = "Toggle notification popups",
            action = "notifications"
        },
        {
            text = "🔊 Sounds: " .. (CONFIG.ENABLE_SOUND and "ON" or "OFF"),
            subText = "Toggle audio feedback",
            action = "sounds"
        },
    }

    local chooser = hs.chooser.new(function(choice)
        if not choice then
            print("Settings chooser cancelled")
            return
        end

        print("Settings choice selected: " .. choice.action)

        if choice.action == "language" then
            changeLanguage()
        elseif choice.action == "model" then
            changeModel()
        elseif choice.action == "notifications" then
            toggleNotifications()
        elseif choice.action == "sounds" then
            toggleSounds()
        end
    end)

    chooser:choices(settingsChoices)
    chooser:searchSubText(true)
    chooser:placeholderText("Configure Whisper settings...")
    chooser:show()
end

local function showAbout()
    print("showAbout called")

    local aboutText = string.format([[Whisper Transcription v1.0

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
        REC and "✅ Installed" or "❌ Missing",
        (GROQ_API_KEY and GROQ_API_KEY ~= "") and "✅ Set" or "❌ Missing"
    )


    hs.dialog.blockAlert("About Whisper Transcription", aboutText, "OK")
end


function updateUI()
    if not menubar then return end

    if isRecording then
        menubar:setTitle("🎙️")
        menubar:setTooltip("Recording audio... (Hold to continue)")
        menubar:setMenu({
            { title = "🔴 Recording...", disabled = true },
            { title = "-" },
            { title = "Stop Recording", fn = stopRecordingAndTranscribe },
            { title = "-" },
            { title = "Quit", fn = function() os.exit() end },
        })
    elseif isBusy then
        menubar:setTitle("⏳")
        menubar:setTooltip("Transcribing audio...")
        menubar:setMenu({
            { title = "🔄 Transcribing...", disabled = true },
            { title = "-" },
            { title = "Quit", fn = function() os.exit() end },
        })
    else
        menubar:setTitle("🎤")
        menubar:setTooltip("Whisper Transcription Ready\nHold " ..
                         table.concat(CONFIG.HOTKEY_MODS, "+") .. "+" .. CONFIG.HOTKEY_KEY .. " to record")
        menubar:setMenu({
            { title = "✅ Ready to Record", disabled = true },
            { title = "-" },
            {
                title = "Settings",
                fn = function()
                    print("Settings menu clicked")
                    showSettings()
                end
            },
            {
                title = "About",
                fn = function()
                    print("About menu clicked")
                    showAbout()
                end
            },
            { title = "-" },
            { title = "Quit", fn = function() os.exit() end },
        })
    end
end

local function createRecordingIndicator()
    local mousePos = hs.mouse.absolutePosition()
    recordingIndicator = hs.canvas.new({
        x = mousePos.x - 15,
        y = mousePos.y - 35,
        w = 30,
        h = 30
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
        h = 30
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

    local url = "https://api.groq.com/openai/v1/audio/transcriptions"
    local curlArgs = {
        "-sS", "-m", tostring(CONFIG.API_TIMEOUT),
        "-H", "Authorization: Bearer " .. GROQ_API_KEY,
        "-F", "file=@" .. path .. ";type=audio/wav",
        "-F", "model=" .. CONFIG.MODEL,
        "-F", "response_format=" .. CONFIG.RESPONSE_FORMAT,
    }

    if CONFIG.LANGUAGE then
        table.insert(curlArgs, "-F")
        table.insert(curlArgs, "language=" .. CONFIG.LANGUAGE)
    end

    table.insert(curlArgs, url)

    local curl = hs.task.new("/usr/bin/curl", function(exitCode, out, err)
        isBusy = false
        cleanupIndicators()

        if path then
            os.remove(path)
            wavPath = nil
        end
        updateUI()

        if exitCode ~= 0 then
            notify("API Error", err or "Network request failed", "Basso")
            playSound("error")
            return
        end

        local ok, body = pcall(hs.json.decode, out or "")
        if not ok or not body then
            notify("API Error", "Invalid response from server", "Basso")
            playSound("error")
            return
        end

        if body.error then
            notify("Transcription Error", body.error.message or "Unknown API error", "Basso")
            playSound("error")
            return
        end

        local text = (body.text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then
            notify("No Speech", "No text was detected in the audio", "Funk")
            return
        end

        hs.pasteboard.setContents(text)
        hs.eventtap.keyStroke({ "cmd" }, "v", 0)
        notify("Success", "\"" .. (text:len() > 50 and text:sub(1, 50) .. "..." or text) .. "\"", "Glass")
        playSound("success")
    end, curlArgs)

    curl:start()
end


function stopRecordingAndTranscribe()
    if not isRecording then return end

    cleanupRecording()
    playSound("stop")

    local attrs = wavPath and hs.fs.attributes(wavPath)
    if not attrs or (attrs.size or 0) < CONFIG.MIN_BYTES then
        notify("Recording Too Short", "Please speak for a longer duration", "Funk")
        if wavPath then os.remove(wavPath) end
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
        if not checkDependencies() then return end
    end

    isRecording = true
    wavPath = tmpWavPath()

    recTask = hs.task.new(REC, function(exitCode, stdOut, stdErr)
        recTask = nil
        stopRecordingAndTranscribe()
    end, {
        "-q", "-c", "1", "-r", tostring(CONFIG.SAMPLE_RATE), wavPath,
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


local function init()
    if not checkDependencies() then return end

    menubar = hs.menubar.new()
    hs.hotkey.bind(CONFIG.HOTKEY_MODS, CONFIG.HOTKEY_KEY, startRecording, stopRecordingAndTranscribe)
    updateUI()
    notify("Whisper Ready", "Hold " .. table.concat(CONFIG.HOTKEY_MODS, "+") .. "+" .. CONFIG.HOTKEY_KEY .. " to start recording", "Glass")
end

init()