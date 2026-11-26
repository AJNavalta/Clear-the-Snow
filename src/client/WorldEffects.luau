--!nonstrict
-- Local-only effects in the world: your own snow pile mound, falling snow, the
-- price / owned labels on the tool display, and the display turntables.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.UI.Theme)
local Shop = require(script.Parent.UI.ShopPanel)
local C, new = Theme.C, Theme.new
local fmt = Config.FormatNumber
local H = Config.Hub

local player = Players.LocalPlayer

local WorldEffects = {}

-- your own pile mound (each player sees their own pile)
local mound = new("Part", {
	Name = "MyPile",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Material = Enum.Material.Snow,
	Color = Color3.fromRGB(246, 250, 255),
	Size = Vector3.new(H.PileRadius * 2, 0.4, H.PileRadius * 2),
	CFrame = CFrame.new(H.Pile),
	Parent = Workspace,
}, { new("SpecialMesh", { MeshType = Enum.MeshType.Sphere }) })

-- falling snow around the camera
local snowEmitterPart = new("Part", {
	Name = "Snowfall",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Transparency = 1,
	Size = Vector3.new(140, 1, 140),
	Parent = Workspace,
})
new("ParticleEmitter", {
	Texture = "rbxasset://textures/particles/sparkles_main.dds",
	Color = ColorSequence.new(Color3.new(1, 1, 1)),
	LightEmission = 0.4,
	Size = NumberSequence.new(0.35),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.6) }),
	Lifetime = NumberRange.new(8, 12),
	Rate = 150,
	Speed = NumberRange.new(5, 8),
	SpreadAngle = Vector2.new(15, 15),
	Acceleration = Vector3.new(0.6, 0, 0.3),
	EmissionDirection = Enum.NormalId.Bottom,
	RotSpeed = NumberRange.new(-40, 40),
	Parent = snowEmitterPart,
})

-- display labels: price, OWNED or EQUIPPED
local function labelOf(holder: Instance)
	local hit = holder:FindFirstChild("Hit")
	return hit and hit:FindFirstChild("Label")
end

function WorldEffects.refreshDisplays()
	local owned = Shop.ownedSet()
	local equipped = player:GetAttribute("Equipped")
	for _, holder in CollectionService:GetTagged("ToolDisplay") do
		local id = holder:GetAttribute("ToolId")
		local bb = labelOf(holder)
		local sub = bb and bb:FindFirstChild("Subtitle")
		if sub then
			local tool = Config.GetTool(id)
			sub.Text = if equipped == id then "EQUIPPED" elseif owned[id] then "OWNED" else fmt(tool.price) .. " coins"
			sub.TextColor3 = if owned[id] then Color3.fromHex("#b9f6ca") else C.accent
		end
	end
end

-- The tool you point at (or stand closest to) on the display is "selected": its label grows,
-- turns gold and shows on top, and the tool gets a glowing outline.
local highlight = new("Highlight", {
	Name = "DisplayHighlight",
	FillColor = Color3.fromHex("#ffd54f"),
	FillTransparency = 0.75,
	OutlineColor = Color3.fromHex("#ffd54f"),
	OutlineTransparency = 0,
	DepthMode = Enum.HighlightDepthMode.Occluded,
	Enabled = false,
	Parent = Workspace,
})
local mouse = player:GetMouse()
local selected: Instance? = nil
local function setSelected(holder: Instance?)
	if holder == selected then
		return
	end
	if selected then
		local bb = labelOf(selected)
		if bb then
			bb.Size = UDim2.fromScale(3.8, 1.1)
			bb.AlwaysOnTop = false
			bb.Title.TextColor3 = Color3.new(1, 1, 1)
		end
	end
	selected = holder
	if holder then
		local bb = labelOf(holder)
		if bb then
			bb.Size = UDim2.fromScale(6.5, 1.9)
			bb.AlwaysOnTop = true
			bb.Title.TextColor3 = C.accent
		end
		highlight.Adornee = holder:FindFirstChild("Item")
		highlight.Enabled = true
	else
		highlight.Enabled = false
		highlight.Adornee = nil
	end
end

local function findSelected(): Instance?
	-- pointing at a tool (or its invisible click box)
	local target = mouse.Target
	while target and target ~= Workspace do
		if target:GetAttribute("ToolId") then
			return target
		end
		target = target.Parent
	end
	-- otherwise the closest one within a few steps
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local best, bestD = nil, 9
	for _, holder in CollectionService:GetTagged("ToolDisplay") do
		local hit = holder:FindFirstChild("Hit")
		if hit then
			local d = (Vector3.new(hit.Position.X, hrp.Position.Y, hit.Position.Z) - hrp.Position).Magnitude
			if d < bestD then
				best, bestD = holder, d
			end
		end
	end
	return best
end
task.spawn(function()
	while true do
		task.wait(0.1)
		setSelected(findSelected())
	end
end)
player:GetAttributeChangedSignal("Owned"):Connect(WorldEffects.refreshDisplays)
player:GetAttributeChangedSignal("Equipped"):Connect(WorldEffects.refreshDisplays)
task.delay(2, WorldEffects.refreshDisplays)

-- turntables
local turntables = {}
local function addTurntable(holder: Instance)
	local item = holder:WaitForChild("Item", 10)
	if item and item:IsA("Model") then
		local centre = item:GetAttribute("SpinCentre")
		local pivot = item.PrimaryPart.CFrame
		table.insert(turntables, { root = item.PrimaryPart, centre = centre, offset = CFrame.new(centre):Inverse() * pivot, phase = #turntables })
	end
end
for _, h in CollectionService:GetTagged("ToolDisplay") do
	task.spawn(addTurntable, h)
end
CollectionService:GetInstanceAddedSignal("ToolDisplay"):Connect(addTurntable)

local tAcc = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local cam = Workspace.CurrentCamera
	snowEmitterPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 40, 0))
	-- pile mound grows with your pile
	local pile = player:GetAttribute("Pile") or 0
	local h = math.min(9, 0.4 + math.log10(1 + pile) * 2.4)
	local cur = mound.Size.Y
	if math.abs(h * 2 - cur) > 0.02 then -- only resize while it's actually growing
		local y = cur + (h * 2 - cur) * math.min(1, dt * 4)
		mound.Size = Vector3.new(H.PileRadius * 2, y, H.PileRadius * 2)
		mound.CFrame = CFrame.new(H.Pile + Vector3.new(0, 0.3, 0))
	end
	-- turntables (throttled, only near the camera)
	tAcc += dt
	if tAcc > 1 / 20 then
		tAcc = 0
		for _, tt in turntables do
			if (cam.CFrame.Position - tt.centre).Magnitude < 90 then
				tt.root.CFrame = CFrame.new(tt.centre) * CFrame.Angles(0, t * 0.5 + tt.phase, 0) * tt.offset
			end
		end
	end
end)

return WorldEffects
