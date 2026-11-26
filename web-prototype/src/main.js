import * as THREE from 'three';
import { TOOLS, toolById, toolIndex, SNOW_VALUE } from './data.js';
import { buildCharacter, buildHandTool, buildMachine, buildStall, makeLabel, mat, box, cyl, bake } from './models.js';
import { SnowField } from './snow.js';
import { buildWorld, HALF, PLAZA } from './world.js';
import { state, loadState, saveState, boostActive, fmt } from './state.js';
import { initUI, ui } from './ui.js';

// ------------------------------------------------------------------ renderer / scene
const canvas = document.getElementById('game');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;

const scene = new THREE.Scene();
scene.background = new THREE.Color('#b9d0e8');
scene.fog = new THREE.Fog('#c6d8ec', 45, 175);
const camera = new THREE.PerspectiveCamera(55, 1, 0.1, 500);

scene.add(new THREE.HemisphereLight('#eef5ff', '#7d8ea6', 1.4));
const sun = new THREE.DirectionalLight('#fff2dc', 2.3);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -32, right: 32, top: 32, bottom: -32, near: 1, far: 140 });
sun.shadow.bias = -0.0005;
sun.shadow.normalBias = 0.03;
scene.add(sun, sun.target);

loadState();

// ------------------------------------------------------------------ world
const snow = new SnowField({ size: 120, tile: 1, maxUnits: 6, unitHeight: 0.07, regrowSeconds: 40 });
scene.add(snow.mesh);
const { colliders } = buildWorld(scene, snow);

// ------------------------------------------------------------------ market hub
const HUB = {
  sell: new THREE.Vector3(-6.4, 0, -8.6),
  shop: new THREE.Vector3(-2.5, 0, -8.6),
  pile: new THREE.Vector3(-11.4, 0, -5.0),
  wheel: new THREE.Vector3(11.2, 0, -8.2),
  gift: new THREE.Vector3(11.2, 0, -3.2),
};
const hubStatic = new THREE.Group();

function addStall(pos, opts, vendorOpts) {
  const s = buildStall(opts);
  s.position.copy(pos);
  hubStatic.add(s);
  const v = buildCharacter(vendorOpts);
  v.position.set(pos.x, 0, pos.z + 0.15);
  scene.add(v);
  colliders.push({ x0: pos.x - opts.width / 2, z0: pos.z - 0.6, x1: pos.x + opts.width / 2, z1: pos.z + 1.05 });
  return v;
}
const sellVendor = addStall(HUB.sell, { color: '#1e88e5', stripe: '#e3f2fd', sign: 'SNOW BUYER', width: 3.4 }, { coat: '#1565c0', hat: '#f9a825', scarf: '#e3f2fd' });
const shopVendor = addStall(HUB.shop, { color: '#c62828', stripe: '#fff8e1', sign: 'TOOL SHOP', width: 3.4 }, { coat: '#6d4c41', hat: '#c62828', scarf: '#43a047' });
// crates of coins on the buyer's counter, tools leaning on the shop counter
for (let i = 0; i < 3; i++) cyl(0.12, 0.12, 0.05 + i * 0.04, mat('#ffca28', { metalness: 0.8, roughness: 0.3 }), HUB.sell.x - 1.0 + i * 0.3, 1.1 + i * 0.02, HUB.sell.z + 0.6, hubStatic, 14);
const shopSign = makeLabel('TOOL SHOP', 'Shopping list inside!');
shopSign.position.set(HUB.shop.x, 4.4, HUB.shop.z); scene.add(shopSign);
const sellSign = makeLabel('SNOW BUYER', `${SNOW_VALUE} coin / snow`);
sellSign.position.set(HUB.sell.x, 4.4, HUB.sell.z); scene.add(sellSign);

// --- snow pile corral (where players toss their snow)
const PILE_R = 2.0;
{
  const wood = mat('#8d6e63', { roughness: 0.9 });
  const n = 18;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    if (Math.abs(a - Math.PI / 2) < 0.5) continue; // opening facing the plaza
    const p = box(0.5, 0.8, 0.12, wood, HUB.pile.x + Math.cos(a) * (PILE_R + 0.4), 0.4, HUB.pile.z + Math.sin(a) * (PILE_R + 0.4), hubStatic);
    p.rotation.y = -a + Math.PI / 2;
  }
  const sign = makeLabel('SNOW PILE', 'Toss snow here');
  sign.position.set(HUB.pile.x, 3.6, HUB.pile.z - 1.5); scene.add(sign);
}
const pileMound = new THREE.Mesh(new THREE.SphereGeometry(PILE_R, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2), mat('#f6faff', { roughness: 0.95 }));
pileMound.position.copy(HUB.pile); pileMound.castShadow = true; pileMound.receiveShadow = true;
scene.add(pileMound);
colliders.push({ x0: HUB.pile.x - PILE_R, z0: HUB.pile.z - PILE_R, x1: HUB.pile.x + PILE_R, z1: HUB.pile.z + PILE_R, round: PILE_R });
const pileArrow = new THREE.Mesh(new THREE.ConeGeometry(0.5, 1.1, 16), mat('#ffd54f', { emissive: '#ffb300', emissiveIntensity: 0.8 }));
pileArrow.rotation.x = Math.PI; scene.add(pileArrow);

// --- tool display: 20 items clustered on 4 tight tiers right beside the shop vendor
const DISPLAY = { x0: -0.2, z0: -9.4, cols: 5, sx: 1.45, sz: 1.5 };
const displays = []; // { id, group, label, pedestal, item }
{
  const stepMat = mat('#e8e2d6', { roughness: 0.8 });
  const trim = mat('#c62828');
  const width = DISPLAY.cols * DISPLAY.sx + 0.4;
  for (let r = 0; r < 4; r++) {
    const h = 0.25 + (3 - r) * 0.28; // back rows higher (r=0 back)
    const z = DISPLAY.z0 + r * DISPLAY.sz + DISPLAY.sz / 2;
    box(width, h, DISPLAY.sz, stepMat, DISPLAY.x0 + width / 2 - 0.2, h / 2, z, hubStatic);
    box(width, 0.06, 0.06, trim, DISPLAY.x0 + width / 2 - 0.2, h, z + DISPLAY.sz / 2 - 0.03, hubStatic);
  }
  const bx0 = DISPLAY.x0 - 0.2, bx1 = DISPLAY.x0 - 0.2 + width;
  colliders.push({ x0: bx0, z0: DISPLAY.z0, x1: bx1, z1: DISPLAY.z0 + 4 * DISPLAY.sz });
  const banner = makeLabel('TOOLS & MACHINES', 'Click one to inspect');
  banner.position.set((bx0 + bx1) / 2, 4.2, DISPLAY.z0 + 0.3); scene.add(banner);

  TOOLS.forEach((t, i) => {
    // rows: front two = hand tools, back two = machines
    const tierFromFront = Math.floor(i / 5);       // 0..3
    const r = 3 - tierFromFront;                    // row index from back
    const c = i % 5;
    const h = 0.25 + (3 - r) * 0.28;
    const x = DISPLAY.x0 + c * DISPLAY.sx + DISPLAY.sx / 2 - 0.2;
    const z = DISPLAY.z0 + r * DISPLAY.sz + DISPLAY.sz / 2;
    const group = new THREE.Group();
    group.position.set(x, h, z);
    scene.add(group);
    const ped = cyl(0.58, 0.62, 0.12, mat(t.kind === 'hand' ? '#90caf9' : '#ffcc80', { roughness: 0.5 }), 0, 0.06, 0, group, 24);
    ped.receiveShadow = true;
    // the model
    const model = t.kind === 'hand' ? buildHandTool(t.id) : buildMachine(t.id);
    if (t.kind === 'hand') model.rotation.x = -0.25;
    const bb = new THREE.Box3().setFromObject(model);
    const size = bb.getSize(new THREE.Vector3());
    const s = t.kind === 'hand' ? Math.min(1.25, 1.1 / Math.max(size.y, 0.3)) : 1.05 / Math.max(size.x, size.z);
    const holder = new THREE.Group();
    model.position.set(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2);
    holder.add(model); holder.scale.setScalar(s); holder.position.y = 0.12;
    const spinner = new THREE.Group(); spinner.add(holder); group.add(spinner);
    let item = holder;
    if (t.kind === 'hand') item = bake(holder); else item = bake(holder);
    spinner.remove(holder); spinner.add(item);
    const label = makeLabel(t.name, '');
    label.scale.set(1.35, 0.42, 1);
    label.position.set(0, (t.kind === 'hand' ? size.y * s : size.y * s) + 0.55, 0);
    group.add(label);
    // hit target for clicking
    const hit = new THREE.Mesh(new THREE.CylinderGeometry(0.65, 0.65, 1.6, 8), new THREE.MeshBasicMaterial({ visible: false }));
    hit.position.y = 0.8; hit.userData.toolId = t.id; group.add(hit);
    displays.push({ id: t.id, group, spinner, label, hit });
  });
}
function refreshDisplayLabels() {
  for (const d of displays) {
    const t = toolById(d.id);
    const owned = state.owned.includes(t.id);
    const sub = state.equipped === t.id ? '✔ EQUIPPED' : owned ? 'OWNED' : `🪙 ${fmt(t.price)}`;
    const nl = makeLabel(t.name.length > 18 ? t.name.slice(0, 17) + '…' : t.name, sub, owned ? '#b9f6ca' : '#ffffff');
    d.label.material.map.dispose();
    d.label.material.map = nl.material.map;
    d.label.material.needsUpdate = true;
  }
}

// --- spin wheel stand + daily gift
const wheelProp = new THREE.Group();
{
  wheelProp.position.copy(HUB.wheel);
  scene.add(wheelProp);
  const post = mat('#5d4037');
  box(0.2, 3.2, 0.2, post, -1.6, 1.6, 0, hubStatic).position.add(HUB.wheel);
  box(0.2, 3.2, 0.2, post, 1.6, 1.6, 0, hubStatic).position.add(HUB.wheel);
  box(3.6, 0.3, 1.0, post, 0, 0.15, 0, hubStatic).position.add(HUB.wheel);
  colliders.push({ x0: HUB.wheel.x - 1.8, z0: HUB.wheel.z - 0.5, x1: HUB.wheel.x + 1.8, z1: HUB.wheel.z + 0.5 });
  const sign = makeLabel('LUCKY SPIN', 'Free spin daily!');
  sign.position.set(HUB.wheel.x, 4.5, HUB.wheel.z); scene.add(sign);
}
let wheelDisc;
function makeWheelProp(tex) {
  wheelDisc = new THREE.Group();
  const rim = cyl(1.4, 1.4, 0.15, mat('#ffd54f', { metalness: 0.5, roughness: 0.4 }), 0, 0, 0, wheelDisc, 48);
  rim.rotation.x = Math.PI / 2; rim.castShadow = true;
  const face = new THREE.Mesh(new THREE.CircleGeometry(1.38, 48), new THREE.MeshStandardMaterial({ map: tex, roughness: 0.5 }));
  face.position.z = 0.08; wheelDisc.add(face);
  const holder = new THREE.Group(); holder.position.y = 1.9; holder.add(wheelDisc);
  wheelProp.add(holder);
  const pin = cyl(0.12, 0.12, 0.3, mat('#ffd54f', { metalness: 0.7 }), 0, 1.9, 0.12, wheelProp, 12); pin.rotation.x = Math.PI / 2;
  const ptr = new THREE.Mesh(new THREE.ConeGeometry(0.18, 0.4, 3), mat('#e53935')); ptr.rotation.z = Math.PI; ptr.position.set(0, 3.45, 0.12); wheelProp.add(ptr);
}
const gift = new THREE.Group();
{
  gift.position.copy(HUB.gift); scene.add(gift);
  box(1.1, 1.0, 1.1, mat('#8e24aa'), 0, 0.5, 0, gift);
  box(1.2, 0.2, 1.2, mat('#8e24aa'), 0, 1.08, 0, gift);
  box(0.2, 1.2, 1.14, mat('#ffd54f'), 0, 0.6, 0, gift);
  box(1.14, 1.2, 0.2, mat('#ffd54f'), 0, 0.6, 0, gift);
  for (const s of [-1, 1]) { const b = new THREE.Mesh(new THREE.TorusGeometry(0.2, 0.06, 8, 16), mat('#ffd54f')); b.position.set(s * 0.18, 1.32, 0); b.rotation.y = Math.PI / 2; b.rotation.x = s * 0.6; gift.add(b); }
  gift.traverse((c) => { if (c.isMesh) c.castShadow = true; });
  colliders.push({ x0: HUB.gift.x - 0.6, z0: HUB.gift.z - 0.6, x1: HUB.gift.x + 0.6, z1: HUB.gift.z + 0.6 });
  const sign = makeLabel('DAILY REWARD', '');
  sign.position.set(HUB.gift.x, 2.4, HUB.gift.z); scene.add(sign);
}
// plaza Christmas tree for flair
{
  const t = new THREE.Group();
  for (let i = 0; i < 5; i++) {
    const c = new THREE.Mesh(new THREE.ConeGeometry(2.2 - i * 0.4, 1.8, 12), mat('#2e6b3f'));
    c.position.y = 1.2 + i * 1.0; t.add(c);
  }
  cyl(0.3, 0.4, 1.0, mat('#5d4037'), 0, 0.5, 0, t, 8);
  const star = new THREE.Mesh(new THREE.OctahedronGeometry(0.35), mat('#ffd54f', { emissive: '#ffb300', emissiveIntensity: 1 })); star.position.y = 6.4; t.add(star);
  const colors = ['#e53935', '#ffd54f', '#42a5f5', '#ab47bc', '#66bb6a'];
  for (let i = 0; i < 40; i++) {
    const y = 1.0 + Math.random() * 4.6; const r = (2.3 - (y - 0.8) * 0.4) * 0.92; const a = Math.random() * 6.28;
    const c = colors[i % colors.length];
    const b = new THREE.Mesh(new THREE.SphereGeometry(0.11, 8, 6), mat(c, { emissive: c, emissiveIntensity: 0.6 })); b.position.set(Math.cos(a) * r, y, Math.sin(a) * r); t.add(b);
  }
  t.position.set(11.5, 0, 2.2);
  hubStatic.add(t);
  colliders.push({ x0: 10.7, z0: 1.4, x1: 12.3, z1: 3.0 });
}
// benches
for (const x of [-8, 6]) { const b = new THREE.Group(); box(2, 0.1, 0.6, mat('#8d6e63'), 0, 0.5, 0, b); box(2, 0.5, 0.08, mat('#8d6e63'), 0, 0.85, -0.28, b); for (const s of [-0.85, 0.85]) box(0.08, 0.5, 0.5, mat('#263238'), s, 0.25, 0, b); b.position.set(x, 0, 4.6); b.rotation.y = Math.PI; hubStatic.add(b); colliders.push({ x0: x - 1, z0: 4.3, x1: x + 1, z1: 4.9 }); }
scene.add(bake(hubStatic));

// ------------------------------------------------------------------ player
const player = {
  pos: new THREE.Vector3(0, 0, 1.5),
  heading: Math.PI,
  group: new THREE.Group(),
  char: buildCharacter(),
  tool: null,        // THREE object of current hand tool / machine
  isMachine: false,
  radius: 0.4,
  front: 0.8,
  moving: false,
  scooping: false,
  anim: 0,
  speedNow: 0,
};
player.group.add(player.char);
scene.add(player.group);
let digSwing = 0;

function capacity() { return toolById(state.equipped).capacity * (boostActive('capacity') ? 2 : 1); }

function equip(id) {
  const t = toolById(id);
  state.equipped = t.id;
  if (player.tool) player.tool.parent.remove(player.tool);
  const ch = player.char, ud = ch.userData;
  ud.legs.forEach((l) => l.rotation.set(0, 0, 0));
  ud.arms.forEach((a) => a.arm.rotation.set(0, 0, 0));
  ch.position.set(0, 0, 0);
  if (t.kind === 'hand') {
    player.isMachine = false;
    const tool = buildHandTool(t.id);
    const bb = new THREE.Box3().setFromObject(tool);
    const len = -bb.min.y;
    // tilt so the blade reaches the ground in front of the player
    const handY = 0.95;
    tool.userData.tilt = len > 0.4 ? Math.acos(Math.min(0.99, (handY - 0.12) / len)) - 0.5 : 0.2;
    ud.arms[1].hand.add(tool);
    player.tool = tool;
    player.radius = 0.4;
    player.front = 0.5 + t.radius * 0.6;
  } else {
    player.isMachine = true;
    const m = buildMachine(t.id);
    player.group.add(m);
    player.tool = m;
    const seat = m.userData.seat;
    ch.position.set(seat.x, seat.y - (m.userData.standing ? 0 : 0.82), seat.z);
    if (!m.userData.standing) ud.legs.forEach((l) => (l.rotation.x = -1.45));
    ud.arms.forEach((a) => (a.arm.rotation.x = -1.0));
    const bb = new THREE.Box3().setFromObject(m);
    player.front = bb.max.z - t.radius * 0.5;
    player.radius = Math.min(2.0, Math.max(0.8, Math.min(bb.max.x - bb.min.x, bb.max.z - bb.min.z) * 0.45));
  }
  state.load = Math.min(state.load, capacity());
  refreshDisplayLabels();
  ui.update();
  saveState(true);
}

// ------------------------------------------------------------------ input
const keys = new Set();
const input = { x: 0, y: 0, scoop: false, touchScoop: false };
let cam = { yaw: 0, pitch: 0.42, dist: 9, targetDist: 9 };
addEventListener('keydown', (e) => {
  if (e.target.tagName === 'INPUT') return;
  if (ui.modalOpen() && e.code !== 'Escape') return;
  keys.add(e.code);
  if (e.code === 'Space') e.preventDefault();
  if (e.code === 'KeyE' && !e.repeat) interact();
  if (e.code === 'KeyR' && !e.repeat) { state.auto = !state.auto; ui.update(); }
});
addEventListener('keyup', (e) => keys.delete(e.code));
addEventListener('keydown', (e) => { if (e.code === 'Escape') ui.closeAll(); });
addEventListener('blur', () => keys.clear());

let drag = null;
canvas.addEventListener('pointerdown', (e) => {
  if (e.pointerType === 'touch') return;
  drag = { x: e.clientX, y: e.clientY, sx: e.clientX, sy: e.clientY, moved: false };
  canvas.setPointerCapture(e.pointerId);
});
canvas.addEventListener('pointermove', (e) => {
  if (!drag || e.pointerType === 'touch') return;
  const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
  drag.x = e.clientX; drag.y = e.clientY;
  if (Math.abs(e.clientX - drag.sx) + Math.abs(e.clientY - drag.sy) > 6) drag.moved = true;
  cam.yaw -= dx * 0.006;
  cam.pitch = THREE.MathUtils.clamp(cam.pitch + dy * 0.004, 0.08, 1.35);
});
canvas.addEventListener('pointerup', (e) => {
  if (!drag || e.pointerType === 'touch') return;
  if (!drag.moved) clickPick(e.clientX, e.clientY);
  drag = null;
});
canvas.addEventListener('wheel', (e) => {
  cam.targetDist = THREE.MathUtils.clamp(cam.targetDist + Math.sign(e.deltaY) * 1.2, 4, 40);
}, { passive: true });
canvas.addEventListener('contextmenu', (e) => e.preventDefault());

const raycaster = new THREE.Raycaster();
function clickPick(cx, cy) {
  const ndc = new THREE.Vector2((cx / innerWidth) * 2 - 1, -(cy / innerHeight) * 2 + 1);
  raycaster.setFromCamera(ndc, camera);
  const hits = raycaster.intersectObjects(displays.map((d) => d.hit), false);
  if (hits.length) { ui.openShop(hits[0].object.userData.toolId); return; }
  if (raycaster.intersectObject(wheelProp, true).length) { ui.openSpin(); return; }
  if (raycaster.intersectObject(gift, true).length) { ui.openDaily(); return; }
  if (raycaster.intersectObjects([sellVendor, shopVendor], true).length) {
    const d = raycaster.intersectObject(sellVendor, true).length ? 'sell' : 'shop';
    if (d === 'shop') ui.openShop(); else sellPile();
  }
}

// touch controls
const isTouch = matchMedia('(pointer: coarse)').matches || 'ontouchstart' in window;
if (isTouch) {
  document.getElementById('touch').classList.remove('hidden');
  const joy = document.getElementById('joy'), knob = document.getElementById('joy-knob');
  let joyId = null, camTouch = null;
  const setJoy = (t) => {
    const r = joy.getBoundingClientRect();
    let dx = t.clientX - (r.left + r.width / 2), dy = t.clientY - (r.top + r.height / 2);
    const m = Math.hypot(dx, dy), max = r.width / 2;
    if (m > max) { dx *= max / m; dy *= max / m; }
    knob.style.transform = `translate(${dx}px, ${dy}px)`;
    input.x = dx / max; input.y = -dy / max;
  };
  joy.addEventListener('touchstart', (e) => { joyId = e.changedTouches[0].identifier; setJoy(e.changedTouches[0]); e.preventDefault(); }, { passive: false });
  addEventListener('touchmove', (e) => {
    for (const t of e.changedTouches) {
      if (t.identifier === joyId) setJoy(t);
      else if (camTouch && t.identifier === camTouch.id) {
        cam.yaw -= (t.clientX - camTouch.x) * 0.008;
        cam.pitch = THREE.MathUtils.clamp(cam.pitch + (t.clientY - camTouch.y) * 0.005, 0.08, 1.35);
        camTouch.x = t.clientX; camTouch.y = t.clientY; camTouch.moved = true;
      }
    }
  }, { passive: true });
  addEventListener('touchend', (e) => {
    for (const t of e.changedTouches) {
      if (t.identifier === joyId) { joyId = null; input.x = input.y = 0; knob.style.transform = ''; }
      if (camTouch && t.identifier === camTouch.id) { if (!camTouch.moved) clickPick(t.clientX, t.clientY); camTouch = null; }
    }
  });
  canvas.addEventListener('touchstart', (e) => { const t = e.changedTouches[0]; camTouch = { id: t.identifier, x: t.clientX, y: t.clientY, moved: false }; }, { passive: true });
  const sc = document.getElementById('t-scoop');
  sc.addEventListener('touchstart', (e) => { input.touchScoop = true; e.preventDefault(); }, { passive: false });
  sc.addEventListener('touchend', () => (input.touchScoop = false));
  document.getElementById('t-act').addEventListener('touchstart', (e) => { interact(); e.preventDefault(); }, { passive: false });
}

// ------------------------------------------------------------------ interactions
function nearest() {
  const p = player.pos, reach = player.radius + 2.4;
  const d2 = (v, dz = 0) => Math.hypot(p.x - v.x, p.z - (v.z + dz));
  if (d2(HUB.sell, 1.6) < reach) return 'sell';
  if (d2(HUB.shop, 1.6) < reach) return 'shop';
  const dx = Math.max(DISPLAY.x0 - 0.2 - p.x, 0, p.x - (DISPLAY.x0 - 0.2 + DISPLAY.cols * DISPLAY.sx + 0.4));
  const dz = Math.max(DISPLAY.z0 - p.z, 0, p.z - (DISPLAY.z0 + 4 * DISPLAY.sz));
  if (Math.hypot(dx, dz) < player.radius + 1.6) return 'display';
  if (d2(HUB.wheel, 0.5) < reach) return 'wheel';
  if (d2(HUB.gift) < reach) return 'gift';
  return null;
}
function interact() {
  if (ui.modalOpen()) return;
  switch (nearest()) {
    case 'sell': sellPile(); break;
    case 'shop': ui.openShop(); break;
    case 'display': {
      // focus the closest machine/tool column
      let best = null, bd = 1e9;
      for (const d of displays) { const wp = d.group.position; const dd = Math.hypot(wp.x - player.pos.x, wp.z - player.pos.z); if (dd < bd) { bd = dd; best = d; } }
      ui.openShop(best?.id);
      break;
    }
    case 'wheel': ui.openSpin(); break;
    case 'gift': ui.openDaily(); break;
  }
}
function sellPile() {
  if (state.pile < 1) { ui.toast(state.load > 0 ? 'Toss your snow on the pile first!' : 'The pile is empty. Go clear some snow!'); return; }
  const mult = boostActive('sell') ? 2 : 1;
  const coins = Math.floor(state.pile) * SNOW_VALUE * mult;
  state.coins += coins;
  state.totalSold += Math.floor(state.pile);
  state.pile = 0;
  ui.floater(`+${fmt(coins)} 🪙`, worldToScreen(sellVendor.position.clone().add(new THREE.Vector3(0, 2.4, 0))));
  sellVendor.userData.cheer = 1;
  ui.update();
  saveState(true);
}

// ------------------------------------------------------------------ effects
const flyBalls = [];
const ballGeo = new THREE.SphereGeometry(0.18, 10, 8);
function tossToPile(units) {
  const n = Math.min(8, 1 + Math.floor(Math.log2(1 + units)));
  for (let i = 0; i < n; i++) {
    const m = new THREE.Mesh(ballGeo, mat('#ffffff'));
    const from = player.pos.clone().add(new THREE.Vector3(0, player.isMachine ? 2 : 1.4, 0));
    const to = HUB.pile.clone().add(new THREE.Vector3((Math.random() - 0.5) * 1.6, 0.6 + pileHeight() * 0.8, (Math.random() - 0.5) * 1.6));
    m.position.copy(from);
    scene.add(m);
    flyBalls.push({ m, from, to, t: -i * 0.06, dur: 0.55 });
  }
}
// snow spray particles
const SPRAY = 300;
const sprayGeo = new THREE.BufferGeometry();
sprayGeo.setAttribute('position', new THREE.BufferAttribute(new Float32Array(SPRAY * 3), 3));
const sprayVel = new Float32Array(SPRAY * 3), sprayLife = new Float32Array(SPRAY);
const spray = new THREE.Points(sprayGeo, new THREE.PointsMaterial({ color: '#ffffff', size: 0.14, transparent: true, opacity: 0.9, depthWrite: false }));
spray.frustumCulled = false; scene.add(spray);
let sprayIdx = 0;
function emitSpray(x, y, z, n, power = 1) {
  const p = sprayGeo.attributes.position.array;
  for (let i = 0; i < n; i++) {
    const k = sprayIdx++ % SPRAY;
    p[k * 3] = x + (Math.random() - 0.5) * 0.6; p[k * 3 + 1] = y; p[k * 3 + 2] = z + (Math.random() - 0.5) * 0.6;
    sprayVel[k * 3] = (Math.random() - 0.5) * 3 * power; sprayVel[k * 3 + 1] = (2 + Math.random() * 3) * power; sprayVel[k * 3 + 2] = (Math.random() - 0.5) * 3 * power;
    sprayLife[k] = 0.6 + Math.random() * 0.5;
  }
}
function updateSpray(dt) {
  const p = sprayGeo.attributes.position.array;
  for (let k = 0; k < SPRAY; k++) {
    if (sprayLife[k] <= 0) { p[k * 3 + 1] = -100; continue; }
    sprayLife[k] -= dt;
    sprayVel[k * 3 + 1] -= 9.8 * dt;
    p[k * 3] += sprayVel[k * 3] * dt; p[k * 3 + 1] += sprayVel[k * 3 + 1] * dt; p[k * 3 + 2] += sprayVel[k * 3 + 2] * dt;
  }
  sprayGeo.attributes.position.needsUpdate = true;
}
// falling snow
const FLAKES = 2500;
const flakeGeo = new THREE.BufferGeometry();
const fp = new Float32Array(FLAKES * 3);
for (let i = 0; i < FLAKES; i++) { fp[i * 3] = (Math.random() - 0.5) * 80; fp[i * 3 + 1] = Math.random() * 30; fp[i * 3 + 2] = (Math.random() - 0.5) * 80; }
flakeGeo.setAttribute('position', new THREE.BufferAttribute(fp, 3));
const flakes = new THREE.Points(flakeGeo, new THREE.PointsMaterial({ color: '#ffffff', size: 0.12, transparent: true, opacity: 0.85, depthWrite: false }));
flakes.frustumCulled = false; scene.add(flakes);
function updateFlakes(dt, t) {
  const c = player.pos;
  for (let i = 0; i < FLAKES; i++) {
    let y = fp[i * 3 + 1] - dt * (1.2 + (i % 5) * 0.25);
    let x = fp[i * 3] + Math.sin(t * 0.7 + i) * dt * 0.4;
    let z = fp[i * 3 + 2];
    if (y < 0) { y += 30; }
    if (x - c.x > 40) x -= 80; if (x - c.x < -40) x += 80;
    if (z - c.z > 40) z -= 80; if (z - c.z < -40) z += 80;
    fp[i * 3] = x; fp[i * 3 + 1] = y; fp[i * 3 + 2] = z;
  }
  flakeGeo.attributes.position.needsUpdate = true;
}

function pileHeight() { return Math.min(2.6, 0.15 + Math.log10(1 + state.pile) * 0.75); }
function worldToScreen(v) {
  const p = v.clone().project(camera);
  return { x: (p.x * 0.5 + 0.5) * innerWidth, y: (-p.y * 0.5 + 0.5) * innerHeight };
}

// ------------------------------------------------------------------ movement & collisions
function collide(pos, r) {
  for (const c of colliders) {
    if (c.round) {
      const cx = (c.x0 + c.x1) / 2, cz = (c.z0 + c.z1) / 2;
      const dx = pos.x - cx, dz = pos.z - cz, d = Math.hypot(dx, dz), min = c.round + r;
      if (d < min && d > 1e-4) { pos.x = cx + (dx / d) * min; pos.z = cz + (dz / d) * min; }
      continue;
    }
    const qx = THREE.MathUtils.clamp(pos.x, c.x0, c.x1), qz = THREE.MathUtils.clamp(pos.z, c.z0, c.z1);
    const dx = pos.x - qx, dz = pos.z - qz, d2 = dx * dx + dz * dz;
    if (d2 < r * r) {
      if (d2 > 1e-8) { const d = Math.sqrt(d2); pos.x = qx + (dx / d) * r; pos.z = qz + (dz / d) * r; }
      else { // inside: push out the shortest way
        const opts = [[c.x0 - r - pos.x, 0], [c.x1 + r - pos.x, 0], [0, c.z0 - r - pos.z], [0, c.z1 + r - pos.z]];
        opts.sort((a, b) => Math.abs(a[0] + a[1]) - Math.abs(b[0] + b[1]));
        pos.x += opts[0][0]; pos.z += opts[0][1];
      }
    }
  }
  const lim = HALF - 0.8 - r * 0.5;
  pos.x = THREE.MathUtils.clamp(pos.x, -lim, lim);
  pos.z = THREE.MathUtils.clamp(pos.z, -lim, lim);
}

const tmp = new THREE.Vector3();
let fullWarned = false;
function updatePlayer(dt, t) {
  const tool = toolById(state.equipped);
  // input vector (camera relative)
  let ix = input.x, iy = input.y;
  if (keys.has('KeyW') || keys.has('ArrowUp')) iy += 1;
  if (keys.has('KeyS') || keys.has('ArrowDown')) iy -= 1;
  if (keys.has('KeyA') || keys.has('ArrowLeft')) ix -= 1;
  if (keys.has('KeyD') || keys.has('ArrowRight')) ix += 1;
  const m = Math.hypot(ix, iy);
  if (m > 1) { ix /= m; iy /= m; }
  const fwd = new THREE.Vector3(-Math.sin(cam.yaw), 0, -Math.cos(cam.yaw));
  const right = new THREE.Vector3(Math.cos(cam.yaw), 0, -Math.sin(cam.yaw));
  const dir = fwd.multiplyScalar(iy).add(right.multiplyScalar(ix));
  const want = dir.length();
  const old = player.pos.clone();
  if (want > 0.05) {
    const target = Math.atan2(dir.x, dir.z);
    let diff = ((target - player.heading + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
    const turn = (player.isMachine ? 3.2 : 14) * dt;
    player.heading += THREE.MathUtils.clamp(diff, -turn, turn);
    let sp = tool.speed * want;
    if (player.isMachine) sp *= Math.max(0, Math.cos(diff)) * 0.85 + 0.15;
    player.speedNow = THREE.MathUtils.lerp(player.speedNow, sp, Math.min(1, dt * (player.isMachine ? 3 : 10)));
  } else {
    player.speedNow = THREE.MathUtils.lerp(player.speedNow, 0, Math.min(1, dt * (player.isMachine ? 3 : 12)));
  }
  const hv = new THREE.Vector3(Math.sin(player.heading), 0, Math.cos(player.heading));
  player.pos.addScaledVector(hv, player.speedNow * dt);
  collide(player.pos, player.radius);
  const moved = player.pos.distanceTo(old);
  player.moving = moved > 0.002;

  // ---- scooping
  const cap = capacity();
  const wantsScoop = keys.has('Space') || input.touchScoop || state.auto || (player.isMachine && player.moving);
  player.scooping = false;
  const scoopPos = player.pos.clone().addScaledVector(hv, player.front);
  if (wantsScoop && state.load < cap - 1e-6) {
    const got = snow.harvest(scoopPos.x, scoopPos.z, tool.radius, Math.min(tool.rate * dt, cap - state.load));
    if (got > 0) {
      state.load = Math.min(cap, state.load + got);
      player.scooping = true;
      if (Math.random() < Math.min(1, dt * 30)) emitSpray(scoopPos.x, 0.3, scoopPos.z, player.isMachine ? 6 : 2, player.isMachine ? 1.4 : 0.8);
    }
  }
  if (state.load >= cap - 1e-6) {
    if (!fullWarned && wantsScoop) { ui.toast(player.isMachine ? 'Machine full! Drive to the Snow Pile.' : 'Hands full! Take it to the Snow Pile.'); fullWarned = true; }
  } else fullWarned = false;

  // ---- dump into pile
  const dPile = Math.hypot(player.pos.x - HUB.pile.x, player.pos.z - HUB.pile.z);
  if (state.load >= 0.5 && dPile < PILE_R + player.radius + 1.3) {
    const units = Math.floor(state.load + 1e-6);
    state.pile += units;
    state.load -= units;
    tossToPile(units);
    ui.floater(`+${fmt(units)} ❄`, worldToScreen(player.pos.clone().add(new THREE.Vector3(0, 2.4, 0))));
    saveState();
  }

  // ---- animate
  player.group.position.copy(player.pos);
  player.group.rotation.y = player.heading;
  const ud = player.char.userData;
  player.anim += moved * 3.2;
  if (!player.isMachine) {
    const sw = Math.sin(player.anim) * Math.min(1, player.speedNow / 3) * 0.7;
    ud.legs[0].rotation.x = sw; ud.legs[1].rotation.x = -sw;
    ud.arms[0].arm.rotation.x = -sw * 0.8 - (player.tool && tool.id !== 'hands' ? 0.5 : 0);
    digSwing = player.scooping ? digSwing + dt * 12 : THREE.MathUtils.lerp(digSwing, 0, dt * 8);
    const dig = player.scooping ? (Math.sin(digSwing) * 0.5 + 0.5) : 0;
    ud.arms[1].arm.rotation.x = -0.5 - dig * 0.6;
    if (player.tool) player.tool.rotation.x = -(player.tool.userData.tilt || 0) - dig * 0.3;
    player.char.position.y = Math.abs(Math.sin(player.anim)) * 0.05 * Math.min(1, player.speedNow / 3);
  } else {
    const mu = player.tool.userData;
    for (const s of mu.spinners) {
      if (s.wheel) s.obj.rotation[s.axis] += player.speedNow * dt * s.speed;
      else if (player.scooping || player.moving) s.obj.rotation[s.axis] += dt * s.speed * 3;
    }
    for (const tr of mu.tracks) tr.userData.advance(player.speedNow * dt);
    if (mu.standing) {
      const sw = Math.sin(player.anim) * Math.min(1, player.speedNow / 3) * 0.6;
      ud.legs[0].rotation.x = sw; ud.legs[1].rotation.x = -sw;
    }
    player.tool.position.y = player.scooping ? Math.sin(t * 40) * 0.01 : 0;
  }
  // load visual
  const fill = Math.min(1, state.load / cap);
  const ld = player.tool?.userData.load;
  if (ld) {
    ld.visible = fill > 0.01;
    if (player.tool.userData.loadIsBall) ld.scale.setScalar(0.35 + 0.65 * fill);
    else ld.scale.set(1, Math.max(0.05, fill), 1);
  }
}

// ------------------------------------------------------------------ camera
function updateCamera(dt) {
  const t = toolById(state.equipped);
  const base = player.isMachine ? 1.6 + toolIndex(t.id) * 0.06 : 1.4;
  cam.dist = THREE.MathUtils.lerp(cam.dist, cam.targetDist + (player.isMachine ? 2 + (toolIndex(t.id) - 10) * 0.4 : 0), Math.min(1, dt * 4));
  const target = player.pos.clone().add(new THREE.Vector3(0, base, 0));
  const cp = new THREE.Vector3(
    target.x + Math.sin(cam.yaw) * Math.cos(cam.pitch) * cam.dist,
    target.y + Math.sin(cam.pitch) * cam.dist,
    target.z + Math.cos(cam.yaw) * Math.cos(cam.pitch) * cam.dist,
  );
  camera.position.lerp(cp, Math.min(1, dt * 10));
  camera.lookAt(target);
  sun.position.set(player.pos.x + 25, 45, player.pos.z + 18);
  sun.target.position.copy(player.pos);
}

// ------------------------------------------------------------------ loop
function resize() {
  renderer.setSize(innerWidth, innerHeight, false);
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
}
addEventListener('resize', resize);
resize();

const clock = new THREE.Clock();
let hudTimer = 0, promptKey = '';
function frame() {
  const dt = Math.min(0.05, clock.getDelta());
  const t = clock.elapsedTime;
  if (!ui.modalOpen()) updatePlayer(dt, t);
  snow.update(dt);
  updateCamera(dt);
  updateSpray(dt);
  updateFlakes(dt, t);

  // display turntables
  displays.forEach((d, i) => { d.spinner.rotation.y = t * 0.5 + i; });
  // pile
  const ph = pileHeight();
  pileMound.scale.y = THREE.MathUtils.lerp(pileMound.scale.y, ph / PILE_R, Math.min(1, dt * 4));
  pileArrow.visible = state.load > 0;
  pileArrow.position.set(HUB.pile.x, ph + 2.5 + Math.sin(t * 4) * 0.3, HUB.pile.z);
  pileArrow.rotation.y = t * 2;
  // flying snowballs
  for (let i = flyBalls.length - 1; i >= 0; i--) {
    const b = flyBalls[i]; b.t += dt;
    const k = THREE.MathUtils.clamp(b.t / b.dur, 0, 1);
    b.m.position.lerpVectors(b.from, b.to, k); b.m.position.y += Math.sin(k * Math.PI) * 2.5;
    if (k >= 1) { scene.remove(b.m); flyBalls.splice(i, 1); emitSpray(b.to.x, b.to.y, b.to.z, 3, 0.5); }
  }
  // vendors idle
  sellVendor.userData.head.rotation.y = Math.sin(t * 0.8) * 0.3;
  shopVendor.userData.head.rotation.y = Math.sin(t * 0.7 + 1) * 0.3;
  if (sellVendor.userData.cheer > 0) {
    sellVendor.userData.cheer -= dt;
    sellVendor.userData.arms.forEach((a) => (a.arm.rotation.z = (a.arm.position.x > 0 ? 1 : -1) * 2.6 * Math.max(0, sellVendor.userData.cheer)));
  }
  shopVendor.userData.arms[1].arm.rotation.z = Math.max(0, Math.sin(t * 2)) * 1.2; // waving
  gift.rotation.y = Math.sin(t) * 0.2; gift.position.y = Math.abs(Math.sin(t * 2)) * 0.15;
  if (wheelDisc && !ui.spinning()) wheelDisc.parent.rotation.z = t * 0.3;

  // prompt
  const near = ui.modalOpen() ? null : nearest();
  const pk = near + ':' + Math.floor(state.pile);
  if (pk !== promptKey) {
    promptKey = pk;
    const mult = boostActive('sell') ? 2 : 1;
    const texts = {
      sell: `<kbd>E</kbd> Sell pile: ${fmt(state.pile)} snow → 🪙 ${fmt(Math.floor(state.pile) * SNOW_VALUE * mult)}`,
      shop: `<kbd>E</kbd> Open the tool shopping list`,
      display: `<kbd>E</kbd> Inspect tools (or click one)`,
      wheel: `<kbd>E</kbd> Spin the wheel`,
      gift: `<kbd>E</kbd> Daily reward`,
    };
    ui.prompt(near ? (isTouch ? texts[near].replace('<kbd>E</kbd>', '<kbd>Use</kbd>') : texts[near]) : '');
  }
  hudTimer -= dt;
  if (hudTimer <= 0) { hudTimer = 0.1; ui.update(); }
  saveState();
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
}

// ------------------------------------------------------------------ thumbnails for the shop list
function makeThumbs() {
  const r = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
  r.setSize(192, 192); r.toneMapping = THREE.ACESFilmicToneMapping;
  const s = new THREE.Scene();
  s.add(new THREE.HemisphereLight('#ffffff', '#667788', 2));
  const dl = new THREE.DirectionalLight('#ffffff', 2); dl.position.set(3, 5, 4); s.add(dl);
  const c = new THREE.PerspectiveCamera(32, 1, 0.01, 100);
  const out = {};
  for (const t of TOOLS) {
    const m = t.kind === 'hand' ? buildHandTool(t.id) : buildMachine(t.id);
    if (t.kind === 'hand') m.rotation.set(-0.3, 0.6, 0.5);
    else m.rotation.y = -0.7;
    s.add(m);
    const bb = new THREE.Box3().setFromObject(m);
    const sphere = bb.getBoundingSphere(new THREE.Sphere());
    const d = sphere.radius / Math.sin((c.fov * Math.PI) / 360) * 1.02;
    c.position.copy(sphere.center).add(new THREE.Vector3(0, 0.35, 1).normalize().multiplyScalar(d));
    c.lookAt(sphere.center);
    r.render(s, c);
    out[t.id] = r.domElement.toDataURL();
    s.remove(m);
  }
  r.dispose();
  return out;
}

// ------------------------------------------------------------------ boot
const thumbs = makeThumbs();
const api = {
  equip, refreshDisplayLabels, capacity,
  isTouch,
  onWheelTexture: makeWheelProp,
};
initUI(api, thumbs);
equip(state.equipped);
document.getElementById('loading').remove();
if (!state.seenHelp) { ui.open('help'); state.seenHelp = true; saveState(true); }
requestAnimationFrame(frame);
window.__game = { state, player, snow, equip, ui, renderer, cam, HUB, camera, scene };
