--!nonstrict
-- The event bar at the top of the screen: a countdown to the next event, then the
-- current event's name, time left and its progress (green) or HP (red) bar.
-- It reads attributes on ReplicatedStorage.EventState, set by the server's EventService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local Panels = require(script.Parent.Panels)
local C, new, label = Theme.C, Theme.new, Theme.label

local state = ReplicatedStorage:WaitForChild("EventState")
local gui = Panels.gui

local EventBar = {}

local frame = new("Frame", {
	Name = "EventBar",
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(250, 34),
	LayoutOrder = 1,
	ZIndex = 18,
	Parent = Panels.top,
}, { Theme.corner(12) })
-- square off the top corners so the bar sits flush against the top edge
new("Frame", { BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 14), ZIndex = 18, Parent = frame })
local title = label({ Text = "", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), Font = Theme.TitleFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 19, Parent = frame })
local timer = label({ Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6), Size = UDim2.fromOffset(70, 22), Font = Theme.TitleFont, TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 19, Parent = frame })
local bar = new("Frame", { BackgroundColor3 = Color3.fromRGB(10, 22, 44), Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 24), ClipsDescendants = true, Visible = false, ZIndex = 19, Parent = frame }, { Theme.corner(10) })
local fill = new("Frame", { BackgroundColor3 = C.good, Size = UDim2.fromScale(0, 1), ZIndex = 20, Parent = bar }, { Theme.corner(10) })
local barText = label({ Text = "", Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.8), ZIndex = 21, TextStrokeTransparency = 0.4, Parent = bar })

local function clock(secs: number): string
	secs = math.max(0, math.floor(secs))
	return string.format("%d:%02d", secs // 60, secs % 60)
end

RunService.RenderStepped:Connect(function()
	local now = Workspace:GetServerTimeNow()
	if state:GetAttribute("Phase") == "active" then
		frame.Size = UDim2.fromOffset(420, 66)
		title.Text = state:GetAttribute("Title") or "Event"
		title.Size = UDim2.new(1, -100, 0, 22)
		timer.Visible = true
		timer.Text = clock((state:GetAttribute("EndsAt") or now) - now)
		bar.Visible = true
		local hp = state:GetAttribute("BarKind") == "hp"
		fill.BackgroundColor3 = if hp then C.bad else C.good
		fill.Size = UDim2.fromScale(state:GetAttribute("Progress") or 0, 1)
		barText.Text = state:GetAttribute("BarText") or ""
	else
		local nextAt = state:GetAttribute("NextAt")
		frame.Size = UDim2.fromOffset(250, 34)
		title.Size = UDim2.new(1, -24, 0, 22)
		title.Text = if nextAt then "Next event in " .. clock(nextAt - now) else "Events starting soon"
		timer.Visible = false
		bar.Visible = false
	end
end)

return EventBar
