--!strict
-- Original R15 choreography. Angles are degrees; every key is a full-body pose.
type Pose = { [string]: CFrame }
type Frame = { Pose: Pose, Duration: number, EasingStyle: Enum.EasingStyle?, EasingDirection: Enum.EasingDirection? }
type Sequence = { Loop: boolean, Keyframes: { Frame } }
local sequences: { [string]: Sequence } = {}
local function a(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0))
end
local guard: Pose = {
	Root = CFrame.new(0, -0.16, 0), Waist = a(5, -12), Neck = a(-3, 10),
	RightShoulder = a(38, -12, 18), RightElbow = a(88), RightWrist = a(0, 0, -8),
	LeftShoulder = a(55, 10, -20), LeftElbow = a(95), LeftWrist = a(0, 0, 8),
	RightHip = a(-12, 8, 7), RightKnee = a(-18), RightAnkle = a(10),
	LeftHip = a(14, -8, -7), LeftKnee = a(-12), LeftAnkle = a(4),
}
local function f(duration: number, changes: Pose, sharp: boolean?): Frame
	local pose = table.clone(guard)
	for name, transform in changes do pose[name] = transform end
	return { Pose = pose, Duration = duration,
		EasingStyle = if sharp then Enum.EasingStyle.Quart else Enum.EasingStyle.Sine,
		EasingDirection = if sharp then Enum.EasingDirection.Out else Enum.EasingDirection.InOut }
end
local function add(name: string, frames: { Frame }, loop: boolean?)
	sequences[name] = { Loop = loop or false, Keyframes = frames }
end
local function punch(right: boolean, power: number): Pose
	local side = if right then "Right" else "Left"
	local sign = if right then -1 else 1
	return {
		Root = CFrame.new(0, -0.2, -0.12 * power), Waist = a(9, sign * 24 * power, sign * 4), Neck = a(-5, -sign * 16),
		[side .. "Shoulder"] = a(94, sign * 6, sign * 9), [side .. "Elbow"] = a(8), [side .. "Wrist"] = a(0, sign * 12),
		RightHip = a(if right then 8 else -15, 5, 7), LeftHip = a(if right then -15 else 8, -5, -7),
	}
end
for step = 1, 4 do
	local right = step % 2 == 1
	local frames = { f(0.055, { Waist = a(-4, if right then 18 else -18) }), f(0.065, punch(right, if step == 4 then 1.4 else 1), true) }
	if step == 3 then
		frames[2] = f(0.075, { Waist = a(-12, -28), RightShoulder = a(112, 5, -20), RightElbow = a(62), Root = CFrame.new(0, 0.12, -0.1) }, true)
	end
	table.insert(frames, f(0.07, frames[2].Pose))
	table.insert(frames, f(0.13, {}))
	add("M1_" .. step, frames)
end
local function barrage(name: string, count: number, interval: number)
	local frames: { Frame } = {}
	for i = 1, count do
		table.insert(frames, f(interval * 0.58, punch(i % 2 == 1, 0.8), true))
		table.insert(frames, f(interval * 0.42, { Waist = a(4, if i % 2 == 1 then -8 else 8) }))
	end
	table.insert(frames, f(0.065, punch(true, 1.5), true))
	table.insert(frames, f(0.12, punch(true, 1.3)))
	table.insert(frames, f(0.14, {}))
	add(name, frames)
end
barrage("RushAttack", 12, 0.10)
barrage("OmnidirectionalPunches", 20, 0.075)
-- Cup both hands at the right hip, coil, and release on the server damage beat.
local charge: Pose = {
	Root = CFrame.new(0, -0.32, 0.12), Waist = a(5, 36, -5), Neck = a(-3, -30),
	RightShoulder = a(-41.4, -11.2, -24.1), RightElbow = a(130.7), RightWrist = a(-15, -25, -22),
	LeftShoulder = a(-1.3, -2.0, 79.0), LeftElbow = a(32.9), LeftWrist = a(15, 35, 28),
	RightHip = a(-20, 18, 12), RightKnee = a(-30), RightAnkle = a(12),
	LeftHip = a(22, -15, -12), LeftKnee = a(-20), LeftAnkle = a(8),
}
local release: Pose = {
	Root = CFrame.new(0, -0.25, 0.18), Waist = a(12, -8), Neck = a(-9, 6),
	RightShoulder = a(76.9, 13.1, -29.2), RightElbow = a(9.6), RightWrist = a(0, -12, -12),
	LeftShoulder = a(67.6, 1.2, 25.4), LeftElbow = a(17.4), LeftWrist = a(0, 12, 12),
	RightHip = a(-24, 10, 10), RightKnee = a(-30), LeftHip = a(22, -10, -10),
}
local function beam(name: string, windup: number)
	add(name, { f(0.16, charge), f(windup - 0.22, charge), f(0.06, release, true),
		f(0.08, release),
		f(0.25, release), f(0.18, {}) })
end
beam("Kamehameha", 0.50)
beam("SuperKamehameha", 0.55)
local function slam(name: string, windup: number)
	add(name, {
		f(0.10, { Root = CFrame.new(0, -0.45, 0), Waist = a(18), RightHip = a(30, 0, 10), LeftHip = a(30, 0, -10), RightKnee = a(-55), LeftKnee = a(-55) }),
		f(windup - 0.16, { Root = CFrame.new(0, 0.1, 0), Waist = a(-15), RightShoulder = a(155, 0, 12), LeftShoulder = a(155, 0, -12), RightElbow = a(35), LeftElbow = a(35) }),
		f(0.06, { Root = CFrame.new(0, -0.6, -0.1), Waist = a(44), Neck = a(-20), RightShoulder = a(32, 0, -10), LeftShoulder = a(32, 0, 10), RightElbow = a(15), LeftElbow = a(15), RightHip = a(34), LeftHip = a(34), RightKnee = a(-65), LeftKnee = a(-65) }, true),
		f(0.15, { Root = CFrame.new(0, -0.4, 0), Waist = a(24), RightKnee = a(-30), LeftKnee = a(-30) }), f(0.27, {}),
	})
end
slam("GroundSlam", 0.30)
slam("CataclysmicSlam", 0.40)
local teleport: Pose = { RightShoulder = a(96.9, 22.5, -72.2), RightElbow = a(130.4), RightWrist = a(0, -30, -10), Waist = a(0, 18), Neck = a(0, -15) }
add("InstantTransmission", { f(0.12, teleport), f(0.66, teleport), f(0.08, {}) })
add("SpiritBomb", {
	f(0.16, { Waist = a(-10), Neck = a(-20), RightShoulder = a(130, 0, 22), LeftShoulder = a(130, 0, -22), RightElbow = a(15), LeftElbow = a(15) }),
	f(0.33, { Root = CFrame.new(0, 0.15, 0), Waist = a(-12), Neck = a(-24), RightShoulder = a(172, 0, 15), LeftShoulder = a(172, 0, -15), RightElbow = a(8), LeftElbow = a(8) }),
	f(0.06, { Waist = a(28), Neck = a(-10), RightShoulder = a(82, 0, -8), LeftShoulder = a(82, 0, 8), RightElbow = a(8), LeftElbow = a(8), Root = CFrame.new(0, -0.2, -0.2) }, true),
	f(0.30, { Waist = a(18), RightShoulder = a(75), LeftShoulder = a(75), RightElbow = a(12), LeftElbow = a(12) }), f(0.22, {}),
})
add("CounterPunish", { f(0.05, { Waist = a(-6, 28) }), f(0.07, punch(true, 1.5), true), f(0.10, punch(true, 1.2)), f(0.15, {}) })
add("FlashDash", { f(0.06, { Waist = a(25), Neck = a(-20), RightShoulder = a(-35), LeftShoulder = a(-35), RightHip = a(35), LeftHip = a(-25) }), f(0.14, { Waist = a(20), Neck = a(-15), RightShoulder = a(-30), LeftShoulder = a(-30) }), f(0.12, {}) })
add("AwakeningTransform", {
	f(0.4, { Root = CFrame.new(0, -0.5, 0), Waist = a(18), Neck = a(20), RightShoulder = a(10, 0, 30), LeftShoulder = a(10, 0, -30), RightElbow = a(100), LeftElbow = a(100), RightKnee = a(-35), LeftKnee = a(-35) }),
	f(0.3, { Root = CFrame.new(0, -0.4, 0), Waist = a(12), RightShoulder = a(8, 0, 35), LeftShoulder = a(8, 0, -35), RightElbow = a(105), LeftElbow = a(105) }),
	f(0.10, { Waist = a(-12), Neck = a(-26), RightShoulder = a(0, 0, 48), LeftShoulder = a(0, 0, -48), RightElbow = a(35), LeftElbow = a(35) }, true),
	f(0.85, { Waist = a(-8), Neck = a(-18), RightShoulder = a(0, 0, 42), LeftShoulder = a(0, 0, -42), RightElbow = a(30), LeftElbow = a(30) }), f(0.35, {}),
})
local block: Pose = { RightShoulder = a(72, -20, 22), LeftShoulder = a(72, 20, -22), RightElbow = a(115), LeftElbow = a(115), Neck = a(8) }
add("Block", { f(0.10, block), f(0.8, block) }, true)
add("Hitstun", { f(0.05, { Waist = a(-18, 8), Neck = a(-12), RightShoulder = a(-12, 0, 30), LeftShoulder = a(-12, 0, -30) }, true), f(0.17, {}) })
sequences.HeavyPunch = sequences.Kamehameha
sequences.SeriousPunch = sequences.SuperKamehameha
sequences.CounterStance = sequences.InstantTransmission
sequences.GodspeedCounter = sequences.SpiritBomb
sequences.ConsecutivePunches = sequences.RushAttack
return sequences
