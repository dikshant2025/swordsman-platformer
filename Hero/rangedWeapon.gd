# res://scripts/weapons/RangedWeapon.gd
extends Resource
class_name RangedWeapon

@export var display_name: String = "Bow"
@export var damage: int = 6
@export var cooldown: float = 0.22
@export var projectile_speed: float = 560.0
@export var projectile_scene: PackedScene

var muzzle: Marker2D

func is_melee() -> bool: return false
func is_ranged() -> bool: return true

func shoot(direction: Vector2) -> void:
	if muzzle == null or projectile_scene == null:
		return

	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var p := projectile_scene.instantiate()
	p.global_position = muzzle.global_position

	# If it’s your Projectile.gd (class_name Projectile), use its setup()
	if p.has_method("setup"):
		p.setup(dir, projectile_speed, damage)
	else:
		# Fallback for other projectile scripts
		if p.has_variable("direction"): p.direction = dir
		if p.has_variable("speed"):     p.speed = projectile_speed
		if p.has_variable("damage"):    p.damage = damage

	# Spawn into the active scene
	muzzle.get_tree().current_scene.add_child(p)
