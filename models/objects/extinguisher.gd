extends RigidBody3D

var foam_particles: CPUParticles3D
var is_held: bool = false

func _ready() -> void:
	# Create foam particles dynamically so we don't need complex editor setup
	foam_particles = CPUParticles3D.new()
	add_child(foam_particles)
	
	# Configure foam particles to look like white foam spray
	var material = StandardMaterial3D.new()
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.8) # White foam
	
	# Create a simple sphere mesh for the particles
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.08
	sphere_mesh.height = 0.16
	sphere_mesh.material = material
	
	foam_particles.mesh = sphere_mesh
	foam_particles.emitting = false
	foam_particles.amount = 40
	foam_particles.lifetime = 0.5
	foam_particles.one_shot = false
	foam_particles.explosiveness = 0.0
	foam_particles.local_coords = false # Let particles float in space
	foam_particles.top_level = true # Avoid inheriting parent's 0.1 scale
	
	# Spray direction and speed
	foam_particles.direction = Vector3(0, 0, -1) # Forward relative to the basis we assign
	foam_particles.spread = 20.0
	foam_particles.gravity = Vector3(0, -2.0, 0) # Fall slightly over time
	foam_particles.initial_velocity_min = 6.0
	foam_particles.initial_velocity_max = 8.0
	
	# Scale over lifetime (starts small, gets bigger, then fades away)
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.3, 1.2))
	scale_curve.add_point(Vector2(1.0, 0.0))
	foam_particles.scale_amount_curve = scale_curve

func _process(delta: float) -> void:
	var interact_comp = get_node_or_null("InteractionComponent")
	if interact_comp:
		is_held = interact_comp.is_interacting
	
	if not is_held:
		stop_spraying()

func start_spraying(player_hand: Marker3D) -> void:
	if not is_held:
		return
	if foam_particles:
		foam_particles.global_transform.basis = player_hand.global_transform.basis
		# Position particles at the nozzle of the extinguisher
		foam_particles.global_position = global_position
		
		if not foam_particles.emitting:
			foam_particles.emitting = true

func stop_spraying() -> void:
	if foam_particles and foam_particles.emitting:
		foam_particles.emitting = false
