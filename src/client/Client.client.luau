--!nonstrict
-- Clear the Snow: client entry point. It loads the UI modules, wires the side buttons,
-- handles input and listens for messages from the server.
--
--   UI/Theme.luau       colours, fonts, drawn icons (coin, arrow)
--   UI/Panels.luau      the ScreenGui and the pop-up window frame
--   UI/Hud.luau         coins, pile, load bar, side buttons, toasts
--   UI/ShopPanel.luau   shopping list
--   UI/DailyPanel.luau  daily rewards
--   UI/SpinPanel.luau   lucky spin wheel
--   UI/HelpPanel.luau   how to play
--   UI/EventBar.luau    event countdown and progress / HP bar at the top
--   Tutorial.luau       step-by-step tutorial with arrows
--   Snowballs.luau      snowball throwing (Bare Hands), flight visuals, stumble
--   WorldEffects.luau   pile mound, snowfall, display labels and turntables

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

-- ---------------------------------------------------------------- guard against old copies
-- If the place file still holds an older copy of this game's client script (for example
-- from an earlier .rbxlx), both would run and the HUD would be drawn twice. Stop any other
-- "Client" script and remove what it drew, and say where it was so it can be deleted.
local function isStrayClient(inst: Instance): boolean
	return inst ~= script and inst:IsA("LocalScript") and inst.Name == "Client"
end
local function stopStray(inst: Instance)
	warn("[ClearTheSnow] Stopped an old copy of the client script at " .. inst:GetFullName()
		.. ". Delete it in Studio (look in StarterPlayer > StarterPlayerScripts and StarterGui) so only Rojo's copy is left.")
	inst.Enabled = false
	inst:Destroy()
end
local function sweepStrays()
	local localPlayer = Players.LocalPlayer
	for _, root in { localPlayer:FindFirstChild("PlayerScripts"), localPlayer:FindFirstChild("PlayerGui"), localPlayer.Character } do
		if root then
			for _, d in root:GetDescendants() do
				if isStrayClient(d) and not d:IsDescendantOf(script.Parent) then
					stopStray(d)
				end
			end
		end
	end
	for _, c in script.Parent:GetChildren() do
		if isStrayClient(c) then
			stopStray(c)
		end
	end
end
sweepStrays()
task.delay(3, sweepStrays) -- catch copies that start a little later

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = script.Parent:WaitForChild("UI")
local Panels = require(UI.Panels)
local Hud = require(UI.Hud)
local Shop = require(UI.ShopPanel)
local Daily = require(UI.DailyPanel)
local Spin = require(UI.SpinPanel)
local Help = require(UI.HelpPanel)
-- these wait for things the server makes, so load them in the background: the shop,
-- buttons and prompts must work even if one of them is still waiting
task.spawn(require, UI.EventBar)
task.spawn(require, script.Parent:WaitForChild("Tutorial"))
task.spawn(require, script.Parent:WaitForChild("Snowballs"))
local WorldEffects = require(script.Parent:WaitForChild("WorldEffects"))

local player = Players.LocalPlayer
local fmt = Config.FormatNumber

-- the game equips tools itself, so hide the default backpack bar
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- ---------------------------------------------------------------- side buttons
Hud.shopBtn.Activated:Connect(function()
	Shop.open()
end)
Hud.dailyBtn.Activated:Connect(Daily.open)
Hud.spinBtn.Activated:Connect(Spin.open)
Hud.helpBtn.Activated:Connect(Help.open)
Hud.autoBtn.Activated:Connect(function()
	Remotes.SetAuto:FireServer(not player:GetAttribute("Auto"))
end)

-- ---------------------------------------------------------------- refresh UI when attributes change
local function refresh()
	Hud.refresh()
	if Shop.panel.Visible then
		Shop.render()
	end
	if Daily.panel.Visible then
		Daily.render()
	end
	if Spin.panel.Visible and not Spin.isSpinning() then
		Spin.render()
	end
end
for _, a in { "Coins", "Load", "Capacity", "Pile", "Equipped", "Owned", "Spins", "DailyCanClaim", "Auto", "BoostSell", "BoostCapacity" } do
	player:GetAttributeChangedSignal(a):Connect(refresh)
end
task.spawn(function()
	while true do
		task.wait(1)
		refresh()
	end
end)

-- ---------------------------------------------------------------- input: hold to scoop
local held = { mouse = false, key = false, touch = false }
local function sendScoop()
	Remotes.SetScooping:FireServer(held.mouse or held.key or held.touch)
end
if Panels.isTouch then
	Hud.makeScoopButton(function(on)
		held.touch = on
		sendScoop()
	end)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		held.mouse = true
		sendScoop()
	elseif input.KeyCode == Enum.KeyCode.F then
		held.key = true
		sendScoop()
	elseif input.KeyCode == Enum.KeyCode.R then
		Remotes.SetAuto:FireServer(not player:GetAttribute("Auto"))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		held.mouse = false
		sendScoop()
	elseif input.KeyCode == Enum.KeyCode.F then
		held.key = false
		sendScoop()
	end
end)

-- ---------------------------------------------------------------- messages from the server
Remotes.Notify.OnClientEvent:Connect(function(kind, a, b)
	if kind == "toast" then
		Hud.toast(a, b)
	elseif kind == "open" then
		if a == "shop" then
			Shop.open(b)
		elseif a == "daily" then
			Daily.open()
		elseif a == "spin" then
			Spin.open()
		end
	elseif kind == "dumped" then
		Hud.floater("+" .. fmt(a) .. " snow on the pile", Color3.new(1, 1, 1))
	elseif kind == "present" then
		Hud.floater("Present! +" .. fmt(a) .. " coins", Color3.fromHex("#ffd54f"))
		Hud.toast("You opened a present: +" .. fmt(a) .. " coins!", 2.5)
	elseif kind == "sold" then
		Hud.floater("+" .. fmt(a) .. " coins")
	elseif kind == "full" then
		local tool = Config.GetTool(player:GetAttribute("Equipped") or "hands")
		Hud.toast(if tool.kind == "machine" then "Machine full! Drive to the Snow Pile." else "Hands full! Take it to the Snow Pile.")
	end
end)

-- ---------------------------------------------------------------- out-of-date place check
-- If the server scripts in this place are older than this client, say so on screen.
task.delay(8, function()
	local serverVersion = ReplicatedStorage:GetAttribute("ClearTheSnowVersion")
	if serverVersion == Config.Version then
		return
	end
	warn("[ClearTheSnow] Server scripts are version " .. tostring(serverVersion) .. " but the client is " .. tostring(Config.Version)
		.. ". This place has old copies of the game's scripts. Open the latest ClearTheSnow.rbxlx, or delete the old scripts and sync with Rojo.")
	local Theme = require(UI.Theme)
	local warnCard = Theme.new("TextButton", {
		Name = "OldScriptsWarning",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.C.bad,
		Size = UDim2.fromOffset(480, 58),
		LayoutOrder = 0,
		Font = Theme.BoldFont,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextWrapped = true,
		Text = "This place is running OLD game scripts, so some things won't work. Open the latest ClearTheSnow.rbxlx (or see Output). Click to hide.",
		ZIndex = 30,
		Parent = Panels.top,
	}, { Theme.corner(12), Theme.pad(8) })
	warnCard.Activated:Connect(function()
		warnCard:Destroy()
	end)
end)

-- ---------------------------------------------------------------- first load
task.spawn(function()
	while not player:GetAttribute("Ready") do
		task.wait(0.5)
	end
	refresh()
	WorldEffects.refreshDisplays()
end)
