--!strict
-- VFXHelper.luau
-- High-performance procedural visual effects engine for Roblox Battleground Arena
-- Features: Dash trails & ghost after-images, Punch impact sparks & shockwaves,
-- Ground Slam expanding shockwave rings & debris, Awakening flaming aura bursts,
-- Wall Splat impacts, and Flash Counter teleport flashes.
-- 100% Procedural: Zero dependency on external asset IDs.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local VFXHelper = {}

-- Folder container for temporary VFX to keep Workspace clean
local function getVFXContainer(): Folder
	local folder = workspace:FindFirstChild("VFX_Container") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "VFX_Container"
		folder.Parent = workspace
	end
	return folder
end

--------------------------------------------------------------------------------
-- 1. DASH TRAILS & AFTER-IMAGES
--------------------------------------------------------------------------------

-- Spawns a series of fading "ghost" after-images of the character while dashing
function VFXHelper.DashTrail(character: Model, direction: Vector3, duration: number?, color: Color3?)
	local vfxFolder = getVFXContainer()
	local trailColor = color or Color3.fromRGB(150, 220, 255)
	local dur = duration or 0.25
	local startTime = os.clock()

	task.spawn(function()
		while os.clock() - startTime < dur do
			if not character or not character.Parent then break end

			for _, part in character:GetChildren() do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					local ghost = Instance.new("Part")
					ghost.Name = "DashGhost"
					ghost.Size = part.Size
					ghost.CFrame = part.CFrame
					ghost.Color = trailColor
					ghost.Material = Enum.Material.Neon
					ghost.Transparency = 0.55
					ghost.CanCollide = false
					ghost.CanTouch = false
					ghost.CanQuery = false
					ghost.CastShadow = false
					ghost.Anchored = true
					ghost.Parent = vfxFolder

					local fadeTween = TweenService:Create(
						ghost,
						TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Transparency = 1, Size = part.Size * 0.9 }
					)
					fadeTween:Play()
					fadeTween.Completed:Connect(function()
						ghost:Destroy()
					end)
				end
			end

			-- Spawn speed line streaks along dash direction
			local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				local streak = Instance.new("Part")
				streak.Name = "SpeedStreak"
				streak.Size = Vector3.new(0.2, 0.2, 5 + math.random() * 4)
				local offset = Vector3.new((math.random() - 0.5) * 4, (math.random() - 0.5) * 3, (math.random() - 0.5) * 4)
				streak.CFrame = CFrame.lookAt(hrp.Position + offset, hrp.Position + offset + direction)
				streak.Color = Color3.fromRGB(240, 250, 255)
				streak.Material = Enum.Material.Neon
				streak.Transparency = 0.4
				streak.CanCollide = false
				streak.CanTouch = false
				streak.CanQuery = false
				streak.CastShadow = false
				streak.Anchored = true
				streak.Parent = vfxFolder

				local streakTween = TweenService:Create(
					streak,
					TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Transparency = 1, Size = Vector3.new(0.05, 0.05, 8) }
				)
				streakTween:Play()
				streakTween.Completed:Connect(function()
					streak:Destroy()
				end)
			end

			task.wait(0.04)
		end
	end)
end

--------------------------------------------------------------------------------
-- 2. PUNCH IMPACT SPARKS & SHOCKWAVES
--------------------------------------------------------------------------------

function VFXHelper.PunchImpact(position: Vector3, normal: Vector3?, isCrit: boolean?)
	local vfxFolder = getVFXContainer()
	local norm = (normal or Vector3.new(0, 1, 0)).Unit
	local mainColor = if isCrit then Color3.fromRGB(255, 180, 30) else Color3.fromRGB(255, 70, 70)
	local innerColor = Color3.fromRGB(255, 255, 255)

	-- 1. Central Hit Flash Sphere
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = if isCrit then Vector3.new(3.5, 3.5, 3.5) else Vector3.new(2.2, 2.2, 2.2)
	flash.CFrame = CFrame.new(position)
	flash.Color = innerColor
	flash.Material = Enum.Material.Neon
	flash.Transparency = 0.1
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Anchored = true
	flash.Parent = vfxFolder

	-- PointLight for dramatic flash
	local light = Instance.new("PointLight")
	light.Color = mainColor
	light.Range = if isCrit then 16 else 10
	light.Brightness = 8
	light.Parent = flash

	local flashTween = TweenService:Create(
		flash,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = flash.Size * 1.6, Transparency = 1 }
	)
	local lightTween = TweenService:Create(
		light,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Brightness = 0 }
	)
	flashTween:Play()
	lightTween:Play()
	flashTween.Completed:Connect(function()
		flash:Destroy()
	end)

	-- 2. Expanding Hit Ring Shockwave
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 1.0, 1.0)
	-- Align cylinder along normal
	ring.CFrame = CFrame.lookAt(position, position + norm) * CFrame.Angles(0, math.rad(90), 0)
	ring.Color = mainColor
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Anchored = true
	ring.Parent = vfxFolder

	local targetRingRadius = if isCrit then 9.0 else 5.5
	local ringTween = TweenService:Create(
		ring,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(0.05, targetRingRadius, targetRingRadius),
			Transparency = 1,
		}
	)
	ringTween:Play()
	ringTween.Completed:Connect(function()
		ring:Destroy()
	end)

	-- 3. Sharp Hit Sparks / Star Bursts
	local sparkCount = if isCrit then 8 else 5
	for i = 1, sparkCount do
		local spark = Instance.new("Part")
		spark.Size = Vector3.new(0.15, 0.15, 1.8)
		spark.Color = if i % 2 == 0 then mainColor else innerColor
		spark.Material = Enum.Material.Neon
		spark.CanCollide = false
		spark.CanTouch = false
		spark.CanQuery = false
		spark.CastShadow = false
		spark.Anchored = true

		local randomDir = (norm + Vector3.new((math.random() - 0.5) * 1.8, (math.random() - 0.5) * 1.8, (math.random() - 0.5) * 1.8)).Unit
		spark.CFrame = CFrame.lookAt(position, position + randomDir)
		spark.Parent = vfxFolder

		local targetPos = position + (randomDir * (if isCrit then 6.5 else 4.0))
		local sparkTween = TweenService:Create(
			spark,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				CFrame = CFrame.lookAt(targetPos, targetPos + randomDir),
				Size = Vector3.new(0.05, 0.05, 0.2),
				Transparency = 1,
			}
		)
		sparkTween:Play()
		sparkTween.Completed:Connect(function()
			spark:Destroy()
		end)
	end
end

--------------------------------------------------------------------------------
-- 3. GROUND SLAM SHOCKWAVES & DEBRIS
--------------------------------------------------------------------------------

function VFXHelper.GroundSlam(position: Vector3, radius: number?)
	local vfxFolder = getVFXContainer()
	local maxRadius = radius or 18.0
	local ringColor = Color3.fromRGB(255, 140, 40) -- Bright fiery orange
	local shockwaveColor = Color3.fromRGB(255, 230, 180)

	-- 1. Primary Flat Expanding Ring (Cylinder on ground)
	local groundRing = Instance.new("Part")
	groundRing.Shape = Enum.PartType.Cylinder
	groundRing.Size = Vector3.new(0.4, 2.0, 2.0)
	groundRing.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	groundRing.Color = ringColor
	groundRing.Material = Enum.Material.Neon
	groundRing.Transparency = 0.1
	groundRing.CanCollide = false
	groundRing.CanTouch = false
	groundRing.CanQuery = false
	groundRing.CastShadow = false
	groundRing.Anchored = true
	groundRing.Parent = vfxFolder

	local ringTween = TweenService:Create(
		groundRing,
		TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(0.1, maxRadius * 2, maxRadius * 2),
			Transparency = 1,
		}
	)
	ringTween:Play()
	ringTween.Completed:Connect(function()
		groundRing:Destroy()
	end)

	-- 2. Secondary Expanding Dome Shockwave
	local dome = Instance.new("Part")
	dome.Shape = Enum.PartType.Ball
	dome.Size = Vector3.new(3, 3, 3)
	dome.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
	dome.Color = shockwaveColor
	dome.Material = Enum.Material.Neon
	dome.Transparency = 0.25
	dome.CanCollide = false
	dome.CanTouch = false
	dome.CanQuery = false
	dome.CastShadow = false
	dome.Anchored = true
	dome.Parent = vfxFolder

	local domeTween = TweenService:Create(
		dome,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(maxRadius * 1.5, maxRadius * 1.2, maxRadius * 1.5),
			Transparency = 1,
		}
	)
	domeTween:Play()
	domeTween.Completed:Connect(function()
		dome:Destroy()
	end)

	-- 3. Flying Debris Rock Chunks
	local debrisCount = 14
	for i = 1, debrisCount do
		local angle = (i / debrisCount) * math.pi * 2 + (math.random() * 0.4)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
		local rock = Instance.new("Part")
		local s = 0.8 + math.random() * 1.4
		rock.Size = Vector3.new(s, s * 0.8, s)
		rock.Color = Color3.fromRGB(110 + math.random(0, 30), 105 + math.random(0, 20), 100)
		rock.Material = Enum.Material.Slate
		rock.CanCollide = false
		rock.CanTouch = false
		rock.CanQuery = false
		rock.CastShadow = true
		rock.Anchored = true

		local startPos = position + (dir * (2 + math.random() * 3))
		local peakPos = startPos + (dir * (maxRadius * 0.65)) + Vector3.new(0, 6 + math.random() * 5, 0)
		local endPos = startPos + (dir * (maxRadius * 0.95)) + Vector3.new(0, 0.2, 0)

		rock.CFrame = CFrame.new(startPos) * CFrame.Angles(math.random(), math.random(), math.random())
		rock.Parent = vfxFolder

		-- Quadratic trajectory tween
		task.spawn(function()
			local flightTime = 0.45 + math.random() * 0.2
			local tStart = os.clock()
			while true do
				local elapsed = os.clock() - tStart
				local alpha = math.clamp(elapsed / flightTime, 0, 1)

				-- Bezier curve from startPos -> peakPos -> endPos
				local p1 = startPos:Lerp(peakPos, alpha)
				local p2 = peakPos:Lerp(endPos, alpha)
				local currentPos = p1:Lerp(p2, alpha)

				rock.CFrame = CFrame.new(currentPos) * CFrame.Angles(alpha * 6, alpha * 4, alpha * 2)

				if alpha >= 1 then break end
				task.wait()
			end

			-- Shrink into ground
			local shrinkTween = TweenService:Create(
				rock,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Size = Vector3.zero, Transparency = 1 }
			)
			shrinkTween:Play()
			shrinkTween.Completed:Connect(function()
				rock:Destroy()
			end)
		end)
	end

	-- 4. Ground Flash Light
	local lightPart = Instance.new("Part")
	lightPart.Size = Vector3.new(1, 1, 1)
	lightPart.Transparency = 1
	lightPart.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.Parent = vfxFolder

	local pLight = Instance.new("PointLight")
	pLight.Color = ringColor
	pLight.Range = maxRadius * 1.5
	pLight.Brightness = 12
	pLight.Parent = lightPart

	local lightTween = TweenService:Create(
		pLight,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Brightness = 0 }
	)
	lightTween:Play()
	lightTween.Completed:Connect(function()
		lightPart:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- 4. AWAKENING TRANSFORMATION BURST & FLAMING AURA
--------------------------------------------------------------------------------

-- Massive transformation explosion
function VFXHelper.AwakeningBurst(character: Model)
	local vfxFolder = getVFXContainer()
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	local center = hrp.Position
	local auraColor = Color3.fromRGB(190, 50, 255) -- Deep royal purple / magenta
	local flameColor = Color3.fromRGB(255, 90, 200)

	-- 1. Pillar of Light shot into sky
	local pillar = Instance.new("Part")
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(90, 6, 6)
	pillar.CFrame = CFrame.new(center + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Color = Color3.fromRGB(255, 255, 255)
	pillar.Material = Enum.Material.Neon
	pillar.Transparency = 0.1
	pillar.CanCollide = false
	pillar.CanTouch = false
	pillar.CanQuery = false
	pillar.CastShadow = false
	pillar.Anchored = true
	pillar.Parent = vfxFolder

	local pillarTween = TweenService:Create(
		pillar,
		TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(120, 18, 18), Transparency = 1 }
	)
	pillarTween:Play()
	pillarTween.Completed:Connect(function()
		pillar:Destroy()
	end)

	-- 2. Massive Spherical Energy Shockwave
	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(4, 4, 4)
	sphere.CFrame = CFrame.new(center)
	sphere.Color = auraColor
	sphere.Material = Enum.Material.Neon
	sphere.Transparency = 0.15
	sphere.CanCollide = false
	sphere.CanTouch = false
	sphere.CanQuery = false
	sphere.CastShadow = false
	sphere.Anchored = true
	sphere.Parent = vfxFolder

	local sphereTween = TweenService:Create(
		sphere,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(38, 38, 38), Transparency = 1 }
	)
	sphereTween:Play()
	sphereTween.Completed:Connect(function()
		sphere:Destroy()
	end)

	-- 3. Concentric Ground Rings
	for i = 1, 3 do
		task.delay((i - 1) * 0.1, function()
			local r = Instance.new("Part")
			r.Shape = Enum.PartType.Cylinder
			r.Size = Vector3.new(0.5, 3.0, 3.0)
			r.CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
			r.Color = if i % 2 == 1 then auraColor else flameColor
			r.Material = Enum.Material.Neon
			r.Transparency = 0.2
			r.CanCollide = false
			r.CanTouch = false
			r.CanQuery = false
			r.CastShadow = false
			r.Anchored = true
			r.Parent = vfxFolder

			local rTween = TweenService:Create(
				r,
				TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = Vector3.new(0.1, 32, 32), Transparency = 1 }
			)
			rTween:Play()
			rTween.Completed:Connect(function()
				r:Destroy()
			end)
		end)
	end

	-- 4. Automatically activate persistent aura
	VFXHelper.SetAwakeningAura(character, true)
end

-- Persistent flaming aura on character limbs
function VFXHelper.SetAwakeningAura(character: Model, active: boolean)
	local auraFolder = character:FindFirstChild("AwakeningAuraFolder") :: Folder?

	if not active then
		if auraFolder then
			auraFolder:Destroy()
		end
		local hl = character:FindFirstChild("AwakeningHighlight")
		if hl then
			hl:Destroy()
		end
		return
	end

	-- Remove existing if present to avoid stacking
	if auraFolder then
		auraFolder:Destroy()
	end

	auraFolder = Instance.new("Folder")
	auraFolder.Name = "AwakeningAuraFolder"
	auraFolder.Parent = character

	-- Highlight effect on character
	local highlight = Instance.new("Highlight")
	highlight.Name = "AwakeningHighlight"
	highlight.FillColor = Color3.fromRGB(220, 60, 255)
	highlight.FillTransparency = 0.72
	highlight.OutlineColor = Color3.fromRGB(255, 180, 255)
	highlight.OutlineTransparency = 0.2
	highlight.Parent = character

	-- Attach particle flames to UpperTorso / Torso and Limbs
	local targetParts = { "UpperTorso", "Torso", "HumanoidRootPart", "RightHand", "LeftHand", "RightArm", "LeftArm" }
	for _, partName in targetParts do
		local part = character:FindFirstChild(partName) :: BasePart?
		if part then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "FlameParticle"
			emitter.Rate = 18
			emitter.Lifetime = NumberRange.new(0.35, 0.6)
			emitter.Speed = NumberRange.new(1.5, 4.0)
			emitter.SpreadAngle = Vector2.new(45, 45)
			emitter.Acceleration = Vector3.new(0, 7, 0)
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(0.5, 1.3),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.6, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 255)),
				ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 90, 220)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 20, 240)),
			})
			emitter.LightEmission = 0.95
			emitter.LightInfluence = 0
			emitter.Parent = part
			emitter.Parent = auraFolder -- Parenting to auraFolder ensures clean one-step teardown
			-- Parent attachment inside part to anchor emitter position
			local att = Instance.new("Attachment")
			att.Name = "AuraAttachment"
			att.Parent = part
			emitter.Parent = att
		end
	end
end

--------------------------------------------------------------------------------
-- 5. WALL SPLAT IMPACT
--------------------------------------------------------------------------------

function VFXHelper.WallSplatImpact(position: Vector3, wallNormal: Vector3)
	local vfxFolder = getVFXContainer()
	local norm = wallNormal.Unit
	local splatColor = Color3.fromRGB(255, 80, 180)

	-- 1. Wall Impact Ring
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 1.5, 1.5)
	ring.CFrame = CFrame.lookAt(position, position + norm) * CFrame.Angles(0, math.rad(90), 0)
	ring.Color = splatColor
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.1
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Anchored = true
	ring.Parent = vfxFolder

	local ringTween = TweenService:Create(
		ring,
		TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, 11, 11), Transparency = 1 }
	)
	ringTween:Play()
	ringTween.Completed:Connect(function()
		ring:Destroy()
	end)

	-- 2. Rock Chips Flying from Wall
	for i = 1, 8 do
		local chip = Instance.new("Part")
		chip.Size = Vector3.new(0.4, 0.4, 0.4)
		chip.Color = Color3.fromRGB(130, 125, 120)
		chip.Material = Enum.Material.Slate
		chip.CanCollide = false
		chip.CanTouch = false
		chip.CanQuery = false
		chip.Anchored = true

		local sprayDir = (norm + Vector3.new((math.random() - 0.5) * 1.5, (math.random() - 0.5) * 1.5, (math.random() - 0.5) * 1.5)).Unit
		chip.CFrame = CFrame.new(position)
		chip.Parent = vfxFolder

		local targetPos = position + (sprayDir * (4 + math.random() * 4))
		local chipTween = TweenService:Create(
			chip,
			TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(targetPos), Size = Vector3.zero, Transparency = 1 }
		)
		chipTween:Play()
		chipTween.Completed:Connect(function()
			chip:Destroy()
		end)
	end
end

--------------------------------------------------------------------------------
-- 6. FLASH DASH / COUNTER FLASH
--------------------------------------------------------------------------------

function VFXHelper.FlashCounter(character: Model)
	local vfxFolder = getVFXContainer()
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	-- Sharp electrical / neon flash
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(5, 5, 5)
	flash.CFrame = hrp.CFrame
	flash.Color = Color3.fromRGB(120, 220, 255)
	flash.Material = Enum.Material.Neon
	flash.Transparency = 0.1
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Anchored = true
	flash.Parent = vfxFolder

	local flashTween = TweenService:Create(
		flash,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(12, 12, 12), Transparency = 1 }
	)
	flashTween:Play()
	flashTween.Completed:Connect(function()
		flash:Destroy()
	end)

	-- Spawns rapid after-image
	VFXHelper.DashTrail(character, hrp.CFrame.LookVector, 0.2, Color3.fromRGB(100, 220, 255))
end

-- Auto-listener on client for Remotes
if RunService:IsClient() then
	task.spawn(function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 8) :: Folder?
		if not remotes then return end

		-- DashEvent hook
		local dashEvent = remotes:WaitForChild("DashEvent", 5) :: RemoteEvent?
		if dashEvent then
			dashEvent.OnClientEvent:Connect(function(targetChar: Model, direction: Vector3, isLocal: boolean)
				if targetChar and targetChar.Parent then
					VFXHelper.DashTrail(targetChar, direction, 0.25)
				end
			end)
		end

		-- CombatEvent hook
		local combatEvent = remotes:WaitForChild("CombatEvent", 5) :: RemoteEvent?
		if combatEvent then
			combatEvent.OnClientEvent:Connect(function(action: string, data: any)
				if typeof(data) ~= "table" then return end

				if action == "HitConfirm" and data.Target then
					local hrp = data.Target:FindFirstChild("HumanoidRootPart") :: BasePart?
					if hrp then
						local isCrit = data.Knockback or (data.Step and data.Step >= 4)
						local hitPos = hrp.Position + Vector3.new(0, 0.5, 0)
						local norm = if data.Attacker and data.Attacker:FindFirstChild("HumanoidRootPart")
							then (hrp.Position - data.Attacker.HumanoidRootPart.Position).Unit
							else Vector3.new(0, 1, 0)
						VFXHelper.PunchImpact(hitPos, norm, isCrit)
					end
				elseif action == "WallSplat" and data.Target then
					local hrp = data.Target:FindFirstChild("HumanoidRootPart") :: BasePart?
					if hrp then
						local norm = data.Normal or Vector3.new(0, 0, 1)
						VFXHelper.WallSplatImpact(hrp.Position, norm)
					end
				end
			end)
		end

		-- SkillEvent hook
		local skillEvent = remotes:WaitForChild("SkillEvent", 5) :: RemoteEvent?
		if skillEvent then
			skillEvent.OnClientEvent:Connect(function(action: string, data: any)
				if typeof(data) ~= "table" then return end

				if action == "SkillFired" then
					local skillId = data.SkillId
					local pos = data.Position
					if skillId == 3 and pos then -- Ground Slam
						VFXHelper.GroundSlam(pos, 18)
					elseif skillId == 4 and data.User then -- Flash Dash / Counter
						VFXHelper.FlashCounter(data.User)
					elseif (skillId == 1 or skillId == 2) and pos then
						VFXHelper.PunchImpact(pos, Vector3.new(0, 1, 0), skillId == 2)
					end
				elseif action == "AwakeningState" and data.User then
					if data.Active == true then
						VFXHelper.AwakeningBurst(data.User)
					else
						VFXHelper.SetAwakeningAura(data.User, false)
					end
				end
			end)
		end
	end)
end

return VFXHelper
