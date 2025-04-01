extends Node3D

@export var damage = 25
@export var attack_range = 2.0
@export var attack_rate = 1.0  # attacks per second
@export var stamina_cost = 10
@export var model_node_path: String = ""  # Path to the 3D model
@export var swing_speed = 1.0  # Speed multiplier for swing animation
@export var recoil_strength = 0.7  # How strong the recoil effect is (0-1)
@export var recoil_duration = 0.15  # How long the recoil animation takes

# Weapon type enum - for animation and behavior
enum WeaponType {
	ONE_HANDED_CRUSH,
	ONE_HANDED_SLASH,
	TWO_HANDED
}

@export var weapon_type: WeaponType = WeaponType.ONE_HANDED_CRUSH

# Impact particle system reference
@export var impact_particle_scene: PackedScene = preload("res://scenes/effects/impact_particles.tscn")

# Collision exclusion list - for entities the weapon should not hit
@export var collision_exclusions = ["player", "Player", "PlayerBody", "self"]

var can_attack = true
var attack_timer = 0.0
var is_attacking = false
var interactables_hit = []  # Track what we've hit during the current swing

# Animation and impact feedback variables
var has_hit_target = false
var hit_recoil_active = false
var hit_recoil_progress = 0.0
var hit_position = Vector3.ZERO
var hit_normal = Vector3.ZERO

# Reference to components
@onready var anim_player = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var player = get_parent().get_parent()  # Assumes this is attached to Head node of player

# References to weapon components
var weapon_model: Node3D = null
var grip_area: Node3D = null
var hitbox: Area3D = null

# Public accessor to check attack status
func is_attack_in_progress() -> bool:
	return is_attacking

# Attack animations for one-handed crush and slash weapons
var attack_animations = {
	WeaponType.ONE_HANDED_CRUSH: [
		{
			"name": "overhead_smash",
			"origin": Vector3.ZERO,
			"target": Vector3(-1.2, 0.0, 0.2),   # Strong downward motion with slight rightward curve
			"duration": 0.8,  # Slower swing
			"position_offset_start": Vector3(0.0, 0.5, -0.1),  # Start high
			"position_offset_mid": Vector3(0.0, 0.65, -0.3),   # Higher at midpoint
			"position_offset_end": Vector3(0.0, -0.5, -0.4)    # Much lower end position
		},
		{
			"name": "overhead_left",
			"origin": Vector3.ZERO,
			"target": Vector3(-1.1, -0.15, 0.1),  # Downward with slight left angle
			"duration": 0.75,
			"position_offset_start": Vector3(-0.1, 0.5, -0.1),  # Start high, slight left
			"position_offset_mid": Vector3(-0.2, 0.6, -0.3),    # Higher at midpoint
			"position_offset_end": Vector3(-0.3, -0.5, -0.3)    # Much lower end position
		},
		{
			"name": "overhead_right",
			"origin": Vector3.ZERO,
			"target": Vector3(-1.1, 0.15, 0.1),  # Downward with slight right angle
			"duration": 0.75,
			"position_offset_start": Vector3(0.1, 0.5, -0.1),   # Start high, slight right
			"position_offset_mid": Vector3(0.2, 0.6, -0.3),     # Higher at midpoint
			"position_offset_end": Vector3(0.3, -0.5, -0.3)     # Much lower end position
		}
	],
	WeaponType.ONE_HANDED_SLASH: [
		{
			"name": "horizontal_slash_right",
			"origin": Vector3.ZERO,
			"target": Vector3(-0.3, 1.2, 0.2),   # Horizontal slash right to left
			"duration": 0.6,  # Faster than crush
			"position_offset_start": Vector3(0.3, 0.1, -0.1),  # Start right
			"position_offset_mid": Vector3(0.0, 0.2, -0.2),   # Middle position
			"position_offset_end": Vector3(-0.3, 0.1, -0.1)    # End left
		},
		{
			"name": "horizontal_slash_left",
			"origin": Vector3.ZERO,
			"target": Vector3(-0.3, -1.2, 0.2),  # Horizontal slash left to right
			"duration": 0.6,
			"position_offset_start": Vector3(-0.3, 0.1, -0.1),  # Start left
			"position_offset_mid": Vector3(0.0, 0.2, -0.2),    # Middle position
			"position_offset_end": Vector3(0.3, 0.1, -0.1)    # End right
		},
		{
			"name": "diagonal_slash",
			"origin": Vector3.ZERO,
			"target": Vector3(-0.8, 0.8, 0.2),  # Diagonal slash
			"duration": 0.65,
			"position_offset_start": Vector3(0.2, -0.2, -0.1),  # Start lower right
			"position_offset_mid": Vector3(0.0, 0.0, -0.2),     # Middle position
			"position_offset_end": Vector3(-0.2, 0.2, -0.1)     # End upper left
		},
		{
			"name": "wide_horizontal_sweep",
			"origin": Vector3.ZERO,
			"target": Vector3(-0.2, 1.5, 0.2),   # Wider horizontal sweep right to left
			"duration": 2.0,  # Much slower for smoother motion
			"position_offset_start": Vector3(0.4, 0.1, -0.2),  # Start right
			"position_offset_mid": Vector3(0.0, 0.15, -0.2),   # Minimal vertical movement
			"position_offset_end": Vector3(-0.4, 0.1, -0.2)    # End left, same height
		},
		{
			"name": "wide_horizontal_sweep_reverse",
			"origin": Vector3.ZERO,
			"target": Vector3(-0.2, -1.5, 0.2),  # Wider horizontal sweep left to right
			"duration": 2.0,  # Much slower for smoother motion
			"position_offset_start": Vector3(-0.4, 0.1, -0.2),  # Start left
			"position_offset_mid": Vector3(0.0, 0.15, -0.2),    # Minimal vertical movement
			"position_offset_end": Vector3(0.4, 0.1, -0.2)    # End right, same height
		},
		{
			"name": "heavy_diagonal_slash",
			"origin": Vector3.ZERO,
			"target": Vector3(-0.6, 1.0, 0.2),  # Diagonal slash
			"duration": 2.2,  # Very slow execution
			"position_offset_start": Vector3(0.3, -0.3, -0.2),  # Start lower right
			"position_offset_mid": Vector3(0.0, -0.15, -0.25),  # Gradual transition
			"position_offset_end": Vector3(-0.3, 0.3, -0.2)     # End upper left
		},
		{
			"name": "spinning_slash",
			"origin": Vector3.ZERO,
			"target": Vector3(-0.5, 2.5, 0.0),  # Full circular motion
			"duration": 2.5,  # Very slow spinning slash
			"position_offset_start": Vector3(0.3, 0.0, -0.2),   # Start position
			"position_offset_mid": Vector3(0.0, 0.25, -0.2),    # Minimal vertical change
			"position_offset_end": Vector3(-0.3, 0.0, -0.2)     # End position, same height as start
		}
	]
}

# Swing animation variables
var is_swinging = false
var swing_progress = 0.0
var swing_direction = 1
var swing_origin_rotation = Vector3.ZERO
var swing_target_rotation = Vector3.ZERO
var swing_origin_position = Vector3.ZERO
var swing_target_position = Vector3.ZERO
var animation_data = null  # Store the current animation data

func _ready():
	if model_node_path:
		# If a model path was provided, load the model
		load_model(model_node_path)
	else:
		# Otherwise, look for an existing model in our children
		for child in get_children():
			if "model" in child.name.to_lower() or child is MeshInstance3D:
				weapon_model = child
				break
	
	# Setup components to handle attacks and positioning
	setup_weapon_components()
	
	# If we have a grip area, position the weapon relative to it
	position_weapon()
	
	# Create an animation player if we don't have one
	if not anim_player:
		anim_player = AnimationPlayer.new()
		add_child(anim_player)
		create_attack_animations()
	
	# Enable monitoring on the hitbox area
	if hitbox:
		hitbox.monitorable = true
		hitbox.monitoring = true
		
		# Connect the signal for body entered (collision)
		if not hitbox.is_connected("body_entered", Callable(self, "_on_hitbox_body_entered")):
			hitbox.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
		
		print("Hitbox setup complete with collision detection")

func load_model(path: String) -> void:
	# Load and instance the specified model
	var model_scene = load(path)
	if model_scene:
		var model_instance = model_scene.instantiate()
		add_child(model_instance)
		
		# Find the main mesh in the model
		weapon_model = find_mesh_instance(model_instance)
		if not weapon_model:
			weapon_model = model_instance
		
		print("Loaded weapon model: ", path)
	else:
		printerr("ERROR: Failed to load weapon model from path: ", path)

func setup_weapon_components() -> void:
	print("Setting up weapon components...")
	
	# Find the model if it's not already assigned
	if not weapon_model:
		for child in get_children():
			if "model" in child.name.to_lower():
				weapon_model = child
				print("Found weapon model: ", child.name)
				break
	
	if not weapon_model:
		printerr("ERROR: Could not find weapon model!")
		return
		
	# Find grip area in the model
	grip_area = find_node_by_name(weapon_model, "mgrip")
	if grip_area:
		print("Found grip area: ", grip_area.name)
		make_node_invisible(grip_area)
	else:
		printerr("WARNING: No grip area found in weapon model")
	
	# Create a new hitbox area as a direct child of the weapon model
	# This ensures it moves with the model during animations
	create_hitbox()

func create_hitbox() -> void:
	print("Creating weapon hitbox...")
	
	# First, check if we already have a hitbox node
	var existing_hitbox = find_node_by_name(weapon_model, "hitbox")
	if existing_hitbox:
		print("Found existing hitbox node: ", existing_hitbox.name)
		
		# If it's already an Area3D, use it directly
		if existing_hitbox is Area3D:
			hitbox = existing_hitbox
			make_node_invisible(hitbox)
			print("Using existing Area3D hitbox")
		else:
			# Otherwise, create a new Area3D as a child of the existing hitbox
			hitbox = Area3D.new()
			hitbox.name = "HitboxArea"
			existing_hitbox.add_child(hitbox)
			
			# Make the original hitbox invisible but keep its functionality
			make_node_invisible(existing_hitbox)
			
			# Create collision shape
			var collision = create_collision_shape(existing_hitbox)
			hitbox.add_child(collision)
			print("Created hitbox as child of existing node")
	else:
		# No existing hitbox found, so create a new one
		hitbox = Area3D.new()
		hitbox.name = "WeaponHitbox"
		
		# Add it directly to the weapon model so it moves with animations
		if weapon_model:
			weapon_model.add_child(hitbox)
			
			# Create a collision shape for the hitbox
			var collision = create_collision_shape(weapon_model)
			hitbox.add_child(collision)
			print("Created new hitbox attached to weapon model")
		else:
			add_child(hitbox)
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(0.2, 0.2, 0.5)
			
			var collision = CollisionShape3D.new()
			collision.shape = box_shape
			hitbox.add_child(collision)
			print("Created fallback hitbox (no weapon model found)")
	
	# Configure the hitbox
	hitbox.collision_layer = 8  # Set to layer 4 for weapon
	hitbox.collision_mask = 7   # Set to detect layers 1, 2, and 3
	hitbox.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
	print("Hitbox configuration complete")

func create_collision_shape(source_node: Node) -> CollisionShape3D:
	var collision = CollisionShape3D.new()
	var shape = null
	
	# If the source is a MeshInstance3D, base the shape on its mesh
	if source_node is MeshInstance3D and source_node.mesh:
		var aabb = source_node.mesh.get_aabb()
		shape = BoxShape3D.new()
		shape.size = aabb.size
		
		# Adjust position to match the mesh's center
		collision.position = aabb.position + aabb.size/2
	else:
		# Create a custom shape for the weapon head
		shape = SphereShape3D.new()
		shape.radius = 0.3  # Size of the weapon head
		
		# Position at the end of the weapon
		if grip_area:
			var offset = grip_area.position.length()
			collision.position = Vector3(0, 0, -offset)
	
	collision.shape = shape
	return collision

func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var mesh = find_mesh_instance(child)
		if mesh:
			return mesh
	
	return null

func find_node_by_name(parent: Node, name_part: String) -> Node:
	if parent.name.to_lower().contains(name_part.to_lower()):
		return parent
		
	for child in parent.get_children():
		var found = find_node_by_name(child, name_part)
		if found:
			return found
	
	return null

func position_weapon() -> void:
	# If we have a grip area, position the weapon so the grip is at the origin
	if grip_area and weapon_model:
		# Calculate the offset from the grip to the model's origin
		var grip_local_pos = grip_area.position
		
		# Apply the inverse of this offset to position the weapon
		weapon_model.position = -grip_local_pos
		
		print("Positioned weapon based on grip area")
	else:
		print("No grip area found for positioning")
	
	# Reset rotation to default
	rotation = Vector3.ZERO

func _process(delta):
	# Process attack cooldown
	if not can_attack:
		attack_timer += delta
		if attack_timer >= 1.0 / attack_rate:
			can_attack = true
			attack_timer = 0.0
	
	# Process hit recoil animation (has priority over regular swing)
	if hit_recoil_active:
		hit_recoil_progress += delta / recoil_duration
		if hit_recoil_progress >= 1.0:
			hit_recoil_active = false
			hit_recoil_progress = 0.0
			is_swinging = false
			swing_progress = 0.0
			interactables_hit.clear()
			
			# Return to ready position
			if weapon_model:
				weapon_model.rotation = swing_origin_rotation
				weapon_model.position = swing_origin_position
		else:
			# Apply recoil animation - pulls back from the hit point
			apply_hit_recoil(hit_recoil_progress)
	
	# Process swing animation (only if not in recoil)
	elif is_swinging:
		# Calculate swing speed based on animation duration if available
		var speed_multiplier = 1.0
		if animation_data and animation_data.has("duration") and animation_data.duration > 0:
			# Use the inverse of duration to get the proper speed (longer duration = slower animation)
			speed_multiplier = 1.0 / animation_data.duration
		else:
			# Fallback to the old calculation if no duration is available
			speed_multiplier = 3.0 * swing_speed
		
		swing_progress += delta * speed_multiplier
		
		if swing_progress >= 1.0:
			is_swinging = false
			swing_progress = 0.0
			interactables_hit.clear()  # Reset hit objects
			
			# Print debug information about available hitbox
			if hitbox:
				print("Swing complete, hitbox at position: ", hitbox.global_position)
		
		# Apply interpolated rotation to the weapon model
		if weapon_model and not has_hit_target:
			var current_target_rotation = Vector3.ZERO
			var current_target_position = Vector3.ZERO
			
			if animation_data:
				if swing_progress < 0.5:
					current_target_rotation = animation_data.target * swing_progress * 2
					current_target_position = animation_data.position_offset_start + (animation_data.position_offset_mid - animation_data.position_offset_start) * swing_progress * 2
				else:
					current_target_rotation = animation_data.target - (animation_data.target - Vector3.ZERO) * (swing_progress - 0.5) * 2
					current_target_position = animation_data.position_offset_mid + (animation_data.position_offset_end - animation_data.position_offset_mid) * (swing_progress - 0.5) * 2
			
			weapon_model.rotation = lerp(
				swing_origin_rotation,
				current_target_rotation,
				ease_out_cubic(swing_progress)
			)
			weapon_model.position = lerp(
				swing_origin_position,
				current_target_position,
				ease_out_cubic(swing_progress)
			)

func apply_hit_recoil(progress: float) -> void:
	if not weapon_model:
		return
	
	# Calculate recoil animation - pulls back from the hit point
	var recoil_curve = ease_in_out_cubic(progress)
	
	# Create a recoil effect that pulls back initially then returns to start
	var recoil_factor = sin(progress * PI) * recoil_strength
	
	# Get the point where the weapon was in the swing when it hit
	var current_rotation = weapon_model.rotation
	var current_position = weapon_model.position
	
	# Pull back from impact point
	var recoil_rotation = current_rotation + Vector3(0.3, 0, -0.2) * recoil_factor
	var recoil_position = current_position + Vector3(0.1, 0.1, 0.2) * recoil_factor
	
	# Apply the recoil animation
	weapon_model.rotation = lerp(current_rotation, recoil_rotation, recoil_curve)
	weapon_model.position = lerp(current_position, recoil_position, recoil_curve)
	
	# Add slight shake at the peak of recoil
	if progress > 0.2 and progress < 0.8:
		var shake_intensity = 0.03 * recoil_strength * sin(progress * 50)
		weapon_model.rotation += Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)

func ease_out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3)

func ease_in_out_cubic(x: float) -> float:
	return 4 * x * x * x if x < 0.5 else 1 - pow(-2 * x + 2, 3) / 2

func attack():
	if is_attacking:
		return
		
	# Check if we have a player reference with stamina
	if player and player.has_method("use_stamina"):
		if not player.use_stamina(stamina_cost):
			return  # Not enough stamina
	
	is_attacking = true
	can_attack = false
	attack_timer = 0.0
	interactables_hit.clear()
	has_hit_target = false
	hit_recoil_active = false
	
	# Get a random attack animation for this weapon type
	var attack_type = choose_attack_animation()
	
	# Play attack animation if available
	if anim_player and anim_player.has_animation(attack_type):
		print("Playing animation: " + attack_type)
		anim_player.play(attack_type)
	else:
		# Perform manual swing animation with the chosen type
		start_swing_animation(attack_type)
	
	# Debug output for hitbox
	if hitbox:
		print("Attack started with hitbox at: ", hitbox.global_position)
	else:
		print("WARNING: No hitbox found for attack!")
	
	# Reset attacking state after animation completes
	await get_tree().create_timer(0.5).timeout
	is_attacking = false

func choose_attack_animation() -> String:
	# Choose randomly between available animations for this weapon type
	if weapon_type in attack_animations:
		var animations = attack_animations[weapon_type]
		var random_index = randi() % animations.size()
		return animations[random_index].name
	
	# Default fallback
	return "attack"

func start_swing_animation(attack_name: String = ""):
	# Start a manual swing animation if no animation player is available
	if not weapon_model:
		return
		
	is_swinging = true
	swing_progress = 0.0
	has_hit_target = false
	
	# Find the animation data
	animation_data = null
	if weapon_type in attack_animations:
		for anim in attack_animations[weapon_type]:
			if anim.name == attack_name or attack_name == "":
				animation_data = anim
				break
		
		# If no specific animation was found, use the first one
		if animation_data == null and attack_animations[weapon_type].size() > 0:
			animation_data = attack_animations[weapon_type][0]
	
	# Set origin and target rotations for the swing
	swing_origin_rotation = weapon_model.rotation
	swing_origin_position = weapon_model.position
	
	if animation_data:
		swing_target_rotation = animation_data.target
		swing_target_position = animation_data.position_offset_start
		print("Using animation: " + animation_data.name)
	else:
		# Default animation if none found
		swing_target_rotation = Vector3(
			swing_origin_rotation.x - 0.5,  # Swing down
			swing_origin_rotation.y,
			swing_origin_rotation.z + 1.2   # Swing to the right
		)
		swing_target_position = Vector3(0.0, 0.3, -0.4)
	
	# Add some slight random variation to make swings feel different
	swing_target_rotation += Vector3(
		randf_range(-0.1, 0.1),
		randf_range(-0.1, 0.1),
		randf_range(-0.1, 0.1)
	)

func create_attack_animations():
	# Create an animation library for the weapon
	var animation_library = AnimationLibrary.new()
	
	# Create animations for the current weapon type
	if weapon_type in attack_animations:
		var animations = attack_animations[weapon_type]
		
		for anim_data in animations:
			var animation = Animation.new()
			var track_idx = animation.add_track(Animation.TYPE_VALUE)
			
			# Get the proper path to the weapon model
			var anim_target_path = ""
			if weapon_model:
				anim_target_path = weapon_model.get_path()
				anim_target_path = NodePath(anim_target_path.get_concatenated_names())
				if anim_target_path.is_empty():
					anim_target_path = "%MorningStarModel"
			else:
				anim_target_path = "%MorningStarModel"
			
			# Target the weapon model's rotation
			animation.track_set_path(track_idx, str(anim_target_path) + ":rotation")
			animation.track_insert_key(track_idx, 0.0, Vector3.ZERO)
			
			# Wind-up phase
			animation.track_insert_key(track_idx, 0.1, Vector3(-anim_data.target.x * 0.3, 
															 -anim_data.target.y * 0.3, 
															 -anim_data.target.z * 0.3))
			
			# Attack phase
			animation.track_insert_key(track_idx, 0.2, anim_data.target)
			
			# Return to neutral
			animation.track_insert_key(track_idx, anim_data.duration, Vector3.ZERO)
			
			animation.length = anim_data.duration
			animation.loop_mode = Animation.LOOP_NONE
			
			# Add animation to the library
			animation_library.add_animation(anim_data.name, animation)
			print("Created animation: " + anim_data.name)
	
	# Add the animation library to the animation player
	if animation_library.get_animation_list().size() > 0:
		anim_player.add_animation_library("weapon_animations", animation_library)
		print("Added animation library with " + str(animation_library.get_animation_list().size()) + " animations")

func _on_hitbox_body_entered(body):
	if is_attacking and not body in interactables_hit:
		# Skip bodies in our exclusion list
		for exclusion in collision_exclusions:
			if body.is_in_group(exclusion) or body.name.to_lower().contains(exclusion.to_lower()):
				print("Skipping collision with excluded object: ", body.name)
				return
		
		# Add to hit list so we don't hit it again this swing
		interactables_hit.append(body)
		
		# Damage logic
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("Damaged: ", body.name)
		
		# Stop the current animation and start recoil animation
		has_hit_target = true
		
		# If using AnimationPlayer, stop it
		if anim_player and anim_player.is_playing():
			anim_player.stop()
		
		# Capture the current weapon state for recoil animation
		if weapon_model:
			hit_recoil_active = true
			hit_recoil_progress = 0.0
		
		# Handle impact effects
		var impact_type = determine_impact_type(body)
		spawn_impact_particles(body, impact_type)
		
		# Add screen shake or camera effect if this is the player's weapon
		if player and player.has_method("add_camera_shake"):
			player.add_camera_shake(0.2 * recoil_strength, 0.2)

# Determine impact type based on what was hit
func determine_impact_type(body) -> int:
	var body_name = body.name.to_lower()
	
	# Check for specific types based on name or groups
	if body.is_in_group("metal") or body_name.contains("metal"):
		return 1  # Metal
	elif body.is_in_group("stone") or body_name.contains("wall") or body_name.contains("floor") or body_name.contains("stone"):
		return 2  # Stone
	elif body.is_in_group("wood") or body_name.contains("wood"):
		return 3  # Wood
	elif body.is_in_group("enemy") or body.is_in_group("flesh") or body_name.contains("enemy"):
		return 4  # Flesh
	
	# Default impact type
	return 0  # Default

# Spawn impact particles at the hit location
func spawn_impact_particles(body, impact_type: int) -> void:
	if not impact_particle_scene:
		print("ERROR: No impact particle scene assigned!")
		return
		
	if not hitbox:
		print("ERROR: No hitbox to determine impact position!")
		return
	
	# Create particle instance
	var particles = impact_particle_scene.instantiate()
	get_tree().current_scene.add_child(particles)
	
	# IMPROVED: Find a better spawn position for particles within the hitbox bounds
	var impact_position = hitbox.global_position
	var direction = Vector3.ZERO
	
	# Get the hitbox collision shape for bounds calculation
	var hitbox_shape = null
	var hitbox_size = Vector3(0.2, 0.2, 0.2)  # Default size
	var hitbox_radius = 0.3  # Default radius
	
	for child in hitbox.get_children():
		if child is CollisionShape3D and child.shape:
			hitbox_shape = child.shape
			if hitbox_shape is BoxShape3D:
				hitbox_size = hitbox_shape.size
			elif hitbox_shape is SphereShape3D:
				hitbox_radius = hitbox_shape.radius
			break
			
	# Find closest point on body to use as reference
	var body_collision_point = null
	var closest_distance = 999999.0
	
	if body is CollisionObject3D:
		# Try to find the exact collision point using PhysicsBodyDirectSpaceState3D if available
		var space_state = get_world_3d().direct_space_state
		if space_state:
			# Define query parameters for a ray from hitbox to body center
			var query = PhysicsRayQueryParameters3D.new()
			query.from = hitbox.global_position
			query.to = body.global_position
			query.collision_mask = body.collision_layer
			query.collide_with_bodies = true
			query.exclude = [hitbox]
			
			# Perform the raycast
			var collision = space_state.intersect_ray(query)
			if collision and collision.has("position"):
				body_collision_point = collision.position
				direction = (body_collision_point - impact_position).normalized()
			else:
				# Fallback: Check all collision shapes in the body
				for child in body.get_children():
					if child is CollisionShape3D:
						var to_child_dir = (child.global_position - impact_position).normalized()
						var dist = child.global_position.distance_to(impact_position)
						
						if dist < closest_distance:
							closest_distance = dist
							body_collision_point = child.global_position
							direction = to_child_dir
		
	# If we couldn't find a good collision point, use body position
	if not body_collision_point:
		body_collision_point = body.global_position
		direction = (body_collision_point - impact_position).normalized()
	
	# Calculate offset from hitbox center based on shape
	var offset = Vector3.ZERO
	if hitbox_shape is BoxShape3D:
		# For box shapes, find a point on the surface in the direction of the hit
		offset.x = clamp(direction.x * hitbox_size.x * 0.5, -hitbox_size.x * 0.5, hitbox_size.x * 0.5)
		offset.y = clamp(direction.y * hitbox_size.y * 0.5, -hitbox_size.y * 0.5, hitbox_size.y * 0.5)
		offset.z = clamp(direction.z * hitbox_size.z * 0.5, -hitbox_size.z * 0.5, hitbox_size.z * 0.5)
	elif hitbox_shape is SphereShape3D:
		# For sphere shapes, find a point on the surface
		offset = direction * hitbox_radius
	
	# Add some randomization within bounds of the hitbox (25% of the way from center to edge)
	var rand_factor = 0.25
	if hitbox_shape is BoxShape3D:
		offset.x += randf_range(-hitbox_size.x * rand_factor, hitbox_size.x * rand_factor)
		offset.y += randf_range(-hitbox_size.y * rand_factor, hitbox_size.y * rand_factor)
		offset.z += randf_range(-hitbox_size.z * rand_factor, hitbox_size.z * rand_factor)
	elif hitbox_shape is SphereShape3D:
		offset += Vector3(
			randf_range(-hitbox_radius * rand_factor, hitbox_radius * rand_factor),
			randf_range(-hitbox_radius * rand_factor, hitbox_radius * rand_factor),
			randf_range(-hitbox_radius * rand_factor, hitbox_radius * rand_factor)
		)
	
	# Apply the offset to get the impact position
	impact_position += offset
	
	# Ensure particles don't spawn inside the hit body by pulling them slightly toward the weapon
	# Get the midpoint between current position and hitbox center, then move 10% toward weapon
	var safe_position = impact_position.lerp(hitbox.global_position, 0.1)
	particles.global_position = safe_position
	
	# Orient particles to face away from hitbox
	particles.look_at(particles.global_position + direction, Vector3.UP)
	
	# Play the impact effect with the determined type
	if particles.has_method("play_impact"):
		particles.play_impact(impact_type)
		print("Spawned impact particles of type: " + str(impact_type) + " at " + str(particles.global_position))

func make_node_invisible(node: Node) -> void:
	if node is MeshInstance3D:
		node.visible = false
	
	# Also set visibility of all mesh children to false
	for child in node.get_children():
		if child is MeshInstance3D:
			child.visible = false
		
		# Check grandchildren too
		for grandchild in child.get_children():
			if grandchild is MeshInstance3D:
				grandchild.visible = false
