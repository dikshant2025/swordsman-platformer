# res://SpawnPoint2.gd
extends Marker2D
@export var tag: String = "from_level1"   # e.g., "from_level1", "from_level2"

func _ready() -> void:
	add_to_group("SpawnPoint")
	set_meta("tag", tag)
