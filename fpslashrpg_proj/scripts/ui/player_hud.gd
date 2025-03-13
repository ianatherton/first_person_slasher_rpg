extends Control

@onready var stamina_bar = %StaminaBar
@onready var stamina_value = %StaminaValue

func _ready():
	# Connect to player's stamina signal
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.stamina_changed.connect(_on_player_stamina_changed)
		
		# Initialize with current stamina value
		_on_player_stamina_changed(player.stamina, player.max_stamina)
	else:
		print("ERROR: Could not find player to connect stamina signal!")

func _on_player_stamina_changed(current: float, maximum: float):
	# Update the bar
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	
	# Update the text
	stamina_value.text = "%d / %d" % [int(current), int(maximum)]
	
	# Visual feedback when stamina is low
	if current < maximum * 0.25:
		stamina_bar.modulate = Color(1, 0.3, 0.3)  # Red tint when low
	else:
		stamina_bar.modulate = Color(1, 1, 1)  # Normal color
