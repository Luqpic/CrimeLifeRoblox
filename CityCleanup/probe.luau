-- City baseline probe. Run in Edit via execute_luau. Read-only; yields every 20,000 descendants.
local ws = workspace
local function isScript(i) return i:IsA("LuaSourceContainer") end
local c = {parts=0, mesh=0, union=0, unanch=0, scripts=0, enabled=0, lights=0, emit=0, decal=0}
local n, budget = 0, 0
local desc = ws:GetDescendants()
for _, i in ipairs(desc) do
	n += 1; budget += 1
	if i:IsA("BasePart") then
		c.parts += 1
		if i:IsA("MeshPart") then c.mesh += 1 elseif i:IsA("UnionOperation") then c.union += 1 end
		if not i.Anchored then c.unanch += 1 end
	elseif isScript(i) then
		c.scripts += 1
		if i:IsA("BaseScript") then if not i.Disabled then c.enabled += 1 end else c.enabled += 1 end
	elseif i:IsA("Light") then c.lights += 1
	elseif i:IsA("ParticleEmitter") then c.emit += 1
	elseif i:IsA("Decal") or i:IsA("Texture") then c.decal += 1 end
	if budget >= 20000 then budget = 0; task.wait() end
end
desc = nil
local sizes = {}
local function measure(inst, label)
	local k = #inst:GetDescendants() + 1
	table.insert(sizes, {label, k})
	budget += k
	if budget >= 20000 then budget = 0; task.wait() end
end
local top = ws:GetChildren()
for _, ch in ipairs(top) do
	if not ch:IsA("Terrain") and not ch:IsA("Camera") then
		measure(ch, ch.Name)
		for _, g in ipairs(ch:GetChildren()) do measure(g, ch.Name .. "/" .. g.Name) end
	end
end
table.sort(sizes, function(a, b) return a[2] > b[2] end)
local out = {
	"workspace_instances=" .. n,
	("baseparts=%d  meshparts=%d  unions=%d"):format(c.parts, c.mesh, c.union),
	"unanchored_parts=" .. c.unanch,
	("scripts_total=%d  scripts_enabled=%d"):format(c.scripts, c.enabled),
	("lights=%d  particle_emitters=%d  decals_textures=%d"):format(c.lights, c.emit, c.decal),
	"top_level_children=" .. #top,
	"streaming_enabled=" .. tostring(ws.StreamingEnabled),
	"top20_models:",
}
for i = 1, math.min(20, #sizes) do table.insert(out, ("  %s %d"):format(sizes[i][1], sizes[i][2])) end
local ss = 0
for _ in ipairs(game:GetService("ServerStorage"):GetDescendants()) do ss += 1 end
table.insert(out, "serverstorage_instances=" .. ss)
local okm, mem = pcall(function() return game.Stats.PerformanceStats.Memory:GetValueString() end)
table.insert(out, "studio_memory=" .. (okm and mem or "not recorded"))
return table.concat(out, "\n")
