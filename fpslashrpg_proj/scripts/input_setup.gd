extends Node

func _ready():
	set_input_map()
	
func set_input_map():
	# Clear any existing mappings
	for action in InputMap.get_actions():
		if not action.begins_with("ui_"):
			InputMap.erase_action(action)
	
	# Player movement
	add_action_with_key("move_forward", KEY_W)
	add_action_with_key("move_back", KEY_S)
	add_action_with_key("move_left", KEY_A)
	add_action_with_key("move_right", KEY_D)
	add_action_with_key("jump", KEY_SPACE)
	add_action_with_key("sprint", KEY_SHIFT)
	
	# Combat
	add_action_with_mouse("attack", MOUSE_BUTTON_LEFT)
	add_action_with_mouse("block", MOUSE_BUTTON_RIGHT)
	
	# Inventory & Equipment
	add_action_with_key("inventory", KEY_I)
	add_action_with_key("weapon_slot_1", KEY_1)
	add_action_with_key("weapon_slot_2", KEY_2)
	add_action_with_key("weapon_slot_3", KEY_3)
	add_action_with_mouse("next_weapon", MOUSE_BUTTON_WHEEL_UP)
	add_action_with_mouse("prev_weapon", MOUSE_BUTTON_WHEEL_DOWN)
	
	# Interaction
	add_action_with_key("interact", KEY_E)
	add_action_with_key("crouch", KEY_C)
	
	# Add debug toggle actions
	InputMap.add_action("toggle_debug")
	InputMap.add_action("toggle_advanced_metrics")

	# Map debug actions to keys
	var debug_event = InputEventKey.new()
	debug_event.keycode = KEY_F1
	InputMap.action_add_event("toggle_debug", debug_event)

	var metrics_event = InputEventKey.new()
	metrics_event.keycode = KEY_F2
	InputMap.action_add_event("toggle_advanced_metrics", metrics_event)

func add_action_with_key(action_name: String, keycode: int):
	InputMap.add_action(action_name)
	var event = InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action_name, event)

func add_action_with_mouse(action_name: String, button_index: int):
	InputMap.add_action(action_name)
	var event = InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)
