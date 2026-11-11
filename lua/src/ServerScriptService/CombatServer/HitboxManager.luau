--!strict
-- HitboxManager.luau
-- Server authority for spatial hitbox verification, M1 combo progression,
-- Block & Guard Break evaluation, Ragdoll knockdown, and Wall Splat mechanics.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local AnimationManager = require(Modules:WaitForChild("AnimationManager"))
local RagdollHelper = require(Modules:WaitForChild("RagdollHelper"))
local RagdollServer = require(script.Parent.RagdollServer)

type PlayerCombatState = {
	ComboStep: number,
	LastAttackTime: number,
	LastDashTime: number,
	IsAttacking: boolean,
	DashCancelActive: boolean,
}

local HitboxManager = {}
local combatStates: { [Player]: PlayerCombatState } = {}

-- Ensure Remotes folder and events exist
local function ensureRemotes(): Folder
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local neededEvents = { "CombatEvent", "BlockEvent", "DashEvent", "SkillEvent" }
	for _, eventName in neededEvents do
		if not remotes:FindFirstChild(eventName) then
			local event = Instance.new("RemoteEvent")
			event.Name = eventName
			event.Parent = remotes
		end
	end

	return remotes
end

local Remotes = ensureRemotes()
local CombatEvent = Remotes:WaitForChild("CombatEvent") :: RemoteEvent
local BlockEvent = Remotes:WaitForChild("BlockEvent") :: RemoteEvent
local DashEvent = Remotes:WaitForChild("DashEvent") :: RemoteEvent

-- Safely retrieves DestructibleManager if initialized by Agent 4
local function getDestructibleManager()
	local combatServerFolder = ServerScriptService:FindFirstChild("CombatServer")
	if combatServerFolder then
		local destModule = combatServerFolder:FindFirstChild("DestructibleManager")
		if destModule and destModule:IsA("ModuleScript") then
			local success, res = pcall(require, destModule)
			if success then
				return res
			end
		end
	end
	return nil
end

-- Retrieves or initializes player combat state
local function getState(player: Player): PlayerCombatState
	local state = combatStates[player]
	if not state then
		state = {
			ComboStep = 1,
			LastAttackTime = 0,
			LastDashTime = 0,
			IsAttacking = false,
			DashCancelActive = false,
		}
		combatStates[player] = state
	end
	return state
end

-- Checks if a character is under crowd control (hitstun, ragdoll, etc.)
function HitboxManager.IsDisabled(character: Model): boolean
	if not character or not character.Parent then
		return true
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return true
	end
	if character:GetAttribute("IsRagdolled") == true then
		return true
	end
	if character:GetAttribute("IsStunned") == true then
		return true
	end
	return false
end

-- Applies hitstun to a character for a duration
function HitboxManager.ApplyHitstun(targetChar: Model, duration: number)
	local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	targetChar:SetAttribute("IsStunned", true)
	local origWalkSpeed = targetChar:GetAttribute("OriginalWalkSpeed")
	if not origWalkSpeed then
		targetChar:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)
	end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	task.delay(duration, function()
		if targetChar and targetChar.Parent and not RagdollHelper.IsRagdolled(targetChar) then
			targetChar:SetAttribute("IsStunned", false)
			local restoredSpeed = targetChar:GetAttribute("OriginalWalkSpeed") or 16
			humanoid.WalkSpeed = restoredSpeed
			humanoid.JumpPower = 50
		end
	end)
end

-- Applies damage and updates Ultimate / Rage meter
function HitboxManager.ApplyDamage(attackerChar: Model, targetChar: Model, damage: number)
	local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid:TakeDamage(damage)

	-- Rage building
	local attackerRage = attackerChar:GetAttribute("Rage") or 0
	attackerChar:SetAttribute("Rage", math.clamp(attackerRage + CombatConfig.RageGainOnHit, 0, 100))

	local targetRage = targetChar:GetAttribute("Rage") or 0
	targetChar:SetAttribute("Rage", math.clamp(targetRage + CombatConfig.RageGainOnDamageTaken, 0, 100))
end

-- Evaluates whether a target is blocking an incoming attack (angle & guard break)
function HitboxManager.EvaluateBlock(attackerChar: Model, targetChar: Model, isGuardBreakAttack: boolean): (boolean, boolean)
	local isBlocking = targetChar:GetAttribute("IsBlocking") == true
	if not isBlocking then
		return false, false -- Not blocking
	end

	local attackerHRP = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetHRP = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not attackerHRP or not targetHRP then
		return false, false
	end

	-- Angle calculation between target's front and attacker direction
	local targetLook = targetHRP.CFrame.LookVector
	local toAttacker = (attackerHRP.Position - targetHRP.Position)
	local flatToAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if flatToAttacker.Magnitude < 0.1 then
		return true, isGuardBreakAttack
	end
	flatToAttacker = flatToAttacker.Unit

	local dot = targetLook:Dot(flatToAttacker)
	local angle = math.acos(math.clamp(dot, -1, 1))

	if angle > CombatConfig.MaxBlockAngle then
		-- Back hit! Block bypassed
		return false, false
	end

	-- Frontal block succeeded
	if isGuardBreakAttack then
		-- Guard Broken!
		targetChar:SetAttribute("IsBlocking", false)
		HitboxManager.ApplyHitstun(targetChar, CombatConfig.GuardBreakStun)
		BlockEvent:FireAllClients(targetChar, false, true)
		return true, true -- wasBlocking = true, guardBroken = true
	end

	return true, false -- wasBlocking = true, guardBroken = false
end

-- Checks for wall splat along knockback path
function HitboxManager.CheckWallSplat(targetChar: Model, knockbackVelocity: Vector3)
	local targetHRP = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetHRP then
		return
	end

	local flatVel = Vector3.new(knockbackVelocity.X, 0, knockbackVelocity.Z)
	if flatVel.Magnitude < CombatConfig.WallSplatThresholdVelocity then
		return
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { targetChar }
	raycastParams.IgnoreWater = true

	local dir = flatVel.Unit * CombatConfig.WallSplatRaycastDistance

	-- Perform check over a short duration during knockback flight
	task.spawn(function()
		local startTime = os.clock()
		while os.clock() - startTime < 0.6 do
			if not targetHRP or not targetHRP.Parent then
				break
			end

			local rayResult = Workspace:Raycast(targetHRP.Position, dir, raycastParams)
			if rayResult and rayResult.Instance then
				local normal = rayResult.Normal
				-- Check if surface is vertical (wall)
				if math.abs(normal.Y) <= CombatConfig.WallSplatMaxVerticalAngle then
					-- Wall Splat confirmed!
					targetHRP.AssemblyLinearVelocity = Vector3.zero
					targetHRP.AssemblyAngularVelocity = Vector3.zero
					targetHRP.CFrame = CFrame.lookAt(rayResult.Position + normal * 1.5, rayResult.Position + normal * 5.0)

					-- Deal wall splat impact damage & stun
					local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:TakeDamage(CombatConfig.WallSplatDamage)
					end
					HitboxManager.ApplyHitstun(targetChar, CombatConfig.WallSplatStunDuration)

					-- Splat VFX event
					CombatEvent:FireAllClients("WallSplat", {
						Target = targetChar,
						Position = rayResult.Position,
						Normal = normal,
					})

					-- Destructible integration
					local destructibleManager = getDestructibleManager()
					if destructibleManager and destructibleManager.BreakObstacle then
						pcall(function()
							destructibleManager.BreakObstacle(rayResult.Instance, flatVel, 6)
						end)
					end

					break
				end
			end
			task.wait(0.05)
		end
	end)
end

-- Executes server-side M1 attack logic
function HitboxManager.ProcessM1(player: Player, requestedStep: number)
	local character = player.Character
	if not character or HitboxManager.IsDisabled(character) or character:GetAttribute("IsAttacking") == true then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	local state = getState(player)
	local now = os.clock()

	-- Combo reset logic if player waited too long
	if now - state.LastAttackTime > CombatConfig.ComboResetTime then
		state.ComboStep = 1
	end

	local currentStep = state.ComboStep
	local stepConfig = CombatConfig.M1[currentStep]
	if not stepConfig then
		state.ComboStep = 1
		stepConfig = CombatConfig.M1[1]
		currentStep = 1
	end

	-- Cooldown check
	if now - state.LastAttackTime < stepConfig.Cooldown * 0.75 then
		return -- Attacking faster than allowed
	end

	AnimationManager.PlayAnimation(character, "M1_" .. tostring(currentStep))
	state.LastAttackTime = now
	state.IsAttacking = true
	state.DashCancelActive = true

	-- Dash cancel window closes after DashCancelWindow
	task.delay(CombatConfig.DashCancelWindow, function()
		if state.LastAttackTime == now then
			state.DashCancelActive = false
		end
	end)

	-- Advance next combo step
	if currentStep >= CombatConfig.MaxComboSteps then
		state.ComboStep = 1
	else
		state.ComboStep = currentStep + 1
	end

	-- Spatial Hitbox Query
	local hitboxCFrame = hrp.CFrame * CFrame.new(stepConfig.HitboxOffset)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.MaxParts = 20

	local partsInBox = Workspace:GetPartBoundsInBox(hitboxCFrame, stepConfig.HitboxSize, overlapParams)
	local hitCharacters: { [Model]: boolean } = {}

	for _, part in partsInBox do
		local hitModel = part:FindFirstAncestorOfClass("Model")
		if hitModel and hitModel ~= character and not hitCharacters[hitModel] then
			local targetHumanoid = hitModel:FindFirstChildOfClass("Humanoid")
			local targetHRP = hitModel:FindFirstChild("HumanoidRootPart") :: BasePart?

			if targetHumanoid and targetHumanoid.Health > 0 and targetHRP then
				hitCharacters[hitModel] = true

				-- Distance & Reach anti-cheat validation
				local dist = (targetHRP.Position - hrp.Position).Magnitude
				if dist > CombatConfig.MaxAllowedHitDistance then
					continue
				end

				-- Check target invincibility frames
				if hitModel:GetAttribute("iFrames") == true then
					continue
				end

				-- Evaluate Block & Guard Break
				local wasBlocked, guardBroken = HitboxManager.EvaluateBlock(character, hitModel, false)

				if wasBlocked and not guardBroken then
					-- Blocked successfully: deal reduced damage, no hitstun
					local reducedDamage = stepConfig.Damage * (1 - CombatConfig.BlockDamageReduction)
					HitboxManager.ApplyDamage(character, hitModel, reducedDamage)

					CombatEvent:FireAllClients("HitConfirm", {
						Attacker = character,
						Target = hitModel,
						Step = currentStep,
						Blocked = true,
						Damage = reducedDamage,
					})
				else
					-- Unblocked or Guard Broken hit
					HitboxManager.ApplyDamage(character, hitModel, stepConfig.Damage)

					if currentStep < CombatConfig.MaxComboSteps then
						-- Hits 1-3: Hitstun applied
						HitboxManager.ApplyHitstun(hitModel, stepConfig.Hitstun)

						CombatEvent:FireAllClients("HitConfirm", {
							Attacker = character,
							Target = hitModel,
							Step = currentStep,
							Blocked = false,
							Damage = stepConfig.Damage,
						})
					else
						-- Hit 4: Knockback & Ragdoll Knockdown
						local look = hrp.CFrame.LookVector
						local knockbackVel = (look * stepConfig.KnockbackForce) + Vector3.new(0, stepConfig.KnockbackLift, 0)
						targetHRP.AssemblyLinearVelocity = knockbackVel

						RagdollServer.RagdollCharacter(hitModel, CombatConfig.KnockdownDuration)

						CombatEvent:FireAllClients("HitConfirm", {
							Attacker = character,
							Target = hitModel,
							Step = currentStep,
							Blocked = false,
							Knockback = true,
							Damage = stepConfig.Damage,
						})

						-- Detect Wall Splat on knockback
						HitboxManager.CheckWallSplat(hitModel, knockbackVel)
					end
				end
			end
		end
	end
end

-- Executes Dash and Dash Cancel
function HitboxManager.ProcessDash(player: Player, direction: Vector3, dashType: string)
	local character = player.Character
	if not character or HitboxManager.IsDisabled(character) then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	local state = getState(player)
	local now = os.clock()

	-- Check dash cooldown unless cancelling an M1
	local isDashCancel = state.DashCancelActive and (now - state.LastAttackTime <= CombatConfig.DashCancelWindow)
	if not isDashCancel and (now - state.LastDashTime < CombatConfig.DashCooldown) then
		return
	end

	state.LastDashTime = now
	if isDashCancel then
		-- Dash Cancel executed: reset attack lock to allow rapid combo continuation
		state.IsAttacking = false
		state.DashCancelActive = false
	end

	-- Apply server-side i-frames
	character:SetAttribute("iFrames", true)
	task.delay(CombatConfig.iFrameDuration, function()
		if character and character.Parent then
			character:SetAttribute("iFrames", false)
		end
	end)

	-- Normalize direction or fallback to look vector
	local dashDir = direction
	if dashDir.Magnitude < 0.1 then
		dashDir = hrp.CFrame.LookVector
	else
		dashDir = dashDir.Unit
	end

	-- Apply impulse velocity
	hrp.AssemblyLinearVelocity = dashDir * CombatConfig.DashSpeed

	-- Notify clients for dash trails/VFX
	DashEvent:FireAllClients(character, dashDir, true)
end

-- Handles Blocking state update
function HitboxManager.ProcessBlock(player: Player, isBlocking: boolean)
	local character = player.Character
	if not character or HitboxManager.IsDisabled(character) then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if isBlocking then
		character:SetAttribute("IsBlocking", true)
		AnimationManager.PlayAnimation(character, "Block")
		if humanoid then
			humanoid.WalkSpeed = 16 * CombatConfig.BlockWalkSpeedMultiplier
		end
	else
		character:SetAttribute("IsBlocking", false)
		AnimationManager.StopAnimation(character, "Block")
		if humanoid and not character:GetAttribute("IsStunned") then
			humanoid.WalkSpeed = character:GetAttribute("OriginalWalkSpeed") or 16
		end
	end

	BlockEvent:FireAllClients(character, isBlocking, false)
end

-- Initialize remote event connections
function HitboxManager.Init()
	CombatEvent.OnServerEvent:Connect(function(player: Player, action: any, param1: any, ...)
		if action == "M1" then
			local requestedStep = typeof(param1) == "number" and param1 or 1
			HitboxManager.ProcessM1(player, requestedStep)
		elseif action == "RagdollRecovery" then
			RagdollServer.AttemptRecovery(player)
		end
	end)

	BlockEvent.OnServerEvent:Connect(function(player: Player, isBlocking: any)
		if typeof(isBlocking) == "boolean" then
			HitboxManager.ProcessBlock(player, isBlocking)
		end
	end)

	DashEvent.OnServerEvent:Connect(function(player: Player, direction: any, dashType: any)
		local dir = typeof(direction) == "Vector3" and direction or Vector3.zero
		local dType = typeof(dashType) == "string" and dashType or "Front"
		HitboxManager.ProcessDash(player, dir, dType)
	end)

	Players.PlayerRemoving:Connect(function(player)
		combatStates[player] = nil
	end)
end

-- Automatically initialize on require
HitboxManager.Init()

return HitboxManager
