// Neighbourhood: ground, roads, houses, trees, lamps, fence, plus collision boxes.
import * as THREE from 'three';
import { mat, box, cyl, bake } from './models.js';

export const WORLD_SIZE = 120;
export const HALF = WORLD_SIZE / 2;

// deterministic RNG so the neighbourhood is the same every visit
function rng(seed) {
  return () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
}

export const ROADS = [
  // [x0, z0, x1, z1]
  [-HALF, 13, HALF, 20],     // main street (north of plaza)
  [-HALF, -36, HALF, -29],   // south street
  [-36, -HALF, -29, HALF],   // west avenue
  [29, -HALF, 36, HALF],     // east avenue
];
export const PLAZA = [-14, -11, 14, 6];

export function buildWorld(scene, snow) {
  const colliders = []; // {x0,z0,x1,z1}
  const rand = rng(1337);

  // ---- ground texture (grass/dirt under snow, roads, plaza)
  const C = 1024;
  const cv = document.createElement('canvas'); cv.width = C; cv.height = C;
  const g = cv.getContext('2d');
  const toPx = (v) => ((v + HALF) / WORLD_SIZE) * C;
  g.fillStyle = '#6b7d55'; g.fillRect(0, 0, C, C);
  for (let i = 0; i < 6000; i++) { g.fillStyle = rand() < 0.5 ? '#5e7049' : '#76885e'; g.fillRect(rand() * C, rand() * C, 3, 3); }
  for (const [x0, z0, x1, z1] of ROADS) {
    g.fillStyle = '#4a4d52'; g.fillRect(toPx(x0), toPx(z0), toPx(x1) - toPx(x0), toPx(z1) - toPx(z0));
  }
  // road centre dashes
  g.fillStyle = '#e8c547';
  for (const [x0, z0, x1, z1] of ROADS) {
    const horiz = x1 - x0 > z1 - z0;
    if (horiz) { const zc = toPx((z0 + z1) / 2); for (let x = toPx(x0); x < toPx(x1); x += 24) g.fillRect(x, zc - 1, 12, 3); }
    else { const xc = toPx((x0 + x1) / 2); for (let z = toPx(z0); z < toPx(z1); z += 24) g.fillRect(xc - 1, z, 3, 12); }
  }
  // plaza cobbles
  const [px0, pz0, px1, pz1] = PLAZA;
  g.fillStyle = '#9c8f80'; g.fillRect(toPx(px0), toPx(pz0), toPx(px1) - toPx(px0), toPx(pz1) - toPx(pz0));
  g.strokeStyle = '#857869'; g.lineWidth = 1;
  for (let x = toPx(px0); x < toPx(px1); x += 6) { g.beginPath(); g.moveTo(x, toPx(pz0)); g.lineTo(x, toPx(pz1)); g.stroke(); }
  for (let z = toPx(pz0); z < toPx(pz1); z += 6) { g.beginPath(); g.moveTo(toPx(px0), z); g.lineTo(toPx(px1), z); g.stroke(); }
  const tex = new THREE.CanvasTexture(cv); tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 8;
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(WORLD_SIZE, WORLD_SIZE), new THREE.MeshStandardMaterial({ map: tex, roughness: 0.95 }));
  ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true;
  scene.add(ground);
  // outer snowfield beyond the fence
  const outer = new THREE.Mesh(new THREE.PlaneGeometry(600, 600), mat('#e9f0fa', { roughness: 1 }));
  outer.rotation.x = -Math.PI / 2; outer.position.y = -0.02; outer.receiveShadow = true;
  scene.add(outer);

  const stat = new THREE.Group();
  snow.block(px0, pz0, px1, pz1);

  // ---- houses
  const houseColors = ['#c0504d', '#4f81bd', '#9bbb59', '#f2c14e', '#8064a2', '#e98b5a', '#5fb3b3', '#d7d2c8', '#a9746e'];
  const onRoad = (x0, z0, x1, z1) => ROADS.some(([a, b, c, d]) => x1 > a - 1 && x0 < c + 1 && z1 > b - 1 && z0 < d + 1);
  const inPlaza = (x0, z0, x1, z1) => x1 > px0 - 6 && x0 < px1 + 6 && z1 > pz0 - 6 && z0 < pz1 + 6;
  const houses = [];
  const tryHouse = (cx, cz, facing) => {
    const w = 7 + rand() * 2, d = 6 + rand() * 1.5;
    const side = Math.abs(Math.sin(facing)) > 0.5; // rotated 90 degrees: footprint swaps
    const fw = side ? d : w, fd = side ? w : d;
    const x0 = cx - fw / 2, x1 = cx + fw / 2, z0 = cz - fd / 2, z1 = cz + fd / 2;
    if (Math.abs(cx) > HALF - 6 || Math.abs(cz) > HALF - 6) return;
    if (onRoad(x0, z0, x1, z1) || inPlaza(x0, z0, x1, z1)) return;
    if (houses.some((h) => x1 > h[0] - 3 && x0 < h[2] + 3 && z1 > h[1] - 3 && z0 < h[3] + 3)) return;
    houses.push([x0, z0, x1, z1]);
    const house = buildHouse(w, d, houseColors[Math.floor(rand() * houseColors.length)], rand);
    house.position.set(cx, 0, cz);
    house.rotation.y = facing;
    stat.add(house);
    colliders.push({ x0, z0, x1, z1 });
    snow.block(x0, z0, x1, z1);
  };
  // rows of houses facing the streets
  for (let x = -54; x <= 54; x += 11) {
    tryHouse(x, 26, Math.PI); tryHouse(x, 6, 0);       // around main street
    tryHouse(x, -42, 0); tryHouse(x, -22, Math.PI);    // around south street
    tryHouse(x, 46, Math.PI);
  }
  for (let z = -54; z <= 54; z += 11) {
    tryHouse(-46, z, Math.PI / 2); tryHouse(-19, z, -Math.PI / 2);
    tryHouse(46, z, -Math.PI / 2); tryHouse(19, z, Math.PI / 2);
  }

  // ---- pine trees
  const treeSpots = [];
  for (let i = 0; i < 140; i++) {
    const x = (rand() - 0.5) * (WORLD_SIZE - 6), z = (rand() - 0.5) * (WORLD_SIZE - 6);
    const r = 0.8;
    if (onRoad(x - r, z - r, x + r, z + r) || inPlaza(x - 2, z - 2, x + 2, z + 2)) continue;
    if (houses.some((h) => x > h[0] - 2 && x < h[2] + 2 && z > h[1] - 2 && z < h[3] + 2)) continue;
    if (treeSpots.some(([a, b]) => (a - x) ** 2 + (b - z) ** 2 < 25)) continue;
    treeSpots.push([x, z]);
    const t = buildTree(0.8 + rand() * 0.7);
    t.position.set(x, 0, z); t.rotation.y = rand() * 6;
    stat.add(t);
    colliders.push({ x0: x - 0.4, z0: z - 0.4, x1: x + 0.4, z1: z + 0.4 });
  }

  // ---- street lamps along roads
  for (let x = -50; x <= 50; x += 16) {
    for (const z of [12, 21, -28, -37]) addLamp(stat, x, z, colliders);
  }

  // ---- perimeter fence
  const fenceMat = mat('#7b5a3a', { roughness: 0.9 });
  for (const s of [-1, 1]) {
    for (const horiz of [true, false]) {
      for (let t = -HALF; t <= HALF; t += 3) {
        const x = horiz ? t : s * HALF, z = horiz ? s * HALF : t;
        cyl(0.08, 0.08, 1.3, fenceMat, x, 0.65, z, stat, 6).castShadow = true;
      }
      for (const y of [0.45, 0.95]) {
        const rail = box(horiz ? WORLD_SIZE : 0.06, 0.1, horiz ? 0.06 : WORLD_SIZE, fenceMat, horiz ? 0 : s * HALF, y, horiz ? s * HALF : 0, stat);
        rail.castShadow = true;
      }
    }
  }

  // distant hills
  for (let i = 0; i < 18; i++) {
    const a = (i / 18) * Math.PI * 2;
    const hill = new THREE.Mesh(new THREE.SphereGeometry(30 + rand() * 25, 16, 8, 0, Math.PI * 2, 0, Math.PI / 2), mat('#f2f6fc', { roughness: 1 }));
    hill.position.set(Math.cos(a) * 160, -6, Math.sin(a) * 160); hill.scale.y = 0.5 + rand() * 0.4;
    stat.add(hill);
    for (let k = 0; k < 6; k++) {
      const t = buildTree(2 + rand() * 1.5);
      const r = 105 + rand() * 30;
      const b = a + (rand() - 0.5) * 0.3;
      t.position.set(Math.cos(b) * r, 0, Math.sin(b) * r);
      stat.add(t);
    }
  }

  scene.add(bake(stat));

  return { colliders };
}

function buildHouse(w, d, color, rand) {
  const g = new THREE.Group();
  const wall = mat(color, { roughness: 0.85 });
  const trim = mat('#f5f1e8');
  const roofM = mat('#5d4037', { roughness: 0.9 });
  const h = 3.2;
  box(w, h, d, wall, 0, h / 2, 0, g);
  box(w + 0.1, 0.3, d + 0.1, mat('#8e8e8e'), 0, 0.15, 0, g); // foundation
  // gabled roof (prism) along X
  const shape = new THREE.Shape();
  shape.moveTo(-d / 2 - 0.5, 0); shape.lineTo(d / 2 + 0.5, 0); shape.lineTo(0, 2.2); shape.lineTo(-d / 2 - 0.5, 0);
  const rg = new THREE.ExtrudeGeometry(shape, { depth: w + 0.8, bevelEnabled: false });
  rg.translate(0, 0, -(w + 0.8) / 2); rg.rotateY(Math.PI / 2);
  const roof = new THREE.Mesh(rg, roofM); roof.position.y = h; g.add(roof);
  // snow on roof: slightly bigger, thinner prism on top
  const sShape = new THREE.Shape();
  sShape.moveTo(-d / 2 - 0.6, 0.05); sShape.lineTo(d / 2 + 0.6, 0.05); sShape.lineTo(0, 2.42); sShape.lineTo(-d / 2 - 0.6, 0.05);
  const sg = new THREE.ExtrudeGeometry(sShape, { depth: w + 0.9, bevelEnabled: false });
  sg.translate(0, 0, -(w + 0.9) / 2); sg.rotateY(Math.PI / 2);
  const sn = new THREE.Mesh(sg, mat('#f7fbff', { roughness: 0.95 })); sn.position.y = h + 0.12; sn.scale.set(1, 1, 1); g.add(sn);
  // chimney
  box(0.7, 2, 0.7, mat('#8d4b3a'), w * 0.25, h + 1.6, -d * 0.15, g);
  box(0.8, 0.15, 0.8, mat('#f7fbff'), w * 0.25, h + 2.65, -d * 0.15, g);
  // front (+z) door, windows, porch
  box(1.1, 2.1, 0.08, mat('#5b3a29'), 0, 1.05, d / 2 + 0.04, g);
  box(0.08, 0.08, 0.1, mat('#d4af37', { metalness: 0.8 }), 0.4, 1.05, d / 2 + 0.1, g);
  box(1.3, 0.12, 0.1, trim, 0, 2.15, d / 2 + 0.05, g);
  const win = mat('#ffe7a3', { emissive: '#ffcf6b', emissiveIntensity: 0.6 });
  for (const x of [-w * 0.3, w * 0.3]) {
    box(1.2, 1.0, 0.06, win, x, 1.8, d / 2 + 0.03, g);
    box(1.35, 0.1, 0.12, trim, x, 1.25, d / 2 + 0.06, g);
    box(0.06, 1.0, 0.1, trim, x, 1.8, d / 2 + 0.06, g);
    box(1.2, 0.06, 0.1, trim, x, 1.8, d / 2 + 0.06, g);
  }
  for (const s of [-1, 1]) box(0.06, 1.0, 1.2, win, s * (w / 2 + 0.03), 1.8, 0, g);
  // porch step + wreath
  box(1.8, 0.2, 0.8, mat('#9e9e9e'), 0, 0.1, d / 2 + 0.4, g);
  const wreath = new THREE.Mesh(new THREE.TorusGeometry(0.22, 0.07, 8, 16), mat('#2e7d32')); wreath.position.set(0, 1.6, d / 2 + 0.12); g.add(wreath);
  const bow = new THREE.Mesh(new THREE.SphereGeometry(0.06, 8, 6), mat('#c62828')); bow.position.set(0, 1.4, d / 2 + 0.16); g.add(bow);
  // mailbox
  if (rand() > 0.4) {
    cyl(0.05, 0.05, 1.1, mat('#5d4037'), w * 0.45, 0.55, d / 2 + 2.6, g, 6);
    box(0.3, 0.25, 0.45, mat('#263238', { metalness: 0.5 }), w * 0.45, 1.2, d / 2 + 2.6, g);
  }
  g.traverse((c) => { if (c.isMesh) { c.castShadow = true; c.receiveShadow = true; } });
  return g;
}

export function buildTree(s = 1) {
  const g = new THREE.Group();
  cyl(0.18 * s, 0.25 * s, 1.2 * s, mat('#5d4037'), 0, 0.6 * s, 0, g, 8);
  const green = mat('#2f5d3a', { roughness: 0.9 });
  const snowM = mat('#f5f9ff', { roughness: 0.95 });
  for (let i = 0; i < 4; i++) {
    const r = (1.6 - i * 0.32) * s, h = 1.5 * s;
    const y = (1.2 + i * 0.95) * s;
    const c = new THREE.Mesh(new THREE.ConeGeometry(r, h, 9), green); c.position.y = y + h / 2; g.add(c);
    const sc = new THREE.Mesh(new THREE.ConeGeometry(r * 0.72, h * 0.45, 9), snowM); sc.position.y = y + h * 0.82; g.add(sc);
  }
  g.traverse((c) => { if (c.isMesh) { c.castShadow = true; } });
  return g;
}

function addLamp(scene, x, z, colliders) {
  const g = new THREE.Group();
  const iron = mat('#1f2a33', { metalness: 0.6, roughness: 0.4 });
  cyl(0.08, 0.12, 4, iron, 0, 2, 0, g, 8);
  cyl(0.2, 0.25, 0.3, iron, 0, 0.15, 0, g, 8);
  box(0.4, 0.5, 0.4, mat('#fff3c4', { emissive: '#ffd27a', emissiveIntensity: 1.3 }), 0, 4.2, 0, g);
  box(0.55, 0.08, 0.55, iron, 0, 4.48, 0, g);
  box(0.6, 0.08, 0.6, mat('#f5f9ff'), 0, 4.55, 0, g);
  g.position.set(x, 0, z);
  g.traverse((c) => { if (c.isMesh) c.castShadow = true; });
  scene.add(g);
  colliders.push({ x0: x - 0.2, z0: z - 0.2, x1: x + 0.2, z1: z + 0.2 });
}
