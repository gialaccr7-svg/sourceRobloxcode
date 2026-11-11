--!strict
-- MovesetData.luau
-- Authoritative configuration for R15 Saitama-like Martial Arts character moveset:
-- 4 Core Skills (Rush Attack, Heavy Punch, Ground Slam, Counter/Flash Dash)
-- Awakening Transformation (Key G, Serious Mode, Omnidirectional Punches, Serious Punch)

export type SkillConfig = {
	Id: number,
	Name: string,
	KeyName: string,
	Description: string,
	Cooldown: number,
	Damage: number,
	Duration: number,
	WindupTime: number,
	HitboxSize: Vector3,
	HitboxOffset: Vector3,
	KnockbackForce: number,
	KnockbackLift: number,
	GuardBreak: boolean,
	CausesKnockdown: boolean,
	CausesHitstun: boolean,
	HitstunDuration: number,
	AnimationName: string,
	SoundId: string?,
	VFXType: string,
	HitCount: number?,
	HitInterval: number?,
	FinisherDamage: number?,
	FinisherKnockback: number?,
	FinisherLift: number?,
	AoeRadius: number?,
	CounterWindow: number?,
	CounterPunishDamage: number?,
	FlashDashDistance: number?,
	FlashDashDuration: number?,
	DestroysEnvironment: boolean?,
}

export type AwakeningConfig = {
	Name: string,
	KeyName: string,
	Description: string,
	RequiredRageMeter: number,
	TransformationDuration: number,
	Duration: number,
	WalkSpeedBuff: number,
	CooldownReduction: number, -- fraction, e.g. 0.30 = 30% reduction
	DamageMultiplier: number, -- e.g. 1.5x
	AnimationName: string,
	AuraColor: Color3,
}

local MovesetData = {}

-- Awakening Transformation settings (Super Saiyan / Serious Mode)
MovesetData.AwakeningConfig = {
	Name = "Super Saiyan / Serious Mode",
	KeyName = "G",
	Description = "Reach 100% Rage to awaken Goku's Super Saiyan power. Grants 24 WalkSpeed, 30% CDR, 1.5x damage, and evolves skills into Super Saiyan God / Serious moves.",
	RequiredRageMeter = 100,
	TransformationDuration = 2.0, -- Cinematic power-up lock
	Duration = 30.0, -- Active duration in seconds
	WalkSpeedBuff = 24.0, -- Normal is 16.0
	CooldownReduction = 0.30, -- 30% CDR
	DamageMultiplier = 1.50, -- 1.5x damage
	AnimationName = "AwakeningTransform",
	AuraColor = Color3.fromRGB(255, 215, 30),
} :: AwakeningConfig

-- Base 4 Skills (Goku Base Mode: Rush Attack, Kamehameha, Kaioken, Instant Transmission)
MovesetData.BaseSkills = {
	[1] = {
		Id = 1,
		Name = "Rush Attack (Consecutive Punches)",
		KeyName = "Z",
		Description = "Goku unleashes a rapid martial arts punch barrage (Đấm liên hoàn), trapping the target in continuous hitstun with forward momentum before blasting them back with a finisher strike.",
		Cooldown = 10.0,
		Damage = 2.5, -- per tick
		Duration = 1.5,
		WindupTime = 0.12,
		HitboxSize = Vector3.new(6.0, 6.0, 7.0),
		HitboxOffset = Vector3.new(0, 0, -3.8),
		KnockbackForce = 0, -- intermediate hits do not knock away
		KnockbackLift = 0,
		GuardBreak = false,
		CausesKnockdown = false,
		CausesHitstun = true,
		HitstunDuration = 0.35,
		AnimationName = "RushAttack",
		SoundId = "rbxassetid://0",
		VFXType = "GokuRushFlurry",
		HitCount = 12,
		HitInterval = 0.10,
		FinisherDamage = 10.0,
		FinisherKnockback = 45.0,
		FinisherLift = 6.0,
		DestroysEnvironment = false,
	} :: SkillConfig,

	[2] = {
		Id = 2,
		Name = "Kamehameha (Heavy Punch)",
		KeyName = "X",
		Description = "Goku takes a charging stance at hip gathering radiant blue Ki energy, then releases a colossal Kamehameha beam blast (Heavy Punch) that shatters obstacles, breaks enemy guard (Guard Break), and deals multi-hit damage with heavy knockback.",
		Cooldown = 14.0,
		Damage = 40.0,
		Duration = 1.2,
		WindupTime = 0.50,
		HitboxSize = Vector3.new(12.0, 10.0, 48.0),
		HitboxOffset = Vector3.new(0, 0, -24.0),
		KnockbackForce = 90.0,
		KnockbackLift = 15.0,
		GuardBreak = true,
		CausesKnockdown = true,
		CausesHitstun = true,
		HitstunDuration = 1.8,
		AnimationName = "Kamehameha",
		SoundId = "rbxassetid://0",
		VFXType = "KamehamehaBeam",
		DestroysEnvironment = true,
	} :: SkillConfig,

	[3] = {
		Id = 3,
		Name = "Kaioken / Ground Slam",
		KeyName = "C",
		Description = "Goku bursts into a crimson Kaioken aura, boosting speed and unleashing a rapid succession of martial arts strikes ending with an earth-shattering Ground Slam that launches enemies airborne and fractures obstacles.",
		Cooldown = 16.0,
		Damage = 32.0,
		Duration = 1.0,
		WindupTime = 0.30, -- jump ascent
		HitboxSize = Vector3.new(36.0, 12.0, 36.0),
		HitboxOffset = Vector3.new(0, -1.0, 0),
		KnockbackForce = 30.0,
		KnockbackLift = 65.0, -- Upward knockup
		GuardBreak = false,
		CausesKnockdown = true,
		CausesHitstun = true,
		HitstunDuration = 1.3,
		AnimationName = "GroundSlam",
		SoundId = "rbxassetid://0",
		VFXType = "KaiokenSlamCrater",
		AoeRadius = 18.0,
		DestroysEnvironment = true,
	} :: SkillConfig,

	[4] = {
		Id = 4,
		Name = "Instant Transmission (Counter / Flash Dash)",
		KeyName = "V",
		Description = "Goku places two fingers to his forehead and vanishes in a blue Ki flash, instantly teleporting behind the target (Counter / Flash Dash) to strike with a crushing heavy blow, or dashing forward at godspeed.",
		Cooldown = 18.0,
		Damage = 35.0,
		Duration = 0.8,
		WindupTime = 0.15,
		HitboxSize = Vector3.new(8.0, 8.0, 8.0),
		HitboxOffset = Vector3.new(0, 0, -3.5),
		KnockbackForce = 65.0,
		KnockbackLift = 12.0,
		GuardBreak = true,
		CausesKnockdown = true,
		CausesHitstun = true,
		HitstunDuration = 1.4,
		AnimationName = "InstantTransmission",
		SoundId = "rbxassetid://0",
		VFXType = "InstantTransmissionFlash",
		CounterWindow = 0.8,
		CounterPunishDamage = 35.0,
		FlashDashDistance = 35.0,
		FlashDashDuration = 0.20,
		DestroysEnvironment = true,
	} :: SkillConfig,
}

-- Awakened Upgraded Skills (Super Saiyan Mode: Super Rush Attack, Super Kamehameha, Kaioken x20, Spirit Bomb)
MovesetData.AwakenedSkills = {
	[1] = {
		Id = 1,
		Name = "Super Rush Attack (Omnidirectional Punches)",
		KeyName = "Z",
		Description = "Move at supersonic speed generating golden Ki afterimages around the foe, striking 20 rapid times before an explosive double-fist finish.",
		Cooldown = 12.0,
		Damage = 3.0,
		Duration = 1.7,
		WindupTime = 0.10,
		HitboxSize = Vector3.new(8.0, 7.0, 8.0),
		HitboxOffset = Vector3.new(0, 0, -4.5),
		KnockbackForce = 0,
		KnockbackLift = 0,
		GuardBreak = false,
		CausesKnockdown = true,
		CausesHitstun = true,
		HitstunDuration = 0.35,
		AnimationName = "OmnidirectionalPunches",
		SoundId = "rbxassetid://0",
		VFXType = "OmniPunchAfterimages",
		HitCount = 20,
		HitInterval = 0.075,
		FinisherDamage = 20.0,
		FinisherKnockback = 75.0,
		FinisherLift = 15.0,
		DestroysEnvironment = true,
	} :: SkillConfig,

	[2] = {
		Id = 2,
		Name = "Super Kamehameha (Serious Punch)",
		KeyName = "X",
		Description = "Execute the legendary Super Kamehameha (Serious Punch). Unleashes a massive golden-blue Ki beam across a 50-stud corridor, pulverizing barriers and dealing 80 damage with colossal knockback.",
		Cooldown = 18.0,
		Damage = 80.0,
		Duration = 1.2,
		WindupTime = 0.55,
		HitboxSize = Vector3.new(16.0, 12.0, 50.0),
		HitboxOffset = Vector3.new(0, 0, -25.0),
		KnockbackForce = 130.0,
		KnockbackLift = 25.0,
		GuardBreak = true,
		CausesKnockdown = true,
		CausesHitstun = true,
		HitstunDuration = 2.2,
		AnimationName = "SuperKamehameha",
		SoundId = "rbxassetid://0",
		VFXType = "SuperKamehamehaShockwave",
		DestroysEnvironment = true,
	} :: SkillConfig,

	[3] = {
		Id = 3,
		Name = "Kaioken x20 (Cataclysmic Slam)",
		KeyName = "C",
		Description = "Burst into the blazing crimson aura of Kaioken x20 (Cataclysmic Slam) and plummet with earth-shattering power, shattering a 28-stud radius and ejecting all targets high into the air.",
		Cooldown = 18.0,
		Damage = 48.0,
		Duration = 1.0,
		WindupTime = 0.40,
		HitboxSize = Vector3.new(56.0, 16.0, 56.0),
		HitboxOffset = Vector3.new(0, -1.0, 0),
		KnockbackForce = 45.0,
		KnockbackLift = 85.0,
		GuardBreak = false,
		CausesKnockdown = true,
		CausesHitstun = true,
		HitstunDuration = 1.5,
		AnimationName = "CataclysmicSlam",
		SoundId = "rbxassetid://0",
		VFXType = "KaiokenCataclysmicCrater",
		AoeRadius = 28.0,
		DestroysEnvironment = true,
	} :: SkillConfig,

	[4] = {
		Id = 4,
		Name = "Spirit Bomb (Godspeed Counter)",
		KeyName = "V",
		Description = "Goku leaps high into the air gathering a colossal Spirit Bomb above head, hurling the giant energy sphere forward for a catastrophic 30-stud AOE explosion (Spirit Bomb / Godspeed Counter).",
		Cooldown = 20.0,
		Damage = 50.0,
		Duration = 1.2,
		WindupTime = 0.35,
		HitboxSize = Vector3.new(10.0, 10.0, 10.0),
		HitboxOffset = Vector3.new(0, 0, -4.0),
		KnockbackForce = 75.0,
		KnockbackLift = 20.0,
		GuardBreak = true,
		CausesKnockdown = true,
		CausesHitstun = true,
		HitstunDuration = 1.8,
		AnimationName = "SpiritBomb",
		SoundId = "rbxassetid://0",
		VFXType = "SpiritBombExplosion",
		CounterWindow = 1.0,
		CounterPunishDamage = 50.0,
		FlashDashDistance = 50.0,
		FlashDashDuration = 0.20,
		DestroysEnvironment = true,
	} :: SkillConfig,
}

-- Returns skill configuration according to slot ID and awakening state
function MovesetData.GetSkill(skillId: number, isAwakened: boolean?): SkillConfig?
	if isAwakened then
		local awakened = MovesetData.AwakenedSkills[skillId]
		if awakened then
			return awakened
		end
	end
	return MovesetData.BaseSkills[skillId]
end

-- Returns the effective cooldown for a skill, applying awakening CDR if active
function MovesetData.GetCooldown(skillId: number, isAwakened: boolean?): number
	local skill = MovesetData.GetSkill(skillId, isAwakened)
	if not skill then
		return 0
	end
	if isAwakened then
		return skill.Cooldown * (1 - MovesetData.AwakeningConfig.CooldownReduction)
	end
	return skill.Cooldown
end

-- Returns the effective damage for a skill, applying awakening damage multiplier if active
function MovesetData.GetDamage(skillId: number, isAwakened: boolean?): number
	local skill = MovesetData.GetSkill(skillId, isAwakened)
	if not skill then
		return 0
	end
	if isAwakened then
		return skill.Damage * MovesetData.AwakeningConfig.DamageMultiplier
	end
	return skill.Damage
end

-- Returns all skills table for UI / HUD or enumeration
function MovesetData.GetAllSkills(isAwakened: boolean?): { [number]: SkillConfig }
	if isAwakened then
		return MovesetData.AwakenedSkills
	end
	return MovesetData.BaseSkills
end

-- Returns the awakening configuration
function MovesetData.GetAwakeningConfig(): AwakeningConfig
	return MovesetData.AwakeningConfig
end

return MovesetData
