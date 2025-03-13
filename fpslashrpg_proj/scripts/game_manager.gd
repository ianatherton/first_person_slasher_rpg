extends Node

var player_health = 100
var player_stamina = 100
var player_max_stamina = 100
var stamina_regen_rate = 10  # per second

signal health_changed(new_health)
signal stamina_changed(new_stamina)

var input_setup = preload("res://scripts/input_setup.gd").new()

func _ready():
	# Initialize input mappings
	add_child(input_setup)
	
	# Configure default game settings
	Engine.max_fps = 60
	
	# Load game configuration here if needed

func _process(delta):
	# Regenerate stamina over time
	if player_stamina < player_max_stamina:
		player_stamina = min(player_stamina + stamina_regen_rate * delta, player_max_stamina)
		emit_signal("stamina_changed", player_stamina)

func damage_player(amount):
	player_health = max(0, player_health - amount)
	emit_signal("health_changed", player_health)
	
	if player_health <= 0:
		game_over()

func use_stamina(amount):
	if player_stamina >= amount:
		player_stamina -= amount
		emit_signal("stamina_changed", player_stamina)
		return true
	return false

func game_over():
	# Handle game over state
	print("Game Over!")
	# Eventually implement proper game over screen
