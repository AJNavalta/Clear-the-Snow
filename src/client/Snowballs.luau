--!nonstrict
-- Snowball fights on the client: Q (or the THROW button on touch screens) throws a
-- snowball while Bare Hands are equipped. The server decides hits; this script draws
-- every snowball in flight and the stumble when someone gets hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Theme = require(script.Parent.UI.Theme)
local Panels = require(script.Parent.UI.Panels)
local Hud = require(script.Parent.UI.Hud)
local SB = Config.Snowball

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local ThrowRemote = Remotes:WaitForChild("ThrowSnowball")
local Fx = Remotes:WaitForChild("SnowballFx")

local Snowballs = {}

local function hasHands(): boolean
	return player:GetAttribute("Equipped") == "hands"
end

-- ---------------------------------------------------------------- throwing
local lastThrow = 0
local function throw()
	if not hasHands() or os.clock() - lastThrow < SB.Cooldown then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	lastThrow = os.clock()
	local dir
	if Panels.isTouch then
		dir = Workspace.CurrentCamera.CFrame.LookVector
	else
		dir = mouse.Hit.Position - (hrp.Position + Vector3.new(0, 1.5, 0))
	end
	if dir.Magnitude < 0.1 then
		dir = hrp.CFrame.LookVector
	end
	ThrowRemote:FireServer(dir.Unit)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Q then
		throw()
	end
end)

local throwBtn
if Panels.isTouch then
	throwBtn = Theme.button({
		Text = "THROW",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -214),
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = Color3.fromRGB(240, 246, 255),
		Visible = false,
		Parent = Panels.gui,
	})
	throwBtn:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	throwBtn.Activated:Connect(throw)
end
local function refreshButton()
	if throwBtn then
		throwBtn.Visible = hasHands()
	end
end
player:GetAttributeChangedSignal("Equipped"):Connect(refreshButton)
refreshButton()

-- ---------------------------------------------------------------- snowballs in flight
local function flyBall(origin: Vector3, velocity: Vector3, thrower: Player)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1, 1, 1) * SB.Radius * 2
	ball.Material = Enum.Material.Snow
	ball.Color = Color3.fromRGB(248, 251, 255)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Parent = Workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ball, thrower.Character }
	local pos, vel, t = origin, velocity, 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		local nv = vel + Vector3.new(0, -SB.Gravity * dt, 0)
		local step = (vel + nv) * 0.5 * dt
		vel = nv
		local hit = Workspace:Raycast(pos, step, params)
		if hit or t > SB.MaxFlightTime then
			conn:Disconnect()
			if hit then
				-- little puff of snow
				local puff = Instance.new("Part")
				puff.Shape = Enum.PartType.Ball
				puff.Anchored, puff.CanCollide, puff.CanQuery, puff.CanTouch = true, false, false, false
				puff.Material = Enum.Material.Snow
				puff.Color = ball.Color
				puff.Size = Vector3.new(2.2, 2.2, 2.2)
				puff.CFrame = CFrame.new(hit.Position)
				puff.Transparency = 0.3
				puff.Parent = Workspace
				game:GetService("TweenService"):Create(puff, TweenInfo.new(0.35), { Size = Vector3.new(3.6, 3.6, 3.6), Transparency = 1 }):Play()
				game:GetService("Debris"):AddItem(puff, 0.4)
			end
			ball:Destroy()
			return
		end
		pos += step
		ball.CFrame = CFrame.new(pos)
	end)
end

-- ---------------------------------------------------------------- stumble
-- Tips the character's root joint back and forth for the stun time. Every client runs
-- this for the stunned character, so everyone sees the stumble.
local function stumble(char: Model, seconds: number)
	local joint = (char:FindFirstChild("LowerTorso") and char.LowerTorso:FindFirstChild("Root"))
		or (char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart:FindFirstChild("RootJoint"))
	if not joint or not joint:IsA("Motor6D") then
		return
	end
	local isR6 = joint.Name == "RootJoint"
	local t0 = os.clock()
	local total = seconds + 0.25
	local conn
	conn = RunService.Stepped:Connect(function()
		local k = (os.clock() - t0) / total
		if k >= 1 or not joint.Parent then
			conn:Disconnect()
			return
		end
		local fade = math.sin(k * math.pi)
		local back = math.rad(-28) * fade -- lean back from the hit
		local wobble = math.rad(14) * math.sin(k * math.pi * 4) * fade
		local tilt = if isR6 then CFrame.Angles(-back, wobble, 0) else CFrame.Angles(back, 0, wobble)
		joint.Transform = joint.Transform * tilt
	end)
end

Fx.OnClientEvent:Connect(function(kind, a, b, c, d, e)
	if kind == "throw" then
		local thrower, origin, velocity, sentAt = a, b, c, d
		if typeof(origin) == "Vector3" and typeof(velocity) == "Vector3" and thrower then
			-- skip ahead by the network delay so the ball lines up with the server's
			local lag = math.clamp(Workspace:GetServerTimeNow() - (sentAt or 0), 0, 0.3)
			flyBall(origin + velocity * lag, velocity, thrower)
		end
	elseif kind == "stun" then
		local char, seconds, throwerName, victim = a, b, c, d
		if typeof(char) == "Instance" then
			stumble(char, seconds)
		end
		if victim == player then
			Hud.toast("Splat! " .. tostring(throwerName) .. " hit you with a snowball!", 1.6)
		elseif throwerName == player.Name and victim then
			Hud.floater("Direct hit on " .. victim.DisplayName .. "!", Color3.new(1, 1, 1))
		end
	end
end)

return Snowballs
