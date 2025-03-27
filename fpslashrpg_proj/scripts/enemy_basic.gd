extends CharacterBody3D

@export var health = 1
@export var death_delay = 2.0  # Time before enemy is removed after death
@export var death_particles: PackedScene = null
@export var detection_radius = 10.0  # Used for the detection area size

# Use Events system instead of direct signals
@onready var events = get_node("/root/Events")
@onready var game_state = get_node("/root/GameState")

var is_dead = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player_detected = false
var player = null

func _ready():
	# Add to enemy group for targeting
	add_to_group("enemy")
	
	# Randomize scale slightly for variety
	var scale_variation = randf_range(0.9, 1.1)
	scale = Vector3(scale_variation, scale_variation, scale_variation)
	
	# Create detection area
	var detection_area = Area3D.new()
	detection_area.name = "DetectionArea"
	add_child(detection_area)
	
	# Add collision shape to detection area
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = detection_radius
	collision_shape.shape = sphere_shape
	detection_area.add_child(collision_shape)
	
	# Connect signals for player detection
	detection_area.body_entered.connect(Callable(self, "_on_detection_area_body_entered"))
	detection_area.body_exited.connect(Callable(self, "_on_detection_area_body_exited"))
	
	# Debug message to verify the enemy is properly initialized
	print("Enemy initialized with health: ", health)

func _physics_process(delta):
	if is_dead or game_state.game_paused:
		return
		
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	move_and_slide()

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body
		player_detected = true
		events.emit_signal("enemy_detected_player", self)
		print("Player detected by " + name)

func _on_detection_area_body_exited(body):
	if body.is_in_group("player") and body == player:
		player_detected = false
		print("Player lost by " + name)

func take_damage(amount):
	if is_dead:
		return
		
	print("Enemy taking damage: ", amount)
	health -= amount
	
	# Emit damage signal through Events
	events.emit_signal("enemy_damaged", self, amount)
	
	# Flash the mesh to indicate hit
	if $MeshInstance3D:
		var tween = create_tween()
		tween.tween_property($MeshInstance3D, "modulate", Color(1, 0.3, 0.3), 0.05)
		tween.tween_property($MeshInstance3D, "modulate", Color(1, 1, 1), 0.05)
	
	if health <= 0:
		print("Enemy killed!")
		die()

func die():
	is_dead = true
	
	# Emit death signal through Events
	events.emit_signal("enemy_died", self)
	
	# Disable collision
	$CollisionShape3D.disabled = true
	if has_node("DetectionArea"):
		$DetectionArea.monitoring = false
		$DetectionArea.monitorable = false
	
	# Spawn death particles if available
	if death_particles:
		var particles_instance = death_particles.instantiate()
		get_parent().add_child(particles_instance)
		particles_instance.global_position = global_position
		particles_instance.emitting = true
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.0)
	
	# Remove after delay
	await get_tree().create_timer(death_delay).timeout
	queue_free()
