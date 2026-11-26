# Clear the Snow ❄

A cozy 3D snow-clearing harvest game that runs in the browser (Three.js, no build step).

The neighbourhood is buried in snow that slowly grows back. Scoop it up, toss it on the
**Snow Pile**, sell the pile to the **Snow Buyer**, and spend your coins at the **Tool Shop**
right next door. Start with your bare hands (one snowball at a time) and work up to a
rotary snow blower truck.

## Play

Serve the folder with any static web server and open it:

```bash
python3 -m http.server 8000
# then open http://localhost:8000
```

(Opening `index.html` straight from disk won't work because browsers block ES modules on `file://`.)

**Controls:** WASD / arrows to move · hold **Space** to scoop · **R** toggles auto-scoop ·
**E** to interact · drag to rotate the camera · mouse wheel to zoom. On touch screens there's a
joystick plus Scoop / Use buttons.

## Features

- **Regrowing snow**: a 120 × 120 m heightfield over roads, yards and driveways. Cleared tiles
  pause briefly, then grow back over about 40 seconds.
- **20 tools, each with its own carry capacity**:
  - 10 hand tools: Bare Hands (1) → Garden Trowel → Kid's Plastic Shovel → Snow Shovel → Big
    Shovel → Mega Shovel → Steel Grain Scoop → Push Shovel → Wheeled Sleigh Pusher → Sled Scoop (120)
  - 10 machines: Walk-Behind Snow Blower (175) → Garden Tractor Plow → ATV Plow → Snowmobile
    Groomer → Pickup Plow Truck → Skid Steer Loader → Ice Resurfacer → Snowcat → Wheel Loader →
    Rotary Snow Blower Truck (4,000)
  - Machines are detailed procedural 3D models with spinning wheels and augers, moving crawler
    tracks, plows, buckets, cabs, light bars and beacons. Your load is shown as a snow heap in
    the bucket, bed or hopper.
- **Market plaza**: the Snow Pile, the Snow Buyer stall and the Tool Shop stall sit side by side.
  All 20 tools are shown on a tight four-tier display right beside the shop vendor. Click one
  to open it in the shopping list. Tools unlock in order.
- **Daily rewards**: a 7-day streak calendar. Coins scale with your next upgrade, and some days
  add bonus spins. Missing a day resets the streak.
- **Lucky Spin**: one free spin per day, plus bonus spins. Prizes are coins, a 2x sell boost,
  a 2x capacity boost, an extra spin, or the jackpot.
- Progress saves automatically in `localStorage`.

## Code layout

| File | What it does |
| --- | --- |
| `src/data.js` | Tool stats and prices, daily reward table, wheel segments |
| `src/models.js` | Procedural models: character, hand tools, machines, stalls, labels, mesh baking |
| `src/snow.js` | Harvestable, regrowing snow heightfield |
| `src/world.js` | Neighbourhood: roads, houses, trees, lamps, fence |
| `src/state.js` | Save data, daily reward and spin logic |
| `src/ui.js` | HUD, shop, daily rewards and spin wheel panels |
| `src/main.js` | Scene, market hub, player, input, game loop |

`vendor/` contains Three.js r169 (MIT).
