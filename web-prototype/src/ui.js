// DOM user interface: HUD, tool shop, daily rewards, spin wheel.
import * as THREE from 'three';
import { TOOLS, toolById, toolIndex, WHEEL, DAILY_REWARDS } from './data.js';
import {
  state, saveState, fmt, dailyStatus, dailyReward, claimDaily, msUntilTomorrow,
  freeSpinAvailable, spinsAvailable, useSpin, pickWheel, applyWheel, wheelCoins, boostActive,
} from './state.js';

const $ = (id) => document.getElementById(id);
let api, thumbs;
let shopTab = 'hand';
let spinning = false;
let wheelAngle = 0;

export const ui = {
  modalOpen: () => !!document.querySelector('.panel:not(.hidden)'),
  spinning: () => spinning,
  open(name) {
    ui.closeAll();
    $(name).classList.remove('hidden');
  },
  closeAll() {
    if (spinning) return;
    document.querySelectorAll('.panel').forEach((p) => p.classList.add('hidden'));
  },
  toast(msg, ms = 2200) {
    const t = $('toast');
    t.innerHTML = msg; t.classList.remove('hidden');
    clearTimeout(ui._tt); ui._tt = setTimeout(() => t.classList.add('hidden'), ms);
  },
  floater(text, at) {
    const f = document.createElement('div');
    f.className = 'floater'; f.textContent = text;
    f.style.left = at.x + 'px'; f.style.top = at.y + 'px';
    $('floaters').appendChild(f);
    setTimeout(() => f.remove(), 1400);
  },
  prompt(html) {
    const p = $('prompt');
    if (!html) { p.classList.add('hidden'); return; }
    p.innerHTML = html; p.classList.remove('hidden');
  },
  update() {
    const tool = toolById(state.equipped);
    const cap = api.capacity();
    $('coins').textContent = fmt(state.coins);
    $('pile').textContent = fmt(state.pile);
    $('tool-name').textContent = `${tool.kind === 'machine' ? '🚜' : '🧤'} ${tool.name}`;
    const fill = Math.min(1, state.load / cap);
    $('load-fill').style.width = fill * 100 + '%';
    $('load-fill').classList.toggle('full', fill >= 0.999);
    $('load-text').textContent = `${fmt(Math.floor(state.load + 1e-6))} / ${fmt(cap)} snow`;
    $('auto-state').textContent = state.auto ? 'ON' : 'OFF';
    $('auto-ind').classList.toggle('hidden', api.isTouch && !state.auto);
    const ds = dailyStatus();
    $('daily-badge').classList.toggle('off', !ds.canClaim);
    const sp = spinsAvailable();
    $('spin-badge').textContent = sp;
    $('spin-badge').classList.toggle('off', sp === 0);
    // boosts
    const now = Date.now();
    const b = [];
    for (const [k, label] of [['sell', '💰 2x Sell'], ['capacity', '❄ 2x Capacity']]) {
      const left = (state.boosts[k] || 0) - now;
      if (left > 0) b.push(`<div class="boost ${k}">${label} ${Math.floor(left / 60000)}:${String(Math.floor(left / 1000) % 60).padStart(2, '0')}</div>`);
    }
    const html = b.join('');
    if ($('boosts').innerHTML !== html) $('boosts').innerHTML = html;
    if (!$('daily').classList.contains('hidden')) renderDailyNext();
  },
  openShop(focusId) {
    if (focusId) shopTab = toolById(focusId).kind;
    renderShop(focusId);
    ui.open('shop');
  },
  openDaily() { renderDaily(); ui.open('daily'); },
  openSpin() { renderSpinInfo(); ui.open('spin'); },
};

// ---------------------------------------------------------------- shop
function renderShop(focusId) {
  document.querySelectorAll('.tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === shopTab));
  const list = $('shop-list');
  list.innerHTML = '';
  TOOLS.forEach((t, i) => {
    if (t.kind !== shopTab) return;
    const owned = state.owned.includes(t.id);
    const prevOwned = i === 0 || state.owned.includes(TOOLS[i - 1].id);
    const card = document.createElement('div');
    card.className = 'card' + (!owned && !prevOwned ? ' locked' : '') + (t.id === focusId ? ' focus' : '');
    card.id = 'card-' + t.id;
    card.innerHTML = `
      <img src="${thumbs[t.id]}" alt="${t.name}" />
      <div class="nm">${i + 1}. ${t.name}</div>
      <div class="ds">${t.desc}</div>
      <div class="stats"><span>Carries <b>${fmt(t.capacity)}</b></span><span>Width <b>${(t.radius * 2).toFixed(1)}m</b></span></div>
      <div class="stats"><span>Scoop <b>${t.rate}/s</b></span><span>Speed <b>${t.speed}</b></span></div>`;
    const btn = document.createElement('button');
    if (state.equipped === t.id) { btn.textContent = '✔ Equipped'; btn.disabled = true; }
    else if (owned) { btn.textContent = 'Equip'; btn.className = 'equip'; btn.onclick = () => { api.equip(t.id); renderShop(); }; }
    else if (!prevOwned) { btn.textContent = `🔒 Buy ${TOOLS[i - 1].name} first`; btn.disabled = true; }
    else {
      btn.textContent = `Buy 🪙 ${fmt(t.price)}`;
      btn.disabled = state.coins < t.price;
      btn.onclick = () => {
        if (state.coins < t.price) return;
        state.coins -= t.price;
        state.owned.push(t.id);
        api.equip(t.id);
        saveState(true);
        ui.toast(`🎉 You got the ${t.name}!<br><small>Carries ${fmt(t.capacity)} snow</small>`);
        renderShop(t.id);
      };
    }
    card.appendChild(btn);
    list.appendChild(card);
  });
  if (focusId) requestAnimationFrame(() => $('card-' + focusId)?.scrollIntoView({ block: 'nearest', behavior: 'smooth' }));
}

// ---------------------------------------------------------------- daily
function renderDaily() {
  const st = dailyStatus();
  const grid = $('daily-grid');
  grid.innerHTML = '';
  DAILY_REWARDS.forEach((r, i) => {
    const rw = dailyReward(i);
    const d = document.createElement('div');
    const done = st.canClaim ? i < st.idx : i <= st.idx;
    d.className = 'day' + (done ? ' done' : '') + (st.canClaim && i === st.idx ? ' today' : '');
    d.innerHTML = `<b>Day ${i + 1}</b><div class="rw">🪙 ${fmt(rw.coins)}</div>${rw.spins ? `<div class="rw">🎡 +${rw.spins}</div>` : ''}${done ? '<div>✔</div>' : ''}`;
    grid.appendChild(d);
  });
  const btn = $('daily-claim');
  btn.disabled = !st.canClaim;
  btn.textContent = st.canClaim ? `Claim Day ${st.idx + 1}` : 'Claimed today ✔';
  renderDailyNext();
}
function renderDailyNext() {
  const st = dailyStatus();
  const ms = msUntilTomorrow();
  const h = Math.floor(ms / 3600000), m = Math.floor(ms / 60000) % 60;
  $('daily-next').textContent = st.canClaim
    ? (st.broken ? 'Your streak reset. Start again today!' : `Current streak: ${st.streak - 1} day${st.streak - 1 === 1 ? '' : 's'}`)
    : `Streak: ${state.daily.streak} day${state.daily.streak === 1 ? '' : 's'} · next reward in ${h}h ${m}m`;
}

// ---------------------------------------------------------------- spin wheel
const SEG = (Math.PI * 2) / WHEEL.length;
function drawWheel(ctx, size) {
  const r = size / 2;
  ctx.clearRect(0, 0, size, size);
  ctx.save(); ctx.translate(r, r);
  WHEEL.forEach((s, i) => {
    const a0 = -Math.PI / 2 + i * SEG - SEG / 2;
    ctx.beginPath(); ctx.moveTo(0, 0); ctx.arc(0, 0, r - 8, a0, a0 + SEG); ctx.closePath();
    ctx.fillStyle = s.color; ctx.fill();
    ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 3; ctx.stroke();
    ctx.save();
    ctx.rotate(a0 + SEG / 2);
    ctx.fillStyle = '#ffffff'; ctx.font = `bold ${Math.round(size / 24)}px system-ui, sans-serif`;
    ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
    ctx.shadowColor = 'rgba(0,0,0,.5)'; ctx.shadowBlur = 4;
    ctx.fillText(s.label, r - 22, 0);
    ctx.restore();
  });
  ctx.beginPath(); ctx.arc(0, 0, r - 6, 0, Math.PI * 2); ctx.lineWidth = 10; ctx.strokeStyle = '#ffd54f'; ctx.stroke();
  for (let i = 0; i < WHEEL.length; i++) {
    const a = -Math.PI / 2 + i * SEG - SEG / 2;
    ctx.beginPath(); ctx.arc(Math.cos(a) * (r - 6), Math.sin(a) * (r - 6), 6, 0, Math.PI * 2); ctx.fillStyle = '#fff'; ctx.fill();
  }
  ctx.beginPath(); ctx.arc(0, 0, size / 12, 0, Math.PI * 2); ctx.fillStyle = '#ffd54f'; ctx.fill();
  ctx.fillStyle = '#0f1e37'; ctx.font = `bold ${Math.round(size / 28)}px system-ui`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.fillText('SPIN', 0, 1);
  ctx.restore();
}
function renderSpinInfo() {
  const n = spinsAvailable();
  $('spin-go').disabled = spinning || n === 0;
  $('spin-go').textContent = freeSpinAvailable() ? 'Free Spin!' : n > 0 ? `Spin! (${n} left)` : 'No spins left';
  const coins = WHEEL.filter((s) => s.type === 'coins').map((s) => wheelCoins(s));
  $('spin-info').innerHTML = n === 0
    ? `Free spin resets in ${Math.ceil(msUntilTomorrow() / 3600000)}h. Daily rewards give bonus spins.`
    : `Coin prizes right now: 🪙 ${fmt(Math.min(...coins))} up to ${fmt(Math.max(...coins))}`;
}
function doSpin() {
  if (spinning || !useSpin()) return;
  spinning = true;
  renderSpinInfo();
  const i = pickWheel();
  const el = $('wheel');
  const start = wheelAngle;
  const want = -i * SEG + (Math.random() - 0.5) * SEG * 0.7;
  let delta = ((want - start) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2);
  const end = start + Math.PI * 2 * 6 + delta;
  const t0 = performance.now(), dur = 4200;
  const step = (now) => {
    const k = Math.min(1, (now - t0) / dur);
    const e = 1 - Math.pow(1 - k, 4);
    wheelAngle = start + (end - start) * e;
    el.style.transform = `rotate(${wheelAngle}rad)`;
    if (k < 1) requestAnimationFrame(step);
    else {
      spinning = false;
      wheelAngle %= Math.PI * 2;
      const msg = applyWheel(i);
      ui.toast(`🎡 ${WHEEL[i].label}<br>${msg}`, 2800);
      renderSpinInfo();
      ui.update();
    }
  };
  requestAnimationFrame(step);
}

// ---------------------------------------------------------------- init
export function initUI(gameApi, thumbImages) {
  api = gameApi; thumbs = thumbImages;
  const wc = $('wheel');
  drawWheel(wc.getContext('2d'), wc.width);
  // same artwork on the 3D wheel in the plaza
  const c3 = document.createElement('canvas'); c3.width = c3.height = 512;
  drawWheel(c3.getContext('2d'), 512);
  const tex = new THREE.CanvasTexture(c3); tex.colorSpace = THREE.SRGBColorSpace;
  api.onWheelTexture(tex);

  document.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', () => ui.closeAll()));
  document.querySelectorAll('.tab').forEach((b) => b.addEventListener('click', () => { shopTab = b.dataset.tab; renderShop(); }));
  $('btn-shop').onclick = () => ui.openShop();
  $('btn-daily').onclick = () => ui.openDaily();
  $('btn-spin').onclick = () => ui.openSpin();
  $('btn-help').onclick = () => ui.open('help');
  $('spin-go').onclick = doSpin;
  $('daily-claim').onclick = () => {
    const rw = claimDaily();
    if (!rw) return;
    ui.toast(`🎁 +${fmt(rw.coins)} coins${rw.spins ? ` and +${rw.spins} spin${rw.spins > 1 ? 's' : ''}` : ''}!`);
    renderDaily();
    ui.update();
  };
  // click outside panel closes it
  document.addEventListener('pointerdown', (e) => {
    if (!ui.modalOpen() || spinning) return;
    if (!e.target.closest('.panel') && !e.target.closest('#hud-side')) ui.closeAll();
  });
}
