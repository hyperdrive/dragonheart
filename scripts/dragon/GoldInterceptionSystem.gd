extends Node

class_name GoldInterceptionSystem

## Dragon's steal mechanism (child of Dragon). Finds payload-carrying NPCs in
## range, resolves the interception, transfers the payload to the dragon stash
## (GameManager.add_stolen — two pools never mix). STEAL-ONLY: flyovers never
## damage or kill (decision 2026-11-08-dragon-strikes-respawn-prices — only an
## explicit E-press does).
## docs/plans/2026-11-08-behavior-system-rebuild.md — Trace 1.

signal resources_seized(res_type: String, amount: int)

@export var interception_range: float = 100.0
@export var min_interception_cooldown: float = 3.0
@export var max_interception_risk: float = 0.8

var interception_cooldown: float = 0.0

## Injected by Dragon._ready (GameManager is the only state hub).
var game_manager: GameManager

func _ready() -> void:
	print("GoldInterceptionSystem initialized")

func setup(mgr: GameManager) -> void:
	game_manager = mgr

func _process(delta: float) -> void:
	if interception_cooldown > 0.0:
		interception_cooldown = maxf(interception_cooldown - delta, 0.0)

## Payload carriers (any BaseNPC) within interception range: miners AND
## adventurers (2026-11-12) — the hero's lair loot is stealable back, the
## same payload-slot rule every carrier follows.
func check_interception_opportunities(dragon_position: Vector2) -> Array[BaseNPC]:
	var available: Array[BaseNPC] = []
	var carriers: Array[Node] = []
	carriers.append_array(get_tree().get_nodes_in_group("miners"))
	carriers.append_array(get_tree().get_nodes_in_group("adventurers"))
	for carrier: Node in carriers:
		var npc := carrier as BaseNPC
		if npc == null or not npc.is_alive or npc.payload_amount <= 0:
			continue
		if dragon_position.distance_to(npc.global_position) < interception_range:
			available.append(npc)
	return available

## Sort the available targets by value (payload + proximity) and return the best.
func get_best_interception_targets(dragon_position: Vector2, max_targets: int = 3) -> Array[BaseNPC]:
	var targets := check_interception_opportunities(dragon_position)
	targets.sort_custom(func(a: BaseNPC, b: BaseNPC) -> bool:
		var a_value := a.payload_amount * 15 - dragon_position.distance_to(a.global_position)
		var b_value := b.payload_amount * 15 - dragon_position.distance_to(b.global_position)
		return a_value > b_value
	)
	return targets.slice(0, mini(max_targets, targets.size()))

## Resolve one interception attempt. Returns true when it connected.
func attempt_interception(dragon: Node2D, target: BaseNPC) -> bool:
	if interception_cooldown > 0.0:
		return false

	# Distance-weighted success chance.
	var distance := dragon.global_position.distance_to(target.global_position)
	var success_probability := max_interception_risk * (1.0 - clampf(distance / interception_range, 0.0, 1.0))
	if randf() >= success_probability:
		return false

	interception_cooldown = min_interception_cooldown

	# Transfer the whole payload into the dragon's claws (banked at the lair).
	var loot := target.steal_payload()
	if loot["amount"] > 0:
		var dragon_c := dragon as Dragon
		if dragon_c != null:
			dragon_c.take_loot(loot["res_type"], loot["amount"])
		else:
			push_warning("GoldInterceptionSystem: no Dragon carry — loot discarded")
		resources_seized.emit(loot["res_type"], loot["amount"])

	# Steal-only by design (decision 2026-11-08-dragon-strikes-respawn-prices):
	# a flyover NEVER damages or kills — only an explicit E-press does.
	# Surviving miners panic anyway (payload already gone → pause in _check).
	var miner := target as Miner
	if miner != null:
		miner.intercepted_by_dragon()
	return true

func get_interception_status() -> Dictionary:
	return {
		"cooldown_remaining": maxf(0.0, interception_cooldown),
		"interception_range": interception_range,
	}
