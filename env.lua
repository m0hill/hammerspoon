local M = {}

local envCache = {}
local isLoaded = false

function M.load()
	if isLoaded then
		return envCache
	end

	local configDir = hs.configdir
	local envPath = configDir .. "/.env"

	local file = io.open(envPath, "r")
	if not file then
		print("Warning: .env file not found at " .. envPath)
		isLoaded = true
		return envCache
	end

	for line in file:lines() do
		line = line:match("^%s*(.-)%s*$")

		if line ~= "" and not line:match("^#") then
			local key, value = line:match("^([^=]+)=(.*)$")
			if key and value then
				key = key:match("^%s*(.-)%s*$")
				value = value:match("^%s*(.-)%s*$")
				value = value:gsub("^['\"](.-)['\"]+$", "%1")
				envCache[key] = value
			end
		end
	end

	file:close()
	isLoaded = true

	return envCache
end

function M.get(key, default)
	if not isLoaded then
		M.load()
	end

	if envCache[key] then
		return envCache[key]
	end

	local sysValue = os.getenv(key)
	if sysValue then
		return sysValue
	end

	return default
end

function M.reload()
	isLoaded = false
	envCache = {}
	return M.load()
end

return M
