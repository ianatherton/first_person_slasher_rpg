extends GPUParticles3D

enum ImpactType {
	DEFAULT,
	METAL,
	STONE,
	WOOD,
	FLESH
}

# Reference to spark particles component
@onready var spark_particles = %SparkParticles

# Different impact colors for different materials
var impact_colors = {
	ImpactType.DEFAULT: Color(1.0, 0.78, 0.25, 1.0),  # Orange-yellow sparks
	ImpactType.METAL: Color(0.9, 0.9, 1.0, 1.0),      # Bright white-blue sparks
	ImpactType.STONE: Color(0.8, 0.7, 0.6, 1.0),      # Gray-brown dust particles
	ImpactType.WOOD: Color(0.7, 0.5, 0.3, 1.0),       # Brown wood chips
	ImpactType.FLESH: Color(0.9, 0.0, 0.0, 1.0)       # Bright red blood particles
}

func _ready():
	# Don't start emitting automatically
	emitting = false
	spark_particles.emitting = false

# Play the appropriate impact effect based on the surface type
func play_impact(impact_type: ImpactType = ImpactType.DEFAULT, impact_strength: float = 1.0):
	# Configure particles based on impact type
	var particle_material = process_material.duplicate()
	var spark_material = spark_particles.process_material.duplicate()
	
	# Set the appropriate color based on impact type
	var color = impact_colors.get(impact_type, impact_colors[ImpactType.DEFAULT])
	particle_material.color = color
	
	# Adjust spark color and behavior based on impact type
	if impact_type == ImpactType.METAL:
		spark_material.color = Color(0.9, 0.9, 1.0, 1.0)
		spark_particles.draw_pass_1.material.emission = Color(0.8, 0.8, 1.0)
		spark_particles.draw_pass_1.material.emission_energy_multiplier = 8.0
	elif impact_type == ImpactType.STONE:
		spark_material.color = Color(0.8, 0.7, 0.6, 1.0)
		spark_particles.draw_pass_1.material.emission = Color(0.7, 0.6, 0.5)
		spark_particles.draw_pass_1.material.emission_energy_multiplier = 3.0
	elif impact_type == ImpactType.FLESH:
		# Make blood-like particles
		spark_material.color = Color(0.9, 0.0, 0.0, 0.9)
		spark_particles.draw_pass_1.material.emission = Color(1.0, 0.0, 0.0)
		spark_particles.draw_pass_1.material.emission_energy_multiplier = 2.0
		
		# Adjust particle physics for blood - slower, more spread, larger particles
		particle_material.scale_min = 0.15
		particle_material.scale_max = 0.25
		particle_material.gravity = Vector3(0, -2.0, 0)  # Slower falling for blood
		
		# Adjust spread for blood particles
		particle_material.spread = 45.0  # Wider spread for blood splatter
		
		print("Configured blood impact particles")
	
	# Set velocities based on impact strength
	particle_material.initial_velocity_min = 2.0 * impact_strength
	particle_material.initial_velocity_max = 5.0 * impact_strength
	spark_material.initial_velocity_min = 3.0 * impact_strength
	spark_material.initial_velocity_max = 7.0 * impact_strength
	
	# Apply the configured materials
	process_material = particle_material
	spark_particles.process_material = spark_material
	
	# Start the particle effects
	emitting = true
	spark_particles.emitting = true
	
	# Print debug info
	print("Playing impact effect type: ", impact_type)

# Auto-destroy the particles after they've finished
func _on_destroy_timer_timeout():
	queue_free()
