// Game balance data: tools, machines, daily rewards and spin wheel.
// capacity = snow units carried per trip, rate = units scooped per second,
// radius = how wide (metres) the tool clears, speed = walk / drive speed.

export const TOOLS = [
  // ---- 10 hand tools ----
  { id: 'hands',      kind: 'hand',    name: 'Bare Hands',         price: 0,       capacity: 1,    rate: 1.5, radius: 0.55, speed: 6.0, desc: 'Pack a snowball. Cold fingers, tiny loads.' },
  { id: 'trowel',     kind: 'hand',    name: 'Garden Trowel',      price: 10,      capacity: 3,    rate: 3,   radius: 0.6,  speed: 6.0, desc: 'Borrowed from the flower bed.' },
  { id: 'kidshovel',  kind: 'hand',    name: "Kid's Plastic Shovel", price: 30,    capacity: 6,    rate: 5,   radius: 0.7,  speed: 6.2, desc: 'Bright red and surprisingly sturdy.' },
  { id: 'shovel',     kind: 'hand',    name: 'Snow Shovel',        price: 65,     capacity: 10,   rate: 7,   radius: 0.8,  speed: 6.2, desc: 'The classic. Lift with your legs.' },
  { id: 'bigshovel',  kind: 'hand',    name: 'Big Shovel',         price: 120,     capacity: 16,   rate: 10,  radius: 0.95, speed: 6.4, desc: 'A wider blade for wider driveways.' },
  { id: 'megashovel', kind: 'hand',    name: 'Mega Shovel',        price: 200,    capacity: 25,   rate: 14,  radius: 1.1,  speed: 6.4, desc: 'Even bigger. Your back is worried.' },
  { id: 'steelshovel',kind: 'hand',    name: 'Steel Grain Scoop',  price: 340,    capacity: 40,   rate: 19,  radius: 1.25, speed: 6.6, desc: 'Deep steel scoop that hauls a heap.' },
  { id: 'pusher',     kind: 'hand',    name: 'Push Shovel',        price: 560,    capacity: 60,   rate: 26,  radius: 1.45, speed: 6.8, desc: 'Just walk and push the snow along.' },
  { id: 'twinpusher', kind: 'hand',    name: 'Wheeled Sleigh Pusher', price: 900, capacity: 85,   rate: 34,  radius: 1.65, speed: 7.0, desc: 'A huge curved blade on two wheels.' },
  { id: 'sledscoop',  kind: 'hand',    name: 'Sled Scoop',         price: 1350,   capacity: 120,  rate: 44,  radius: 1.85, speed: 7.2, desc: 'Scoop, sled and slide your haul home.' },
  // ---- 10 machines ----
  { id: 'blower',     kind: 'machine', name: 'Walk-Behind Snow Blower', price: 2000,   capacity: 175,  rate: 60,  radius: 2.0, speed: 7.5,  desc: 'Two-stage auger, chute and headlight.' },
  { id: 'tractor',    kind: 'machine', name: 'Garden Tractor Plow',     price: 3000,   capacity: 250,  rate: 80,  radius: 2.2, speed: 9.0,  desc: 'Lawn tractor with a front blade and chains.' },
  { id: 'atv',        kind: 'machine', name: 'ATV Plow',               price: 4400,   capacity: 350,  rate: 105, radius: 2.4, speed: 11.0, desc: 'Four-wheeler with a winch-raised blade.' },
  { id: 'snowmobile', kind: 'machine', name: 'Snowmobile Groomer',     price: 6300,  capacity: 500,  rate: 135, radius: 2.6, speed: 13.0, desc: 'Track, skis and a drag sled out back.' },
  { id: 'pickup',     kind: 'machine', name: 'Pickup Plow Truck',      price: 9000,  capacity: 700,  rate: 170, radius: 2.9, speed: 13.5, desc: 'V-plow, light bar and a salt spreader.' },
  { id: 'skidsteer',  kind: 'machine', name: 'Skid Steer Loader',      price: 13000,  capacity: 1000, rate: 215, radius: 3.1, speed: 11.0, desc: 'Compact loader with a big snow bucket.' },
  { id: 'resurfacer', kind: 'machine', name: 'Ice Resurfacer',         price: 18500,  capacity: 1400, rate: 270, radius: 3.3, speed: 10.5, desc: 'Rink-style machine with a snow tank.' },
  { id: 'snowcat',    kind: 'machine', name: 'Snowcat',                price: 26000,  capacity: 2000, rate: 340, radius: 3.6, speed: 12.0, desc: 'Twin tracks, tiller and a 12-way blade.' },
  { id: 'loader',     kind: 'machine', name: 'Wheel Loader',           price: 37500,  capacity: 2800, rate: 430, radius: 3.9, speed: 12.5, desc: 'Articulated giant with a monster bucket.' },
  { id: 'rotary',     kind: 'machine', name: 'Rotary Snow Blower Truck', price: 52500, capacity: 4000, rate: 550, radius: 4.3, speed: 14.0, desc: 'The king of clearing: dual-drum blower truck.' },
];

export const toolIndex = (id) => TOOLS.findIndex((t) => t.id === id);
export const toolById = (id) => TOOLS[toolIndex(id)] || TOOLS[0];

export const SNOW_VALUE = 1; // coins per unit of snow sold

// 7 day streak calendar (repeats after day 7). Coins scale with progress:
// `pct` of the price of your next tool upgrade (at least `min`).
export const DAILY_REWARDS = [
  { pct: 0.25, min: 10,  spins: 0 },
  { pct: 0.35, min: 15,  spins: 1 },
  { pct: 0.5,  min: 25,  spins: 0 },
  { pct: 0.6,  min: 35,  spins: 1 },
  { pct: 0.75, min: 50,  spins: 1 },
  { pct: 1.0,  min: 75,  spins: 2 },
  { pct: 1.5,  min: 120, spins: 3 },
];

// Spin wheel segments. weight = relative chance.
// type: coins (scaled by progress), boost (timed multiplier), spin (extra spin)
export const WHEEL = [
  { label: 'Coins',        type: 'coins', mult: 1,   color: '#4fa3e0', weight: 22 },
  { label: '2x Sell 3m',   type: 'boost', boost: 'sell',     mins: 3, color: '#f5b83d', weight: 12 },
  { label: 'Big Coins',    type: 'coins', mult: 3,   color: '#2f7fc1', weight: 14 },
  { label: '+1 Spin',      type: 'spin',             color: '#9b6ce0', weight: 10 },
  { label: 'Coins',        type: 'coins', mult: 1,   color: '#4fa3e0', weight: 22 },
  { label: '2x Capacity',  type: 'boost', boost: 'capacity', mins: 3, color: '#3cc48a', weight: 10 },
  { label: 'Huge Coins',   type: 'coins', mult: 8,   color: '#1d5d96', weight: 6 },
  { label: 'JACKPOT',      type: 'coins', mult: 25,  color: '#e0505a', weight: 2 },
];
