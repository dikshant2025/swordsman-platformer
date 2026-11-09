# res://Boss/healthbar.gd  (works for player or boss)
extends Control

@onready var fill: Range       = $Fill
@onready var dmg: Range        = $Damagebar
@onready var tick: Timer       = $Timer
@onready var value_label: Label = $ValueLabel
@onready var damage_label: Label = $DamageLabel

# Follow mode (if you use world-space follow):
@export var follow_target: bool = true
@export var target_path: NodePath
@export var pixel_offset: Vector2 = Vector2(0, -28)

var _target: Node2D
var _target_value: float = 0.0

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D

func setup(max_value: int, current_value: int) -> void:
	max_value = max(1, max_value)
	fill.max_value = max_value
	dmg.max_value = max_value
	# Allow “overheal”: keep bar range big enough to show > max
	if current_value > max_value:
		fill.max_value = current_value
		dmg.max_value = current_value

	fill.value = current_value
	dmg.value = current_value
	_target_value = current_value
	_update_value_text(current_value, int(fill.max_value))

func set_max(max_value: int) -> void:
	max_value = max(1, max_value)
	# keep current values but expand the range if needed
	fill.max_value = max(fill.max_value, max_value)
	dmg.max_value  = max(dmg.max_value,  max_value)
	# keep labels consistent
	_update_value_text(int(fill.value), int(fill.max_value))

func set_health(current_value: int) -> void:
	# Expand max if overheal
	if current_value > fill.max_value:
		fill.max_value = current_value
		dmg.max_value  = current_value

	_target_value = current_value
	fill.value = _target_value
	_update_value_text(int(fill.value), int(fill.max_value))

	if tick.is_stopped():
		tick.start()

func _on_Timer_timeout() -> void:
	# Smoothly move the red bar toward green
	if abs(dmg.value - _target_value) < 0.5:
		dmg.value = _target_value
		tick.stop()
	else:
		dmg.value = lerp(dmg.value, _target_value, 0.25)

func set_attack(melee: int, ranged: int) -> void:
	# Show your damage numbers however you prefer
	damage_label.text = "DMG %d | R %d" % [melee, ranged]

func _update_value_text(current: int, maxv: int) -> void:
	# If you want only the current number:  value_label.text = str(current)
	# If you want current and cap:          value_label.text = "%d / %d" % [current, maxv]
	value_label.text = str(current)

func _process(_dt: float) -> void:
	if not follow_target or _target == null: return
	var cam := get_viewport().get_camera_2d()
	if cam == null: return
	position = cam.to_screen(_target.global_position) + pixel_offset
