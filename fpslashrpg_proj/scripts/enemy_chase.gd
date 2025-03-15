extends "res://scripts/enemy_basic.gd"

@export var detection_range = 15.0  # How far the enemy can see
@export var chase_speed = 3.0       # Movement speed when chasing
@export var aggression = 1.5        # Higher values make the enemy more aggressive
@export var attack_range = 1.5      # How close the enemy needs to be to attack
@export var attack_cooldown = 1.0   # Time between attacks
@export var attack_damage = 10      # Damage dealt to player

var player = null
var can_attack = true
var attack_timer = 0.0
var current_state = State.IDLE

enum State {
	IDLE,
	CHASE,
	ATTACK,
	STUNNED
}

func _ready():
	# Set chase enemy properties before calling parent _ready
	# This ensures that the health value will not be overridden
	health = 2  # Takes 2 hits to kill
	
	# Now call parent _ready
	super()
	
	# Print health to confirm it's properly set
	print("Chase enemy initialized with health: ", health)
	
	# Find the player
	player = get_tree().get_nodes_in_group("player")
	if player.size() > 0:
		player = player[0]
	else:
		player = null
		print("Chase enemy couldn't find player!")

func _physics_process(delta):
	if is_dead:
		return
		
	# Check for player detection and state transitions
	update_state()
	
	match current_state:
		State.IDLE:
			process_idle(delta)
		State.CHASE:
			process_chase(delta)
		State.ATTACK:
			process_attack(delta)
		State.STUNNED:
			process_stunned(delta)
	
	# Call parent to handle gravity and movement
	super._physics_process(delta)

func update_state():
	if is_dead or not player:
		return
		
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# State transitions
	match current_state:
		State.IDLE:
			if distance_to_player < detection_range:
				current_state = State.CHASE
				$AlertSound.play()
		State.CHASE:
			if distance_to_player > detection_range * 1.5:
				current_state = State.IDLE
			elif distance_to_player < attack_range:
				current_state = State.ATTACK
		State.ATTACK:
			if distance_to_player > attack_range * 1.2:
				current_state = State.CHASE
		State.STUNNED:
			# Stay stunned until the timer expires
			pass

func process_idle(_delta):
	# Simple idle behavior - just wait for player
	velocity.x = 0
	velocity.z = 0

func process_chase(delta):
	if not player:
		return
		
	# Get direction to player
	var direction = (player.global_position - global_position).normalized()
	direction.y = 0  # Keep enemy on ground
	
	# Set velocity based on direction
	velocity.x = direction.x * chase_speed
	velocity.z = direction.z * chase_speed
	
	# Rotate to face player
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 10.0)

func process_attack(delta):
	# Face the player
	if player:
		var direction = (player.global_position - global_position).normalized()
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 15.0)
	
	velocity.x = 0
	velocity.z = 0
	
	# Handle attack cooldown
	if not can_attack:
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			can_attack = true
			attack_timer = 0.0
			
	# Attack if possible
	if can_attack and player:
		attempt_attack()

func attempt_attack():
	can_attack = false
	attack_timer = 0.0
	
	# Visual attack feedback
	$AttackAnimation.play("attack")
	
	# Try to damage player
	if player and player.has_method("take_damage"):
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range * 1.2:
			player.take_damage(attack_damage)

func process_stunned(_delta):
	velocity.x = 0
	velocity.z = 0

func take_damage(amount):
	# Override parent method to add custom behavior
	print("Chase enemy taking damage: ", amount, " (Current health: ", health, ")")
	
	# Flash red when taking damage
	if $MeshInstance3D:
		var tween = create_tween()
		tween.tween_property($MeshInstance3D, "modulate", Color(1.5, 0.3, 0.3), 0.05)
		tween.tween_property($MeshInstance3D, "modulate", Color(1, 1, 1), 0.15)
	
	# Enter stunned state briefly
	current_state = State.STUNNED
	
	# Create stun timer to return to chase after short delay
	var stun_timer = get_tree().create_timer(0.5)
	stun_timer.timeout.connect(func(): current_state = State.CHASE)
	
	# Apply damage and check health
	health -= amount
	
	print("Chase enemy health after damage: ", health)
	
	if health <= 0:
		print("Chase enemy killed!")
		die()
	else:
		print("Chase enemy hurt but still alive with ", health, " health remaining")
