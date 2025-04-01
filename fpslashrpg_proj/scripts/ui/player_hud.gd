extends Control

@export var show_debug_info = true  # Toggle for debug information
@export var advanced_metrics = true  # Toggle for advanced performance metrics

@onready var stamina_bar = %StaminaBar
@onready var stamina_value = %StaminaValue
@onready var health_bar = %HealthBar
@onready var health_value = %HealthValue
@onready var debug_container = %DebugContainer
@onready var fps_counter = %FPSCounter
@onready var events = get_node("/root/Events")
@onready var game_state = get_node("/root/GameState")

# Weapon indicator references
@onready var weapon_indicator_container = %WeaponIndicatorContainer
@onready var weapon_slots = %WeaponSlots
@onready var slot1 = %Slot1
@onready var slot2 = %Slot2
@onready var slot3 = %Slot3
@onready var weapon_name = %WeaponName
var weapon_slots_array = []

# Advanced performance metrics
@onready var draw_calls_counter = %DrawCallsCounter
@onready var node_count_counter = %NodeCountCounter
@onready var objects_counter = %ObjectsCounter
@onready var memory_counter = %MemoryCounter

# Performance monitoring variables
var update_metrics_timer = 0.0
var metrics_update_interval = 0.5  # Update advanced metrics every half-second to reduce overhead

# Styling for weapon slots
var active_style = null
var inactive_style = null

func _ready():
	# Connect to Events signals for stamina and health updates
	events.connect("player_stamina_changed", Callable(self, "_on_stamina_changed"))
	events.connect("player_health_changed", Callable(self, "_on_health_changed"))
	events.connect("player_weapon_changed", Callable(self, "_on_weapon_changed"))
	
	# Initialize with current values from GameState
	_on_stamina_changed(game_state.player_stamina, game_state.player_max_stamina)
	_on_health_changed(game_state.player_health, game_state.player_max_health)
	
	# Set initial debug visibility
	debug_container.visible = show_debug_info
	
	# Create advanced metrics labels if they don't exist
	_setup_advanced_metrics()
	
	# Initialize weapon UI
	_setup_weapon_ui()

func _setup_weapon_ui():
	# Store weapon slots in an array for easier access
	weapon_slots_array = [slot1, slot2, slot3]
	
	# Store the styles for active and inactive slots
	if slot1 and slot1.get("theme_override_styles/panel"):
		active_style = slot1.get("theme_override_styles/panel")
		
		# Create a duplicate style for inactive slots
		inactive_style = active_style.duplicate()
		inactive_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
		
		# Initially set all slots to inactive style except the first one
		for i in range(1, weapon_slots_array.size()):
			if weapon_slots_array[i]:
				weapon_slots_array[i].set("theme_override_styles/panel", inactive_style)

func _setup_advanced_metrics():
	# Only create if debug container exists
	if not debug_container:
		return
		
	# Check if we need to create the advanced metrics labels
	if not draw_calls_counter:
		draw_calls_counter = Label.new()
		draw_calls_counter.name = "DrawCallsCounter"
		draw_calls_counter.text = "Draw Calls: 0"
		debug_container.add_child(draw_calls_counter)
	
	if not node_count_counter:
		node_count_counter = Label.new()
		node_count_counter.name = "NodeCountCounter"
		node_count_counter.text = "Node Count: 0"
		debug_container.add_child(node_count_counter)
	
	if not objects_counter:
		objects_counter = Label.new()
		objects_counter.name = "ObjectsCounter"
		objects_counter.text = "Objects: 0"
		debug_container.add_child(objects_counter)
	
	if not memory_counter:
		memory_counter = Label.new()
		memory_counter.name = "MemoryCounter"
		memory_counter.text = "Memory: 0 MB"
		debug_container.add_child(memory_counter)

func _process(delta):
	if fps_counter:
		fps_counter.text = "FPS: " + str(Engine.get_frames_per_second())
	
	# Update advanced metrics less frequently to reduce performance impact
	if advanced_metrics and show_debug_info:
		update_metrics_timer += delta
		if update_metrics_timer >= metrics_update_interval:
			update_metrics_timer = 0.0
			_update_advanced_metrics()

func _update_advanced_metrics():
	if draw_calls_counter:
		var renderer_info = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		draw_calls_counter.text = "Draw Calls: " + str(renderer_info)
	
	if node_count_counter:
		var node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		node_count_counter.text = "Nodes: " + str(node_count)
	
	if objects_counter:
		var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)
		objects_counter.text = "Objects: " + str(object_count)
	
	if memory_counter:
		var memory_static = Performance.get_monitor(Performance.MEMORY_STATIC)
		memory_counter.text = "Memory: " + str(round(memory_static / 1048576.0)) + " MB"

func update_health(current_health, max_health):
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	if health_value:
		health_value.text = str(current_health) + "/" + str(max_health)

func update_stamina(current_stamina, max_stamina):
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina
	
	if stamina_value:
		stamina_value.text = str(int(current_stamina)) + "/" + str(int(max_stamina))

func update_weapon_indicator(current_index, total_weapons):
	# First make sure we don't exceed our UI slots
	var available_slots = min(weapon_slots_array.size(), total_weapons)
	
	# Update weapon slots visibility and styling
	for i in range(weapon_slots_array.size()):
		if i < available_slots:
			# Show slots that have weapons
			weapon_slots_array[i].visible = true
			
			# Apply the appropriate style based on whether this is the active weapon
			if i == current_index:
				weapon_slots_array[i].set("theme_override_styles/panel", active_style)
			else:
				weapon_slots_array[i].set("theme_override_styles/panel", inactive_style)
		else:
			# Hide slots for which we don't have weapons
			weapon_slots_array[i].visible = false
	
	# Try to get the weapon name from the player
	var player = get_node_or_null("/root/GameManager/Player")
	if player and player.current_weapon:
		weapon_name.text = player.current_weapon.name
	else:
		# Default names based on index if we can't get the actual weapon
		var weapon_names = ["Morning Star", "Short Sword", "Battle Axe"]
		if current_index < weapon_names.size():
			weapon_name.text = weapon_names[current_index]
		else:
			weapon_name.text = "Weapon " + str(current_index + 1)

func _on_stamina_changed(current_stamina, max_stamina):
	update_stamina(current_stamina, max_stamina)

func _on_health_changed(current_health, max_health):
	update_health(current_health, max_health)

func _on_weapon_changed(weapon_index):
	# Weapon index is the new active weapon
	var player = get_node_or_null("/root/GameManager/Player")
	var total_weapons = 1  # Default to 1 if we can't find the player
	
	if player and player.has_method("get_weapon_count"):
		total_weapons = player.get_weapon_count()
	elif player and "weapons" in player:
		total_weapons = player.weapons.size()
	
	update_weapon_indicator(weapon_index, total_weapons)

func toggle_debug_info():
	show_debug_info = !show_debug_info
	debug_container.visible = show_debug_info
	return show_debug_info

func toggle_advanced_metrics():
	advanced_metrics = !advanced_metrics
	return advanced_metrics
