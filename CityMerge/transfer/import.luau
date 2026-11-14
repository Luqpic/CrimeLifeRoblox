-- Run in the TARGET window (Crimelife city.rbxl) via execute_luau (Edit). Paste the whole file; edit only the CALL SITE.
-- import(key, parent, newName?) -> Instance: fetches the key, deserializes, stamps ImportedFrom, parents.
-- Errors if parent already has a child with the final name. parent == nil returns the UNPARENTED copy (dry run).
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

local function import(key: string, parent: Instance?, newName: string?): Instance
	local res = HttpService:RequestAsync({Url = "http://127.0.0.1:8765/" .. key, Method = "GET"})
	if not res.Success then error("GET failed for " .. key .. ": " .. tostring(res.StatusCode)) end
	local arr = SerializationService:DeserializeInstancesAsync(EncodingService:Base64Decode(buffer.fromstring(res.Body)))
	local root = arr[1]
	if newName then root.Name = newName end
	if parent and parent:FindFirstChild(root.Name) then
		root:Destroy()
		error(parent:GetFullName() .. " already has a child named " .. root.Name)
	end
	root:SetAttribute("ImportedFrom", "FPS System")
	if parent then root.Parent = parent end
	return root
end

-- ===== CALL SITE (edit) =====
-- Dry-run round trip check (not parented, destroyed after):
local copy = import("test__1__Persistence.b64", nil)
local schema = copy:FindFirstChild("Schema", true)
local n, h = #copy:GetDescendants(), adler32(schema.Source)
copy:Destroy()
return string.format("descendants=%d adler(Schema.Source)=%d", n, h)
