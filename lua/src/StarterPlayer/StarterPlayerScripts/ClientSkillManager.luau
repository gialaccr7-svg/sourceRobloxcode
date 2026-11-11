--!strict
-- ClientSkillManager.luau
-- Client-side moveset controller for Saitama R15 Martial Arts character:
-- 1. Listens for PC skill inputs: Keys Z, X, C, V and G (Awakening / Ultimate).
-- 2. Client prediction: Instant animation playback via AnimationManager, camera shakes, and VFX triggers.
-- 3. Communicates with server via SkillEvent remote.
-- 4. Receives and renders remote VFX & ScreenShake events from other players and server authorities.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local ClientCombatCore = require(script.Parent:WaitForChild("ClientCombatCore"))

-- Safe references to shared modules
local Modules = ReplicatedStorage:WaitForChild("Modules", 5) :: Folder?
local MovesetData
if Modules and Modules:FindFirstChild("MovesetData") then
	MovesetData = require(Modules:WaitForChild("MovesetData"))
else
	MovesetData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MovesetData"))
end

local AnimationManager
if Modules and Modules:FindFirstChild("AnimationManager") then
	AnimationManager = require(Modules:WaitForChild("AnimationManager"))
else
	AnimationManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AnimationManager"))
end

-- Optional UI & VFX modules with graceful fallback
local function getScreenShake()
	if Modules and Modules:FindFirstChild("ScreenShake") then
		local s, res = pcall(require, Modules.ScreenShake)
		if s then return res end
	end
	return nil
end

local function getVFXHelper()
	if Modules and Modules:FindFirstChild("VFXHelper") then
		local s, res = pcall(require, Modules.VFXHelper)
		if s then return res end
	end
	return nil
end

local ClientSkillManager = {}

-- State tracking
local isAwakenedState = false
local localCooldowns: { [number]: number } = {}
local isInitialized = false

-- Safe remote retrieval
local function getSkillEvent(): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
	if not remotes then
		remotes = ReplicatedStorage:WaitForChild("Remotes", 5) :: Folder?
	end
	if not remotes then return nil end
	return remotes:FindFirstChild("SkillEvent") :: RemoteEvent?
end

--------------------------------------------------------------------------------
-- LOCAL QUERY HELPERS
--------------------------------------------------------------------------------

-- Checks if the local player is currently awakened
function ClientSkillManager.IsAwakened(): boolean
	local char = player.Character
	if char and char:GetAttribute("IsAwakened") ~= nil then
		return char:GetAttribute("IsAwakened") == true
	end
	return isAwakenedState
end

-- Gets remaining cooldown time in seconds for a skill slot (1-4)
function ClientSkillManager.GetRemainingCooldown(skillId: number): number
	local expiry = localCooldowns[skillId]
	if not expiry then return 0 end
	local remaining = expiry - os.clock()
	return math.max(0, remaining)
end

-- Goku Authentic SFX Asset IDs mined from open-source references
local GOKU_SFX = {
	RushBarrage = "rbxassetid://6968100828",
	KamehamehaCharge = "rbxassetid://1370232812",
	KamehamehaFire = "rbxassetid://5689578119",
	KaiokenAura = "rbxassetid://4595238902",
	InstantTransmission = "rbxassetid://4826619573",
	SuperSaiyanAwakening = "rbxassetid://275282542",
}

local function playGokuSound(soundId: string, parentInstance: Instance?, volume: number?)
	if not parentInstance or soundId == "" or soundId == "rbxassetid://0" then return end
	pcall(function()
		local snd = Instance.new("Sound")
		snd.SoundId = soundId
		snd.Volume = volume or 1.0
		snd.RollOffMaxDistance = 120
		snd.Parent = parentInstance
		snd:Play()
		task.delay(3.5, function()
			snd:Destroy()
		end)
	end)
end

-- Procedural VFX for Goku skills
local function spawnKamehamehaClientVFX(character: Model, isAwakened: boolean)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local vfxFolder = workspace:FindFirstChild("VFX_Container") or workspace

	-- Phase 1: Blue charging Ki sphere at hip
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(1.0, 1.0, 1.0)
	orb.CFrame = root.CFrame * CFrame.new(0.7, 0.33, -1.05)
	local orbColor = Color3.fromRGB(80, 200, 255)
	if isAwakened then
		orbColor = Color3.fromRGB(255, 230, 80)
	end
	orb.Color = orbColor
	orb.Material = Enum.Material.Neon
	orb.CanCollide = false
 orb.CanQuery = false
 orb.CanTouch = false
	orb.Anchored = true
	orb.CanTouch = false
 orb.CanQuery = false
 orb.Parent = vfxFolder
 local chargeFollow = RunService.RenderStepped:Connect(function()
  if root.Parent and orb.Parent then
   orb.CFrame = root.CFrame * CFrame.new(0.7, 0.33, -1.05)
  end
 end)
 game:GetService("Debris"):AddItem(orb, 2)

	local light = Instance.new("PointLight")
	light.Color = orb.Color
	light.Range = 18
	light.Brightness = 4
	light.Parent = orb

	local chargeTween = game:GetService("TweenService"):Create(
		orb,
		TweenInfo.new(if isAwakened then 0.53 else 0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(1.8, 1.8, 1.8) }
	)
	chargeTween:Play()

	-- Phase 2: Beam release forward
	task.delay(if isAwakened then 0.55 else 0.50, function()
		chargeFollow:Disconnect()
		if not character.Parent or not root.Parent then
			orb:Destroy()
			return
		end
		orb:Destroy()

		local beamLen = 44.0
		local beamWidth = 7.5
		if isAwakened then
			beamLen = 50.0
			beamWidth = 10.0
		end

		-- Outer Energy Beam Cylinder
		local beam = Instance.new("Part")
		beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(beamLen, beamWidth, beamWidth)
		beam.CFrame = (root.CFrame * CFrame.new(0.2, 1.25, -beamLen / 2 - 1.5)) * CFrame.Angles(0, math.rad(90), 0)
		local beamColor = Color3.fromRGB(50, 160, 255)
		if isAwakened then
			beamColor = Color3.fromRGB(255, 220, 60)
		end
		beam.Color = beamColor
		beam.Material = Enum.Material.Neon
		beam.Transparency = 0.25
		beam.CanCollide = false
 beam.CanQuery = false
 beam.CanTouch = false
		beam.Anchored = true
		beam.Parent = vfxFolder

		-- Inner Core Cylinder
		local core = Instance.new("Part")
		core.Shape = Enum.PartType.Cylinder
		core.Size = Vector3.new(beamLen + 1, beamWidth * 0.5, beamWidth * 0.5)
		core.CFrame = beam.CFrame
		core.Color = Color3.fromRGB(255, 255, 255)
		core.Material = Enum.Material.Neon
		core.Transparency = 0.05
		core.CanCollide = false
 core.CanQuery = false
 core.CanTouch = false
		core.Anchored = true
		core.Parent = vfxFolder

		-- Fade and dissipate beam
		task.delay(0.40, function()
			local fade = game:GetService("TweenService"):Create(
				beam,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1, Size = Vector3.new(beamLen, beamWidth * 1.5, beamWidth * 1.5) }
			)
			local coreFade = game:GetService("TweenService"):Create(
				core,
				TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1 }
			)
			fade:Play()
			coreFade:Play()
			task.delay(0.26, function()
				beam:Destroy()
				core:Destroy()
			end)
		end)
	end)
end

local function spawnKaiokenClientVFX(character: Model, isAwakened: boolean)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local vfxFolder = workspace:FindFirstChild("VFX_Container") or workspace

	-- Crimson Kaioken Aura burst sphere
	local burst = Instance.new("Part")
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.new(4, 4, 4)
	burst.CFrame = root.CFrame
	local burstColor = Color3.fromRGB(255, 25, 45)
	if isAwakened then
		burstColor = Color3.fromRGB(255, 70, 30)
	end
	burst.Color = burstColor
	burst.Material = Enum.Material.Neon
	burst.Transparency = 0.3
	burst.CanCollide = false
 burst.CanQuery = false
 burst.CanTouch = false
	burst.Anchored = true
	burst.Parent = vfxFolder

	local bLight = Instance.new("PointLight")
	bLight.Color = burst.Color
	bLight.Range = 25
	bLight.Brightness = 8
	bLight.Parent = burst

	local tw = game:GetService("TweenService"):Create(
		burst,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(16, 16, 16), Transparency = 1 }
	)
	tw:Play()
	tw.Completed:Connect(function()
		burst:Destroy()
	end)
end

local function spawnInstantTransmissionClientVFX(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local vfxFolder = workspace:FindFirstChild("VFX_Container") or workspace

	-- Departure vertical streak flash
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Cylinder
	flash.Size = Vector3.new(14, 3, 3)
	flash.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90))
	flash.Color = Color3.fromRGB(150, 235, 255)
	flash.Material = Enum.Material.Neon
	flash.Transparency = 0.15
	flash.CanCollide = false
 flash.CanQuery = false
 flash.CanTouch = false
	flash.Anchored = true
	flash.Parent = vfxFolder

	local tw = game:GetService("TweenService"):Create(
		flash,
		TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(24, 0.2, 0.2), Transparency = 1 }
	)
	tw:Play()
	tw.Completed:Connect(function()
		flash:Destroy()
	end)
end

local function spawnSpiritBombClientVFX(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local vfxFolder = workspace:FindFirstChild("VFX_Container") or workspace

	-- Giant energy sphere above head
	local bomb = Instance.new("Part")
	bomb.Shape = Enum.PartType.Ball
	bomb.Size = Vector3.new(3, 3, 3)
	bomb.CFrame = root.CFrame * CFrame.new(0, 10, 0)
	bomb.Color = Color3.fromRGB(80, 220, 255)
	bomb.Material = Enum.Material.Neon
	bomb.Transparency = 0.2
	bomb.CanCollide = false
 bomb.CanQuery = false
 bomb.CanTouch = false
	bomb.Anchored = true
	bomb.CanTouch = false
 bomb.CanQuery = false
 bomb.Parent = vfxFolder
 local bombFollow = RunService.RenderStepped:Connect(function()
  if root.Parent and bomb.Parent then bomb.CFrame = root.CFrame * CFrame.new(0, 10, 0) end
 end)
 game:GetService("Debris"):AddItem(bomb, 3)

	local bLight = Instance.new("PointLight")
	bLight.Color = bomb.Color
	bLight.Range = 35
	bLight.Brightness = 10
	bLight.Parent = bomb

	local tw = game:GetService("TweenService"):Create(
		bomb,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = Vector3.new(14, 14, 14) }
	)
	tw:Play()

	-- Launch forward and explode
	task.delay(0.55, function()
		bombFollow:Disconnect()
		if not character.Parent or not root.Parent then
			bomb:Destroy()
			return
		end
		local forwardPos = root.Position + (root.CFrame.LookVector * 28)
		local moveTw = game:GetService("TweenService"):Create(
			bomb,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = forwardPos }
		)
		moveTw:Play()
		moveTw.Completed:Connect(function()
			local blast = Instance.new("Part")
			blast.Shape = Enum.PartType.Ball
			blast.Size = Vector3.new(8, 8, 8)
			blast.CFrame = CFrame.new(forwardPos)
			blast.Color = Color3.fromRGB(150, 240, 255)
			blast.Material = Enum.Material.Neon
			blast.CanCollide = false
 blast.CanQuery = false
 blast.CanTouch = false
			blast.Anchored = true
			blast.Parent = vfxFolder

			bomb:Destroy()

			local blastTw = game:GetService("TweenService"):Create(
				blast,
				TweenInfo.new(0.40, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = Vector3.new(32, 32, 32), Transparency = 1 }
			)
			blastTw:Play()
			blastTw.Completed:Connect(function()
				blast:Destroy()
			end)
		end)
	end)
end

-- Checks if local character can currently cast actions (not stunned or ragdolled)
local function canCastSkill(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	-- Only hard stuns and active ragdoll prevent skill activation
	if character:GetAttribute("IsStunned") == true
		or character:GetAttribute("IsRagdolled") == true
		or character:GetAttribute("IsCountering") == true then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
-- SKILL EXECUTION & CLIENT PREDICTION
--------------------------------------------------------------------------------

-- Triggers skill cast for given skill slot (1-4)
function ClientSkillManager.CastSkill(skillId: number)
	local character = player.Character
	if not character or not canCastSkill(character) then
		return
	end

	-- Check local cooldown
	if ClientSkillManager.GetRemainingCooldown(skillId) > 0 then
		return
	end

	local isAwakened = ClientSkillManager.IsAwakened()
	local skillConfig = MovesetData.GetSkill(skillId, isAwakened)
	if not skillConfig then return end
	local skillEvent = getSkillEvent()
	if not skillEvent then return end

	-- Release both the local block controller and its authoritative server state.
	ClientCombatCore.StopBlock()
	character:SetAttribute("IsBlocking", false)

	-- Optimistic local cooldown prediction
	local expectedCD = MovesetData.GetCooldown(skillId, isAwakened)
	localCooldowns[skillId] = os.clock() + expectedCD

	-- Send intent immediately; optional audio/VFX must never delay or prevent it.
	skillEvent:FireServer("CastSkill", skillId)

	-- 1. Client Prediction: Instant Animation Playback
	AnimationManager.PlayAnimation(character, skillConfig.AnimationName)

	-- 2. Client Prediction: Camera Shake & Local Audio/VFX
	local screenShake = getScreenShake()
	local vfxHelper = getVFXHelper()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?

	if skillId == 1 then
		-- Rush Attack / Đấm liên hoàn: rapid rumble & punch impacts
		playGokuSound(GOKU_SFX.RushBarrage, root, 0.9)
		if screenShake and screenShake.Light then
			screenShake.Light()
		end
		if vfxHelper and vfxHelper.PunchImpact and root then
			vfxHelper.PunchImpact(root.Position + (root.CFrame.LookVector * 3.5), root.CFrame.LookVector, false)
		end
	elseif skillId == 2 then
		-- Kamehameha: charging stance at hip with blue Ki orb, then beam fire
		playGokuSound(GOKU_SFX.KamehamehaCharge, root, 1.0)
		task.delay(skillConfig.WindupTime, function()
			playGokuSound(GOKU_SFX.KamehamehaFire, root, 1.0)
		end)
  task.delay(skillConfig.WindupTime, function()
   if character.Parent and screenShake and screenShake.Heavy then screenShake.Heavy() end
  end)
		spawnKamehamehaClientVFX(character, isAwakened)
	elseif skillId == 3 then
		-- Kaioken / Cận chiến võ thuật: crimson aura burst & martial arts slam
		playGokuSound(GOKU_SFX.KaiokenAura, root, 1.0)
		if screenShake and screenShake.Medium then
			screenShake.Medium()
		end
		spawnKaiokenClientVFX(character, isAwakened)

	elseif skillId == 4 then
		-- Instant Transmission / Spirit Bomb
		if isAwakened then
			playGokuSound(GOKU_SFX.KamehamehaFire, root, 1.0)
			spawnSpiritBombClientVFX(character)
		else
			playGokuSound(GOKU_SFX.InstantTransmission, root, 1.0)
			if screenShake and screenShake.Medium then
				screenShake.Medium()
			end
			spawnInstantTransmissionClientVFX(character)
			if vfxHelper and vfxHelper.FlashCounter then
				vfxHelper.FlashCounter(character)
			end
		end
	end

end

-- Triggers Awakening / Ultimate transformation (Key G)
function ClientSkillManager.ActivateAwakening()
	local character = player.Character
	if not character or not canCastSkill(character) or character:GetAttribute("IsAttacking") == true then
		return
	end

	if ClientSkillManager.IsAwakened() then
		return
	end

	-- Check Rage meter requirement (100%)
	local currentRage = (character and character:GetAttribute("Rage")) or 0
	if currentRage < MovesetData.AwakeningConfig.RequiredRageMeter then
		return
	end

	-- Client Prediction: Super Saiyan Transformation Audio, Animation & Shake
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	playGokuSound(GOKU_SFX.SuperSaiyanAwakening, root, 1.0)
	AnimationManager.PlayAnimation(character, MovesetData.AwakeningConfig.AnimationName)

	local screenShake = getScreenShake()
	if screenShake and screenShake.Awakening then
		screenShake.Awakening()
	end

	local vfxHelper = getVFXHelper()
	if vfxHelper and vfxHelper.AwakeningBurst then
		vfxHelper.AwakeningBurst(character)
	end

	-- Send request to server
	local skillEvent = getSkillEvent()
	if skillEvent then
		skillEvent:FireServer("Awakening")
	end
end

--------------------------------------------------------------------------------
-- REMOTE EVENT HANDLING (SERVER SYNC & VFX REPLICATION)
--------------------------------------------------------------------------------

local function setupRemoteListeners()
	local skillEvent = getSkillEvent()
	if not skillEvent then
		task.delay(1, setupRemoteListeners)
		return
	end

	skillEvent.OnClientEvent:Connect(function(action: string, data: any)
		if typeof(data) ~= "table" then return end

		local screenShake = getScreenShake()
		local vfxHelper = getVFXHelper()

		if action == "SkillCooldown" then
			local slotId = data.SkillId or (data.ActionKey and tonumber(string.match(data.ActionKey, "(%d+)")))
			local duration = data.Duration :: number?
			if slotId and duration then
				localCooldowns[slotId] = os.clock() + duration
			end

		elseif action == "AwakeningState" then
			local isAwk = data.IsAwakened == true or data.Active == true
			isAwakenedState = isAwk

			local char = player.Character
			if char then
				char:SetAttribute("IsAwakened", isAwk)
			end

			if vfxHelper then
				if isAwk and char then
					vfxHelper.AwakeningBurst(char)
				elseif not isAwk and char then
					vfxHelper.SetAwakeningAura(char, false)
				end
			end

		elseif action == "SkillVFX" then
			local skillId = data.SkillId
			local vfxAction = data.Action
			local attacker = data.Attacker :: Model?
			local isAwakened = data.IsAwakened == true

   if attacker and attacker ~= player.Character then
    if vfxAction == "HeavyPunchWindup" then spawnKamehamehaClientVFX(attacker, isAwakened)
    elseif vfxAction == "SpiritBombStart" then spawnSpiritBombClientVFX(attacker)
    elseif vfxAction == "CounterStance" then spawnInstantTransmissionClientVFX(attacker) end
   end

			if vfxAction == "RushTick" then
				if attacker and screenShake and screenShake.Light then
					local hrp = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
					if hrp then
						screenShake.ShakeAtPosition(hrp.Position, 80, 0.4, 0.1, 30)
					end
				end

			elseif vfxAction == "RushFinisher" then
				if attacker and screenShake and screenShake.Medium then
					local hrp = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
					if hrp then
						screenShake.ShakeAtPosition(hrp.Position, 90, 1.2, 0.25, 25)
						if vfxHelper and vfxHelper.PunchImpact then
							vfxHelper.PunchImpact(hrp.Position + (hrp.CFrame.LookVector * 4), hrp.CFrame.LookVector, true)
						end
					end
				end

			elseif vfxAction == "KamehamehaBeam" or vfxAction == "HeavyPunchImpact" then
				local impactCFrame = data.ImpactCFrame :: CFrame?
				local impactPos = Vector3.zero
				if impactCFrame then
					impactPos = impactCFrame.Position
				elseif attacker and attacker:FindFirstChild("HumanoidRootPart") then
					impactPos = attacker.HumanoidRootPart.Position
				end

				if screenShake then
					if isAwakened and screenShake.Explosion then
						screenShake.Explosion()
					elseif screenShake.Heavy then
						screenShake.Heavy()
					end
				end

				if vfxHelper and vfxHelper.PunchImpact then
					vfxHelper.PunchImpact(impactPos, Vector3.new(0, 1, 0), true)
				end

			elseif vfxAction == "KaiokenBurst" or vfxAction == "GroundSlamImpact" then
				local impactPos = data.ImpactPosition :: Vector3?
				local radius = data.Radius :: number? or 18.0
				if impactPos then
					if vfxHelper and vfxHelper.GroundSlam then
						vfxHelper.GroundSlam(impactPos, radius)
					end
					if screenShake and screenShake.Explosion then
						screenShake.ShakeAtPosition(impactPos, 120, 2.2, 0.45, 22)
					end
				end

			elseif vfxAction == "CounterTriggered" or vfxAction == "InstantTransmissionFlash" then
				if attacker and vfxHelper and vfxHelper.FlashCounter then
					vfxHelper.FlashCounter(attacker)
				end
				if screenShake and screenShake.Medium then
					screenShake.Medium()
				end

			elseif vfxAction == "FlashDash" then
				local startPos = data.StartPos :: Vector3?
				local endPos = data.EndPos :: Vector3?
				if attacker and vfxHelper and vfxHelper.DashTrail and startPos and endPos then
					vfxHelper.DashTrail(attacker, (endPos - startPos).Unit, 0.22, Color3.fromRGB(120, 230, 255))
				end

			elseif vfxAction == "AwakeningTransform" then
				if attacker and vfxHelper and vfxHelper.AwakeningBurst then
					vfxHelper.AwakeningBurst(attacker)
				end
				if screenShake and screenShake.Awakening then
					screenShake.Awakening()
				end

			elseif vfxAction == "AwakeningEnd" then
				if attacker and vfxHelper and vfxHelper.SetAwakeningAura then
					vfxHelper.SetAwakeningAura(attacker, false)
				end
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- INPUT LISTENER & INITIALIZATION
--------------------------------------------------------------------------------

function ClientSkillManager.Init()
	if isInitialized then return end
	isInitialized = true

	setupRemoteListeners()

	-- Keyboard dispatch lives in CombatController.

	-- Sync awakening state when character respawns
	player.CharacterAdded:Connect(function(char)
		isAwakenedState = false
		table.clear(localCooldowns)
	end)
end

-- Auto-initialize if running on client
if RunService:IsClient() then
	ClientSkillManager.Init()
end

return ClientSkillManager
