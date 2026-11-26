# Clear the Snow ❄ (Roblox)

A snow-clearing harvest game for Roblox. The neighbourhood is buried in snow that slowly
grows back. Scoop it up, toss it on the **Snow Pile**, sell the pile to the **Snow Buyer**,
and spend your coins at the **Tool Shop** right next door. Start with your bare hands (one
snowball at a time) and work up to a rotary snow blower truck.

Everything (town, market, tools and machines) is built from parts in code, so there are no
assets to upload.

## Open it in Roblox Studio

**Quickest:** open `ClearTheSnow.rbxlx` (built with `rojo build`) in Roblox Studio and press Play.

**With Rojo (for editing the code):**

1. Install [Rojo](https://rojo.space) 7.x and the Rojo Studio plugin.
2. In this folder run `rojo serve`.
3. In Studio, open a new Baseplate, click **Rojo → Connect**, then press Play.

To rebuild the place file: `rojo build -o ClearTheSnow.rbxlx`.

**Saving progress:** publish the place, then turn on *Game Settings → Security → Enable Studio
Access to API Services* to test DataStores in Studio. Without it the game runs but doesn't save.

## How to play

- Walk into the snow and **hold left click** (or **F**) to scoop. On mobile, hold **SCOOP**.
- **R** or the side button toggles auto-scoop. Machines scoop automatically while driving.
- Walk up to the Snow Pile to toss your load in, then use the Snow Buyer's prompt (**E**) to sell.
- Walk up to the tool display and press **E**, or click a tool, to open it in the shopping list.

## Features

- **Regrowing snow:** 60 × 60 tiles of Snow-material parts cover yards, roads and driveways.
  Each tile's height follows how much snow is on it. Scooped tiles pause for 6–12 seconds,
  then grow back over about 40 seconds.
- **20 tools, each with its own carry capacity:**
  - 10 hand tools: Bare Hands (1) → Garden Trowel (3) → Kid's Plastic Shovel (6) → Snow Shovel
    (10) → Big Shovel (16) → Mega Shovel (25) → Steel Grain Scoop (40) → Push Shovel (60) →
    Wheeled Sleigh Pusher (85) → Sled Scoop (120)
  - 10 machines: Walk-Behind Snow Blower (175) → Garden Tractor Plow (250) → ATV Plow (350) →
    Snowmobile Groomer (500) → Pickup Plow Truck (700) → Skid Steer Loader (1,000) → Ice
    Resurfacer (1,400) → Snowcat (2,000) → Wheel Loader (2,800) → Rotary Snow Blower Truck (4,000)
- **Detailed machines** built from 100–400 parts each: treaded tyres with rims and lug nuts,
  crawler tracks with sprockets and road wheels, augers, curved plow blades with marker stakes,
  cabs with glass, light bars, beacons, mirrors and buckets. You sit in the seat (or walk behind
  the snow blower), and your load shows as a snow heap in the bucket, bed or hopper.
- **Market:** the Snow Pile, the Snow Buyer and the Tool Shop stand side by side. All 20 tools
  spin on a tight four-tier display right beside the shop vendor. Hand tools are on the front
  tiers and machines on the back. Tools unlock in order.
- **Daily rewards:** a 7-day streak calendar. Coins scale with your next upgrade, and some days
  add bonus spins. Missing a day resets the streak.
- **Lucky Spin:** one free spin per day, plus bonus spins. Prizes are coins, 2x sell for
  3 minutes, 2x capacity for 3 minutes, an extra spin, or the jackpot. The wheel in the plaza
  spins along with the one on screen.
- **Saving:** DataStore with retries, autosave every 90 seconds, and saving on leave and shutdown.
- The server handles all buying, selling, scooping and spinning, so the client can't give
  itself coins.

## Code layout

| Path | Where it ends up | What it does |
| --- | --- | --- |
| `src/shared/Config.luau` | ReplicatedStorage.Shared | Tool stats and prices, daily rewards, wheel, market layout |
| `src/shared/Models.luau` | ReplicatedStorage.Shared | Part-built models: tools, machines, stalls, NPCs, houses, trees, wheel |
| `src/server/Main.server.luau` | ServerScriptService.Server | Remotes, scooping loop, pile, selling, shop, daily, spin |
| `src/server/World.luau` | ServerScriptService.Server | Town, roads, houses, lighting, market hub and display |
| `src/server/SnowService.luau` | ServerScriptService.Server | Regrowing snow tiles |
| `src/server/DataService.luau` | ServerScriptService.Server | DataStore saving |
| `src/client/Client.client.luau` | StarterPlayerScripts.Client | HUD, shopping list, daily rewards, spin wheel, input, effects |

Balance numbers (prices, capacities, scoop rates, regrow time) are all in `Config.luau`.

`web-prototype/` holds the earlier browser version (Three.js) for reference.
