--!strict
-- Everything you're likely to tweak lives here: tool stats and prices, snow regrowth,
-- daily rewards, the spin wheel, the tutorial text and where the market stands.
-- Edit, save, and Rojo syncs it into Studio straight away.
--
-- Tool columns: capacity = snow carried per trip, rate = snow scooped per second,
-- radius = clearing radius (metres), speed = walking speed (metres/second).

local Config = {}

-- Bumped whenever the game's scripts change. The client compares it with the server's so it
-- can warn when a place is running an out-of-date copy of the scripts.
Config.Version = 6

Config.STUDS_PER_METER = 3
Config.SNOW_VALUE = 1 -- coins per unit of snow sold

-- Snow field
Config.WORLD_SIZE = 360 -- studs, centred on the origin
Config.TILE = 6 -- studs per snow tile
Config.TILE_MAX_UNITS = 20 -- snow units in a full tile
Config.UNIT_HEIGHT = 0.11 -- studs of depth per unit
Config.REGROW_SECONDS = 40 -- time for an empty tile to refill
Config.REGROW_DELAY = { 6, 12 } -- pause after being scooped before regrowing

export type Tool = {
	id: string,
	kind: "hand" | "machine",
	name: string,
	price: number,
	capacity: number,
	rate: number,
	radius: number,
	speed: number,
	desc: string,
}

local S = Config.STUDS_PER_METER
local function t(id, kind, name, price, capacity, rate, radiusM, speedM, desc): Tool
	return {
		id = id,
		kind = kind,
		name = name,
		price = price,
		capacity = capacity,
		rate = rate,
		radius = radiusM * S,
		speed = math.floor(speedM * S * 0.95 + 0.5),
		desc = desc,
	}
end

Config.Tools = {
	-- 10 hand tools
	t("hands", "hand", "Bare Hands", 0, 1, 1.5, 0.55, 6.0, "Pack a snowball. Cold fingers, tiny loads."),
	t("trowel", "hand", "Garden Trowel", 10, 3, 3, 0.6, 6.0, "Borrowed from the flower bed."),
	t("kidshovel", "hand", "Kid's Plastic Shovel", 30, 6, 5, 0.7, 6.2, "Bright red and surprisingly sturdy."),
	t("shovel", "hand", "Snow Shovel", 65, 10, 7, 0.8, 6.2, "The classic. Lift with your legs."),
	t("bigshovel", "hand", "Big Shovel", 120, 16, 10, 0.95, 6.4, "A wider blade for wider driveways."),
	t("megashovel", "hand", "Mega Shovel", 200, 25, 14, 1.1, 6.4, "Even bigger. Your back is worried."),
	t("steelshovel", "hand", "Steel Grain Scoop", 340, 40, 19, 1.25, 6.6, "Deep steel scoop that hauls a heap."),
	t("pusher", "hand", "Push Shovel", 560, 60, 26, 1.45, 6.8, "Just walk and push the snow along."),
	t("twinpusher", "hand", "Wheeled Sleigh Pusher", 900, 85, 34, 1.65, 7.0, "A huge curved blade on two wheels."),
	t("sledscoop", "hand", "Sled Scoop", 1350, 120, 44, 1.85, 7.2, "Scoop, sled and slide your haul home."),
	-- 10 machines
	t("blower", "machine", "Walk-Behind Snow Blower", 2000, 175, 60, 2.0, 7.5, "Two-stage auger, chute and headlight."),
	t("tractor", "machine", "Garden Tractor Plow", 3000, 250, 80, 2.2, 9.0, "Lawn tractor with a front blade and a cart."),
	t("atv", "machine", "ATV Plow", 4400, 350, 105, 2.4, 11.0, "Four-wheeler with a winch-raised blade."),
	t("snowmobile", "machine", "Snowmobile Groomer", 6300, 500, 135, 2.6, 13.0, "Track, skis and a drag sled out back."),
	t("pickup", "machine", "Pickup Plow Truck", 9000, 700, 170, 2.9, 13.5, "V-plow, light bar and a salt spreader."),
	t("skidsteer", "machine", "Skid Steer Loader", 13000, 1000, 215, 3.1, 11.0, "Compact loader with a big snow bucket."),
	t("resurfacer", "machine", "Ice Resurfacer", 18500, 1400, 270, 3.3, 10.5, "Rink-style machine with a snow tank."),
	t("snowcat", "machine", "Snowcat", 26000, 2000, 340, 3.6, 12.0, "Twin tracks, tiller and a 12-way blade."),
	t("loader", "machine", "Wheel Loader", 37500, 2800, 430, 3.9, 12.5, "Articulated giant with a monster bucket."),
	t("rotary", "machine", "Rotary Snow Blower Truck", 52500, 4000, 550, 4.3, 14.0, "The king of clearing: dual-drum blower truck."),
}

Config.ToolIndex = {} :: { [string]: number }
for i, tool in Config.Tools do
	Config.ToolIndex[tool.id] = i
end

function Config.GetTool(id: string): Tool
	local i = Config.ToolIndex[id]
	return if i then Config.Tools[i] else Config.Tools[1]
end

-- 7 day streak (repeats). Coins = pct of your next upgrade's price, at least `min`.
Config.DailyRewards = {
	{ pct = 0.25, min = 10, spins = 0 },
	{ pct = 0.35, min = 15, spins = 1 },
	{ pct = 0.5, min = 25, spins = 0 },
	{ pct = 0.6, min = 35, spins = 1 },
	{ pct = 0.75, min = 50, spins = 1 },
	{ pct = 1.0, min = 75, spins = 2 },
	{ pct = 1.5, min = 120, spins = 3 },
}

-- Spin wheel. weight = relative chance. Coin prizes = mult x 10% of next upgrade price.
Config.Wheel = {
	{ label = "Coins", kind = "coins", mult = 1, color = "#4fa3e0", weight = 22 },
	{ label = "2x Sell", kind = "boost", boost = "sell", mins = 3, color = "#f5b83d", weight = 12 },
	{ label = "Big Coins", kind = "coins", mult = 3, color = "#2f7fc1", weight = 14 },
	{ label = "+1 Spin", kind = "spin", color = "#9b6ce0", weight = 10 },
	{ label = "Coins", kind = "coins", mult = 1, color = "#4fa3e0", weight = 22 },
	{ label = "2x Capacity", kind = "boost", boost = "capacity", mins = 3, color = "#3cc48a", weight = 10 },
	{ label = "Huge Coins", kind = "coins", mult = 8, color = "#1d5d96", weight = 6 },
	{ label = "JACKPOT", kind = "coins", mult = 25, color = "#e0505a", weight = 2 },
}

-- Hands-on tutorial for new players. Each step points an arrow at where to go.
-- Step 4's %s is replaced by the name of the next tool to buy.
Config.Tutorial = {
	Steps = {
		{ title = "Pick up snow", text = "Walk into the snow and hold click (or F) to scoop until you're full.", touchText = "Walk into the snow and hold SCOOP until you're full." },
		{ title = "Toss it on the pile", text = "Carry your snow to the Snow Pile. You toss it in when you get close." },
		{ title = "Sell it", text = "Walk up to the Snow Buyer and press E to sell your pile.", touchText = "Walk up to the Snow Buyer and tap Sell to sell your pile." },
		{ title = "Buy a new tool", text = "Go to the Tool Shop display and buy the %s." },
		{ title = "Enjoy the game!", text = "Keep clearing snow, sell it and upgrade all the way to the big machines." },
	},
	EnjoySeconds = 7, -- how long the final "Enjoy the game!" card stays up
	StarterBonus = true, -- first sale tops coins up so a new player can afford the trowel
}

-- Snowball fights: with Bare Hands equipped, press Q (or tap THROW) to throw a snowball.
-- A hit stuns the other player briefly with a stumble.
Config.Snowball = {
	Cooldown = 0.8, -- seconds between throws
	Speed = 90, -- studs per second
	Gravity = 40, -- studs per second squared (lower than world gravity for a nice arc)
	MaxFlightTime = 2.5, -- seconds before a snowball melts away
	StunSeconds = 0.5, -- how long a hit player can't move
	ImmuneSeconds = 1.0, -- after a stun ends, how long before you can be stunned again
	Radius = 0.45, -- snowball size (studs)
}

-- Christmas presents that drop from the sky. Walk into one to open it for bonus coins.
Config.Presents = {
	Interval = { 40, 80 }, -- seconds between drops (random in this range)
	PerDrop = { 2, 4 }, -- presents per drop
	MaxOnMap = 8,
	FallSpeed = 18, -- studs per second
	Lifetime = 120, -- seconds a landed present waits before vanishing
	MinCoins = 15,
	ProgressShare = 0.15, -- coins = this share of your next upgrade's price (at least MinCoins)
}

-- Timed events. Every Interval seconds one event is picked at random from the files in
-- src/server/Events (add a new file there to add an event). A timer and a progress / HP
-- bar show at the top of the screen. Everyone who helps gets a reward when it succeeds.
Config.Events = {
	Interval = 600, -- 10 minutes between events
	StudioInterval = 60, -- shorter wait when you press Play in Studio, for testing
	OnlyEvent = nil, -- e.g. "Yeti" or "SantaSled" to always run that one (handy for testing)
	RewardShare = 0.5, -- reward = this share of your next upgrade's price...
	RewardMin = 50, -- ...but at least this many coins

	SantaSled = {
		Duration = 300, -- seconds to clear the road
		Runway = { -48, 42, 48, 60 }, -- x0, z0, x1, z1 (studs): the stretch of main road to clear
		SleighPosition = Vector3.new(-62, 0, 51), -- Santa waits here and takes off along +X
		SnowPerPlayer = 6, -- snow per road tile for each player in the server (max 20)
		ClearBoost = 2, -- scooping on the runway is this much faster, and needs no space in your load
		DoneAt = 0.97, -- share of the snow that must be cleared
	},
	Yeti = {
		Duration = 240,
		HitsPerPlayer = 15, -- Yeti HP = this x players in the server
		Position = Vector3.new(60, 0, 51), -- where the Yeti appears (on the main road)
	},
}

-- Market layout (studs). The hub sits in the plaza at the centre of town.
Config.Hub = {
	Spawn = Vector3.new(0, 0, 6),
	Sell = Vector3.new(-19.2, 0, -25.8),
	Shop = Vector3.new(-7.5, 0, -25.8),
	Pile = Vector3.new(-34, 0, -15),
	PileRadius = 6,
	Wheel = Vector3.new(33.6, 0, -24.6),
	Gift = Vector3.new(33.6, 0, -9.6),
	-- tool display: 5 columns x 4 tiers, packed tight right beside the shop stall
	DisplayOrigin = Vector3.new(-0.6, 0, -28.2), -- back-left corner
	DisplayCols = 5,
	DisplayStepX = 4.35,
	DisplayStepZ = 4.5,
}

function Config.FormatNumber(n: number): string
	n = math.floor(n)
	if n >= 1e6 then
		return (string.format("%.2fM", n / 1e6):gsub("%.?0+M$", "M"))
	elseif n >= 1e4 then
		return (string.format("%.1fK", n / 1e3):gsub("%.0K$", "K"))
	end
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

return Config
