# res://portal1.gd
extends Area2D

@export_file("*.tscn") var target_scene_path: String = "World//level2.tscn"   # e.g. "res://level2.tscn"
@export var target_spawn_tag: String = "from_level2"              # tag to spawn at in the next scene
@export var require_button: bool = false                    # set true if you want "press to use"
@export var input_action: String = "interact_grab"          # or "ui_accept"

var _player_inside := false

func _ready() -> void:
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if require_button and _player_inside and Input.is_action_just_pressed(input_action):
		_teleport()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_inside = true
		if not require_button:
			_teleport()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_inside = false

func _teleport() -> void:
	if target_scene_path == "": 
		push_warning("Portal: target_scene_path is empty.")
		return
	var p := get_tree().get_first_node_in_group("Player")
	if p and get_node_or_null("/root/GameState"):
		GameState.save_from_player(p)	
		
	# hand off the desired spawn tag to the next scene
	get_tree().set_meta("spawn_tag", target_spawn_tag)
	get_tree().change_scene_to_file(target_scene_path)
