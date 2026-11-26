--!nonstrict
-- The Tool Shop's shopping list: two tabs (hand tools / machines) of cards with a 3D
-- preview, stats and a Buy / Equip button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local Shop = {}

local panel = Panels.make("Shop", "Tool Shop - Shopping List", Vector2.new(900, 560))
Shop.panel = panel
local tab = "hand"
-- your coins, top right next to the close button
local wallet = new("Frame", { BackgroundColor3 = C.panel2, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -46, 0, 2), Size = UDim2.fromOffset(150, 32), ZIndex = 11, Parent = panel }, { Theme.corner(16) })
Theme.coin(22, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), ZIndex = 12, Parent = wallet })
local walletText = label({ Text = "0", Position = UDim2.fromOffset(34, 5), Size = UDim2.new(1, -42, 1, -10), Font = Theme.TitleFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = wallet })
local tabs = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 40), ZIndex = 11, Parent = panel }, {
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
	Parent = panel,
}, {
	new("UIGridLayout", { CellSize = UDim2.fromOffset(165, 300), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})
Shop.list = list

function Shop.ownedSet(): { [string]: boolean }
	local s = {}
	for id in string.gmatch(player:GetAttribute("Owned") or "hands", "[^,]+") do
		s[id] = true
	end
	return s
end

-- the next tool the player can buy, or nil when they own everything
function Shop.nextToolId(): string?
	local owned = Shop.ownedSet()
	for _, t in Config.Tools do
		if not owned[t.id] then
			return t.id
		end
	end
	return nil
end

-- 3D thumbnail of a model in a ViewportFrame
local function thumbnail(id: string, parent: Instance)
	local vf = new("ViewportFrame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 149),
		Ambient = Color3.fromRGB(180, 190, 210),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -2, -1),
		ZIndex = 12,
		Parent = parent,
	}, {
		Theme.corner(10),
		new("UIGradient", { -- soft blue backdrop, like the web version's cards
			Color = ColorSequence.new(Color3.fromHex("#3d5f8f"), Color3.fromHex("#1c3354")),
			Rotation = 90,
		}),
	})
	local m = Models.Build(id)
	if Config.GetTool(id).kind == "hand" then
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

local cards: { [string]: Frame } = {}
local focused: string? = nil

-- one row of two stats, e.g. "Carries 10" on the left and "Width 2.4m" on the right
local function hex(c: Color3): string
	return string.format("#%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end
local function statRow(y: number, parent: Instance, leftName: string, leftValue: string, rightName: string, rightValue: string)
	local function cell(text, align)
		label({
			Text = text,
			RichText = true,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 15),
			Font = Theme.BodyFont,
			TextColor3 = C.text,
			TextXAlignment = align,
			ZIndex = 12,
			Parent = parent,
		})
	end
	local a = hex(C.accent)
	cell(string.format('%s <font color="%s"><b>%s</b></font>', leftName, a, leftValue), Enum.TextXAlignment.Left)
	cell(string.format('%s <font color="%s"><b>%s</b></font>', rightName, a, rightValue), Enum.TextXAlignment.Right)
end

function Shop.render()
	tabHand.BackgroundColor3 = if tab == "hand" then C.accent else C.panel2
	tabHand.TextColor3 = if tab == "hand" then C.ink else C.text
	tabMachine.BackgroundColor3 = if tab == "machine" then C.accent else C.panel2
	tabMachine.TextColor3 = if tab == "machine" then C.ink else C.text
	local owned = Shop.ownedSet()
	local coins = player:GetAttribute("Coins") or 0
	walletText.Text = fmt(coins)
	local equipped = player:GetAttribute("Equipped")
	for i, tool in Config.Tools do
		local card = cards[tool.id]
		if not card then
			card = new("Frame", { BackgroundColor3 = C.panel2, LayoutOrder = i, ZIndex = 11, Parent = list }, { Theme.corner(14), Theme.pad(8) })
			thumbnail(tool.id, card)
			label({ Name = "ToolName", Text = i .. ". " .. tool.name, Position = UDim2.fromOffset(0, 154), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = card })
			label({ Text = tool.desc, Position = UDim2.fromOffset(0, 174), Size = UDim2.new(1, 0, 0, 28), Font = Theme.BodyFont, TextColor3 = C.muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 12, Parent = card })
			statRow(206, card, "Carries", fmt(tool.capacity), "Width", string.format("%.1fm", tool.radius * 2 / Config.STUDS_PER_METER))
			statRow(224, card, "Scoop", tostring(tool.rate) .. "/s", "Speed", tostring(tool.speed))
			local b = button({ Name = "Action", Text = "", Position = UDim2.new(0, 0, 1, -34), Size = UDim2.new(1, 0, 0, 34), ZIndex = 12, Parent = card })
			new("UIStroke", { Color = C.accent, Thickness = 3, Enabled = false, Parent = card })
			Theme.coin(18, { Name = "Coin", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Visible = false, ZIndex = 13, Parent = b })
			b.Activated:Connect(function()
				local ok, msg = Remotes.BuyTool:InvokeServer(tool.id)
				if msg then
					Hud.toast(msg)
				end
				task.wait(0.1)
				Shop.render()
				if ok and (player:GetAttribute("Tutorial") or 0) == 5 then
					Panels.closeAll() -- let the "Enjoy the game!" card show
				end
			end)
			cards[tool.id] = card
		end
		card.Visible = tool.kind == tab
		local b = card.Action
		local prevOwned = i == 1 or owned[Config.Tools[i - 1].id]
		if equipped == tool.id then
			b.Text = "Equipped"
			b.BackgroundColor3 = C.disabled
			b.Active = false
		elseif owned[tool.id] then
			b.Text = "Equip"
			b.BackgroundColor3 = C.blue
			b.Active = true
		elseif not prevOwned then
			b.Text = "Buy " .. Config.Tools[i - 1].name .. " first"
			b.BackgroundColor3 = C.disabled
			b.Active = false
		else
			b.Text = "    Buy " .. fmt(tool.price)
			b.BackgroundColor3 = if coins >= tool.price then C.good else C.disabled
			b.Active = true
		end
		b.Coin.Visible = owned[tool.id] ~= true and prevOwned == true and equipped ~= tool.id
		b.TextColor3 = if b.BackgroundColor3 == C.blue then Color3.new(1, 1, 1) else C.ink
		card.BackgroundTransparency = if not owned[tool.id] and not prevOwned then 0.45 else 0
		card:FindFirstChildOfClass("UIStroke").Enabled = tool.id == focused
	end
end

tabHand.Activated:Connect(function()
	tab = "hand"
	Shop.render()
end)
tabMachine.Activated:Connect(function()
	tab = "machine"
	Shop.render()
end)

-- the card for a tool, if it's on the visible tab (used by the tutorial arrow)
function Shop.visibleCard(id: string): Frame?
	local c = cards[id]
	if panel.Visible and c and c.Visible then
		return c
	end
	return nil
end

function Shop.open(focus: string?)
	Panels.closeAll()
	if not focus and (player:GetAttribute("Tutorial") or 0) == 4 then
		focus = Shop.nextToolId()
	end
	focused = focus
	if focus then
		tab = Config.GetTool(focus).kind
	end
	Shop.render()
	panel.Visible = true
	if focus and cards[focus] then
		task.defer(function()
			local c = cards[focus]
			local y = c.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y
			list.CanvasPosition = Vector2.new(0, math.max(0, y - 10))
		end)
	end
end

return Shop
