extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5
@export var mouse_sensitivity = 0.002
@export var sprint_speed_multiplier = 1.5

# Stamina system
@export var max_stamina = 100.0
@export var stamina_regen_rate = 10.0  # Per second
@export var sprint_stamina_cost = 15.0  # Per second
@export var stamina_regen_delay = 1.0  # Seconds to wait before regen starts
@export var attack_stamina_cost = 10.0  # Cost per attack

@onready var camera = $Head/Camera3D
@onready var head = $Head
@onready var weapon_holder = $Head/Camera3D/WeaponHolder
@onready var current_weapon = $Head/Camera3D/WeaponHolder/MorningStar
@onready var player_hud = $Head/Camera3D/PlayerHUD
@onready var movement_animations = $MovementAnimations
@onready var game_state = get_node("/root/GameState")
@onready var events = get_node("/root/Events")

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_sprinting = false
var stamina = 0.0
var stamina_regen_timer = 0.0
var health = 0

# Weapon variables
var weapons = []
var current_weapon_index = 0

# Movement state tracking
enum MovementState { IDLE, WALKING, SPRINTING }
var current_movement_state = MovementState.IDLE
var last_movement_state = MovementState.IDLE

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Set initial health and stamina from GameState
	health = game_state.player_health
	stamina = game_state.player_stamina
	max_stamina = game_state.player_max_stamina
	
	# Apply player's stamina settings to GameState
	game_state.set_max_stamina(max_stamina)
	game_state.stamina_regen_rate = stamina_regen_rate
	
	# Initialize weapons array with any weapons already in the holder
	for child in weapon_holder.get_children():
		if child.has_method("attack"):
			weapons.append(child)
			print("Added weapon to array: " + child.name)
	
	if weapons.size() > 0:
		current_weapon = weapons[0]
		print("Current weapon set to: " + current_weapon.name)
	else:
		print("Warning: No weapons found in weapon holder")
	
	# Add player to the "player" group so enemies can find it
	add_to_group("player")
	
	# Start in idle animation
	movement_animations.play("idle")
	
	# Connect to GameState signals
	events.connect("player_health_changed", Callable(self, "_on_health_changed"))
	events.connect("player_stamina_changed", Callable(self, "_on_stamina_changed"))

func _input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			game_state.pause_game(true)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			game_state.pause_game(false)
	
	# Weapon switching
	if event.is_action_pressed("next_weapon"):
		switch_weapon(1)
	elif event.is_action_pressed("prev_weapon"):
		switch_weapon(-1)
		
	# Attack with left mouse button
	if event.is_action_pressed("attack"):
		perform_attack()
		
	# Toggle debug info with F3 key
	if event is InputEventKey and event.keycode == KEY_F3 and event.pressed and not event.echo:
		if player_hud and player_hud.has_method("toggle_debug_info"):
			var debug_enabled = player_hud.toggle_debug_info()
			print("Debug info " + ("enabled" if debug_enabled else "disabled"))

func _process(_delta):
	if game_state.game_paused:
		return
		
	# Update GameState stamina
	game_state.set_stamina(stamina)
	
	# Check for weapon switching
	if Input.is_action_just_pressed("next_weapon"):
		switch_weapon(1)
	elif Input.is_action_just_pressed("prev_weapon"):
		switch_weapon(-1)
	
	# Debug info toggle
	if Input.is_action_just_pressed("toggle_debug") and player_hud:
		var debug_state = player_hud.toggle_debug_info()
		print("Debug info: " + ("ON" if debug_state else "OFF"))
		
	# Advanced metrics toggle
	if Input.is_action_just_pressed("toggle_advanced_metrics") and player_hud:
		var metrics_state = player_hud.toggle_advanced_metrics()
		print("Advanced metrics: " + ("ON" if metrics_state else "OFF"))

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if game_state.use_stamina(20):  # Jump costs stamina
			velocity.y = jump_velocity
	
	# Handle sprinting and stamina
	process_stamina(delta)
	
	# Calculate speed based on sprint state and attack state
	var current_speed = speed
	var weapon = $Head/Camera3D/WeaponHolder/MorningStar
	var attack_speed_penalty = 0.5 # 50% speed during attacks
	
	# Apply sprint multiplier if sprinting
	if is_sprinting:
		current_speed *= sprint_speed_multiplier
	
	# Apply attack speed penalty if attacking
	if weapon and weapon.has_method("is_attack_in_progress") and weapon.is_attack_in_progress():
		current_speed *= attack_speed_penalty

	# Movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	move_and_slide()
	
	# Update movement state and animations
	update_movement_state(direction)

func update_movement_state(direction):
	# Determine current movement state
	last_movement_state = current_movement_state
	
	if direction.length() < 0.1:
		current_movement_state = MovementState.IDLE
	elif is_sprinting:
		current_movement_state = MovementState.SPRINTING
	else:
		current_movement_state = MovementState.WALKING
	
	# Update animations based on movement state
	if current_movement_state != last_movement_state:
		match current_movement_state:
			MovementState.IDLE:
				movement_animations.play("idle")
			MovementState.WALKING:
				movement_animations.play("walk")
			MovementState.SPRINTING:
				movement_animations.play("sprint")
	
	# Adjust animation speed based on movement speed
	if current_movement_state == MovementState.SPRINTING:
		movement_animations.speed_scale = 1.5
	elif current_movement_state == MovementState.WALKING:
		# Calculate a smooth speed scale based on input magnitude
		var input_magnitude = direction.length()
		movement_animations.speed_scale = max(0.7, input_magnitude)
	else:
		movement_animations.speed_scale = 1.0

func process_stamina(delta):
	is_sprinting = Input.is_action_pressed("sprint") and Input.is_action_pressed("move_forward") and stamina > 0
	
	if is_sprinting:
		if game_state.use_stamina(sprint_stamina_cost * delta):
			stamina = game_state.player_stamina
			stamina_regen_timer = 0
	else:
		# We don't need to regenerate stamina here anymore as it's handled by GameState
		stamina = game_state.player_stamina

func _on_health_changed(new_health, max_health_value):
	health = new_health
	if player_hud and player_hud.has_method("update_health"):
		player_hud.update_health(health, max_health_value)

func _on_stamina_changed(new_stamina, max_stamina_value):
	stamina = new_stamina
	if player_hud and player_hud.has_method("update_stamina"):
		player_hud.update_stamina(stamina, max_stamina_value)

func take_damage(amount):
	game_state.damage_player(amount)
	print("Player took " + str(amount) + " damage! Health: " + str(health))

func perform_attack():
	if current_weapon and current_weapon.has_method("attack"):
		# Check if we can afford the stamina cost
		if game_state.use_stamina(attack_stamina_cost):
			current_weapon.attack()
			events.emit_signal("player_attacked", current_weapon)

func switch_weapon(direction):
	if weapons.size() <= 1:
		return  # Only one or no weapons
	
	# Hide current weapon
	if current_weapon:
		current_weapon.visible = false
	
	# Calculate new index with wrap-around
	current_weapon_index = (current_weapon_index + direction) % weapons.size()
	if current_weapon_index < 0:
		current_weapon_index = weapons.size() - 1
	
	# Set and show new weapon
	current_weapon = weapons[current_weapon_index]
	current_weapon.visible = true
	
	print("Switched to weapon: " + current_weapon.name)
	events.emit_signal("player_weapon_changed", current_weapon_index)
