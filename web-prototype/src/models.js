// Procedural 3D models built from Three.js primitives.
// Machines face +Z. Each machine group carries userData:
//   seat:     Vector3 where the player sits / stands
//   standing: true if the player stands (walk-behind)
//   load:     Object3D scaled with how full the machine is
//   spinners: [{ obj, axis, speed }] animated while moving / working
import * as THREE from 'three';

// ---------------------------------------------------------------- materials
const matCache = new Map();
export function mat(color, opts = {}) {
  const key = color + JSON.stringify(opts);
  if (!matCache.has(key)) {
    matCache.set(key, new THREE.MeshStandardMaterial({ color, roughness: 0.6, metalness: 0.1, ...opts }));
  }
  return matCache.get(key);
}
const M = {
  tire: () => mat('#1b1c1f', { roughness: 0.95 }),
  rim: () => mat('#c9ccd1', { metalness: 0.7, roughness: 0.3 }),
  steel: () => mat('#8d939b', { metalness: 0.75, roughness: 0.35 }),
  dark: () => mat('#2a2d33', { roughness: 0.7 }),
  black: () => mat('#111214', { roughness: 0.6 }),
  chrome: () => mat('#e6e9ee', { metalness: 0.95, roughness: 0.12 }),
  glass: () => mat('#7fb6d9', { metalness: 0.2, roughness: 0.05, transparent: true, opacity: 0.45 }),
  light: () => mat('#fff6d8', { emissive: '#fff1b8', emissiveIntensity: 1.2 }),
  tail: () => mat('#ff3b30', { emissive: '#ff2010', emissiveIntensity: 0.9 }),
  amber: () => mat('#ffb020', { emissive: '#ff9000', emissiveIntensity: 1.0 }),
  seat: () => mat('#232428', { roughness: 0.85 }),
  wood: () => mat('#9a6a3c', { roughness: 0.85 }),
  rubber: () => mat('#26272b', { roughness: 0.9 }),
  snow: () => mat('#f4f8ff', { roughness: 0.9 }),
};

// ---------------------------------------------------------------- helpers
function shadow(o) {
  o.traverse((c) => { if (c.isMesh) { c.castShadow = true; c.receiveShadow = true; } });
  return o;
}
export function box(w, h, d, material, x = 0, y = 0, z = 0, parent) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
  m.position.set(x, y, z);
  if (parent) parent.add(m);
  return m;
}
export function cyl(rt, rb, h, material, x = 0, y = 0, z = 0, parent, seg = 20) {
  const m = new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg), material);
  m.position.set(x, y, z);
  if (parent) parent.add(m);
  return m;
}
function sphere(r, material, x = 0, y = 0, z = 0, parent, seg = 16) {
  const m = new THREE.Mesh(new THREE.SphereGeometry(r, seg, Math.max(8, seg * 0.75)), material);
  m.position.set(x, y, z);
  if (parent) parent.add(m);
  return m;
}
// tube between two points
function rod(a, b, r, material, parent, seg = 10) {
  const A = new THREE.Vector3(...a), B = new THREE.Vector3(...b);
  const len = A.distanceTo(B);
  const m = new THREE.Mesh(new THREE.CylinderGeometry(r, r, len, seg), material);
  m.position.copy(A).add(B).multiplyScalar(0.5);
  m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), B.clone().sub(A).normalize());
  if (parent) parent.add(m);
  return m;
}
// rounded-ish slab using an extruded rounded rectangle (profile in XY, extruded along Z)
function roundedBox(w, h, d, r, material, x = 0, y = 0, z = 0, parent) {
  const s = new THREE.Shape();
  const hw = w / 2, hh = h / 2;
  s.moveTo(-hw + r, -hh);
  s.lineTo(hw - r, -hh); s.quadraticCurveTo(hw, -hh, hw, -hh + r);
  s.lineTo(hw, hh - r); s.quadraticCurveTo(hw, hh, hw - r, hh);
  s.lineTo(-hw + r, hh); s.quadraticCurveTo(-hw, hh, -hw, hh - r);
  s.lineTo(-hw, -hh + r); s.quadraticCurveTo(-hw, -hh, -hw + r, -hh);
  const g = new THREE.ExtrudeGeometry(s, { depth: d, bevelEnabled: true, bevelSize: r * 0.3, bevelThickness: r * 0.3, bevelSegments: 2, curveSegments: 4 });
  g.translate(0, 0, -d / 2);
  const m = new THREE.Mesh(g, material);
  m.position.set(x, y, z);
  if (parent) parent.add(m);
  return m;
}
// extrude an arbitrary side profile (points in ZY plane) to a width along X
function sideProfile(points, width, material, parent, x = 0) {
  const s = new THREE.Shape(points.map(([z, y]) => new THREE.Vector2(z, y)));
  const g = new THREE.ExtrudeGeometry(s, { depth: width, bevelEnabled: false });
  g.translate(0, 0, -width / 2);
  g.rotateY(-Math.PI / 2); // shape x -> world z, extrude -> world x
  const m = new THREE.Mesh(g, material);
  m.position.x = x;
  if (parent) parent.add(m);
  return m;
}

// Wheel spinning about X. tread = number of lugs.
function wheel(r, w, opts = {}) {
  const g = new THREE.Group();
  const tire = cyl(r, r, w, M.tire(), 0, 0, 0, g, 28);
  tire.rotation.z = Math.PI / 2;
  // sidewall bulge
  const tor = new THREE.Mesh(new THREE.TorusGeometry(r * 0.86, w * 0.18, 8, 28), M.tire());
  tor.rotation.y = Math.PI / 2; tor.position.x = w / 2 * 0.95; g.add(tor);
  const tor2 = tor.clone(); tor2.position.x = -w / 2 * 0.95; g.add(tor2);
  // tread lugs
  const lugs = opts.lugs ?? 18;
  for (let i = 0; i < lugs; i++) {
    const a = (i / lugs) * Math.PI * 2;
    const lug = box(w * 0.42, r * 0.12, r * 0.16, M.tire(), (i % 2 ? 1 : -1) * w * 0.24, Math.cos(a) * r, Math.sin(a) * r, g);
    lug.rotation.x = -a;
  }
  // rim + hub + lug nuts, both sides
  const rimColor = opts.rim ? mat(opts.rim, { metalness: 0.6, roughness: 0.35 }) : M.rim();
  for (const side of [1, -1]) {
    const rim = cyl(r * 0.62, r * 0.62, 0.02, rimColor, side * (w / 2 + 0.005), 0, 0, g, 24);
    rim.rotation.z = Math.PI / 2;
    const dish = cyl(r * 0.45, r * 0.55, 0.04, mat('#9ea3ab', { metalness: 0.6, roughness: 0.4 }), side * (w / 2 + 0.02), 0, 0, g, 24);
    dish.rotation.z = Math.PI / 2;
    const hub = cyl(r * 0.16, r * 0.2, 0.06, M.chrome(), side * (w / 2 + 0.05), 0, 0, g, 12);
    hub.rotation.z = Math.PI / 2;
    const nuts = opts.nuts ?? 6;
    for (let i = 0; i < nuts; i++) {
      const a = (i / nuts) * Math.PI * 2;
      const n = cyl(r * 0.035, r * 0.035, 0.05, M.chrome(), side * (w / 2 + 0.04), Math.cos(a) * r * 0.3, Math.sin(a) * r * 0.3, g, 6);
      n.rotation.z = Math.PI / 2;
    }
  }
  return g;
}

// Crawler track along Z, centred at origin. len = distance between end wheel centres.
function track(len, r, w, color = '#1e1f22', opts = {}) {
  const g = new THREE.Group();
  const spinners = [];
  const padMat = mat(color, { roughness: 0.85, metalness: 0.2 });
  const perim = 2 * len + 2 * Math.PI * r;
  const pads = Math.round(perim / (opts.pitch ?? 0.17));
  const padsGroup = new THREE.Group();
  g.add(padsGroup);
  const pt = (s) => {
    s = ((s % perim) + perim) % perim;
    if (s < len) return { z: len / 2 - s, y: -r, a: 0 };           // bottom, moving back
    s -= len;
    if (s < Math.PI * r) { const a = s / r; return { z: -len / 2 - Math.sin(a) * r, y: -Math.cos(a) * r, a }; }
    s -= Math.PI * r;
    if (s < len) return { z: -len / 2 + s, y: r, a: Math.PI };
    s -= len;
    const a = Math.PI + s / r;
    return { z: len / 2 - Math.sin(a) * r, y: -Math.cos(a) * r, a };
  };
  const padMeshes = [];
  for (let i = 0; i < pads; i++) {
    const p = box(w, 0.06, (perim / pads) * 0.8, padMat, 0, 0, 0, padsGroup);
    const grouser = box(w, 0.05, 0.04, padMat, 0, -0.05, 0, p);
    grouser.position.y = -0.045;
    padMeshes.push(p);
  }
  let offset = 0;
  const layout = () => {
    padMeshes.forEach((p, i) => {
      const q = pt(i * (perim / pads) + offset);
      p.position.set(0, q.y, q.z);
      p.rotation.x = -q.a;
    });
  };
  layout();
  // drive sprocket + idler + road wheels
  const wheelMat = mat(opts.wheel ?? '#3a3d44', { metalness: 0.5, roughness: 0.4 });
  const ends = [];
  for (const z of [len / 2, -len / 2]) {
    const sp = new THREE.Group(); sp.position.z = z; g.add(sp);
    const c = cyl(r * 0.85, r * 0.85, w * 0.8, wheelMat, 0, 0, 0, sp, 18); c.rotation.z = Math.PI / 2;
    for (let i = 0; i < 10; i++) {
      const a = (i / 10) * Math.PI * 2;
      const t = box(w * 0.82, r * 0.18, r * 0.18, wheelMat, 0, Math.cos(a) * r * 0.85, Math.sin(a) * r * 0.85, sp);
      t.rotation.x = -a;
    }
    const cap = cyl(r * 0.3, r * 0.3, w * 0.9, mat('#d0a020', { metalness: 0.4 }), 0, 0, 0, sp, 10); cap.rotation.z = Math.PI / 2;
    ends.push(sp);
  }
  const nRoad = opts.roadWheels ?? Math.max(3, Math.floor(len / (r * 1.2)));
  for (let i = 0; i < nRoad; i++) {
    const z = -len / 2 + r + ((len - 2 * r) * (i + 0.5)) / nRoad;
    const rw = cyl(r * 0.55, r * 0.55, w * 0.7, wheelMat, 0, -r + r * 0.6, z, g, 14); rw.rotation.z = Math.PI / 2;
    ends.push(rw);
  }
  // track frame
  box(w * 0.3, r * 0.7, len, mat(opts.frame ?? '#2b2e33'), 0, 0, 0, g);
  g.userData.advance = (d) => {
    offset = (offset + d) % perim; layout();
    ends.forEach((e) => (e.rotation.x -= d / r));
  };
  return g;
}

// helical auger along X
function auger(len, r, material) {
  const g = new THREE.Group();
  const shaft = cyl(r * 0.18, r * 0.18, len, M.steel(), 0, 0, 0, g, 10); shaft.rotation.z = Math.PI / 2;
  const turns = 3, steps = 36;
  for (const dir of [1, -1]) {
    for (let i = 0; i < steps; i++) {
      const t = i / steps;
      const x = dir * (t * len / 2);
      const a = t * turns * Math.PI * 2 * dir;
      const blade = box(0.03, r * 0.85, r * 0.25, material, x, 0, 0, g);
      blade.rotation.x = a;
      blade.position.y = Math.cos(a) * r * 0.5;
      blade.position.z = Math.sin(a) * r * 0.5;
    }
  }
  return g;
}

function headlight(r, parent, x, y, z) {
  const housing = cyl(r * 1.25, r * 1.25, r * 0.8, M.black(), x, y, z, parent, 16); housing.rotation.x = Math.PI / 2;
  const lens = cyl(r, r, 0.02, M.light(), x, y, z + r * 0.42, parent, 16); lens.rotation.x = Math.PI / 2;
  return housing;
}
function beacon(parent, x, y, z, s = 1) {
  cyl(0.08 * s, 0.1 * s, 0.05 * s, M.black(), x, y, z, parent, 12);
  const b = cyl(0.07 * s, 0.08 * s, 0.14 * s, M.amber(), x, y + 0.09 * s, z, parent, 12);
  return b;
}
function seatModel(parent, x, y, z, s = 1, color) {
  const g = new THREE.Group(); g.position.set(x, y, z); parent.add(g);
  const sm = color ? mat(color, { roughness: 0.85 }) : M.seat();
  roundedBox(0.5 * s, 0.1 * s, 0.48 * s, 0.04 * s, sm, 0, 0, 0, g);
  const back = roundedBox(0.5 * s, 0.5 * s, 0.1 * s, 0.04 * s, sm, 0, 0.28 * s, -0.22 * s, g);
  back.rotation.x = -0.15;
  return g;
}
function steeringWheel(parent, x, y, z, tilt = 0.9, r = 0.18) {
  const g = new THREE.Group(); g.position.set(x, y, z); g.rotation.x = -tilt; parent.add(g);
  const ring = new THREE.Mesh(new THREE.TorusGeometry(r, 0.022, 8, 24), M.black()); ring.rotation.x = Math.PI / 2; g.add(ring);
  for (let i = 0; i < 3; i++) {
    const a = (i / 3) * Math.PI * 2 + Math.PI / 2;
    rod([0, 0, 0], [Math.cos(a) * r, 0, Math.sin(a) * r], 0.012, M.black(), g, 6);
  }
  cyl(0.04, 0.04, 0.04, M.dark(), 0, 0, 0, g, 10);
  rod([0, 0, 0], [0, -0.4, 0], 0.025, M.dark(), g, 8);
  return g;
}
function mirror(parent, x, y, z, side) {
  rod([x, y, z], [x + side * 0.18, y + 0.06, z], 0.015, M.black(), parent, 6);
  box(0.04, 0.2, 0.14, M.black(), x + side * 0.22, y + 0.06, z, parent);
  box(0.005, 0.17, 0.11, M.chrome(), x + side * 0.22 - side * 0.022, y + 0.06, z, parent);
}
function plowBlade(w, h, color, parent, x, y, z, opts = {}) {
  const g = new THREE.Group(); g.position.set(x, y, z); parent.add(g);
  const paint = mat(color, { metalness: 0.35, roughness: 0.4 });
  // curved moldboard built from slats along a concave profile (bottom and top lean forward)
  const prof = (t) => [-0.32 * h * Math.sin(t * Math.PI) + 0.12 * h * t * t * t, t * h];
  const N = 8;
  for (let k = 0; k < N; k++) {
    const [z0, y0] = prof(k / N), [z1, y1] = prof((k + 1) / N);
    const len = Math.hypot(z1 - z0, y1 - y0);
    const slat = box(w, len * 1.08, 0.04, paint, 0, (y0 + y1) / 2, (z0 + z1) / 2, g);
    slat.rotation.x = -Math.atan2(z1 - z0, y1 - y0);
  }
  box(w, 0.06, 0.06, M.dark(), 0, h, prof(1)[0], g); // top lip
  box(w, 0.05, 0.08, M.steel(), 0, 0.02, 0.02, g); // cutting edge
  // ribs on back
  const ribs = opts.ribs ?? 5;
  for (let i = 0; i < ribs; i++) {
    const rx = -w / 2 + (w * (i + 0.5)) / ribs;
    box(0.04, h * 0.8, 0.06, paint, rx, h * 0.45, -h * 0.36, g);
  }
  // marker stakes
  for (const s of [-1, 1]) {
    rod([s * w * 0.48, h * 0.8, -h * 0.4], [s * w * 0.48, h * 1.6, -h * 0.4], 0.012, mat('#ff7a00'), g, 6);
    sphere(0.025, mat('#ff7a00'), s * w * 0.48, h * 1.6, -h * 0.4, g, 6);
  }
  return g;
}
function snowLoad(w, h, d) {
  // lumpy pile used as the visual "load"; scaled on Y by fill level
  const g = new THREE.Group();
  const sm = M.snow();
  const base = new THREE.Mesh(new THREE.SphereGeometry(1, 14, 8, 0, Math.PI * 2, 0, Math.PI / 2), sm);
  base.scale.set(w / 2, h, d / 2); g.add(base);
  for (let i = 0; i < 4; i++) {
    const b = sphere(Math.min(w, d) * 0.22, sm, (Math.random() - 0.5) * w * 0.5, h * 0.4, (Math.random() - 0.5) * d * 0.5, g, 8);
    b.scale.y = 0.6;
  }
  return g;
}

// ---------------------------------------------------------------- character
export function buildCharacter(opts = {}) {
  const g = new THREE.Group();
  const coat = mat(opts.coat ?? '#d9433b', { roughness: 0.8 });
  const pants = mat(opts.pants ?? '#2f3e63', { roughness: 0.85 });
  const skin = mat(opts.skin ?? '#f1c6a0', { roughness: 0.7 });
  const hat = mat(opts.hat ?? '#2b6cb0', { roughness: 0.9 });
  const boot = mat('#3a2a20', { roughness: 0.8 });
  const glove = mat(opts.glove ?? '#24324a', { roughness: 0.9 });

  const legs = [];
  for (const s of [-1, 1]) {
    const leg = new THREE.Group(); leg.position.set(s * 0.13, 0.85, 0); g.add(leg);
    const l = new THREE.Mesh(new THREE.CapsuleGeometry(0.11, 0.5, 4, 10), pants); l.position.y = -0.38; leg.add(l);
    const b = roundedBox(0.2, 0.16, 0.3, 0.05, boot, 0, -0.78, 0.04, leg);
    legs.push(leg);
  }
  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.27, 0.45, 6, 14), coat);
  torso.position.y = 1.2; torso.scale.z = 0.8; g.add(torso);
  // zipper + pockets
  box(0.02, 0.6, 0.02, M.steel(), 0, 1.22, 0.22, g);
  box(0.14, 0.1, 0.03, mat('#b5342d'), -0.13, 1.0, 0.2, g);
  box(0.14, 0.1, 0.03, mat('#b5342d'), 0.13, 1.0, 0.2, g);
  // scarf
  const scarf = new THREE.Mesh(new THREE.TorusGeometry(0.17, 0.06, 8, 16), mat(opts.scarf ?? '#f2c14e')); scarf.rotation.x = Math.PI / 2; scarf.position.y = 1.58; g.add(scarf);
  box(0.09, 0.3, 0.04, mat(opts.scarf ?? '#f2c14e'), 0.1, 1.42, 0.2, g).rotation.z = 0.15;
  // head
  const head = new THREE.Group(); head.position.y = 1.8; g.add(head);
  sphere(0.2, skin, 0, 0, 0, head, 20);
  sphere(0.025, M.black(), -0.07, 0.03, 0.18, head, 8);
  sphere(0.025, M.black(), 0.07, 0.03, 0.18, head, 8);
  sphere(0.035, mat('#f08a7a'), 0, -0.02, 0.2, head, 8);
  sphere(0.03, mat('#f4a3a3'), -0.12, -0.05, 0.15, head, 8);
  sphere(0.03, mat('#f4a3a3'), 0.12, -0.05, 0.15, head, 8);
  const beanie = new THREE.Mesh(new THREE.SphereGeometry(0.215, 18, 10, 0, Math.PI * 2, 0, Math.PI / 2), hat); beanie.position.y = 0.03; head.add(beanie);
  const cuff = cyl(0.218, 0.218, 0.08, mat('#e8eef7'), 0, 0.04, 0, head, 18);
  sphere(0.07, mat('#e8eef7'), 0, 0.26, 0, head, 10);

  const arms = [];
  for (const s of [-1, 1]) {
    const arm = new THREE.Group(); arm.position.set(s * 0.33, 1.46, 0); g.add(arm);
    const a = new THREE.Mesh(new THREE.CapsuleGeometry(0.085, 0.42, 4, 10), coat); a.position.y = -0.27; arm.add(a);
    sphere(0.085, glove, 0, -0.56, 0, arm, 10);
    const hand = new THREE.Group(); hand.position.set(0, -0.58, 0); arm.add(hand);
    arms.push({ arm, hand });
  }
  shadow(g);
  g.userData = { legs, arms, head, torso };
  return g;
}

// ---------------------------------------------------------------- hand tools
// Built upright: grip near origin (held in right hand), working end downwards/forwards.
function shaft(len, color = '#b07a45', r = 0.025) {
  const m = cyl(r, r, len, mat(color, { roughness: 0.7 }), 0, 0, 0, null, 10);
  return m;
}
function dGrip(parent, y, color = '#222') {
  const t = new THREE.Mesh(new THREE.TorusGeometry(0.07, 0.015, 6, 14, Math.PI), mat(color));
  t.position.y = y; parent.add(t);
  rod([-0.07, y, 0], [0.07, y, 0], 0.016, mat(color), parent, 6);
}

export function buildHandTool(id) {
  const g = new THREE.Group();
  const load = new THREE.Group();
  g.userData.load = load;
  g.add(load);
  switch (id) {
    case 'hands': {
      // just a snowball held in the glove
      const ball = sphere(0.13, M.snow(), 0, -0.05, 0.08, load, 14);
      g.userData.loadIsBall = true;
      break;
    }
    case 'trowel': {
      const h = cyl(0.025, 0.03, 0.14, mat('#2e7d32'), 0, 0, 0, g, 10);
      cyl(0.008, 0.008, 0.1, M.steel(), 0, -0.12, 0, g, 6);
      const blade = new THREE.Mesh(new THREE.ConeGeometry(0.06, 0.2, 12, 1, true, 0, Math.PI), mat('#b9bec6', { metalness: 0.7, roughness: 0.3, side: THREE.DoubleSide }));
      blade.rotation.x = Math.PI; blade.position.set(0, -0.26, 0.02); g.add(blade);
      load.position.set(0, -0.26, 0.02);
      load.add(snowLoad(0.1, 0.06, 0.12));
      break;
    }
    default: {
      // shovels: parameterised family
      const P = {
        kidshovel:   { len: 0.75, bw: 0.24, bh: 0.24, color: '#e53935', shaft: '#e53935', grip: '#ffeb3b', dg: true },
        shovel:      { len: 1.05, bw: 0.42, bh: 0.34, color: '#1e88e5', shaft: '#b07a45', grip: '#222', dg: true },
        bigshovel:   { len: 1.15, bw: 0.56, bh: 0.4,  color: '#43a047', shaft: '#8d6e63', grip: '#222', dg: true },
        megashovel:  { len: 1.2,  bw: 0.72, bh: 0.48, color: '#fb8c00', shaft: '#5d4037', grip: '#111', dg: true },
        steelshovel: { len: 1.2,  bw: 0.66, bh: 0.5,  color: '#9aa3ad', shaft: '#3e2723', grip: '#111', dg: true, metal: true },
        pusher:      { len: 1.35, bw: 0.95, bh: 0.32, color: '#283593', shaft: '#9e9e9e', grip: '#111', push: true },
        twinpusher:  { len: 1.3,  bw: 1.2,  bh: 0.5,  color: '#c62828', shaft: '#616161', grip: '#111', push: true, wheels: true },
        sledscoop:   { len: 1.2,  bw: 1.0,  bh: 0.42, color: '#6a1b9a', shaft: '#424242', grip: '#111', push: true, sled: true },
      }[id] || { len: 1, bw: 0.4, bh: 0.3, color: '#888', shaft: '#888', grip: '#222', dg: true };
      const s = shaft(P.len, P.shaft);
      s.position.y = -P.len / 2 + 0.1;
      g.add(s);
      if (P.dg) dGrip(g, 0.17, P.grip);
      else { // T bar
        rod([-0.16, 0.12, 0], [0.16, 0.12, 0], 0.02, mat(P.grip), g, 8);
        for (const x of [-0.16, 0.16]) cyl(0.026, 0.026, 0.1, mat('#d32f2f'), x, 0.12, 0, g, 8).rotation.z = Math.PI / 2;
      }
      const bladeMat = mat(P.color, { metalness: P.metal ? 0.7 : 0.15, roughness: P.metal ? 0.3 : 0.5 });
      const blade = new THREE.Group();
      blade.position.y = -P.len + 0.08;
      g.add(blade);
      // collar
      cyl(0.035, 0.03, 0.12, M.steel(), 0, 0.1, 0, blade, 10);
      if (P.push) {
        // wide curved pusher blade, angled
        const c = new THREE.Mesh(new THREE.CylinderGeometry(P.bh, P.bh, P.bw, 16, 1, true, 0, Math.PI * 0.6), bladeMat.clone());
        c.material.side = THREE.DoubleSide;
        c.rotation.z = Math.PI / 2; c.position.set(0, -0.05, 0.12);
        blade.add(c);
        box(P.bw, 0.03, 0.05, M.steel(), 0, -0.05 - P.bh * 0.6, 0.12 + P.bh * 0.78, blade);
        // braces
        rod([0, 0.05, 0], [P.bw * 0.35, -0.05, 0.1], 0.012, M.steel(), blade, 6);
        rod([0, 0.05, 0], [-P.bw * 0.35, -0.05, 0.1], 0.012, M.steel(), blade, 6);
        if (P.wheels) {
          for (const x of [-P.bw * 0.45, P.bw * 0.45]) {
            const w = wheel(0.12, 0.06, { lugs: 10, nuts: 4 }); w.position.set(x, -0.3, -0.12); blade.add(w);
          }
        }
        if (P.sled) {
          for (const x of [-P.bw * 0.4, P.bw * 0.4]) {
            box(0.04, 0.03, 0.7, M.chrome(), x, -0.42, -0.1, blade);
            const tip = new THREE.Mesh(new THREE.TorusGeometry(0.1, 0.018, 6, 10, Math.PI / 2), M.chrome());
            tip.rotation.y = Math.PI / 2; tip.position.set(x, -0.32, 0.25); blade.add(tip);
          }
          box(P.bw * 0.85, 0.2, 0.6, bladeMat, 0, -0.32, -0.1, blade);
        }
        load.position.set(0, -P.len + 0.08 - 0.1, 0.05);
        load.add(snowLoad(P.bw * 0.8, 0.22, 0.35));
      } else {
        // scoop shovel: back plate + floor + side walls
        const tilt = new THREE.Group(); tilt.rotation.x = 0.35; blade.add(tilt);
        box(P.bw, P.bh, 0.02, bladeMat, 0, -P.bh / 2, 0, tilt);
        box(P.bw, 0.02, P.bh * 0.9, bladeMat, 0, -P.bh, P.bh * 0.45, tilt);
        for (const x of [-P.bw / 2, P.bw / 2]) {
          const side = sideProfile([[0, 0], [0, -P.bh], [P.bh * 0.9, -P.bh], [P.bh * 0.1, -P.bh * 0.1]], 0.02, bladeMat, tilt, x);
        }
        box(P.bw, 0.025, 0.03, M.steel(), 0, -P.bh, P.bh * 0.9, tilt); // wear strip
        // rivets
        for (let i = 0; i < 4; i++) sphere(0.012, M.steel(), -P.bw * 0.3 + i * P.bw * 0.2, -0.04, 0.012, tilt, 6);
        load.position.set(0, -P.len + 0.08 - P.bh * 0.75, P.bh * 0.45);
        load.add(snowLoad(P.bw * 0.8, P.bh * 0.5, P.bh * 0.7));
      }
    }
  }
  shadow(g);
  return g;
}

// ---------------------------------------------------------------- machines
export function buildMachine(id) {
  const g = new THREE.Group();
  const ud = { seat: new THREE.Vector3(0, 1, 0), standing: false, spinners: [], tracks: [], load: null };
  g.userData = ud;
  const spin = (obj, axis = 'x', speed = 1) => ud.spinners.push({ obj, axis, speed });
  const addWheel = (r, w, x, y, z, opts) => { const wh = wheel(r, w, opts); wh.position.set(x, y, z); g.add(wh); ud.spinners.push({ obj: wh, axis: 'x', speed: 1 / r, wheel: true }); return wh; };
  const setLoad = (obj, x, y, z) => { obj.position.set(x, y, z); g.add(obj); ud.load = obj; };

  switch (id) {
    case 'blower': {
      const paint = mat('#d32f2f', { metalness: 0.3, roughness: 0.35 });
      // auger housing (open front half-drum)
      const housing = new THREE.Mesh(new THREE.CylinderGeometry(0.32, 0.32, 0.8, 24, 1, true, Math.PI, Math.PI), paint.clone());
      housing.material.side = THREE.DoubleSide; housing.rotation.z = Math.PI / 2; housing.position.set(0, 0.36, 0.45); g.add(housing);
      for (const x of [-0.4, 0.4]) { const cap = cyl(0.32, 0.32, 0.03, paint, x, 0.36, 0.45, g, 24); cap.rotation.z = Math.PI / 2; }
      box(0.82, 0.04, 0.1, M.steel(), 0, 0.04, 0.68, g); // scraper bar
      for (const x of [-0.42, 0.42]) box(0.04, 0.1, 0.28, M.steel(), x, 0.06, 0.55, g); // skid shoes
      const aug = auger(0.76, 0.26, mat('#fbc02d', { metalness: 0.4 })); aug.position.set(0, 0.36, 0.5); g.add(aug); spin(aug, 'x', 4);
      // impeller housing + chute
      const imp = cyl(0.2, 0.2, 0.2, paint, 0, 0.36, 0.2, g, 20); imp.rotation.x = Math.PI / 2;
      const chute = cyl(0.08, 0.1, 0.6, paint, 0.05, 0.85, 0.22, g, 14); chute.rotation.z = -0.12;
      const defl = box(0.2, 0.06, 0.26, paint, 0.1, 1.17, 0.32, g); defl.rotation.x = 0.5;
      rod([0.05, 0.6, 0.12], [0.05, 0.9, -0.6], 0.012, M.steel(), g, 6);
      // engine
      roundedBox(0.5, 0.36, 0.45, 0.05, M.dark(), 0, 0.62, -0.12, g);
      for (let i = 0; i < 6; i++) box(0.52, 0.015, 0.03, M.steel(), 0, 0.5 + i * 0.05, 0.1, g); // cooling fins
      cyl(0.09, 0.09, 0.08, mat('#212121'), 0.18, 0.86, -0.12, g, 14); // gas cap
      box(0.16, 0.12, 0.14, mat('#424242'), -0.2, 0.84, -0.22, g); // air filter
      cyl(0.04, 0.04, 0.16, M.chrome(), -0.29, 0.64, -0.3, g, 10).rotation.x = Math.PI / 2; // muffler
      // frame + wheels
      box(0.6, 0.1, 0.8, M.dark(), 0, 0.32, -0.25, g);
      addWheel(0.26, 0.18, -0.4, 0.26, -0.45, { lugs: 14, rim: '#d32f2f' });
      addWheel(0.26, 0.18, 0.4, 0.26, -0.45, { lugs: 14, rim: '#d32f2f' });
      // handlebars
      for (const x of [-0.27, 0.27]) rod([x, 0.42, -0.5], [x, 1.05, -1.0], 0.02, M.black(), g, 8);
      rod([-0.27, 1.05, -1.0], [0.27, 1.05, -1.0], 0.02, M.black(), g, 8);
      for (const x of [-0.25, 0.25]) cyl(0.03, 0.03, 0.12, M.rubber(), x, 1.05, -1.0, g, 8).rotation.z = Math.PI / 2;
      const dash = box(0.38, 0.12, 0.08, M.dark(), 0, 0.92, -0.86, g); dash.rotation.x = 0.6;
      sphere(0.02, mat('#4caf50', { emissive: '#2e7d32' }), -0.08, 0.96, -0.83, g, 8);
      sphere(0.02, mat('#f44336', { emissive: '#b71c1c' }), 0.08, 0.96, -0.83, g, 8);
      headlight(0.05, g, 0, 0.82, 0.12);
      // load: collection bag on back
      setLoad(snowLoad(0.4, 0.3, 0.35), 0, 0.78, -0.55);
      ud.seat.set(0, 0, -1.45); ud.standing = true;
      break;
    }
    case 'tractor': {
      const paint = mat('#2e7d32', { metalness: 0.3, roughness: 0.35 });
      const yellow = mat('#fdd835', { metalness: 0.2, roughness: 0.4 });
      // chassis + hood
      box(0.7, 0.18, 1.9, M.dark(), 0, 0.45, 0, g);
      sideProfile([[0.95, 0.55], [0.95, 0.85], [0.55, 1.0], [-0.1, 1.0], [-0.1, 0.55]], 0.72, paint, g);
      for (let i = 0; i < 6; i++) box(0.74, 0.02, 0.025, M.black(), 0, 0.68 + i * 0.04, 0.93, g); // grille
      headlight(0.05, g, -0.2, 0.9, 0.93); headlight(0.05, g, 0.2, 0.9, 0.93);
      box(0.74, 0.05, 0.4, yellow, 0, 0.72, 0.45, g); // stripe
      // fenders + seat deck
      for (const s of [-1, 1]) {
        const f = new THREE.Mesh(new THREE.CylinderGeometry(0.45, 0.45, 0.32, 20, 1, true, -Math.PI / 2, Math.PI), paint.clone());
        f.material.side = THREE.DoubleSide; f.rotation.z = Math.PI / 2; f.position.set(s * 0.52, 0.42, -0.6); g.add(f);
      }
      box(1.2, 0.06, 0.7, paint, 0, 0.8, -0.6, g);
      seatModel(g, 0, 0.87, -0.65, 1, '#fdd835');
      steeringWheel(g, 0, 1.25, -0.1, 0.8);
      // wheels
      addWheel(0.42, 0.3, -0.62, 0.42, -0.6, { rim: '#fdd835', lugs: 20 });
      addWheel(0.42, 0.3, 0.62, 0.42, -0.6, { rim: '#fdd835', lugs: 20 });
      addWheel(0.25, 0.18, -0.45, 0.25, 0.65, { rim: '#fdd835', lugs: 12 });
      addWheel(0.25, 0.18, 0.45, 0.25, 0.65, { rim: '#fdd835', lugs: 12 });
      // front plow on push frame
      rod([-0.3, 0.4, 0.6], [-0.4, 0.35, 1.3], 0.03, M.dark(), g, 8);
      rod([0.3, 0.4, 0.6], [0.4, 0.35, 1.3], 0.03, M.dark(), g, 8);
      plowBlade(1.7, 0.5, '#fdd835', g, 0, 0.02, 1.45);
      cyl(0.04, 0.04, 0.5, M.chrome(), 0.25, 1.15, 0.5, g, 8); // exhaust
      // dump cart
      const cart = new THREE.Group(); cart.position.set(0, 0, -1.9); g.add(cart);
      rod([0, 0.35, 0.95], [0, 0.35, 0.55], 0.03, M.dark(), cart, 6);
      box(1.1, 0.4, 0.9, mat('#1b5e20'), 0, 0.6, 0, cart);
      box(1.0, 0.36, 0.8, mat('#0d3b10'), 0, 0.64, 0, cart);
      const cw1 = wheel(0.22, 0.14); cw1.position.set(-0.62, 0.22, 0); cart.add(cw1); ud.spinners.push({ obj: cw1, axis: 'x', speed: 4.5, wheel: true });
      const cw2 = wheel(0.22, 0.14); cw2.position.set(0.62, 0.22, 0); cart.add(cw2); ud.spinners.push({ obj: cw2, axis: 'x', speed: 4.5, wheel: true });
      setLoad(snowLoad(0.95, 0.4, 0.75), 0, 0.8, -1.9);
      ud.seat.set(0, 0.92, -0.62);
      break;
    }
    case 'atv': {
      const paint = mat('#1565c0', { metalness: 0.35, roughness: 0.3 });
      box(0.6, 0.2, 1.5, M.dark(), 0, 0.5, 0, g);
      sideProfile([[0.9, 0.6], [0.8, 0.85], [0.35, 0.9], [0.2, 1.05], [-0.4, 1.0], [-0.85, 0.9], [-0.9, 0.6]], 0.75, paint, g);
      // fenders over each wheel
      for (const [x, z] of [[-0.5, 0.55], [0.5, 0.55], [-0.5, -0.55], [0.5, -0.55]]) {
        const f = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 0.34, 18, 1, true, -Math.PI / 2, Math.PI), paint.clone());
        f.material.side = THREE.DoubleSide; f.rotation.z = Math.PI / 2; f.position.set(x, 0.38, z); g.add(f);
        addWheel(0.32, 0.26, x, 0.32, z, { lugs: 16, nuts: 4 });
      }
      roundedBox(0.4, 0.14, 0.7, 0.05, M.seat(), 0, 1.08, -0.2, g);
      // handlebars
      rod([0, 1.0, 0.35], [0, 1.25, 0.4], 0.03, M.black(), g, 8);
      rod([-0.38, 1.25, 0.38], [0.38, 1.25, 0.38], 0.02, M.black(), g, 8);
      for (const x of [-0.36, 0.36]) cyl(0.03, 0.03, 0.12, M.rubber(), x, 1.25, 0.38, g, 8).rotation.z = Math.PI / 2;
      box(0.18, 0.08, 0.06, M.black(), 0, 1.22, 0.45, g);
      // racks (tubular)
      for (const z of [0.75, -0.75]) {
        for (let i = 0; i < 4; i++) rod([-0.3 + i * 0.2, 1.0, z - 0.2], [-0.3 + i * 0.2, 1.0, z + 0.2], 0.012, M.black(), g, 6);
        rod([-0.35, 1.0, z - 0.2], [0.35, 1.0, z - 0.2], 0.015, M.black(), g, 6);
        rod([-0.35, 1.0, z + 0.2], [0.35, 1.0, z + 0.2], 0.015, M.black(), g, 6);
      }
      headlight(0.06, g, -0.2, 0.82, 0.92); headlight(0.06, g, 0.2, 0.82, 0.92);
      box(0.3, 0.05, 0.03, M.tail(), 0, 0.82, -0.92, g);
      // winch + plow
      cyl(0.07, 0.07, 0.26, M.dark(), 0, 0.5, 1.0, g, 12).rotation.z = Math.PI / 2;
      rod([-0.25, 0.4, 0.6], [-0.3, 0.3, 1.35], 0.025, M.dark(), g, 6);
      rod([0.25, 0.4, 0.6], [0.3, 0.3, 1.35], 0.025, M.dark(), g, 6);
      plowBlade(1.6, 0.42, '#212121', g, 0, 0.02, 1.45);
      setLoad(snowLoad(0.6, 0.3, 0.4), 0, 1.02, -0.75);
      ud.seat.set(0, 1.08, -0.25);
      break;
    }
    case 'snowmobile': {
      const paint = mat('#00897b', { metalness: 0.4, roughness: 0.25 });
      const accent = mat('#ffeb3b');
      // tunnel + track
      box(0.55, 0.12, 1.6, M.dark(), 0, 0.42, -0.4, g);
      const tr = track(1.3, 0.16, 0.42, '#1a1a1a', { roadWheels: 4, pitch: 0.12 });
      tr.position.set(0, 0.2, -0.45); g.add(tr); ud.tracks.push(tr);
      // cowl / hood
      sideProfile([[1.0, 0.35], [1.05, 0.5], [0.8, 0.8], [0.35, 0.95], [0.25, 0.6], [0.2, 0.35]], 0.75, paint, g);
      box(0.76, 0.06, 0.4, accent, 0, 0.6, 0.65, g);
      const ws = box(0.6, 0.35, 0.02, M.glass(), 0, 1.1, 0.38, g); ws.rotation.x = -0.5;
      headlight(0.07, g, -0.15, 0.62, 1.03); headlight(0.07, g, 0.15, 0.62, 1.03);
      // skis + spindles
      for (const s of [-1, 1]) {
        rod([s * 0.3, 0.45, 0.6], [s * 0.42, 0.12, 0.7], 0.025, M.dark(), g, 6);
        box(0.12, 0.04, 1.0, M.black(), s * 0.42, 0.06, 0.75, g);
        const tip = new THREE.Mesh(new THREE.TorusGeometry(0.12, 0.02, 6, 10, Math.PI / 2), M.black());
        tip.rotation.y = -Math.PI / 2; tip.position.set(s * 0.42, 0.18, 1.25); g.add(tip);
        rod([s * 0.42, 0.18, 0.55], [s * 0.42, 0.18, 0.95], 0.015, M.chrome(), g, 6);
      }
      // seat, bars, tail
      roundedBox(0.42, 0.18, 1.0, 0.06, M.seat(), 0, 0.6, -0.45, g);
      rod([-0.35, 1.0, 0.3], [0.35, 1.0, 0.3], 0.02, M.black(), g, 8);
      rod([0, 0.8, 0.35], [0, 1.0, 0.3], 0.03, M.black(), g, 8);
      box(0.4, 0.05, 0.03, M.tail(), 0, 0.5, -1.21, g);
      rod([-0.2, 0.55, -1.2], [-0.2, 0.75, -1.3], 0.015, M.chrome(), g, 6);
      rod([0.2, 0.55, -1.2], [0.2, 0.75, -1.3], 0.015, M.chrome(), g, 6);
      // tow sled
      const sled = new THREE.Group(); sled.position.set(0, 0, -2.3); g.add(sled);
      rod([0, 0.3, 1.0], [0, 0.25, 0.55], 0.025, M.dark(), sled, 6);
      box(0.9, 0.3, 1.1, mat('#004d40'), 0, 0.3, 0, sled);
      for (const s of [-1, 1]) box(0.06, 0.04, 1.2, M.chrome(), s * 0.38, 0.12, 0, sled);
      setLoad(snowLoad(0.8, 0.4, 0.95), 0, 0.45, -2.3);
      ud.seat.set(0, 0.68, -0.4);
      break;
    }
    case 'pickup': {
      const paint = mat('#37474f', { metalness: 0.55, roughness: 0.3 });
      box(1.7, 0.25, 4.6, M.dark(), 0, 0.6, 0, g); // frame
      // cab + hood profile
      sideProfile([[2.3, 0.75], [2.3, 1.2], [1.2, 1.35], [0.7, 1.35], [0.4, 2.0], [-0.55, 2.0], [-0.6, 0.75]], 1.9, paint, g);
      // windows
      const wf = box(1.7, 0.6, 0.02, M.glass(), 0, 1.67, 0.56, g); wf.rotation.x = -0.6;
      for (const s of [-1, 1]) box(0.02, 0.5, 0.85, M.glass(), s * 0.955, 1.65, -0.1, g);
      box(1.6, 0.45, 0.02, M.glass(), 0, 1.68, -0.61, g);
      // bed
      box(1.9, 0.1, 2.0, paint, 0, 0.85, -1.65, g);
      for (const s of [-1, 1]) box(0.08, 0.55, 2.0, paint, s * 0.91, 1.15, -1.65, g);
      box(1.9, 0.55, 0.08, paint, 0, 1.15, -2.62, g);
      box(1.82, 0.04, 0.04, M.chrome(), 0, 1.45, -2.62, g);
      // salt spreader
      const sp = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.12, 0.6, 4), mat('#ef6c00')); sp.rotation.y = Math.PI / 4; sp.position.set(0, 1.5, -2.3); g.add(sp);
      const spinner = cyl(0.2, 0.2, 0.03, M.black(), 0, 0.75, -2.85, g, 12); spin(spinner, 'y', 2);
      // grille, lights, bumper
      box(1.4, 0.4, 0.04, M.chrome(), 0, 1.0, 2.31, g);
      for (let i = 0; i < 5; i++) box(1.3, 0.03, 0.05, M.black(), 0, 0.85 + i * 0.07, 2.32, g);
      for (const s of [-1, 1]) { box(0.3, 0.15, 0.05, M.light(), s * 0.75, 1.1, 2.31, g); box(0.12, 0.3, 0.04, M.tail(), s * 0.9, 1.15, -2.66, g); }
      box(1.95, 0.18, 0.2, M.chrome(), 0, 0.68, -2.7, g);
      // light bar
      box(1.4, 0.08, 0.15, M.black(), 0, 2.06, -0.1, g);
      for (let i = 0; i < 6; i++) box(0.18, 0.05, 0.02, i % 2 ? M.amber() : M.light(), -0.55 + i * 0.22, 2.06, -0.02, g);
      mirror(g, 0.95, 1.5, 0.45, 1); mirror(g, -0.95, 1.5, 0.45, -1);
      // wheels + arches
      for (const [x, z] of [[-0.85, 1.5], [0.85, 1.5], [-0.85, -1.6], [0.85, -1.6]]) addWheel(0.45, 0.32, x, 0.45, z, { lugs: 22, nuts: 8 });
      // V-plow
      for (const s of [-1, 1]) {
        const half = plowBlade(1.5, 0.8, '#f9a825', g, s * 0.68, 0.02, 3.05, { ribs: 4 });
        half.rotation.y = s * 0.35;
      }
      box(0.6, 0.4, 0.5, M.dark(), 0, 0.6, 2.6, g);
      rod([0, 0.6, 2.35], [0, 1.1, 2.6], 0.05, M.chrome(), g, 8);
      setLoad(snowLoad(1.6, 0.5, 1.8), 0, 0.9, -1.65);
      seatModel(g, -0.4, 1.0, -0.2, 1);
      steeringWheel(g, -0.4, 1.45, 0.25, 1.1);
      ud.seat.set(-0.4, 1.05, -0.2);
      break;
    }
    case 'skidsteer': {
      const paint = mat('#f9a825', { metalness: 0.3, roughness: 0.35 });
      box(1.5, 0.7, 2.2, paint, 0, 0.8, -0.2, g);
      box(1.52, 0.1, 2.22, M.black(), 0, 0.48, -0.2, g);
      // engine grille at back
      for (let i = 0; i < 6; i++) box(1.0, 0.04, 0.04, M.black(), 0, 0.7 + i * 0.1, -1.32, g);
      box(0.3, 0.2, 0.04, M.tail(), -0.6, 1.05, -1.32, g); box(0.3, 0.2, 0.04, M.tail(), 0.6, 1.05, -1.32, g);
      // ROPS cab with cage
      const cabM = M.black();
      for (const [x, z] of [[-0.55, 0.45], [0.55, 0.45], [-0.55, -0.7], [0.55, -0.7]]) box(0.08, 1.2, 0.08, cabM, x, 1.75, z, g);
      box(1.2, 0.1, 1.25, paint, 0, 2.38, -0.12, g);
      for (let i = 0; i < 6; i++) box(0.02, 1.1, 0.02, cabM, -0.45 + i * 0.18, 1.75, 0.47, g); // front cage
      box(1.0, 1.0, 0.02, M.glass(), 0, 1.75, -0.72, g);
      for (const s of [-1, 1]) box(0.02, 1.0, 1.1, M.glass(), s * 0.56, 1.75, -0.12, g);
      seatModel(g, 0, 1.22, -0.25, 1);
      for (const s of [-1, 1]) rod([s * 0.25, 1.2, 0.05], [s * 0.25, 1.45, 0.15], 0.02, M.black(), g, 6);
      beacon(g, 0.4, 2.43, -0.5);
      // lift arms
      for (const s of [-1, 1]) {
        rod([s * 0.82, 1.9, -0.9], [s * 0.82, 1.3, 0.7], 0.08, paint, g, 8);
        rod([s * 0.82, 1.3, 0.7], [s * 0.82, 0.5, 1.25], 0.08, paint, g, 8);
        rod([s * 0.82, 0.8, -0.2], [s * 0.82, 1.4, 0.6], 0.05, M.chrome(), g, 8); // ram
      }
      // bucket
      const bucket = new THREE.Group(); bucket.position.set(0, 0.05, 1.4); g.add(bucket);
      box(2.0, 0.05, 0.85, M.dark(), 0, 0, 0.1, bucket);
      box(2.0, 0.9, 0.05, M.dark(), 0, 0.45, -0.32, bucket);
      for (const s of [-1, 1]) sideProfile([[-0.32, 0], [0.52, 0], [-0.32, 0.9]], 0.05, M.dark(), bucket, s * 1.0);
      box(2.0, 0.04, 0.08, M.steel(), 0, 0.02, 0.55, bucket);
      for (let i = 0; i < 6; i++) box(0.08, 0.06, 0.15, M.steel(), -0.85 + i * 0.34, 0.02, 0.62, bucket);
      setLoad(snowLoad(1.8, 0.6, 0.75), 0, 0.1, 1.5);
      for (const [x, z] of [[-0.85, 0.5], [0.85, 0.5], [-0.85, -0.85], [0.85, -0.85]]) addWheel(0.42, 0.34, x, 0.42, z, { lugs: 14, rim: '#f9a825' });
      headlight(0.06, g, -0.62, 2.25, 0.5); headlight(0.06, g, 0.62, 2.25, 0.5);
      ud.seat.set(0, 1.28, -0.25);
      break;
    }
    case 'resurfacer': {
      const paint = mat('#1565c0', { metalness: 0.3, roughness: 0.3 });
      const white = mat('#eceff1', { metalness: 0.2, roughness: 0.4 });
      // main body + tall snow tank at front
      roundedBox(2.0, 1.0, 3.6, 0.12, white, 0, 0.95, 0, g);
      box(2.04, 0.18, 3.64, paint, 0, 0.55, 0, g);
      box(2.04, 0.1, 3.64, paint, 0, 1.3, 0, g);
      // tank walls (open top so the load shows)
      const tank = new THREE.Group(); tank.position.set(0, 1.45, 0.6); g.add(tank);
      box(2.0, 0.9, 0.06, white, 0, 0.45, 1.2, tank);
      box(2.0, 0.9, 0.06, white, 0, 0.45, -0.95, tank);
      for (const s of [-1, 1]) box(0.06, 0.9, 2.2, white, s * 0.98, 0.45, 0.12, tank);
      for (const z of [1.2, -0.95]) box(2.08, 0.1, 0.12, paint, 0, 0.92, z, tank);
      for (const sx of [-1, 1]) box(0.12, 0.1, 2.26, paint, sx * 0.98, 0.92, 0.12, tank);
      box(0.06, 0.06, 2.2, M.steel(), 0, 0.97, 0.12, tank); // centre rail
      setLoad(snowLoad(1.85, 0.8, 2.0), 0, 1.45, 0.75);
      // logo stripe
      for (const s of [-1, 1]) box(0.02, 0.2, 2.6, mat('#e53935'), s * 1.03, 1.05, 0, g);
      // operator platform at rear-left with seat and wheel
      box(0.9, 0.1, 1.0, M.dark(), -0.55, 1.45, -1.3, g);
      seatModel(g, -0.55, 1.55, -1.45, 1, '#1565c0');
      steeringWheel(g, -0.55, 1.95, -0.95, 0.5);
      box(0.6, 0.6, 0.12, M.dark(), -0.55, 1.75, -0.8, g); // dash
      for (let i = 0; i < 3; i++) sphere(0.03, mat(['#4caf50', '#ffeb3b', '#f44336'][i], { emissive: ['#2e7d32', '#f9a825', '#c62828'][i] }), -0.75 + i * 0.2, 1.95, -0.73, g, 8);
      // rear conditioner + towel
      box(2.2, 0.35, 0.4, M.steel(), 0, 0.3, -2.0, g);
      box(2.1, 0.06, 0.6, mat('#90caf9'), 0, 0.05, -2.4, g);
      const cond = auger(2.0, 0.14, M.steel()); cond.position.set(0, 0.25, -2.0); g.add(cond); spin(cond, 'x', 6);
      // side brushes
      for (const s of [-1, 1]) {
        const br = cyl(0.25, 0.25, 0.08, mat('#212121'), s * 1.05, 0.1, -1.8, g, 18); spin(br, 'y', 5 * s);
        for (let i = 0; i < 12; i++) { const a = (i / 12) * Math.PI * 2; box(0.02, 0.08, 0.12, mat('#ffca28'), s * 1.05 + Math.cos(a) * 0.25, 0.08, -1.8 + Math.sin(a) * 0.25, g); }
      }
      // headlights + rotating beacon
      headlight(0.08, g, -0.6, 0.8, 1.82); headlight(0.08, g, 0.6, 0.8, 1.82);
      beacon(g, 0.6, 2.55, 1.7);
      // water tank fill pipes
      rod([0.85, 1.4, -1.6], [0.85, 1.9, -1.6], 0.05, M.chrome(), g, 10);
      for (const [x, z] of [[-1.0, 1.2], [1.0, 1.2], [-1.0, -1.2], [1.0, -1.2]]) addWheel(0.42, 0.3, x, 0.42, z, { lugs: 16 });
      ud.seat.set(-0.55, 1.6, -1.45);
      break;
    }
    case 'snowcat': {
      const paint = mat('#e53935', { metalness: 0.3, roughness: 0.35 });
      // tracks
      for (const s of [-1, 1]) {
        const tr = track(3.4, 0.5, 0.9, '#2a2a2a', { roadWheels: 6, pitch: 0.2, wheel: '#555' });
        tr.position.set(s * 1.35, 0.5, -0.2); g.add(tr); ud.tracks.push(tr);
        box(1.0, 0.08, 4.3, paint, s * 1.35, 1.08, -0.2, g); // fender
      }
      // body
      box(1.8, 0.8, 4.2, M.dark(), 0, 1.0, -0.2, g);
      sideProfile([[2.0, 1.4], [2.0, 2.0], [1.2, 2.1], [1.1, 2.1], [0.9, 3.2], [-0.8, 3.25], [-0.9, 2.1], [-2.3, 2.1], [-2.3, 1.4]], 2.4, paint, g);
      // big cab windows
      const front = box(2.2, 0.95, 0.02, M.glass(), 0, 2.65, 1.0, g); front.rotation.x = -0.18;
      for (const s of [-1, 1]) box(0.02, 0.85, 1.55, M.glass(), s * 1.21, 2.65, 0.15, g);
      box(2.1, 0.8, 0.02, M.glass(), 0, 2.65, -0.81, g);
      for (const s of [-1, 1]) box(0.08, 1.1, 0.08, M.black(), s * 1.2, 2.65, 0.95, g);
      // roof light bar + beacons
      box(2.0, 0.12, 0.25, M.black(), 0, 3.32, 0.75, g);
      for (let i = 0; i < 6; i++) box(0.22, 0.08, 0.02, M.light(), -0.8 + i * 0.32, 3.32, 0.88, g);
      beacon(g, -0.8, 3.27, -0.6); beacon(g, 0.8, 3.27, -0.6);
      // exhaust stack + grille
      cyl(0.06, 0.06, 0.8, M.chrome(), 0.9, 2.5, -1.8, g, 10);
      for (let i = 0; i < 5; i++) box(2.0, 0.04, 0.04, M.black(), 0, 1.5 + i * 0.1, 2.01, g);
      headlight(0.1, g, -0.8, 1.9, 2.0); headlight(0.1, g, 0.8, 1.9, 2.0);
      seatModel(g, -0.45, 2.15, 0.1, 1.1);
      steeringWheel(g, -0.45, 2.55, 0.6, 0.7);
      // 12-way front blade on hydraulic arms
      for (const s of [-1, 1]) { rod([s * 0.9, 1.1, 1.6], [s * 1.1, 0.7, 2.8], 0.09, M.dark(), g, 8); rod([s * 0.5, 1.5, 1.9], [s * 0.6, 1.0, 2.8], 0.05, M.chrome(), g, 8); }
      plowBlade(4.0, 1.1, '#e53935', g, 0, 0.02, 3.2, { ribs: 8 });
      // rear tiller + finisher comb
      box(3.6, 0.5, 0.7, paint, 0, 0.6, -2.9, g);
      const till = auger(3.4, 0.25, M.steel()); till.position.set(0, 0.35, -2.9); g.add(till); spin(till, 'x', 5);
      box(3.6, 0.04, 0.6, mat('#9e9e9e'), 0, 0.08, -3.45, g);
      for (let i = 0; i < 24; i++) box(0.02, 0.05, 0.08, M.dark(), -1.75 + i * 0.152, 0.05, -3.78, g);
      // cargo bed behind cab for the load
      box(1.9, 0.1, 1.2, M.dark(), 0, 2.15, -1.55, g);
      for (const s of [-1, 1]) box(0.05, 0.4, 1.2, paint, s * 0.95, 2.35, -1.55, g);
      setLoad(snowLoad(1.75, 0.6, 1.1), 0, 2.2, -1.55);
      ud.seat.set(-0.45, 2.22, 0.1);
      break;
    }
    case 'loader': {
      const paint = mat('#fbc02d', { metalness: 0.3, roughness: 0.35 });
      // rear frame (engine + cab)
      const rear = new THREE.Group(); g.add(rear);
      box(2.0, 1.2, 2.6, paint, 0, 1.5, -1.4, rear);
      box(2.1, 0.3, 0.6, M.dark(), 0, 1.0, -2.8, rear); // counterweight
      for (let i = 0; i < 6; i++) box(1.6, 0.05, 0.05, M.black(), 0, 1.4 + i * 0.12, -2.71, rear); // grille
      cyl(0.08, 0.08, 1.0, M.dark(), 0.6, 2.5, -2.2, rear, 10); // exhaust
      cyl(0.12, 0.12, 0.3, M.dark(), -0.6, 2.25, -2.3, rear, 10); // pre-cleaner
      // cab
      box(1.6, 0.1, 1.6, paint, 0, 3.55, -0.6, rear);
      for (const [x, z] of [[-0.75, 0.15], [0.75, 0.15], [-0.75, -1.35], [0.75, -1.35]]) box(0.08, 1.4, 0.08, M.black(), x, 2.85, z, rear);
      const fw = box(1.45, 1.3, 0.02, M.glass(), 0, 2.85, 0.17, rear); fw.rotation.x = -0.05;
      box(1.45, 1.2, 0.02, M.glass(), 0, 2.85, -1.36, rear);
      for (const s of [-1, 1]) box(0.02, 1.25, 1.45, M.glass(), s * 0.77, 2.85, -0.6, rear);
      seatModel(rear, 0, 2.2, -0.8, 1.1);
      steeringWheel(rear, 0, 2.6, -0.2, 0.7);
      beacon(rear, 0.6, 3.6, -1.2);
      for (const s of [-1, 1]) { headlight(0.07, rear, s * 0.65, 3.5, 0.2); mirror(rear, s * 0.8, 3.1, 0.15, s); }
      // ladder
      for (let i = 0; i < 4; i++) box(0.3, 0.03, 0.12, M.steel(), -1.05, 0.8 + i * 0.3, -0.4, rear);
      // articulation joint
      cyl(0.25, 0.25, 0.6, M.dark(), 0, 1.0, 0.1, g, 14);
      // front frame
      box(1.6, 0.7, 1.6, paint, 0, 1.0, 1.0, g);
      // lift arms (Z-bar) + tilt cylinder
      for (const s of [-1, 1]) {
        rod([s * 0.7, 1.4, 0.4], [s * 0.7, 1.4, 2.4], 0.14, paint, g, 8);
        rod([s * 0.7, 1.4, 2.4], [s * 0.7, 0.8, 3.0], 0.14, paint, g, 8);
        rod([s * 0.5, 0.9, 0.6], [s * 0.5, 1.3, 1.8], 0.08, M.chrome(), g, 8);
      }
      rod([0, 1.9, 1.0], [0, 1.6, 2.4], 0.1, M.chrome(), g, 8);
      // bucket
      const bucket = new THREE.Group(); bucket.position.set(0, 0.06, 3.2); g.add(bucket);
      const curve = new THREE.Mesh(new THREE.CylinderGeometry(0.75, 0.75, 3.0, 20, 1, true, Math.PI * 0.5, Math.PI * 0.75), M.dark().clone());
      curve.material.side = THREE.DoubleSide; curve.rotation.z = Math.PI / 2; curve.position.set(0, 0.75, 0.1); bucket.add(curve);
      for (const s of [-1, 1]) sideProfile([[-0.6, 0.0], [0.85, 0.0], [-0.65, 1.4]], 0.06, M.dark(), bucket, s * 1.5);
      box(3.0, 0.05, 0.12, M.steel(), 0, 0.02, 0.8, bucket);
      for (let i = 0; i < 8; i++) box(0.12, 0.08, 0.2, M.steel(), -1.3 + i * 0.37, 0.03, 0.9, bucket);
      setLoad(snowLoad(2.8, 0.8, 1.2), 0, 0.1, 3.25);
      // huge tyres
      for (const [x, z] of [[-1.15, 1.0], [1.15, 1.0], [-1.15, -1.5], [1.15, -1.5]]) addWheel(0.85, 0.6, x, 0.85, z, { lugs: 20, rim: '#fbc02d', nuts: 10 });
      ud.seat.set(0, 2.3, -0.8);
      break;
    }
    case 'rotary': {
      const paint = mat('#ff6f00', { metalness: 0.35, roughness: 0.35 });
      const white = mat('#eceff1');
      box(2.0, 0.35, 7.0, M.dark(), 0, 0.85, -0.6, g); // frame
      // cab (cab-forward)
      box(2.4, 1.6, 1.8, paint, 0, 2.1, 1.6, g);
      box(2.42, 0.2, 1.82, white, 0, 1.6, 1.6, g);
      box(2.2, 0.85, 0.02, M.glass(), 0, 2.45, 2.51, g);
      for (const s of [-1, 1]) box(0.02, 0.75, 1.3, M.glass(), s * 1.21, 2.45, 1.7, g);
      box(2.2, 0.15, 0.3, M.black(), 0, 3.0, 2.3, g);
      for (let i = 0; i < 6; i++) box(0.25, 0.08, 0.02, M.light(), -0.8 + i * 0.32, 3.0, 2.46, g);
      beacon(g, -1.0, 2.95, 1.0); beacon(g, 1.0, 2.95, 1.0);
      for (const s of [-1, 1]) mirror(g, s * 1.2, 2.6, 2.3, s);
      seatModel(g, -0.5, 1.75, 1.4, 1.1);
      steeringWheel(g, -0.5, 2.2, 2.0, 0.9);
      // engine housing behind cab
      box(2.3, 1.4, 2.0, paint, 0, 2.0, -0.4, g);
      for (let i = 0; i < 8; i++) box(0.02, 0.9, 1.4, M.black(), 1.16, 2.0, -1.0 + i * 0.18, g); // louvres
      cyl(0.1, 0.1, 1.4, M.chrome(), 0.9, 3.2, -0.9, g, 12);
      // hopper (load)
      box(2.4, 0.12, 2.8, paint, 0, 1.1, -2.9, g);
      for (const s of [-1, 1]) box(0.08, 1.2, 2.8, paint, s * 1.18, 1.7, -2.9, g);
      box(2.4, 1.2, 0.08, paint, 0, 1.7, -4.28, g);
      box(2.4, 1.2, 0.08, paint, 0, 1.7, -1.52, g);
      for (let i = 0; i < 5; i++) box(0.05, 1.1, 0.05, M.dark(), 1.24, 1.7, -4.1 + i * 0.6, g);
      setLoad(snowLoad(2.25, 1.0, 2.6), 0, 1.15, -2.9);
      for (const s of [-1, 1]) box(0.15, 0.3, 0.05, M.tail(), s * 1.05, 0.9, -4.35, g);
      // rotary blower head: two contra-rotating drums + impeller + chute
      const head = new THREE.Group(); head.position.set(0, 0, 3.0); g.add(head);
      box(3.4, 1.6, 0.1, paint, 0, 1.0, -0.5, head); // back plate
      box(3.4, 0.1, 1.2, paint, 0, 1.75, 0.05, head); // top hood
      for (const s of [-1, 1]) box(0.1, 1.6, 1.2, paint, s * 1.7, 1.0, 0.05, head);
      box(3.4, 0.08, 0.15, M.steel(), 0, 0.06, 0.6, head);
      for (const s of [-1, 1]) {
        const drum = new THREE.Group(); drum.position.set(s * 0.85, 0.85, 0.1); head.add(drum);
        cyl(0.12, 0.12, 0.9, M.steel(), 0, 0, 0, drum, 10).rotation.x = Math.PI / 2;
        for (let i = 0; i < 30; i++) {
          const t = i / 30, a = t * Math.PI * 4;
          const fl = box(0.08, 0.6, 0.05, mat('#fdd835', { metalness: 0.4 }), Math.cos(a) * 0.4, Math.sin(a) * 0.4, -0.4 + t * 0.85, drum);
          fl.rotation.z = a;
        }
        spin(drum, 'z', 4 * s);
      }
      const chute = cyl(0.25, 0.32, 1.6, paint, 0, 2.5, -0.3, head, 16);
      const hood = box(0.6, 0.25, 0.7, paint, 0, 3.3, -0.05, head); hood.rotation.x = 0.35;
      // wheels: front axle + tandem rear
      for (const z of [1.0, -2.3, -3.6]) for (const s of [-1, 1]) addWheel(0.55, 0.4, s * 1.05, 0.55, z, { lugs: 22, nuts: 10 });
      headlight(0.09, g, -0.9, 1.35, 2.52); headlight(0.09, g, 0.9, 1.35, 2.52);
      ud.seat.set(-0.5, 1.8, 1.4);
      break;
    }
  }
  shadow(g);
  if (ud.load) ud.load.traverse((c) => { if (c.isMesh) c.castShadow = false; });
  return g;
}

// ---------------------------------------------------------------- vendors & props
export function buildVendor(opts) {
  const npc = buildCharacter({ coat: opts.coat, hat: opts.hat, scarf: opts.scarf, pants: '#3e2723' });
  return npc;
}

// Market stall: counter, striped awning, sign board.
export function buildStall({ color = '#c62828', stripe = '#fafafa', sign = '', width = 3.4 }) {
  const g = new THREE.Group();
  const wood = M.wood();
  box(width, 1.0, 0.8, wood, 0, 0.5, 0.6, g);
  box(width + 0.1, 0.08, 0.95, mat('#6d4c41'), 0, 1.04, 0.6, g);
  for (const x of [-width / 2 + 0.1, width / 2 - 0.1]) {
    box(0.12, 2.6, 0.12, wood, x, 1.3, 0.95, g);
    box(0.12, 2.9, 0.12, wood, x, 1.45, -0.4, g);
  }
  box(width, 2.6, 0.1, mat('#8d6e63'), 0, 1.4, -0.45, g); // back wall
  // striped awning
  const stripes = 9;
  for (let i = 0; i < stripes; i++) {
    const w = width / stripes;
    const a = box(w, 0.06, 1.7, mat(i % 2 ? stripe : color), -width / 2 + w * (i + 0.5), 2.85, 0.4, g);
    a.rotation.x = 0.22;
    const flap = box(w, 0.3, 0.04, mat(i % 2 ? stripe : color), -width / 2 + w * (i + 0.5), 2.55, 1.25, g);
  }
  // snow on awning
  const snowCap = box(width, 0.08, 1.6, M.snow(), 0, 2.93, 0.38, g); snowCap.rotation.x = 0.22;
  // sign
  if (sign) {
    const c = document.createElement('canvas'); c.width = 512; c.height = 128;
    const x = c.getContext('2d');
    x.fillStyle = '#3e2723'; x.fillRect(0, 0, 512, 128);
    x.strokeStyle = '#ffd54f'; x.lineWidth = 8; x.strokeRect(6, 6, 500, 116);
    x.fillStyle = '#fff8e1'; x.font = 'bold 56px system-ui, sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle';
    x.fillText(sign, 256, 68);
    const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace;
    const s = new THREE.Mesh(new THREE.PlaneGeometry(width * 0.8, width * 0.2), new THREE.MeshStandardMaterial({ map: tex, roughness: 0.8 }));
    s.position.set(0, 3.35, -0.3); g.add(s);
    box(width * 0.82, width * 0.22, 0.06, mat('#3e2723'), 0, 3.35, -0.34, g);
  }
  shadow(g);
  return g;
}

export function makeLabel(text, sub = '', color = '#ffffff') {
  const c = document.createElement('canvas'); c.width = 512; c.height = 160;
  const x = c.getContext('2d');
  x.fillStyle = 'rgba(15,30,55,0.82)';
  const r = 30; x.beginPath(); x.roundRect(4, 4, 504, 152, r); x.fill();
  x.fillStyle = color; x.font = 'bold 54px system-ui, sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle';
  x.fillText(text, 256, sub ? 58 : 80);
  if (sub) { x.fillStyle = '#ffd54f'; x.font = 'bold 40px system-ui, sans-serif'; x.fillText(sub, 256, 116); }
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace;
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthWrite: false }));
  s.scale.set(2.4, 0.75, 1);
  return s;
}

// Merge every mesh under `root` into one mesh per material (huge draw-call saver
// for static scenery). Returns a new Group; `root` is left untouched.
import { mergeGeometries } from '../vendor/BufferGeometryUtils.js';
export function bake(root, { castShadow = true, receiveShadow = true } = {}) {
  root.updateMatrixWorld(true);
  const inv = new THREE.Matrix4().copy(root.matrixWorld).invert();
  const buckets = new Map();
  root.traverse((o) => {
    if (!o.isMesh) return;
    let geo = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry.clone();
    for (const k of Object.keys(geo.attributes)) if (!['position', 'normal', 'uv'].includes(k)) geo.deleteAttribute(k);
    if (!geo.attributes.uv) geo.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(geo.attributes.position.count * 2), 2));
    geo.applyMatrix4(new THREE.Matrix4().multiplyMatrices(inv, o.matrixWorld));
    if (!buckets.has(o.material)) buckets.set(o.material, []);
    buckets.get(o.material).push(geo);
  });
  const out = new THREE.Group();
  for (const [m, geos] of buckets) {
    const merged = mergeGeometries(geos, false);
    geos.forEach((g) => g.dispose());
    const mesh = new THREE.Mesh(merged, m);
    mesh.castShadow = castShadow && !m.transparent; mesh.receiveShadow = receiveShadow;
    out.add(mesh);
  }
  out.position.copy(root.position); out.quaternion.copy(root.quaternion); out.scale.copy(root.scale);
  return out;
}
