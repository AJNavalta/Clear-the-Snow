--!nonstrict
-- Procedural part-built models: hand tools, machines, stalls, NPCs, spin wheel.
--
-- Models are authored in metres with the front facing +Z (like the web prototype),
-- then `finish` scales them to studs and turns them to face -Z (Roblox forward).
-- Every model gets an invisible, anchored "Root" PrimaryPart at its origin:
--   hand tools: origin = the grip (held in the right hand), blade points down
--   machines:   origin = ground under the machine's centre
-- Machine attributes: SeatOffset (Vector3, studs, relative to Root), Standing (bool).
-- A part named "Load" (ellipsoid) shows how full the tool is.

local Config = require(script.Parent.Config)

local S = Config.STUDS_PER_METER
local Models = {}

-- ------------------------------------------------------------------ styles
type Style = { color: Color3, material: Enum.Material, transparency: number?, reflectance: number? }

local styleCache: { [string]: Style } = {}
local function st(hex: string, material: Enum.Material?, transparency: number?, reflectance: number?): Style
	local key = hex .. tostring(material) .. tostring(transparency) .. tostring(reflectance)
	local s = styleCache[key]
	if not s then
		s = {
			color = Color3.fromHex(hex),
			material = material or Enum.Material.SmoothPlastic,
			transparency = transparency,
			reflectance = reflectance,
		}
		styleCache[key] = s
	end
	return s
end
Models.style = st

local M = {
	tire = st("#1b1c1f", Enum.Material.Rubber),
	rim = st("#c9ccd1", Enum.Material.Metal),
	steel = st("#8d939b", Enum.Material.Metal),
	dark = st("#2a2d33"),
	black = st("#111214"),
	chrome = st("#e6e9ee", Enum.Material.Metal, nil, 0.25),
	glass = st("#7fb6d9", Enum.Material.Glass, 0.45),
	light = st("#fff6d8", Enum.Material.Neon),
	tail = st("#ff3b30", Enum.Material.Neon),
	amber = st("#ffb020", Enum.Material.Neon),
	seat = st("#232428", Enum.Material.Fabric),
	wood = st("#9a6a3c", Enum.Material.Wood),
	rubber = st("#26272b", Enum.Material.Rubber),
	snow = st("#f4f8ff", Enum.Material.Snow),
}
Models.M = M

local function S_(s: Style | string): Style
	if typeof(s) == "string" then
		return st(s)
	end
	return s
end

-- ------------------------------------------------------------------ frames & primitives
-- A frame is { model = Model, cf = CFrame (metres) }. Parts are placed in frame space.
type Frame = { model: Model, cf: CFrame }

local function sub(g: Frame, x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): Frame
	return { model = g.model, cf = g.cf * CFrame.new(x, y, z) * CFrame.Angles(rx or 0, ry or 0, rz or 0) }
end

local function newPart(className: string, g: Frame, size: Vector3, localCf: CFrame, style: Style | string): BasePart
	local s = S_(style)
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = s.material
	p.Color = s.color
	if s.transparency then
		p.Transparency = s.transparency
	end
	if s.reflectance then
		p.Reflectance = s.reflectance
	end
	p.Size = Vector3.new(math.max(size.X * S, 0.05), math.max(size.Y * S, 0.05), math.max(size.Z * S, 0.05))
	local cf = g.cf * localCf
	p.CFrame = CFrame.new(cf.Position * S) * cf.Rotation
	p.Parent = g.model
	return p
end

local function box(g: Frame, w: number, h: number, d: number, style, x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): BasePart
	return newPart("Part", g, Vector3.new(w, h, d), CFrame.new(x, y, z) * CFrame.Angles(rx or 0, ry or 0, rz or 0), style)
end
-- cylinder whose axis runs along local X
local function cylX(g: Frame, r: number, len: number, style, x: number, y: number, z: number): BasePart
	local p = newPart("Part", g, Vector3.new(len, r * 2, r * 2), CFrame.new(x, y, z), style) :: Part
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function cylY(g: Frame, r: number, h: number, style, x: number, y: number, z: number): BasePart
	local p = newPart("Part", g, Vector3.new(h, r * 2, r * 2), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), style) :: Part
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function cylZ(g: Frame, r: number, len: number, style, x: number, y: number, z: number): BasePart
	local p = newPart("Part", g, Vector3.new(len, r * 2, r * 2), CFrame.new(x, y, z) * CFrame.Angles(0, math.pi / 2, 0), style) :: Part
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function ball(g: Frame, r: number, style, x: number, y: number, z: number): BasePart
	local p = newPart("Part", g, Vector3.new(r * 2, r * 2, r * 2), CFrame.new(x, y, z), style) :: Part
	p.Shape = Enum.PartType.Ball
	return p
end
-- ellipsoid (block + sphere mesh)
local function blob(g: Frame, w: number, h: number, d: number, style, x: number, y: number, z: number): BasePart
	local p = newPart("Part", g, Vector3.new(w, h, d), CFrame.new(x, y, z), style)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
-- tube between two points (frame space)
local function rod(g: Frame, a: Vector3, b: Vector3, r: number, style): BasePart?
	local len = (b - a).Magnitude
	if len < 1e-4 then
		return nil
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
	local p = newPart("Part", g, Vector3.new(len, r * 2, r * 2), cf, style) :: Part
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- Solid triangle (a, b, c in frame space) with the given thickness, from two wedges.
local function tri(g: Frame, a: Vector3, b: Vector3, c: Vector3, thickness: number, style)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local cross = ac:Cross(ab)
	if cross.Magnitude < 1e-6 then
		return
	end
	local right = cross.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local w1 = newPart("WedgePart", g, Vector3.new(thickness, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), style)
	local w2 = newPart("WedgePart", g, Vector3.new(thickness, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), style)
	return w1, w2
end

-- Extrude a side profile (points are {z, y}) across `width` along X, centred on x.
local function profile(g: Frame, points: { { number } }, width: number, style, x: number?)
	local px = x or 0
	local cz, cy = 0, 0
	for _, p in points do
		cz += p[1]
		cy += p[2]
	end
	cz /= #points
	cy /= #points
	local c = v(px, cy, cz)
	for i = 1, #points do
		local p1, p2 = points[i], points[i % #points + 1]
		tri(g, c, v(px, p1[2], p1[1]), v(px, p2[2], p2[1]), width, style)
	end
end

-- Curved surface made of slats around an axis parallel to X through (y=cy, z=cz).
-- Angle 0 points to +Y, positive angles sweep toward +Z.
local function arc(g: Frame, cy: number, cz: number, r: number, a0: number, a1: number, n: number, width: number, thick: number, style, x: number?)
	local da = (a1 - a0) / n
	local len = 2 * r * math.sin(math.abs(da) / 2) * 1.12
	for k = 0, n - 1 do
		local a = a0 + da * (k + 0.5)
		box(g, width, thick, len, style, x or 0, cy + r * math.cos(a), cz + r * math.sin(a), a, 0, 0)
	end
end

-- ------------------------------------------------------------------ assemblies
local function wheel(g: Frame, r: number, w: number, x: number, y: number, z: number, opts: { lugs: number?, rim: string?, nuts: number? }?)
	local o = opts or {}
	local f = sub(g, x, y, z)
	cylX(f, r, w, M.tire, 0, 0, 0)
	local lugs = o.lugs or 18
	for i = 0, lugs - 1 do
		local a = i / lugs * math.pi * 2
		box(f, w * 0.42, r * 0.12, r * 0.18, M.tire, (if i % 2 == 1 then 1 else -1) * w * 0.24, r * math.cos(a), r * math.sin(a), a, 0, 0)
	end
	local rimStyle = if o.rim then st(o.rim, Enum.Material.Metal) else M.rim
	for _, side in { 1, -1 } do
		cylX(f, r * 0.62, 0.02, rimStyle, side * (w / 2 + 0.005), 0, 0)
		cylX(f, r * 0.5, 0.04, st("#9ea3ab", Enum.Material.Metal), side * (w / 2 + 0.02), 0, 0)
		cylX(f, r * 0.18, 0.06, M.chrome, side * (w / 2 + 0.05), 0, 0)
		local nuts = o.nuts or 6
		for i = 0, nuts - 1 do
			local a = i / nuts * math.pi * 2
			cylX(f, r * 0.04, 0.05, M.chrome, side * (w / 2 + 0.04), math.cos(a) * r * 0.32, math.sin(a) * r * 0.32)
		end
	end
end

-- Crawler track along Z centred on (x, y, z). len = distance between end wheel centres.
local function track(g: Frame, len: number, r: number, w: number, x: number, y: number, z: number, opts: { color: string?, pitch: number?, roadWheels: number?, wheel: string? }?)
	local o = opts or {}
	local f = sub(g, x, y, z)
	local padStyle = st(o.color or "#1e1f22", Enum.Material.Metal)
	local perim = 2 * len + 2 * math.pi * r
	local pads = math.floor(perim / (o.pitch or 0.17) + 0.5)
	local step = perim / pads
	for i = 0, pads - 1 do
		local s = i * step
		local pz, py, a
		if s < len then
			pz, py, a = len / 2 - s, -r, 0
		elseif s < len + math.pi * r then
			local t = (s - len) / r
			pz, py, a = -len / 2 - math.sin(t) * r, -math.cos(t) * r, t
		elseif s < 2 * len + math.pi * r then
			pz, py, a = -len / 2 + (s - len - math.pi * r), r, math.pi
		else
			local t = math.pi + (s - 2 * len - math.pi * r) / r
			pz, py, a = len / 2 - math.sin(t) * r, -math.cos(t) * r, t
		end
		box(f, w, 0.06, step * 0.8, padStyle, 0, py, pz, -a, 0, 0)
	end
	local ws = st(o.wheel or "#3a3d44", Enum.Material.Metal)
	for _, ez in { len / 2, -len / 2 } do
		cylX(f, r * 0.85, w * 0.8, ws, 0, 0, ez)
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			box(f, w * 0.82, r * 0.18, r * 0.18, ws, 0, math.cos(a) * r * 0.85, ez + math.sin(a) * r * 0.85, a, 0, 0)
		end
		cylX(f, r * 0.3, w * 0.9, st("#d0a020", Enum.Material.Metal), 0, 0, ez)
	end
	local nRoad = o.roadWheels or math.max(3, math.floor(len / (r * 1.2)))
	for i = 0, nRoad - 1 do
		local rz = -len / 2 + r + (len - 2 * r) * (i + 0.5) / nRoad
		cylX(f, r * 0.55, w * 0.7, ws, 0, -r + r * 0.6, rz)
	end
	box(f, w * 0.3, r * 0.7, len, st("#2b2e33"), 0, 0, 0)
end

-- helical auger along X
local function auger(g: Frame, len: number, r: number, style, x: number, y: number, z: number)
	local f = sub(g, x, y, z)
	cylX(f, r * 0.18, len, M.steel, 0, 0, 0)
	local steps = 18
	for _, dir in { 1, -1 } do
		for i = 0, steps - 1 do
			local t = i / steps
			local a = t * 3 * math.pi * 2 * dir
			box(f, 0.05, r * 0.85, r * 0.25, style, dir * t * len / 2, math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, a, 0, 0)
		end
	end
end

local function headlight(g: Frame, r: number, x: number, y: number, z: number)
	cylZ(g, r * 1.25, r * 0.8, M.black, x, y, z)
	cylZ(g, r, 0.03, M.light, x, y, z + r * 0.42)
end
local function beacon(g: Frame, x: number, y: number, z: number, s: number?)
	local k = s or 1
	cylY(g, 0.1 * k, 0.05 * k, M.black, x, y, z)
	cylY(g, 0.075 * k, 0.15 * k, M.amber, x, y + 0.09 * k, z)
end
local function seat(g: Frame, x: number, y: number, z: number, k: number?, color: string?)
	local s = k or 1
	local sty = if color then st(color, Enum.Material.Fabric) else M.seat
	box(g, 0.5 * s, 0.1 * s, 0.48 * s, sty, x, y, z)
	box(g, 0.5 * s, 0.5 * s, 0.1 * s, sty, x, y + 0.28 * s, z - 0.22 * s, -0.15, 0, 0)
end
local function steering(g: Frame, x: number, y: number, z: number, tilt: number?, r: number?)
	local rr = r or 0.18
	local f = sub(g, x, y, z, -(tilt or 0.9), 0, 0)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		box(f, 0.04, 0.04, rr * 0.55, M.black, math.cos(a) * rr, 0, math.sin(a) * rr, 0, -a, 0)
	end
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + math.pi / 2
		rod(f, v(0, 0, 0), v(math.cos(a) * rr, 0, math.sin(a) * rr), 0.012, M.black)
	end
	cylY(f, 0.04, 0.04, M.dark, 0, 0, 0)
	rod(f, v(0, 0, 0), v(0, -0.4, 0), 0.025, M.dark)
end
local function mirror(g: Frame, x: number, y: number, z: number, side: number)
	rod(g, v(x, y, z), v(x + side * 0.18, y + 0.06, z), 0.015, M.black)
	box(g, 0.04, 0.2, 0.14, M.black, x + side * 0.22, y + 0.06, z)
	box(g, 0.01, 0.17, 0.11, M.chrome, x + side * 0.2, y + 0.06, z)
end
-- Plow blade: concave moldboard of slats, cutting edge, back ribs, marker stakes.
local function plow(g: Frame, w: number, h: number, color: string, x: number, y: number, z: number, ribs: number?, ry: number?, noStakes: boolean?): Frame
	local f = sub(g, x, y, z, 0, ry or 0, 0)
	local paint = st(color, Enum.Material.Metal)
	local function prof(t: number): (number, number)
		return -0.32 * h * math.sin(t * math.pi) + 0.12 * h * t * t * t, t * h
	end
	local n = 8
	for k = 0, n - 1 do
		local z0, y0 = prof(k / n)
		local z1, y1 = prof((k + 1) / n)
		local len = math.sqrt((z1 - z0) ^ 2 + (y1 - y0) ^ 2)
		box(f, w, len * 1.08, 0.05, paint, 0, (y0 + y1) / 2, (z0 + z1) / 2, -math.atan2(z1 - z0, y1 - y0), 0, 0)
	end
	local topZ = prof(1)
	box(f, w, 0.06, 0.06, M.dark, 0, h, topZ)
	box(f, w, 0.05, 0.08, M.steel, 0, 0.02, 0.02)
	local nr = ribs or 5
	for i = 0, nr - 1 do
		box(f, 0.04, h * 0.8, 0.06, paint, -w / 2 + w * (i + 0.5) / nr, h * 0.45, -h * 0.36)
	end
	local orange = st("#ff7a00")
	for _, s in (if noStakes then {} else { -1, 1 }) do
		rod(f, v(s * w * 0.48, h * 0.8, -h * 0.4), v(s * w * 0.48, h * 1.6, -h * 0.4), 0.015, orange)
		ball(f, 0.03, orange, s * w * 0.48, h * 1.6, -h * 0.4)
	end
	return f
end
-- the visible load: an ellipsoid named "Load"; its centre sits on the floor of the container
local function load(g: Frame, w: number, h: number, d: number, x: number, y: number, z: number)
	local p = blob(g, w, h * 2, d, M.snow, x, y, z)
	p.Name = "Load"
	p.CastShadow = false
	p:SetAttribute("FullHeight", h * 2 * S)
	return p
end

-- ------------------------------------------------------------------ finishing
local function newModel(name: string): (Model, Frame)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.4, 0.4, 0.4)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	return model, { model = model, cf = CFrame.new() }
end

-- turn from +Z-forward to Roblox's -Z-forward
local TURN = CFrame.Angles(0, math.pi, 0)
local function finish(model: Model): Model
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" then
			d.CFrame = TURN * d.CFrame
		end
	end
	local seatOffset = model:GetAttribute("SeatOffset")
	if typeof(seatOffset) == "Vector3" then
		model:SetAttribute("SeatOffset", Vector3.new(-seatOffset.X, seatOffset.Y, -seatOffset.Z))
	end
	return model
end

-- ------------------------------------------------------------------ hand tools
local SHOVELS = {
	kidshovel = { len = 0.75, bw = 0.24, bh = 0.24, color = "#e53935", shaft = "#e53935", grip = "#ffeb3b", dg = true },
	shovel = { len = 1.05, bw = 0.42, bh = 0.34, color = "#1e88e5", shaft = "#b07a45", grip = "#222222", dg = true },
	bigshovel = { len = 1.15, bw = 0.56, bh = 0.4, color = "#43a047", shaft = "#8d6e63", grip = "#222222", dg = true },
	megashovel = { len = 1.2, bw = 0.72, bh = 0.48, color = "#fb8c00", shaft = "#5d4037", grip = "#111111", dg = true },
	steelshovel = { len = 1.2, bw = 0.66, bh = 0.5, color = "#9aa3ad", shaft = "#3e2723", grip = "#111111", dg = true, metal = true },
	pusher = { len = 1.35, bw = 0.95, bh = 0.32, color = "#283593", shaft = "#9e9e9e", grip = "#111111", push = true },
	twinpusher = { len = 1.3, bw = 1.2, bh = 0.5, color = "#c62828", shaft = "#616161", grip = "#111111", push = true, wheels = true },
	sledscoop = { len = 1.2, bw = 1.0, bh = 0.42, color = "#6a1b9a", shaft = "#424242", grip = "#111111", push = true, sled = true },
}

function Models.BuildHandTool(id: string): Model
	local model, g = newModel(id)
	if id == "hands" then
		load(g, 0.26, 0.13, 0.26, 0, -0.05, 0.06)
	elseif id == "trowel" then
		-- drawn a bit larger than life so it reads clearly in the player's hand
		local k = 1.7
		cylY(g, 0.03 * k, 0.14 * k, st("#2e7d32"), 0, 0, 0)
		cylY(g, 0.01 * k, 0.1 * k, M.steel, 0, -0.12 * k, 0)
		local blade = st("#b9bec6", Enum.Material.Metal)
		tri(g, v(-0.06 * k, -0.17 * k, 0.02 * k), v(0.06 * k, -0.17 * k, 0.02 * k), v(0, -0.38 * k, 0.06 * k), 0.015 * k, blade)
		box(g, 0.02 * k, 0.18 * k, 0.04 * k, blade, -0.055 * k, -0.25 * k, 0.04 * k, 0, 0, -0.28)
		box(g, 0.02 * k, 0.18 * k, 0.04 * k, blade, 0.055 * k, -0.25 * k, 0.04 * k, 0, 0, 0.28)
		load(g, 0.1 * k, 0.05 * k, 0.1 * k, 0, -0.24 * k, 0.07 * k)
	else
		local P = SHOVELS[id] or SHOVELS.shovel
		local shaftSt = st(P.shaft, Enum.Material.Wood)
		cylY(g, 0.025, P.len, shaftSt, 0, -P.len / 2 + 0.1, 0)
		local gripSt = st(P.grip)
		if P.dg then
			box(g, 0.16, 0.03, 0.03, gripSt, 0, 0.2, 0)
			box(g, 0.025, 0.1, 0.025, gripSt, -0.07, 0.15, 0)
			box(g, 0.025, 0.1, 0.025, gripSt, 0.07, 0.15, 0)
		else
			cylX(g, 0.022, 0.34, gripSt, 0, 0.12, 0)
			cylX(g, 0.028, 0.1, st("#d32f2f", Enum.Material.Rubber), -0.15, 0.12, 0)
			cylX(g, 0.028, 0.1, st("#d32f2f", Enum.Material.Rubber), 0.15, 0.12, 0)
		end
		local bladeSt = st(P.color, if P.metal then Enum.Material.Metal else Enum.Material.SmoothPlastic)
		local b = sub(g, 0, -P.len + 0.08, 0)
		cylY(b, 0.035, 0.12, M.steel, 0, 0.1, 0)
		if P.push then
			plow(b, P.bw, P.bh * 1.3, P.color, 0, -P.bh * 1.1, 0.12, 4, 0, true)
			rod(b, v(0, 0.05, 0), v(P.bw * 0.35, -0.12, 0.0), 0.012, M.steel)
			rod(b, v(0, 0.05, 0), v(-P.bw * 0.35, -0.12, 0.0), 0.012, M.steel)
			if P.wheels then
				wheel(b, 0.12, 0.06, -P.bw * 0.45, -0.3, -0.12, { lugs = 10, nuts = 4 })
				wheel(b, 0.12, 0.06, P.bw * 0.45, -0.3, -0.12, { lugs = 10, nuts = 4 })
			end
			if P.sled then
				for _, x in { -P.bw * 0.4, P.bw * 0.4 } do
					box(b, 0.04, 0.03, 0.7, M.chrome, x, -0.42, -0.1)
					box(b, 0.04, 0.03, 0.16, M.chrome, x, -0.37, 0.28, -0.7, 0, 0)
				end
				box(b, P.bw * 0.85, 0.2, 0.6, bladeSt, 0, -0.32, -0.1)
			end
			load(g, P.bw * 0.8, 0.18, 0.35, 0, -P.len + 0.08 - 0.35, 0.02)
		else
			local tilt = sub(b, 0, 0, 0, 0.35, 0, 0)
			box(tilt, P.bw, P.bh, 0.02, bladeSt, 0, -P.bh / 2, 0)
			box(tilt, P.bw, 0.02, P.bh * 0.9, bladeSt, 0, -P.bh, P.bh * 0.45)
			for _, x in { -P.bw / 2, P.bw / 2 } do
				tri(tilt, v(x, 0, 0), v(x, -P.bh, 0), v(x, -P.bh, P.bh * 0.9), 0.02, bladeSt)
			end
			box(tilt, P.bw, 0.025, 0.03, M.steel, 0, -P.bh, P.bh * 0.9)
			for i = 0, 3 do
				ball(tilt, 0.012, M.steel, -P.bw * 0.3 + i * P.bw * 0.2, -0.04, 0.012)
			end
			load(tilt, P.bw * 0.8, P.bh * 0.45, P.bh * 0.7, 0, -P.bh, P.bh * 0.45)
		end
	end
	return finish(model)
end

-- ------------------------------------------------------------------ machines
function Models.BuildMachine(id: string): Model
	local model, g = newModel(id)
	local seatPos = v(0, 1, 0)
	local standing = false

	if id == "blower" then
		local paint = st("#d32f2f", Enum.Material.Metal)
		arc(g, 0.36, 0.45, 0.32, 0, -math.pi, 8, 0.8, 0.03, paint) -- auger housing (open at the front)
		cylX(g, 0.32, 0.03, paint, -0.4, 0.36, 0.45)
		cylX(g, 0.32, 0.03, paint, 0.4, 0.36, 0.45)
		box(g, 0.82, 0.04, 0.1, M.steel, 0, 0.04, 0.68)
		box(g, 0.04, 0.1, 0.28, M.steel, -0.42, 0.06, 0.55)
		box(g, 0.04, 0.1, 0.28, M.steel, 0.42, 0.06, 0.55)
		auger(g, 0.76, 0.26, st("#fbc02d", Enum.Material.Metal), 0, 0.36, 0.5)
		cylZ(g, 0.2, 0.2, paint, 0, 0.36, 0.2)
		rod(g, v(0, 0.5, 0.22), v(0.08, 1.12, 0.26), 0.09, paint) -- chute
		box(g, 0.22, 0.06, 0.26, paint, 0.1, 1.17, 0.34, 0.5, 0, 0)
		rod(g, v(0.05, 0.6, 0.12), v(0.05, 0.9, -0.6), 0.012, M.steel)
		box(g, 0.5, 0.36, 0.45, M.dark, 0, 0.62, -0.12)
		for i = 0, 5 do
			box(g, 0.52, 0.015, 0.03, M.steel, 0, 0.5 + i * 0.05, 0.1)
		end
		cylY(g, 0.09, 0.08, st("#212121"), 0.18, 0.86, -0.12)
		box(g, 0.16, 0.12, 0.14, st("#424242"), -0.2, 0.84, -0.22)
		cylZ(g, 0.04, 0.16, M.chrome, -0.29, 0.64, -0.3)
		box(g, 0.6, 0.1, 0.8, M.dark, 0, 0.32, -0.25)
		wheel(g, 0.26, 0.18, -0.4, 0.26, -0.45, { lugs = 14, rim = "#d32f2f" })
		wheel(g, 0.26, 0.18, 0.4, 0.26, -0.45, { lugs = 14, rim = "#d32f2f" })
		for _, x in { -0.27, 0.27 } do
			rod(g, v(x, 0.42, -0.5), v(x, 1.05, -1.0), 0.02, M.black)
			cylX(g, 0.03, 0.12, M.rubber, x, 1.05, -1.0)
		end
		rod(g, v(-0.27, 1.05, -1.0), v(0.27, 1.05, -1.0), 0.02, M.black)
		box(g, 0.38, 0.12, 0.08, M.dark, 0, 0.92, -0.86, 0.6, 0, 0)
		ball(g, 0.025, st("#4caf50", Enum.Material.Neon), -0.08, 0.96, -0.83)
		ball(g, 0.025, st("#f44336", Enum.Material.Neon), 0.08, 0.96, -0.83)
		headlight(g, 0.05, 0, 0.82, 0.12)
		load(g, 0.4, 0.25, 0.35, 0, 0.8, -0.55)
		seatPos, standing = v(0, 0, -1.45), true
	elseif id == "tractor" then
		local paint = st("#2e7d32", Enum.Material.Metal)
		local yellow = st("#fdd835")
		box(g, 0.7, 0.18, 1.9, M.dark, 0, 0.45, 0)
		profile(g, { { 0.95, 0.55 }, { 0.95, 0.85 }, { 0.55, 1.0 }, { -0.1, 1.0 }, { -0.1, 0.55 } }, 0.72, paint)
		for i = 0, 5 do
			box(g, 0.74, 0.02, 0.025, M.black, 0, 0.62 + i * 0.04, 0.96)
		end
		headlight(g, 0.05, -0.2, 0.84, 0.94)
		headlight(g, 0.05, 0.2, 0.84, 0.94)
		box(g, 0.74, 0.05, 0.4, yellow, 0, 0.98, 0.45)
		for _, s in { -1, 1 } do
			arc(g, 0.42, -0.6, 0.46, -math.pi / 2, math.pi / 2, 8, 0.34, 0.03, paint, s * 0.62)
		end
		box(g, 1.2, 0.06, 0.7, paint, 0, 0.8, -0.6)
		seat(g, 0, 0.87, -0.65, 1, "#fdd835")
		steering(g, 0, 1.25, -0.1, 0.8)
		wheel(g, 0.42, 0.3, -0.62, 0.42, -0.6, { rim = "#fdd835", lugs = 20 })
		wheel(g, 0.42, 0.3, 0.62, 0.42, -0.6, { rim = "#fdd835", lugs = 20 })
		wheel(g, 0.25, 0.18, -0.45, 0.25, 0.65, { rim = "#fdd835", lugs = 12 })
		wheel(g, 0.25, 0.18, 0.45, 0.25, 0.65, { rim = "#fdd835", lugs = 12 })
		rod(g, v(-0.3, 0.4, 0.6), v(-0.4, 0.35, 1.3), 0.03, M.dark)
		rod(g, v(0.3, 0.4, 0.6), v(0.4, 0.35, 1.3), 0.03, M.dark)
		plow(g, 1.7, 0.5, "#fdd835", 0, 0.02, 1.45)
		cylY(g, 0.04, 0.5, M.chrome, 0.25, 1.15, 0.5)
		-- towed dump cart
		local cart = sub(g, 0, 0, -1.9)
		rod(cart, v(0, 0.35, 0.95), v(0, 0.35, 0.45), 0.03, M.dark)
		box(cart, 1.1, 0.06, 0.9, st("#1b5e20"), 0, 0.42, 0)
		for _, s in { -1, 1 } do
			box(cart, 0.05, 0.4, 0.9, st("#1b5e20"), s * 0.53, 0.62, 0)
			box(cart, 1.1, 0.4, 0.05, st("#1b5e20"), 0, 0.62, s * 0.43)
		end
		wheel(cart, 0.22, 0.14, -0.62, 0.22, 0)
		wheel(cart, 0.22, 0.14, 0.62, 0.22, 0)
		load(g, 0.95, 0.35, 0.75, 0, 0.45, -1.9)
		seatPos = v(0, 0.92, -0.62)
	elseif id == "atv" then
		local paint = st("#1565c0", Enum.Material.Metal)
		box(g, 0.6, 0.2, 1.5, M.dark, 0, 0.5, 0)
		profile(g, { { 0.9, 0.6 }, { 0.8, 0.85 }, { 0.35, 0.92 }, { -0.4, 1.0 }, { -0.85, 0.9 }, { -0.9, 0.6 } }, 0.75, paint)
		for _, pz in { { -0.5, 0.55 }, { 0.5, 0.55 }, { -0.5, -0.55 }, { 0.5, -0.55 } } do
			arc(g, 0.32, pz[2], 0.4, -math.pi / 2, math.pi / 2, 7, 0.34, 0.03, paint, pz[1])
			wheel(g, 0.32, 0.26, pz[1], 0.32, pz[2], { lugs = 16, nuts = 4 })
		end
		box(g, 0.4, 0.14, 0.7, M.seat, 0, 1.08, -0.2)
		rod(g, v(0, 1.0, 0.35), v(0, 1.25, 0.4), 0.03, M.black)
		rod(g, v(-0.38, 1.25, 0.38), v(0.38, 1.25, 0.38), 0.02, M.black)
		cylX(g, 0.03, 0.12, M.rubber, -0.36, 1.25, 0.38)
		cylX(g, 0.03, 0.12, M.rubber, 0.36, 1.25, 0.38)
		box(g, 0.18, 0.08, 0.06, M.black, 0, 1.22, 0.45)
		for _, rz in { 0.75, -0.75 } do
			for i = 0, 3 do
				rod(g, v(-0.3 + i * 0.2, 1.0, rz - 0.2), v(-0.3 + i * 0.2, 1.0, rz + 0.2), 0.012, M.black)
			end
			rod(g, v(-0.35, 1.0, rz - 0.2), v(0.35, 1.0, rz - 0.2), 0.015, M.black)
			rod(g, v(-0.35, 1.0, rz + 0.2), v(0.35, 1.0, rz + 0.2), 0.015, M.black)
		end
		headlight(g, 0.06, -0.2, 0.8, 0.92)
		headlight(g, 0.06, 0.2, 0.8, 0.92)
		box(g, 0.3, 0.05, 0.03, M.tail, 0, 0.82, -0.92)
		cylX(g, 0.07, 0.26, M.dark, 0, 0.5, 1.0)
		rod(g, v(-0.25, 0.4, 0.6), v(-0.3, 0.3, 1.35), 0.025, M.dark)
		rod(g, v(0.25, 0.4, 0.6), v(0.3, 0.3, 1.35), 0.025, M.dark)
		plow(g, 1.6, 0.42, "#212121", 0, 0.02, 1.45)
		load(g, 0.6, 0.25, 0.4, 0, 1.02, -0.75)
		seatPos = v(0, 1.08, -0.25)
	elseif id == "snowmobile" then
		local paint = st("#00897b", Enum.Material.Metal)
		box(g, 0.55, 0.12, 1.6, M.dark, 0, 0.42, -0.4)
		track(g, 1.3, 0.16, 0.42, 0, 0.2, -0.45, { color = "#1a1a1a", roadWheels = 4, pitch = 0.12 })
		profile(g, { { 1.0, 0.35 }, { 1.05, 0.5 }, { 0.8, 0.8 }, { 0.35, 0.95 }, { 0.25, 0.6 }, { 0.2, 0.35 } }, 0.75, paint)
		box(g, 0.76, 0.06, 0.4, st("#ffeb3b"), 0, 0.62, 0.65, -0.3, 0, 0)
		box(g, 0.6, 0.35, 0.02, M.glass, 0, 1.08, 0.38, -0.5, 0, 0)
		headlight(g, 0.07, -0.15, 0.6, 1.02)
		headlight(g, 0.07, 0.15, 0.6, 1.02)
		for _, s in { -1, 1 } do
			rod(g, v(s * 0.3, 0.45, 0.6), v(s * 0.42, 0.12, 0.7), 0.025, M.dark)
			box(g, 0.12, 0.04, 1.0, M.black, s * 0.42, 0.06, 0.75)
			box(g, 0.12, 0.04, 0.2, M.black, s * 0.42, 0.12, 1.3, -0.6, 0, 0)
			rod(g, v(s * 0.42, 0.18, 0.55), v(s * 0.42, 0.18, 0.95), 0.015, M.chrome)
		end
		box(g, 0.42, 0.18, 1.0, M.seat, 0, 0.6, -0.45)
		rod(g, v(-0.35, 1.0, 0.3), v(0.35, 1.0, 0.3), 0.02, M.black)
		rod(g, v(0, 0.8, 0.35), v(0, 1.0, 0.3), 0.03, M.black)
		box(g, 0.4, 0.05, 0.03, M.tail, 0, 0.5, -1.21)
		local sled = sub(g, 0, 0, -2.3)
		rod(sled, v(0, 0.3, 1.0), v(0, 0.25, 0.55), 0.025, M.dark)
		box(sled, 0.9, 0.05, 1.1, st("#004d40"), 0, 0.2, 0)
		for _, s in { -1, 1 } do
			box(sled, 0.05, 0.3, 1.1, st("#004d40"), s * 0.43, 0.35, 0)
			box(sled, 0.06, 0.04, 1.2, M.chrome, s * 0.38, 0.12, 0)
		end
		load(g, 0.8, 0.35, 0.95, 0, 0.25, -2.3)
		seatPos = v(0, 0.68, -0.4)
	elseif id == "pickup" then
		local paint = st("#37474f", Enum.Material.Metal)
		box(g, 1.7, 0.25, 4.6, M.dark, 0, 0.6, 0)
		box(g, 1.9, 0.6, 1.7, paint, 0, 1.05, 1.45) -- hood block
		box(g, 1.9, 0.6, 1.2, paint, 0, 1.05, 0.0) -- cab lower
		profile(g, { { 0.6, 1.35 }, { 0.35, 2.0 }, { -0.55, 2.0 }, { -0.6, 1.35 } }, 1.9, paint) -- cab upper
		box(g, 1.7, 0.6, 0.02, M.glass, 0, 1.67, 0.5, -0.38, 0, 0)
		for _, s in { -1, 1 } do
			box(g, 0.02, 0.5, 0.8, M.glass, s * 0.955, 1.65, -0.1)
		end
		box(g, 1.6, 0.45, 0.02, M.glass, 0, 1.68, -0.61)
		box(g, 1.9, 0.1, 2.0, paint, 0, 0.85, -1.65)
		for _, s in { -1, 1 } do
			box(g, 0.08, 0.55, 2.0, paint, s * 0.91, 1.15, -1.65)
		end
		box(g, 1.9, 0.55, 0.08, paint, 0, 1.15, -2.62)
		box(g, 1.82, 0.04, 0.04, M.chrome, 0, 1.45, -2.62)
		box(g, 0.55, 0.45, 0.55, st("#ef6c00"), 0, 1.45, -2.3, 0, math.pi / 4, 0) -- salt spreader
		cylY(g, 0.2, 0.03, M.black, 0, 0.75, -2.85)
		box(g, 1.4, 0.4, 0.04, M.chrome, 0, 1.0, 2.31)
		for i = 0, 4 do
			box(g, 1.3, 0.03, 0.05, M.black, 0, 0.85 + i * 0.07, 2.33)
		end
		for _, s in { -1, 1 } do
			box(g, 0.3, 0.15, 0.05, M.light, s * 0.75, 1.1, 2.31)
			box(g, 0.12, 0.3, 0.04, M.tail, s * 0.9, 1.15, -2.66)
		end
		box(g, 1.95, 0.18, 0.2, M.chrome, 0, 0.68, -2.7)
		box(g, 1.4, 0.08, 0.15, M.black, 0, 2.06, -0.1)
		for i = 0, 5 do
			box(g, 0.18, 0.05, 0.02, if i % 2 == 1 then M.amber else M.light, -0.55 + i * 0.22, 2.06, -0.02)
		end
		mirror(g, 0.95, 1.5, 0.45, 1)
		mirror(g, -0.95, 1.5, 0.45, -1)
		for _, p in { { -0.85, 1.5 }, { 0.85, 1.5 }, { -0.85, -1.6 }, { 0.85, -1.6 } } do
			wheel(g, 0.45, 0.32, p[1], 0.45, p[2], { lugs = 22, nuts = 8 })
		end
		for _, s in { -1, 1 } do
			plow(g, 1.5, 0.8, "#f9a825", s * 0.68, 0.02, 3.05, 4, s * 0.35)
		end
		box(g, 0.6, 0.4, 0.5, M.dark, 0, 0.6, 2.6)
		rod(g, v(0, 0.6, 2.35), v(0, 1.1, 2.6), 0.05, M.chrome)
		load(g, 1.6, 0.45, 1.8, 0, 0.9, -1.65)
		seat(g, -0.4, 1.0, -0.2, 1)
		steering(g, -0.4, 1.45, 0.25, 1.1)
		seatPos = v(-0.4, 1.05, -0.2)
	elseif id == "skidsteer" then
		local paint = st("#f9a825", Enum.Material.Metal)
		box(g, 1.5, 0.7, 2.2, paint, 0, 0.8, -0.2)
		box(g, 1.52, 0.1, 2.22, M.black, 0, 0.48, -0.2)
		for i = 0, 5 do
			box(g, 1.0, 0.04, 0.04, M.black, 0, 0.7 + i * 0.1, -1.32)
		end
		box(g, 0.3, 0.2, 0.04, M.tail, -0.6, 1.05, -1.32)
		box(g, 0.3, 0.2, 0.04, M.tail, 0.6, 1.05, -1.32)
		for _, p in { { -0.55, 0.45 }, { 0.55, 0.45 }, { -0.55, -0.7 }, { 0.55, -0.7 } } do
			box(g, 0.08, 1.2, 0.08, M.black, p[1], 1.75, p[2])
		end
		box(g, 1.2, 0.1, 1.25, paint, 0, 2.38, -0.12)
		for i = 0, 5 do
			box(g, 0.02, 1.1, 0.02, M.black, -0.45 + i * 0.18, 1.75, 0.47)
		end
		box(g, 1.0, 1.0, 0.02, M.glass, 0, 1.75, -0.72)
		for _, s in { -1, 1 } do
			box(g, 0.02, 1.0, 1.1, M.glass, s * 0.56, 1.75, -0.12)
		end
		seat(g, 0, 1.22, -0.25, 1)
		beacon(g, 0.4, 2.43, -0.5)
		for _, s in { -1, 1 } do
			rod(g, v(s * 0.82, 1.9, -0.9), v(s * 0.82, 1.3, 0.7), 0.08, paint)
			rod(g, v(s * 0.82, 1.3, 0.7), v(s * 0.82, 0.5, 1.25), 0.08, paint)
			rod(g, v(s * 0.82, 0.8, -0.2), v(s * 0.82, 1.4, 0.6), 0.05, M.chrome)
		end
		local bk = sub(g, 0, 0.05, 1.4)
		box(bk, 2.0, 0.05, 0.85, M.dark, 0, 0, 0.1)
		box(bk, 2.0, 0.9, 0.05, M.dark, 0, 0.45, -0.32)
		for _, s in { -1, 1 } do
			tri(bk, v(s, 0, -0.32), v(s, 0, 0.52), v(s, 0.9, -0.32), 0.05, M.dark)
		end
		box(bk, 2.0, 0.04, 0.08, M.steel, 0, 0.02, 0.55)
		for i = 0, 5 do
			box(bk, 0.08, 0.06, 0.15, M.steel, -0.85 + i * 0.34, 0.02, 0.62)
		end
		load(g, 1.8, 0.5, 0.75, 0, 0.1, 1.5)
		for _, p in { { -0.85, 0.5 }, { 0.85, 0.5 }, { -0.85, -0.85 }, { 0.85, -0.85 } } do
			wheel(g, 0.42, 0.34, p[1], 0.42, p[2], { lugs = 14, rim = "#f9a825" })
		end
		headlight(g, 0.06, -0.62, 2.25, 0.5)
		headlight(g, 0.06, 0.62, 2.25, 0.5)
		seatPos = v(0, 1.28, -0.25)
	elseif id == "resurfacer" then
		local paint = st("#1565c0", Enum.Material.Metal)
		local white = st("#eceff1", Enum.Material.SmoothPlastic)
		box(g, 2.0, 1.0, 3.6, white, 0, 0.95, 0)
		box(g, 2.04, 0.18, 3.64, paint, 0, 0.55, 0)
		box(g, 2.04, 0.1, 3.64, paint, 0, 1.3, 0)
		local tank = sub(g, 0, 1.45, 0.6)
		box(tank, 2.0, 0.9, 0.06, white, 0, 0.45, 1.2)
		box(tank, 2.0, 0.9, 0.06, white, 0, 0.45, -0.95)
		for _, s in { -1, 1 } do
			box(tank, 0.06, 0.9, 2.2, white, s * 0.98, 0.45, 0.12)
			box(tank, 0.12, 0.1, 2.26, paint, s * 0.98, 0.92, 0.12)
		end
		box(tank, 2.08, 0.1, 0.12, paint, 0, 0.92, 1.2)
		box(tank, 2.08, 0.1, 0.12, paint, 0, 0.92, -0.95)
		box(tank, 0.06, 0.06, 2.2, M.steel, 0, 0.97, 0.12)
		load(g, 1.85, 0.75, 2.0, 0, 1.45, 0.75)
		for _, s in { -1, 1 } do
			box(g, 0.02, 0.2, 2.6, st("#e53935"), s * 1.03, 1.05, 0)
		end
		box(g, 0.9, 0.1, 1.0, M.dark, -0.55, 1.45, -1.3)
		seat(g, -0.55, 1.55, -1.45, 1, "#1565c0")
		steering(g, -0.55, 1.95, -0.95, 0.5)
		box(g, 0.6, 0.6, 0.12, M.dark, -0.55, 1.75, -0.8)
		ball(g, 0.03, st("#4caf50", Enum.Material.Neon), -0.75, 1.95, -0.73)
		ball(g, 0.03, st("#ffeb3b", Enum.Material.Neon), -0.55, 1.95, -0.73)
		ball(g, 0.03, st("#f44336", Enum.Material.Neon), -0.35, 1.95, -0.73)
		box(g, 2.2, 0.35, 0.4, M.steel, 0, 0.3, -2.0)
		box(g, 2.1, 0.06, 0.6, st("#90caf9", Enum.Material.Fabric), 0, 0.05, -2.4)
		auger(g, 2.0, 0.14, M.steel, 0, 0.25, -2.0)
		for _, s in { -1, 1 } do
			cylY(g, 0.25, 0.08, st("#212121"), s * 1.05, 0.1, -1.8)
			for i = 0, 11 do
				local a = i / 12 * math.pi * 2
				box(g, 0.02, 0.08, 0.12, st("#ffca28"), s * 1.05 + math.cos(a) * 0.25, 0.08, -1.8 + math.sin(a) * 0.25, 0, -a, 0)
			end
		end
		headlight(g, 0.08, -0.6, 0.8, 1.82)
		headlight(g, 0.08, 0.6, 0.8, 1.82)
		beacon(g, 0.6, 2.55, 1.7)
		cylY(g, 0.05, 0.5, M.chrome, 0.85, 1.65, -1.6)
		for _, p in { { -1.0, 1.2 }, { 1.0, 1.2 }, { -1.0, -1.2 }, { 1.0, -1.2 } } do
			wheel(g, 0.42, 0.3, p[1], 0.42, p[2], { lugs = 16 })
		end
		seatPos = v(-0.55, 1.6, -1.45)
	elseif id == "snowcat" then
		local paint = st("#e53935", Enum.Material.Metal)
		for _, s in { -1, 1 } do
			track(g, 3.4, 0.5, 0.9, s * 1.35, 0.5, -0.2, { color = "#2a2a2a", roadWheels = 6, pitch = 0.22, wheel = "#555555" })
			box(g, 1.0, 0.08, 4.3, paint, s * 1.35, 1.08, -0.2)
		end
		box(g, 1.8, 0.8, 4.2, M.dark, 0, 1.0, -0.2)
		box(g, 2.4, 0.7, 4.3, paint, 0, 1.75, -0.15) -- lower body
		profile(g, { { 2.0, 2.0 }, { 1.2, 2.1 }, { -0.9, 2.1 }, { -0.9, 2.0 } }, 2.4, paint)
		box(g, 2.4, 1.05, 0.1, paint, 0, 2.62, -0.85) -- cab back
		box(g, 2.4, 0.1, 1.95, paint, 0, 3.2, 0.1) -- roof
		for _, p in { { -1.17, 1.0 }, { 1.17, 1.0 }, { -1.17, -0.8 }, { 1.17, -0.8 } } do
			box(g, 0.08, 1.1, 0.08, M.black, p[1], 2.65, p[2])
		end
		box(g, 2.2, 0.95, 0.02, M.glass, 0, 2.65, 1.0, -0.18, 0, 0)
		for _, s in { -1, 1 } do
			box(g, 0.02, 0.85, 1.6, M.glass, s * 1.18, 2.65, 0.1)
		end
		box(g, 2.0, 0.12, 0.25, M.black, 0, 3.32, 0.75)
		for i = 0, 5 do
			box(g, 0.22, 0.08, 0.02, M.light, -0.8 + i * 0.32, 3.32, 0.88)
		end
		beacon(g, -0.8, 3.27, -0.6)
		beacon(g, 0.8, 3.27, -0.6)
		cylY(g, 0.06, 0.8, M.chrome, 0.9, 2.5, -1.8)
		for i = 0, 4 do
			box(g, 2.0, 0.04, 0.04, M.black, 0, 1.5 + i * 0.1, 2.01)
		end
		headlight(g, 0.1, -0.8, 1.9, 2.0)
		headlight(g, 0.1, 0.8, 1.9, 2.0)
		seat(g, -0.45, 2.15, 0.1, 1.1)
		steering(g, -0.45, 2.55, 0.6, 0.7)
		for _, s in { -1, 1 } do
			rod(g, v(s * 0.9, 1.1, 1.6), v(s * 1.1, 0.7, 2.8), 0.09, M.dark)
			rod(g, v(s * 0.5, 1.5, 1.9), v(s * 0.6, 1.0, 2.8), 0.05, M.chrome)
		end
		plow(g, 4.0, 1.1, "#e53935", 0, 0.02, 3.2, 8)
		box(g, 3.6, 0.5, 0.7, paint, 0, 0.6, -2.9)
		auger(g, 3.4, 0.25, M.steel, 0, 0.35, -2.9)
		box(g, 3.6, 0.04, 0.6, st("#9e9e9e"), 0, 0.08, -3.45)
		for i = 0, 23 do
			box(g, 0.02, 0.05, 0.08, M.dark, -1.75 + i * 0.152, 0.05, -3.78)
		end
		box(g, 1.9, 0.1, 1.2, M.dark, 0, 2.15, -1.55)
		for _, s in { -1, 1 } do
			box(g, 0.05, 0.4, 1.2, paint, s * 0.95, 2.35, -1.55)
		end
		load(g, 1.75, 0.55, 1.1, 0, 2.2, -1.55)
		seatPos = v(-0.45, 2.22, 0.1)
	elseif id == "loader" then
		local paint = st("#fbc02d", Enum.Material.Metal)
		box(g, 2.0, 1.2, 2.6, paint, 0, 1.5, -1.4)
		box(g, 2.1, 0.3, 0.6, M.dark, 0, 1.0, -2.8)
		for i = 0, 5 do
			box(g, 1.6, 0.05, 0.05, M.black, 0, 1.4 + i * 0.12, -2.71)
		end
		cylY(g, 0.08, 1.0, M.dark, 0.6, 2.5, -2.2)
		cylY(g, 0.12, 0.3, M.dark, -0.6, 2.25, -2.3)
		box(g, 1.6, 0.1, 1.6, paint, 0, 3.55, -0.6)
		for _, p in { { -0.75, 0.15 }, { 0.75, 0.15 }, { -0.75, -1.35 }, { 0.75, -1.35 } } do
			box(g, 0.08, 1.4, 0.08, M.black, p[1], 2.85, p[2])
		end
		box(g, 1.45, 1.3, 0.02, M.glass, 0, 2.85, 0.17)
		box(g, 1.45, 1.2, 0.02, M.glass, 0, 2.85, -1.36)
		for _, s in { -1, 1 } do
			box(g, 0.02, 1.25, 1.45, M.glass, s * 0.77, 2.85, -0.6)
			headlight(g, 0.07, s * 0.65, 3.5, 0.2)
			mirror(g, s * 0.8, 3.1, 0.15, s)
		end
		seat(g, 0, 2.2, -0.8, 1.1)
		steering(g, 0, 2.6, -0.2, 0.7)
		beacon(g, 0.6, 3.6, -1.2)
		for i = 0, 3 do
			box(g, 0.3, 0.03, 0.12, M.steel, -1.05, 0.8 + i * 0.3, -0.4)
		end
		cylY(g, 0.25, 0.6, M.dark, 0, 1.0, 0.1)
		box(g, 1.6, 0.7, 1.6, paint, 0, 1.0, 1.0)
		for _, s in { -1, 1 } do
			rod(g, v(s * 0.7, 1.4, 0.4), v(s * 0.7, 1.4, 2.4), 0.14, paint)
			rod(g, v(s * 0.7, 1.4, 2.4), v(s * 0.7, 0.8, 3.0), 0.14, paint)
			rod(g, v(s * 0.5, 0.9, 0.6), v(s * 0.5, 1.3, 1.8), 0.08, M.chrome)
		end
		rod(g, v(0, 1.9, 1.0), v(0, 1.6, 2.4), 0.1, M.chrome)
		local bk = sub(g, 0, 0.06, 3.2)
		arc(bk, 0.75, 0.1, 0.75, math.pi * 0.85, math.pi * 1.6, 9, 3.0, 0.05, M.dark)
		for _, s in { -1, 1 } do
			tri(bk, v(s * 1.5, 0, -0.6), v(s * 1.5, 0, 0.85), v(s * 1.5, 1.4, -0.65), 0.06, M.dark)
		end
		box(bk, 3.0, 0.05, 0.12, M.steel, 0, 0.02, 0.8)
		for i = 0, 7 do
			box(bk, 0.12, 0.08, 0.2, M.steel, -1.3 + i * 0.37, 0.03, 0.9)
		end
		load(g, 2.8, 0.7, 1.2, 0, 0.1, 3.25)
		for _, p in { { -1.15, 1.0 }, { 1.15, 1.0 }, { -1.15, -1.5 }, { 1.15, -1.5 } } do
			wheel(g, 0.85, 0.6, p[1], 0.85, p[2], { lugs = 20, rim = "#fbc02d", nuts = 10 })
		end
		seatPos = v(0, 2.3, -0.8)
	elseif id == "rotary" then
		local paint = st("#ff6f00", Enum.Material.Metal)
		local white = st("#eceff1")
		box(g, 2.0, 0.35, 7.0, M.dark, 0, 0.85, -0.6)
		box(g, 2.4, 1.6, 1.8, paint, 0, 2.1, 1.6)
		box(g, 2.42, 0.2, 1.82, white, 0, 1.6, 1.6)
		box(g, 2.2, 0.85, 0.02, M.glass, 0, 2.45, 2.51)
		for _, s in { -1, 1 } do
			box(g, 0.02, 0.75, 1.3, M.glass, s * 1.21, 2.45, 1.7)
			mirror(g, s * 1.2, 2.6, 2.3, s)
		end
		box(g, 2.2, 0.15, 0.3, M.black, 0, 3.0, 2.3)
		for i = 0, 5 do
			box(g, 0.25, 0.08, 0.02, M.light, -0.8 + i * 0.32, 3.0, 2.46)
		end
		beacon(g, -1.0, 2.95, 1.0)
		beacon(g, 1.0, 2.95, 1.0)
		seat(g, -0.5, 1.75, 1.4, 1.1)
		steering(g, -0.5, 2.2, 2.0, 0.9)
		box(g, 2.3, 1.4, 2.0, paint, 0, 2.0, -0.4)
		for i = 0, 7 do
			box(g, 0.02, 0.9, 0.12, M.black, 1.16, 2.0, -1.2 + i * 0.22)
		end
		cylY(g, 0.1, 1.4, M.chrome, 0.9, 3.2, -0.9)
		box(g, 2.4, 0.12, 2.8, paint, 0, 1.1, -2.9)
		for _, s in { -1, 1 } do
			box(g, 0.08, 1.2, 2.8, paint, s * 1.18, 1.7, -2.9)
			box(g, 0.15, 0.3, 0.05, M.tail, s * 1.05, 0.9, -4.35)
		end
		box(g, 2.4, 1.2, 0.08, paint, 0, 1.7, -4.28)
		box(g, 2.4, 1.2, 0.08, paint, 0, 1.7, -1.52)
		for i = 0, 4 do
			box(g, 0.05, 1.1, 0.05, M.dark, 1.24, 1.7, -4.1 + i * 0.6)
		end
		load(g, 2.25, 0.9, 2.6, 0, 1.15, -2.9)
		-- rotary head: two drums, impeller and chute
		local head = sub(g, 0, 0, 3.0)
		box(head, 3.4, 1.6, 0.1, paint, 0, 1.0, -0.5)
		box(head, 3.4, 0.1, 1.2, paint, 0, 1.75, 0.05)
		for _, s in { -1, 1 } do
			box(head, 0.1, 1.6, 1.2, paint, s * 1.7, 1.0, 0.05)
			local drum = sub(head, s * 0.85, 0.85, 0.1)
			cylZ(drum, 0.12, 0.9, M.steel, 0, 0, 0)
			for i = 0, 17 do
				local t = i / 18
				local a = t * math.pi * 4
				box(drum, 0.08, 0.6, 0.05, st("#fdd835", Enum.Material.Metal), math.cos(a) * 0.4, math.sin(a) * 0.4, -0.4 + t * 0.85, 0, 0, a)
			end
		end
		box(head, 3.4, 0.08, 0.15, M.steel, 0, 0.06, 0.6)
		cylY(head, 0.3, 1.6, paint, 0, 2.5, -0.3)
		box(head, 0.6, 0.25, 0.7, paint, 0, 3.3, -0.05, 0.35, 0, 0)
		for _, wz in { 1.0, -2.3, -3.6 } do
			for _, s in { -1, 1 } do
				wheel(g, 0.55, 0.4, s * 1.05, 0.55, wz, { lugs = 22, nuts = 10 })
			end
		end
		headlight(g, 0.09, -0.9, 1.35, 2.52)
		headlight(g, 0.09, 0.9, 1.35, 2.52)
		seatPos = v(-0.5, 1.8, 1.4)
	end

	model:SetAttribute("SeatOffset", seatPos * S)
	model:SetAttribute("Standing", standing)
	return finish(model)
end

function Models.Build(id: string): Model
	local tool = Config.GetTool(id)
	if tool.kind == "hand" then
		return Models.BuildHandTool(id)
	end
	return Models.BuildMachine(id)
end

-- ------------------------------------------------------------------ people & props
-- Blocky NPC (no Humanoid), feet at origin, facing -Z.
function Models.BuildNPC(coat: string, hat: string, scarf: string): Model
	local model, g = newModel("Vendor")
	local skin = st("#f1c6a0")
	local pants = st("#3e2723", Enum.Material.Fabric)
	box(g, 0.18, 0.75, 0.2, pants, -0.12, 0.45, 0)
	box(g, 0.18, 0.75, 0.2, pants, 0.12, 0.45, 0)
	box(g, 0.2, 0.12, 0.3, st("#3a2a20"), -0.12, 0.06, 0.04)
	box(g, 0.2, 0.12, 0.3, st("#3a2a20"), 0.12, 0.06, 0.04)
	box(g, 0.55, 0.7, 0.32, st(coat, Enum.Material.Fabric), 0, 1.18, 0)
	box(g, 0.02, 0.6, 0.02, M.steel, 0, 1.18, 0.17)
	cylY(g, 0.17, 0.12, st(scarf, Enum.Material.Fabric), 0, 1.56, 0)
	box(g, 0.09, 0.3, 0.04, st(scarf, Enum.Material.Fabric), 0.1, 1.4, 0.18, 0, 0, 0.15)
	box(g, 0.16, 0.62, 0.18, st(coat, Enum.Material.Fabric), -0.36, 1.2, 0)
	box(g, 0.16, 0.62, 0.18, st(coat, Enum.Material.Fabric), 0.36, 1.2, 0)
	ball(g, 0.085, st("#24324a", Enum.Material.Fabric), -0.36, 0.86, 0)
	ball(g, 0.085, st("#24324a", Enum.Material.Fabric), 0.36, 0.86, 0)
	ball(g, 0.2, skin, 0, 1.8, 0)
	ball(g, 0.025, M.black, -0.07, 1.83, 0.18)
	ball(g, 0.025, M.black, 0.07, 1.83, 0.18)
	ball(g, 0.035, st("#f08a7a"), 0, 1.78, 0.2)
	cylY(g, 0.21, 0.16, st(hat, Enum.Material.Fabric), 0, 1.95, 0)
	cylY(g, 0.22, 0.07, st("#e8eef7", Enum.Material.Fabric), 0, 1.87, 0)
	ball(g, 0.07, st("#e8eef7", Enum.Material.Fabric), 0, 2.08, 0)
	return finish(model)
end

-- Market stall with counter, striped awning and a sign. Faces -Z after finishing.
function Models.BuildStall(color: string, stripe: string, sign: string, width: number): Model
	local model, g = newModel("Stall")
	local wood = M.wood
	box(g, width, 1.0, 0.8, wood, 0, 0.5, 0.6)
	box(g, width + 0.1, 0.08, 0.95, st("#6d4c41", Enum.Material.Wood), 0, 1.04, 0.6)
	for _, x in { -width / 2 + 0.1, width / 2 - 0.1 } do
		box(g, 0.12, 2.6, 0.12, wood, x, 1.3, 0.95)
		box(g, 0.12, 2.9, 0.12, wood, x, 1.45, -0.4)
	end
	box(g, width, 2.6, 0.1, st("#8d6e63", Enum.Material.Wood), 0, 1.4, -0.45)
	local stripes = 9
	for i = 0, stripes - 1 do
		local w = width / stripes
		local c = if i % 2 == 1 then stripe else color
		box(g, w, 0.06, 1.7, st(c, Enum.Material.Fabric), -width / 2 + w * (i + 0.5), 2.85, 0.4, 0.22, 0, 0)
		box(g, w, 0.3, 0.04, st(c, Enum.Material.Fabric), -width / 2 + w * (i + 0.5), 2.55, 1.25)
	end
	box(g, width, 0.08, 1.6, M.snow, 0, 2.95, 0.38, 0.22, 0, 0)
	local board = box(g, width * 0.82, width * 0.22, 0.08, st("#3e2723", Enum.Material.Wood), 0, 3.4, -0.34)
	board.Name = "SignBoard"
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back -- +Z before finishing, so it faces the customers afterwards
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = board
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = sign
	tl.TextScaled = true
	tl.Font = Enum.Font.FredokaOne
	tl.TextColor3 = Color3.fromHex("#fff8e1")
	tl.Parent = sg
	return finish(model)
end

-- Spin wheel disc (8 coloured triangles + labels), centre at origin, facing -Z (toward
-- whoever stands in front of it). Segment i is centred at the top when the disc's Z
-- rotation equals i * 45 degrees.
function Models.BuildWheel(radiusM: number): Model
	local model, g = newModel("Wheel")
	local n = #Config.Wheel
	local seg = math.pi * 2 / n
	local r = radiusM
	for i, s in Config.Wheel do
		local centre = math.pi / 2 - (i - 1) * seg
		local a0, a1 = centre - seg / 2, centre + seg / 2
		tri(g, v(0, 0, 0), v(math.cos(a0) * r, math.sin(a0) * r, 0), v(math.cos(a1) * r, math.sin(a1) * r, 0), 0.06, st(s.color))
		-- label plate along the segment's radius
		local plate = box(g, r * 0.62, r * 0.16, 0.01, st(s.color), math.cos(centre) * r * 0.56, math.sin(centre) * r * 0.56, 0.04, 0, 0, centre)
		plate.Transparency = 1
		plate.Name = "Label" .. i
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Back
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 50
		sg.LightInfluence = 0
		sg.Parent = plate
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Text = s.label
		tl.TextScaled = true
		tl.Font = Enum.Font.FredokaOne
		tl.TextColor3 = Color3.new(1, 1, 1)
		tl.TextStrokeTransparency = 0.4
		tl.Parent = sg
		-- rim pegs
		ball(g, 0.06, st("#ffffff", Enum.Material.Neon), math.cos(a0) * r, math.sin(a0) * r, 0.04)
	end
	-- gold rim made of short segments, and a hub
	for k = 0, 31 do
		local a = k / 32 * math.pi * 2
		box(g, 0.12, r * 2 * math.sin(math.pi / 32) * 1.1, 0.12, st("#ffd54f", Enum.Material.Metal), math.cos(a) * r, math.sin(a) * r, 0, 0, 0, a)
	end
	cylZ(g, r * 0.15, 0.14, st("#ffd54f", Enum.Material.Metal), 0, 0, 0.02)
	return finish(model)
end


-- ------------------------------------------------------------------ scenery
-- Low-poly pine: six-sided cone tiers with a snowy top. Origin at the trunk base.
function Models.BuildPine(k: number): Model
	local model, g = newModel("Pine")
	cylY(g, 0.2 * k, 1.2 * k, st("#5d4037", Enum.Material.Wood), 0, 0.6 * k, 0)
	local green = st("#2f5d3a", Enum.Material.Grass)
	local sides = 6
	for tier = 0, 2 do
		local r = (1.7 - tier * 0.45) * k
		local h = 1.7 * k
		local y = (1.0 + tier * 1.05) * k
		local style = if tier == 2 then M.snow else green
		local apex = v(0, y + h, 0)
		for i = 0, sides - 1 do
			local a0, a1 = i / sides * math.pi * 2, (i + 1) / sides * math.pi * 2
			tri(g, apex, v(math.cos(a0) * r, y, math.sin(a0) * r), v(math.cos(a1) * r, y, math.sin(a1) * r), 0.08, style)
		end
		-- snow ring on the lower tiers
		if tier < 2 then
			cylY(g, r * 0.45, 0.12 * k, M.snow, 0, y + h * 0.62, 0)
		end
	end
	return model
end

-- House with a gabled, snow-covered roof. Front door faces -Z after finishing.
function Models.BuildHouse(w: number, d: number, color: string, extras: boolean): Model
	local model, g = newModel("House")
	local wall = st(color, Enum.Material.Brick)
	local trim = st("#f5f1e8")
	local roof = st("#5d4037", Enum.Material.Slate)
	local h = 3.2
	box(g, w, h, d, wall, 0, h / 2, 0)
	box(g, w + 0.1, 0.3, d + 0.1, st("#8e8e8e", Enum.Material.Concrete), 0, 0.15, 0)
	-- gable ends
	local rh = 2.2
	for _, x in { -w / 2, w / 2 } do
		tri(g, v(x, h, -d / 2), v(x, h, d / 2), v(x, h + rh, 0), 0.1, wall)
	end
	-- roof planes and snow
	local half = d / 2 + 0.5
	local slope = math.atan2(rh, half)
	local len = math.sqrt(half * half + rh * rh)
	for _, s in { -1, 1 } do
		box(g, w + 0.8, 0.15, len, roof, 0, h + rh / 2, s * half / 2, s * slope, 0, 0)
		box(g, w + 0.9, 0.18, len * 0.98, M.snow, 0, h + rh / 2 + 0.16, s * half / 2, s * slope, 0, 0)
	end
	box(g, 0.7, 2, 0.7, st("#8d4b3a", Enum.Material.Brick), w * 0.25, h + 1.6, -d * 0.15)
	box(g, 0.8, 0.15, 0.8, M.snow, w * 0.25, h + 2.65, -d * 0.15)
	-- front (+Z here)
	box(g, 1.1, 2.1, 0.08, st("#5b3a29", Enum.Material.Wood), 0, 1.05, d / 2 + 0.04)
	ball(g, 0.05, st("#d4af37", Enum.Material.Metal), 0.4, 1.05, d / 2 + 0.1)
	box(g, 1.3, 0.12, 0.1, trim, 0, 2.15, d / 2 + 0.05)
	local win = st("#ffe7a3", Enum.Material.Neon)
	for _, x in { -w * 0.3, w * 0.3 } do
		box(g, 1.2, 1.0, 0.06, win, x, 1.8, d / 2 + 0.03)
		box(g, 1.35, 0.1, 0.12, trim, x, 1.25, d / 2 + 0.06)
		box(g, 0.06, 1.0, 0.1, trim, x, 1.8, d / 2 + 0.06)
		box(g, 1.2, 0.06, 0.1, trim, x, 1.8, d / 2 + 0.06)
	end
	for _, s in { -1, 1 } do
		box(g, 0.06, 1.0, 1.2, win, s * (w / 2 + 0.03), 1.8, 0)
	end
	box(g, 1.8, 0.2, 0.8, st("#9e9e9e", Enum.Material.Concrete), 0, 0.1, d / 2 + 0.4)
	-- wreath
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		ball(g, 0.08, st("#2e7d32", Enum.Material.Grass), math.cos(a) * 0.2, 1.6 + math.sin(a) * 0.2, d / 2 + 0.12)
	end
	ball(g, 0.07, st("#c62828"), 0, 1.4, d / 2 + 0.16)
	if extras then
		cylY(g, 0.05, 1.1, st("#5d4037", Enum.Material.Wood), w * 0.45, 0.55, d / 2 + 2.6)
		box(g, 0.3, 0.25, 0.45, st("#263238", Enum.Material.Metal), w * 0.45, 1.2, d / 2 + 2.6)
	end
	return finish(model)
end

function Models.BuildLamp(): Model
	local model, g = newModel("Lamp")
	local iron = st("#1f2a33", Enum.Material.Metal)
	cylY(g, 0.1, 4, iron, 0, 2, 0)
	cylY(g, 0.25, 0.3, iron, 0, 0.15, 0)
	local bulb = box(g, 0.4, 0.5, 0.4, st("#fff3c4", Enum.Material.Neon), 0, 4.2, 0)
	box(g, 0.55, 0.08, 0.55, iron, 0, 4.48, 0)
	box(g, 0.6, 0.08, 0.6, M.snow, 0, 4.55, 0)
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromHex("#ffd27a")
	light.Shadows = false
	light.Parent = bulb
	return model
end

function Models.BuildGift(): Model
	local model, g = newModel("Gift")
	local purple, gold = st("#8e24aa"), st("#ffd54f", Enum.Material.Metal)
	box(g, 1.1, 1.0, 1.1, purple, 0, 0.5, 0)
	box(g, 1.2, 0.2, 1.2, purple, 0, 1.08, 0)
	box(g, 0.2, 1.22, 1.14, gold, 0, 0.6, 0)
	box(g, 1.14, 1.22, 0.2, gold, 0, 0.6, 0)
	for _, s in { -1, 1 } do
		box(g, 0.06, 0.35, 0.35, gold, s * 0.18, 1.32, 0, 0.785, 0, s * 0.5)
	end
	return model
end

-- ------------------------------------------------------------------ event models
local function reindeer(g: Frame, x: number, z: number, lead: boolean)
	local fur = st("#7b5236", Enum.Material.Fabric)
	local belly = st("#c9a27e", Enum.Material.Fabric)
	local hoof = st("#2b211b")
	local r = sub(g, x, 0, z)
	blob(r, 0.36, 0.38, 0.85, fur, 0, 0.95, 0)
	blob(r, 0.28, 0.2, 0.6, belly, 0, 0.85, 0)
	blob(r, 0.14, 0.14, 0.12, st("#f3eee6", Enum.Material.Fabric), 0, 1.02, -0.43) -- tail
	for _, lx in { -0.11, 0.11 } do
		for _, lz in { -0.28, 0.28 } do
			box(r, 0.07, 0.62, 0.08, fur, lx, 0.45, lz)
			box(r, 0.09, 0.08, 0.1, hoof, lx, 0.12, lz + 0.01)
		end
	end
	rod(r, v(0, 1.05, 0.33), v(0, 1.38, 0.52), 0.07, fur) -- neck
	blob(r, 0.2, 0.2, 0.34, fur, 0, 1.45, 0.62) -- head
	blob(r, 0.13, 0.12, 0.14, belly, 0, 1.41, 0.78) -- muzzle
	ball(r, 0.045, if lead then st("#ff2d2d", Enum.Material.Neon) else M.black, 0, 1.43, 0.86)
	ball(r, 0.025, M.black, -0.08, 1.5, 0.7)
	ball(r, 0.025, M.black, 0.08, 1.5, 0.7)
	box(r, 0.05, 0.1, 0.04, fur, -0.12, 1.55, 0.56, 0, 0, 0.7) -- ears
	box(r, 0.05, 0.1, 0.04, fur, 0.12, 1.55, 0.56, 0, 0, -0.7)
	local antler = st("#e2d2b0")
	for _, sx in { -1, 1 } do
		rod(r, v(sx * 0.06, 1.55, 0.6), v(sx * 0.2, 1.85, 0.55), 0.02, antler)
		rod(r, v(sx * 0.2, 1.85, 0.55), v(sx * 0.3, 2.0, 0.45), 0.018, antler)
		rod(r, v(sx * 0.15, 1.75, 0.57), v(sx * 0.12, 1.92, 0.68), 0.016, antler)
		rod(r, v(sx * 0.24, 1.92, 0.52), v(sx * 0.2, 2.06, 0.6), 0.015, antler)
	end
	-- harness collar with a gold bell
	cylZ(r, 0.11, 0.05, st("#b71c1c", Enum.Material.Fabric), 0, 1.15, 0.36)
	ball(r, 0.04, st("#ffd54f", Enum.Material.Metal), 0, 1.03, 0.4)
end

-- Santa's sleigh with Santa, his sack and three reindeer (two side by side, Rudolph in
-- front). Origin = ground under the sleigh; faces -Z in Roblox after finishing.
function Models.BuildSleigh(): Model
	local model, g = newModel("SantaSleigh")
	local red = st("#c62828")
	local gold = st("#ffcc33", Enum.Material.Metal)
	-- runners with curled fronts
	for _, x in { -0.42, 0.42 } do
		box(g, 0.05, 0.05, 1.7, gold, x, 0.08, 0)
		arc(g, 0.25, 0.85, 0.17, math.pi, -0.3, 7, 0.05, 0.05, gold, x)
		for _, z in { -0.5, 0.4 } do
			box(g, 0.04, 0.28, 0.04, gold, x, 0.24, z)
		end
	end
	-- body
	box(g, 0.95, 0.42, 1.4, red, 0, 0.6, -0.05)
	box(g, 0.95, 0.5, 0.12, red, 0, 1.0, -0.72) -- tall back
	box(g, 0.99, 0.06, 1.44, gold, 0, 0.83, -0.05)
	box(g, 0.95, 0.35, 0.1, red, 0, 0.9, 0.62, -0.5, 0, 0) -- front curl
	ball(g, 0.08, gold, -0.48, 1.25, -0.72)
	ball(g, 0.08, gold, 0.48, 1.25, -0.72)
	box(g, 0.85, 0.08, 0.5, st("#1b5e20", Enum.Material.Fabric), 0, 0.86, -0.4) -- seat
	-- the sack of presents
	blob(g, 0.6, 0.7, 0.5, st("#8d6e63", Enum.Material.Fabric), 0.15, 1.15, -0.55)
	box(g, 0.22, 0.22, 0.22, st("#2e7d32"), 0.05, 1.5, -0.55, 0.3, 0.4, 0)
	box(g, 0.2, 0.2, 0.2, st("#1565c0"), 0.28, 1.47, -0.5, 0.2, -0.5, 0.2)
	-- Santa
	local sx = -0.18
	box(g, 0.42, 0.5, 0.36, st("#d32f2f", Enum.Material.Fabric), sx, 1.15, -0.32)
	box(g, 0.44, 0.08, 0.38, M.black, sx, 1.02, -0.32)
	box(g, 0.1, 0.06, 0.02, gold, sx, 1.02, -0.12)
	box(g, 0.44, 0.1, 0.38, st("#ffffff", Enum.Material.Fabric), sx, 0.92, -0.32)
	for _, ax in { -0.26, 0.26 } do
		rod(g, v(sx + ax, 1.33, -0.32), v(sx + ax * 0.9, 1.12, 0.0), 0.075, st("#d32f2f", Enum.Material.Fabric))
		ball(g, 0.065, M.black, sx + ax * 0.85, 1.1, 0.04)
	end
	ball(g, 0.17, st("#f1c6a0"), sx, 1.55, -0.3)
	blob(g, 0.3, 0.28, 0.16, st("#ffffff", Enum.Material.Fabric), sx, 1.45, -0.18) -- beard
	ball(g, 0.035, st("#e57373"), sx, 1.56, -0.13) -- nose
	ball(g, 0.022, M.black, sx - 0.06, 1.6, -0.15)
	ball(g, 0.022, M.black, sx + 0.06, 1.6, -0.15)
	cylY(g, 0.18, 0.08, st("#ffffff", Enum.Material.Fabric), sx, 1.68, -0.3)
	rod(g, v(sx, 1.7, -0.3), v(sx + 0.08, 1.95, -0.42), 0.12, st("#d32f2f", Enum.Material.Fabric))
	ball(g, 0.06, st("#ffffff", Enum.Material.Fabric), sx + 0.1, 1.98, -0.46)
	-- reindeer and harness
	reindeer(g, -0.32, 1.6, false)
	reindeer(g, 0.32, 1.6, false)
	reindeer(g, 0, 2.75, true)
	local strap = st("#6d1b1b", Enum.Material.Fabric)
	rod(g, v(-0.3, 0.85, 0.6), v(-0.32, 1.12, 1.95), 0.02, strap)
	rod(g, v(0.3, 0.85, 0.6), v(0.32, 1.12, 1.95), 0.02, strap)
	rod(g, v(0, 1.12, 1.95), v(0, 1.12, 3.1), 0.02, strap)
	rod(g, v(-0.32, 1.12, 1.95), v(0.32, 1.12, 1.95), 0.02, strap)
	rod(g, v(sx - 0.22, 1.1, 0.04), v(-0.32, 1.12, 1.95), 0.01, M.black) -- reins
	rod(g, v(sx + 0.22, 1.1, 0.04), v(0.32, 1.12, 1.95), 0.01, M.black)
	return finish(model)
end

-- The Yeti: a big shaggy snow beast, about 4.6 m tall. Origin at its feet, faces -Z.
function Models.BuildYeti(): Model
	local model, g = newModel("Yeti")
	local fur = st("#eef3fa", Enum.Material.Snow)
	local shade = st("#d3dfee", Enum.Material.Snow)
	local skin = st("#6f8fb3")
	local dark = st("#22324a")
	-- legs and feet
	for _, x in { -0.45, 0.45 } do
		blob(g, 0.7, 1.4, 0.75, fur, x, 0.9, 0)
		blob(g, 0.6, 0.3, 0.9, skin, x, 0.15, 0.15)
		for _, t in { -0.18, 0, 0.18 } do
			ball(g, 0.07, st("#e9e2cf"), x + t, 0.1, 0.6)
		end
	end
	-- body
	blob(g, 2.0, 2.2, 1.5, fur, 0, 2.6, 0)
	blob(g, 1.2, 1.3, 0.4, shade, 0, 2.5, 0.6) -- chest
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		blob(g, 0.5, 0.6, 0.5, fur, math.cos(a) * 0.9, 1.65, math.sin(a) * 0.65) -- shaggy fringe
	end
	-- arms
	for _, sx in { -1, 1 } do
		local arm = sub(g, sx * 1.05, 3.2, 0, 0, 0, sx * 0.25)
		blob(arm, 0.7, 1.9, 0.7, fur, sx * 0.1, -0.9, 0)
		blob(arm, 0.55, 0.45, 0.6, skin, sx * 0.2, -1.9, 0.05)
		for _, t in { -0.15, 0, 0.15 } do
			box(arm, 0.06, 0.18, 0.06, st("#e9e2cf"), sx * 0.2 + t, -2.15, 0.2, 0.4, 0, 0)
		end
	end
	-- head
	blob(g, 1.3, 1.15, 1.2, fur, 0, 4.05, 0.05)
	blob(g, 0.9, 0.75, 0.3, skin, 0, 3.95, 0.55) -- face
	blob(g, 0.24, 0.16, 0.08, st("#ffffff"), -0.2, 4.12, 0.7)
	blob(g, 0.24, 0.16, 0.08, st("#ffffff"), 0.2, 4.12, 0.7)
	ball(g, 0.06, st("#d50000", Enum.Material.Neon), -0.2, 4.12, 0.74)
	ball(g, 0.06, st("#d50000", Enum.Material.Neon), 0.2, 4.12, 0.74)
	box(g, 0.3, 0.06, 0.06, dark, -0.2, 4.25, 0.7, 0, 0, -0.35) -- angry brows
	box(g, 0.3, 0.06, 0.06, dark, 0.2, 4.25, 0.7, 0, 0, 0.35)
	blob(g, 0.5, 0.25, 0.1, dark, 0, 3.75, 0.68) -- mouth
	for _, x in { -0.16, 0.16 } do
		box(g, 0.07, 0.14, 0.04, st("#ffffff"), x, 3.82, 0.72) -- fangs
	end
	-- horns
	local horn = st("#d9c9a3")
	for _, sx in { -1, 1 } do
		rod(g, v(sx * 0.45, 4.4, 0), v(sx * 0.8, 4.75, -0.1), 0.1, horn)
		rod(g, v(sx * 0.8, 4.75, -0.1), v(sx * 0.85, 5.05, 0.15), 0.07, horn)
	end
	return finish(model)
end

-- Decorated plaza tree.
function Models.BuildXmasTree(): Model
	local model = Models.BuildPine(1.5)
	local g = { model = model, cf = CFrame.new() }
	local colors = { "#e53935", "#ffd54f", "#42a5f5", "#ab47bc", "#66bb6a" }
	local rng = Random.new(7)
	for i = 1, 36 do
		local y = 1.6 + rng:NextNumber() * 4.4
		local r = math.max(0.3, (2.5 - (y - 1.5) * 0.5)) * 0.95
		local a = rng:NextNumber() * math.pi * 2
		ball(g, 0.13, st(colors[i % #colors + 1], Enum.Material.Neon), math.cos(a) * r, y, math.sin(a) * r)
	end
	ball(g, 0.3, st("#ffd54f", Enum.Material.Neon), 0, 7.2, 0)
	return model
end

-- Anchor or weld a model for use. When `weldTo` is given, every part is unanchored,
-- massless and welded to the model's Root.
function Models.Weld(model: Model)
	local root = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if d ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = d
				w.Parent = d
			end
			d.Anchored = false
		end
	end
end

-- Weld every part to the Root and keep only the Root anchored. Moving the model is then a
-- single CFrame write on the Root (model.PrimaryPart.CFrame = ...), which is far cheaper
-- than PivotTo on a model with hundreds of parts, and only one part replicates.
function Models.Rig(model: Model): BasePart
	Models.Weld(model)
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	return root
end

-- turn off shadows on every part (big savings for detailed models on display)
function Models.NoShadows(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
end

return Models
