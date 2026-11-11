--!strict
-- HUDController.client.luau
-- Client controller for the Anime Battleground Combat HUD.
-- Orchestrates real-time HealthBar tweening with damage ghost fill,
-- Ultimate / Awakening meter filling and ready glow pulse,
-- and accurate Skill Slot cooldown countdown sweeps and ready bounce animations.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

local HUDLayout = require(script.Parent:WaitForChild("HUDLayout"))

-- Initialize HUD
local screenGui, elements = HUDLayout.CreateHUD(PlayerGui)

-- Skill Name Mapping for Goku Base vs Super Saiyan Awakening Modes
local SKILL_NAMES = {
	Base = {
		[1] = "Rush Attack",
		[2] = "Kamehameha",
		[3] = "Kaioken",
		[4] = "Instant Transmission",
	},
	Awakening = {
		[1] = "Super Rush",
		[2] = "Super Kamehameha",
		[3] = "Kaioken x20",
		[4] = "Spirit Bomb",
	},
}

-- Initialize on-screen clickable buttons for skill slots 1 to 4
for i = 1, 4 do
	local slot = elements.SkillSlots[i]
	if slot and slot.Frame then
		if SKILL_NAMES.Base[i] then
			slot.NameLabel.Text = SKILL_NAMES.Base[i]
		end

		local clickBtn = Instance.new("TextButton")
		clickBtn.Name = "SlotClickButton"
		clickBtn.Size = UDim2.new(1, 0, 1, 0)
		clickBtn.Position = UDim2.new(0, 0, 0, 0)
		clickBtn.BackgroundTransparency = 1
		clickBtn.Text = ""
		clickBtn.ZIndex = 20
		clickBtn.Parent = slot.Frame

		local slotId = i
		clickBtn.Activated:Connect(function()
			local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
			local csmModule = playerScripts and playerScripts:FindFirstChild("ClientSkillManager")
			if csmModule and csmModule:IsA("ModuleScript") then
				local s, csm = pcall(require, csmModule)
				if s and csm and csm.CastSkill then
					csm.CastSkill(slotId)
					return
				end
			end
			-- Fallback to remote event
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local skillEvent = remotes and remotes:FindFirstChild("SkillEvent") :: RemoteEvent?
			if skillEvent then
				skillEvent:FireServer("CastSkill", slotId)
			end
		end)
	end
end

-- Make Awakening Banner clickable as well
if elements.AwakeningBanner then
	local awkBtn = Instance.new("TextButton")
	awkBtn.Name = "AwakeningClickButton"
	awkBtn.Size = UDim2.new(1, 0, 1, 0)
	awkBtn.BackgroundTransparency = 1
	awkBtn.Text = ""
	awkBtn.ZIndex = 25
	awkBtn.Parent = elements.AwakeningBanner
	awkBtn.Activated:Connect(function()
		local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
		local csmModule = playerScripts and playerScripts:FindFirstChild("ClientSkillManager")
		if csmModule and csmModule:IsA("ModuleScript") then
			local s, csm = pcall(require, csmModule)
			if s and csm and csm.ActivateAwakening then
				csm.ActivateAwakening()
				return
			end
		end
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local skillEvent = remotes and remotes:FindFirstChild("SkillEvent") :: RemoteEvent?
		if skillEvent then
			skillEvent:FireServer("Awakening")
		end
	end)
end

-- State variables
local currentHealth = 100
local maxHealth = 100
local currentUltimate = 0
local isAwakened = false
local awakeningEndTime = 0
local awakeningDuration = 30

-- Active Cooldowns: [slotIndex] = { EndTime, TotalDuration, Thread }
type CooldownData = {
	EndTime: number,
	TotalDuration: number,
	Connection: RBXScriptConnection?,
}
local activeCooldowns: { [number]: CooldownData } = {}

--------------------------------------------------------------------------------
-- 1. RESPONSIVE HUD SCALING
--------------------------------------------------------------------------------
local function updateViewportScale()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewportSize = camera.ViewportSize
	local baseWidth = 1920
	local baseHeight = 1080

	local scaleX = viewportSize.X / baseWidth
	local scaleY = viewportSize.Y / baseHeight
	local finalScale = math.clamp(math.min(scaleX, scaleY) * 1.15, 0.65, 1.35)

	local hudScale = elements.MainContainer:FindFirstChild("HUDScale") :: UIScale?
	if hudScale then
		hudScale.Scale = finalScale
	end
end

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateViewportScale)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateViewportScale)
		updateViewportScale()
	end
end)
updateViewportScale()

--------------------------------------------------------------------------------
-- 2. HEALTH BAR LOGIC (SMOOTH TWEEN & DAMAGE GHOST TRAIL)
--------------------------------------------------------------------------------
local ghostTween: Tween? = nil
local healthFillTween: Tween? = nil
local lowHealthPulsing = false

local function updateHealth(newHealth: number, newMaxHealth: number)
	currentHealth = math.clamp(newHealth, 0, newMaxHealth)
	maxHealth = math.max(newMaxHealth, 1)

	local healthRatio = math.clamp(currentHealth / maxHealth, 0, 1)

	-- Update Health Text
	elements.HealthText.Text = string.format("%d / %d", math.floor(currentHealth), math.floor(maxHealth))

	-- Cancel active fill tween
	if healthFillTween then
		healthFillTween:Cancel()
	end

	-- Rapid tween for primary health fill
	healthFillTween = TweenService:Create(
		elements.HealthBarFill,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(healthRatio, 0, 1, 0) }
	)
	healthFillTween:Play()

	-- Delayed catchup for Ghost Fill (damage trail)
	if ghostTween then
		ghostTween:Cancel()
	end

	task.delay(0.32, function()
		if elements.HealthGhostFill and elements.HealthGhostFill.Parent then
			ghostTween = TweenService:Create(
				elements.HealthGhostFill,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(healthRatio, 0, 1, 0) }
			)
			ghostTween:Play()
		end
	end)

	-- Low Health Warning Flash (when HP <= 25%)
	if healthRatio <= 0.25 and not lowHealthPulsing then
		lowHealthPulsing = true
		task.spawn(function()
			while lowHealthPulsing and currentHealth / maxHealth <= 0.25 do
				local flashRed = TweenService:Create(
					elements.HealthStroke,
					TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ Color = Color3.fromRGB(255, 30, 30), Thickness = 3.0 }
				)
				flashRed:Play()
				task.wait(0.4)
				local restore = TweenService:Create(
					elements.HealthStroke,
					TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ Color = Color3.fromRGB(80, 20, 20), Thickness = 1.8 }
				)
				restore:Play()
				task.wait(0.4)
			end
			elements.HealthStroke.Color = Color3.fromRGB(60, 65, 75)
			elements.HealthStroke.Thickness = 1.8
			lowHealthPulsing = false
		end)
	elseif healthRatio > 0.25 then
		lowHealthPulsing = false
		elements.HealthStroke.Color = Color3.fromRGB(60, 65, 75)
		elements.HealthStroke.Thickness = 1.8
	end
end

--------------------------------------------------------------------------------
-- 3. ULTIMATE / AWAKENING METER LOGIC
--------------------------------------------------------------------------------
local ultFillTween: Tween? = nil
local ultGlowPulsing = false

local function setUltimate(value: number)
	currentUltimate = math.clamp(value, 0, 100)

	if isAwakened then
		-- In awakening mode, meter display is handled by the countdown loop
		return
	end

	local ratio = currentUltimate / 100

	if ultFillTween then
		ultFillTween:Cancel()
	end

	ultFillTween = TweenService:Create(
		elements.UltBarFill,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(ratio, 0, 1, 0) }
	)
	ultFillTween:Play()

	elements.UltText.Text = string.format("ULTIMATE: %d%%", math.floor(currentUltimate))

	-- Ready State when 100%
	if currentUltimate >= 100 and not isAwakened then
		elements.AwakeningBanner.Visible = true
		elements.AwakeningText.Text = "🔥 AWAKENING READY [G] 🔥"

		if not ultGlowPulsing then
			ultGlowPulsing = true
			task.spawn(function()
				while ultGlowPulsing and currentUltimate >= 100 and not isAwakened do
					local glowOn = TweenService:Create(
						elements.UltGlowStroke,
						TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{ Color = Color3.fromRGB(255, 200, 40), Thickness = 3.0 }
					)
					glowOn:Play()
					task.wait(0.5)
					local glowOff = TweenService:Create(
						elements.UltGlowStroke,
						TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{ Color = Color3.fromRGB(150, 40, 220), Thickness = 1.5 }
					)
					glowOff:Play()
					task.wait(0.5)
				end
				ultGlowPulsing = false
				elements.UltGlowStroke.Color = Color3.fromRGB(90, 50, 140)
				elements.UltGlowStroke.Thickness = 1.5
			end)
		end
	else
		if not isAwakened then
			elements.AwakeningBanner.Visible = false
			ultGlowPulsing = false
			elements.UltGlowStroke.Color = Color3.fromRGB(90, 50, 140)
			elements.UltGlowStroke.Thickness = 1.5
		end
	end
end

local function setAwakeningState(active: boolean, duration: number?)
	isAwakened = active
	local dur = duration or awakeningDuration
	awakeningDuration = dur

	if active then
		awakeningEndTime = os.clock() + dur
		elements.AwakeningBanner.Visible = true

		-- Update Skill Names to Awakening variants
		for i = 1, 4 do
			local slot = elements.SkillSlots[i]
			if slot and SKILL_NAMES.Awakening[i] then
				slot.NameLabel.Text = SKILL_NAMES.Awakening[i]
				slot.NameLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
			end
		end

		-- Flash golden aura on skill slots
		for _, slot in elements.SkillSlots do
			slot.UIStroke.Color = Color3.fromRGB(255, 180, 40)
		end

		-- Awakening Countdown Loop
		task.spawn(function()
			while isAwakened do
				local remaining = math.max(0, awakeningEndTime - os.clock())
				local fraction = remaining / dur

				elements.UltBarFill.Size = UDim2.new(fraction, 0, 1, 0)
				elements.UltText.Text = string.format("AWAKENED: %.1fs", remaining)
				elements.AwakeningText.Text = string.format("⚡ AWAKENED (%.1fs) ⚡", remaining)

				if remaining <= 0 then
					break
				end
				task.wait(0.05)
			end

			if isAwakened then
				setAwakeningState(false)
			end
		end)
	else
		-- Revert to Normal Mode
		elements.AwakeningBanner.Visible = false
		elements.UltBarFill.Size = UDim2.new(0, 0, 1, 0)
		elements.UltText.Text = "ULTIMATE: 0%"
		currentUltimate = 0

		-- Revert Skill Names
		for i = 1, 4 do
			local slot = elements.SkillSlots[i]
			if slot and SKILL_NAMES.Base[i] then
				slot.NameLabel.Text = SKILL_NAMES.Base[i]
				slot.NameLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
				slot.UIStroke.Color = Color3.fromRGB(55, 60, 75)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- 4. SKILL COOLDOWN SYSTEM (SWEEP OVERLAY, COUNTDOWN, POP BOUNCE)
--------------------------------------------------------------------------------
local function startSkillCooldown(slotIndex: number, duration: number)
	local slot = elements.SkillSlots[slotIndex]
	if not slot or duration <= 0 then return end

	-- Clean up prior cooldown connection if active
	if activeCooldowns[slotIndex] and activeCooldowns[slotIndex].Connection then
		activeCooldowns[slotIndex].Connection:Disconnect()
	end

	local endTime = os.clock() + duration
	slot.CooldownOverlay.Visible = true

	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local remaining = endTime - os.clock()
		if remaining <= 0 then
			-- Cooldown Complete
			if conn then
				conn:Disconnect()
			end
			activeCooldowns[slotIndex] = nil
			slot.CooldownOverlay.Visible = false
			slot.CooldownOverlay.Size = UDim2.new(1, 0, 0, 0)
			slot.TimerLabel.Text = ""

			-- Pop Bounce animation to indicate readiness
			local popTween = TweenService:Create(
				slot.UIScale,
				TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1.15 }
			)
			local settleTween = TweenService:Create(
				slot.UIScale,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1.0 }
			)

			-- Flash stroke green/gold momentarily
			slot.UIStroke.Color = Color3.fromRGB(80, 255, 140)
			popTween:Play()
			popTween.Completed:Connect(function()
				settleTween:Play()
				task.delay(0.2, function()
					if isAwakened then
						slot.UIStroke.Color = Color3.fromRGB(255, 180, 40)
					else
						slot.UIStroke.Color = Color3.fromRGB(55, 60, 75)
					end
				end)
			end)
		else
			-- Sweep overlay from top to bottom
			local progress = remaining / duration
			slot.CooldownOverlay.Size = UDim2.new(1, 0, progress, 0)

			-- Format timer string
			if remaining >= 10 then
				slot.TimerLabel.Text = string.format("%ds", math.ceil(remaining))
			else
				slot.TimerLabel.Text = string.format("%.1fs", remaining)
			end
		end
	end)

	activeCooldowns[slotIndex] = {
		EndTime = endTime,
		TotalDuration = duration,
		Connection = conn,
	}
end

--------------------------------------------------------------------------------
-- 5. CHARACTER CONNECTION & ATTRIBUTE LISTENERS
--------------------------------------------------------------------------------
local function connectCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then return end

	-- Initial HP setup
	updateHealth(humanoid.Health, humanoid.MaxHealth)

	humanoid.HealthChanged:Connect(function(newHealth)
		updateHealth(newHealth, humanoid.MaxHealth)
	end)

	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		updateHealth(humanoid.Health, humanoid.MaxHealth)
	end)

	-- Attribute listener for Rage meter
	character:GetAttributeChangedSignal("Rage"):Connect(function()
		local rage = character:GetAttribute("Rage")
		if typeof(rage) == "number" then
			setUltimate(rage)
		end
	end)

	character:GetAttributeChangedSignal("IsAwakened"):Connect(function()
		local awakened = character:GetAttribute("IsAwakened") == true
		if awakened ~= isAwakened then
			setAwakeningState(awakened)
		end
	end)

	-- Read initial attributes
	local initRage = character:GetAttribute("Rage")
	if typeof(initRage) == "number" then
		setUltimate(initRage)
	end
	if character:GetAttribute("IsAwakened") == true then
		setAwakeningState(true)
	end
end

if LocalPlayer.Character then
	task.spawn(connectCharacter, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(connectCharacter)

--------------------------------------------------------------------------------
-- 6. REMOTE LISTENERS (SKILL COOLDOWNS & AWAKENING BROADCASTS)
--------------------------------------------------------------------------------
local function setupRemoteHooks()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes", 8) :: Folder?
	if not Remotes then return end

	-- 1. SkillEvent
	local skillEvent = Remotes:WaitForChild("SkillEvent", 5) :: RemoteEvent?
	if skillEvent then
		skillEvent.OnClientEvent:Connect(function(action: string, data: any)
			if typeof(data) ~= "table" then return end

			if action == "SkillCooldown" and data then
				local slotId = data.SkillId or (data.ActionKey and tonumber(string.match(data.ActionKey, "(%d+)")))
				if slotId and data.Duration then
					startSkillCooldown(slotId, data.Duration)
				end
			elseif action == "SkillFired" and (data.User == LocalPlayer.Character or data.Player == LocalPlayer) then
				if data.SkillId and data.Cooldown then
					startSkillCooldown(data.SkillId, data.Cooldown)
				end
			elseif action == "AwakeningState" and (data.User == LocalPlayer.Character or data.Character == LocalPlayer.Character or data.Player == LocalPlayer) then
				setAwakeningState(data.Active == true or data.IsAwakened == true, data.Duration)
			elseif action == "AwakeningMeter" and typeof(data.Meter) == "number" then
				setUltimate(data.Meter)
			end
		end)
	end

	-- 2. CombatEvent
	local combatEvent = Remotes:WaitForChild("CombatEvent", 5) :: RemoteEvent?
	if combatEvent then
		combatEvent.OnClientEvent:Connect(function(action: string, data: any)
			if typeof(data) ~= "table" then return end
			if action == "HitConfirm" and data.Attacker == LocalPlayer.Character then
				-- Play subtle punch scale on HUD
				local mScale = elements.MainContainer:FindFirstChild("HUDScale") :: UIScale?
				if mScale then
					local cur = mScale.Scale
					local pTween = TweenService:Create(mScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = cur * 1.02 })
					local rTween = TweenService:Create(mScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = cur })
					pTween:Play()
					pTween.Completed:Connect(function() rTween:Play() end)
				end
			end
		end)
	end
end

task.spawn(setupRemoteHooks)

-- Expose global table for local testing / other client scripts
local HUDController = {
	StartCooldown = startSkillCooldown,
	SetHealth = updateHealth,
	SetUltimate = setUltimate,
	SetAwakening = setAwakeningState,
	Elements = elements,
}

_G.HUDController = HUDController

print("[HUDController] Initialized and active.")
return HUDController
