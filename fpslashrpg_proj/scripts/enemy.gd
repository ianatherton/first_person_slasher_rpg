extends CharacterBody3D

@export var max_health = 100
@export var move_speed = 2.0
@export var detection_range = 10.0
@export var attack_range = 1.5
@export var attack_damage = 10
@export var attack_cooldown = 1.0

var health = max_health
var player = null
var can_attack = true
var is_dead = false

# Navigation variables
var path_timer = 0.0
var path_update_interval = 1.0  # How often to recalculate path
var path = []
var navigation_agent: NavigationAgent3D

@onready var animation_player = $AnimationPlayer if has_node("AnimationPlayer") else null

func _ready():
	health = max_health
	
	# Set up navigation
	navigation_agent = NavigationAgent3D.new()
	add_child(navigation_agent)
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 1.0
	
	# Find the player
	player = get_tree().get_nodes_in_group("player")
	if player.size() > 0:
		player = player[0]
	else:
		player = null
		print("Enemy couldn't find player!")

func _physics_process(delta):
	if is_dead:
		return
	
	if player == null:
		player = get_tree().get_nodes_in_group("player")
		if player.size() > 0:
			player = player[0]
		else:
			return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# If within detection range, update path to player
	if distance_to_player < detection_range:
		path_timer += delta
		if path_timer >= path_update_interval:
			path_timer = 0
			navigation_agent.target_position = player.global_position
		
		# Move along the path
		if navigation_agent.is_navigation_finished():
			velocity = Vector3.ZERO
		else:
			var next_position = navigation_agent.get_next_path_position()
			var new_velocity = (next_position - global_position).normalized() * move_speed
			velocity = new_velocity
			
			# Look at player but only on the horizontal plane
			var look_position = player.global_position
			look_position.y = global_position.y
			look_at(look_position)
		
		# Attack if in range
		if distance_to_player <= attack_range and can_attack:
			attack()
	else:
		velocity = Vector3.ZERO
	
	move_and_slide()

func attack():
	can_attack = false
	
	# Play attack animation if available
	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")
	
	# Deal damage to player if in range
	if player and player.global_position.distance_to(global_position) <= attack_range:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)
	
	# Reset attack cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func take_damage(amount):
	if is_dead:
		return
	
	health -= amount
	print("Enemy took " + str(amount) + " damage! Health: " + str(health) + "/" + str(max_health))
	
	if health <= 0:
		die()
	else:
		# Play hit animation if available
		if animation_player and animation_player.has_animation("hit"):
			animation_player.play("hit")

func die():
	is_dead = true
	print("Enemy died!")
	
	# Play death animation if available
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")
		await animation_player.animation_finished
	
	# Alternatively, we could drop loot here
	
	# Remove the enemy from the scene
	queue_free()
