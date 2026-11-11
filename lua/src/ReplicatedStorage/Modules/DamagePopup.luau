--!strict
-- DamagePopup.luau
-- Spawns animated 3D BillboardGui damage numbers and combat notifications
-- (Red normal damage, Yellow/Orange crits, Guard Break warnings, Blocked hits)

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local DamagePopup = {}

export type PopupType = "Normal" | "Crit" | "GuardBreak" | "Blocked" | "WallSplat" | "Awakening"

type StyleConfig = {
	TextColor: Color3,
	StrokeColor: Color3,
	TextSize: number,
	Prefix: string,
	Suffix: string,
	ScaleMultiplier: number,
	Font: Enum.Font,
}

local STYLES: { [PopupType]: StyleConfig } = {
	Normal = {
		TextColor = Color3.fromRGB(255, 65, 65), -- Bright red
		StrokeColor = Color3.fromRGB(40, 5, 5),
		TextSize = 26,
		Prefix = "-",
		Suffix = "",
		ScaleMultiplier = 1.0,
		Font = Enum.Font.GothamBlack,
	},
	Crit = {
		TextColor = Color3.fromRGB(255, 205, 40), -- Golden yellow
		StrokeColor = Color3.fromRGB(120, 45, 0),
		TextSize = 34,
		Prefix = "CRIT! -",
		Suffix = "!",
		ScaleMultiplier = 1.35,
		Font = Enum.Font.GothamBlack,
	},
	GuardBreak = {
		TextColor = Color3.fromRGB(255, 120, 20), -- Vivid orange
		StrokeColor = Color3.fromRGB(60, 10, 0),
		TextSize = 32,
		Prefix = "⚡ ",
		Suffix = " ⚡",
		ScaleMultiplier = 1.4,
		Font = Enum.Font.GothamBlack,
	},
	Blocked = {
		TextColor = Color3.fromRGB(120, 210, 255), -- Ice blue
		StrokeColor = Color3.fromRGB(10, 30, 60),
		TextSize = 22,
		Prefix = "🛡️ -",
		Suffix = "",
		ScaleMultiplier = 0.9,
		Font = Enum.Font.GothamBold,
	},
	WallSplat = {
		TextColor = Color3.fromRGB(255, 80, 180), -- Magenta / Hot pink
		StrokeColor = Color3.fromRGB(50, 0, 30),
		TextSize = 32,
		Prefix = "💥 WALL SPLAT -",
		Suffix = "",
		ScaleMultiplier = 1.3,
		Font = Enum.Font.GothamBlack,
	},
	Awakening = {
		TextColor = Color3.fromRGB(190, 80, 255), -- Electric purple
		StrokeColor = Color3.fromRGB(40, 0, 80),
		TextSize = 38,
		Prefix = "🔥 -",
		Suffix = " 🔥",
		ScaleMultiplier = 1.5,
		Font = Enum.Font.GothamBlack,
	},
}

-- Resolves target instance or creates an attachment if given a Vector3
local function resolveAdornee(target: Instance | Vector3): (Instance?, Attachment?, Vector3)
	if typeof(target) == "Vector3" then
		local att = Instance.new("Attachment")
		att.WorldPosition = target + Vector3.new(0, 2.5, 0)
		att.Parent = workspace.Terrain
		return nil, att, target
	elseif typeof(target) == "Instance" then
		if target:IsA("Model") then
			local head = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
			if head and head:IsA("BasePart") then
				return head, nil, head.Position
			end
		elseif target:IsA("BasePart") or target:IsA("Attachment") then
			return target, nil, if target:IsA("BasePart") then target.Position else target.WorldPosition
		end
	end
	return nil, nil, Vector3.zero
end

-- Primary spawn function
function DamagePopup.Spawn(
	target: Instance | Vector3,
	amount: number | string,
	popupType: PopupType?,
	customColor: Color3?
)
	local pType = popupType or "Normal"
	local style = STYLES[pType] or STYLES.Normal

	local adornee, tempAttachment, basePos = resolveAdornee(target)
	if not adornee and not tempAttachment then
		return
	end

	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageBillboard"
	billboard.Size = UDim2.new(0, 180, 0, 60)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 150
	billboard.LightInfluence = 0
	billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Random horizontal drift so consecutive combo hits don't stack directly on top
	local spreadX = (math.random() - 0.5) * 2.8
	local spreadY = (math.random() * 0.8)
	local startOffset = Vector3.new(spreadX, 2.5 + spreadY, 0)
	billboard.StudsOffset = startOffset

	if adornee then
		billboard.Adornee = adornee
		billboard.Parent = adornee
	elseif tempAttachment then
		billboard.Adornee = tempAttachment
		billboard.Parent = tempAttachment
	end

	-- Text container with scale punch
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "DamageLabel"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = style.Font
	textLabel.TextSize = style.TextSize
	textLabel.TextColor3 = customColor or style.TextColor
	textLabel.TextStrokeColor3 = style.StrokeColor
	textLabel.TextStrokeTransparency = 0
	textLabel.ZIndex = 10

	-- Format text display
	if typeof(amount) == "number" then
		local rounded = math.round(amount * 10) / 10
		textLabel.Text = style.Prefix .. tostring(rounded) .. style.Suffix
	else
		textLabel.Text = tostring(amount)
	end

	-- UIStroke for extra punchy anime outline
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 2.5
	uiStroke.Color = style.StrokeColor
	uiStroke.Transparency = 0
	uiStroke.Parent = textLabel

	-- UIGradient for vibrant vertical sheen
	local uiGradient = Instance.new("UIGradient")
	uiGradient.Rotation = 90
	uiGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.4, textLabel.TextColor3),
		ColorSequenceKeypoint.new(1, textLabel.TextColor3:Lerp(Color3.new(0, 0, 0), 0.3)),
	})
	uiGradient.Parent = textLabel

	-- UIScale for punchy bounce animation
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.4
	uiScale.Parent = textLabel

	textLabel.Parent = billboard

	-- Animation Sequence:
	-- Phase 1: Snappy pop up scale punch (0.4 -> 1.35 * multiplier -> 1.0)
	local targetScale = style.ScaleMultiplier
	local popTween = TweenService:Create(
		uiScale,
		TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = targetScale * 1.3 }
	)
	local settleTween = TweenService:Create(
		uiScale,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = targetScale }
	)

	-- Phase 2: Upward drift and fade out
	local endOffset = startOffset + Vector3.new(spreadX * 0.5, 3.2, 0)
	local driftTween = TweenService:Create(
		billboard,
		TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = endOffset }
	)

	local fadeTween = TweenService:Create(
		textLabel,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	local strokeFade = TweenService:Create(
		uiStroke,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Transparency = 1 }
	)

	-- Execute animation
	popTween:Play()
	popTween.Completed:Connect(function()
		settleTween:Play()
	end)

	driftTween:Play()

	-- Trigger fade after brief display
	task.delay(0.45, function()
		fadeTween:Play()
		strokeFade:Play()
	end)

	-- Clean up
	task.delay(0.95, function()
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
		if tempAttachment and tempAttachment.Parent then
			tempAttachment:Destroy()
		end
	end)
end

-- Preset Spawners
function DamagePopup.Normal(target: Instance | Vector3, amount: number)
	DamagePopup.Spawn(target, amount, "Normal")
end

function DamagePopup.Crit(target: Instance | Vector3, amount: number)
	DamagePopup.Spawn(target, amount, "Crit")
end

function DamagePopup.GuardBreak(target: Instance | Vector3)
	DamagePopup.Spawn(target, "GUARD BREAK!", "GuardBreak")
end

function DamagePopup.Blocked(target: Instance | Vector3, amount: number)
	DamagePopup.Spawn(target, amount, "Blocked")
end

function DamagePopup.WallSplat(target: Instance | Vector3, amount: number)
	DamagePopup.Spawn(target, amount, "WallSplat")
end

function DamagePopup.Awakening(target: Instance | Vector3, amount: number)
	DamagePopup.Spawn(target, amount, "Awakening")
end

-- Auto-listener on client: connects to CombatEvent & BlockEvent to spawn popups automatically
if RunService:IsClient() then
	task.spawn(function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 8) :: Folder?
		if not remotes then return end

		local combatEvent = remotes:WaitForChild("CombatEvent", 5) :: RemoteEvent?
		if combatEvent then
			combatEvent.OnClientEvent:Connect(function(action: string, data: any)
				if typeof(data) ~= "table" or not data.Target then return end

				if action == "HitConfirm" then
					local dmg = data.Damage or 0
					if data.Blocked then
						DamagePopup.Blocked(data.Target, dmg)
					elseif data.Knockback or (data.Step and data.Step >= 4) then
						DamagePopup.Crit(data.Target, dmg)
					else
						DamagePopup.Normal(data.Target, dmg)
					end
				elseif action == "WallSplat" then
					local dmg = data.Damage or 10
					DamagePopup.WallSplat(data.Target, dmg)
				end
			end)
		end

		local blockEvent = remotes:WaitForChild("BlockEvent", 5) :: RemoteEvent?
		if blockEvent then
			blockEvent.OnClientEvent:Connect(function(targetChar: Model, isBlocking: boolean, guardBroken: boolean)
				if guardBroken and targetChar then
					DamagePopup.GuardBreak(targetChar)
				end
			end)
		end
	end)
end

return DamagePopup
