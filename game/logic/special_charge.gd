class_name SpecialCharge
extends RefCounted
## Hold-to-charge for the special (SAO Sword Skill). The attack press starts a
## hold; releasing after `special_hold` seconds fires the special when it is
## off cooldown, which then starts COOLDOWN. A weapon with a `charge_hold`
## stage (the bow) gives CHARGED for a release between the two, or past
## special_hold while the special is still cooling down.

enum { NONE, CHARGED, SPECIAL }

const HOLD := 0.5
const COOLDOWN := 4.0
## Below this the hold shows nothing (a normal tap).
const GLOW_START := 0.12

var special_hold: float = HOLD
var charge_hold: float = -1.0
var hold: float = 0.0
var holding: bool = false
var cooldown: float = 0.0


func _init(special_hold_s: float = HOLD, charge_hold_s: float = -1.0) -> void:
	special_hold = special_hold_s
	charge_hold = charge_hold_s


func press() -> void:
	holding = true
	hold = 0.0


func cancel() -> void:
	holding = false
	hold = 0.0


func is_ready() -> bool:
	return cooldown <= 0.0


## The special would fire on release.
func is_charged() -> bool:
	return holding and is_ready() and hold >= special_hold


## The charged (piercing) shot would fire on release.
func is_stage_one() -> bool:
	return holding and charge_hold > 0.0 and hold >= charge_hold and not is_charged()


## 0..1 toward the next stage that can fire, for the glow.
func glow() -> float:
	if not holding or hold < GLOW_START:
		return 0.0
	var target := special_hold if is_ready() else charge_hold
	if target <= 0.0:
		return 0.0
	return clampf(hold / target, 0.0, 1.0)


## 1 right after the special, 0 when it is ready (HUD).
func cooldown_ratio() -> float:
	return clampf(cooldown / COOLDOWN, 0.0, 1.0)


## Advances the hold while `held`; on release returns what fires.
func tick(delta: float, held: bool) -> int:
	cooldown = maxf(cooldown - delta, 0.0)
	if not holding:
		return NONE
	if held:
		hold += delta
		return NONE
	var result := NONE
	if is_ready() and hold >= special_hold:
		result = SPECIAL
		cooldown = COOLDOWN
	elif charge_hold > 0.0 and hold >= charge_hold:
		result = CHARGED
	cancel()
	return result
