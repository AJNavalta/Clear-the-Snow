--!nonstrict
-- Builds the neighbourhood (ground, roads, houses, trees, lamps, fence) and the
-- market hub (snow pile, Snow Buyer, Tool Shop, tool display, spin wheel, daily gift).
-- Returns rectangles where snow must not grow and handles to the interactive bits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Models = require(Shared.Models)

local S = Config.STUDS_PER_METER
local HALF = Config.WORLD_SIZE / 2
local FACE_PLAZA = CFrame.Angles(0, math.pi, 0) -- models face -Z; this turns them to +Z

local World = {}

local function part(parent: Instance, size: Vector3, cf: CFrame, color: string, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromHex(color)
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, val in props do
			(p :: any)[k] = val
		end
	end
	p.Parent = parent
	return p
end

local function rectOverlap(a, b, margin: number): boolean
	return a[3] > b[1] - margin and a[1] < b[3] + margin and a[4] > b[2] - margin and a[2] < b[4] + margin
end

-- [x0, z0, x1, z1] in studs
World.Roads = {
	{ -HALF, 13 * S, HALF, 20 * S },
	{ -HALF, -36 * S, HALF, -29 * S },
	{ -36 * S, -HALF, -29 * S, HALF },
	{ 29 * S, -HALF, 36 * S, HALF },
}
World.Plaza = { -14 * S, -11 * S, 14 * S, 6 * S }

function World.SetupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(120, 130, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 185, 210)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.32
	atmo.Offset = 0.1
	atmo.Color = Color3.fromRGB(205, 220, 240)
	atmo.Decay = Color3.fromRGB(150, 175, 210)
	atmo.Glare = 0
	atmo.Haze = 1.6
	atmo.Parent = Lighting
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.08
	cc.TintColor = Color3.fromRGB(245, 250, 255)
	cc.Parent = Lighting
end

function World.Build()
	World.SetupLighting()
	local root = Instance.new("Folder")
	root.Name = "Town"
	root.Parent = workspace
	local blocks = {} -- areas without snow

	-- remove the default baseplate if there is one
	local bp = workspace:FindFirstChild("Baseplate")
	if bp then
		bp:Destroy()
	end

	-- ground, outer snowfield, roads and plaza
	part(root, Vector3.new(Config.WORLD_SIZE, 2, Config.WORLD_SIZE), CFrame.new(0, -1, 0), "#6b7d55", Enum.Material.Grass, { Name = "Ground" })
	part(root, Vector3.new(2000, 2, 2000), CFrame.new(0, -1.05, 0), "#e9f0fa", Enum.Material.Snow, { Name = "OuterSnow" })
	for i, r in World.Roads do
		local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
		part(root, Vector3.new(r[3] - r[1], 0.2, r[4] - r[2]), CFrame.new(cx, 0.0, cz), "#4a4d52", Enum.Material.Asphalt, { Name = "Road" .. i })
	end
	local P = World.Plaza
	part(root, Vector3.new(P[3] - P[1], 0.3, P[4] - P[2]), CFrame.new((P[1] + P[3]) / 2, 0.05, (P[2] + P[4]) / 2), "#9c8f80", Enum.Material.Cobblestone, { Name = "Plaza" })
	table.insert(blocks, P)

	-- houses
	local rng = Random.new(1337)
	local houseColors = { "#c0504d", "#4f81bd", "#9bbb59", "#f2c14e", "#8064a2", "#e98b5a", "#5fb3b3", "#d7d2c8", "#a9746e" }
	local houses = {}
	local houseFolder = Instance.new("Folder")
	houseFolder.Name = "Houses"
	houseFolder.Parent = root
	local colliders = {}
	local function tryHouse(cxM: number, czM: number, facing: number)
		local wM, dM = 7 + rng:NextNumber() * 2, 6 + rng:NextNumber() * 1.5
		local side = math.abs(math.sin(facing)) > 0.5
		local fw, fd = (if side then dM else wM) * S, (if side then wM else dM) * S
		local cx, cz = cxM * S, czM * S
		local rect = { cx - fw / 2, cz - fd / 2, cx + fw / 2, cz + fd / 2 }
		if math.abs(cx) > HALF - 18 or math.abs(cz) > HALF - 18 then
			return
		end
		for _, r in World.Roads do
			if rectOverlap(rect, r, 3) then
				return
			end
		end
		if rectOverlap(rect, P, 18) then
			return
		end
		for _, h in houses do
			if rectOverlap(rect, h, 9) then
				return
			end
		end
		table.insert(houses, rect)
		table.insert(blocks, rect)
		local house = Models.BuildHouse(wM, dM, houseColors[rng:NextInteger(1, #houseColors)], rng:NextNumber() > 0.4)
		-- built facing -Z; `facing` is the direction the front door should point (radians about Y from +Z)
		house:PivotTo(CFrame.new(cx, 0, cz) * CFrame.Angles(0, facing + math.pi, 0))
		for _, d in house:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = d.Name ~= "Root"
				d.CanQuery = true
			end
		end
		house.Parent = houseFolder
	end
	for x = -54, 54, 11 do
		tryHouse(x, 26, math.pi)
		tryHouse(x, 6, 0)
		tryHouse(x, -42, 0)
		tryHouse(x, -22, math.pi)
		tryHouse(x, 46, math.pi)
	end
	for z = -54, 54, 11 do
		tryHouse(-46, z, math.pi / 2)
		tryHouse(-19, z, -math.pi / 2)
		tryHouse(46, z, -math.pi / 2)
		tryHouse(19, z, math.pi / 2)
	end

	-- pine trees
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = root
	local spots = {}
	for _ = 1, 160 do
		if #spots >= 70 then
			break
		end
		local x = (rng:NextNumber() - 0.5) * (Config.WORLD_SIZE - 20)
		local z = (rng:NextNumber() - 0.5) * (Config.WORLD_SIZE - 20)
		local rect = { x - 3, z - 3, x + 3, z + 3 }
		local ok = not rectOverlap(rect, P, 12)
		for _, r in World.Roads do
			ok = ok and not rectOverlap(rect, r, 1)
		end
		for _, h in houses do
			ok = ok and not rectOverlap(rect, h, 4)
		end
		for _, s in spots do
			ok = ok and (s[1] - x) ^ 2 + (s[2] - z) ^ 2 > 15 * 15
		end
		if ok then
			table.insert(spots, { x, z })
			local t = Models.BuildPine(0.8 + rng:NextNumber() * 0.7)
			t:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber() * 6, 0))
			local trunk = part(t, Vector3.new(2, 8, 2), CFrame.new(x, 4, z), "#000000", nil, { Transparency = 1, CanCollide = true, Name = "Collider" })
			trunk.CanQuery = false
			t.Parent = trees
		end
	end

	-- street lamps
	for xM = -50, 50, 16 do
		for _, zM in { 12, 21, -28, -37 } do
			local lamp = Models.BuildLamp()
			lamp:PivotTo(CFrame.new(xM * S, 0, zM * S))
			part(lamp, Vector3.new(1, 12, 1), CFrame.new(xM * S, 6, zM * S), "#000000", nil, { Transparency = 1, CanCollide = true, Name = "Collider" })
			lamp.Parent = root
		end
	end

	-- perimeter fence (also stops players wandering off)
	for _, sgn in { -1, 1 } do
		for _, horiz in { true, false } do
			for t = -HALF, HALF, 9 do
				local x, z = if horiz then t else sgn * HALF, if horiz then sgn * HALF else t
				local post = part(root, Vector3.new(1.2, 0.5, 0.5), CFrame.new(x, 1.9, z) * CFrame.Angles(0, 0, math.pi / 2), "#7b5a3a", Enum.Material.Wood)
				post.Shape = Enum.PartType.Cylinder
				post.Size = Vector3.new(3.9, 0.5, 0.5)
			end
			for _, y in { 1.35, 2.85 } do
				local size = if horiz then Vector3.new(Config.WORLD_SIZE, 0.3, 0.2) else Vector3.new(0.2, 0.3, Config.WORLD_SIZE)
				part(root, size, CFrame.new(if horiz then 0 else sgn * HALF, y, if horiz then sgn * HALF else 0), "#7b5a3a", Enum.Material.Wood)
			end
			-- invisible wall
			local wall = if horiz then Vector3.new(Config.WORLD_SIZE, 30, 1) else Vector3.new(1, 30, Config.WORLD_SIZE)
			part(root, wall, CFrame.new(if horiz then 0 else sgn * HALF, 15, if horiz then sgn * HALF else 0), "#000000", nil, { Transparency = 1, Name = "Boundary" })
		end
	end

	-- distant forest ring
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		for k = 0, 2 do
			local r = HALF + 25 + k * 20 + rng:NextNumber() * 10
			local b = a + (rng:NextNumber() - 0.5) * 0.2
			local t = Models.BuildPine(2 + rng:NextNumber() * 1.5)
			t:PivotTo(CFrame.new(math.cos(b) * r, 0, math.sin(b) * r))
			t.Parent = trees
		end
	end

	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(Config.Hub.Spawn + Vector3.new(0, 0.3, 0))
	spawn.Material = Enum.Material.Cobblestone
	spawn.Color = Color3.fromHex("#9c8f80")
	spawn.Transparency = 0
	spawn.Duration = 0
	spawn.Parent = root

	local hub = World.BuildHub(root)
	return blocks, hub
end

-- ------------------------------------------------------------------ market hub
local function prompt(parent: Instance, action: string, object: string, dist: number?, key: Enum.KeyCode?): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = 0
	pp.MaxActivationDistance = dist or 12
	pp.KeyboardKeyCode = key or Enum.KeyCode.E
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

local function billboard(parent: Instance, title: string, subtitle: string, height: number, w: number?): (TextLabel, TextLabel)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(w or 180, 54)
	bb.StudsOffset = Vector3.new(0, height, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Parent = parent
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(15, 30, 55)
	bg.BackgroundTransparency = 0.18
	bg.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = bg
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.Size = UDim2.new(1, -8, 0.55, 0)
	t.Position = UDim2.fromOffset(4, 2)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = title
	t.Parent = bg
	local s = Instance.new("TextLabel")
	s.Name = "Subtitle"
	s.Size = UDim2.new(1, -8, 0.38, 0)
	s.Position = UDim2.new(0, 4, 0.58, 0)
	s.BackgroundTransparency = 1
	s.Font = Enum.Font.GothamBold
	s.TextScaled = true
	s.TextColor3 = Color3.fromHex("#ffd54f")
	s.Text = subtitle
	s.Parent = bg
	return t, s
end

function World.BuildHub(root: Instance)
	local H = Config.Hub
	local hub = Instance.new("Folder")
	hub.Name = "Market"
	hub.Parent = root
	local out = {}

	local function stall(pos: Vector3, color: string, stripe: string, sign: string, npcColors: { string }, title: string, sub: string)
		local m = Models.BuildStall(color, stripe, sign, 3.4)
		m:PivotTo(CFrame.new(pos) * FACE_PLAZA)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = true
			end
		end
		m.Parent = hub
		local npc = Models.BuildNPC(npcColors[1], npcColors[2], npcColors[3])
		npc:PivotTo(CFrame.new(pos + Vector3.new(0, 0, 0.15 * S)) * FACE_PLAZA)
		npc.Parent = hub
		local anchor = part(hub, Vector3.new(4, 4, 1), CFrame.new(pos + Vector3.new(0, 4, 1.4 * S)), "#000000", nil, { Transparency = 1, CanCollide = false, Name = sign .. "Prompt" })
		billboard(anchor, title, sub, 8.5, 220)
		return anchor, npc
	end
	local sellAnchor, sellNpc = stall(H.Sell, "#1e88e5", "#e3f2fd", "SNOW BUYER", { "#1565c0", "#f9a825", "#e3f2fd" }, "SNOW BUYER", Config.SNOW_VALUE .. " coin per snow")
	local shopAnchor, shopNpc = stall(H.Shop, "#c62828", "#fff8e1", "TOOL SHOP", { "#6d4c41", "#c62828", "#43a047" }, "TOOL SHOP", "Shopping list inside!")
	out.SellPrompt = prompt(sellAnchor, "Sell snow pile", "Snow Buyer")
	out.ShopPrompt = prompt(shopAnchor, "Open shopping list", "Tool Shop")
	out.SellNpc, out.ShopNpc = sellNpc, shopNpc
	CollectionService:AddTag(sellNpc, "Vendor")
	CollectionService:AddTag(shopNpc, "Vendor")

	-- snow pile corral (the mound itself is drawn per player on the client)
	local ring = H.PileRadius + 1.4
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		if math.abs(a - math.pi / 2) > 0.5 then
			local p = part(hub, Vector3.new(1.5, 2.4, 0.36), CFrame.new(H.Pile.X + math.cos(a) * ring, 1.2, H.Pile.Z + math.sin(a) * ring) * CFrame.Angles(0, -a + math.pi / 2, 0), "#8d6e63", Enum.Material.Wood)
			p.CanCollide = true
		end
	end
	local pileBase = part(hub, Vector3.new(0.4, H.PileRadius * 2, H.PileRadius * 2), CFrame.new(H.Pile + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), "#dfe8f3", Enum.Material.Snow, { Name = "PileBase", Shape = Enum.PartType.Cylinder, CanCollide = false })
	billboard(pileBase, "SNOW PILE", "Toss your snow here", 9, 200)
	out.PileBase = pileBase

	-- tool display: 20 items on 4 tight tiers right beside the shop stall
	local displayFolder = Instance.new("Folder")
	displayFolder.Name = "ToolDisplay"
	displayFolder.Parent = hub
	local o, cols, sx, sz = H.DisplayOrigin, H.DisplayCols, H.DisplayStepX, H.DisplayStepZ
	local width = cols * sx + 1.2
	for r = 0, 3 do
		local hgt = (0.25 + (3 - r) * 0.28) * S
		local z = o.Z + r * sz + sz / 2
		part(displayFolder, Vector3.new(width, hgt, sz), CFrame.new(o.X + width / 2 - 0.6, hgt / 2, z), "#e8e2d6", Enum.Material.Marble, { CanCollide = true })
		part(displayFolder, Vector3.new(width, 0.2, 0.2), CFrame.new(o.X + width / 2 - 0.6, hgt, z + sz / 2 - 0.1), "#c62828")
	end
	local banner = part(displayFolder, Vector3.new(1, 1, 1), CFrame.new(o.X + width / 2, 12, o.Z + 1), "#000000", nil, { Transparency = 1, CanCollide = false })
	billboard(banner, "TOOLS & MACHINES", "Walk up or click one", 0, 240)

	out.Displays = {}
	for i, tool in Config.Tools do
		local fromFront = (i - 1) // 5 -- 0..3: hand tools in front, machines at the back
		local r = 3 - fromFront
		local c = (i - 1) % 5
		local hgt = (0.25 + (3 - r) * 0.28) * S
		local x = o.X + c * sx + sx / 2 - 0.6
		local z = o.Z + r * sz + sz / 2
		local holder = Instance.new("Model")
		holder.Name = "Display_" .. tool.id
		holder:SetAttribute("ToolId", tool.id)
		local ped = part(holder, Vector3.new(0.36, 3.6, 3.6), CFrame.new(x, hgt + 0.18, z) * CFrame.Angles(0, 0, math.pi / 2), if tool.kind == "hand" then "#90caf9" else "#ffcc80", Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, Name = "Pedestal" })
		ped.CanCollide = false
		local top = hgt + 0.36
		-- the model
		local m = Models.Build(tool.id)
		if tool.kind == "hand" then
			m:PivotTo(CFrame.Angles(math.rad(-15), 0, 0))
		end
		local _, size = m:GetBoundingBox()
		local scale = if tool.kind == "hand" then math.min(1.3, 3.4 / math.max(size.Y, 0.8)) else 3.2 / math.max(size.X, size.Z)
		m:ScaleTo(scale)
		local bcf, bsize = m:GetBoundingBox()
		local pivot = m:GetPivot()
		local offset = Vector3.new(x, top, z) - Vector3.new(bcf.Position.X, bcf.Position.Y - bsize.Y / 2, bcf.Position.Z)
		m:PivotTo(pivot + offset)
		m.Name = "Item"
		m:SetAttribute("SpinCentre", Vector3.new(x, top, z))
		m.Parent = holder
		local hit = part(holder, Vector3.new(3.8, math.max(4, bsize.Y + 1), 3.8), CFrame.new(x, top + math.max(4, bsize.Y + 1) / 2, z), "#000000", nil, { Transparency = 1, CanCollide = false, Name = "Hit" })
		hit.CanQuery = true
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 80
		click.Parent = hit
		local pp = prompt(hit, "Inspect", tool.name, 7)
		pp.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		local title, sub = billboard(hit, tool.name, Config.FormatNumber(tool.price) .. " coins", bsize.Y / 2 + 1.4, 150)
		title.Name = "Title"
		sub.Name = "Subtitle"
		holder.Parent = displayFolder
		CollectionService:AddTag(holder, "ToolDisplay")
		table.insert(out.Displays, { id = tool.id, click = click, prompt = pp })
	end

	-- spin wheel stand
	local post = "#5d4037"
	part(hub, Vector3.new(0.6, 9.6, 0.6), CFrame.new(H.Wheel + Vector3.new(-4.8, 4.8, 0)), post, Enum.Material.Wood, { CanCollide = true })
	part(hub, Vector3.new(0.6, 9.6, 0.6), CFrame.new(H.Wheel + Vector3.new(4.8, 4.8, 0)), post, Enum.Material.Wood, { CanCollide = true })
	part(hub, Vector3.new(10.8, 0.9, 3), CFrame.new(H.Wheel + Vector3.new(0, 0.45, 0)), post, Enum.Material.Wood, { CanCollide = true })
	part(hub, Vector3.new(9.6, 0.4, 0.4), CFrame.new(H.Wheel + Vector3.new(0, 9.4, 0)), post, Enum.Material.Wood)
	local wheel = Models.BuildWheel(1.4)
	wheel.Name = "SpinWheel"
	wheel:PivotTo(CFrame.new(H.Wheel + Vector3.new(0, 5.7, 0.4)) * FACE_PLAZA)
	wheel.Parent = hub
	CollectionService:AddTag(wheel, "SpinWheel")
	local pointer = Instance.new("WedgePart")
	pointer.Anchored = true
	pointer.Size = Vector3.new(0.3, 1.2, 0.8)
	pointer.Color = Color3.fromHex("#e53935")
	pointer.CFrame = CFrame.new(H.Wheel + Vector3.new(0, 10.2, 0.6)) * CFrame.Angles(math.pi, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
	pointer.Parent = hub
	local wheelAnchor = part(hub, Vector3.new(4, 4, 1), CFrame.new(H.Wheel + Vector3.new(0, 4, 2)), "#000000", nil, { Transparency = 1, CanCollide = false, Name = "WheelPrompt" })
	billboard(wheelAnchor, "LUCKY SPIN", "Free spin every day!", 9, 220)
	out.WheelPrompt = prompt(wheelAnchor, "Spin the wheel", "Lucky Spin")
	local wclick = Instance.new("ClickDetector")
	wclick.MaxActivationDistance = 80
	wclick.Parent = wheelAnchor
	out.WheelClick = wclick

	-- daily gift
	local gift = Models.BuildGift()
	gift:ScaleTo(1)
	gift:PivotTo(CFrame.new(H.Gift))
	gift.Parent = hub
	CollectionService:AddTag(gift, "Gift")
	local giftAnchor = part(hub, Vector3.new(3.6, 3.6, 3.6), CFrame.new(H.Gift + Vector3.new(0, 1.8, 0)), "#000000", nil, { Transparency = 1, CanCollide = true, Name = "GiftPrompt" })
	billboard(giftAnchor, "DAILY REWARD", "Claim every day", 4.5, 200)
	out.GiftPrompt = prompt(giftAnchor, "Claim daily reward", "Gift")
	local gclick = Instance.new("ClickDetector")
	gclick.MaxActivationDistance = 80
	gclick.Parent = giftAnchor
	out.GiftClick = gclick

	-- plaza tree and benches
	local tree = Models.BuildXmasTree()
	tree:PivotTo(CFrame.new(11.5 * S, 0, 2.2 * S))
	tree.Parent = hub
	part(hub, Vector3.new(3, 10, 3), CFrame.new(11.5 * S, 5, 2.2 * S), "#000000", nil, { Transparency = 1, CanCollide = true })
	for _, bx in { -8 * S, 6 * S } do
		local bench = Instance.new("Model")
		bench.Name = "Bench"
		local wood = "#8d6e63"
		part(bench, Vector3.new(6, 0.3, 1.8), CFrame.new(bx, 1.5, 4.6 * S), wood, Enum.Material.Wood, { CanCollide = true })
		part(bench, Vector3.new(6, 1.5, 0.24), CFrame.new(bx, 2.55, 4.6 * S + 0.84), wood, Enum.Material.Wood, { CanCollide = true })
		for _, sx2 in { -2.55, 2.55 } do
			part(bench, Vector3.new(0.24, 1.5, 1.5), CFrame.new(bx + sx2, 0.75, 4.6 * S), "#263238", Enum.Material.Metal, { CanCollide = true })
		end
		bench.Parent = hub
	end

	return out
end

return World
