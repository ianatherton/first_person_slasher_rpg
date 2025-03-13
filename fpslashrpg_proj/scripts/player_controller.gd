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
@export var attack_stamina_cost = 25.0  # Cost per attack

@onready var camera = $Head/Camera3D
@onready var head = $Head
@onready var weapon_holder = $Head/WeaponHolder
@onready var current_weapon = $Head/WeaponHolder/MorningStar  # Updated to match actual node name
@onready var player_hud = $Head/Camera3D/PlayerHUD

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_sprinting = false
var stamina = max_stamina
var stamina_regen_timer = 0.0
var health = 100

# Weapon variables
var weapons = []
var current_weapon_index = 0

signal stamina_changed(current, maximum)
signal health_changed(current, maximum)

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
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

func _input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Weapon switching - temporarily commented out until we define the actions
	# if event.is_action_pressed("next_weapon"):
	# 	switch_weapon(1)
	# elif event.is_action_pressed("prev_weapon"):
	# 	switch_weapon(-1)
		
	# Attack with left mouse button
	if event.is_action_pressed("attack"):
		perform_attack()
		
	# Toggle debug info with F3 key
	if event is InputEventKey and event.keycode == KEY_F3 and event.pressed and not event.echo:
		if player_hud and player_hud.has_method("toggle_debug_info"):
			var debug_enabled = player_hud.toggle_debug_info()
			print("Debug info " + ("enabled" if debug_enabled else "disabled"))

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if use_stamina(20):  # Jump costs stamina
			velocity.y = jump_velocity
	
	# Handle sprinting and stamina
	process_stamina(delta)
	
	# Calculate speed based on sprint state
	var current_speed = speed * (sprint_speed_multiplier if is_sprinting else 1.0)
	
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

func process_stamina(delta):
	is_sprinting = Input.is_action_pressed("sprint") and Input.is_action_pressed("move_forward") and stamina > 0
	
	if is_sprinting:
		stamina = max(0, stamina - sprint_stamina_cost * delta)
		stamina_regen_timer = 0
		emit_signal("stamina_changed", stamina, max_stamina)
	else:
		# Only regenerate after delay
		if stamina < max_stamina:
			stamina_regen_timer += delta
			if stamina_regen_timer >= stamina_regen_delay:
				stamina = min(max_stamina, stamina + stamina_regen_rate * delta)
				emit_signal("stamina_changed", stamina, max_stamina)

func use_stamina(amount):
	if stamina >= amount:
		stamina -= amount
		stamina_regen_timer = 0
		emit_signal("stamina_changed", stamina, max_stamina)
		return true
	return false

func take_damage(amount):
	health -= amount
	emit_signal("health_changed", health, 100)
	print("Player took " + str(amount) + " damage! Health: " + str(health))
	
	if health <= 0:
		die()

func die():
	print("Player died!")
	# Could implement respawn or game over logic here

func switch_weapon(direction):
	if weapons.size() <= 1:
		return  # Only one or no weapons
	
	# Hide current weapon
	if current_weapon:
		current_weapon.visible = false
	
	# Update index with wrap-around
	current_weapon_index = (current_weapon_index + direction) % weapons.size()
	if current_weapon_index < 0:
		current_weapon_index = weapons.size() - 1
	
	# Update reference and show weapon
	current_weapon = weapons[current_weapon_index]
	current_weapon.visible = true

func perform_attack():
	print("Attempting to attack!")
	
	# Check if we have a valid weapon
	if current_weapon and current_weapon.has_method("attack"):
		# Check stamina cost
		if use_stamina(attack_stamina_cost):
			print("Attack executed with " + current_weapon.name)
			current_weapon.attack()
		else:
			print("Not enough stamina to attack!")
	else:
		print("No valid weapon to attack with!")
