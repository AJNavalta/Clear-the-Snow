--!nonstrict
-- Yeti Abomination: a huge Yeti stomps onto the main road. Everyone can throw snowballs
-- (Q) during this event, whatever tool they hold. Its HP is Config.Events.Yeti.HitsPerPlayer
-- snowballs for every player in the server.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Event = {
	Name = "Yeti Abomination",
	BarKind = "hp",
	Weight = 1,
	Duration = Config.Events.Yeti.Duration,
}

function Event.Run(ev)
	local cfg = ev.Config.Events.Yeti
	local maxHp = cfg.HitsPerPlayer * math.max(1, #Players:GetPlayers())
	local hp = maxHp

	-- more players joining makes it tougher
	local joined = Players.PlayerAdded:Connect(function()
		maxHp += cfg.HitsPerPlayer
		hp += cfg.HitsPerPlayer
	end)
	ev.OnCleanup(function()
		joined:Disconnect()
	end)

	local yeti = ev.Models.BuildYeti()
	local root = ev.Models.Rig(yeti) -- move it by its Root only
	for _, p in yeti:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			p.CanQuery = true -- snowballs can hit it
			p.CanCollide = true
		end
	end
	local pos = cfg.Position
	local facing = CFrame.lookAt(pos, Vector3.new(0, 0, 0) * Vector3.new(1, 0, 1) + Vector3.new(0, pos.Y, 0))
	root.CFrame = facing * CFrame.new(0, -14, 0)
	yeti.Parent = Workspace
	ev.OnCleanup(function()
		yeti:Destroy()
	end)
	ev.Billboard(yeti.PrimaryPart, "YETI", "Throw snowballs! (Q)", 17)

	local flinch = 0
	ev.AllowSnowballsForAll(true)
	ev.OnSnowballHit(function(inst, thrower)
		if hp > 0 and inst:IsDescendantOf(yeti) then
			hp -= 1
			flinch = 1
			ev.Contribute(thrower, 1)
			return true
		end
		return false
	end)
	ev.Announce("A Yeti Abomination is on the main road! Everyone can throw snowballs (Q). Knock it out!", 5)

	-- rise out of the snow
	for i = 1, 30 do
		root.CFrame = facing * CFrame.new(0, -14 + 14 * (i / 30), 0)
		task.wait(1 / 30)
	end

	local won = false
	local yaw = 0
	while true do
		local dt = RunService.Heartbeat:Wait()
		ev.SetBar(hp / maxHp, "Yeti HP: " .. math.max(0, hp) .. " / " .. maxHp)
		if hp <= 0 then
			won = true
			break
		end
		if ev.TimeLeft() <= 0 then
			break
		end
		-- turn toward the nearest player
		local best, bestD = nil, math.huge
		for _, p in Players:GetPlayers() do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = (hrp.Position - pos).Magnitude
				if d < bestD then
					best, bestD = hrp, d
				end
			end
		end
		if best then
			local to = best.Position - pos
			local want = math.atan2(-to.X, -to.Z)
			local base = select(2, facing:ToOrientation())
			local diff = (want - base - yaw + math.pi) % (2 * math.pi) - math.pi
			yaw += diff * math.min(1, dt * 1.5)
		end
		flinch = math.max(0, flinch - dt * 5)
		local stomp = math.abs(math.sin(os.clock() * 2)) * 0.5
		root.CFrame = facing * CFrame.Angles(0, yaw, 0) * CFrame.new(0, stomp, 0) * CFrame.Angles(-0.15 * flinch, 0, 0)
	end

	local finalCf = root.CFrame
	if won then
		ev.SetBar(0, "The Yeti is down!")
		ev.Announce("The Yeti is knocked out! Great throwing, everyone!", 4)
		for i = 1, 40 do
			root.CFrame = finalCf * CFrame.Angles(-math.rad(85) * (i / 40), 0, 0)
			task.wait(1 / 30)
		end
		task.wait(1.5)
		finalCf = root.CFrame
	else
		ev.Announce("The Yeti got away! It'll be back...", 4)
	end
	for i = 1, 45 do
		root.CFrame = finalCf * CFrame.new(0, -0.35 * i, 0)
		task.wait(1 / 30)
	end
	return won
end

return Event
