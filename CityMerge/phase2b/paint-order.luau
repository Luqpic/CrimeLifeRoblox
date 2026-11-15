--!strict
-- Paint order of a ScreenGui under ZIndexBehavior Global vs Sibling (phase 2b Task 4).
-- Run in Studio through execute_luau: wrap the file as `local M = (function() <file> end)()`.
-- paintOrder(root, mode): GuiObject descendants as paths with sibling indexes, e.g. `Shop[1]/Grid[2]/Card[7]`
-- (index = position in the parent's GetChildren(); the first segment is a direct child of root).
-- Last in the list paints on top.
--   Global : every GuiObject descendant, stable-sorted by ZIndex, ties in depth-first pre-order of GetChildren().
--   Sibling: depth-first, parent before its children, each parent's children stable-sorted by ZIndex.
-- A non-GuiObject child (Folder, ...) is looked through: its GuiObject children count as the parent's.
-- swappedPairs(root): pairs whose relative order differs between the modes, with whether their rectangles overlap.

local M = {}

type Item = { obj: GuiObject, path: string }

-- GuiObject children of `parent` in GetChildren() order, looking through non-GuiObjects
local function guiChildren(parent: Instance, prefix: string, out: { Item })
	for i, child in ipairs(parent:GetChildren()) do
		local path = prefix .. child.Name .. "[" .. i .. "]"
		if child:IsA("GuiObject") then
			table.insert(out, { obj = child, path = path })
		else
			guiChildren(child, path .. "/", out)
		end
	end
end

-- stable sort by ZIndex (table.sort is not stable: sort on (ZIndex, original position))
local function stableByZ(items: { Item }): { Item }
	local keyed = {}
	for pos, it in ipairs(items) do
		table.insert(keyed, { it = it, z = it.obj.ZIndex, pos = pos })
	end
	table.sort(keyed, function(a, b)
		if a.z ~= b.z then return a.z < b.z end
		return a.pos < b.pos
	end)
	local out = {}
	for _, k in ipairs(keyed) do
		table.insert(out, k.it)
	end
	return out
end

local function walk(parent: Instance, prefix: string, out: { Item })
	local kids: { Item } = {}
	guiChildren(parent, prefix, kids)
	for _, it in ipairs(kids) do
		table.insert(out, it)
		walk(it.obj, it.path .. "/", out)
	end
end

local function items(root: Instance, mode: string): { Item }
	if mode == "Global" then
		local preorder: { Item } = {}
		walk(root, "", preorder)
		return stableByZ(preorder)
	end
	local out: { Item } = {}
	local function sib(parent: Instance, prefix: string)
		local kids: { Item } = {}
		guiChildren(parent, prefix, kids)
		for _, it in ipairs(stableByZ(kids)) do
			table.insert(out, it)
			sib(it.obj, it.path .. "/")
		end
	end
	sib(root, "")
	return out
end

function M.paintOrder(root: Instance, mode: "Global" | "Sibling"): { string }
	local list = {}
	for _, it in ipairs(items(root, mode)) do
		table.insert(list, it.path)
	end
	return list
end

function M.equal(a: { string }, b: { string }): boolean
	if #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

-- pairs (earlier-painted first under Global) whose order is reversed under Sibling
function M.swappedPairs(root: Instance): { { a: string, b: string, za: number, zb: number, overlap: boolean, bothVisible: boolean } }
	local g, s = items(root, "Global"), items(root, "Sibling")
	local sibPos: { [GuiObject]: number } = {}
	for i, it in ipairs(s) do sibPos[it.obj] = i end
	local res = {}
	for i = 1, #g do
		for j = i + 1, #g do
			local a, b = g[i], g[j]
			if (sibPos[a.obj] :: number) > (sibPos[b.obj] :: number) then
				local pa, sa, pb, sb = a.obj.AbsolutePosition, a.obj.AbsoluteSize, b.obj.AbsolutePosition, b.obj.AbsoluteSize
				local overlap = pa.X < pb.X + sb.X and pb.X < pa.X + sa.X and pa.Y < pb.Y + sb.Y and pb.Y < pa.Y + sa.Y
				table.insert(res, { a = a.path, b = b.path, za = a.obj.ZIndex, zb = b.obj.ZIndex, overlap = overlap, bothVisible = a.obj.Visible and b.obj.Visible })
			end
		end
	end
	return res
end

-- Self-check: run in Edit on Frames under a ScreenGui that is never parented. Returns "PASS ..." or errors.
function M.selfCheck(): string
	local function frame(parent: Instance, name: string, z: number): Frame
		local f = Instance.new("Frame")
		f.Name, f.ZIndex, f.Parent = name, z, parent
		return f
	end
	-- (a) everything ZIndex 1: same list in both modes
	local ga = Instance.new("ScreenGui")
	local shop = frame(ga, "Shop", 1)
	local grid = frame(shop, "Grid", 1)
	frame(grid, "Card", 1); frame(grid, "Card", 1)
	frame(shop, "Title", 1)
	local gl, sl = M.paintOrder(ga, "Global"), M.paintOrder(ga, "Sibling")
	assert(M.equal(gl, sl), "(a) all ZIndex 1 differs: " .. table.concat(gl, ",") .. " | " .. table.concat(sl, ","))
	assert(#gl == 5, "(a) expected 5 entries, got " .. #gl)
	ga:Destroy()
	-- (b) notification case: card Z4 with label Z1, beside a card Z3
	local gb = Instance.new("ScreenGui")
	local cont = frame(gb, "Container", 1)
	local card4 = frame(cont, "Card4", 4)
	frame(card4, "Label", 1)
	frame(cont, "Card3", 3)
	local g2, s2 = M.paintOrder(gb, "Global"), M.paintOrder(gb, "Sibling")
	assert(not M.equal(g2, s2), "(b) lists are equal")
	local function at(list: { string }, p: string): number
		for i, v in ipairs(list) do if v == p then return i end end
		error("missing " .. p)
	end
	assert(at(g2, "Container[1]/Card4[1]/Label[1]") < at(g2, "Container[1]/Card4[1]"), "(b) Global: label must come before its own card")
	assert(at(s2, "Container[1]/Card4[1]") < at(s2, "Container[1]/Card4[1]/Label[1]"), "(b) Sibling: label must come after its own card")
	gb:Destroy()
	return "PASS (a) equal at ZIndex 1, 5 entries; (b) differ, Global label-before-card | Global=" .. table.concat(g2, ",") .. " | Sibling=" .. table.concat(s2, ",")
end

return M
