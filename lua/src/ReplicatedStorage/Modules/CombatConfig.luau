--!strict
-- CombatConfig.luau
-- Centralized configuration for Core Combat & Physics mechanics
-- (M1 Combos, 4-Directional Dash, Block & Guard Break, Ragdoll & Recovery, Wall Splat)

export type M1StepConfig = {
	Step: number,
	Damage: number,
	Hitstun: number,
	SwingTime: number,
	Cooldown: number,
	HitboxSize: Vector3,
	HitboxOffset: Vector3,
	KnockbackForce: number,
	KnockbackLift: number,
	CausesKnockdown: boolean,
}

local CombatConfig = {
	-- Hitstun & Knockdown
	HitstunDuration = 0.4, -- seconds
	KnockdownDuration = 1.5, -- seconds
	RagdollMinRecoveryTime = 0.4, -- minimum time before space recovery is permitted
	RecoveryiFrames = 0.5, -- i-frame invulnerability upon get-up/recovery

	-- Combo System
	ComboResetTime = 1.2, -- time without attacking before combo resets to step 1
	MaxComboSteps = 4,

	-- M1 Combo Steps Configuration
	M1 = {
		[1] = {
			Step = 1,
			Damage = 5,
			Hitstun = 0.4,
			SwingTime = 0.22,
			Cooldown = 0.32,
			HitboxSize = Vector3.new(4.5, 5.0, 5.0),
			HitboxOffset = Vector3.new(0, 0, -3.0),
			KnockbackForce = 8,
			KnockbackLift = 0,
			CausesKnockdown = false,
		} :: M1StepConfig,
		[2] = {
			Step = 2,
			Damage = 5,
			Hitstun = 0.4,
			SwingTime = 0.22,
			Cooldown = 0.32,
			HitboxSize = Vector3.new(4.5, 5.0, 5.0),
			HitboxOffset = Vector3.new(0, 0, -3.0),
			KnockbackForce = 10,
			KnockbackLift = 0,
			CausesKnockdown = false,
		} :: M1StepConfig,
		[3] = {
			Step = 3,
			Damage = 6,
			Hitstun = 0.4,
			SwingTime = 0.28,
			Cooldown = 0.38,
			HitboxSize = Vector3.new(5.0, 5.0, 5.5),
			HitboxOffset = Vector3.new(0, 0, -3.2),
			KnockbackForce = 12,
			KnockbackLift = 0,
			CausesKnockdown = false,
		} :: M1StepConfig,
		[4] = {
			Step = 4,
			Damage = 10,
			Hitstun = 0.0,
			SwingTime = 0.38,
			Cooldown = 0.85,
			HitboxSize = Vector3.new(6.0, 5.5, 6.0),
			HitboxOffset = Vector3.new(0, 0, -3.5),
			KnockbackForce = 80, -- Strong knockback velocity (studs/s)
			KnockbackLift = 22, -- Vertical trajectory lift
			CausesKnockdown = true,
		} :: M1StepConfig,
	},

	-- Dash & Evasion
	DashDistance = 25, -- studs
	DashDuration = 0.25, -- seconds
	DashCooldown = 1.4, -- seconds
	iFrameDuration = 0.25, -- seconds of invincibility during dash
	DashCancelWindow = 0.35, -- window after M1 attack start where Q cancels recovery
	DashSpeed = 95, -- velocity applied during dash impulse

	-- Block & Guard Break
	BlockDamageReduction = 0.8, -- 80% damage reduction when successfully blocking
	MaxBlockAngle = math.rad(105), -- Frontal block arc (dot product threshold ~ -0.25)
	GuardBreakStun = 2.0, -- seconds of posture broken stun
	BlockWalkSpeedMultiplier = 0.5, -- slowed movement while holding block

	-- Wall Splat
	WallSplatThresholdVelocity = 40, -- minimum impact speed to trigger splat (studs/s)
	WallSplatStunDuration = 1.2, -- seconds target is pinned/stunned on wall
	WallSplatDamage = 10, -- bonus impact damage from wall slam
	WallSplatRaycastDistance = 4.5, -- studs forward to detect wall collision during knockback
	WallSplatMaxVerticalAngle = 0.35, -- normal Y threshold to ensure surface is vertical (wall)

	-- Rage / Ultimate Meter Building
	RageGainOnHit = 3.5, -- % rage granted to attacker on successful hit
	RageGainOnDamageTaken = 2.0, -- % rage granted to victim upon receiving damage

	-- Verification limits & Anti-reach
	MaxAllowedHitDistance = 12.0, -- studs max reach validation on server
}

return CombatConfig
