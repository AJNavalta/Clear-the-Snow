// Snow heightfield that can be harvested and slowly grows back.
import * as THREE from 'three';

export class SnowField {
  constructor({ size = 120, tile = 1, maxUnits = 6, unitHeight = 0.07, regrowSeconds = 40 }) {
    this.size = size;
    this.tile = tile;
    this.n = Math.round(size / tile);       // tiles per side
    this.maxUnits = maxUnits;
    this.unitHeight = unitHeight;
    this.regrowRate = maxUnits / regrowSeconds; // units per second per tile
    this.units = new Float32Array(this.n * this.n).fill(maxUnits);
    this.blocked = new Uint8Array(this.n * this.n);
    this.cooldown = new Float32Array(this.n * this.n); // seconds before a tile starts regrowing
    this.dirty = true;
    this.regrowTimer = 0;
    this.total = 0;

    const v = this.n + 1;
    const geo = new THREE.PlaneGeometry(size, size, this.n, this.n);
    geo.rotateX(-Math.PI / 2);
    const colors = new Float32Array(v * v * 3);
    geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    this.geo = geo;
    const m = new THREE.MeshStandardMaterial({ color: '#ffffff', vertexColors: true, roughness: 0.92, metalness: 0 });
    this.mesh = new THREE.Mesh(geo, m);
    this.mesh.receiveShadow = true;
    this.mesh.castShadow = false;
    // small random variation so the blanket isn't perfectly flat
    this.noise = new Float32Array(v * v);
    for (let i = 0; i < this.noise.length; i++) this.noise[i] = Math.random() * 0.04;
  }

  idx(i, j) { return j * this.n + i; }
  tileOf(x, z) {
    const i = Math.floor((x + this.size / 2) / this.tile);
    const j = Math.floor((z + this.size / 2) / this.tile);
    return [i, j];
  }

  // mark a world-space rectangle as not snowable (houses, plaza...)
  block(x0, z0, x1, z1) {
    const [i0, j0] = this.tileOf(Math.min(x0, x1), Math.min(z0, z1));
    const [i1, j1] = this.tileOf(Math.max(x0, x1) - 1e-3, Math.max(z0, z1) - 1e-3);
    for (let j = Math.max(0, j0); j <= Math.min(this.n - 1, j1); j++)
      for (let i = Math.max(0, i0); i <= Math.min(this.n - 1, i1); i++) {
        const k = this.idx(i, j);
        this.blocked[k] = 1; this.units[k] = 0;
      }
    this.dirty = true;
  }

  depthAt(x, z) {
    const [i, j] = this.tileOf(x, z);
    if (i < 0 || j < 0 || i >= this.n || j >= this.n) return 0;
    return this.units[this.idx(i, j)] * this.unitHeight;
  }

  // Remove up to `amount` units from tiles inside a circle. Returns units removed.
  harvest(x, z, radius, amount) {
    const r = Math.max(radius, this.tile * 0.5);
    const [i0, j0] = this.tileOf(x - r, z - r);
    const [i1, j1] = this.tileOf(x + r, z + r);
    const list = [];
    let avail = 0;
    for (let j = Math.max(0, j0); j <= Math.min(this.n - 1, j1); j++) {
      for (let i = Math.max(0, i0); i <= Math.min(this.n - 1, i1); i++) {
        const k = this.idx(i, j);
        if (this.blocked[k] || this.units[k] <= 0.001) continue;
        const cx = -this.size / 2 + (i + 0.5) * this.tile;
        const cz = -this.size / 2 + (j + 0.5) * this.tile;
        if ((cx - x) ** 2 + (cz - z) ** 2 > (r + this.tile * 0.5) ** 2) continue;
        list.push(k); avail += this.units[k];
      }
    }
    if (avail <= 0) return 0;
    const take = Math.min(amount, avail);
    const f = take / avail;
    for (const k of list) {
      this.units[k] -= this.units[k] * f;
      if (this.units[k] < 0.02) this.units[k] = 0;
      this.cooldown[k] = 6 + Math.random() * 6; // short pause before regrowing
    }
    this.dirty = true;
    return take;
  }

  update(dt) {
    this.regrowTimer += dt;
    if (this.regrowTimer >= 0.25) {
      const step = this.regrowTimer;
      this.regrowTimer = 0;
      const max = this.maxUnits, rate = this.regrowRate * step;
      const u = this.units, b = this.blocked, cd = this.cooldown;
      let changed = false;
      for (let k = 0; k < u.length; k++) {
        if (b[k] || u[k] >= max) continue;
        if (cd[k] > 0) { cd[k] -= step; continue; }
        u[k] = Math.min(max, u[k] + rate * (0.6 + Math.random() * 0.8));
        changed = true;
      }
      if (changed) this.dirty = true;
    }
    if (this.dirty) this.rebuild();
  }

  rebuild() {
    this.dirty = false;
    const n = this.n, v = n + 1;
    const pos = this.geo.attributes.position.array;
    const col = this.geo.attributes.color.array;
    const u = this.units, b = this.blocked;
    const max = this.maxUnits, uh = this.unitHeight;
    let total = 0;
    for (let k = 0; k < u.length; k++) total += u[k];
    this.total = total;
    for (let j = 0; j <= n; j++) {
      for (let i = 0; i <= n; i++) {
        let s = 0, c = 0, snowy = 0;
        for (let dj = -1; dj <= 0; dj++) for (let di = -1; di <= 0; di++) {
          const ti = i + di, tj = j + dj;
          if (ti < 0 || tj < 0 || ti >= n || tj >= n) continue;
          const k = tj * n + ti;
          if (b[k]) { c++; continue; }
          s += u[k]; c++;
          if (u[k] > 0.05) snowy++;
        }
        const avg = c ? s / c : 0;
        const vi = j * v + i;
        // PlaneGeometry vertex order is row-major from -z (top) — after rotateX the
        // row index maps to +z, which matches our j.
        pos[vi * 3 + 1] = snowy ? avg * uh + this.noise[vi] : -0.08;
        const t = Math.min(1, avg / max);
        col[vi * 3] = 0.82 + 0.16 * t;
        col[vi * 3 + 1] = 0.87 + 0.12 * t;
        col[vi * 3 + 2] = 0.96 + 0.04 * t;
      }
    }
    this.geo.attributes.position.needsUpdate = true;
    this.geo.attributes.color.needsUpdate = true;
    this.geo.computeVertexNormals();
  }

  fraction() {
    let cap = 0;
    for (let k = 0; k < this.units.length; k++) if (!this.blocked[k]) cap += this.maxUnits;
    return cap ? this.total / cap : 0;
  }
}
