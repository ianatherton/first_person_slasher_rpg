extends CharacterBody3D

@export var max_health = 100
@export var move_speed = 2.0
@export var detection_range = 10.0
@export var attack_range = 1.5
@export var attack_damage = 10
@export var attack_cooldown = 1.0
@export var path_update_interval = 1.0  # How often to recalculate path

var health = max_health
var player = null
var can_attack = true
var is_dead = false
var player_detected = false

# Navigation variables
var navigation_agent: NavigationAgent3D
var path_update_timer: Timer

@onready var animation_player = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var events = get_node("/root/Events")
@onready var game_state = get_node("/root/GameState")

func _ready():
	health = max_health
	
	# Set up navigation
	navigation_agent = NavigationAgent3D.new()
	add_child(navigation_agent)
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 1.0
	
	# Set up path update timer
	path_update_timer = Timer.new()
	path_update_timer.wait_time = path_update_interval
	path_update_timer.autostart = false
	path_update_timer.one_shot = false
	add_child(path_update_timer)
	path_update_timer.timeout.connect(Callable(self, "_on_path_update_timer_timeout"))
	
	# Create detection area
	var detection_area = Area3D.new()
	detection_area.name = "DetectionArea"
	add_child(detection_area)
	
	# Add collision shape to detection area
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = detection_range
	collision_shape.shape = sphere_shape
	detection_area.add_child(collision_shape)
	
	# Connect signals for player detection
	detection_area.body_entered.connect(Callable(self, "_on_detection_area_body_entered"))
	detection_area.body_exited.connect(Callable(self, "_on_detection_area_body_exited"))
	
	# Create attack area
	var attack_area = Area3D.new()
	attack_area.name = "AttackArea"
	add_child(attack_area)
	
	# Add collision shape to attack area
	var attack_collision = CollisionShape3D.new()
	var attack_sphere = SphereShape3D.new()
	attack_sphere.radius = attack_range
	attack_collision.shape = attack_sphere
	attack_area.add_child(attack_collision)
	
	# Connect signals for attack range detection
	attack_area.body_entered.connect(Callable(self, "_on_attack_area_body_entered"))
	attack_area.body_exited.connect(Callable(self, "_on_attack_area_body_exited"))

func _physics_process(_delta):
	if is_dead or game_state.game_paused:
		return
	
	if player_detected and player:
		# Move along the path if player is detected
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
	else:
		velocity = Vector3.ZERO
	
	move_and_slide()

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body
		player_detected = true
		events.emit_signal("enemy_detected_player", self)
		print("Player detected by " + name)
		
		# Start path updates when player is detected
		_update_path_to_player()
		path_update_timer.start()

func _on_detection_area_body_exited(body):
	if body.is_in_group("player") and body == player:
		player_detected = false
		path_update_timer.stop()
		print("Player lost by " + name)

func _on_attack_area_body_entered(body):
	if body.is_in_group("player") and can_attack:
		attack()

func _on_path_update_timer_timeout():
	if player_detected and player:
		_update_path_to_player()

func _update_path_to_player():
	if player:
		navigation_agent.target_position = player.global_position

func attack():
	can_attack = false
	
	# Play attack animation if available
	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")
	
	# Deal damage to player
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)
		# Emit attack signal
		events.emit_signal("enemy_attacked", self, player, attack_damage)
	
	# Reset attack cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func take_damage(amount):
	if is_dead:
		return
	
	health -= amount
	print("Enemy took " + str(amount) + " damage! Health: " + str(health) + "/" + str(max_health))
	
	# Emit signal for taking damage
	events.emit_signal("enemy_damaged", self, amount)
	
	if health <= 0:
		die()
	else:
		# Play hit animation if available
		if animation_player and animation_player.has_animation("hit"):
			animation_player.play("hit")

func die():
	is_dead = true
	print("Enemy died!")
	
	# Emit death signal
	events.emit_signal("enemy_died", self)
	
	# Disable detection and collision
	$CollisionShape3D.disabled = true
	if has_node("DetectionArea"):
		$DetectionArea.monitoring = false
		$DetectionArea.monitorable = false
	if has_node("AttackArea"):
		$AttackArea.monitoring = false
		$AttackArea.monitorable = false
	
	# Stop path updates
	path_update_timer.stop()
	
	# Play death animation if available
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")
		await animation_player.animation_finished
	
	# Remove the enemy from the scene
	queue_free()
