--!strict
-- Harvestable snow that grows back. The town is split into square tiles; each tile
-- holds 0..TILE_MAX_UNITS units of snow and is drawn as one Snow-material part whose
-- height follows the amount of snow on it.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local SnowService = {}

local SIZE = Config.WORLD_SIZE
local TILE = Config.TILE
local N = math.floor(SIZE / TILE)
local MAX = Config.TILE_MAX_UNITS
local UH = Config.UNIT_HEIGHT
local REGROW_RATE = MAX / Config.REGROW_SECONDS

local units: { number } = table.create(N * N, MAX)
local blocked: { boolean } = table.create(N * N, false)
local cooldown: { number } = table.create(N * N, 0)
local frozen: { boolean } = table.create(N * N, false) -- events can stop tiles regrowing
local parts: { [number]: BasePart } = {}
local dirty: { [number]: boolean } = {}
local folder: Folder

local function idx(i: number, j: number): number
	return j * N + i + 1
end
local function tileOf(x: number, z: number): (number, number)
	return math.floor((x + SIZE / 2) / TILE), math.floor((z + SIZE / 2) / TILE)
end
local function centre(i: number, j: number): (number, number)
	return -SIZE / 2 + (i + 0.5) * TILE, -SIZE / 2 + (j + 0.5) * TILE
end

local snowColors = {
	Color3.fromRGB(244, 248, 255),
	Color3.fromRGB(238, 244, 253),
	Color3.fromRGB(248, 250, 255),
}

local function draw(k: number)
	local p = parts[k]
	if not p then
		return
	end
	local u = units[k]
	local h = u * UH
	if u < 0.15 then
		p.Transparency = 1
		h = 0.05
	else
		p.Transparency = 0
	end
	local j = (k - 1) // N
	local i = (k - 1) % N
	local x, z = centre(i, j)
	p.Size = Vector3.new(TILE, h + 0.2, TILE)
	p.CFrame = CFrame.new(x, h / 2 + 0.1, z)
end

-- rects: list of { x0, z0, x1, z1 } in studs where snow never grows
function SnowService.Init(rects: { { number } })
	for _, r in rects do
		local i0, j0 = tileOf(math.min(r[1], r[3]), math.min(r[2], r[4]))
		local i1, j1 = tileOf(math.max(r[1], r[3]) - 0.01, math.max(r[2], r[4]) - 0.01)
		for j = math.max(0, j0), math.min(N - 1, j1) do
			for i = math.max(0, i0), math.min(N - 1, i1) do
				local k = idx(i, j)
				blocked[k] = true
				units[k] = 0
			end
		end
	end
	folder = Instance.new("Folder")
	folder.Name = "Snow"
	local rng = Random.new(42)
	for j = 0, N - 1 do
		for i = 0, N - 1 do
			local k = idx(i, j)
			if not blocked[k] then
				local p = Instance.new("Part")
				p.Name = "SnowTile"
				p.Anchored = true
				p.CanCollide = false
				p.CanTouch = false
				p.CanQuery = false
				p.CastShadow = false
				p.Material = Enum.Material.Snow
				p.Color = snowColors[rng:NextInteger(1, #snowColors)]
				p.TopSurface = Enum.SurfaceType.Smooth
				p.BottomSurface = Enum.SurfaceType.Smooth
				parts[k] = p
				draw(k)
				p.Parent = folder
			end
		end
	end
	folder.Parent = workspace

	-- regrowth
	task.spawn(function()
		local step = 1
		while true do
			task.wait(step)
			for k = 1, N * N do
				if not blocked[k] and not frozen[k] and units[k] < MAX then
					if cooldown[k] > 0 then
						cooldown[k] -= step
					else
						units[k] = math.min(MAX, units[k] + REGROW_RATE * step * (0.6 + math.random() * 0.8))
						dirty[k] = true
					end
				end
			end
		end
	end)
	-- redraw changed tiles a few times per second
	task.spawn(function()
		while true do
			task.wait(0.1)
			for k in dirty do
				draw(k)
			end
			table.clear(dirty)
		end
	end)
end

-- Remove up to `amount` units from the tiles inside a circle. Returns units removed.
function SnowService.Harvest(x: number, z: number, radius: number, amount: number): number
	if amount <= 0 then
		return 0
	end
	local r = math.max(radius, TILE * 0.5)
	local i0, j0 = tileOf(x - r, z - r)
	local i1, j1 = tileOf(x + r, z + r)
	local list = {}
	local avail = 0
	local reach = (r + TILE * 0.5) ^ 2
	for j = math.max(0, j0), math.min(N - 1, j1) do
		for i = math.max(0, i0), math.min(N - 1, i1) do
			local k = idx(i, j)
			if not blocked[k] and units[k] > 0.001 then
				local cx, cz = centre(i, j)
				if (cx - x) ^ 2 + (cz - z) ^ 2 <= reach then
					table.insert(list, k)
					avail += units[k]
				end
			end
		end
	end
	if avail <= 0 then
		return 0
	end
	local take = math.min(amount, avail)
	local f = take / avail
	for _, k in list do
		units[k] -= units[k] * f
		if units[k] < 0.05 then
			units[k] = 0
		end
		cooldown[k] = Config.REGROW_DELAY[1] + math.random() * (Config.REGROW_DELAY[2] - Config.REGROW_DELAY[1])
		dirty[k] = true
	end
	return take
end

-- ---------------------------------------------------------------- helpers for events
-- tile ids inside a rectangle { x0, z0, x1, z1 } (studs), skipping tiles without snow
function SnowService.TilesInRect(r: { number }): { number }
	local list = {}
	local i0, j0 = tileOf(math.min(r[1], r[3]), math.min(r[2], r[4]))
	local i1, j1 = tileOf(math.max(r[1], r[3]) - 0.01, math.max(r[2], r[4]) - 0.01)
	for j = math.max(0, j0), math.min(N - 1, j1) do
		for i = math.max(0, i0), math.min(N - 1, i1) do
			local k = idx(i, j)
			if not blocked[k] then
				table.insert(list, k)
			end
		end
	end
	return list
end

-- stop (or restart) regrowth on these tiles
function SnowService.SetFrozen(list: { number }, on: boolean)
	for _, k in list do
		frozen[k] = on
		if not on then
			cooldown[k] = 0
		end
	end
end

-- set these tiles to an exact amount of snow (0..TILE_MAX_UNITS)
function SnowService.Fill(list: { number }, amount: number)
	for _, k in list do
		units[k] = math.clamp(amount, 0, MAX)
		dirty[k] = true
	end
end

-- total snow on these tiles
function SnowService.Amount(list: { number }): number
	local t = 0
	for _, k in list do
		t += units[k]
	end
	return t
end

function SnowService.DepthAt(x: number, z: number): number
	local i, j = tileOf(x, z)
	if i < 0 or j < 0 or i >= N or j >= N then
		return 0
	end
	return units[idx(i, j)] * UH
end

return SnowService
