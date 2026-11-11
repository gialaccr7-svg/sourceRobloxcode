--!strict
-- CombatInit.server.luau
-- Main Server Entry Script for Roblox Battleground Arena
-- Orchestrates Remotes, Player Lifecycle, HitboxManager, SkillServer,
-- RagdollServer, DestructibleManager, CooldownManager, and anti-cheat validation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Require core shared modules
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5) :: Folder?
local RemotesInit = if RemotesFolder and RemotesFolder:FindFirstChild("RemotesInit") then require(RemotesFolder:WaitForChild("RemotesInit")) else require(ReplicatedStorage.Remotes.RemotesInit)

-- Initialize Remotes
RemotesInit.InitServer()
local CombatEvent = RemotesInit.GetCombatEvent()
local SkillEvent = RemotesInit.GetSkillEvent()
local BlockEvent = RemotesInit.GetBlockEvent()
local DashEvent = RemotesInit.GetDashEvent()

-- Require Server modules
local CooldownManager = require(ServerScriptService:WaitForChild("CooldownManager"))
local CharacterSetup = require(ServerScriptService:WaitForChild("CharacterSetup"))
local CombatServerFolder = ServerScriptService:WaitForChild("CombatServer") :: Folder
local HitboxManager = require(CombatServerFolder:WaitForChild("HitboxManager"))
local RagdollServer = require(CombatServerFolder:WaitForChild("RagdollServer"))

-- Safely require optional/concurrent modules with fallbacks
local ModulesFolder = ReplicatedStorage:WaitForChild("Modules", 5) :: Folder?

local function safeRequire(parent: Instance?, childName: string)
	if not parent then
		return nil
	end
	local child = parent:FindFirstChild(childName)
	if child and child:IsA("ModuleScript") then
		local success, result = pcall(require, child)
		if success then
			return result
		else
			warn(string.format("[CombatInit] Failed to load %s: %s", childName, tostring(result)))
		end
	end
	return nil
end

local MovesetData = safeRequire(ModulesFolder, "MovesetData")
local RagdollHelper = safeRequire(ModulesFolder, "RagdollHelper")
local SkillServer = safeRequire(CombatServerFolder, "SkillServer")
local DestructibleManager = safeRequire(CombatServerFolder, "DestructibleManager")

-- Anti-cheat sanity checks
local MAX_SKILL_REACH = 40.0 -- Maximum reasonable distance for non-aoe interactions

local function isCharacterAliveAndActive(character: Model?): (boolean, Humanoid?)
	if not character or not character.Parent then
		return false, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, nil
	end
	if character:GetAttribute("IsRagdolled") == true then
		return false, humanoid
	end
	if character:GetAttribute("IsStunned") == true then
		return false, humanoid
	end
	return true, humanoid
end

-- Setup player character initialization
local function onCharacterAdded(player: Player, character: Instance)
	local targetModel: Model? = nil
	if CharacterSetup and CharacterSetup.RepairBrokenCharacter then
		local success, repaired = pcall(function()
			return CharacterSetup.RepairBrokenCharacter(player, character)
		end)
		if success and repaired and repaired:IsA("Model") then
			targetModel = repaired
		end
	end

	if not targetModel and character and character:IsA("Model") then
		targetModel = character
	end

	if not targetModel then
		warn("[CombatInit] Character could not be resolved as a valid Model for " .. player.Name)
		return
	end

	local humanoid = targetModel:WaitForChild("Humanoid", 10) :: Humanoid?
	local hrp = targetModel:WaitForChild("HumanoidRootPart", 10) :: BasePart?

	if not humanoid or not hrp then
		return
	end

	-- Apply Goku character appearance, rig validation, and skin
	if CharacterSetup and CharacterSetup.SetupGoku then
		pcall(function()
			CharacterSetup.SetupGoku(targetModel)
		end)
	end

	-- Configure default combat attributes
	targetModel:SetAttribute("Rage", 0)
	targetModel:SetAttribute("IsBlocking", false)
	targetModel:SetAttribute("IsStunned", false)
	targetModel:SetAttribute("IsRagdolled", false)
	targetModel:SetAttribute("iFrames", false)
	targetModel:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)

	-- Pre-initialize ragdoll constraints if helper available
	if RagdollHelper and RagdollHelper.SetupRig then
		pcall(function()
			RagdollHelper.SetupRig(targetModel)
		end)
	end

	-- Cleanup on humanoid death
	humanoid.Died:Connect(function()
		targetModel:SetAttribute("IsBlocking", false)
		targetModel:SetAttribute("IsStunned", false)
		targetModel:SetAttribute("iFrames", false)
		CooldownManager.ResetAll(player)
	end)
end

local function onPlayerAdded(player: Player)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	CooldownManager.OnPlayerRemoving(player)
end)

-- Execute Awakening Transformation Sequence
local function handleAwakening(player: Player)
	local character = player.Character
	local canAct, humanoid = isCharacterAliveAndActive(character)
	if not canAct or not character or not humanoid then
		return
	end

	-- Check Rage requirement
	local currentRage = character:GetAttribute("Rage") or 0
	if currentRage < 100 then
		return -- Not enough rage
	end

	-- Check Awakening cooldown
	if CooldownManager.IsOnCooldown(player, "Awakening") then
		return
	end

	-- If SkillServer provides custom Awakening logic, delegate to it
	if SkillServer and SkillServer.ExecuteAwakening then
		local success, handled = pcall(function()
			return SkillServer.ExecuteAwakening(player)
		end)
		if success and handled then
			return
		end
	end

	-- Default authoritative Awakening execution:
	character:SetAttribute("IsAwakened", true)
	character:SetAttribute("Rage", 0)
	CooldownManager.SetAwakening(player, true, 0.30)

	local origSpeed = character:GetAttribute("OriginalWalkSpeed") or 16
	humanoid.WalkSpeed = 24.0 -- Speed buff in Awakening

	-- Notify all clients
	SkillEvent:FireAllClients("AwakeningState", {
		Player = player,
		Character = character,
		Active = true,
		Duration = 30.0,
	})

	-- Awakening duration timer (30 seconds)
	task.delay(30.0, function()
		if player and player.Parent and character and character.Parent then
			character:SetAttribute("IsAwakened", false)
			CooldownManager.SetAwakening(player, false)
			local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
			if currentHumanoid and currentHumanoid.Health > 0 and not character:GetAttribute("IsStunned") then
				currentHumanoid.WalkSpeed = origSpeed
			end

			-- Set 60s cooldown on re-awakening
			CooldownManager.SetCooldown(player, "Awakening", 60.0)

			SkillEvent:FireAllClients("AwakeningState", {
				Player = player,
				Character = character,
				Active = false,
			})
		end
	end)
end

-- Handle Skill Cast Request
local function handleSkillCast(player: Player, skillId: number)
	if typeof(skillId) ~= "number" or skillId < 1 or skillId > 4 then
		return
	end

	local character = player.Character
	local canAct, _ = isCharacterAliveAndActive(character)
	if not canAct or not character then
		return
	end

	local skillKey = "Skill_" .. tostring(skillId)
	if CooldownManager.IsOnCooldown(player, skillKey) then
		return
	end

	-- Delegate to SkillServer if available
	if SkillServer and SkillServer.ExecuteSkill then
		local success, handled = pcall(function()
			return SkillServer.ExecuteSkill(player, skillId)
		end)
		if success and handled then
			return
		end
	end

	-- Fallback server skill handler using MovesetData
	if MovesetData then
		local isAwakened = CooldownManager.IsAwakened(player)
		local skillConfig = MovesetData.GetSkill(skillId, isAwakened)
		if skillConfig then
			-- Apply cooldown
			local cd = CooldownManager.SetCooldown(player, skillKey, skillConfig.Cooldown)

			-- Notify clients for cooldown HUD and VFX
			SkillEvent:FireAllClients("SkillFired", {
				Player = player,
				Character = character,
				SkillId = skillId,
				SkillName = skillConfig.Name,
				Cooldown = cd,
				IsAwakened = isAwakened,
			})

			-- Destructible integration on AOE skills
			if skillConfig.DestroysEnvironment and DestructibleManager and DestructibleManager.ExplodeGround then
				local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					pcall(function()
						DestructibleManager.ExplodeGround(hrp.Position, skillConfig.AoeRadius or 18, 50)
					end)
				end
			end
		end
	end
end

-- Initialize CharacterSetup
if CharacterSetup and CharacterSetup.Init then
	pcall(function()
		CharacterSetup.Init()
	end)
end

-- SkillServer is the authoritative handler for SkillEvent (CastSkill and Awakening).
-- Ensure SkillServer is initialized if not already running.
if SkillServer and SkillServer.Init then
	pcall(function()
		SkillServer.Init()
	end)
end

-- Destructible Manager initialization if applicable
if DestructibleManager and DestructibleManager.Init then
	pcall(function()
		DestructibleManager.Init()
	end)
end

print("[CombatInit] Server combat architecture initialized successfully.")
