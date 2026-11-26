# Clear the Snow (Roblox)

A snow-clearing harvest game for Roblox. The neighbourhood is buried in snow that slowly
grows back. Scoop it up, toss it on the **Snow Pile**, sell the pile to the **Snow Buyer**,
and spend your coins at the **Tool Shop** right next door. Start with your bare hands (one
snowball at a time) and work up to a rotary snow blower truck.

Everything (town, market, tools and machines) is built from parts in code, so there are no
assets to upload.

## Open it in Roblox Studio

**Quickest:** open `ClearTheSnow.rbxlx` in Roblox Studio and press Play.

## Editing the game with Rojo

All the game's code lives in `src/` as plain `.luau` files. [Rojo](https://rojo.space) syncs
them into Studio live, so you edit in VS Code, hit save, and Studio updates.

**One-time setup**

1. Install [VS Code](https://code.visualstudio.com/).
2. Install Rojo. Either:
   - install [Rokit](https://github.com/rojo-rbx/rokit) and run `rokit install` in this folder
     (it reads `rokit.toml` and gets the right Rojo version), or
   - install the **Rojo** VS Code extension, which can install Rojo for you.
3. Install the Rojo plugin in Studio: run `rojo plugin install`, or get "Rojo" from the
   Creator Store plugins.
4. Open this folder in VS Code and accept the recommended extensions (Rojo and Luau LSP).
   Luau LSP gives you autocomplete for the Roblox API.

**Every time you work on it**

1. In this folder run `rojo serve` (or in VS Code: Rojo, then *Start server*).
2. In Studio open `ClearTheSnow.rbxlx` (or a new Baseplate), then click **Rojo, Connect**.
3. Edit any file in `src/` and save. Studio updates right away. Press Play to test.

To make a fresh place file: `rojo build -o ClearTheSnow.rbxlx`.

Rojo only manages `ReplicatedStorage.Shared`, `ServerScriptService.Server` and
`StarterPlayerScripts.Client`. Anything you build by hand in Studio's Workspace (extra
buildings, decorations, terrain) is left alone, so you can mix code and hand-built parts.
Save the place in Studio to keep those.

**Where to change things**

| I want to change... | Edit |
| --- | --- |
| Tool prices, capacity, speed, names | `src/shared/Config.luau` (`Config.Tools`) |
| Snow regrowth speed, sell price | `src/shared/Config.luau` (top of file) |
| Daily rewards, spin wheel prizes and odds | `src/shared/Config.luau` |
| Tutorial steps and text | `src/shared/Config.luau` (`Config.Tutorial`) |
| Where the market, pile, shop and wheel stand | `src/shared/Config.luau` (`Config.Hub`) |
| UI colours and fonts | `src/client/UI/Theme.luau` |
| A tool's or machine's 3D model | `src/shared/Models.luau` |
| The town layout | `src/server/World.luau` |

**Saving progress:** publish the place, then turn on *Game Settings, Security, Enable Studio
Access to API Services* to test DataStores in Studio. Without it the game runs but doesn't save.

## How to play

- Walk into the snow and **hold left click** (or **F**) to scoop. On mobile, hold **SCOOP**.
- **R** or the side button toggles auto-scoop. Machines scoop automatically while driving.
- Walk up to the Snow Pile to toss your load in, then use the Snow Buyer's prompt (**E**) to sell.
- Walk up to the tool display and press **E**, or click a tool, to open it in the shopping list.
- New players get a hands-on tutorial: pick up snow, toss it on the pile, sell it, buy a new
  tool. An arrow and a line on the ground show where to go. **Help, Replay tutorial** runs it again.

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
| `src/shared/Config.luau` | ReplicatedStorage.Shared | All the numbers and text: tools, rewards, wheel, tutorial, layout |
| `src/shared/Models.luau` | ReplicatedStorage.Shared | Part-built models: tools, machines, stalls, NPCs, houses, trees, wheel |
| `src/server/Main.server.luau` | ServerScriptService.Server | Remotes, scooping, held tools, pile, selling, shop, daily, spin, tutorial steps |
| `src/server/World.luau` | ServerScriptService.Server | Town, roads, houses, lighting, market hub and display |
| `src/server/SnowService.luau` | ServerScriptService.Server | Regrowing snow tiles |
| `src/server/DataService.luau` | ServerScriptService.Server | DataStore saving |
| `src/client/Client.client.luau` | StarterPlayerScripts.Client | Starts the UI, input, server messages |
| `src/client/UI/Theme.luau` | ...Client.UI | Colours, fonts, drawn coin and arrow icons |
| `src/client/UI/Panels.luau` | ...Client.UI | The ScreenGui and pop-up window frame |
| `src/client/UI/Hud.luau` | ...Client.UI | Coins, pile, load bar, side buttons, toasts |
| `src/client/UI/ShopPanel.luau` | ...Client.UI | Shopping list |
| `src/client/UI/DailyPanel.luau` | ...Client.UI | Daily rewards |
| `src/client/UI/SpinPanel.luau` | ...Client.UI | Lucky Spin wheel |
| `src/client/UI/HelpPanel.luau` | ...Client.UI | How to play, replay tutorial |
| `src/client/Tutorial.luau` | ...Client | Step card, world arrow, ground line, screen-edge arrow |
| `src/client/WorldEffects.luau` | ...Client | Pile mound, snowfall, display labels and turntables |

The UI uses no emoji or special characters, because Roblox fonts show those as empty boxes.
Icons are drawn from frames in `Theme.luau`.

`web-prototype/` holds the earlier browser version (Three.js) for reference.
