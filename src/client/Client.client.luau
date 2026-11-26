--!nonstrict
-- Clear the Snow: client. Input, HUD, shopping list, daily rewards, spin wheel,
-- and local-only effects (your own snow pile mound, display turntables, snowfall).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Models = require(Shared.Models)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local fmt = Config.FormatNumber
local H = Config.Hub

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- ------------------------------------------------------------------ ui helpers
local C = {
	panel = Color3.fromRGB(18, 36, 66),
	panel2 = Color3.fromRGB(32, 58, 98),
	accent = Color3.fromHex("#ffd54f"),
	good = Color3.fromHex("#3cc48a"),
	bad = Color3.fromHex("#e0505a"),
	text = Color3.fromRGB(243, 247, 255),
	muted = Color3.fromRGB(169, 187, 214),
	ink = Color3.fromRGB(15, 30, 55),
}

local function new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props or {} do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local function corner(r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end
local function pad(px: number)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end
local function label(props)
	local base = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.text,
		TextScaled = true,
	}
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base)
end
local function button(props)
	local base = {
		AutoButtonColor = true,
		BackgroundColor3 = C.accent,
		Font = Enum.Font.FredokaOne,
		TextColor3 = C.ink,
		TextScaled = true,
	}
	for k, v in props do
		base[k] = v
	end
	local b = new("TextButton", base, { corner(12) })
	return b
end

local gui = new("ScreenGui", {
	Name = "ClearTheSnowUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ------------------------------------------------------------------ HUD
local top = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(260, 200), Parent = gui }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local function pill(order: number, height: number)
	return new("Frame", { BackgroundColor3 = C.panel, BackgroundTransparency = 0.05, Size = UDim2.fromOffset(200, height), LayoutOrder = order, Parent = top }, { corner(height // 2), pad(6) })
end
local coinPill = pill(1, 46)
local coinText = label({ Text = "🪙 0", Size = UDim2.fromScale(1, 1), Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = coinPill })
local pilePill = pill(2, 34)
local pileText = label({ Text = "⛰ Pile: 0", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = pilePill })
local boostsFrame = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 70), LayoutOrder = 3, Parent = top }, {
	new("UIListLayout", { Padding = UDim.new(0, 4) }),
})

local bottom = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(420, 84),
	Parent = gui,
})
new("UISizeConstraint", { MaxSize = Vector2.new(420, 84), Parent = bottom })
local toolText = label({ Text = "Bare Hands", Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.5, Parent = bottom })
local bar = new("Frame", { BackgroundColor3 = C.panel, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 28), ClipsDescendants = true, Parent = bottom }, { corner(14) })
local barFill = new("Frame", { BackgroundColor3 = Color3.fromRGB(220, 238, 255), Size = UDim2.fromScale(0, 1), Parent = bar }, { corner(14) })
local barText = label({ Text = "0 / 1 snow", Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1), TextColor3 = C.ink, ZIndex = 2, Parent = bar })
local hint = label({
	Text = if isTouch then "Hold SCOOP in the snow" else "Hold click or F to scoop · R auto-scoop",
	Size = UDim2.new(1, 0, 0, 18),
	Position = UDim2.fromOffset(0, 62),
	Font = Enum.Font.Gotham,
	TextColor3 = C.ink,
	TextStrokeColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.3,
	Parent = bottom,
})

local side = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(78, 330),
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center }) })
local function sideButton(icon: string, text: string)
	local b = new("TextButton", { BackgroundColor3 = C.panel, Size = UDim2.fromOffset(74, 70), Text = "", AutoButtonColor = true, Parent = side }, { corner(16) })
	label({ Text = icon, Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.fromScale(0, 0.06), Parent = b })
	label({ Text = text, Size = UDim2.new(1, 0, 0.28, 0), Position = UDim2.fromScale(0, 0.64), Parent = b })
	local badge = new("TextLabel", {
		BackgroundColor3 = C.bad,
		Size = UDim2.fromOffset(24, 24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Text = "!",
		Visible = false,
		Parent = b,
	}, { corner(12) })
	return b, badge
end
local shopBtn = sideButton("🛒", "Shop")
local dailyBtn, dailyBadge = sideButton("🎁", "Daily")
local spinBtn, spinBadge = sideButton("🎡", "Spin")
local autoBtn = sideButton("🔁", "Auto: Off")

-- toast + floaters
local toast = new("TextLabel", {
	BackgroundColor3 = C.panel,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.16),
	Size = UDim2.fromOffset(420, 64),
	Font = Enum.Font.FredokaOne,
	TextColor3 = C.text,
	TextScaled = true,
	Visible = false,
	ZIndex = 20,
	Parent = gui,
}, { corner(14), pad(10) })
local toastToken = 0
local function showToast(text: string, secs: number?)
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
local function floater(text: string, color: Color3?)
	local f = label({
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(300, 44),
		Font = Enum.Font.FredokaOne,
		TextColor3 = color or C.accent,
		TextStrokeTransparency = 0.2,
		ZIndex = 15,
		Parent = gui,
	})
	TweenService:Create(f, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.32),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.4, function()
		f:Destroy()
	end)
end

-- touch scoop button
local scoopHeld = { mouse = false, key = false, touch = false }
local sendScoop
if isTouch then
	local tb = new("TextButton", {
		BackgroundColor3 = Color3.fromRGB(191, 227, 255),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -110, 1, -110),
		Size = UDim2.fromOffset(96, 96),
		Font = Enum.Font.FredokaOne,
		Text = "SCOOP",
		TextColor3 = C.ink,
		TextScaled = true,
		Parent = gui,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), pad(14) })
	tb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			scoopHeld.touch = true
			sendScoop()
		end
	end)
	tb.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			scoopHeld.touch = false
			sendScoop()
		end
	end)
end

-- ------------------------------------------------------------------ panels
local panels = {}
local function makePanel(name: string, title: string, size: Vector2)
	local p = new("Frame", {
		Name = name,
		BackgroundColor3 = C.panel,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, { corner(20), pad(16), new("UISizeConstraint", { MaxSize = size }) })
	new("UIScale", { Parent = p })
	label({ Text = title, Size = UDim2.new(1, -50, 0, 34), Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = p })
	local close = button({ Text = "✕", Size = UDim2.fromOffset(36, 36), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), BackgroundColor3 = C.panel2, TextColor3 = C.text, ZIndex = 11, Parent = p })
	close.Activated:Connect(function()
		p.Visible = false
	end)
	panels[name] = p
	return p
end
local spinning = false
local function closeAll()
	if spinning then
		return
	end
	for _, p in panels do
		p.Visible = false
	end
end
local function fitPanels()
	local vp = Workspace.CurrentCamera.ViewportSize
	for _, p in panels do
		local s = math.min(1, (vp.X - 24) / p.Size.X.Offset, (vp.Y - 60) / p.Size.Y.Offset)
		p:FindFirstChildOfClass("UIScale").Scale = math.max(0.45, s)
	end
end

-- ---------- shop
local shop = makePanel("Shop", "🛒 Tool Shop — Shopping List", Vector2.new(900, 560))
local tab = "hand"
local tabs = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 40), ZIndex = 11, Parent = shop }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
})
local tabHand = button({ Text = "Hand Tools", Size = UDim2.new(0.5, -4, 1, 0), ZIndex = 11, Parent = tabs })
local tabMachine = button({ Text = "Machines", Size = UDim2.new(0.5, -4, 1, 0), ZIndex = 11, Parent = tabs })
local list = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 94),
	Size = UDim2.new(1, 0, 1, -94),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 8,
	ZIndex = 11,
	Parent = shop,
}, {
	new("UIGridLayout", { CellSize = UDim2.fromOffset(165, 300), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function ownedSet(): { [string]: boolean }
	local s = {}
	for id in string.gmatch(player:GetAttribute("Owned") or "hands", "[^,]+") do
		s[id] = true
	end
	return s
end

-- 3D thumbnail of a model in a ViewportFrame
local function thumbnail(id: string, parent: Instance)
	local vf = new("ViewportFrame", {
		BackgroundColor3 = Color3.fromRGB(40, 70, 112),
		Size = UDim2.new(1, 0, 0, 140),
		Ambient = Color3.fromRGB(180, 190, 210),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -2, -1),
		ZIndex = 12,
		Parent = parent,
	}, { corner(10) })
	local m = Models.Build(id)
	local tool = Config.GetTool(id)
	if tool.kind == "hand" then
		m:PivotTo(CFrame.Angles(-0.3, 0.6, 0.5))
	else
		m:PivotTo(CFrame.Angles(0, 0.7, 0))
	end
	m.Parent = vf
	local cf, size = m:GetBoundingBox()
	local radius = size.Magnitude / 2
	local cam = new("Camera", { FieldOfView = 30, Parent = vf })
	local dir = Vector3.new(0.35, 0.45, -1).Unit
	local dist = radius / math.tan(math.rad(15)) * 1.02
	cam.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
	vf.CurrentCamera = cam
	return vf
end

local cards = {}
local function renderShop(focus: string?)
	tabHand.BackgroundColor3 = if tab == "hand" then C.accent else C.panel2
	tabHand.TextColor3 = if tab == "hand" then C.ink else C.text
	tabMachine.BackgroundColor3 = if tab == "machine" then C.accent else C.panel2
	tabMachine.TextColor3 = if tab == "machine" then C.ink else C.text
	local owned = ownedSet()
	local coins = player:GetAttribute("Coins") or 0
	local equipped = player:GetAttribute("Equipped")
	for i, tool in Config.Tools do
		local card = cards[tool.id]
		if not card then
			card = new("Frame", { BackgroundColor3 = C.panel2, LayoutOrder = i, ZIndex = 11, Parent = list }, { corner(14), pad(8) })
			thumbnail(tool.id, card)
			label({ Name = "Name", Text = i .. ". " .. tool.name, Position = UDim2.fromOffset(0, 146), Size = UDim2.new(1, 0, 0, 34), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = card })
			label({ Text = tool.desc, Position = UDim2.fromOffset(0, 182), Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.Gotham, TextColor3 = C.muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = card })
			label({
				Text = string.format("Carries %s · Width %.0f", fmt(tool.capacity), tool.radius * 2),
				Position = UDim2.fromOffset(0, 214),
				Size = UDim2.new(1, 0, 0, 16),
				Font = Enum.Font.Gotham,
				TextColor3 = C.accent,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 12,
				Parent = card,
			})
			label({
				Text = "Scoop " .. tostring(tool.rate) .. "/s · Speed " .. tostring(tool.speed),
				Position = UDim2.fromOffset(0, 232),
				Size = UDim2.new(1, 0, 0, 16),
				Font = Enum.Font.Gotham,
				TextColor3 = C.accent,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 12,
				Parent = card,
			})
			local b = button({ Name = "Action", Text = "", Position = UDim2.new(0, 0, 1, -34), Size = UDim2.new(1, 0, 0, 34), ZIndex = 12, Parent = card })
			new("UIStroke", { Color = C.accent, Thickness = 3, Enabled = false, Parent = card })
			b.Activated:Connect(function()
				local ok, msg = Remotes.BuyTool:InvokeServer(tool.id)
				if msg then
					showToast((if ok then "🎉 " else "") .. msg)
				end
				task.wait(0.1)
				renderShop(tool.id)
			end)
			cards[tool.id] = card
		end
		card.Visible = tool.kind == tab
		local b = card.Action
		local prevOwned = i == 1 or owned[Config.Tools[i - 1].id]
		if equipped == tool.id then
			b.Text = "✔ Equipped"
			b.BackgroundColor3 = Color3.fromRGB(93, 109, 134)
			b.Active = false
		elseif owned[tool.id] then
			b.Text = "Equip"
			b.BackgroundColor3 = Color3.fromHex("#4fa3e0")
			b.Active = true
		elseif not prevOwned then
			b.Text = "🔒 Buy previous first"
			b.BackgroundColor3 = Color3.fromRGB(93, 109, 134)
			b.Active = false
		else
			b.Text = "Buy 🪙 " .. fmt(tool.price)
			b.BackgroundColor3 = if coins >= tool.price then C.good else Color3.fromRGB(93, 109, 134)
			b.Active = true
		end
		card.BackgroundTransparency = if not owned[tool.id] and not prevOwned then 0.45 else 0
		card:FindFirstChildOfClass("UIStroke").Enabled = tool.id == focus
	end
	if focus and cards[focus] then
		task.defer(function()
			local c = cards[focus]
			local y = c.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y
			list.CanvasPosition = Vector2.new(0, math.max(0, y - 10))
		end)
	end
end
tabHand.Activated:Connect(function()
	tab = "hand"
	renderShop()
end)
tabMachine.Activated:Connect(function()
	tab = "machine"
	renderShop()
end)
local function openShop(focus: string?)
	closeAll()
	if focus then
		tab = Config.GetTool(focus).kind
	end
	renderShop(focus)
	shop.Visible = true
end

-- ---------- daily rewards
local daily = makePanel("Daily", "🎁 Daily Rewards", Vector2.new(520, 420))
label({ Text = "Come back every day to keep your streak. Day 7 is the big one!", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.Gotham, TextColor3 = C.muted, ZIndex = 11, Parent = daily })
local grid = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 200), ZIndex = 11, Parent = daily }, {
	new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 92), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local dayCells = {}
for i = 1, #Config.DailyRewards do
	local cell = new("Frame", { BackgroundColor3 = if i == 7 then Color3.fromHex("#7a4fd0") else C.panel2, LayoutOrder = i, ZIndex = 11, Parent = grid }, { corner(12), pad(6) })
	label({ Text = "Day " .. i, Size = UDim2.new(1, 0, 0, 16), TextColor3 = C.muted, ZIndex = 12, Parent = cell })
	label({ Name = "Reward", Text = "", Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, ZIndex = 12, Parent = cell })
	label({ Name = "Check", Text = "✔", Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 18), TextColor3 = C.good, Visible = false, ZIndex = 12, Parent = cell })
	new("UIStroke", { Color = C.accent, Thickness = 3, Enabled = false, Parent = cell })
	dayCells[i] = cell
end
local claimBtn = button({ Text = "Claim", Position = UDim2.new(0, 0, 1, -86), Size = UDim2.new(1, 0, 0, 48), ZIndex = 11, Parent = daily })
local dailyInfo = label({ Text = "", Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.Gotham, TextColor3 = C.muted, ZIndex = 11, Parent = daily })

local function untilTomorrow(): string
	local t = Workspace:GetServerTimeNow()
	local left = 86400 - (t % 86400)
	return string.format("%dh %dm", math.floor(left / 3600), math.floor((left % 3600) / 60))
end
local function renderDaily()
	local can = player:GetAttribute("DailyCanClaim")
	local idx = player:GetAttribute("DailyIndex") or 1
	local progress = player:GetAttribute("ProgressCoins") or 10
	for i, r in Config.DailyRewards do
		local cell = dayCells[i]
		local coins = math.max(r.min, math.floor(progress * r.pct + 0.5))
		cell.Reward.Text = "🪙 " .. fmt(coins) .. (if r.spins > 0 then "\n🎡 +" .. r.spins else "")
		local done = if can then i < idx else i <= idx
		cell.Check.Visible = done
		cell.BackgroundTransparency = if done then 0.5 else 0
		cell:FindFirstChildOfClass("UIStroke").Enabled = can and i == idx
	end
	claimBtn.Text = if can then "Claim Day " .. idx else "Claimed today ✔"
	claimBtn.BackgroundColor3 = if can then C.accent else Color3.fromRGB(93, 109, 134)
	claimBtn.Active = can == true
	local streak = player:GetAttribute("DailyStreak") or 0
	if can and player:GetAttribute("DailyBroken") then
		dailyInfo.Text = "Your streak reset. Start again today!"
	elseif can then
		dailyInfo.Text = "Current streak: " .. streak .. " day" .. (if streak == 1 then "" else "s")
	else
		dailyInfo.Text = "Streak: " .. streak .. " · next reward in " .. untilTomorrow()
	end
end
claimBtn.Activated:Connect(function()
	if not player:GetAttribute("DailyCanClaim") then
		return
	end
	local rw = Remotes.ClaimDaily:InvokeServer()
	if rw then
		showToast("🎁 +" .. fmt(rw.coins) .. " coins" .. (if rw.spins > 0 then " and +" .. rw.spins .. " spin" .. (if rw.spins > 1 then "s" else "") else "") .. "!")
	end
	task.wait(0.15)
	renderDaily()
end)
local function openDaily()
	closeAll()
	renderDaily()
	daily.Visible = true
end

-- ---------- spin wheel
local spinPanel = makePanel("Spin", "🎡 Lucky Spin", Vector2.new(480, 560))
local wheelHolder = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 56),
	Size = UDim2.fromOffset(340, 340),
	ZIndex = 11,
	Parent = spinPanel,
})
local wheelDisc = new("Frame", { BackgroundColor3 = Color3.fromHex("#ffd54f"), Size = UDim2.fromScale(1, 1), ZIndex = 11, Parent = wheelHolder }, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
})
local nSeg = #Config.Wheel
local segDeg = 360 / nSeg
for i, s in Config.Wheel do
	local arm = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = (i - 1) * segDeg, ZIndex = 12, Parent = wheelDisc })
	local width = 2 * math.sin(math.rad(segDeg / 2)) * 0.47
	local petal = new("Frame", {
		BackgroundColor3 = Color3.fromHex(s.color),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(width * 1.08, 0.47),
		ZIndex = 12 + (i % 2),
		Parent = arm,
	}, { corner(18) })
	label({
		Text = s.label,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromScale(1.6, 0.16),
		Rotation = -90,
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0.5,
		ZIndex = 14,
		Parent = petal,
	})
end
new("Frame", { BackgroundColor3 = Color3.fromHex("#ffd54f"), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.2, 0.2), ZIndex = 16, Parent = wheelDisc }, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
})
label({ Text = "▼", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(44, 44), TextColor3 = C.bad, TextStrokeTransparency = 0, ZIndex = 18, Parent = wheelHolder })
local spinBtnGo = button({ Text = "Spin!", Position = UDim2.new(0, 0, 1, -96), Size = UDim2.new(1, 0, 0, 50), ZIndex = 11, Parent = spinPanel })
local spinInfo = label({ Text = "", Position = UDim2.new(0, 0, 1, -38), Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.Gotham, TextColor3 = C.muted, TextWrapped = true, ZIndex = 11, Parent = spinPanel })

local function renderSpin()
	local n = player:GetAttribute("Spins") or 0
	local free = player:GetAttribute("FreeSpin")
	spinBtnGo.Text = if spinning then "Spinning…" elseif free then "Free Spin!" elseif n > 0 then "Spin! (" .. n .. " left)" else "No spins left"
	spinBtnGo.BackgroundColor3 = if not spinning and n > 0 then C.accent else Color3.fromRGB(93, 109, 134)
	local base = math.max(10, math.floor((player:GetAttribute("ProgressCoins") or 10) * 0.1 + 0.5))
	spinInfo.Text = if n == 0
		then "Free spin resets in " .. untilTomorrow() .. ". Daily rewards give bonus spins."
		else "Coin prizes right now: 🪙 " .. fmt(base) .. " up to " .. fmt(base * 25)
end

-- the 3D wheel in the plaza spins along with the UI wheel
local plazaWheel, plazaBase
task.spawn(function()
	plazaWheel = CollectionService:GetTagged("SpinWheel")[1]
	while not plazaWheel do
		task.wait(1)
		plazaWheel = CollectionService:GetTagged("SpinWheel")[1]
	end
	plazaBase = plazaWheel:GetPivot()
end)
local wheelAngle = 0 -- degrees, UI rotation (clockwise)
local function setWheel(deg: number)
	wheelAngle = deg
	wheelDisc.Rotation = deg
	if plazaWheel and plazaBase then
		plazaWheel:PivotTo(plazaBase * CFrame.Angles(0, 0, math.rad(deg)))
	end
end

spinBtnGo.Activated:Connect(function()
	if spinning or (player:GetAttribute("Spins") or 0) <= 0 then
		return
	end
	spinning = true
	renderSpin()
	local result = Remotes.Spin:InvokeServer()
	if not result then
		spinning = false
		renderSpin()
		return
	end
	local start = wheelAngle
	local want = -(result.index - 1) * segDeg + (math.random() - 0.5) * segDeg * 0.6
	local delta = (want - start) % 360
	local finish = start + 360 * 6 + delta
	local t0, dur = os.clock(), 4.2
	while true do
		local k = math.min(1, (os.clock() - t0) / dur)
		local e = 1 - (1 - k) ^ 4
		setWheel(start + (finish - start) * e)
		if k >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	setWheel(wheelAngle % 360)
	spinning = false
	showToast("🎡 " .. Config.Wheel[result.index].label .. "\n" .. result.message, 3)
	renderSpin()
end)
local function openSpin()
	closeAll()
	renderSpin()
	spinPanel.Visible = true
end

-- ---------- help
local help = makePanel("Help", "❄ Clear the Snow", Vector2.new(520, 420))
label({
	Text = "1. Walk into the snow and hold click (or F) to scoop it up. Each tool only carries so much.\n"
		.. "2. Bring it back to the Snow Pile at the market. You toss it in automatically.\n"
		.. "3. Talk to the Snow Buyer to sell your whole pile for coins.\n"
		.. "4. The Tool Shop is right next door. Walk up to the display or click a tool to see it.\n"
		.. "5. Snow grows back, so keep clearing! Claim your daily reward and free spin every day.",
	Position = UDim2.fromOffset(0, 46),
	Size = UDim2.new(1, 0, 1, -110),
	Font = Enum.Font.Gotham,
	TextScaled = false,
	TextSize = 17,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 11,
	Parent = help,
})
local go = button({ Text = "Let's go!", Position = UDim2.new(0, 0, 1, -52), Size = UDim2.new(1, 0, 0, 50), ZIndex = 11, Parent = help })
go.Activated:Connect(function()
	help.Visible = false
end)

shopBtn.Activated:Connect(function()
	openShop()
end)
dailyBtn.Activated:Connect(openDaily)
spinBtn.Activated:Connect(openSpin)
autoBtn.Activated:Connect(function()
	Remotes.SetAuto:FireServer(not player:GetAttribute("Auto"))
end)

Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanels)
fitPanels()

-- ------------------------------------------------------------------ HUD refresh
local function refreshHud()
	local coins = player:GetAttribute("Coins") or 0
	local load = player:GetAttribute("Load") or 0
	local cap = player:GetAttribute("Capacity") or 1
	coinText.Text = "🪙 " .. fmt(coins)
	pileText.Text = "⛰ Pile: " .. fmt(player:GetAttribute("Pile") or 0)
	local tool = Config.GetTool(player:GetAttribute("Equipped") or "hands")
	toolText.Text = (if tool.kind == "machine" then "🚜 " else "🧤 ") .. tool.name
	local fill = math.clamp(load / cap, 0, 1)
	barFill.Size = UDim2.fromScale(fill, 1)
	barFill.BackgroundColor3 = if fill >= 0.999 then Color3.fromHex("#ff8a8a") else Color3.fromRGB(220, 238, 255)
	barText.Text = fmt(load) .. " / " .. fmt(cap) .. " snow"
	dailyBadge.Visible = player:GetAttribute("DailyCanClaim") == true
	local spins = player:GetAttribute("Spins") or 0
	spinBadge.Visible = spins > 0
	spinBadge.Text = tostring(spins)
	for _, c in autoBtn:GetChildren() do
		if c:IsA("TextLabel") and c.Text:sub(1, 4) == "Auto" then
			c.Text = if player:GetAttribute("Auto") then "Auto: On" else "Auto: Off"
		end
	end
	-- boosts
	local now = Workspace:GetServerTimeNow()
	for _, c in boostsFrame:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	for _, b in { { "BoostSell", "💰 2x Sell", C.accent }, { "BoostCapacity", "❄ 2x Capacity", C.good } } do
		local left = (player:GetAttribute(b[1]) or 0) - now
		if left > 0 then
			new("TextLabel", {
				BackgroundColor3 = b[3],
				Size = UDim2.fromOffset(170, 26),
				Font = Enum.Font.GothamBold,
				TextScaled = true,
				TextColor3 = C.ink,
				Text = string.format("%s %d:%02d", b[2], math.floor(left / 60), math.floor(left % 60)),
				Parent = boostsFrame,
			}, { corner(8), pad(4) })
		end
	end
	hint.Visible = not isTouch or not player:GetAttribute("Auto")
	if shop.Visible then
		renderShop()
	end
	if daily.Visible then
		renderDaily()
	end
	if spinPanel.Visible and not spinning then
		renderSpin()
	end
end
for _, a in { "Coins", "Load", "Capacity", "Pile", "Equipped", "Owned", "Spins", "DailyCanClaim", "Auto", "BoostSell", "BoostCapacity" } do
	player:GetAttributeChangedSignal(a):Connect(refreshHud)
end
task.spawn(function()
	while true do
		task.wait(1)
		refreshHud()
	end
end)

-- ------------------------------------------------------------------ input
function sendScoop()
	Remotes.SetScooping:FireServer(scoopHeld.mouse or scoopHeld.key or scoopHeld.touch)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		scoopHeld.mouse = true
		sendScoop()
	elseif input.KeyCode == Enum.KeyCode.F then
		scoopHeld.key = true
		sendScoop()
	elseif input.KeyCode == Enum.KeyCode.R then
		Remotes.SetAuto:FireServer(not player:GetAttribute("Auto"))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		scoopHeld.mouse = false
		sendScoop()
	elseif input.KeyCode == Enum.KeyCode.F then
		scoopHeld.key = false
		sendScoop()
	end
end)

-- ------------------------------------------------------------------ server messages
Remotes.Notify.OnClientEvent:Connect(function(kind, a, b)
	if kind == "toast" then
		showToast(a)
	elseif kind == "open" then
		if a == "shop" then
			openShop(b)
		elseif a == "daily" then
			openDaily()
		elseif a == "spin" then
			openSpin()
		end
	elseif kind == "dumped" then
		floater("+" .. fmt(a) .. " ❄ on the pile", Color3.new(1, 1, 1))
	elseif kind == "sold" then
		floater("+" .. fmt(a) .. " 🪙")
	elseif kind == "full" then
		local tool = Config.GetTool(player:GetAttribute("Equipped") or "hands")
		showToast(if tool.kind == "machine" then "Machine full! Drive to the Snow Pile." else "Hands full! Take it to the Snow Pile.")
	end
end)

-- ------------------------------------------------------------------ local world effects
-- your own pile mound
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
local arrow = new("Part", {
	Name = "PileArrow",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Material = Enum.Material.Neon,
	Color = Color3.fromHex("#ffd54f"),
	Size = Vector3.new(2.4, 2.4, 2.4),
	Parent = Workspace,
	Shape = Enum.PartType.Ball,
})

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
	Rate = 260,
	Speed = NumberRange.new(5, 8),
	SpreadAngle = Vector2.new(15, 15),
	Acceleration = Vector3.new(0.6, 0, 0.3),
	EmissionDirection = Enum.NormalId.Bottom,
	RotSpeed = NumberRange.new(-40, 40),
	Parent = snowEmitterPart,
})

-- display labels (owned / equipped) and turntables
local function refreshDisplays()
	local owned = ownedSet()
	local equipped = player:GetAttribute("Equipped")
	for _, holder in CollectionService:GetTagged("ToolDisplay") do
		local id = holder:GetAttribute("ToolId")
		local hit = holder:FindFirstChild("Hit")
		local bb = hit and hit:FindFirstChildOfClass("BillboardGui")
		local frame = bb and bb:FindFirstChildOfClass("Frame")
		local sub = frame and frame:FindFirstChild("Subtitle")
		if sub then
			local tool = Config.GetTool(id)
			sub.Text = if equipped == id then "✔ EQUIPPED" elseif owned[id] then "OWNED" else "🪙 " .. fmt(tool.price)
			sub.TextColor3 = if owned[id] then Color3.fromHex("#b9f6ca") else C.accent
		end
	end
end
player:GetAttributeChangedSignal("Owned"):Connect(refreshDisplays)
player:GetAttributeChangedSignal("Equipped"):Connect(refreshDisplays)
task.delay(2, refreshDisplays)

local turntables = {}
local function addTurntable(holder: Instance)
	local item = holder:WaitForChild("Item", 10)
	if item and item:IsA("Model") then
		local centre = item:GetAttribute("SpinCentre")
		local pivot = item:GetPivot()
		table.insert(turntables, { model = item, centre = centre, offset = CFrame.new(centre):Inverse() * pivot, phase = #turntables })
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
	-- pile mound
	local pile = player:GetAttribute("Pile") or 0
	local h = math.min(9, 0.4 + math.log10(1 + pile) * 2.4)
	local cur = mound.Size.Y
	local y = cur + (h * 2 - cur) * math.min(1, dt * 4)
	mound.Size = Vector3.new(H.PileRadius * 2, y, H.PileRadius * 2)
	mound.CFrame = CFrame.new(H.Pile + Vector3.new(0, 0.3, 0))
	-- bouncing marker over the pile while carrying snow
	local carrying = (player:GetAttribute("Load") or 0) > 0
	arrow.Transparency = if carrying then 0 else 1
	arrow.CFrame = CFrame.new(H.Pile + Vector3.new(0, h + 7 + math.sin(t * 4), 0))
	-- turntables (throttled, only near the camera)
	tAcc += dt
	if tAcc > 1 / 30 then
		tAcc = 0
		for _, tt in turntables do
			if (cam.CFrame.Position - tt.centre).Magnitude < 90 then
				tt.model:PivotTo(CFrame.new(tt.centre) * CFrame.Angles(0, t * 0.5 + tt.phase, 0) * tt.offset)
			end
		end
	end
	-- idle plaza wheel
	if plazaWheel and plazaBase and not spinning then
		wheelAngle = (wheelAngle + dt * 10) % 360
		plazaWheel:PivotTo(plazaBase * CFrame.Angles(0, 0, math.rad(wheelAngle)))
		wheelDisc.Rotation = wheelAngle
	end
end)

-- first-time help
task.spawn(function()
	while not player:GetAttribute("Ready") do
		task.wait(0.5)
	end
	refreshHud()
	refreshDisplays()
	help.Visible = true
end)
