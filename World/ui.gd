# res://UI/ui.gd
extends CanvasLayer

@onready var player_bar = $PlayerBar
@onready var boss_bar = $BossBar

func _enter_tree() -> void:
	# In case the boss is instanced later, re-hook when new nodes appear
	get_tree().node_added.connect(_maybe_boss_spawned)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_maybe_boss_spawned):
		get_tree().node_added.disconnect(_maybe_boss_spawned)

func _ready() -> void:
	# Hide the default percent readout on both bars
	player_bar.show_percentage = false
	boss_bar.show_percentage   = false

	# Wire up to whoever exists right now
	_hook_player()
	_hook_boss()  # will also hide the bar if no boss is present

# ---------- Player ----------
func _hook_player() -> void:
	var p := get_tree().get_first_node_in_group("Player")
	if p:
		player_bar.setup(p.max_health, p.health)
		if not p.health_changed.is_connected(_on_player_health_changed):
			p.health_changed.connect(_on_player_health_changed)
		if not p.damage_changed.is_connected(_on_player_damage_changed):
			p.damage_changed.connect(_on_player_damage_changed)
		# Initialize the damage labels on the bar (if your bar exposes this)
		player_bar.set_attack(p.base_melee_damage, p.base_ranged_damage)

# ---------- Boss ----------
func _hook_boss() -> void:
	var b := get_tree().get_first_node_in_group("Boss")
	if b:
		boss_bar.visible = true
		boss_bar.max_value = b.max_health
		boss_bar.value = b.health
		if not b.health_changed.is_connected(_on_boss_health_changed):
			b.health_changed.connect(_on_boss_health_changed)
		if not b.died.is_connected(_on_boss_died):
			b.died.connect(_on_boss_died)
	else:
		boss_bar.visible = false
		
func _on_boss_died() -> void:
	boss_bar.visible = false
	boss_bar.value = 0
		

func _maybe_boss_spawned(n: Node) -> void:
	if n.is_in_group("Boss"):
		_hook_boss()

# ---------- Signal handlers you already had ----------
func _on_player_health_changed(current: int, maxv: int) -> void:
	player_bar.set_max(maxv)
	player_bar.set_health(current)

func _on_player_damage_changed(melee: int, ranged: int) -> void:
	player_bar.set_attack(melee, ranged)

func _on_boss_health_changed(current: int, maxv: int) -> void:
	boss_bar.set_max(maxv)
	boss_bar.set_health(current)

func _on_boss_damage_changed(melee: int, ranged: int) -> void:
	boss_bar.set_attack(melee, ranged)
