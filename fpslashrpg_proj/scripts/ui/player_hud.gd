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

# Advanced performance metrics
@onready var draw_calls_counter = %DrawCallsCounter
@onready var node_count_counter = %NodeCountCounter
@onready var objects_counter = %ObjectsCounter
@onready var memory_counter = %MemoryCounter

# Performance monitoring variables
var update_metrics_timer = 0.0
var metrics_update_interval = 0.5  # Update advanced metrics every half-second to reduce overhead

func _ready():
	# Connect to Events signals for stamina and health updates
	events.connect("player_stamina_changed", Callable(self, "_on_stamina_changed"))
	events.connect("player_health_changed", Callable(self, "_on_health_changed"))
	
	# Initialize with current values from GameState
	_on_stamina_changed(game_state.player_stamina, game_state.player_max_stamina)
	_on_health_changed(game_state.player_health, game_state.player_max_health)
	
	# Set initial debug visibility
	debug_container.visible = show_debug_info
	
	# Create advanced metrics labels if they don't exist
	_setup_advanced_metrics()

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

func _on_stamina_changed(current_stamina, max_stamina):
	update_stamina(current_stamina, max_stamina)

func _on_health_changed(current_health, max_health):
	update_health(current_health, max_health)

func toggle_debug_info():
	show_debug_info = !show_debug_info
	debug_container.visible = show_debug_info
	return show_debug_info

func toggle_advanced_metrics():
	advanced_metrics = !advanced_metrics
	return advanced_metrics
