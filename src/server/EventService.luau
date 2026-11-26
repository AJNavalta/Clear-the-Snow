--!nonstrict
-- Timed events. Every Config.Events.Interval seconds this picks a random event from the
-- modules in the Events folder and runs it. The current state goes into attributes on
-- ReplicatedStorage.EventState, which the top-of-screen event bar reads.
--
-- To add an event, add a ModuleScript to src/server/Events that returns:
--   {
--     Name = "My Event",            -- shown at the top of the screen
--     BarKind = "progress" | "hp",  -- green progress bar or red HP bar
--     Weight = 1,                   -- optional: relative chance of being picked
--     Duration = 300,               -- seconds before it times out
--     Run = function(ev) ... return true end, -- true = players won
--   }
-- `ev` gives you helpers: ev.SetBar, ev.Announce, ev.Contribute, ev.TimeLeft, ev.AddZone,
-- ev.OnSnowballHit, ev.AllowSnowballsForAll, ev.OnCleanup, ev.Billboard, plus
-- ev.Config, ev.Models and ev.Snow (SnowService). See SantaSled.luau and Yeti.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Models = require(Shared.Models)
local E = Config.Events

local EventService = {}

local state = Instance.new("Folder")
state.Name = "EventState"
state.Parent = ReplicatedStorage

local zones = {}
local hitHandlers = {}
local snowballsForAll = false

-- ---------------------------------------------------------------- hooks used by Main / SnowballService
-- an event clear-zone containing this point, if any: { boost = n, onCleared = fn(player, amount) }
function EventService.ZoneAt(x: number, z: number)
	for _, zn in zones do
		local r = zn.rect
		if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then
			return zn
		end
	end
	return nil
end

-- returns true if an event used the hit
function EventService.HandleSnowballHit(inst: Instance, thrower: Player): boolean
	for _, fn in hitHandlers do
		if fn(inst, thrower) then
			return true
		end
	end
	return false
end

function EventService.SnowballsForAll(): boolean
	return snowballsForAll
end

-- ---------------------------------------------------------------- helpers
local function now(): number
	return Workspace:GetServerTimeNow()
end

local function billboard(part: BasePart, title: string, sub: string?, height: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 64)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height or 6, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	local function line(text, y, h, color)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0, y)
		t.Size = UDim2.fromScale(1, h)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = color
		t.TextStrokeTransparency = 0.2
		t.Parent = bb
	end
	line(title, 0, if sub then 0.6 else 1, Color3.fromHex("#ffd54f"))
	if sub then
		line(sub, 0.6, 0.4, Color3.new(1, 1, 1))
	end
	bb.Parent = part
	return bb
end

local function loadEvents()
	local list = {}
	local folder = script.Parent:WaitForChild("Events")
	for _, m in folder:GetChildren() do
		if m:IsA("ModuleScript") then
			local ok, ev = pcall(require, m)
			if ok and type(ev) == "table" and type(ev.Run) == "function" then
				ev.Id = m.Name
				table.insert(list, ev)
			else
				warn("[ClearTheSnow] event " .. m.Name .. " failed to load:", ev)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

local function pick(list)
	if E.OnlyEvent then
		for _, ev in list do
			if ev.Id == E.OnlyEvent then
				return ev
			end
		end
	end
	local total = 0
	for _, ev in list do
		total += ev.Weight or 1
	end
	local roll = math.random() * total
	for _, ev in list do
		roll -= ev.Weight or 1
		if roll <= 0 then
			return ev
		end
	end
	return list[1]
end

-- ---------------------------------------------------------------- running an event
local function run(def, hooks)
	local contributions: { [Player]: number } = {}
	local cleanups = {}
	local endsAt = now() + (def.Duration or 300)

	state:SetAttribute("Title", def.Name)
	state:SetAttribute("BarKind", def.BarKind or "progress")
	state:SetAttribute("Progress", if def.BarKind == "hp" then 1 else 0)
	state:SetAttribute("BarText", "")
	state:SetAttribute("EndsAt", endsAt)
	state:SetAttribute("Phase", "active")

	local ev = {
		Config = Config,
		Models = Models,
		Snow = hooks.SnowService,
		Billboard = billboard,
	}
	function ev.TimeLeft(): number
		return endsAt - now()
	end
	function ev.SetBar(fraction: number, text: string)
		state:SetAttribute("Progress", math.clamp(fraction, 0, 1))
		state:SetAttribute("BarText", text)
	end
	function ev.Announce(text: string, secs: number?)
		hooks.Notify:FireAllClients("toast", text, secs or 4)
	end
	function ev.Contribute(player: Player, amount: number)
		contributions[player] = (contributions[player] or 0) + amount
	end
	function ev.OnCleanup(fn)
		table.insert(cleanups, fn)
	end
	-- players scooping inside rect clear snow `boost` times faster without filling their load
	function ev.AddZone(rect: { number }, boost: number, onCleared)
		table.insert(zones, { rect = rect, boost = boost, onCleared = onCleared })
	end
	-- fn(hitInstance, thrower) -> true if the hit counted for this event
	function ev.OnSnowballHit(fn)
		table.insert(hitHandlers, fn)
	end
	function ev.AllowSnowballsForAll(on: boolean)
		snowballsForAll = on
		state:SetAttribute("SnowballsForAll", on)
	end

	local ok, result = pcall(def.Run, ev)
	if not ok then
		warn("[ClearTheSnow] event " .. tostring(def.Id) .. " errored:", result)
		result = false
	end
	for _, fn in cleanups do
		pcall(fn)
	end
	table.clear(zones)
	table.clear(hitHandlers)
	ev.AllowSnowballsForAll(false)

	if result == true then
		for player, amount in contributions do
			if player.Parent and amount > 0 then
				local coins = hooks.reward(player)
				hooks.Notify:FireClient(player, "toast", def.Name .. " complete! You earned " .. Config.FormatNumber(coins) .. " coins for helping.", 4)
			end
		end
	end
end

function EventService.Init(hooks)
	-- hooks: { Notify = RemoteEvent, SnowService = module, reward = fn(player) -> coins }
	local list = loadEvents()
	if #list == 0 then
		return
	end
	local interval = if RunService:IsStudio() then E.StudioInterval else E.Interval
	task.spawn(function()
		while true do
			state:SetAttribute("Phase", "waiting")
			state:SetAttribute("NextAt", now() + interval)
			task.wait(interval)
			if #Players:GetPlayers() > 0 then
				run(pick(list), hooks)
			end
		end
	end)
end

return EventService
