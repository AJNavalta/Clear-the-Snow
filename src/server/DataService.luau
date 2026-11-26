--!strict
-- Player save data in a DataStore, with retries, autosave and shutdown saving.
-- In Studio without "Enable Studio Access to API Services", the game still runs and
-- simply doesn't save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DataService = {}

export type Data = {
	coins: number,
	owned: { string },
	equipped: string,
	load: number,
	pile: number,
	spins: number,
	lastFreeSpinDay: number,
	daily: { lastDay: number, streak: number },
	boosts: { sell: number, capacity: number },
	auto: boolean,
	totalSold: number,
	tutorial: number, -- 1..5 = current tutorial step, 0 = finished
}

local function defaults(): Data
	return {
		coins = 0,
		owned = { "hands" },
		equipped = "hands",
		load = 0,
		pile = 0,
		spins = 0,
		lastFreeSpinDay = -1,
		daily = { lastDay = -1, streak = 0 },
		boosts = { sell = 0, capacity = 0 },
		auto = false,
		totalSold = 0,
		tutorial = 1,
	}
end

local store: DataStore? = nil
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore("ClearTheSnow_v1")
end)
if not ok then
	warn("[ClearTheSnow] DataStore unavailable, progress will not save:", err)
end

local sessions: { [Player]: Data } = {}
local loaded: { [Player]: boolean } = {}

local function key(player: Player): string
	return "player_" .. player.UserId
end

local function merge(saved: any): Data
	local d = defaults()
	if typeof(saved) ~= "table" then
		return d
	end
	for k, v in saved do
		if (d :: any)[k] ~= nil and typeof(v) == typeof((d :: any)[k]) then
			(d :: any)[k] = v
		end
	end
	d.daily = {
		lastDay = if typeof(saved.daily) == "table" and typeof(saved.daily.lastDay) == "number" then saved.daily.lastDay else -1,
		streak = if typeof(saved.daily) == "table" and typeof(saved.daily.streak) == "number" then saved.daily.streak else 0,
	}
	d.boosts = {
		sell = if typeof(saved.boosts) == "table" and typeof(saved.boosts.sell) == "number" then saved.boosts.sell else 0,
		capacity = if typeof(saved.boosts) == "table" and typeof(saved.boosts.capacity) == "number" then saved.boosts.capacity else 0,
	}
	if not table.find(d.owned, "hands") then
		table.insert(d.owned, 1, "hands")
	end
	return d
end

function DataService.Load(player: Player): Data
	local data: Data? = nil
	if store then
		for attempt = 1, 3 do
			local success, result = pcall(function()
				return (store :: DataStore):GetAsync(key(player))
			end)
			if success then
				data = merge(result)
				loaded[player] = true
				break
			end
			warn("[ClearTheSnow] load failed (attempt " .. attempt .. "):", result)
			task.wait(1.5 * attempt)
		end
	end
	local d = data or defaults()
	sessions[player] = d
	return d
end

function DataService.Get(player: Player): Data?
	return sessions[player]
end

function DataService.Save(player: Player)
	local d = sessions[player]
	-- only write if the load succeeded, so a failed load never wipes real progress
	if not d or not store or not loaded[player] then
		return
	end
	for attempt = 1, 3 do
		local success, e = pcall(function()
			(store :: DataStore):SetAsync(key(player), d)
		end)
		if success then
			return
		end
		warn("[ClearTheSnow] save failed (attempt " .. attempt .. "):", e)
		task.wait(1.5 * attempt)
	end
end

function DataService.Release(player: Player)
	DataService.Save(player)
	sessions[player] = nil
	loaded[player] = nil
end

-- autosave
task.spawn(function()
	while true do
		task.wait(90)
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.Save, player)
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() and not store then
		return
	end
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			DataService.Save(player)
			pending -= 1
		end)
	end
	local t = os.clock()
	while pending > 0 and os.clock() - t < 25 do
		task.wait(0.2)
	end
end)

return DataService
