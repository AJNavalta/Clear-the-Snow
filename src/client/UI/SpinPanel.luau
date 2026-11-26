--!nonstrict
-- Lucky Spin. The wheel on screen is the same 3D wheel model as the one in the plaza,
-- shown in a ViewportFrame, with the prize names drawn on top. Both wheels turn together.
-- Prizes and their chances are set in Config.Wheel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Models = require(Shared.Models)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Theme = require(script.Parent.Theme)
local Panels = require(script.Parent.Panels)
local Hud = require(script.Parent.Hud)
local C, new, label, button = Theme.C, Theme.new, Theme.label, Theme.button
local fmt = Config.FormatNumber

local player = Players.LocalPlayer

local Spin = {}

local panel = Panels.make("Spin", "Lucky Spin", Vector2.new(480, 580))
Spin.panel = panel

local WHEEL_PX = 360
local holder = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 62),
	Size = UDim2.fromOffset(WHEEL_PX, WHEEL_PX),
	ZIndex = 11,
	Parent = panel,
})
-- dark backing disc so the wheel edge reads cleanly
new("Frame", { BackgroundColor3 = Color3.fromRGB(10, 22, 44), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.02, 1.02), ZIndex = 11, Parent = holder }, { Theme.round() })

-- the 3D wheel
local RADIUS_M = 1
local view = new("ViewportFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Ambient = Color3.fromRGB(210, 210, 210),
	LightColor = Color3.fromRGB(255, 255, 255),
	LightDirection = Vector3.new(0.3, -0.5, 1),
	ZIndex = 12,
	Parent = holder,
})
local uiWheel = Models.BuildWheel(RADIUS_M)
uiWheel:PivotTo(CFrame.new())
uiWheel.Parent = view
local rim = RADIUS_M * Config.STUDS_PER_METER + 0.2
local cam = new("Camera", { FieldOfView = 30, Parent = view })
cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, -rim / math.tan(math.rad(15))), Vector3.zero)
view.CurrentCamera = cam

-- prize names, laid out to match the model: segment i is (i - 1) * 45 degrees clockwise from the top
local nSeg = #Config.Wheel
local segDeg = 360 / nSeg
local labels = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 13, Parent = holder })
for i, s in Config.Wheel do
	local a = math.rad((i - 1) * segDeg)
	label({
		Text = s.label,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + math.sin(a) * 0.29, 0.5 - math.cos(a) * 0.29),
		Size = UDim2.fromScale(0.34, 0.085),
		Rotation = (i - 1) * segDeg - 90,
		Font = Theme.TitleFont,
		TextStrokeTransparency = 0.3,
		ZIndex = 14,
		Parent = labels,
	})
end
-- pointer at the top
local pointer = Theme.arrow(46, C.bad, 16)
pointer.Position = UDim2.new(0.5, 0, 0, 4)
pointer.Parent = holder

local spinBtn = button({ Text = "Spin!", Position = UDim2.new(0, 0, 1, -100), Size = UDim2.new(1, 0, 0, 50), ZIndex = 11, Parent = panel })
local info = label({ Text = "", Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(1, 0, 0, 34), Font = Theme.BodyFont, TextColor3 = C.muted, TextWrapped = true, ZIndex = 11, Parent = panel })

local spinning = false
function Spin.render()
	local n = player:GetAttribute("Spins") or 0
	local free = player:GetAttribute("FreeSpin")
	spinBtn.Text = if spinning then "Spinning..." elseif free then "Free Spin!" elseif n > 0 then "Spin! (" .. n .. " left)" else "No spins left"
	spinBtn.BackgroundColor3 = if not spinning and n > 0 then C.accent else C.disabled
	local base = math.max(10, math.floor((player:GetAttribute("ProgressCoins") or 10) * 0.1 + 0.5))
	info.Text = if n == 0
		then "Free spin resets in " .. Panels.untilTomorrow() .. ". Daily rewards give bonus spins."
		else "Coin prizes right now: " .. fmt(base) .. " up to " .. fmt(base * 25) .. " coins"
end

-- the 3D wheel in the plaza turns with this one
local plazaWheel, plazaBase
task.spawn(function()
	plazaWheel = CollectionService:GetTagged("SpinWheel")[1]
	while not plazaWheel do
		task.wait(1)
		plazaWheel = CollectionService:GetTagged("SpinWheel")[1]
	end
	plazaBase = plazaWheel.PrimaryPart.CFrame
end)

local angle = 0 -- degrees, clockwise as you look at the wheel
local function setWheel(deg: number)
	angle = deg
	local rot = CFrame.Angles(0, 0, math.rad(deg))
	if panel.Visible then
		uiWheel:PivotTo(rot)
		labels.Rotation = deg
	end
	if plazaWheel and plazaBase then
		plazaWheel.PrimaryPart.CFrame = plazaBase * rot
	end
end

spinBtn.Activated:Connect(function()
	if spinning or (player:GetAttribute("Spins") or 0) <= 0 then
		return
	end
	spinning = true
	Panels.locked = true
	Spin.render()
	local result = Remotes.Spin:InvokeServer()
	if not result then
		spinning = false
		Panels.locked = false
		Spin.render()
		return
	end
	local start = angle
	local want = -(result.index - 1) * segDeg + (math.random() - 0.5) * segDeg * 0.6
	local finish = start + 360 * 6 + (want - start) % 360
	local t0, dur = os.clock(), 4.2
	while true do
		local k = math.min(1, (os.clock() - t0) / dur)
		setWheel(start + (finish - start) * (1 - (1 - k) ^ 4))
		if k >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	setWheel(angle % 360)
	spinning = false
	Panels.locked = false
	Hud.toast(Config.Wheel[result.index].label .. "!\n" .. result.message, 3)
	Spin.render()
end)

-- slow idle turn while nobody is spinning
RunService.RenderStepped:Connect(function(dt)
	if not spinning and (panel.Visible or plazaBase) then
		setWheel((angle + dt * 10) % 360)
	end
end)

function Spin.open()
	Panels.closeAll()
	Spin.render()
	panel.Visible = true
	setWheel(angle)
end

function Spin.isSpinning(): boolean
	return spinning
end

return Spin
