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
function WorldEffects.refreshDisplays()
	local owned = Shop.ownedSet()
	local equipped = player:GetAttribute("Equipped")
	for _, holder in CollectionService:GetTagged("ToolDisplay") do
		local id = holder:GetAttribute("ToolId")
		local hit = holder:FindFirstChild("Hit")
		local bb = hit and hit:FindFirstChildOfClass("BillboardGui")
		local frame = bb and bb:FindFirstChildOfClass("Frame")
		local sub = frame and frame:FindFirstChild("Subtitle")
		if sub then
			local tool = Config.GetTool(id)
			sub.Text = if equipped == id then "EQUIPPED" elseif owned[id] then "OWNED" else fmt(tool.price) .. " coins"
			sub.TextColor3 = if owned[id] then Color3.fromHex("#b9f6ca") else C.accent
		end
	end
end
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
