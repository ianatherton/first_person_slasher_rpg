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

var can_attack = true
var attack_timer = 0.0
var is_attacking = false
var interactables_hit = []  # Track objects already hit in a single swing

# Reference to components
@onready var anim_player = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var player = get_parent().get_parent()  # Assumes this is attached to Head node of player

# References to weapon components
var grip_area: Node3D = null
var hitbox: Area3D = null
var weapon_model: Node3D = null

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
		weapon_model = find_mesh_instance(self)
	
	# Setup components to handle attacks and positioning
	find_weapon_components()
	
	# If we have a grip area, position the weapon relative to it
	position_weapon()
	
	# Create an animation player if we don't have one
	if not anim_player:
		anim_player = AnimationPlayer.new()
		add_child(anim_player)
		create_attack_animations()
		
	# Ensure the hitbox is properly connected for collision detection
	if hitbox and not hitbox.is_connected("body_entered", _on_hitbox_body_entered):
		hitbox.connect("body_entered", _on_hitbox_body_entered)

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

func find_weapon_components() -> void:
	# Look for the grip area and hitbox in our children
	var grip_node = find_node_recursive(self, "Grip")
	if not grip_node:
		grip_node = find_node_recursive(self, "GripArea")
	if not grip_node:
		grip_node = find_node_recursive(self, "mgrip")
	
	grip_area = grip_node  # This ensures grip_area is only assigned a Node3D or null, never a boolean
	
	# Make grip area invisible but keep its functionality
	if grip_area:
		print("Found grip area: ", grip_area.name)
		make_node_invisible(grip_area)
	else:
		printerr("WARNING: No grip area found in weapon model")
	
	# For the hitbox, look for specific names or create one if not found
	var hitbox_node = find_node_recursive(self, "HitBox") 
	if not hitbox_node:
		hitbox_node = find_node_recursive(self, "hitbox")
	if not hitbox_node:
		hitbox_node = find_node_recursive(self, "DamagingArea")
	
	# Make hitbox node invisible but keep its functionality
	if hitbox_node:
		make_node_invisible(hitbox_node)
		
	# If hitbox exists but is not an Area3D, create an Area3D as a child of it
	if hitbox_node and not hitbox_node is Area3D:
		hitbox = Area3D.new()
		hitbox.name = "HitboxArea"
		hitbox_node.add_child(hitbox)
		
		# Create collision shape for hitbox
		create_hitbox_collision(hitbox, hitbox_node)
	elif hitbox_node and hitbox_node is Area3D:
		hitbox = hitbox_node
	else:
		# No hitbox found, try to create one based on the model
		printerr("WARNING: No hitbox found in weapon model, attempting to create one")
		var mesh_instance = find_mesh_instance(self)
		
		if mesh_instance:
			hitbox = Area3D.new()
			hitbox.name = "HitboxArea"
			add_child(hitbox)
			create_hitbox_collision(hitbox, mesh_instance)
		else:
			printerr("ERROR: Could not find mesh to create hitbox from")
	
	# Connect signals for hitbox
	if hitbox:
		print("Hitbox configured: ", hitbox.name)
		if not hitbox.is_connected("body_entered", _on_hitbox_body_entered):
			hitbox.connect("body_entered", _on_hitbox_body_entered)
	else:
		printerr("ERROR: Failed to create or find hitbox")

func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var mesh = find_mesh_instance(child)
		if mesh:
			return mesh
	
	return null

func create_hitbox_collision(hitbox_area: Area3D, source_node: Node) -> void:
	# Create collision shape based on the source node
	var collision_shape = CollisionShape3D.new()
	var shape
	
	if source_node is MeshInstance3D and source_node.mesh:
		# Create shape based on mesh AABB
		var aabb = source_node.mesh.get_aabb()
		shape = BoxShape3D.new()
		shape.size = aabb.size
		
		# Position the collision shape to match the mesh
		collision_shape.position = aabb.position + aabb.size/2
	else:
		# Generic shape as fallback
		shape = BoxShape3D.new()
		shape.size = Vector3(0.2, 0.2, 0.2)
	
	collision_shape.shape = shape
	
	# Make collision shape invisible
	collision_shape.visible = false
	
	hitbox_area.add_child(collision_shape)

func position_weapon() -> void:
	# If we have a grip area, position the weapon so the grip is at the origin
	if grip_area:
		# Move the weapon model so the grip area is at the origin
		var grip_global_pos = grip_area.global_position
		var weapon_global_pos = global_position
		var offset = grip_global_pos - weapon_global_pos
		
		# Apply the inverse of this offset to position the weapon
		position -= offset
	
	# Reset rotation to default
	rotation = Vector3.ZERO

func find_node_recursive(node: Node, name_pattern: String) -> Node:
	if node.name.to_lower().contains(name_pattern.to_lower()):
		return node
	
	for child in node.get_children():
		var found = find_node_recursive(child, name_pattern)
		if found:
			return found
	
	return null

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
		
		# Apply interpolated rotation
		if weapon_model:
			weapon_model.rotation = lerp(
				swing_origin_rotation,
				swing_target_rotation,
				ease_out_cubic(swing_progress)
			)
	
	# We're now handling attack input from player_controller.gd
	# No need to check for attack input here anymore

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
			
			animation.track_set_path(track_idx, ".:rotation")
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
	# Prevents hitting the same object multiple times in a single swing
	if body in interactables_hit:
		return
		
	if is_attacking and body != player:
		if body.has_method("take_damage"):
			body.take_damage(damage)
			interactables_hit.append(body)
			print("Hit enemy with weapon!")
		elif body.has_method("interact"):
			body.interact()
			interactables_hit.append(body)

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
