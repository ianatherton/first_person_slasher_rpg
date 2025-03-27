extends Control

@export var show_debug_info = true  # Toggle for debug information

@onready var stamina_bar = %StaminaBar
@onready var stamina_value = %StaminaValue
@onready var health_bar = %HealthBar
@onready var health_value = %HealthValue
@onready var debug_container = %DebugContainer
@onready var fps_counter = %FPSCounter
@onready var events = get_node("/root/Events")
@onready var game_state = get_node("/root/GameState")

func _ready():
	# Connect to Events signals for stamina and health updates
	events.connect("player_stamina_changed", Callable(self, "_on_stamina_changed"))
	events.connect("player_health_changed", Callable(self, "_on_health_changed"))
	
	# Initialize with current values from GameState
	_on_stamina_changed(game_state.player_stamina, game_state.player_max_stamina)
	_on_health_changed(game_state.player_health, game_state.player_max_health)
	
	# Set initial debug visibility
	debug_container.visible = show_debug_info

func _process(_delta):
	if fps_counter:
		fps_counter.text = "FPS: " + str(Engine.get_frames_per_second())

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
