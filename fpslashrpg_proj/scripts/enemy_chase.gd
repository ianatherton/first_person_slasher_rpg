extends "res://scripts/enemy_basic.gd"

@export var chase_speed = 3.0       # Movement speed when chasing
@export var aggression = 1.5        # Higher values make the enemy more aggressive
@export var attack_cooldown = 1.0   # Time between attacks
@export var attack_damage = 10      # Damage dealt to player

var can_attack = true
var attack_timer = 0.0
var current_state = State.IDLE
var stun_timer = null
var attack_area: Area3D

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
	
	# Create stun timer
	stun_timer = Timer.new()
	stun_timer.one_shot = true
	add_child(stun_timer)
	stun_timer.timeout.connect(Callable(self, "_on_stun_timer_timeout"))
	
	# Create attack area - we need a smaller, more precise one than the parent
	attack_area = Area3D.new()
	attack_area.name = "ChaseAttackArea"
	add_child(attack_area)
	
	# Add collision shape to attack area
	var attack_collision = CollisionShape3D.new()
	var attack_sphere = SphereShape3D.new()
	attack_sphere.radius = 1.5  # Attack range
	attack_collision.shape = attack_sphere
	attack_area.add_child(attack_collision)
	
	# Connect signals for attack range detection
	attack_area.body_entered.connect(Callable(self, "_on_chase_attack_area_body_entered"))

func _physics_process(_delta):
	if is_dead or get_node("/root/GameState").game_paused:
		return
	
	match current_state:
		State.IDLE:
			process_idle()
		State.CHASE:
			process_chase(_delta)
		State.ATTACK:
			process_attack(_delta)
		State.STUNNED:
			process_stunned()
	
	# Call parent to handle gravity and movement
	super._physics_process(_delta)

# Override the parent's detection method
func _on_detection_area_body_entered(body):
	super._on_detection_area_body_entered(body)
	
	if body.is_in_group("player"):
		current_state = State.CHASE
		if has_node("AlertSound"):
			$AlertSound.play()

# Override the parent's detection exit method
func _on_detection_area_body_exited(body):
	super._on_detection_area_body_exited(body)
	
	if body.is_in_group("player") and body == player:
		current_state = State.IDLE

func _on_chase_attack_area_body_entered(body):
	if body.is_in_group("player") and body == player and current_state == State.CHASE:
		current_state = State.ATTACK

func process_idle():
	# Simple idle behavior - just wait for player detection
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
		
	# Check if player moved out of range
	if player and global_position.distance_to(player.global_position) > 2.0:
		current_state = State.CHASE

func attempt_attack():
	can_attack = false
	attack_timer = 0.0
	
	# Visual attack feedback
	if has_node("AttackAnimation"):
		$AttackAnimation.play("attack")
	
	# Try to damage player
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)
		# Signal attack
		get_node("/root/Events").emit_signal("enemy_attacked", self, player, attack_damage)

func process_stunned():
	velocity.x = 0
	velocity.z = 0

func take_damage(amount):
	# Call the parent method first to handle basic damage functionality
	super.take_damage(amount)
	
	# Flash red when taking damage (this is in addition to parent's handling)
	if $MeshInstance3D:
		var tween = create_tween()
		tween.tween_property($MeshInstance3D, "modulate", Color(1, 0.3, 0.3), 0.1)
		tween.tween_property($MeshInstance3D, "modulate", Color(1, 1, 1), 0.1)
	
	# Stun the enemy when taking damage
	current_state = State.STUNNED
	stun_timer.start(0.5)  # Stun for half a second
	if has_node("StunEffect"):
		$StunEffect.emitting = true

func _on_stun_timer_timeout():
	if not is_dead and player_detected:
		current_state = State.CHASE
	else:
		current_state = State.IDLE
