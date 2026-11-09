# res://Level1.gd
extends Node2D
@export var default_spawn_tag: String = "from_level_2"

func _ready() -> void:
	var tag := default_spawn_tag
	if get_tree().has_meta("spawn_tag"):
		var meta = get_tree().get_meta("spawn_tag")
		if meta != null:
			tag = str(meta)
		get_tree().set_meta("spawn_tag", null)  # clear it

	var spawn := _find_spawn(tag)
	if spawn:
		var player := get_tree().get_first_node_in_group("Player")
		if player:
			player.global_position = spawn.global_position
	else:
		push_warning("Level: Spawn tag '%s' not found; using default player position." % tag)

func _find_spawn(tag: String) -> Node2D:
	for n in get_tree().get_nodes_in_group("SpawnPoint"):
		if n.has_meta("tag") and str(n.get_meta("tag")) == tag:
			return n as Node2D
	return null
