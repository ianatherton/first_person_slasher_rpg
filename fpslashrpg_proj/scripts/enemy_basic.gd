extends CharacterBody3D

@export var health = 1
@export var death_delay = 2.0  # Time before enemy is removed after death
@export var death_particles: PackedScene = null

signal enemy_died

var is_dead = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Add to enemy group for targeting
	add_to_group("enemy")
	
	# Randomize scale slightly for variety
	var scale_variation = randf_range(0.9, 1.1)
	scale = Vector3(scale_variation, scale_variation, scale_variation)
	
	# Debug message to verify the enemy is properly initialized
	print("Enemy initialized with health: ", health)

func _physics_process(delta):
	if is_dead:
		return
		
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	move_and_slide()

func take_damage(amount):
	if is_dead:
		return
		
	print("Enemy taking damage: ", amount)
	health -= amount
	
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
	emit_signal("enemy_died")
	print("Enemy death sequence initiated")
	
	# Disable collision
	$CollisionShape3D.disabled = true
	
	# Play death animation/effect
	if death_particles:
		var particles = death_particles.instantiate()
		get_parent().add_child(particles)
		particles.global_position = global_position + Vector3(0, 1, 0)
		particles.emitting = true
	
	# Visual death effect
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.5)
	tween.tween_callback(queue_free)
