# res://scripts/weapons/Weapon.gd
extends Resource
class_name Weapon

@export var name: String = "Weapon"
@export var damage: int = 1
@export var cooldown: float = 0.25

func is_melee() -> bool: return false
func is_ranged() -> bool: return false
