--!nonstrict
-- Always-on-screen HUD: coins, pile, active boosts, the load bar, side buttons,
-- toasts and floating "+5" numbers. Panels hook into the side buttons from Client.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)
local Panels = require(script.Parent.Panels)
local C, new, label = Theme.C, Theme.new, Theme.label
local fmt = Config.FormatNumber

local player = Players.LocalPlayer
local gui = Panels.gui

local Hud = {}

-- ---------------------------------------------------------------- top left: coins, pile, boosts
local top = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(260, 200), Parent = gui }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local function pill(order: number, height: number)
	return new("Frame", { BackgroundColor3 = C.panel, BackgroundTransparency = 0.05, Size = UDim2.fromOffset(200, height), LayoutOrder = order, Parent = top }, { Theme.corner(height // 2) })
end
local coinPill = pill(1, 46)
Theme.coin(30, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Parent = coinPill })
local coinText = label({ Text = "0", Position = UDim2.fromOffset(46, 7), Size = UDim2.new(1, -58, 1, -14), Font = Theme.TitleFont, TextXAlignment = Enum.TextXAlignment.Left, Parent = coinPill })
local pilePill = pill(2, 34)
-- a little white snow mound as the pile icon
new("Frame", { BackgroundColor3 = Color3.fromRGB(235, 243, 255), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -8), Size = UDim2.fromOffset(26, 14), Parent = pilePill }, {
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
})
local pileText = label({ Text = "Pile: 0", Position = UDim2.fromOffset(44, 6), Size = UDim2.new(1, -54, 1, -12), TextXAlignment = Enum.TextXAlignment.Left, Parent = pilePill })
local boostsFrame = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 70), LayoutOrder = 3, Parent = top }, {
	new("UIListLayout", { Padding = UDim.new(0, 4) }),
})

-- ---------------------------------------------------------------- bottom: tool + load bar
local bottom = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(420, 84),
	Parent = gui,
}, { new("UISizeConstraint", { MaxSize = Vector2.new(420, 84) }) })
local toolText = label({ Text = "Bare Hands", Size = UDim2.new(1, 0, 0, 24), Font = Theme.TitleFont, TextStrokeTransparency = 0.5, Parent = bottom })
local bar = new("Frame", { BackgroundColor3 = C.panel, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 28), ClipsDescendants = true, Parent = bottom }, { Theme.corner(14) })
local barFill = new("Frame", { BackgroundColor3 = Color3.fromRGB(220, 238, 255), Size = UDim2.fromScale(0, 1), Parent = bar }, { Theme.corner(14) })
local barText = label({ Text = "0 / 1 snow", Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1), TextColor3 = C.ink, ZIndex = 2, Parent = bar })
local hint = label({
	Text = if Panels.isTouch then "Hold SCOOP in the snow" else "Hold click or F to scoop  |  R = auto-scoop",
	Size = UDim2.new(1, 0, 0, 18),
	Position = UDim2.fromOffset(0, 62),
	Font = Theme.BodyFont,
	TextColor3 = C.ink,
	TextStrokeColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.3,
	Parent = bottom,
})

-- ---------------------------------------------------------------- right side buttons
local side = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(96, 340),
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })

local function sideButton(order: number, text: string, color: Color3)
	local b = new("TextButton", { BackgroundColor3 = C.panel, Size = UDim2.fromOffset(92, 54), Text = "", AutoButtonColor = true, LayoutOrder = order, Parent = side }, { Theme.corner(14) })
	new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 6), Parent = b }, { Theme.corner(3) })
	local t = label({ Name = "Label", Text = text, Font = Theme.TitleFont, Position = UDim2.fromOffset(6, 10), Size = UDim2.new(1, -12, 1, -22), Parent = b })
	local badge = new("TextLabel", {
		BackgroundColor3 = C.bad,
		Size = UDim2.fromOffset(24, 24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Font = Theme.BoldFont,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Text = "!",
		Visible = false,
		ZIndex = 3,
		Parent = b,
	}, { Theme.round() })
	return b, badge, t
end
Hud.shopBtn = sideButton(1, "Shop", C.accent)
Hud.dailyBtn, Hud.dailyBadge = sideButton(2, "Daily", C.good)
Hud.spinBtn, Hud.spinBadge = sideButton(3, "Spin", C.blue)
local autoBtn, _, autoLabel = sideButton(4, "Auto: Off", Color3.fromHex("#9b6ce0"))
Hud.autoBtn = autoBtn
Hud.helpBtn = sideButton(5, "Help", C.muted)

-- ---------------------------------------------------------------- toast + floaters
local toast = new("TextLabel", {
	BackgroundColor3 = C.panel,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(440, 64),
	Font = Theme.TitleFont,
	TextColor3 = C.text,
	TextScaled = true,
	Visible = false,
	ZIndex = 40,
	Parent = gui,
}, { Theme.corner(14), Theme.pad(10) })
local toastToken = 0
function Hud.toast(text: string, secs: number?)
	toastToken += 1
	local my = toastToken
	toast.Text = text
	toast.Visible = true
	task.delay(secs or 2.4, function()
		if toastToken == my then
			toast.Visible = false
		end
	end)
end

function Hud.floater(text: string, color: Color3?)
	local f = label({
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 44),
		Font = Theme.TitleFont,
		TextColor3 = color or C.accent,
		TextStrokeTransparency = 0.2,
		ZIndex = 35,
		Parent = gui,
	})
	TweenService:Create(f, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.4),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.4, function()
		f:Destroy()
	end)
end

-- ---------------------------------------------------------------- touch SCOOP button
-- onChange(held) is called when the button is pressed or released
function Hud.makeScoopButton(onChange: (boolean) -> ())
	local tb = new("TextButton", {
		BackgroundColor3 = Color3.fromRGB(191, 227, 255),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -110, 1, -110),
		Size = UDim2.fromOffset(96, 96),
		Font = Theme.TitleFont,
		Text = "SCOOP",
		TextColor3 = C.ink,
		TextScaled = true,
		Parent = gui,
	}, { Theme.round(), Theme.pad(14) })
	tb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onChange(true)
		end
	end)
	tb.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onChange(false)
		end
	end)
end

-- ---------------------------------------------------------------- refresh from player attributes
function Hud.refresh()
	local coins = player:GetAttribute("Coins") or 0
	local load = player:GetAttribute("Load") or 0
	local cap = player:GetAttribute("Capacity") or 1
	coinText.Text = fmt(coins)
	pileText.Text = "Pile: " .. fmt(player:GetAttribute("Pile") or 0)
	local tool = Config.GetTool(player:GetAttribute("Equipped") or "hands")
	toolText.Text = tool.name
	local fill = math.clamp(load / cap, 0, 1)
	barFill.Size = UDim2.fromScale(fill, 1)
	barFill.BackgroundColor3 = if fill >= 0.999 then Color3.fromHex("#ff8a8a") else Color3.fromRGB(220, 238, 255)
	barText.Text = fmt(load) .. " / " .. fmt(cap) .. " snow" .. (if fill >= 0.999 then "  (FULL)" else "")
	Hud.dailyBadge.Visible = player:GetAttribute("DailyCanClaim") == true
	local spins = player:GetAttribute("Spins") or 0
	Hud.spinBadge.Visible = spins > 0
	Hud.spinBadge.Text = tostring(spins)
	autoLabel.Text = if player:GetAttribute("Auto") then "Auto: On" else "Auto: Off"

	for _, c in boostsFrame:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local now = Workspace:GetServerTimeNow()
	for _, b in { { "BoostSell", "2x Sell", C.accent }, { "BoostCapacity", "2x Capacity", C.good } } do
		local left = (player:GetAttribute(b[1]) or 0) - now
		if left > 0 then
			new("TextLabel", {
				BackgroundColor3 = b[3],
				Size = UDim2.fromOffset(170, 26),
				Font = Theme.BoldFont,
				TextScaled = true,
				TextColor3 = C.ink,
				Text = string.format("%s  %d:%02d", b[2], math.floor(left / 60), math.floor(left % 60)),
				Parent = boostsFrame,
			}, { Theme.corner(8), Theme.pad(4) })
		end
	end
	local hands = player:GetAttribute("Equipped") == "hands"
		or game:GetService("ReplicatedStorage"):FindFirstChild("EventState") and game:GetService("ReplicatedStorage").EventState:GetAttribute("SnowballsForAll") == true
	if Panels.isTouch then
		hint.Text = if hands then "Hold SCOOP in the snow  |  THROW a snowball" else "Hold SCOOP in the snow"
	else
		hint.Text = "Hold click or F to scoop  |  R = auto-scoop" .. (if hands then "  |  Q = throw snowball" else "")
	end
	hint.Visible = not Panels.isTouch or not player:GetAttribute("Auto")
end

return Hud
