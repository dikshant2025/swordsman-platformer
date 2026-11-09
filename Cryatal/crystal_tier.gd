extends Area2D
class_name Crystal

@export var tier: int = 1
@export var heal_amount: int = 10          # HP restored on pickup
@export var melee_bonus: int = 10           # permanent bonus
@export var ranged_bonus: int = 5          # permanent bonus

func _ready() -> void:
	add_to_group("Crystal")
	monitoring = true
	monitorable = true
	# Optional: small idle float/tween etc.

func on_grabbed(player: Node) -> void:
	if player and player.has_method("apply_crystal"):
		player.apply_crystal(self)
	queue_free()   # disappear after pickup
