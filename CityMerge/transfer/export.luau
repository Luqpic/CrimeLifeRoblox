-- Run in the SOURCE window (FPS System.rbxl) via execute_luau (Edit). Paste the whole file; edit only the CALL SITE.
-- export(roots, prefix, startIndex?) -> {string}: one line per root: name | class | descendants | scripts | bytes | key
-- Store key: <prefix>__<index>__<sanitised name>.b64  (sanitised to [A-Za-z0-9_.-], max 80 chars)
local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")
local EncodingService = game:GetService("EncodingService")

local function adler32(s: string): number
	local a, b = 1, 0
	for i = 1, #s do
		a = (a + string.byte(s, i)) % 65521
		b = (b + a) % 65521
	end
	return b * 65536 + a
end

local function export(roots: {Instance}, prefix: string, startIndex: number?): {string}
	local lines = {}
	for i, inst in ipairs(roots) do
		local clean = inst.Name:gsub("[^%w_%.%-]", "_")
		local key = string.sub(string.format("%s__%d__%s", prefix, (startIndex or 1) + i - 1, clean), 1, 76) .. ".b64"
		local desc = inst:GetDescendants()
		local scripts = inst:IsA("LuaSourceContainer") and 1 or 0 -- includes the root itself
		for _, d in ipairs(desc) do
			if d:IsA("LuaSourceContainer") then scripts += 1 end
		end
		local b64 = buffer.tostring(EncodingService:Base64Encode(SerializationService:SerializeInstancesAsync({inst})))
		local res = HttpService:RequestAsync({
			Url = "http://127.0.0.1:8765/" .. key, Method = "POST", Body = b64,
			Headers = {["Content-Type"] = "text/plain"},
		})
		if not res.Success then error("POST failed for " .. key .. ": " .. tostring(res.StatusCode)) end
		table.insert(lines, string.format("%s | %s | %d | %d | %d | %s", inst.Name, inst.ClassName, #desc, scripts, #b64, key))
		task.wait()
	end
	return lines
end

-- ===== CALL SITE (edit) =====
local roots = { game:GetService("ReplicatedStorage").Persistence }
return table.concat(export(roots, "test"), "\n")
