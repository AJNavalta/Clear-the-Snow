--!nonstrict
-- Clear the Snow: server entry point.
-- Builds the town, runs the snow harvesting loop, handles selling, buying,
-- equipping, daily rewards and the spin wheel, and keeps player attributes in sync
-- for the client UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Models = require(Shared.Models)
local World = require(script.Parent.World)
local SnowService = require(script.Parent.SnowService)
local DataService = require(script.Parent.DataService)

local H = Config.Hub

-- ------------------------------------------------------------------ remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remoteEvent(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local function remoteFunction(name: string): RemoteFunction
	local r = Instance.new("RemoteFunction")
	r.Name = name
	r.Parent = remotes
	return r
end
local SetScooping = remoteEvent("SetScooping")
local SetAuto = remoteEvent("SetAuto")
local Notify = remoteEvent("Notify")
local BuyTool = remoteFunction("BuyTool")
local EquipTool = remoteFunction("EquipTool")
local ClaimDaily = remoteFunction("ClaimDaily")
local Spin = remoteFunction("Spin")
local SellPile = remoteFunction("SellPile")
local TutorialAction = remoteEvent("TutorialAction")
remotes.Parent = ReplicatedStorage

-- ------------------------------------------------------------------ world
local blocks, hub = World.Build()
SnowService.Init(blocks)

-- ------------------------------------------------------------------ helpers
local function today(): number
	return math.floor(os.time() / 86400)
end

local function owns(d, id: string): boolean
	return table.find(d.owned, id) ~= nil
end

local function nextTool(d)
	for _, t in Config.Tools do
		if not owns(d, t.id) then
			return t
		end
	end
	return nil
end

-- progress-scaled coin unit used by daily rewards and the wheel
local function progressCoins(d): number
	local n = nextTool(d)
	return if n then n.price else Config.Tools[#Config.Tools].price * 1.5
end

local function boostActive(d, name: string): boolean
	return (d.boosts[name] or 0) > os.time()
end

local function capacity(d): number
	return Config.GetTool(d.equipped).capacity * (if boostActive(d, "capacity") then 2 else 1)
end

local function dailyStatus(d)
	local t = today()
	local canClaim = d.daily.lastDay < t
	local continuing = d.daily.lastDay == t - 1
	local nextStreak = if canClaim then (if continuing then d.daily.streak + 1 else 1) else d.daily.streak
	local idx = (math.max(1, nextStreak) - 1) % #Config.DailyRewards + 1
	return canClaim, idx, nextStreak
end

local function dailyReward(d, idx: number)
	local r = Config.DailyRewards[idx]
	return math.max(r.min, math.floor(progressCoins(d) * r.pct + 0.5)), r.spins
end

local function freeSpinAvailable(d): boolean
	return d.lastFreeSpinDay < today()
end

local function wheelCoins(d, seg): number
	return math.max(10, math.floor(progressCoins(d) * 0.1 + 0.5)) * seg.mult
end

-- ------------------------------------------------------------------ tutorial
-- Steps (see Config.Tutorial): 1 scoop until full, 2 toss on the pile, 3 sell,
-- 4 buy the next tool, 5 "enjoy the game" card, 0 finished.
local publish -- forward declaration

local function setTutorial(player: Player, d, step: number)
	if d.tutorial == step then
		return
	end
	if step == 4 and not nextTool(d) then
		step = 5 -- nothing left to buy
	end
	d.tutorial = step
	if step == 5 then
		task.delay(Config.Tutorial.EnjoySeconds, function()
			local d2 = DataService.Get(player)
			if d2 and d2.tutorial == 5 then
				d2.tutorial = 0
				publish(player)
				task.spawn(DataService.Save, player)
			end
		end)
	end
end

-- automatic steps, checked every frame
local function tutorialTick(player: Player, d, cap: number)
	local t = d.tutorial
	if t == 1 and d.load >= math.max(1, cap) - 1e-6 then
		setTutorial(player, d, 2)
		t = 2
	end
	if (t == 1 or t == 2) and d.pile >= 1 then
		setTutorial(player, d, 3)
	end
end

-- ------------------------------------------------------------------ per-player runtime
type Runtime = {
	scooping: boolean,
	visual: Instance?, -- a Tool for hand tools, a welded Model for machines
	tool: Tool?,
	loadPart: BasePart?,
	loadFull: number,
	loadSize: Vector3?,
	minFill: number,
	front: number,
	tilt: number,
	dig: number,
	swing: number,
	sitTrack: AnimationTrack?,
	origHip: number?,
	lastPublish: number,
	fullWarned: boolean,
	busy: boolean,
}
local runtime: { [Player]: Runtime } = {}

function publish(player: Player)
	local d = DataService.Get(player)
	if not d then
		return
	end
	local canClaim, idx, streak = dailyStatus(d)
	player:SetAttribute("Coins", math.floor(d.coins))
	player:SetAttribute("Load", math.floor(d.load + 1e-6))
	player:SetAttribute("Capacity", capacity(d))
	player:SetAttribute("Pile", math.floor(d.pile))
	player:SetAttribute("Equipped", d.equipped)
	player:SetAttribute("Owned", table.concat(d.owned, ","))
	player:SetAttribute("Spins", d.spins + (if freeSpinAvailable(d) then 1 else 0))
	player:SetAttribute("FreeSpin", freeSpinAvailable(d))
	player:SetAttribute("DailyCanClaim", canClaim)
	player:SetAttribute("DailyIndex", idx)
	player:SetAttribute("DailyStreak", if canClaim then streak - 1 else streak)
	player:SetAttribute("DailyBroken", canClaim and d.daily.lastDay >= 0 and d.daily.lastDay < today() - 1 and d.daily.streak > 0)
	player:SetAttribute("ProgressCoins", progressCoins(d))
	player:SetAttribute("BoostSell", d.boosts.sell or 0)
	player:SetAttribute("BoostCapacity", d.boosts.capacity or 0)
	player:SetAttribute("Auto", d.auto)
	player:SetAttribute("Tutorial", d.tutorial)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Coins.Value = math.floor(d.coins)
		ls.Sold.Value = math.floor(d.totalSold)
	end
end

-- ------------------------------------------------------------------ equipping visuals
local SIT_R15 = "rbxassetid://2506281703"
local SIT_R6 = "rbxassetid://178130996"

local function clearVisual(player: Player, r: Runtime)
	if r.sitTrack then
		r.sitTrack:Stop(0.2)
		r.sitTrack = nil
	end
	if r.visual then
		r.visual:Destroy()
		r.visual = nil
	end
	r.tool = nil
	r.loadPart = nil
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and r.origHip then
		hum.HipHeight = r.origHip
	end
end

local function attachVisual(player: Player)
	local r = runtime[player]
	local d = DataService.Get(player)
	if not r or not d then
		return
	end
	clearVisual(player, r)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and hum and hrp) or hum.Health <= 0 then
		return
	end
	if not r.origHip then
		r.origHip = hum.HipHeight
	end
	local isR15 = hum.RigType == Enum.HumanoidRigType.R15
	local groundToHrp = (r.origHip :: number) + hrp.Size.Y / 2 + (if isR15 then 0 else 2)
	local tool = Config.GetTool(d.equipped)
	hum.WalkSpeed = tool.speed

	local model = Models.Build(tool.id)
	local minZ = math.huge
	local minY = math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			minZ = math.min(minZ, p.Position.Z - p.Size.Z / 2)
			minY = math.min(minY, p.Position.Y - p.Size.Y / 2)
		end
	end
	local loadPart = model:FindFirstChild("Load", true) :: BasePart?
	Models.Weld(model)
	model.Name = "EquippedTool"

	r.loadPart = loadPart
	r.loadFull = if loadPart then (loadPart:GetAttribute("FullHeight") or loadPart.Size.Y) else 1
	r.loadSize = if loadPart then loadPart.Size else nil
	r.minFill = if tool.id == "hands" then 0.45 else 0

	if tool.kind == "hand" then
		-- Hand tools become a real Roblox Tool, so the character holds it out in the
		-- right hand with the standard hold pose. The model's Root part is the Handle.
		local len = -minY -- shaft + blade length below the grip, in studs
		r.tilt = if len > 3.4 then math.acos(math.clamp(3.4 / len, -1, 0.99)) else 0.35
		r.front = 1.5 + tool.radius * 0.6
		local t = Instance.new("Tool")
		t.Name = tool.name
		t.ToolTip = tool.name
		t.CanBeDropped = false
		t.RequiresHandle = true
		t.ManualActivationOnly = true
		local handle = model.PrimaryPart :: BasePart
		handle.Name = "Handle"
		for _, c in model:GetChildren() do
			c.Parent = t
		end
		model:Destroy()
		t.Grip = CFrame.Angles(-r.tilt, 0, 0)
		t.Parent = char -- parenting a Tool to the character equips it
		-- keep it in hand if anything tries to unequip it
		t.AncestryChanged:Connect(function()
			if r.visual == t and t.Parent and t.Parent ~= char and char.Parent then
				task.defer(function()
					if r.visual == t and char.Parent then
						t.Parent = char
					end
				end)
			end
		end)
		r.visual = t
		r.tool = t
	else
		local weld = Instance.new("Weld")
		local seat = model:GetAttribute("SeatOffset") :: Vector3
		local standing = model:GetAttribute("Standing") == true
		local hrpHeight = groundToHrp
		if not standing then
			hrpHeight = seat.Y + 0.6
			hum.HipHeight = (r.origHip :: number) + (hrpHeight - groundToHrp)
			local anim = Instance.new("Animation")
			anim.AnimationId = if isR15 then SIT_R15 else SIT_R6
			local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
			local ok, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = true
				track:Play(0.2)
				r.sitTrack = track
			end
		end
		weld.Part0 = hrp
		weld.C0 = CFrame.new(-seat.X, -hrpHeight, -seat.Z)
		r.front = math.max(2, seat.Z - minZ - tool.radius * 0.5)
		weld.Part1 = model.PrimaryPart
		weld.Parent = model.PrimaryPart
		model.Parent = char
		r.visual = model
	end
	r.dig = 0
	r.swing = -1
end

local function updateLoadVisual(r: Runtime, fill: number)
	local p = r.loadPart
	if not p or not p.Parent then
		return
	end
	if r.minFill > 0 and r.loadSize then
		-- bare hands: always hold a little snowball that grows as you scoop
		local k = r.minFill + (1 - r.minFill) * math.clamp(fill, 0, 1)
		local want = r.loadSize * k
		if (p.Size - want).Magnitude > 0.02 then
			p.Size = want
		end
		p.Transparency = 0
	elseif fill < 0.02 then
		p.Transparency = 1
	else
		p.Transparency = 0
		local s = p.Size
		local y = math.max(0.05, r.loadFull * fill)
		if math.abs(s.Y - y) > 0.03 then
			p.Size = Vector3.new(s.X, y, s.Z)
		end
	end
end

local function equip(player: Player, id: string)
	local d = DataService.Get(player)
	if not d or not owns(d, id) then
		return false
	end
	d.equipped = id
	d.load = math.min(d.load, capacity(d))
	attachVisual(player)
	publish(player)
	return true
end

-- ------------------------------------------------------------------ actions
local function sell(player: Player)
	local d = DataService.Get(player)
	if not d then
		return 0
	end
	if d.pile < 1 then
		Notify:FireClient(player, "toast", if d.load > 0 then "Toss your snow on the Snow Pile first!" else "Your pile is empty. Go clear some snow!")
		return 0
	end
	local units = math.floor(d.pile)
	local coins = units * Config.SNOW_VALUE * (if boostActive(d, "sell") then 2 else 1)
	d.coins += coins
	d.totalSold += units
	d.pile -= units
	if d.tutorial >= 1 and d.tutorial <= 3 then
		local n = nextTool(d)
		if Config.Tutorial.StarterBonus and n and Config.ToolIndex[n.id] == 2 and d.coins < n.price then
			local bonus = n.price - d.coins
			d.coins += bonus
			Notify:FireClient(player, "toast", "Starter bonus: +" .. bonus .. " coins. Go buy the " .. n.name .. "!", 4)
		end
		setTutorial(player, d, 4)
	end
	publish(player)
	Notify:FireClient(player, "sold", coins)
	return coins
end

local function openFor(player: Player, panel: string, focus: string?)
	Notify:FireClient(player, "open", panel, focus)
end

hub.SellPrompt.Triggered:Connect(sell)
hub.ShopPrompt.Triggered:Connect(function(player)
	openFor(player, "shop")
end)
for _, disp in hub.Displays do
	disp.prompt.Triggered:Connect(function(player)
		openFor(player, "shop", disp.id)
	end)
	disp.click.MouseClick:Connect(function(player)
		openFor(player, "shop", disp.id)
	end)
end
hub.WheelPrompt.Triggered:Connect(function(player)
	openFor(player, "spin")
end)
hub.WheelClick.MouseClick:Connect(function(player)
	openFor(player, "spin")
end)
hub.GiftPrompt.Triggered:Connect(function(player)
	openFor(player, "daily")
end)
hub.GiftClick.MouseClick:Connect(function(player)
	openFor(player, "daily")
end)

SellPile.OnServerInvoke = function(player)
	-- selling from the UI only works while standing at the buyer
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - (H.Sell + Vector3.new(0, 0, 5))).Magnitude > 18 then
		return 0
	end
	return sell(player)
end

SetScooping.OnServerEvent:Connect(function(player, on)
	local r = runtime[player]
	if r then
		r.scooping = on == true
	end
end)

TutorialAction.OnServerEvent:Connect(function(player, action)
	local d = DataService.Get(player)
	if not d then
		return
	end
	if action == "skip" then
		d.tutorial = 0
	elseif action == "replay" then
		d.tutorial = 1
	end
	publish(player)
end)

SetAuto.OnServerEvent:Connect(function(player, on)
	local d = DataService.Get(player)
	if d then
		d.auto = on == true
		publish(player)
	end
end)

BuyTool.OnServerInvoke = function(player, id)
	local d = DataService.Get(player)
	local r = runtime[player]
	if not d or not r or typeof(id) ~= "string" or r.busy then
		return false, "Try again."
	end
	local i = Config.ToolIndex[id]
	if not i then
		return false, "Unknown tool."
	end
	local tool = Config.Tools[i]
	if owns(d, id) then
		equip(player, id)
		return true, "Equipped " .. tool.name
	end
	if i > 1 and not owns(d, Config.Tools[i - 1].id) then
		return false, "Buy the " .. Config.Tools[i - 1].name .. " first."
	end
	if d.coins < tool.price then
		return false, "You need " .. Config.FormatNumber(tool.price - d.coins) .. " more coins."
	end
	r.busy = true
	d.coins -= tool.price
	table.insert(d.owned, id)
	equip(player, id)
	r.busy = false
	if d.tutorial >= 1 and d.tutorial <= 4 then
		setTutorial(player, d, 5)
		publish(player)
	end
	task.spawn(DataService.Save, player)
	return true, "You got the " .. tool.name .. "!"
end

EquipTool.OnServerInvoke = function(player, id)
	if typeof(id) ~= "string" then
		return false
	end
	return equip(player, id)
end

ClaimDaily.OnServerInvoke = function(player)
	local d = DataService.Get(player)
	if not d then
		return nil
	end
	local canClaim, idx, streak = dailyStatus(d)
	if not canClaim then
		return nil
	end
	local coins, spins = dailyReward(d, idx)
	d.daily = { lastDay = today(), streak = streak }
	d.coins += coins
	d.spins += spins
	publish(player)
	task.spawn(DataService.Save, player)
	return { coins = coins, spins = spins, day = idx }
end

Spin.OnServerInvoke = function(player)
	local d = DataService.Get(player)
	local r = runtime[player]
	if not d or not r or r.busy then
		return nil
	end
	if freeSpinAvailable(d) then
		d.lastFreeSpinDay = today()
	elseif d.spins > 0 then
		d.spins -= 1
	else
		return nil
	end
	local total = 0
	for _, s in Config.Wheel do
		total += s.weight
	end
	local roll = math.random() * total
	local index = 1
	for i, s in Config.Wheel do
		roll -= s.weight
		if roll <= 0 then
			index = i
			break
		end
	end
	local seg = Config.Wheel[index]
	local msg
	if seg.kind == "coins" then
		local c = wheelCoins(d, seg)
		d.coins += c
		msg = "+" .. Config.FormatNumber(c) .. " coins!"
	elseif seg.kind == "spin" then
		d.spins += 1
		msg = "+1 bonus spin!"
	else
		local now = os.time()
		d.boosts[seg.boost] = math.max(now, d.boosts[seg.boost] or 0) + seg.mins * 60
		msg = (if seg.boost == "sell" then "2x sell price" else "2x carry capacity") .. " for " .. seg.mins .. " minutes!"
	end
	publish(player)
	task.spawn(DataService.Save, player)
	return { index = index, message = msg }
end

-- ------------------------------------------------------------------ players
local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	char:WaitForChild("HumanoidRootPart", 10)
	if not hum then
		return
	end
	local r = runtime[player]
	if r then
		r.origHip = hum.HipHeight
		r.visual = nil
		r.sitTrack = nil
	end
	task.wait(0.2)
	attachVisual(player)
end

local function onPlayer(player: Player)
	runtime[player] = {
		scooping = false,
		loadFull = 1,
		minFill = 0,
		front = 2,
		tilt = 0,
		dig = 0,
		swing = -1,
		lastPublish = 0,
		fullWarned = false,
		busy = false,
	}
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = ls
	local sold = Instance.new("IntValue")
	sold.Name = "Sold"
	sold.Parent = ls
	ls.Parent = player

	local d = DataService.Load(player)
	if not player.Parent then
		DataService.Release(player)
		return
	end
	if not owns(d, d.equipped) then
		d.equipped = "hands"
	end
	publish(player)
	player:SetAttribute("Ready", true)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayer, p)
end
Players.PlayerRemoving:Connect(function(player)
	runtime[player] = nil
	DataService.Release(player)
end)

-- ------------------------------------------------------------------ main loop
local pileFlat = Vector3.new(H.Pile.X, 0, H.Pile.Z)
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for player, r in runtime do
		local d = DataService.Get(player)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (d and hum and hrp) or hum.Health <= 0 then
			continue
		end
		local tool = Config.GetTool(d.equipped)
		local cap = capacity(d)
		local moving = hum.MoveDirection.Magnitude > 0.1
		local wants = r.scooping or d.auto or (tool.kind == "machine" and moving)
		local working = false
		if wants and d.load < cap - 1e-6 then
			local look = hrp.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
			local pos = hrp.Position + flat * r.front
			local got = SnowService.Harvest(pos.X, pos.Z, tool.radius, math.min(tool.rate * dt, cap - d.load))
			if got > 0 then
				d.load = math.min(cap, d.load + got)
				working = true
			end
		end
		if d.load >= cap - 1e-6 then
			if wants and not r.fullWarned then
				r.fullWarned = true
				Notify:FireClient(player, "full")
			end
		else
			r.fullWarned = false
		end

		-- digging motion for hand tools
		if tool.kind == "hand" and r.tool then
			r.dig = if working then r.dig + dt * 9 else 0
			local swing = if working then (math.sin(r.dig) * 0.5 + 0.5) * 0.5 else 0
			if math.abs(swing - r.swing) > 0.04 then
				r.swing = swing
				r.tool.Grip = CFrame.Angles(-(r.tilt + swing), 0, 0)
			end
		end

		-- toss into the pile
		local flatPos = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
		local reach = H.PileRadius + 7 + (if tool.kind == "machine" then r.front * 0.6 else 0)
		if d.load >= 1 and (flatPos - pileFlat).Magnitude < reach then
			local units = math.floor(d.load + 1e-6)
			d.pile += units
			d.load -= units
			Notify:FireClient(player, "dumped", units)
			publish(player)
		end

		if d.tutorial > 0 then
			tutorialTick(player, d, cap)
		end
		updateLoadVisual(r, d.load / cap)
		if now - r.lastPublish > 0.15 then
			r.lastPublish = now
			publish(player)
		end
	end
end)
