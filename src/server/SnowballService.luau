--!nonstrict
-- Snowball fights. With Bare Hands equipped a player can throw snowballs. The server
-- flies each snowball itself (raycasting along its arc) and decides hits, so clients
-- can't fake them. Every client draws the snowball and the stumble. Tuning: Config.Snowball.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SB = Config.Snowball

local SnowballService = {}

-- canThrow(player) -> boolean ; onStun(player, seconds) ; walkSpeed(player) -> number
function SnowballService.Init(remotes: Folder, hooks)
	local throwRemote = Instance.new("RemoteEvent")
	throwRemote.Name = "ThrowSnowball"
	throwRemote.Parent = remotes
	local fx = Instance.new("RemoteEvent") -- to all clients: "throw" and "stun"
	fx.Name = "SnowballFx"
	fx.Parent = remotes

	local lastThrow: { [Player]: number } = {}
	local stunnedUntil: { [Player]: number } = {}
	local flying = {}

	local function stun(victim: Player, thrower: Player)
		local now = os.clock()
		if (stunnedUntil[victim] or 0) + SB.ImmuneSeconds > now then
			return -- still stunned or briefly immune, so nobody gets stun-locked
		end
		local char = victim.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return
		end
		stunnedUntil[victim] = now + SB.StunSeconds
		hooks.onStun(victim, SB.StunSeconds)
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
		fx:FireAllClients("stun", char, SB.StunSeconds, thrower.Name, victim)
		task.delay(SB.StunSeconds, function()
			if hum.Parent and stunnedUntil[victim] and stunnedUntil[victim] <= os.clock() + 0.01 then
				hum.WalkSpeed = hooks.walkSpeed(victim)
				hum.JumpPower = 50
				hum.JumpHeight = 7.2
			end
		end)
	end

	function SnowballService.IsStunned(player: Player): boolean
		return (stunnedUntil[player] or 0) > os.clock()
	end

	throwRemote.OnServerEvent:Connect(function(player, dir)
		if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.1 or dir.Magnitude ~= dir.Magnitude or dir.Magnitude > 1e4 then
			return
		end
		local now = os.clock()
		if now - (lastThrow[player] or 0) < SB.Cooldown or SnowballService.IsStunned(player) or not hooks.canThrow(player) then
			return
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then
			return
		end
		lastThrow[player] = now
		dir = dir.Unit
		local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
		local origin = (if hand then hand.Position else hrp.Position + Vector3.new(0, 1.5, 0)) + dir * 1.5
		local velocity = dir * SB.Speed + Vector3.new(0, SB.Speed * 0.08, 0)
		-- throw animation: the default Animate script plays its tool swing on this value
		local tool = char:FindFirstChildOfClass("Tool")
		if tool then
			local anim = Instance.new("StringValue")
			anim.Name = "toolanim"
			anim.Value = "Slash"
			anim.Parent = tool
			task.delay(0.5, function()
				anim:Destroy()
			end)
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		table.insert(flying, { thrower = player, pos = origin, vel = velocity, t = 0, params = params })
		fx:FireAllClients("throw", player, origin, velocity, Workspace:GetServerTimeNow())
	end)

	RunService.Heartbeat:Connect(function(dt)
		for i = #flying, 1, -1 do
			local b = flying[i]
			b.t += dt
			local vel = b.vel + Vector3.new(0, -SB.Gravity * dt, 0)
			local step = (b.vel + vel) * 0.5 * dt
			b.vel = vel
			local hit = Workspace:Spherecast(b.pos, SB.Radius, step, b.params)
			if hit then
				table.remove(flying, i)
				local model = hit.Instance:FindFirstAncestorOfClass("Model")
				local victim = model and Players:GetPlayerFromCharacter(model)
				if victim and victim ~= b.thrower then
					stun(victim, b.thrower)
				end
			elseif b.t > SB.MaxFlightTime then
				table.remove(flying, i)
			else
				b.pos += step
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		lastThrow[p] = nil
		stunnedUntil[p] = nil
	end)
end

return SnowballService
