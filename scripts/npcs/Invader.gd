extends Soldier

class_name Invader

## The usurper's soldiers (2026-11-15, the invasion). They march out of the
## war camp in waves and go for the realm's people — farmers, miners and
## above all the Prince — cutting down whoever they reach. The dragon they
## only fight when she comes close; she is the realm's defender now.
## Not part of the town's army ("soldiers" group): they don't rally, retire
## or count toward anything; they are "invaders". Two base claw strikes
## (50 HP); they burn like any soldier.

const VICTIM_GROUPS: Array[String] = ["prince", "farmers", "miners"]
const DRAGON_FIGHT_RANGE := 140.0
const TINT := Color(1.25, 0.62, 0.55)   # the usurper's crimson over town colours

var city_target := Vector2.ZERO
var camp_position := Vector2.ZERO
var _hit_debt := 0.0

func _ready() -> void:
	npc_type = "invader"
	max_health = 60      # two claws +1 at base; a garrison soldier needs ~6 s
	speed = 78.0
	attack_damage = 12.0
	attack_range = 58.0
	aggro_range = 0.0
	reward_gold = 0
	danger_radius = 0.0
	super._ready()
	remove_from_group("soldiers")
	add_to_group("invaders")
	var torso := get_node_or_null("Sprite/Torso") as CanvasItem
	if torso != null:
		torso.modulate = TINT

func _killer_key() -> String:
	return "soldier"

# --- whom they hunt --------------------------------------------------------------

func _nearest_victim() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for group: String in VICTIM_GROUPS:
		for node: Node in get_tree().get_nodes_in_group(group):
			var v := node as BaseNPC
			if v == null or not v.is_alive:
				continue
			var d := global_position.distance_to(v.global_position)
			if d < best_d:
				best_d = d
				best = v
	return best

func _dragon_near(reach: float) -> Node2D:
	var dragon := get_tree().get_first_node_in_group("dragon_threat") as Node2D
	if dragon != null and global_position.distance_to(dragon.global_position) <= reach:
		return dragon
	return null

## The dragon is fought only when she is close.
func _attack_ready() -> bool:
	return _dragon_near(DRAGON_FIGHT_RANGE) != null

func _dragon_in_chase_range() -> bool:
	return _dragon_near(DRAGON_FIGHT_RANGE * 1.6) != null

func _pick_dragon_target() -> Vector2:
	var dragon := _dragon_near(DRAGON_FIGHT_RANGE)
	return dragon.global_position if dragon != null else BehaviorTree.TARGET_NONE

func _swarm_rallying() -> bool:
	return false

func _swarm_released() -> bool:
	return false

## "Patrol" = the march: to the nearest victim, else on toward the city.
func _pick_patrol_target() -> Vector2:
	var victim := _nearest_victim()
	return victim.global_position if victim != null else city_target

func _pick_idle_target() -> Vector2:
	return _pick_patrol_target()

## Blades for the dragon (Soldier's contact) AND for the realm's people.
func _contact_damage(delta: float) -> void:
	super._contact_damage(delta)
	if _burning_left > 0.0 or not is_alive:
		return
	var victim := _nearest_foe_in_reach()
	if victim == null:
		return
	_hit_debt += attack_damage * delta
	var whole := int(_hit_debt)
	if whole > 0:
		_hit_debt -= float(whole)
		(victim as BaseNPC).take_damage(whole, Damage.Type.WEAPON, "invader")

## Whoever stands within blade reach: the realm's people first, else a
## soldier of the town's garrison (they fight back when the squad closes in).
func _nearest_foe_in_reach() -> BaseNPC:
	var victim := _nearest_victim()
	if victim != null and global_position.distance_to(victim.global_position) <= attack_range:
		return victim as BaseNPC
	var best: BaseNPC = null
	var best_d := attack_range
	for node: Node in get_tree().get_nodes_in_group("soldiers"):
		var s := node as BaseNPC
		if s == null or not s.is_alive or s.is_in_group("invaders") or s.is_in_group("king"):
			continue
		var d := global_position.distance_to(s.global_position)
		if d <= best_d:
			best_d = d
			best = s
	return best

## When their King falls, the army breaks and runs for the camp.
func rout() -> void:
	retire(camp_position)
