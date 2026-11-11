--!strict
-- ScreenShake.luau
-- Shared module exposing camera screen shake triggers and presets for combat events,
-- heavy hits, awakening transformations, and explosions.

export type ShakeOptions = {
	Intensity: number?,
	Duration: number?,
	Frequency: number?,
	RotationalRatio: number?, -- ratio of rotational shake vs translational shake
	TraumaExponent: number?, -- non-linear power curve for decay (default 2)
	FadeInTime: number?,
	FadeOutTime: number?,
}

local RunService = game:GetService("RunService")
local isClient = RunService:IsClient()

local ScreenShake = {}

-- Handler registered by CameraController on the client
local activeHandler: ((intensity: number, duration: number, frequency: number, options: ShakeOptions?) -> ())? = nil
local pendingQueue: { { intensity: number, duration: number, frequency: number, options: ShakeOptions? } } = {}

-- Preset configurations
local PRESETS = {
	Light = {
		Intensity = 0.35,
		Duration = 0.15,
		Frequency = 30,
		RotationalRatio = 0.6,
		TraumaExponent = 2.0,
	},
	Medium = {
		Intensity = 0.75,
		Duration = 0.25,
		Frequency = 32,
		RotationalRatio = 0.8,
		TraumaExponent = 2.0,
	},
	Heavy = {
		Intensity = 1.85,
		Duration = 0.45,
		Frequency = 26,
		RotationalRatio = 1.1,
		TraumaExponent = 2.2,
	},
	Explosion = {
		Intensity = 2.40,
		Duration = 0.60,
		Frequency = 22,
		RotationalRatio = 1.3,
		TraumaExponent = 2.5,
	},
	Awakening = {
		Intensity = 2.80,
		Duration = 1.60,
		Frequency = 18,
		RotationalRatio = 1.4,
		TraumaExponent = 1.8,
	},
	WallSplat = {
		Intensity = 1.60,
		Duration = 0.35,
		Frequency = 28,
		RotationalRatio = 1.0,
		TraumaExponent = 2.0,
	},
	GuardBreak = {
		Intensity = 2.00,
		Duration = 0.50,
		Frequency = 24,
		RotationalRatio = 1.2,
		TraumaExponent = 2.0,
	},
}

-- Register the active camera shake handler (typically CameraController.client)
function ScreenShake.SetHandler(handler: (intensity: number, duration: number, frequency: number, options: ShakeOptions?) -> ())
	activeHandler = handler
	-- Flush any early queued shakes
	if #pendingQueue > 0 then
		for _, queued in pendingQueue do
			task.spawn(handler, queued.intensity, queued.duration, queued.frequency, queued.options)
		end
		table.clear(pendingQueue)
	end
end

-- Primary shake trigger function
function ScreenShake.Shake(intensity: number?, duration: number?, frequency: number?, options: ShakeOptions?)
	if not isClient then
		return
	end

	local finalIntensity = intensity or 1.0
	local finalDuration = duration or 0.3
	local finalFrequency = frequency or 25

	if activeHandler then
		activeHandler(finalIntensity, finalDuration, finalFrequency, options)
	else
		-- Queue until CameraController registers
		if #pendingQueue < 20 then
			table.insert(pendingQueue, {
				intensity = finalIntensity,
				duration = finalDuration,
				frequency = finalFrequency,
				options = options,
			})
		end
	end
end

-- Triggers screen shake with falloff based on distance from local camera
function ScreenShake.ShakeAtPosition(origin: Vector3, maxDistance: number?, intensity: number?, duration: number?, frequency: number?, options: ShakeOptions?)
	if not isClient then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local maxDist = maxDistance or 120
	local dist = (camera.CFrame.Position - origin).Magnitude
	if dist > maxDist then
		return
	end

	-- Smooth quadratic falloff curve
	local factor = math.clamp(1 - (dist / maxDist), 0, 1)
	local falloffIntensity = (intensity or 1.5) * (factor * factor)

	if falloffIntensity > 0.05 then
		ScreenShake.Shake(falloffIntensity, duration, frequency, options)
	end
end

-- Convenience presets
function ScreenShake.Light(customOptions: ShakeOptions?)
	local p = PRESETS.Light
	ScreenShake.Shake(p.Intensity, p.Duration, p.Frequency, customOptions or p)
end

function ScreenShake.Medium(customOptions: ShakeOptions?)
	local p = PRESETS.Medium
	ScreenShake.Shake(p.Intensity, p.Duration, p.Frequency, customOptions or p)
end

function ScreenShake.Heavy(customOptions: ShakeOptions?)
	local p = PRESETS.Heavy
	ScreenShake.Shake(p.Intensity, p.Duration, p.Frequency, customOptions or p)
end

function ScreenShake.Explosion(customOptions: ShakeOptions?)
	local p = PRESETS.Explosion
	ScreenShake.Shake(p.Intensity, p.Duration, p.Frequency, customOptions or p)
end

function ScreenShake.Awakening(customOptions: ShakeOptions?)
	local p = PRESETS.Awakening
	ScreenShake.Shake(p.Intensity, p.Duration, p.Frequency, customOptions or p)
end

function ScreenShake.WallSplat(customOptions: ShakeOptions?)
	local p = PRESETS.WallSplat
	ScreenShake.Shake(p.Intensity, p.Duration, p.Frequency, customOptions or p)
end

function ScreenShake.GuardBreak(customOptions: ShakeOptions?)
	local p = PRESETS.GuardBreak
	ScreenShake.Shake(p.Intensity, p.Duration, p.Frequency, customOptions or p)
end

return ScreenShake
