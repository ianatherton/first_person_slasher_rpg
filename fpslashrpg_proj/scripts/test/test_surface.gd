extends StaticBody3D

# This script is attached to test cubes to provide basic functionality
# for impact testing. It can be extended to handle damage or other interactions.

func _ready():
	# Add to appropriate group if not already done in the editor
	if "metal" in name.to_lower():
		add_to_group("metal")
	elif "stone" in name.to_lower():
		add_to_group("stone")
	elif "wood" in name.to_lower():
		add_to_group("wood")
	elif "flesh" in name.to_lower():
		add_to_group("flesh")

# Optional: if you want the cubes to take damage from weapon
func take_damage(amount):
	print(name + " took " + str(amount) + " damage!")
	# Could add visual feedback here, like a temporary color change
	modulate_mesh(Color(1.5, 1.5, 1.5))  # Flash white
	await get_tree().create_timer(0.1).timeout
	modulate_mesh(Color(1, 1, 1))  # Reset color

# Helper function to modulate the mesh color
func modulate_mesh(color: Color):
	for child in get_children():
		if child is MeshInstance3D:
			# Create a temporary material to show the hit feedback
			var temp_material = child.get_surface_override_material(0).duplicate()
			temp_material.emission_enabled = true
			temp_material.emission = color
			temp_material.emission_energy_multiplier = 2.0
			child.set_surface_override_material(0, temp_material)
			return
