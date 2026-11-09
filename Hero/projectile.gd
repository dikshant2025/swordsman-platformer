# res://scripts/weapons/Projectile.gd
extends Area2D
class_name Projectile

@export var speed: float = 600.0
@export var damage: int = 4
var direction: Vector2 = Vector2.RIGHT
var life: float = 3.0   # seconds before auto-despawn

func setup(dir: Vector2, spd: float, dmg: int) -> void:
	direction = dir.normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	speed = spd
	damage = dmg

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)  

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	life -= delta
	if life <= 0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("apply_damage"):
		area.apply_damage(damage)
	queue_free()
	
func _on_body_entered(body: Node) -> void:   # <-- add this
	if body.has_method("apply_damage"):
		body.apply_damage(damage, global_position)
	queue_free()
 
