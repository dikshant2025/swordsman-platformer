extends Node
var has_data: bool = false

var health: int
var max_health: int
var base_melee_damage: int
var base_ranged_damage: int
var crystals = { "tier1": 0, "tier2": 0, "tier3": 0 }

func save_from_player(p) -> void:
	health = p.health
	max_health = p.max_health
	base_melee_damage = p.base_melee_damage
	base_ranged_damage = p.base_ranged_damage
	has_data = true

func apply_to_player(p) -> void:
	p.max_health = max_health
	p.health = health
	p.base_melee_damage = base_melee_damage
	p.base_ranged_damage = base_ranged_damage
	
func clear() -> void:
	has_data = false
	health = 0
	max_health = 0
	base_melee_damage = 0
	base_ranged_damage = 0
	crystals = { "tier1": 0, "tier2": 0, "tier3": 0 }
