--!nonstrict
-- Christmas presents that drop from the sky every now and then. Each one floats down
-- under a little parachute glow, lands somewhere in town, and the first player to walk
-- into it gets bonus coins. Tuning: Config.Presents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Models = require(Shared.Models)
local P = Config.Presents

local PresentService = {}

local WRAPS = {
	{ "#c62828", "#ffd54f" },
	{ "#2e7d32", "#ffffff" },
	{ "#1565c0", "#e0e0e0" },
	{ "#8e24aa", "#ffd54f" },
	{ "#ef6c00", "#c62828" },
}

local folder: Folder
local live = {}
local rng = Random.new()

-- a spot on open ground (not a roof, not the market), or nil
local function findSpot(): Vector3?
	local half = Config.WORLD_SIZE / 2 * 0.85
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	for _ = 1, 15 do
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		local nearMarket = math.abs(x) < 45 and z > -40 and z < 15
		if not nearMarket then
			local hit = Workspace:Raycast(Vector3.new(x, 150, z), Vector3.new(0, -300, 0), params)
			if hit and hit.Position.Y < 2 and not (hit.Instance.Parent and hit.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
				return hit.Position
			end
		end
	end
	return nil
end

local function spawnPresent(reward: (Player) -> number, notify: RemoteEvent)
	local spot = findSpot()
	if not spot then
		return
	end
	local gift = Models.BuildGift()
	local wrap = WRAPS[rng:NextInteger(1, #WRAPS)]
	for _, p in gift:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			p.Color = if p.Material == Enum.Material.Metal then Color3.fromHex(wrap[2]) else Color3.fromHex(wrap[1])
			p.CanCollide = false
			p.CanQuery = false
		end
	end
	gift.Name = "Present"
	-- glow so it can be spotted from a distance
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("#ffe9a8")
	light.Range = 14
	light.Brightness = 2
	light.Parent = gift.PrimaryPart
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromHex("#fff3c4")
	sparkle.Parent = gift.PrimaryPart
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 30)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 160
	bb.LightInfluence = 0
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = "PRESENT"
	tl.TextColor3 = Color3.fromHex("#ffd54f")
	tl.TextStrokeTransparency = 0.2
	tl.Parent = bb
	bb.Parent = gift.PrimaryPart

	-- invisible pickup box
	local hitbox = Instance.new("Part")
	hitbox.Name = "Pickup"
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.Transparency = 1
	hitbox.Size = Vector3.new(6, 7, 6)
	hitbox.Parent = gift

	local entry = { model = gift, hitbox = hitbox, target = spot, y = spot.Y + 120, spin = rng:NextNumber(0, 6), landedAt = nil, taken = false }
	local function place()
		gift:PivotTo(CFrame.new(spot.X, entry.y, spot.Z) * CFrame.Angles(0, entry.spin, 0))
		hitbox.CFrame = CFrame.new(spot.X, entry.y + 3, spot.Z)
	end
	place()
	entry.place = place
	gift.Parent = folder

	hitbox.Touched:Connect(function(other)
		if entry.taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(other.Parent)
		local hum = other.Parent and other.Parent:FindFirstChildOfClass("Humanoid")
		if not player or not hum or hum.Health <= 0 then
			return
		end
		entry.taken = true
		local coins = reward(player)
		notify:FireClient(player, "present", coins)
		gift:Destroy()
	end)
	table.insert(live, entry)
end

function PresentService.Init(notify: RemoteEvent, reward: (Player) -> number)
	folder = Instance.new("Folder")
	folder.Name = "Presents"
	folder.Parent = Workspace

	-- falling and cleanup
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for i = #live, 1, -1 do
			local e = live[i]
			if e.taken or not e.model.Parent then
				table.remove(live, i)
			elseif not e.landedAt then
				e.y = math.max(e.target.Y, e.y - P.FallSpeed * dt)
				e.spin += dt * 1.2
				e.place()
				if e.y <= e.target.Y then
					e.landedAt = now
				end
			elseif now - e.landedAt > P.Lifetime then
				e.model:Destroy()
				table.remove(live, i)
			end
		end
	end)

	-- drops
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(P.Interval[1], P.Interval[2]))
			if #Players:GetPlayers() > 0 and #live < P.MaxOnMap then
				local n = math.min(rng:NextInteger(P.PerDrop[1], P.PerDrop[2]), P.MaxOnMap - #live)
				for _ = 1, n do
					spawnPresent(reward, notify)
				end
				notify:FireAllClients("toast", "Presents are falling from the sky! Grab them for bonus coins.", 3.5)
			end
		end
	end)
end

return PresentService
