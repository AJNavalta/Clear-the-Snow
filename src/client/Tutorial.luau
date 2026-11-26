--!nonstrict
-- Hands-on tutorial: a card at the top of the screen says what to do, a yellow arrow
-- floats over where to go, a line on the ground leads there, and an arrow at the edge of
-- the screen points the way when the target is out of view.
--
-- The server decides the current step (player attribute "Tutorial": 1..5, 0 = done) and
-- moves it on as you play. The step text lives in Config.Tutorial.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Theme = require(script.Parent.UI.Theme)
local Panels = require(script.Parent.UI.Panels)
local Hud = require(script.Parent.UI.Hud)
local Shop = require(script.Parent.UI.ShopPanel)
local C, new, label, button = Theme.C, Theme.new, Theme.label, Theme.button
local H = Config.Hub

local player = Players.LocalPlayer
local gui = Panels.gui
local TOTAL = 4 -- steps that have a task (step 5 is the "enjoy" card)

local Tutorial = {}

-- ---------------------------------------------------------------- the step card
local card = new("Frame", {
	Name = "TutorialCard",
	BackgroundColor3 = C.panel,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(480, 104),
	Visible = false,
	ZIndex = 20,
	Parent = gui,
}, { Theme.corner(16), Theme.pad(12), new("UIStroke", { Color = C.accent, Thickness = 3 }), new("UISizeConstraint", { MaxSize = Vector2.new(480, 104) }) })
local stepText = label({ Text = "STEP 1 OF 4", Size = UDim2.new(1, -80, 0, 16), TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = card })
local titleText = label({ Text = "", Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 30), Font = Theme.TitleFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = card })
local bodyText = label({ Text = "", Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 30), Font = Theme.BodyFont, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 21, Parent = card })
local skip = button({ Text = "Skip", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(64, 24), BackgroundColor3 = C.panel2, TextColor3 = C.muted, ZIndex = 22, Parent = card })
skip.Activated:Connect(function()
	Remotes.TutorialAction:FireServer("skip")
end)

-- ---------------------------------------------------------------- arrow at the screen edge
local edgeArrow = Theme.arrow(64, C.accent, 30)
edgeArrow.Visible = false
edgeArrow.Parent = gui

-- ---------------------------------------------------------------- arrow over the target in the world
local marker = new("Part", {
	Name = "TutorialMarker",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Transparency = 1,
	Size = Vector3.new(1, 1, 1),
	Parent = Workspace,
})
local markerGui = new("BillboardGui", {
	Size = UDim2.fromOffset(170, 150),
	StudsOffsetWorldSpace = Vector3.new(0, 5, 0),
	AlwaysOnTop = true,
	LightInfluence = 0,
	MaxDistance = 1e5,
	Enabled = false,
	Parent = marker,
})
local markerLabel = label({ Text = "", Size = UDim2.new(1, 0, 0, 46), Font = Theme.TitleFont, TextStrokeTransparency = 0.2, TextColor3 = C.accent, Parent = markerGui })
local markerArrow = Theme.arrow(70, C.accent, 2)
markerArrow.Parent = markerGui

-- a glowing line on the ground from you to the target
local groundAttach = new("Attachment", { Position = Vector3.new(0, 0.4, 0), Parent = marker })
local playerAttach = new("Attachment", { Name = "TutorialBeamStart" })
local beam = new("Beam", {
	Attachment0 = playerAttach,
	Attachment1 = groundAttach,
	Color = ColorSequence.new(C.accent),
	LightEmission = 1,
	LightInfluence = 0,
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(1, 0.2) }),
	Width0 = 0.6,
	Width1 = 0.6,
	FaceCamera = true,
	Segments = 1,
	Enabled = false,
	Parent = marker,
})
local function hookCharacter(char: Model)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if hrp then
		playerAttach.Position = Vector3.new(0, -2.6, 0)
		playerAttach.Parent = hrp
	end
end
player.CharacterAdded:Connect(hookCharacter)
if player.Character then
	task.spawn(hookCharacter, player.Character)
end

-- ---------------------------------------------------------------- where each step points
local snowTarget: BasePart? = nil
local lastSnowSearch = 0

-- nearest tile that still has a good amount of snow on it
local function findSnow(from: Vector3): BasePart?
	local folder = Workspace:FindFirstChild("Snow")
	if not folder then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") and p.Transparency < 0.5 and p.Size.Y > 1.4 then
			local d = (p.Position - from).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

local function displayFor(id: string): BasePart?
	for _, holder in CollectionService:GetTagged("ToolDisplay") do
		if holder:GetAttribute("ToolId") == id then
			return holder:FindFirstChild("Hit")
		end
	end
	return nil
end

-- returns ground position, label, and whether to hide guidance when you're close
local function targetFor(step: number, hrp: BasePart): (Vector3?, string?, boolean)
	if step == 1 then
		local now = os.clock()
		if not snowTarget or snowTarget.Size.Y < 0.8 or snowTarget.Transparency > 0.5 or now - lastSnowSearch > 4 then
			lastSnowSearch = now
			snowTarget = findSnow(hrp.Position)
		end
		if snowTarget then
			return Vector3.new(snowTarget.Position.X, 0, snowTarget.Position.Z), "SNOW", true
		end
		return nil, nil, true
	elseif step == 2 then
		return H.Pile, "SNOW PILE", false
	elseif step == 3 then
		return H.Sell + Vector3.new(0, 0, 4), "SNOW BUYER", false
	elseif step == 4 then
		local id = Shop.nextToolId()
		local hit = id and displayFor(id)
		if hit then
			return Vector3.new(hit.Position.X, 0, hit.Position.Z), "BUY: " .. Config.GetTool(id).name, false
		end
		return H.Shop + Vector3.new(0, 0, 4), "TOOL SHOP", false
	end
	return nil, nil, false
end

-- ---------------------------------------------------------------- card text
local function stepInfo(step: number)
	local s = Config.Tutorial.Steps[step]
	if not s then
		return "", ""
	end
	local text = if Panels.isTouch and s.touchText then s.touchText else s.text
	if step == 4 then
		local id = Shop.nextToolId()
		text = string.format(text, if id then Config.GetTool(id).name else "next tool")
	end
	return s.title, text
end

local current = -1
local function showStep(step: number)
	if step == current then
		return
	end
	local prev = current
	current = step
	snowTarget = nil
	if step >= 1 and step <= 5 then
		local title, text = stepInfo(step)
		titleText.Text = title
		bodyText.Text = text
		stepText.Text = if step <= TOTAL then "STEP " .. step .. " OF " .. TOTAL else "TUTORIAL COMPLETE"
		skip.Visible = step <= TOTAL
		card.Visible = true
		if prev >= 1 and step > prev then
			Hud.floater(if step == 5 then "Enjoy the game!" else "Nice! Next step", C.good)
		end
	else
		card.Visible = false
	end
end

local function hideGuides()
	markerGui.Enabled = false
	beam.Enabled = false
	edgeArrow.Visible = false
end

-- place the edge arrow so it points toward a world position that is off screen
local function pointEdgeArrow(world: Vector3): boolean
	local cam = Workspace.CurrentCamera
	local vp = cam.ViewportSize
	local sp = cam:WorldToViewportPoint(world)
	local margin = 70
	local onScreen = sp.Z > 0 and sp.X > margin and sp.X < vp.X - margin and sp.Y > margin and sp.Y < vp.Y - margin
	if onScreen then
		return false
	end
	local centre = vp / 2
	local dir = Vector2.new(sp.X, sp.Y) - centre
	if sp.Z <= 0 then
		dir = -dir -- behind the camera: the projection is mirrored
	end
	if dir.Magnitude < 1 then
		dir = Vector2.new(0, 1)
	end
	local t = math.min((vp.X / 2 - margin) / math.max(math.abs(dir.X), 1e-3), (vp.Y / 2 - margin) / math.max(math.abs(dir.Y), 1e-3))
	local pos = centre + dir * t
	local inset = GuiService:GetGuiInset() -- viewport space -> this ScreenGui's space
	edgeArrow.Position = UDim2.fromOffset(pos.X - inset.X, pos.Y - inset.Y)
	edgeArrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) - 90
	edgeArrow.Visible = true
	return true
end

RunService.RenderStepped:Connect(function()
	local step = player:GetAttribute("Tutorial") or 0
	showStep(step)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		hideGuides()
		return
	end
	local bob = math.sin(os.clock() * 5) * 8
	markerArrow.Position = UDim2.new(0.5, 0, 0, 82 + bob)

	-- in the shop during step 4: point at the Buy button of the next tool
	if step == 4 and Shop.panel.Visible then
		markerGui.Enabled = false
		beam.Enabled = false
		local id = Shop.nextToolId()
		local c = id and Shop.visibleCard(id)
		if c then
			local b = c:FindFirstChild("Action")
			local p = b.AbsolutePosition + Vector2.new(b.AbsoluteSize.X / 2, -34 + bob * 0.6)
			edgeArrow.Position = UDim2.fromOffset(p.X, p.Y)
			edgeArrow.Rotation = 0
			edgeArrow.Visible = true
		else
			edgeArrow.Visible = false
		end
		return
	end

	local pos, name, hideNear
	if step >= 1 and step <= TOTAL then
		pos, name, hideNear = targetFor(step, hrp)
	elseif step == 0 then
		-- after the tutorial: a gentle reminder when your tool is full
		local load = player:GetAttribute("Load") or 0
		local cap = player:GetAttribute("Capacity") or 1
		if load >= cap and load > 0 then
			pos, name, hideNear = H.Pile, "SNOW PILE", false
		end
	end
	if not pos or Panels.anyOpen() then
		hideGuides()
		return
	end
	local flat = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
	local dist = (flat - Vector3.new(pos.X, 0, pos.Z)).Magnitude
	marker.CFrame = CFrame.new(pos.X, 0, pos.Z)
	if hideNear and dist < 9 then
		hideGuides()
		return
	end
	markerLabel.Text = name .. "\n" .. math.floor(dist) .. " studs"
	markerGui.Enabled = true
	beam.Enabled = step > 0 and dist > 12
	if step > 0 then
		if not pointEdgeArrow(pos + Vector3.new(0, 5, 0)) then
			edgeArrow.Visible = false
		end
	else
		edgeArrow.Visible = false
	end
end)

return Tutorial
