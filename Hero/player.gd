# res://scripts/Player.gd
extends CharacterBody2D
@export var bullet_scene: PackedScene 
# =========================
# --- Tunables ---
# =========================
@export var ranged_projectile_speed: float = 560.0
@export var move_speed: float = 100.0
@export var jump_velocity: float = -400.0
@export var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float

# Combat / Stats
@export var max_health: int = 500
@export var base_melee_damage: int = 100
@export var base_ranged_damage: int = 25

# Hurt/Death
@export var invuln_time: float = 0.6          # seconds of invulnerability after getting hit
@export var hurt_knockback: float = 220.0      # horizontal knockback on hurt
@export var death_freeze_time: float = 0.4     # short pause after death animation before cleanup

# Optional: drag multiple clips in the Inspector for variety (leave empty if using Streams on nodes)
@export var footstep_variants: Array[AudioStream] = []
@export var jump_variants:     Array[AudioStream] = []
@export var hurt_variants:     Array[AudioStream] = []
@export var grab_variants:     Array[AudioStream] = []
@export var death_variants:    Array[AudioStream] = []
@export var swing_variants:    Array[AudioStream] = []
@export var shot_variants:     Array[AudioStream] = []

# Which frames of the "run" animation should fire a step (tweak to your sprite)
@export var min_step_speed: float = 40.0      # pixels/sec threshold
@export var run_step_frames: Array[int] = [1, 5]

# =========================
# --- State ---
# =========================
signal health_changed(current: int, max: int)
signal damage_changed(melee: int, ranged: int)
signal died

var health: int
var level: int = 1
var xp: int = 0

# Runtime flags
var _is_attacking: bool = false
var _is_grabbing: bool = false
var _is_hurt: bool = false
var _is_dead: bool = false
var _base_modulate: Color = Color(1, 1, 1, 1)
var _hurt_anim_time_left: float = 0.0
var _is_walking_sound_playing: bool = false
var _jump_sfx_queued: bool = false   # tracks if we already fired jump SFX this frame


# --- Node Refs (match your scene) ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var melee_hitbox: Area2D = $MeleeHitbox

# timers live under "Node"
@onready var melee_cooldown: Timer = $Node/MeleeCooldown
@onready var ranged_cooldown: Timer = $Node/RangeCooldown
@onready var i_frames: Timer = $Node/IFrames

# muzzle is named GunMuzzle in your scene
@onready var muzzle: Marker2D = $GunMuzzle

# optional nodes (may be null)
@onready var crystal_probe: Area2D = $Hurtbox   # use Hurtbox as a proximity area

# === SFX nodes ===
@onready var sfx_step:  AudioStreamPlayer2D = $SFX/Step
@onready var sfx_grab:  AudioStreamPlayer2D = $SFX/Grab
@onready var sfx_jump:  AudioStreamPlayer2D = $SFX/Jump
@onready var sfx_hurt:  AudioStreamPlayer2D = $SFX/Hurt
@onready var sfx_death: AudioStreamPlayer2D = $SFX/Death
@onready var sfx_swing: AudioStreamPlayer2D = $SFX/Swing 
@onready var sfx_shot:  AudioStreamPlayer2D = $SFX/Shot  
@onready var step_cd: Timer = $SFX/StepCooldown

# =========================
# --- Lifecycle ---
# =========================
func _ready() -> void:
	set_process_input(true)
	add_to_group("Player")
	
	 # Load saved player stats if available
	if get_node_or_null("/root/GameState") and GameState.has_data:
		GameState.apply_to_player(self)
	else:
		health = max_health
		if get_node_or_null("/root/GameState"):
			GameState.save_from_player(self)
	
	emit_signal("health_changed", health, max_health)  # <-- initial value
	emit_signal("damage_changed", base_melee_damage, base_ranged_damage)
	
	
	_base_modulate = sprite.modulate
	melee_hitbox.monitoring = false
	melee_hitbox.set_deferred("monitorable", true)

	# Clear blink on i-frame end
	if not i_frames.timeout.is_connected(_on_i_frames_timeout):
		i_frames.timeout.connect(_on_i_frames_timeout)
	if not melee_hitbox.body_entered.is_connected(_on_melee_body_entered):
		melee_hitbox.body_entered.connect(_on_melee_body_entered)
	if not melee_hitbox.area_entered.is_connected(_on_melee_area_entered):
		melee_hitbox.area_entered.connect(_on_melee_area_entered)
	_prewarm_sfx([sfx_jump, sfx_grab, sfx_step, sfx_hurt, sfx_death, sfx_swing, sfx_shot])	
	

func _physics_process(delta: float) -> void:
	# If dead, let animation play; soften movement
	if _is_dead:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Horizontal input
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * move_speed
	if dir != 0:
		sprite.flip_h = dir < 0

	if _hurt_anim_time_left > 0.0:
		_hurt_anim_time_left = max(0.0, _hurt_anim_time_left - delta)
		
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_attacking and not _is_grabbing:
		velocity.y = jump_velocity
		if _hurt_anim_time_left <= 0.0:
			sprite.play("jump")

		
	# Melee attack (sword)
	if Input.is_action_just_pressed("attack_melee") and melee_cooldown.time_left <= 0.6 and not _is_grabbing:
		_do_melee_attack()

	# Ranged attack (works even without projectile scene)
	if Input.is_action_just_pressed("attack_ranged") and ranged_cooldown.time_left <= 0.1 and not _is_grabbing:
		var aim_dir := Vector2.RIGHT
		if sprite.flip_h:
			aim_dir = Vector2.LEFT
		_do_ranged_attack(aim_dir)

	# Grab crystal
	if Input.is_action_just_pressed("interact_grab") and not _is_attacking and not _is_hurt:
		_try_grab_crystal()

	move_and_slide()
	_update_movement_anim()
	_update_walk_sound()

# =========================
# --- Animation chooser ---
# =========================
func _update_movement_anim() -> void:
	if _is_attacking or _is_grabbing or _is_dead:
		return
	if _hurt_anim_time_left > 0.0:
		return  # don’t override "hurt" until timer runs out
	if not is_on_floor():
		if sprite.animation != "jump":
			sprite.play("jump")
	elif abs(velocity.x) > 1.0:
		if sprite.animation != "run":
			sprite.play("run")
	else:
		if sprite.animation != "idle":
			sprite.play("idle")

# =========================
# --- Melee (sword) ---
# =========================
func _do_melee_attack() -> void:
	_is_attacking = true
	_play_one_shot(sfx_swing, swing_variants)
	if _hurt_anim_time_left <= 0.0:
		sprite.play("attack_sword")

	# Align hitbox with animation frames
	var swing_windup := 0.05
	var swing_time := 0.6

	melee_hitbox.monitoring = false
	await get_tree().create_timer(swing_windup).timeout
	melee_hitbox.monitoring = true
	await get_tree().create_timer(swing_time).timeout
	melee_hitbox.monitoring = false

	melee_cooldown.start()
	_is_attacking = false

# =========================
# --- Ranged (shoot) ---
# =========================
func _do_ranged_attack(direction: Vector2) -> void:
	# No shoot animation / no muzzle flash
	_play_one_shot(sfx_shot, shot_variants)
	# 1) Decide direction (keep the param, but ensure normalized & fallback)
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		if sprite.flip_h:
			dir = Vector2.LEFT
		else:
			dir = Vector2.RIGHT

	# 2) Instance bullet scene and configure
	if bullet_scene:
		var b := bullet_scene.instantiate()
		b.global_position = muzzle.global_position

		# Prefer the setup API on your Projectile.gd
		if b.has_method("setup"):
			b.setup(dir, ranged_projectile_speed, base_ranged_damage)
		else:
			# (Only if your projectile lacks setup — safe fallback)
			if b.has_method("set"): # avoid has_variable; set if present
				if "direction" in b: b.direction = dir
				if "speed" in b: b.speed = ranged_projectile_speed
				if "damage" in b: b.damage = base_ranged_damage

		get_tree().current_scene.add_child(b)

	# 3) Start cooldown
	ranged_cooldown.start()


# =========================
# --- Grab Crystal ---
# =========================
func _try_grab_crystal() -> void:
	var can_grab := false
	var crystal: Node = null

	for ov in crystal_probe.get_overlapping_bodies():
		if ov.is_in_group("Crystal"):
			can_grab = true
			crystal = ov
			break
	if not can_grab:
		for ov in crystal_probe.get_overlapping_areas():
			if ov.is_in_group("Crystal"):
				can_grab = true
				crystal = ov
				break

	if not can_grab:
		return

	_is_grabbing = true
	sprite.play("grab_crystal")
	_play_one_shot(sfx_grab, grab_variants)

	await get_tree().create_timer(0.4).timeout

	if crystal and crystal.has_method("on_grabbed"):
		crystal.on_grabbed(self)

	await get_tree().create_timer(0.2).timeout
	_is_grabbing = false

# =========================
# --- Damage / Hurt / Death ---
# =========================
# Call this from enemies/hazards: apply_damage(amount, attacker_global_pos)
func apply_damage(dmg: int, from_pos: Vector2 = global_position) -> void:
	if _is_dead:
		return

	# Optional: show hurt animation again even during invuln, but DO NOT return early
	if i_frames.time_left > 0.0:
		sprite.play("hurt")

	# Take damage every time (no skip)
	health = max(0, health - dmg)
	print_debug("[PLAYER] took ", dmg, " damage | HP = ", health)
	emit_signal("health_changed", health, max_health)
	if get_node_or_null("/root/GameState"):
		GameState.save_from_player(self)

	_mirror_stats()

	if health <= 0:
		_do_death()
	else:
		_do_hurt(from_pos)


func _do_hurt(from_pos: Vector2) -> void:
	# Cancel conflicting states
	_is_attacking = false
	_is_grabbing = false

	# Knockback away from attacker
	var dir: float = sign(global_position.x - from_pos.x)
	if dir == 0.0:
		dir = 1.0
		if sprite.flip_h:
			dir = -1.0
	velocity.x = dir * hurt_knockback
	if is_on_floor():
		velocity.y = min(velocity.y, -abs(jump_velocity) * 0.35)

	# Play hurt animation
	sprite.play("hurt")
	_play_one_shot(sfx_hurt, hurt_variants)

	# Compute the real duration of the "hurt" animation and protect it for that long
	var dur := 0.25
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
		var frames := sprite.sprite_frames.get_frame_count("hurt")
		var speed := sprite.sprite_frames.get_animation_speed("hurt")
		if speed > 0:
			dur = float(frames) / float(speed)
	_hurt_anim_time_left = dur

	# Start invulnerability (no blinking)
	i_frames.wait_time = invuln_time
	i_frames.start()

func _do_death() -> void:
	if _is_dead:
		return
	_is_dead = true
	emit_signal("died")
	_is_attacking = false
	_is_grabbing = false

	melee_hitbox.monitoring = false
	sprite.play("death")
	_play_one_shot(sfx_death, death_variants)
	velocity.x = 0

	# Wait for the *real* length of the "death" animation
	var wait_time := death_freeze_time
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		var frames := sprite.sprite_frames.get_frame_count("death")
		var speed := sprite.sprite_frames.get_animation_speed("death")
		if speed > 0:
			wait_time = float(frames) / float(speed)

	await get_tree().create_timer(wait_time).timeout

	get_tree().reload_current_scene()

func _on_i_frames_timeout() -> void:
	sprite.modulate = _base_modulate
	
func _on_melee_body_entered(body: Node) -> void:
	if _is_attacking and body.has_method("apply_damage"):
		body.apply_damage(base_melee_damage, global_position)

func _on_melee_area_entered(area: Node) -> void:
	if _is_attacking and area.has_method("apply_damage"):
		area.apply_damage(base_melee_damage, global_position)
		
		
func apply_crystal(c: Crystal) -> void:
	# Heal
	health += c.heal_amount

	# Permanent damage bonuses (tweak to taste)
	base_melee_damage += c.melee_bonus
	base_ranged_damage += c.ranged_bonus
	GameState.save_from_player(self)         # persist

	# Optional: brief FX
	if sprite:
		sprite.modulate = Color(0.8, 1.0, 0.8)
		await get_tree().create_timer(0.12).timeout
		sprite.modulate = Color(1, 1, 1)
		
	emit_signal("health_changed", health, max_health)
	emit_signal("damage_changed", base_melee_damage, base_ranged_damage)
	_mirror_stats()
		
func _mirror_stats() -> void:
	if get_node_or_null("/root/GameState"):
		GameState.save_from_player(self)
		
func heal(amount: int) -> void:
	health += amount                # allow overflow if you want
	emit_signal("health_changed", health, max_health)
	if get_node_or_null("/root/GameState"):
		GameState.save_from_player(self)		
		
func _play_one_shot(player: AudioStreamPlayer2D, options: Array[AudioStream]) -> void:
	# If you provided variant clips, pick one randomly; else reuse the node's Stream
	if options.size() > 0:
		player.stream = options[randi() % options.size()]
	player.pitch_scale = 1.0 + randf_range(-0.05, 0.05) # tiny variation feels nicer
	player.play()

func _update_walk_sound() -> void:
	if is_on_floor() and abs(velocity.x) >= min_step_speed and _movement_ok():
		if not _is_walking_sound_playing:
			sfx_step.play()
			_is_walking_sound_playing = true
	else:
		if _is_walking_sound_playing:
			sfx_step.stop()
			_is_walking_sound_playing = false


func _movement_ok() -> bool:
	return not (_is_attacking or _is_grabbing or _is_dead or _hurt_anim_time_left > 0.0)

		
func _prewarm_sfx(players: Array[AudioStreamPlayer2D]) -> void:
	for p in players:
		if p == null: continue
		var old_db := p.volume_db
		p.volume_db = -80.0
		p.play()      # forces the stream to load
		p.stop()
		p.volume_db = old_db		
		
# Put this anywhere in Player.gd
func _force_loop_on_stream(s: AudioStream, enable: bool) -> void:
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD if enable else AudioStreamWAV.LOOP_DISABLED
	elif s is AudioStreamOggVorbis:
		s.loop = enable
	elif s is AudioStreamMP3:
		s.loop = enable
		
func _input(event: InputEvent) -> void:
	# Only respond to the synthesized action event (not raw key/axis noise)
	if event is InputEventAction \
	and event.action == "jump" \
	and event.pressed:                      # true only on the press edge
		# fire SFX instantly, but only when a real jump can start
		if is_on_floor() and not _is_attacking and not _is_grabbing and not _is_dead:
			_play_one_shot(sfx_jump, jump_variants)
			# (optional) mark as handled so nothing else re-triggers it this frame
			get_tree().set_input_as_handled()
