--!strict
-- HUDLayout.luau
-- Programmatic ScreenGui constructor for Roblox Battleground Arena HUD
-- Features: Health Bar with ghost damage trail, Ultimate / Awakening % gauge with glowing ready state,
-- 4 Skill Cooldown Slots with animated overlays, keybind badges, and responsive modern anime styling.

local HUDLayout = {}

export type SkillSlotElements = {
	Frame: Frame,
	NameLabel: TextLabel,
	KeyLabel: TextLabel,
	CooldownOverlay: Frame,
	TimerLabel: TextLabel,
	IconLabel: TextLabel,
	UIStroke: UIStroke,
	UIScale: UIScale,
}

export type HUDElements = {
	ScreenGui: ScreenGui,
	MainContainer: Frame,
	HealthContainer: Frame,
	HealthBarFill: Frame,
	HealthGhostFill: Frame,
	HealthText: TextLabel,
	HealthStroke: UIStroke,
	UltContainer: Frame,
	UltBarFill: Frame,
	UltText: TextLabel,
	UltGlowStroke: UIStroke,
	UltGradient: UIGradient,
	AwakeningBanner: Frame,
	AwakeningText: TextLabel,
	SkillSlots: { [number]: SkillSlotElements },
}

local SKILL_DEFAULTS = {
	[1] = { Key = "Z", Name = "Consecutive Punches", Icon = "👊" },
	[2] = { Key = "X", Name = "Heavy Punch", Icon = "💥" },
	[3] = { Key = "C", Name = "Ground Slam", Icon = "⚡" },
	[4] = { Key = "V", Name = "Flash Dash", Icon = "💨" },
}

-- Helper to create rounded corners
local function addCorner(parent: Instance, radius: UDim): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
	return corner
end

-- Helper to create clean UI strokes
local function addStroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function HUDLayout.CreateHUD(parent: Instance?): (ScreenGui, HUDElements)
	-- 1. Root ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CombatHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true

	-- 2. Bottom Main Container (Centered at bottom of screen)
	local mainContainer = Instance.new("Frame")
	mainContainer.Name = "MainContainer"
	mainContainer.Size = UDim2.new(0, 720, 0, 155)
	mainContainer.Position = UDim2.new(0.5, 0, 1, -25)
	mainContainer.AnchorPoint = Vector2.new(0.5, 1)
	mainContainer.BackgroundTransparency = 1
	mainContainer.Parent = screenGui

	-- Aspect / Size Constraint to scale cleanly across 1080p, 1440p, 4K, and mobile
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "HUDScale"
	uiScale.Scale = 1.0
	uiScale.Parent = mainContainer

	-- 3. Health & Ultimate Meter Container (Top half of MainContainer)
	local metersFrame = Instance.new("Frame")
	metersFrame.Name = "MetersFrame"
	metersFrame.Size = UDim2.new(1, 0, 0, 52)
	metersFrame.Position = UDim2.new(0.5, 0, 0, 0)
	metersFrame.AnchorPoint = Vector2.new(0.5, 0)
	metersFrame.BackgroundTransparency = 1
	metersFrame.Parent = mainContainer

	----------------------------------------------------------------------------
	-- HEALTH BAR
	----------------------------------------------------------------------------
	local healthContainer = Instance.new("Frame")
	healthContainer.Name = "HealthContainer"
	healthContainer.Size = UDim2.new(1, 0, 0, 26)
	healthContainer.Position = UDim2.new(0, 0, 0, 0)
	healthContainer.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
	healthContainer.BorderSizePixel = 0
	healthContainer.ClipsDescendants = true
	healthContainer.Parent = metersFrame
	addCorner(healthContainer, UDim.new(0, 7))
	local healthStroke = addStroke(healthContainer, Color3.fromRGB(60, 65, 75), 1.8)

	-- Ghost Fill (Damage trail / damage chunk buffer)
	local healthGhostFill = Instance.new("Frame")
	healthGhostFill.Name = "GhostFill"
	healthGhostFill.Size = UDim2.new(1, 0, 1, 0)
	healthGhostFill.BackgroundColor3 = Color3.fromRGB(240, 80, 70)
	healthGhostFill.BorderSizePixel = 0
	healthGhostFill.Parent = healthContainer
	addCorner(healthGhostFill, UDim.new(0, 6))

	-- Current Health Fill (Vibrant green gradient)
	local healthBarFill = Instance.new("Frame")
	healthBarFill.Name = "HealthFill"
	healthBarFill.Size = UDim2.new(1, 0, 1, 0)
	healthBarFill.BackgroundColor3 = Color3.fromRGB(45, 215, 95)
	healthBarFill.BorderSizePixel = 0
	healthBarFill.Parent = healthContainer
	addCorner(healthBarFill, UDim.new(0, 6))

	local healthGradient = Instance.new("UIGradient")
	healthGradient.Rotation = 90
	healthGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 245, 135)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 175, 70)),
	})
	healthGradient.Parent = healthBarFill

	-- Health Label (Centered: "100 / 100")
	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.Position = UDim2.new(0.5, 0, 0.5, 0)
	healthText.AnchorPoint = Vector2.new(0.5, 0.5)
	healthText.BackgroundTransparency = 1
	healthText.Font = Enum.Font.GothamBlack
	healthText.TextSize = 15
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.TextStrokeColor3 = Color3.fromRGB(10, 15, 20)
	healthText.TextStrokeTransparency = 0.2
	healthText.Text = "100 / 100"
	healthText.ZIndex = 5
	healthText.Parent = healthContainer

	----------------------------------------------------------------------------
	-- ULTIMATE / AWAKENING METER
	----------------------------------------------------------------------------
	local ultContainer = Instance.new("Frame")
	ultContainer.Name = "UltContainer"
	ultContainer.Size = UDim2.new(1, 0, 0, 18)
	ultContainer.Position = UDim2.new(0, 0, 0, 31)
	ultContainer.BackgroundColor3 = Color3.fromRGB(15, 12, 22)
	ultContainer.BorderSizePixel = 0
	ultContainer.ClipsDescendants = true
	ultContainer.Parent = metersFrame
	addCorner(ultContainer, UDim.new(0, 6))
	local ultGlowStroke = addStroke(ultContainer, Color3.fromRGB(90, 50, 140), 1.5)

	-- Ultimate Fill Bar (Fiery Electric Magenta/Purple)
	local ultBarFill = Instance.new("Frame")
	ultBarFill.Name = "UltFill"
	ultBarFill.Size = UDim2.new(0, 0, 1, 0) -- Starts at 0%
	ultBarFill.BackgroundColor3 = Color3.fromRGB(190, 45, 255)
	ultBarFill.BorderSizePixel = 0
	ultBarFill.Parent = ultContainer
	addCorner(ultBarFill, UDim.new(0, 5))

	local ultGradient = Instance.new("UIGradient")
	ultGradient.Rotation = 0
	ultGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 25, 220)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(225, 50, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 40)),
	})
	ultGradient.Parent = ultBarFill

	-- Ultimate Text ("ULTIMATE 0%")
	local ultText = Instance.new("TextLabel")
	ultText.Name = "UltText"
	ultText.Size = UDim2.new(1, 0, 1, 0)
	ultText.Position = UDim2.new(0.5, 0, 0.5, 0)
	ultText.AnchorPoint = Vector2.new(0.5, 0.5)
	ultText.BackgroundTransparency = 1
	ultText.Font = Enum.Font.GothamBold
	ultText.TextSize = 12
	ultText.TextColor3 = Color3.fromRGB(240, 230, 255)
	ultText.TextStrokeColor3 = Color3.fromRGB(20, 5, 30)
	ultText.TextStrokeTransparency = 0.3
	ultText.Text = "ULTIMATE: 0%"
	ultText.ZIndex = 5
	ultText.Parent = ultContainer

	----------------------------------------------------------------------------
	-- AWAKENING BANNER (Pops up when active or ready)
	----------------------------------------------------------------------------
	local awakeningBanner = Instance.new("Frame")
	awakeningBanner.Name = "AwakeningBanner"
	awakeningBanner.Size = UDim2.new(0, 260, 0, 28)
	awakeningBanner.Position = UDim2.new(0.5, 0, 0, -34)
	awakeningBanner.AnchorPoint = Vector2.new(0.5, 0)
	awakeningBanner.BackgroundColor3 = Color3.fromRGB(25, 10, 35)
	awakeningBanner.BorderSizePixel = 0
	awakeningBanner.Visible = false
	awakeningBanner.Parent = mainContainer
	addCorner(awakeningBanner, UDim.new(0, 8))
	addStroke(awakeningBanner, Color3.fromRGB(255, 200, 50), 2)

	local awakeningText = Instance.new("TextLabel")
	awakeningText.Name = "AwakeningText"
	awakeningText.Size = UDim2.new(1, 0, 1, 0)
	awakeningText.BackgroundTransparency = 1
	awakeningText.Font = Enum.Font.GothamBlack
	awakeningText.TextSize = 14
	awakeningText.TextColor3 = Color3.fromRGB(255, 215, 60)
	awakeningText.TextStrokeColor3 = Color3.fromRGB(80, 15, 0)
	awakeningText.TextStrokeTransparency = 0
	awakeningText.Text = "🔥 AWAKENING READY [G] 🔥"
	awakeningText.Parent = awakeningBanner

	----------------------------------------------------------------------------
	-- 4 SKILL SLOTS CONTAINER (Bottom half of MainContainer)
	----------------------------------------------------------------------------
	local skillsContainer = Instance.new("Frame")
	skillsContainer.Name = "SkillsContainer"
	skillsContainer.Size = UDim2.new(1, 0, 0, 90)
	skillsContainer.Position = UDim2.new(0.5, 0, 0, 60)
	skillsContainer.AnchorPoint = Vector2.new(0.5, 0)
	skillsContainer.BackgroundTransparency = 1
	skillsContainer.Parent = mainContainer

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.Padding = UDim.new(0, 14)
	listLayout.Parent = skillsContainer

	local skillSlots: { [number]: SkillSlotElements } = {}

	for slotIndex = 1, 4 do
		local defaultData = SKILL_DEFAULTS[slotIndex]

		-- Skill Slot Card Frame (82 x 82)
		local slotFrame = Instance.new("Frame")
		slotFrame.Name = "Slot_" .. slotIndex
		slotFrame.Size = UDim2.new(0, 160, 0, 82)
		slotFrame.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
		slotFrame.BorderSizePixel = 0
		slotFrame.ClipsDescendants = true
		slotFrame.Parent = skillsContainer
		addCorner(slotFrame, UDim.new(0, 10))
		local slotStroke = addStroke(slotFrame, Color3.fromRGB(55, 60, 75), 1.8)

		local slotScale = Instance.new("UIScale")
		slotScale.Name = "SlotScale"
		slotScale.Scale = 1.0
		slotScale.Parent = slotFrame

		-- Background subtle gradient
		local slotGradient = Instance.new("UIGradient")
		slotGradient.Rotation = 45
		slotGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 32, 42)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 18, 24)),
		})
		slotGradient.Parent = slotFrame

		-- Keybind Badge (Top-left pill: "[Z]")
		local keyBadge = Instance.new("Frame")
		keyBadge.Name = "KeyBadge"
		keyBadge.Size = UDim2.new(0, 24, 0, 22)
		keyBadge.Position = UDim2.new(0, 6, 0, 6)
		keyBadge.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
		keyBadge.BorderSizePixel = 0
		keyBadge.ZIndex = 6
		keyBadge.Parent = slotFrame
		addCorner(keyBadge, UDim.new(0, 5))
		addStroke(keyBadge, Color3.fromRGB(75, 85, 110), 1)

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Name = "KeyLabel"
		keyLabel.Size = UDim2.new(1, 0, 1, 0)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Font = Enum.Font.GothamBlack
		keyLabel.TextSize = 13
		keyLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
		keyLabel.Text = defaultData.Key
		keyLabel.ZIndex = 7
		keyLabel.Parent = keyBadge

		-- Skill Graphic Icon
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Name = "IconLabel"
		iconLabel.Size = UDim2.new(0, 36, 0, 36)
		iconLabel.Position = UDim2.new(0.5, 0, 0.38, 0)
		iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Font = Enum.Font.GothamBlack
		iconLabel.TextSize = 24
		iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		iconLabel.Text = defaultData.Icon
		iconLabel.ZIndex = 4
		iconLabel.Parent = slotFrame

		-- Skill Name Label (Bottom centered)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(1, -12, 0, 22)
		nameLabel.Position = UDim2.new(0.5, 0, 1, -4)
		nameLabel.AnchorPoint = Vector2.new(0.5, 1)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 11
		nameLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
		nameLabel.TextStrokeColor3 = Color3.fromRGB(10, 12, 16)
		nameLabel.TextStrokeTransparency = 0.4
		nameLabel.TextWrapped = true
		nameLabel.Text = defaultData.Name
		nameLabel.ZIndex = 5
		nameLabel.Parent = slotFrame

		-- Cooldown Overlay (Covers the slot, sweeps down as cooldown progresses)
		local cdOverlay = Instance.new("Frame")
		cdOverlay.Name = "CooldownOverlay"
		cdOverlay.Size = UDim2.new(1, 0, 0, 0) -- Starts at height 0 (ready)
		cdOverlay.Position = UDim2.new(0, 0, 1, 0)
		cdOverlay.AnchorPoint = Vector2.new(0, 1)
		cdOverlay.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
		cdOverlay.BackgroundTransparency = 0.32
		cdOverlay.BorderSizePixel = 0
		cdOverlay.ZIndex = 8
		cdOverlay.Visible = false
		cdOverlay.Parent = slotFrame
		addCorner(cdOverlay, UDim.new(0, 10))

		-- Cooldown Countdown Timer Label ("12.4s")
		local timerLabel = Instance.new("TextLabel")
		timerLabel.Name = "TimerLabel"
		timerLabel.Size = UDim2.new(1, 0, 1, 0)
		timerLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
		timerLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		timerLabel.BackgroundTransparency = 1
		timerLabel.Font = Enum.Font.GothamBlack
		timerLabel.TextSize = 18
		timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		timerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		timerLabel.TextStrokeTransparency = 0
		timerLabel.Text = ""
		timerLabel.ZIndex = 9
		timerLabel.Parent = cdOverlay

		skillSlots[slotIndex] = {
			Frame = slotFrame,
			NameLabel = nameLabel,
			KeyLabel = keyLabel,
			CooldownOverlay = cdOverlay,
			TimerLabel = timerLabel,
			IconLabel = iconLabel,
			UIStroke = slotStroke,
			UIScale = slotScale,
		}
	end

	-- Parent ScreenGui if a parent is provided (e.g. PlayerGui or StarterGui)
	if parent then
		screenGui.Parent = parent
	end

	local elements: HUDElements = {
		ScreenGui = screenGui,
		MainContainer = mainContainer,
		HealthContainer = healthContainer,
		HealthBarFill = healthBarFill,
		HealthGhostFill = healthGhostFill,
		HealthText = healthText,
		HealthStroke = healthStroke,
		UltContainer = ultContainer,
		UltBarFill = ultBarFill,
		UltText = ultText,
		UltGlowStroke = ultGlowStroke,
		UltGradient = ultGradient,
		AwakeningBanner = awakeningBanner,
		AwakeningText = awakeningText,
		SkillSlots = skillSlots,
	}

	return screenGui, elements
end

return HUDLayout
