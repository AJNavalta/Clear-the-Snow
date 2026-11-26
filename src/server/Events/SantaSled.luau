--!nonstrict
-- Santa Sled Party: a stretch of the main road fills with deep snow that won't grow back
-- by itself. Players clear it so Santa's sleigh can take off. Settings: Config.Events.SantaSled.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Event = {
	Name = "Santa Sled Party",
	BarKind = "progress",
	Weight = 1,
	Duration = Config.Events.SantaSled.Duration,
}

local function pole(parent: Instance, pos: Vector3)
	-- a red and white striped marker pole
	for i = 0, 5 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Size = Vector3.new(0.6, 1, 0.6)
		p.Material = Enum.Material.SmoothPlastic
		p.Color = if i % 2 == 0 then Color3.fromHex("#d32f2f") else Color3.new(1, 1, 1)
		p.CFrame = CFrame.new(pos + Vector3.new(0, 0.5 + i, 0))
		p.Parent = parent
	end
	local top = Instance.new("Part")
	top.Shape = Enum.PartType.Ball
	top.Anchored = true
	top.CanCollide = false
	top.CanQuery = false
	top.Material = Enum.Material.Neon
	top.Color = Color3.fromHex("#ffd54f")
	top.Size = Vector3.new(1, 1, 1)
	top.CFrame = CFrame.new(pos + Vector3.new(0, 6.4, 0))
	top.Parent = parent
end

function Event.Run(ev)
	local cfg = ev.Config.Events.SantaSled
	local r = cfg.Runway
	local tiles = ev.Snow.TilesInRect(r)

	-- deep snow on the runway, scaled to how many players there are
	local per = math.clamp(cfg.SnowPerPlayer * #Players:GetPlayers(), cfg.SnowPerPlayer, ev.Config.TILE_MAX_UNITS)
	ev.Snow.SetFrozen(tiles, true)
	ev.Snow.Fill(tiles, per)
	ev.OnCleanup(function()
		ev.Snow.SetFrozen(tiles, false)
	end)
	local start = math.max(1, ev.Snow.Amount(tiles))

	local folder = Instance.new("Folder")
	folder.Name = "SantaSledEvent"
	folder.Parent = Workspace
	ev.OnCleanup(function()
		folder:Destroy()
	end)
	for _, x in { r[1], r[3] } do
		for _, z in { r[2], r[4] } do
			pole(folder, Vector3.new(x, 0, z))
		end
	end
	local sign = Instance.new("Part")
	sign.Anchored, sign.CanCollide, sign.CanQuery, sign.Transparency = true, false, false, 1
	sign.Size = Vector3.new(1, 1, 1)
	sign.CFrame = CFrame.new((r[1] + r[3]) / 2, 4, (r[2] + r[4]) / 2)
	sign.Parent = folder
	ev.Billboard(sign, "SANTA'S RUNWAY", "Scoop the road clear!", 4)

	local sleigh = ev.Models.BuildSleigh()
	local base = CFrame.lookAt(cfg.SleighPosition, cfg.SleighPosition + Vector3.xAxis)
	sleigh:PivotTo(base)
	local root = ev.Models.Rig(sleigh) -- move it by its Root only
	sleigh.Parent = folder
	ev.Billboard(sleigh.PrimaryPart, "SANTA", "Waiting for a clear road", 9)

	ev.AddZone(r, cfg.ClearBoost, function(player, amount)
		ev.Contribute(player, amount)
	end)
	ev.Announce("Santa Sled Party! Clear the snow off the main road so Santa's sleigh can take off!", 5)

	local won = false
	while true do
		local progress = 1 - ev.Snow.Amount(tiles) / start
		local shown = math.clamp(progress / cfg.DoneAt, 0, 1)
		ev.SetBar(shown, "Road cleared: " .. math.floor(shown * 100) .. "%")
		if progress >= cfg.DoneAt then
			won = true
			break
		end
		if ev.TimeLeft() <= 0 then
			break
		end
		-- reindeer get restless
		root.CFrame = base * CFrame.new(0, math.abs(math.sin(os.clock() * 3)) * 0.15, 0)
		task.wait(0.2)
	end

	if not won then
		ev.SetBar(0, "Out of time!")
		ev.Announce("Out of time! Santa's sleigh is stuck in the snow. Maybe next time.", 5)
		task.wait(3)
		return false
	end

	-- take off down the runway and up into the sky
	ev.SetBar(1, "Ho ho ho! Santa is taking off!")
	ev.Announce("You did it! Santa's sleigh is taking off!", 4)
	local trail = Instance.new("Sparkles")
	trail.SparkleColor = Color3.fromHex("#ffe9a8")
	trail.Parent = sleigh.PrimaryPart
	local t0 = os.clock()
	while true do
		local t = os.clock() - t0
		if t > 8 then
			break
		end
		local x = 4 * t + 3 * t * t
		local y = math.max(0, t - 1.2) ^ 2 * 2.2
		local pitch = math.clamp((t - 1.2) * 0.12, 0, 0.35)
		root.CFrame = base * CFrame.new(0, y, -x) * CFrame.Angles(pitch, 0, 0)
		RunService.Heartbeat:Wait()
	end
	return true
end

return Event
