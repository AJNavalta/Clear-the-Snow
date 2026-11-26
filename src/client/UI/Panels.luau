--!nonstrict
-- The ScreenGui every UI piece lives in, plus the pop-up panel frame used by the
-- Shop, Daily Rewards, Spin and Help windows.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local C, new, label, button = Theme.C, Theme.new, Theme.label, Theme.button

local player = Players.LocalPlayer

local Panels = {}

-- remove HUDs (and leftovers) drawn by an old copy of the client script, now and later
local playerGui = player:WaitForChild("PlayerGui")
local function removeOldGui(g: Instance)
	if g:IsA("ScreenGui") and g.Name == "ClearTheSnowUI" and g ~= Panels.gui then
		g:Destroy()
	end
end
for _, g in playerGui:GetChildren() do
	removeOldGui(g)
end
for _, name in { "PileArrow" } do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

Panels.gui = new("ScreenGui", {
	Name = "ClearTheSnowUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
playerGui.ChildAdded:Connect(function(g)
	task.defer(removeOldGui, g)
end)
-- The strip at the very top of the screen (event timer, tutorial card). It ignores the
-- top-bar inset so it sits flush against the top edge; items stack downward in order.
Panels.topGui = new("ScreenGui", {
	Name = "ClearTheSnowTop",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})
Panels.top = new("Frame", {
	Name = "TopStack",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromOffset(480, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = Panels.topGui,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
for _, g in playerGui:GetChildren() do
	if g:IsA("ScreenGui") and g.Name == "ClearTheSnowTop" and g ~= Panels.topGui then
		g:Destroy()
	end
end

Panels.isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local all: { [string]: Frame } = {}
Panels.locked = false -- true while the spin wheel is turning, so panels can't close

-- A centred window with a title and a close button. Content goes inside the returned frame,
-- starting about 44px from the top.
function Panels.make(name: string, title: string, size: Vector2)
	local p = new("Frame", {
		Name = name,
		BackgroundColor3 = C.panel,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
		ZIndex = 10,
		Parent = Panels.gui,
	}, { Theme.corner(20), Theme.pad(16), new("UISizeConstraint", { MaxSize = size }), new("UIScale") })
	label({ Name = "Title", Text = title, Size = UDim2.new(1, -50, 0, 34), Font = Theme.TitleFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = p })
	local close = button({ Name = "Close", Text = "X", Size = UDim2.fromOffset(36, 36), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), BackgroundColor3 = C.panel2, TextColor3 = C.text, ZIndex = 11, Parent = p })
	close.Activated:Connect(function()
		if not Panels.locked then
			p.Visible = false
		end
	end)
	all[name] = p
	Panels.fit()
	return p
end

function Panels.closeAll()
	if Panels.locked then
		return
	end
	for _, p in all do
		p.Visible = false
	end
end

function Panels.anyOpen(): boolean
	for _, p in all do
		if p.Visible then
			return true
		end
	end
	return false
end

-- shrink panels to fit small screens
function Panels.fit()
	local vp = Workspace.CurrentCamera.ViewportSize
	for _, p in all do
		local s = math.min(1, (vp.X - 24) / p.Size.X.Offset, (vp.Y - 60) / p.Size.Y.Offset)
		p:FindFirstChildOfClass("UIScale").Scale = math.max(0.45, s)
	end
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Panels.fit)

-- seconds until the next UTC day, as "5h 12m"
function Panels.untilTomorrow(): string
	local t = Workspace:GetServerTimeNow()
	local left = 86400 - (t % 86400)
	return string.format("%dh %dm", math.floor(left / 3600), math.floor((left % 3600) / 60))
end

return Panels
