-- Run in the CITY window (Crimelife city.rbxl) via execute_luau (Edit). Paste the whole file; edit only the CALL SITE.
-- exportSources(paths) -> one line per script: index | full name | bytes | adler32
-- Each Source is POSTed to http://127.0.0.1:8765/src.<n> (n = list index, text/plain).
-- On disk: curl -s http://127.0.0.1:8765/src.<n> > "CityScripts/<FullName>.luau"
local HttpService = game:GetService("HttpService")

-- same function as CityMerge/transfer/export.luau
local function adler32(s: string): number
	local a, b = 1, 0
	for i = 1, #s do
		a = (a + string.byte(s, i)) % 65521
		b = (b + a) % 65521
	end
	return b * 65536 + a
end

-- path "ServerScriptService.Blaster.Scripts.Blaster": first segment is a service, the rest are child names
local function resolve(path: string): Instance
	local segs = string.split(path, ".")
	local inst: Instance = game:GetService(segs[1])
	for i = 2, #segs do
		inst = inst:FindFirstChild(segs[i]) or error("not found: " .. path .. " at " .. segs[i])
	end
	return inst
end

local function exportSources(paths: {string}): {string}
	local lines = {}
	for i, path in ipairs(paths) do
		local s = resolve(path)
		local src = (s :: any).Source
		local res = HttpService:RequestAsync({
			Url = "http://127.0.0.1:8765/src." .. i, Method = "POST", Body = src,
			Headers = {["Content-Type"] = "text/plain"},
		})
		if not res.Success then error("POST failed for " .. path .. ": " .. tostring(res.StatusCode)) end
		table.insert(lines, string.format("%d | %s | %d | %d", i, s:GetFullName(), #src, adler32(src)))
	end
	return lines
end

-- ===== CALL SITE (edit) =====
local paths = { "ServerScriptService.Blaster.Scripts.Blaster" }
return table.concat(exportSources(paths), "\n")
