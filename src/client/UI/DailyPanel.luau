--!nonstrict
-- Daily rewards: a 7-day streak calendar and a Claim button.
-- Reward amounts are set in Config.DailyRewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Theme = require(script.Parent.Theme)
local Panels = require(script.Parent.Panels)
local Hud = require(script.Parent.Hud)
local C, new, label, button = Theme.C, Theme.new, Theme.label, Theme.button
local fmt = Config.FormatNumber

local player = Players.LocalPlayer

local Daily = {}

local panel = Panels.make("Daily", "Daily Rewards", Vector2.new(520, 420))
Daily.panel = panel
label({ Text = "Come back every day to keep your streak. Day 7 is the big one!", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 20), Font = Theme.BodyFont, TextColor3 = C.muted, ZIndex = 11, Parent = panel })
local grid = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 200), ZIndex = 11, Parent = panel }, {
	new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 92), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local cells = {}
for i = 1, #Config.DailyRewards do
	local cell = new("Frame", { BackgroundColor3 = if i == 7 then Color3.fromHex("#7a4fd0") else C.panel2, LayoutOrder = i, ZIndex = 11, Parent = grid }, { Theme.corner(12), Theme.pad(6) })
	label({ Text = "Day " .. i, Size = UDim2.new(1, 0, 0, 16), TextColor3 = C.muted, ZIndex = 12, Parent = cell })
	Theme.coin(16, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), ZIndex = 12, Parent = cell })
	label({ Name = "Reward", Text = "", Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 30), TextWrapped = true, ZIndex = 12, Parent = cell })
	label({ Name = "Check", Text = "CLAIMED", Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 14), TextColor3 = C.good, Visible = false, ZIndex = 12, Parent = cell })
	new("UIStroke", { Color = C.accent, Thickness = 3, Enabled = false, Parent = cell })
	cells[i] = cell
end
local claimBtn = button({ Text = "Claim", Position = UDim2.new(0, 0, 1, -86), Size = UDim2.new(1, 0, 0, 48), ZIndex = 11, Parent = panel })
local info = label({ Text = "", Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 20), Font = Theme.BodyFont, TextColor3 = C.muted, ZIndex = 11, Parent = panel })

function Daily.render()
	local can = player:GetAttribute("DailyCanClaim")
	local idx = player:GetAttribute("DailyIndex") or 1
	local progress = player:GetAttribute("ProgressCoins") or 10
	for i, r in Config.DailyRewards do
		local cell = cells[i]
		local coins = math.max(r.min, math.floor(progress * r.pct + 0.5))
		cell.Reward.Text = fmt(coins) .. " coins" .. (if r.spins > 0 then "\n+" .. r.spins .. " spin" .. (if r.spins > 1 then "s" else "") else "")
		local done = if can then i < idx else i <= idx
		cell.Check.Visible = done
		cell.BackgroundTransparency = if done then 0.5 else 0
		cell:FindFirstChildOfClass("UIStroke").Enabled = can and i == idx
	end
	claimBtn.Text = if can then "Claim Day " .. idx else "Claimed today"
	claimBtn.BackgroundColor3 = if can then C.accent else C.disabled
	claimBtn.Active = can == true
	local streak = player:GetAttribute("DailyStreak") or 0
	if can and player:GetAttribute("DailyBroken") then
		info.Text = "Your streak reset. Start again today!"
	elseif can then
		info.Text = "Current streak: " .. streak .. " day" .. (if streak == 1 then "" else "s")
	else
		info.Text = "Streak: " .. streak .. "  |  next reward in " .. Panels.untilTomorrow()
	end
end

claimBtn.Activated:Connect(function()
	if not player:GetAttribute("DailyCanClaim") then
		return
	end
	local rw = Remotes.ClaimDaily:InvokeServer()
	if rw then
		Hud.toast("+" .. fmt(rw.coins) .. " coins" .. (if rw.spins > 0 then " and +" .. rw.spins .. " spin" .. (if rw.spins > 1 then "s" else "") else "") .. "!")
	end
	task.wait(0.15)
	Daily.render()
end)

function Daily.open()
	Panels.closeAll()
	Daily.render()
	panel.Visible = true
end

return Daily
