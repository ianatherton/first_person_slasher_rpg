class_name EventBus
extends Node

# Player-related signals
@warning_ignore("unused_signal")
signal player_health_changed(new_health, max_health)
@warning_ignore("unused_signal")
signal player_stamina_changed(new_stamina, max_stamina)
@warning_ignore("unused_signal")
signal player_died()
@warning_ignore("unused_signal")
signal player_weapon_changed(weapon_index)
@warning_ignore("unused_signal")
signal player_attacked(weapon)

# Enemy-related signals
@warning_ignore("unused_signal")
signal enemy_damaged(enemy, amount)
@warning_ignore("unused_signal")
signal enemy_died(enemy)
@warning_ignore("unused_signal")
signal enemy_detected_player(enemy)
@warning_ignore("unused_signal")
signal enemy_attacked(enemy, target, damage)

# Game state signals
@warning_ignore("unused_signal")
signal game_started()
@warning_ignore("unused_signal")
signal game_over()
@warning_ignore("unused_signal")
signal game_paused(is_paused)
@warning_ignore("unused_signal")
signal level_loaded(level_name)

# Item and interaction signals
@warning_ignore("unused_signal")
signal item_collected(item_data)
@warning_ignore("unused_signal")
signal item_used(item_data)
@warning_ignore("unused_signal")
signal interaction_started(interactable)
@warning_ignore("unused_signal")
signal interaction_completed(interactable)

# This function can be used for debugging signal connections
func log_signal(signal_name, params = null):
	print("Signal emitted: ", signal_name, " Params: ", params)
