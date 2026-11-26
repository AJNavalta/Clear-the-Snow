--!nonstrict
-- "How to play" window, opened from the Help button. Can restart the tutorial.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Theme = require(script.Parent.Theme)
local Panels = require(script.Parent.Panels)
local C, label, button = Theme.C, Theme.label, Theme.button

local Help = {}

local panel = Panels.make("Help", "Clear the Snow", Vector2.new(520, 440))
Help.panel = panel
label({
	Text = "1. Walk into the snow and hold click (or F) to scoop it up. Each tool only carries so much.\n\n"
		.. "2. Bring it to the Snow Pile at the market. You toss it in when you get close.\n\n"
		.. "3. Walk up to the Snow Buyer and press E to sell your whole pile for coins.\n\n"
		.. "4. The Tool Shop is right next door. Walk up to a tool on the display, or press Shop.\n\n"
		.. "5. Snow grows back, so keep clearing! Claim your daily reward and free spin every day.",
	Position = UDim2.fromOffset(0, 46),
	Size = UDim2.new(1, 0, 1, -116),
	Font = Theme.BodyFont,
	TextScaled = false,
	TextSize = 17,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 11,
	Parent = panel,
})
local replay = button({ Text = "Replay tutorial", Position = UDim2.new(0, 0, 1, -54), Size = UDim2.new(0.5, -6, 0, 50), BackgroundColor3 = C.panel2, TextColor3 = C.text, ZIndex = 11, Parent = panel })
local go = button({ Text = "Let's go!", Position = UDim2.new(0.5, 6, 1, -54), Size = UDim2.new(0.5, -6, 0, 50), ZIndex = 11, Parent = panel })
replay.Activated:Connect(function()
	Remotes.TutorialAction:FireServer("replay")
	panel.Visible = false
end)
go.Activated:Connect(function()
	panel.Visible = false
end)

function Help.open()
	Panels.closeAll()
	panel.Visible = true
end

return Help
