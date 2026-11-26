// Player progress, saving, daily reward and spin bookkeeping.
import { TOOLS, toolIndex, DAILY_REWARDS, WHEEL } from './data.js';

const KEY = 'clear-the-snow-save-v1';

export const state = {
  coins: 0,
  owned: ['hands'],
  equipped: 'hands',
  load: 0,
  pile: 0,
  spins: 0,            // bonus spins on top of the free daily spin
  lastFreeSpinDay: -1,
  daily: { lastDay: -1, streak: 0 },
  boosts: { sell: 0, capacity: 0 }, // expiry timestamps (ms)
  auto: false,
  totalSold: 0,
  seenHelp: false,
};

export function loadState() {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      const s = JSON.parse(raw);
      Object.assign(state, s, { daily: { ...state.daily, ...(s.daily || {}) }, boosts: { ...state.boosts, ...(s.boosts || {}) } });
      state.owned = state.owned.filter((id) => toolIndex(id) >= 0);
      if (!state.owned.includes('hands')) state.owned.unshift('hands');
      if (!state.owned.includes(state.equipped)) state.equipped = 'hands';
    }
  } catch (e) { /* storage unavailable: play without saving */ }
}

let saveTimer = 0;
export function saveState(force = false) {
  const now = performance.now();
  if (!force && now - saveTimer < 2000) return;
  saveTimer = now;
  try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) { /* ignore */ }
}

// local calendar day number
export function today() {
  const d = new Date();
  return Math.floor((d.getTime() - d.getTimezoneOffset() * 60000) / 86400000);
}
export function msUntilTomorrow() {
  const d = new Date(); const t = new Date(d); t.setHours(24, 0, 0, 0);
  return t - d;
}

export function nextTool() {
  return TOOLS.find((t) => !state.owned.includes(t.id)) || null;
}
// progress-scaled coin unit used by daily rewards and the wheel
export function progressCoins() {
  const n = nextTool();
  return n ? n.price : TOOLS[TOOLS.length - 1].price * 1.5;
}

// ---------- daily rewards
export function dailyStatus() {
  const t = today();
  const { lastDay, streak } = state.daily;
  const canClaim = lastDay < t;
  const continuing = lastDay === t - 1;
  const nextStreak = canClaim ? (continuing ? streak + 1 : 1) : streak;
  const idx = (Math.max(1, nextStreak) - 1) % 7;
  return { canClaim, idx, streak: nextStreak, broken: canClaim && !continuing && lastDay >= 0 && streak > 0 };
}
export function dailyReward(idx) {
  const r = DAILY_REWARDS[idx];
  return { coins: Math.max(r.min, Math.round(progressCoins() * r.pct)), spins: r.spins };
}
export function claimDaily() {
  const st = dailyStatus();
  if (!st.canClaim) return null;
  const rw = dailyReward(st.idx);
  state.daily = { lastDay: today(), streak: st.streak };
  state.coins += rw.coins;
  state.spins += rw.spins;
  saveState(true);
  return rw;
}

// ---------- spins
export function freeSpinAvailable() { return state.lastFreeSpinDay < today(); }
export function spinsAvailable() { return state.spins + (freeSpinAvailable() ? 1 : 0); }
export function useSpin() {
  if (freeSpinAvailable()) state.lastFreeSpinDay = today();
  else if (state.spins > 0) state.spins--;
  else return false;
  return true;
}
export function pickWheel() {
  const total = WHEEL.reduce((a, s) => a + s.weight, 0);
  let r = Math.random() * total;
  for (let i = 0; i < WHEEL.length; i++) { r -= WHEEL[i].weight; if (r <= 0) return i; }
  return 0;
}
export function wheelCoins(seg) {
  return Math.max(10, Math.round(progressCoins() * 0.1)) * seg.mult;
}
export function applyWheel(i) {
  const seg = WHEEL[i];
  let text = '';
  if (seg.type === 'coins') { const c = wheelCoins(seg); state.coins += c; text = `+${fmt(c)} coins!`; }
  else if (seg.type === 'spin') { state.spins++; text = '+1 bonus spin!'; }
  else if (seg.type === 'boost') {
    const now = Date.now();
    state.boosts[seg.boost] = Math.max(now, state.boosts[seg.boost] || 0) + seg.mins * 60000;
    text = seg.boost === 'sell' ? `2x sell price for ${seg.mins} min!` : `2x capacity for ${seg.mins} min!`;
  }
  saveState(true);
  return text;
}
export function boostActive(name) { return (state.boosts[name] || 0) > Date.now(); }

export function fmt(n) {
  n = Math.floor(n);
  if (n >= 1e6) return (n / 1e6).toFixed(n >= 1e7 ? 1 : 2).replace(/\.0+$/, '') + 'M';
  if (n >= 1e4) return (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'K';
  return n.toLocaleString();
}
