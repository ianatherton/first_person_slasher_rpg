extends Node3D

@export var damage = 25
@export var attack_range = 2.0
@export var attack_rate = 1.0  # attacks per second
@export var stamina_cost = 10
@export var model_path: String = ""  # Path to the 3D model
@export var swing_speed = 1.0  # Speed multiplier for swing animation

# Weapon type enum - for animation and behavior
enum WeaponType {
	ONE_HANDED_CRUSH,
	ONE_HANDED_SLASH,
	TWO_HANDED
}

@export var weapon_type: WeaponType = WeaponType.ONE_HANDED_CRUSH

# Impact particle system reference
@export var impact_particle_scene: PackedScene = preload("res://scenes/effects/impact_particles.tscn")

var can_attack = true
var attack_timer = 0.0
var is_attacking = false
var interactables_hit = []  # Track objects already hit in a single swing

# Reference to components
@onready var anim_player = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var player = get_parent().get_parent()  # Assumes this is attached to Head node of player

# References to weapon components
var weapon_model: Node3D = null
var grip_area: Node3D = null
var hitbox: Area3D = null

# Attack animations for one-handed crush weapons
var attack_animations = {
	WeaponType.ONE_HANDED_CRUSH: [
		{
			"name": "overhead_smash",
			"origin": Vector3.ZERO,
			"target": Vector3(-0.8, 0.0, 0.3),   # Downward motion with slight rightward curve
			"duration": 0.5
		},
		{
			"name": "side_swing",
			"origin": Vector3.ZERO,
			"target": Vector3(-0.3, -0.2, 1.0),  # Horizontal swing from left to right
			"duration": 0.5
		}
	]
}

# Swing animation variables
var is_swinging = false
var swing_progress = 0.0
var swing_direction = 1
var swing_origin_rotation = Vector3.ZERO
var swing_target_rotation = Vector3.ZERO

func _ready():
	if model_path:
		# If a model path was provided, load the model
		load_model(model_path)
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
		if not hitbox.is_connected("body_entered", _on_hitbox_body_entered):
			hitbox.connect("body_entered", _on_hitbox_body_entered)
		
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
	hitbox.collision_layer = 2  # Set to appropriate collision layer
	hitbox.collision_mask = 1   # Set to detect objects on layer 1
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
	
	# Process swing animation
	if is_swinging:
		swing_progress += delta * 3.0 * swing_speed
		if swing_progress >= 1.0:
			is_swinging = false
			swing_progress = 0.0
			interactables_hit.clear()  # Reset hit objects
			
			# Print debug information about available hitbox
			if hitbox:
				print("Swing complete, hitbox at position: ", hitbox.global_position)
		
		# Apply interpolated rotation to the weapon model
		if weapon_model:
			weapon_model.rotation = lerp(
				swing_origin_rotation,
				swing_target_rotation,
				ease_out_cubic(swing_progress)
			)

func ease_out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3)

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
	
	# Find the animation data
	var animation_data = null
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
	
	if animation_data:
		swing_target_rotation = animation_data.target
		print("Using animation: " + animation_data.name)
	else:
		# Default animation if none found
		swing_target_rotation = Vector3(
			swing_origin_rotation.x - 0.5,  # Swing down
			swing_origin_rotation.y,
			swing_origin_rotation.z + 1.2   # Swing to the right
		)
	
	# Add some slight random variation to make swings feel different
	swing_target_rotation += Vector3(
		randf_range(-0.1, 0.1),
		randf_range(-0.1, 0.1),
		randf_range(-0.1, 0.1)
	)

func create_attack_animations():
	# Create animations for the current weapon type
	if weapon_type in attack_animations:
		var animations = attack_animations[weapon_type]
		
		for anim_data in animations:
			var animation = Animation.new()
			var track_idx = animation.add_track(Animation.TYPE_VALUE)
			
			# Target the weapon model's rotation
			animation.track_set_path(track_idx, "%MorningStarModel:rotation")
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
			
			anim_player.add_animation(anim_data.name, animation)
			print("Created animation: " + anim_data.name)

func _on_hitbox_body_entered(body):
	print("Hitbox detected collision with: " + body.name)
	
	# Prevents hitting the same object multiple times in a single swing
	if body in interactables_hit:
		print("Already hit this object in this swing, ignoring")
		return
		
	if is_attacking and body != player:
		print("Valid hit on: " + body.name)
		
		# Determine impact type based on what was hit
		var impact_type = determine_impact_type(body)
		
		# Create impact particles at hit location
		spawn_impact_particles(body, impact_type)
		
		# Handle damage or interaction
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("Hit enemy with weapon!")
		elif body.has_method("interact"):
			body.interact()
		
		# Add to list of hit objects for this swing
		interactables_hit.append(body)

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
	
	# Position at impact point - use hitbox position for now
	# In a full physics system, we would get the exact contact point
	var impact_position = hitbox.global_position
	
	# If the body has a collision shape, use its position for better precision
	if body is CollisionObject3D:
		for child in body.get_children():
			if child is CollisionShape3D:
				# Position particles at halfway point between hitbox and collision shape
				impact_position = (hitbox.global_position + child.global_position) / 2
				break
	
	particles.global_position = impact_position
	
	# Orient particles to face away from hitbox
	var direction = (impact_position - global_position).normalized()
	particles.look_at(particles.global_position + direction, Vector3.UP)
	
	# Play the impact effect with the determined type
	if particles.has_method("play_impact"):
		particles.play_impact(impact_type)
		print("Spawned impact particles of type: " + str(impact_type) + " at " + str(impact_position))

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
