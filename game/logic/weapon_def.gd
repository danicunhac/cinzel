class_name WeaponDef
extends RefCounted
## How a weapon type fights. The type gives the shape of the attack (combo,
## arc, thrust or arrow, special); the item (ItemCatalog stats) gives damage,
## attack speed, crit and range. Catalog ranges are in the old 320x180 units,
## so reach = range * WORLD_SCALE (the x1.5 of the 480x270 addendum); the
## other px values here are already scaled.

const WORLD_SCALE := 1.5
## A swing at attack_speed 1.0 lasts base_swing; faster weapons divide it.
const DEFAULT_CRIT_MULT := 1.5
## Lâminas Gêmeas (sword + off-hand sword, Equipment.dual_active): a combo
## of 4 that alternates hands (odd steps are the off-hand), swings 15%
## faster, and the off-hand hits add 60% of the off-hand sword's damage.
## The special becomes cross_flurry: CROSS_CUTS X-shaped double slashes.
const DUAL_COMBO_MULT: Array[float] = [1.0, 1.0, 1.0, 1.5]
const DUAL_SWING_MULT := 0.85
const DUAL_OFFHAND_SHARE := 0.6
const DUAL_SPECIAL_MULT := 0.9
const CROSS_CUTS := 4
const CROSS_GAP := 0.12
const CROSS_ARC := 150.0
const CROSS_REACH_MULT := 1.35
## Each X is two cuts this far (degrees) to each side of the facing.
const CROSS_TILT := 35.0

var type: StringName = &"sword"
var combo: int = 3
## Damage multiplier of each combo step (the last one is the finisher).
var combo_mult: Array[float] = [1.0, 1.0, 1.5]
var base_swing: float = 0.27
## Full width of the swing arc (melee, not thrust).
var arc_deg: float = 120.0
## px from the player to the tip (melee) or the arrow's travel (bow).
var reach: float = 33.0
## Thrust: a straight strip `reach` long and thrust_width wide, not an arc.
var thrust: bool = false
var thrust_width: float = 12.0
var lunge_speed: float = 45.0
## Seconds an enemy hit by a normal swing stops acting (bosses ignore it).
var stun: float = 0.0
var crit_mult: float = DEFAULT_CRIT_MULT
var ranged: bool = false
var projectile_speed: float = 0.0
## Enemies a charged arrow passes through (it hits pierce + 1).
var charged_pierce: int = 0
var charged_mult: float = 1.0
## Hold time of the charged shot (bow only, -1 = none) and of the special.
var charge_hold: float = -1.0
var special_hold: float = SpecialCharge.HOLD
## thrust_line, spin, ground_slam, lunge, flurry, arrow_rain, cross_flurry.
var special: StringName = &"thrust_line"
var special_mult: float = 2.0
## Two swords (dual_swords): odd combo steps are off-hand hits.
var dual: bool = false


## Seconds of one swing at this attack speed multiplier.
func swing_time(attack_speed: float) -> float:
	return base_swing / maxf(attack_speed, 0.05)


static func for_type(t: StringName) -> WeaponDef:
	var d := WeaponDef.new()
	d.type = t
	match t:
		&"sword":
			pass
		&"longsword":
			d.combo = 2
			d.combo_mult = [1.0, 1.4]
			d.base_swing = 0.3
			d.arc_deg = 160.0
			d.reach = 45.0
			d.lunge_speed = 30.0
			d.special = &"spin"
		&"axe":
			d.combo = 2
			d.combo_mult = [1.0, 1.3]
			d.base_swing = 0.3
			d.arc_deg = 120.0
			d.lunge_speed = 30.0
			d.stun = 0.4
			d.special = &"ground_slam"
			d.special_mult = 2.5
		&"spear":
			d.combo = 2
			d.combo_mult = [1.0, 1.25]
			d.thrust = true
			d.reach = 72.0
			d.lunge_speed = 40.0
			d.special = &"lunge"
		&"dagger":
			d.combo = 4
			d.combo_mult = [1.0, 1.0, 1.0, 1.5]
			d.base_swing = 0.2
			d.arc_deg = 90.0
			d.reach = 21.0
			d.lunge_speed = 30.0
			d.crit_mult = 2.0
			d.special = &"flurry"
			d.special_mult = 0.8
		&"bow":
			d.combo = 1
			d.combo_mult = [1.0]
			d.base_swing = 0.3
			d.ranged = true
			d.reach = 240.0
			d.lunge_speed = 0.0
			d.projectile_speed = 540.0
			d.charged_pierce = 1
			d.charged_mult = 1.5
			d.charge_hold = 0.5
			d.special_hold = 1.0
			d.special = &"arrow_rain"
			d.special_mult = 1.0
		_:
			push_error("WeaponDef: unknown weapon type '%s'" % t)
	return d


## Whether combo step `step` is swung by the off-hand sword.
func is_offhand_step(step: int) -> bool:
	return dual and step % 2 == 1


## The main sword's def turned into the two-sword fighting style.
static func dual_swords(main_id: StringName) -> WeaponDef:
	var d := for_item(main_id)
	d.dual = true
	d.combo = DUAL_COMBO_MULT.size()
	d.combo_mult = DUAL_COMBO_MULT.duplicate()
	d.base_swing *= DUAL_SWING_MULT
	d.special = &"cross_flurry"
	d.special_mult = DUAL_SPECIAL_MULT
	return d


## The def of an item's type with its catalog range as reach.
static func for_item(id: StringName) -> WeaponDef:
	var d := for_type(ItemDB.weapon_type(id))
	if ItemDB.kind(id) == &"weapon":
		var st: Dictionary = ItemDB.get_def(id)["stats"]
		d.reach = float(st["range"]) * WORLD_SCALE
	return d
