# res://scripts/slime_1.gd
extends CharacterBody2D
class_name Slime2Enemy

# -------- Tunables --------
@export var speed: float = 30.0
@export var max_health: int = 200
@export var gravity: float = 900.0

# --- Roaming (random flips) ---
@export var roam_flip_min: float = 1.0     # min seconds between direction changes
@export var roam_flip_max: float = 3.0     # max seconds between direction changes
@export var roam_speed_scale: float = 0.5  # speed multiplier while roaming (not chasing)
@export var roam_random_pick: bool = true  # pick a random left/right instead of just flipping

var _roam_flip_t: float = 0.0              # countdown to next direction change

# Combat tuning
@export var damage_to_deal: int = 75                  # damage to player per hit
@export var chase_distance: float = 50.0             # start chasing when player is within this range
@export var attack_distance: float = 28.0             # must be this close to start attack (X range)
@export var attack_windup: float = 0.25               # delay before damage lands (sync to attack anim)
@export var contact_damage_cooldown: float = 1.0      # time between consecutive hits on player
@export var hurt_recover_time: float = 0.5           # brief stagger on hit (NO knockback)

# Target hookup (set in Inspector, or add Player to "Player" group)
@export var player_path: NodePath
@export var drop_chance: float = 1.0                    # 1.0 = always, 0.5 = 50%
@export var crystal_drop: PackedScene                   # assign Tier1/2/3 in Inspector


# -------- State --------
var health: int
var dead: bool = false
var taking_damage: bool = false
var is_attacking: bool = false
var is_dealing_damage: bool = false
var is_roaming: bool = true
var is_slime2_chase: bool = true

var player: CharacterBody2D = null
var dir_x: float = 1.0                      # -1 = left, +1 = right
var _contact_cd: float = 0.0                # internal cooldown timer for contact damage

# -------- Nodes --------
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var deal_area: Area2D = $"slime deal damage"   # Area2D used to confirm contact

func _spawn_crystal() -> void:
	if not crystal_drop:
		return
	if randf() <= drop_chance:
		var c := crystal_drop.instantiate()
		c.global_position = global_position + Vector2(0, -6)
		get_tree().current_scene.add_child(c)


func _ready() -> void:
	randomize()
	_schedule_roam_flip()
	health = max_health

	# Find the player (prefer explicit path; fallback to group "Player")
	if player == null and player_path != NodePath():
		player = get_node(player_path) as CharacterBody2D
	if player == null:
		player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
	if player == null:
		push_warning("Slime2Enemy: Player not found. Set 'player_path' or add Player to group 'Player'.")

func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# tick contact-damage cooldown
	if _contact_cd > 0.0:
		_contact_cd -= delta
		
	var can_roam := (not dead) and (not taking_damage) and (not is_attacking) and (not is_slime2_chase or player == null)
	if can_roam:
		_roam_flip_t -= delta
		if _roam_flip_t <= 0.0:
			if roam_random_pick:
				dir_x = ( -1.0 if randf() < 0.5 else 1.0 )
			else:
				dir_x = -dir_x  # simple flip
			_schedule_roam_flip()

	# Decide chase based on proximity
	if player:
		is_slime2_chase = global_position.distance_to(player.global_position) <= chase_distance
	else:
		is_slime2_chase = false

	# Movement / attack state machine
	if dead:
		velocity.x = 0.0
	elif taking_damage:
		# brief stagger: don't move while hurt
		velocity.x = 0.0
	elif is_attacking:
		# stand still while attacking
		velocity.x = 0.0
	else:
		if is_slime2_chase and player:
			var dx := player.position.x - position.x
			if dx >= 0.0:
				dir_x = 1.0
			else:
				dir_x = -1.0

			# If close enough, attack; otherwise walk toward player
			if global_position.distance_to(player.global_position) <= attack_distance and _contact_cd <= 0.0:
				_do_attack()
				velocity.x = 0.0
			else:
				velocity.x = dir_x * speed
		else:
			# simple roaming in current facing
			velocity.x = dir_x * speed * roam_speed_scale

	handle_animation()
	move_and_slide()
	
func _schedule_roam_flip() -> void:
	_roam_flip_t = randf_range(roam_flip_min, roam_flip_max)
	

func handle_animation() -> void:
	if dead:
		if is_roaming:
			is_roaming = false
			if animated_sprite:
				animated_sprite.play("death")
			await get_tree().create_timer(1.25).timeout
			queue_free()
		return

	if taking_damage:
		if animated_sprite:
			animated_sprite.play("hurt")
		return

	if is_attacking:
		if animated_sprite:
			# NOTE: animation is named "deal_damage" (underscore) in your SpriteFrames
			animated_sprite.play("deal_damage")
		return

	# locomotion
	if animated_sprite:
		animated_sprite.play("walk")
		animated_sprite.flip_h = (dir_x < 0.0)

# =========================
# Attack (melee, with windup and cooldown)
# =========================
func _do_attack() -> void:
	if is_attacking or dead or taking_damage:
		return
	is_attacking = true
	is_dealing_damage = true

	if animated_sprite:
		animated_sprite.flip_h = (dir_x < 0.0)
		animated_sprite.play("deal_damage")  # ensure the attack animation plays

	# windup to sync with the attack frames
	await get_tree().create_timer(attack_windup).timeout

	# Land the hit if still valid (distance OR overlap with the attack Area2D)
	var hit_lands := false
	if player and not dead:
		if position.distance_to(player.position) <= attack_distance + 6.0:
			hit_lands = true
		elif deal_area:
			# ensure monitoring is on
			deal_area.set_deferred("monitoring", true)
			# prefer matching the player's Hurtbox via group
			for a in deal_area.get_overlapping_areas():
				if a.is_in_group("PlayerHurtbox"):
					hit_lands = true
					break
			if not hit_lands:
				for b in deal_area.get_overlapping_bodies():
					if b == player:
						hit_lands = true
						break

	if hit_lands and _contact_cd <= 0.0 and player and player.has_method("apply_damage"):
		player.apply_damage(damage_to_deal, global_position)
		_contact_cd = contact_damage_cooldown

	# give the animation a short tail
	await get_tree().create_timer(0.15).timeout
	is_dealing_damage = false
	is_attacking = false

# =========================
# Taking damage (from player sword / bullets)
# =========================
func apply_damage(amount: int, from_pos: Vector2 = global_position) -> void:
	if dead:
		return
	health = max(0, health - amount)
	print_debug("[SLIME2] took ", amount, " dmg | HP = ", health)

	# brief hit flash + stagger (NO knockback)
	taking_damage = true
	if animated_sprite:
		animated_sprite.modulate = Color(1, 0.6, 0.6)
	await get_tree().create_timer(hurt_recover_time).timeout
	if animated_sprite:
		animated_sprite.modulate = Color(1, 1, 1)
	taking_damage = false

	if health <= 0:
		dead = true
		_spawn_crystal() 
		
