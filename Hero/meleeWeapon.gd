# res://scripts/weapons/MeleeWeapon.gd
extends Resource
class_name MeleeWeapon

@export var display_name: String = "Sword"   # avoids confusion with Node.name
@export var damage: int = 10
@export var cooldown: float = 0.3
@export var swing_time: float = 0.18

var hitbox: Area2D

func is_melee() -> bool: return true
func is_ranged() -> bool: return false

func swing() -> void:
	if hitbox == null:
		return
	# Enable the hitbox for the duration of the swing.
	hitbox.monitoring = true

	# Use the hitbox's SceneTree for a one-shot timer and await it.
	var t: SceneTreeTimer = hitbox.get_tree().create_timer(swing_time)
	await t.timeout

	# Safety: only disable if still valid (player might have been freed).
	if is_instance_valid(hitbox):
		hitbox.monitoring = false
