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

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = script.Parent:WaitForChild("UI")
local Panels = require(UI.Panels)
local Hud = require(UI.Hud)
local Shop = require(UI.ShopPanel)
local Daily = require(UI.DailyPanel)
local Spin = require(UI.SpinPanel)
local Help = require(UI.HelpPanel)
require(UI.EventBar)
require(script.Parent:WaitForChild("Tutorial"))
require(script.Parent:WaitForChild("Snowballs"))
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

-- ---------------------------------------------------------------- first load
task.spawn(function()
	while not player:GetAttribute("Ready") do
		task.wait(0.5)
	end
	refresh()
	WorldEffects.refreshDisplays()
end)
