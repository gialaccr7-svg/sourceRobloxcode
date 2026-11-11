--!strict
-- SkillServer.luau
-- Authoritative server execution for Saitama R15 martial arts moveset:
-- Skill 1: Consecutive Punches / Rush Attack (12 rapid punches, hitstuns, finisher knockback)
-- Skill 2: Heavy Punch (Windup punch, Guard Break property, massive knockback & ragdoll)
-- Skill 3: Ground Slam (Jump & ground slam, 18-stud AOE knockup stun, triggers environment destruction)
-- Skill 4: Counter / Flash Dash (0.8s counter stance; counter punish if attacked, flash dash if untouched)
-- Awakening (Key G): Serious Mode, 2s transformation, speed buff, 30% CDR, 1.5x dmg, upgrades skills

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Dynamic references with fallback
local Modules = ReplicatedStorage:WaitForChild("Modules", 5) :: Folder?
local MovesetData
if Modules and Modules:FindFirstChild("MovesetData") then
	MovesetData = require(Modules:WaitForChild("MovesetData"))
else
	MovesetData = require(script.Parent.Parent.Parent.ReplicatedStorage.Modules.MovesetData)
end

local AnimationManager
if Modules and Modules:FindFirstChild("AnimationManager") then
	AnimationManager = require(Modules:WaitForChild("AnimationManager"))
else
	AnimationManager = require(script.Parent.Parent.Parent.ReplicatedStorage.Modules.AnimationManager)
end

local CombatConfig
if Modules and Modules:FindFirstChild("CombatConfig") then
	CombatConfig = require(Modules:WaitForChild("CombatConfig"))
else
	CombatConfig = require(script.Parent.Parent.Parent.ReplicatedStorage.Modules.CombatConfig)
end

-- Optional Server Module requirements with safe pcall/fallback
local function getRagdollServer()
	local combatServerFolder = script.Parent
	local rServer = combatServerFolder:FindFirstChild("RagdollServer")
	if rServer and rServer:IsA("ModuleScript") then
		local s, res = pcall(require, rServer)
		if s then return res end
	end
	return nil
end

local function getHitboxManager()
	local combatServerFolder = script.Parent
	local hb = combatServerFolder:FindFirstChild("HitboxManager")
	if hb and hb:IsA("ModuleScript") then
		local s, res = pcall(require, hb)
		if s then return res end
	end
	return nil
end

local function getDestructibleManager()
	local combatServerFolder = script.Parent
	local dm = combatServerFolder:FindFirstChild("DestructibleManager")
	if dm and dm:IsA("ModuleScript") then
		local s, res = pcall(require, dm)
		if s then return res end
	end
	return nil
end

local function getCooldownManager()
	local sss = script.Parent.Parent
	local cm = sss:FindFirstChild("CooldownManager")
	if cm and cm:IsA("ModuleScript") then
		local s, res = pcall(require, cm)
		if s then return res end
	end
	return nil
end

-- Fallback internal cooldown tracking
local internalCooldowns: { [Player]: { [string]: number } } = {}

-- Awakening active timers tracking
local awakenedPlayers: { [Player]: { EndTime: number, CleanUp: () -> () } } = {}

-- Active counter stances tracking: [VictimModel] = { Player = Player, Expiry = number, Punish = () -> () }
local activeCounters: { [Model]: { Player: Player, Expiry: number, Punish: (attackerChar: Model) -> () } } = {}

local SkillServer = {}

--------------------------------------------------------------------------------
-- REMOTE EVENT HELPERS
--------------------------------------------------------------------------------

local function getRemotesFolder(): Folder
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	return remotes
end

local function getSkillEvent(): RemoteEvent
	local folder = getRemotesFolder()
	local event = folder:FindFirstChild("SkillEvent") :: RemoteEvent?
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "SkillEvent"
		event.Parent = folder
	end
	return event
end

local function getCombatEvent(): RemoteEvent?
	local folder = getRemotesFolder()
	return folder:FindFirstChild("CombatEvent") :: RemoteEvent?
end

local function getBlockEvent(): RemoteEvent?
	local folder = getRemotesFolder()
	return folder:FindFirstChild("BlockEvent") :: RemoteEvent?
end

--------------------------------------------------------------------------------
-- COOLDOWN HELPERS
--------------------------------------------------------------------------------

local function isPlayerOnCooldown(player: Player, actionKey: string): boolean
	local cm = getCooldownManager()
	if cm and cm.IsOnCooldown then
		return cm.IsOnCooldown(player, actionKey)
	end

	local pTable = internalCooldowns[player]
	if not pTable then return false end
	local expiry = pTable[actionKey]
	return expiry ~= nil and os.clock() < expiry
end

local function setPlayerCooldown(player: Player, actionKey: string, duration: number, skillId: number?)
	local cm = getCooldownManager()
	local appliedDuration = duration

	local parsedId = skillId or tonumber(string.match(actionKey, "%d+"))
	local skillConfig = parsedId and MovesetData.GetSkill(parsedId, false)
	local baseDuration = (skillConfig and skillConfig.Cooldown) or duration

	if cm and cm.SetCooldown then
		appliedDuration = cm.SetCooldown(player, actionKey, baseDuration)
	else
		if not internalCooldowns[player] then
			internalCooldowns[player] = {}
		end
		internalCooldowns[player][actionKey] = os.clock() + duration
	end

	-- Notify client HUD of cooldown
	local skillEvent = getSkillEvent()
	skillEvent:FireClient(player, "SkillCooldown", {
		SkillId = parsedId,
		ActionKey = actionKey,
		Duration = appliedDuration,
	})
end

--------------------------------------------------------------------------------
-- HITBOX & SPATIAL QUERY HELPERS
--------------------------------------------------------------------------------

-- Finds all eligible enemy Character models within an Oriented Bounding Box
local function queryBoxTargets(originCFrame: CFrame, boxSize: Vector3, ignoreModel: Model): { Model }
	local hm = getHitboxManager()
	if hm and hm.GetTargetsInBox then
		local s, res = pcall(hm.GetTargetsInBox, originCFrame, boxSize, ignoreModel)
		if s and type(res) == "table" then
			return res
		end
	end

	-- Native Roblox Spatial Query Fallback
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { ignoreModel }
	overlap.CollisionGroup = "Default"

	local parts = Workspace:GetPartBoundsInBox(originCFrame, boxSize, overlap)
	local hitModels: { [Model]: boolean } = {}
	local results: { Model } = {}

	for _, part in ipairs(parts) do
		local char = part:FindFirstAncestorOfClass("Model")
		if char and not hitModels[char] then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and root and char ~= ignoreModel then
				hitModels[char] = true
				table.insert(results, char)
			end
		end
	end

	return results
end

-- Finds all eligible enemy Character models within a spherical radius
local function queryRadiusTargets(centerPosition: Vector3, radius: number, ignoreModel: Model): { Model }
	local hm = getHitboxManager()
	if hm and hm.GetTargetsInRadius then
		local s, res = pcall(hm.GetTargetsInRadius, centerPosition, radius, ignoreModel)
		if s and type(res) == "table" then
			return res
		end
	end

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { ignoreModel }

	local parts = Workspace:GetPartBoundsInRadius(centerPosition, radius, overlap)
	local hitModels: { [Model]: boolean } = {}
	local results: { Model } = {}

	for _, part in ipairs(parts) do
		local char = part:FindFirstAncestorOfClass("Model")
		if char and not hitModels[char] then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and char ~= ignoreModel then
				hitModels[char] = true
				table.insert(results, char)
			end
		end
	end

	return results
end

--------------------------------------------------------------------------------
-- DAMAGE, KNOCKBACK & STATE APPLICATION
--------------------------------------------------------------------------------

local function applyDamage(attackerPlayer: Player?, victimChar: Model, rawDamage: number, isGuardBreak: boolean?): (number, boolean)
	local humanoid = victimChar:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return 0, false
	end

	-- Check invulnerability / i-frames
	if victimChar:GetAttribute("iFrames") == true then
		return 0, false
	end

	-- Check active Counter stance
	if SkillServer.CheckCounter(victimChar, attackerPlayer and attackerPlayer.Character) then
		return 0, false
	end

	local isBlocking = victimChar:GetAttribute("IsBlocking") == true
	local finalDamage = rawDamage
	local guardBroken = false

	if isBlocking then
		if isGuardBreak then
			-- Heavy attacks shatter block (Guard Break)
			guardBroken = true
			victimChar:SetAttribute("IsBlocking", false)
			victimChar:SetAttribute("GuardBroken", true)
			victimChar:SetAttribute("IsStunned", true)

			-- Notify client block broken
			local blockEvent = getBlockEvent()
			if blockEvent then
				blockEvent:FireAllClients(victimChar, false, true)
			end

			-- Reset stun after posture break duration
			task.delay(CombatConfig.GuardBreakStun, function()
				if victimChar and victimChar.Parent then
					victimChar:SetAttribute("GuardBroken", false)
					victimChar:SetAttribute("IsStunned", false)
				end
			end)
		else
			-- Normal block reduction
			finalDamage = rawDamage * (1 - CombatConfig.BlockDamageReduction)
		end
	end

	humanoid:TakeDamage(finalDamage)

	-- Rage / Ultimate Meter Building
	if attackerPlayer and attackerPlayer.Character then
		local currentRage = attackerPlayer.Character:GetAttribute("Rage") or 0
		local gain = CombatConfig.RageGainOnHit * (rawDamage / 10)
		attackerPlayer.Character:SetAttribute("Rage", math.clamp(currentRage + gain, 0, 100))
	end

	local victimPlayer = Players:GetPlayerFromCharacter(victimChar)
	if victimPlayer and victimChar then
		local currentRage = victimChar:GetAttribute("Rage") or 0
		local gain = CombatConfig.RageGainOnDamageTaken * (finalDamage / 10)
		victimChar:SetAttribute("Rage", math.clamp(currentRage + gain, 0, 100))
	end

	-- Notify clients for floating damage pop-up billboard
	local combatEvent = getCombatEvent()
	if combatEvent then
		combatEvent:FireAllClients("DamageDealt", {
			Target = victimChar,
			Damage = math.round(finalDamage),
			IsGuardBreak = guardBroken,
			IsCritical = guardBroken or rawDamage >= 30,
		})
	end

	return finalDamage, guardBroken
end

local function applyKnockback(targetChar: Model, directionVelocity: Vector3, ragdollDuration: number?)
	local root = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	-- Apply physical velocity impulse
	local attachment = Instance.new("Attachment")
	attachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.MaxForce = math.huge
	linearVelocity.VectorVelocity = directionVelocity
	linearVelocity.Attachment0 = attachment
	linearVelocity.Parent = root

	Debris:AddItem(linearVelocity, 0.18)
	Debris:AddItem(attachment, 0.18)

	-- Activate ragdoll if duration specified
	if ragdollDuration and ragdollDuration > 0 then
		local rs = getRagdollServer()
		if rs and rs.RagdollCharacter then
			rs.RagdollCharacter(targetChar, ragdollDuration)
		else
			-- Fallback ragdoll attribute
			targetChar:SetAttribute("IsRagdolled", true)
			task.delay(ragdollDuration, function()
				if targetChar and targetChar.Parent then
					targetChar:SetAttribute("IsRagdolled", false)
				end
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- SKILL 1: CONSECUTIVE PUNCHES / RUSH ATTACK
--------------------------------------------------------------------------------

local function executeRushAttack(player: Player, character: Model, isAwakened: boolean)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end

	local skillConfig = MovesetData.GetSkill(1, isAwakened)
	if not skillConfig then return end

	local hitCount = skillConfig.HitCount or 12
	local hitInterval = skillConfig.HitInterval or 0.11
	local damagePerHit = skillConfig.Damage
	local finisherDamage = skillConfig.FinisherDamage or 8.0
	local finisherKnockback = skillConfig.FinisherKnockback or 38.0
	local finisherLift = skillConfig.FinisherLift or 6.0

	-- Slightly slow attacker during rush flurry
	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 6.0
	character:SetAttribute("IsAttacking", true)

	-- Broadcast animation and initial SFX
	local skillEvent = getSkillEvent()
	skillEvent:FireAllClients("SkillVFX", {
		SkillId = 1,
		Action = "RushStart",
		Attacker = character,
		IsAwakened = isAwakened,
	})

	AnimationManager.PlayAnimation(character, skillConfig.AnimationName)

	task.spawn(function()
		local hitVictims: { [Model]: boolean } = {}

		for tickIndex = 1, hitCount do
			if not character.Parent or humanoid.Health <= 0 then
				break
			end

			local hitboxCFrame = root.CFrame * CFrame.new(skillConfig.HitboxOffset)
			local targets = queryBoxTargets(hitboxCFrame, skillConfig.HitboxSize, character)

			for _, target in ipairs(targets) do
				hitVictims[target] = true
				applyDamage(player, target, damagePerHit, false)

				-- Pull and hold target in front of attacker during flurry
				local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
				if targetRoot then
					local holdPos = root.Position + (root.CFrame.LookVector * 4.0)
					targetRoot.CFrame = CFrame.lookAt(Vector3.new(holdPos.X, targetRoot.Position.Y, holdPos.Z), root.Position)
				end

				target:SetAttribute("IsStunned", true)
				task.delay(skillConfig.HitstunDuration, function()
					if target and target.Parent then
						target:SetAttribute("IsStunned", false)
					end
				end)
			end

			skillEvent:FireAllClients("SkillVFX", {
				SkillId = 1,
				Action = "RushTick",
				Attacker = character,
				TickIndex = tickIndex,
				IsAwakened = isAwakened,
			})

			task.wait(hitInterval)
		end

		-- Finisher Punch
		if character.Parent and humanoid.Health > 0 then
			local finisherCFrame = root.CFrame * CFrame.new(skillConfig.HitboxOffset)
			local finalTargets = queryBoxTargets(finisherCFrame, skillConfig.HitboxSize, character)

			for _, target in ipairs(finalTargets) do
				applyDamage(player, target, finisherDamage, false)

				local launchDir = (root.CFrame.LookVector * finisherKnockback) + Vector3.new(0, finisherLift, 0)
				applyKnockback(target, launchDir, isAwakened and 1.5 or 0.8)
			end

			skillEvent:FireAllClients("SkillVFX", {
				SkillId = 1,
				Action = "RushFinisher",
				Attacker = character,
				IsAwakened = isAwakened,
			})
		end

		-- Reset movement
		if humanoid and humanoid.Parent then
			if isAwakened then
				humanoid.WalkSpeed = MovesetData.AwakeningConfig.WalkSpeedBuff
			else
				humanoid.WalkSpeed = 16.0
			end
		end
		character:SetAttribute("IsAttacking", false)
	end)
end

--------------------------------------------------------------------------------
-- SKILL 2: KAMEHAMEHA / HEAVY PUNCH (BEAM BLAST, GUARD BREAK & WALL SPLAT)
--------------------------------------------------------------------------------

local function executeHeavyPunch(player: Player, character: Model, isAwakened: boolean)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end

	local skillConfig = MovesetData.GetSkill(2, isAwakened)
	if not skillConfig then return end

	character:SetAttribute("IsAttacking", true)
	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 2.0

	local skillEvent = getSkillEvent()
	skillEvent:FireAllClients("SkillVFX", {
		SkillId = 2,
		Action = "HeavyPunchWindup",
		Attacker = character,
		IsAwakened = isAwakened,
	})

	AnimationManager.PlayAnimation(character, skillConfig.AnimationName)

	-- Windup delay (charging Ki orb at hip)
	task.delay(skillConfig.WindupTime, function()
		if not character.Parent or humanoid.Health <= 0 then
			character:SetAttribute("IsAttacking", false)
			return
		end

		local punchCFrame = root.CFrame * CFrame.new(skillConfig.HitboxOffset)
		local targets = queryBoxTargets(punchCFrame, skillConfig.HitboxSize, character)

		for _, target in ipairs(targets) do
			local dmg, guardBroken = applyDamage(player, target, skillConfig.Damage, skillConfig.GuardBreak)

			local knockVelocity = (root.CFrame.LookVector * skillConfig.KnockbackForce) + Vector3.new(0, skillConfig.KnockbackLift, 0)
			local ragdollDur = 1.8
			if isAwakened then
				ragdollDur = 2.2
			end
			applyKnockback(target, knockVelocity, ragdollDur)
		end

		-- Trigger Destructible Environment along beam corridor
		if skillConfig.DestroysEnvironment then
			local dm = getDestructibleManager()
			if dm then
				if dm.BreakInRadius then
					local beamCenter = root.Position + (root.CFrame.LookVector * 24.0)
					dm.BreakInRadius(beamCenter, 16.0, skillConfig.KnockbackForce)
				end
				if dm.BreakObstaclesInBox then
					dm.BreakObstaclesInBox(punchCFrame, skillConfig.HitboxSize, root.CFrame.LookVector * skillConfig.KnockbackForce)
				end
			end
		end

		-- Broadcast Kamehameha beam & impact visual effects
		skillEvent:FireAllClients("SkillVFX", {
			SkillId = 2,
			Action = "KamehamehaBeam",
			Attacker = character,
			IsAwakened = isAwakened,
			ImpactCFrame = punchCFrame,
		})

		skillEvent:FireAllClients("SkillVFX", {
			SkillId = 2,
			Action = "HeavyPunchImpact",
			Attacker = character,
			IsAwakened = isAwakened,
			ImpactCFrame = punchCFrame,
		})

		task.wait(0.35)
		if humanoid and humanoid.Parent then
			if isAwakened then
				humanoid.WalkSpeed = MovesetData.AwakeningConfig.WalkSpeedBuff
			else
				humanoid.WalkSpeed = 16.0
			end
		end
		character:SetAttribute("IsAttacking", false)
	end)
end

--------------------------------------------------------------------------------
-- SKILL 3: KAIOKEN / GROUND SLAM (AOE KNOCKUP & DESTRUCTION)
--------------------------------------------------------------------------------

local function executeGroundSlam(player: Player, character: Model, isAwakened: boolean)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end

	local skillConfig = MovesetData.GetSkill(3, isAwakened)
	if not skillConfig then return end

	character:SetAttribute("IsAttacking", true)
	humanoid.WalkSpeed = 0

	local restored = false
	local function restoreSpeed()
		if restored then return end
		restored = true

		if humanoid and humanoid.Parent and humanoid.Health > 0 then
			if isAwakened or character:GetAttribute("IsAwakened") == true then
				humanoid.WalkSpeed = MovesetData.AwakeningConfig.WalkSpeedBuff
			else
				humanoid.WalkSpeed = 16.0
			end
		end
		if character and character.Parent then
			character:SetAttribute("IsAttacking", false)
		end
	end

	-- Watchdog Timer: Guarantees WalkSpeed is restored and IsAttacking cleared after at most 1.5s even on error
	task.delay(1.5, restoreSpeed)

	local skillEvent = getSkillEvent()
	if skillEvent then
		skillEvent:FireAllClients("SkillVFX", {
			SkillId = 3,
			Action = "KaiokenBurst",
			Attacker = character,
			IsAwakened = isAwakened,
		})

		skillEvent:FireAllClients("SkillVFX", {
			SkillId = 3,
			Action = "GroundSlamLeap",
			Attacker = character,
			IsAwakened = isAwakened,
		})
	end

	pcall(function()
		AnimationManager.PlayAnimation(character, skillConfig.AnimationName)
	end)

	-- Jump upward impulse
	root.AssemblyLinearVelocity = Vector3.new(0, 32, 0)

	task.delay(skillConfig.WindupTime, function()
		if not character.Parent or humanoid.Health <= 0 then
			restoreSpeed()
			return
		end

		-- Slam downward violently
		root.AssemblyLinearVelocity = Vector3.new(0, -60, 0)
		task.wait(0.12)

		local impactPosition = root.Position - Vector3.new(0, 2.8, 0)
		local aoeRadius = skillConfig.AoeRadius or 18.0
		local targets = queryRadiusTargets(impactPosition, aoeRadius, character)

		for _, target in ipairs(targets) do
			applyDamage(player, target, skillConfig.Damage, false)

			local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
			if targetRoot then
				local radialDir = (targetRoot.Position - impactPosition).Unit
				if radialDir.Magnitude == 0 or radialDir ~= radialDir then
					radialDir = root.CFrame.LookVector
				end
				local knockVelocity = (radialDir * skillConfig.KnockbackForce) + Vector3.new(0, skillConfig.KnockbackLift, 0)
				applyKnockback(target, knockVelocity, 1.5)
			end
		end

		-- Destructible Environment fracture wrapped in pcall
		pcall(function()
			local dm = getDestructibleManager()
			if dm then
				if dm.ExplodeGround then
					pcall(dm.ExplodeGround, impactPosition, aoeRadius)
				elseif dm.BreakInRadius then
					pcall(dm.BreakInRadius, impactPosition, aoeRadius, skillConfig.KnockbackForce)
				end
			end
		end)

		if skillEvent then
			skillEvent:FireAllClients("SkillVFX", {
				SkillId = 3,
				Action = "GroundSlamImpact",
				Attacker = character,
				ImpactPosition = impactPosition,
				Radius = aoeRadius,
				IsAwakened = isAwakened,
			})
		end

		task.wait(0.35)
		restoreSpeed()
	end)
end

--------------------------------------------------------------------------------
-- SKILL 4: INSTANT TRANSMISSION / SPIRIT BOMB (COUNTER / FLASH DASH)
--------------------------------------------------------------------------------

local function executeCounter(player: Player, character: Model, isAwakened: boolean)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end

	local skillConfig = MovesetData.GetSkill(4, isAwakened)
	if not skillConfig then return end

	character:SetAttribute("IsAttacking", true)

	local skillEvent = getSkillEvent()

	-- Awakening Variant: Spirit Bomb (Massive AOE Gathering & Throw)
	if isAwakened then
		humanoid.WalkSpeed = 0
		root.AssemblyLinearVelocity = Vector3.new(0, 20, 0)

		skillEvent:FireAllClients("SkillVFX", {
			SkillId = 4,
			Action = "SpiritBombStart",
			Attacker = character,
			IsAwakened = true,
		})

		AnimationManager.PlayAnimation(character, "SpiritBomb")

		-- Watchdog Timer: Guarantees WalkSpeed restored and IsAttacking cleared after at most 1.5s
		task.delay(1.5, function()
			if character and character.Parent then
				character:SetAttribute("IsAttacking", false)
				if humanoid and humanoid.Parent and humanoid.Health > 0 and humanoid.WalkSpeed == 0 then
					humanoid.WalkSpeed = MovesetData.AwakeningConfig.WalkSpeedBuff
				end
			end
		end)

		task.delay(0.55, function()
			if not character.Parent or humanoid.Health <= 0 then
				character:SetAttribute("IsAttacking", false)
				return
			end

			local bombTargetPos = root.Position + (root.CFrame.LookVector * 28.0)
			local bombRadius = 26.0
   -- Charge ends at .55; the visible projectile takes .35 to arrive.
   task.wait(0.35)
   if not character.Parent or humanoid.Health <= 0 or character:GetAttribute("IsRagdolled") then return end
			local targets = queryRadiusTargets(bombTargetPos, bombRadius, character)

			for _, target in ipairs(targets) do
				applyDamage(player, target, skillConfig.Damage, true)

				local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
				if targetRoot then
					local knockDir = (targetRoot.Position - bombTargetPos).Unit
					if knockDir.Magnitude == 0 or knockDir ~= knockDir then
						knockDir = root.CFrame.LookVector
					end
					local knockVel = (knockDir * skillConfig.KnockbackForce) + Vector3.new(0, skillConfig.KnockbackLift, 0)
					applyKnockback(target, knockVel, 2.0)
				end
			end

			pcall(function()
				local dm = getDestructibleManager()
				if dm then
					if dm.ExplodeGround then
						pcall(dm.ExplodeGround, bombTargetPos, bombRadius)
					elseif dm.BreakInRadius then
						pcall(dm.BreakInRadius, bombTargetPos, bombRadius, skillConfig.KnockbackForce)
					end
				end
			end)

			skillEvent:FireAllClients("SkillVFX", {
				SkillId = 4,
				Action = "GroundSlamImpact",
				Attacker = character,
				ImpactPosition = bombTargetPos,
				Radius = bombRadius,
				IsAwakened = true,
			})

			task.wait(0.35)
			if humanoid and humanoid.Parent then
				humanoid.WalkSpeed = MovesetData.AwakeningConfig.WalkSpeedBuff
			end
			character:SetAttribute("IsAttacking", false)
		end)
		return
	end

	-- Base Variant: Instant Transmission (Teleport behind target + Heavy strike)
	character:SetAttribute("IsCountering", true)
	humanoid.WalkSpeed = 4.0

	local counterWindow = skillConfig.CounterWindow or 0.8
	local wasAttacked = false

	skillEvent:FireAllClients("SkillVFX", {
		SkillId = 4,
		Action = "CounterStance",
		Attacker = character,
		IsAwakened = isAwakened,
	})

	AnimationManager.PlayAnimation(character, skillConfig.AnimationName)

	-- Find closest enemy in front/nearby for Instant Transmission teleport
	local closestEnemy: Model? = nil
	local closestDist = 45.0
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			local eChar = otherPlayer.Character
			local eHum = eChar:FindFirstChildOfClass("Humanoid")
			local eRoot = eChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if eHum and eHum.Health > 0 and eRoot then
				local dist = (eRoot.Position - root.Position).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestEnemy = eChar
				end
			end
		end
	end

	-- Register counter punish callback
	local counterEntry = {
		Player = player,
		Expiry = os.clock() + counterWindow,
		Punish = function(attackerChar: Model)
			if wasAttacked then return end
			wasAttacked = true

			character:SetAttribute("IsCountering", false)
			activeCounters[character] = nil

			-- Teleport behind attacker
			local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if attackerRoot and root then
				local behindPos = attackerRoot.Position - (attackerRoot.CFrame.LookVector * 3.5)
				root.CFrame = CFrame.lookAt(behindPos, attackerRoot.Position)
			end

			-- Counter Punish Strike
			AnimationManager.PlayAnimation(character, "CounterPunish")
			local punishDmg = skillConfig.CounterPunishDamage or 35.0
			applyDamage(player, attackerChar, punishDmg, true)

			local knockVelocity = (root.CFrame.LookVector * skillConfig.KnockbackForce) + Vector3.new(0, skillConfig.KnockbackLift, 0)
			applyKnockback(attackerChar, knockVelocity, 1.4)

			skillEvent:FireAllClients("SkillVFX", {
				SkillId = 4,
				Action = "CounterTriggered",
				Attacker = character,
				Victim = attackerChar,
				IsAwakened = isAwakened,
			})

			humanoid.WalkSpeed = 16.0
			character:SetAttribute("IsAttacking", false)
		end,
	}

	activeCounters[character] = counterEntry

	-- Counter stance watchdog failsafe: ensures IsCountering, IsAttacking and WalkSpeed are safely reset even on error/interruption
	task.delay(counterWindow + 0.4, function()
		if activeCounters[character] == counterEntry then
			activeCounters[character] = nil
		end
		if character and character.Parent then
			if character:GetAttribute("IsCountering") == true then
				character:SetAttribute("IsCountering", false)
			end
			if character:GetAttribute("IsAttacking") == true and not wasAttacked then
				character:SetAttribute("IsAttacking", false)
				if humanoid and humanoid.Parent and humanoid.Health > 0 then
					humanoid.WalkSpeed = 16.0
				end
			end
		end
	end)

	-- If an enemy is in range, execute instant transmission teleport strike after brief vanish
	task.delay(0.18, function()
		if wasAttacked or not character.Parent or humanoid.Health <= 0 then
			character:SetAttribute("IsCountering", false)
			activeCounters[character] = nil
			return
		end

		if closestEnemy and closestEnemy.Parent then
			local eRoot = closestEnemy:FindFirstChild("HumanoidRootPart") :: BasePart?
			if eRoot then
				wasAttacked = true
				character:SetAttribute("IsCountering", false)
				activeCounters[character] = nil

				-- Teleport behind target
				local behindPos = eRoot.Position - (eRoot.CFrame.LookVector * 3.5)
				root.CFrame = CFrame.lookAt(behindPos, eRoot.Position)

				AnimationManager.PlayAnimation(character, "CounterPunish")
				applyDamage(player, closestEnemy, skillConfig.Damage, true)

				local knockVel = (root.CFrame.LookVector * skillConfig.KnockbackForce) + Vector3.new(0, skillConfig.KnockbackLift, 0)
				applyKnockback(closestEnemy, knockVel, 1.4)

				skillEvent:FireAllClients("SkillVFX", {
					SkillId = 4,
					Action = "InstantTransmissionFlash",
					Attacker = character,
					Victim = closestEnemy,
					IsAwakened = false,
				})

				task.wait(0.25)
				humanoid.WalkSpeed = 16.0
				character:SetAttribute("IsAttacking", false)
				return
			end
		end

		-- If no enemy, execute Flash Dash forward after counter window
		task.delay(counterWindow - 0.18, function()
			if wasAttacked or not character.Parent or humanoid.Health <= 0 then
				character:SetAttribute("IsCountering", false)
				activeCounters[character] = nil
				character:SetAttribute("IsAttacking", false)
				return
			end

			character:SetAttribute("IsCountering", false)
			activeCounters[character] = nil

			local dashDist = skillConfig.FlashDashDistance or 35.0
			local dashDuration = skillConfig.FlashDashDuration or 0.20

			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			rayParams.FilterDescendantsInstances = { character }

			local rayResult = Workspace:Raycast(root.Position, root.CFrame.LookVector * dashDist, rayParams)
			local targetPos = root.Position + (root.CFrame.LookVector * dashDist)
			if rayResult then
				targetPos = rayResult.Position - (root.CFrame.LookVector * 2.0)
			end

			character:SetAttribute("iFrames", true)
			AnimationManager.PlayAnimation(character, "FlashDash")

			local tweenInfo = TweenInfo.new(dashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = game:GetService("TweenService"):Create(root, tweenInfo, { CFrame = CFrame.lookAt(targetPos, targetPos + root.CFrame.LookVector) })
			tween:Play()

			skillEvent:FireAllClients("SkillVFX", {
				SkillId = 4,
				Action = "FlashDash",
				Attacker = character,
				StartPos = root.Position,
				EndPos = targetPos,
				IsAwakened = isAwakened,
			})

			task.wait(dashDuration)
			character:SetAttribute("iFrames", false)
			if humanoid and humanoid.Parent then
				humanoid.WalkSpeed = 16.0
			end
			character:SetAttribute("IsAttacking", false)
		end)
	end)
end

--------------------------------------------------------------------------------
-- AWAKENING / ULTIMATE (KEY G)
--------------------------------------------------------------------------------

function SkillServer.ActivateAwakening(player: Player): boolean
	local character = player.Character
	if not character then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then return false end

	-- Check if already awakened
	if character:GetAttribute("IsAwakened") == true then
		return false
	end

	-- Check Rage meter requirement (100%)
	local currentRage = (character and character:GetAttribute("Rage")) or 0
	if currentRage < MovesetData.AwakeningConfig.RequiredRageMeter then
		return false
	end

	-- Consume Rage meter
	if character then
		character:SetAttribute("Rage", 0)
	end

	local config = MovesetData.AwakeningConfig

	-- Configure CooldownManager CDR modifier
	local cm = getCooldownManager()
	if cm and cm.SetAwakening then
		cm.SetAwakening(player, true, config.CooldownReduction)
	end

	-- Cinematic 2.0s transformation lock + i-frames
	character:SetAttribute("IsAwakened", true)
	character:SetAttribute("iFrames", true)
	character:SetAttribute("IsAttacking", true)
	humanoid.WalkSpeed = 0

	local skillEvent = getSkillEvent()
	skillEvent:FireAllClients("SkillVFX", {
		Action = "AwakeningTransform",
		Attacker = character,
		Duration = config.TransformationDuration,
		AuraColor = config.AuraColor,
	})

	AnimationManager.PlayAnimation(character, config.AnimationName)

	-- Apply Awakening state after transformation completes
	task.delay(config.TransformationDuration, function()
		if not character.Parent or humanoid.Health <= 0 then
			return
		end

		character:SetAttribute("iFrames", false)
		character:SetAttribute("IsAttacking", false)
		humanoid.WalkSpeed = config.WalkSpeedBuff

		-- Notify client HUD of Awakening active state
		skillEvent:FireAllClients("AwakeningState", {
			Player = player,
			User = character,
			Character = character,
			Active = true,
			IsAwakened = true,
			Duration = config.Duration,
		})

		-- Awakening Expiration Timer
		local cleanupToken = false
		local function revertAwakening()
			if cleanupToken then return end
			cleanupToken = true

			if cm and cm.SetAwakening then
				cm.SetAwakening(player, false)
			end

			awakenedPlayers[player] = nil
			if character and character.Parent then
				character:SetAttribute("IsAwakened", false)
				if humanoid and humanoid.Parent and humanoid.Health > 0 then
					humanoid.WalkSpeed = 16.0
				end
			end

			skillEvent:FireAllClients("AwakeningState", {
				Player = player,
				User = character,
				Character = character,
				Active = false,
				IsAwakened = false,
				Duration = 0,
			})

			skillEvent:FireAllClients("SkillVFX", {
				Action = "AwakeningEnd",
				Attacker = character,
			})
		end

		awakenedPlayers[player] = {
			EndTime = os.clock() + config.Duration,
			CleanUp = revertAwakening,
		}

		task.delay(config.Duration, revertAwakening)
	end)

	return true
end

-- Authoritative alias for CombatInit delegation
function SkillServer.ExecuteAwakening(player: Player): boolean
	return SkillServer.ActivateAwakening(player)
end

-- Adds Rage to a player's character
function SkillServer.AddPlayerRage(player: Player, amount: number): number
	local char = player.Character
	if not char then return 0 end
	local currentRage = char:GetAttribute("Rage") or 0
	local newRage = math.clamp(currentRage + amount, 0, 100)
	char:SetAttribute("Rage", newRage)
	return newRage
end

--------------------------------------------------------------------------------
-- PUBLIC API & REMOTE CONNECTIONS
--------------------------------------------------------------------------------

-- Checks and triggers counter if victim is in active counter stance
function SkillServer.CheckCounter(victimChar: Model, attackerChar: Model?): boolean
	local counter = activeCounters[victimChar]
	if counter and os.clock() <= counter.Expiry then
		if attackerChar then
			counter.Punish(attackerChar)
		end
		return true
	end
	return false
end

-- Checks if a character is currently in Awakening mode
function SkillServer.IsAwakened(character: Model): boolean
	return character:GetAttribute("IsAwakened") == true
end

-- Main entry point to cast a skill (1-4)
function SkillServer.ExecuteSkill(player: Player, skillId: number): boolean
	if skillId % 1 ~= 0 or skillId < 1 or skillId > 4 then return false end
	local character = player.Character
	if not character then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	-- Check character state locks (Stun, Ragdoll, Countering)
	-- Note: IsAttacking is intentionally omitted here to allow skills to chain/cancel normal attacks
	if character:GetAttribute("IsStunned") == true
		or character:GetAttribute("IsRagdolled") == true
		or character:GetAttribute("IsCountering") == true then
		return false
	end

	local isAwakened = character:GetAttribute("IsAwakened") == true
	local actionKey = "Skill_" .. skillId

	-- Check Cooldown
	if isPlayerOnCooldown(player, actionKey) then
		return false
	end

	local cd = MovesetData.GetCooldown(skillId, isAwakened)
	character:SetAttribute("IsBlocking", false)
	setPlayerCooldown(player, actionKey, cd, skillId)

	-- Dispatch corresponding skill
	if skillId == 1 then
		executeRushAttack(player, character, isAwakened)
	elseif skillId == 2 then
		executeHeavyPunch(player, character, isAwakened)
	elseif skillId == 3 then
		executeGroundSlam(player, character, isAwakened)
	elseif skillId == 4 then
		executeCounter(player, character, isAwakened)
	else
		return false
	end

	return true
end

local isInitialized = false

-- Initializes SkillServer and binds Remote listeners
function SkillServer.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	local skillEvent = getSkillEvent()

	skillEvent.OnServerEvent:Connect(function(player, action, ...)
		if action == "CastSkill" then
			local rawId = ...
			local skillId = tonumber(rawId)
			if skillId and skillId >= 1 and skillId <= 4 then
				SkillServer.ExecuteSkill(player, math.floor(skillId))
			end
		elseif action == "Awakening" or action == "ActivateAwakening" then
			SkillServer.ActivateAwakening(player)
		end
	end)

	-- Clean up on player leaving or dying
	Players.PlayerRemoving:Connect(function(player)
		internalCooldowns[player] = nil
		if player.Character then
			activeCounters[player.Character] = nil
		end
		if awakenedPlayers[player] then
			awakenedPlayers[player].CleanUp()
		end
	end)

	local function onCharacterAdded(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(function()
				activeCounters[character] = nil
				character:SetAttribute("IsCountering", false)
				character:SetAttribute("IsAttacking", false)
			end)
		end
	end

	local function onPlayerAdded(player: Player)
		if player.Character then
			onCharacterAdded(player.Character)
		end
		player.CharacterAdded:Connect(onCharacterAdded)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end

-- Auto-initialize if running in Roblox Server environment
if RunService:IsServer() then
	SkillServer.Init()
end

return SkillServer
