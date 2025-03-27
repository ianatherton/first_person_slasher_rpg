class_name GameStateManager
extends Node

# Player stats
var player_health: int = 100
var player_max_health: int = 100
var player_stamina: float = 100.0
var player_max_stamina: float = 100.0
var stamina_regen_rate: float = 10.0  # per second

# Game state
var game_paused: bool = false
var game_over: bool = false
var current_level: String = ""
var debug_mode: bool = false

# Input management
var input_setup = null

func _ready():
	# Initialize input mappings
	input_setup = load("res://scripts/input_setup.gd").new()
	add_child(input_setup)
	
	# Configure default game settings
	Engine.max_fps = 60

func _process(delta):
	# Process stamina regeneration
	if player_stamina < player_max_stamina:
		player_stamina = min(player_stamina + stamina_regen_rate * delta, player_max_stamina)
		# Get the autoload reference instead of using "Events" directly
		var events = get_node("/root/Events")
		events.emit_signal("player_stamina_changed", player_stamina, player_max_stamina)

func damage_player(amount: int) -> void:
	player_health = max(0, player_health - amount)
	var events = get_node("/root/Events")
	events.emit_signal("player_health_changed", player_health, player_max_health)
	
	if player_health <= 0:
		player_died()

func heal_player(amount: int) -> void:
	player_health = min(player_max_health, player_health + amount)
	var events = get_node("/root/Events")
	events.emit_signal("player_health_changed", player_health, player_max_health)

func use_stamina(amount: float) -> bool:
	if player_stamina >= amount:
		player_stamina -= amount
		var events = get_node("/root/Events")
		events.emit_signal("player_stamina_changed", player_stamina, player_max_stamina)
		return true
	return false

func set_max_health(new_max: int) -> void:
	player_max_health = max(1, new_max)
	player_health = min(player_health, player_max_health)
	var events = get_node("/root/Events")
	events.emit_signal("player_health_changed", player_health, player_max_health)

func set_max_stamina(new_max: float) -> void:
	player_max_stamina = max(1.0, new_max)
	player_stamina = min(player_stamina, player_max_stamina)
	var events = get_node("/root/Events")
	events.emit_signal("player_stamina_changed", player_stamina, player_max_stamina)

func player_died() -> void:
	var events = get_node("/root/Events")
	events.emit_signal("player_died")
	trigger_game_over()

func trigger_game_over() -> void:
	game_over = true
	var events = get_node("/root/Events")
	events.emit_signal("game_over")
	print("Game Over!")

func pause_game(paused: bool = true) -> void:
	game_paused = paused
	get_tree().paused = paused
	var events = get_node("/root/Events")
	events.emit_signal("game_paused", paused)

func toggle_pause() -> void:
	pause_game(!game_paused)

func start_new_game() -> void:
	# Reset game state
	player_health = player_max_health
	player_stamina = player_max_stamina
	game_over = false
	game_paused = false
	var events = get_node("/root/Events")
	events.emit_signal("game_started")

func load_level(level_name: String) -> void:
	current_level = level_name
	var events = get_node("/root/Events")
	events.emit_signal("level_loaded", level_name)

func toggle_debug_mode() -> bool:
	debug_mode = !debug_mode
	return debug_mode
