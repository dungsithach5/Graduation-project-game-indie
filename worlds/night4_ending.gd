extends Node

# Night 4 Ending Handler
# Added as a child of sandbox root during Night 4.
# Manages the entire ending sequence (Ending A / Ending B).

var enemy_node: Node3D       # Enemy3D parent node
var enemy_body: CharacterBody3D  # enemy CharacterBody3D (child of Enemy3D)
var player: CharacterBody3D
var trigger_ghost: Area3D
var area_emulet: Node
var lighting_mart: Node

var ending_active: bool = false
var ending_type: String = ""  # "A" or "B"
var enemy_active: bool = false
var talisman_task_active: bool = false
var talismans_placed: int = 0
var total_talismans: int = 4

# Talisman spot tracking
var current_emulet_area: Area3D = null
var placement_progress: float = 0.0
var placement_time: float = 2.0
var is_placing: bool = false

var progress_bar: ProgressBar
var talisman_hand_instance: Node3D = null
var ghost_talismans: Dictionary = {}
var chase_audio_player: AudioStreamPlayer = null

# Track which spots have been used
var used_spots: Array = []

var ending_screen_shown: bool = false
var blackout_triggered: bool = false

# Screen static noise for jumpscare
var noise_layer: CanvasLayer = null
var noise_rect: TextureRect = null
var noise_textures: Array[ImageTexture] = []
var noise_active: bool = false
var noise_frame: int = 0
var noise_timer: float = 0.0

func _ready() -> void:
	# Find all needed nodes from the sandbox root
	var root = get_parent()
	enemy_node = root.get_node_or_null("Enemy3D")
	trigger_ghost = root.get_node_or_null("TriggerGhost")
	area_emulet = root.get_node_or_null("Area_emulet")
	player = root.get_node_or_null("Player")
	lighting_mart = root.find_child("LightingMart", true, false)
	
	# Get progress bar from UI
	var progress_ui = get_tree().get_root().find_child("ProgressUI", true, false)
	if progress_ui:
		progress_bar = progress_ui.get_node_or_null("ProgressBar")
	
	# Initially hide enemy and disable its processing
	if enemy_node:
		enemy_node.visible = false
		# Find the CharacterBody3D child (the actual enemy)
		for child in enemy_node.get_children():
			if child is CharacterBody3D:
				enemy_body = child
				break
		if enemy_body:
			enemy_body.set_process(false)
		enemy_node.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Connect to Director.shift_ended for blackout trigger
	if not Director.shift_ended.is_connected(_on_night4_shift_ended):
		Director.shift_ended.connect(_on_night4_shift_ended)
	
	# Setup TriggerGhost area
	if trigger_ghost:
		trigger_ghost.monitoring = true
		trigger_ghost.monitorable = true
		if not trigger_ghost.body_entered.is_connected(_on_trigger_ghost_entered):
			trigger_ghost.body_entered.connect(_on_trigger_ghost_entered)
	
	# Setup emulet areas (initially disabled, enabled later for Ending A)
	if area_emulet:
		for child in area_emulet.get_children():
			if child is Area3D:
				child.monitoring = false
				child.monitorable = false
				if not child.body_entered.is_connected(_on_emulet_area_entered):
					child.body_entered.connect(_on_emulet_area_entered.bind(child))
				if not child.body_exited.is_connected(_on_emulet_area_exited):
					child.body_exited.connect(_on_emulet_area_exited.bind(child))
	
	# Determine ending type from Dialogic variable set in Night 3
	_determine_ending_type()
	
	print("Night4Ending: Initialized. Ending type = ", ending_type)

func _determine_ending_type() -> void:
	# Check Dialogic variable set during Night 3's thaytu dialogue
	var accepted = Dialogic.VAR.get("accepted_talisman")
	if accepted == true or str(accepted).to_lower() == "true":
		ending_type = "A"
	else:
		ending_type = "B"

# ============================================================
# PHASE 1: Blackout after shift ends
# ============================================================

func _on_night4_shift_ended() -> void:
	if blackout_triggered:
		return
	blackout_triggered = true
	print("Night4Ending: Shift ended - triggering blackout!")
	
	# Play power cut sound
	var power_cut_audio = AudioStreamPlayer.new()
	power_cut_audio.stream = load("res://sounds/power-cut.mp3")
	power_cut_audio.volume_db = 10.0 # Make it louder
	power_cut_audio.bus = &"SFX"
	add_child(power_cut_audio)
	power_cut_audio.play()
	
	# Turn off ALL LightingMart lights permanently
	if lighting_mart:
		for child in lighting_mart.get_children():
			if child is Light3D:
				child.visible = false
	
	# Show enemy in corner (visible but not moving)
	if enemy_node:
		if enemy_body:
			enemy_body.set_process(false)  # Ensure no movement
		enemy_node.process_mode = Node.PROCESS_MODE_INHERIT
		enemy_node.visible = true
	
	print("Night4Ending: Blackout done. Enemy visible. Waiting for player to enter TriggerGhost...")

# ============================================================
# PHASE 2: Player enters TriggerGhost
# ============================================================

func _on_trigger_ghost_entered(body: Node3D) -> void:
	if ending_active or ending_screen_shown:
		return
	if not (body.is_in_group("player") or body is Player):
		return
	if not blackout_triggered:
		return
	
	ending_active = true
	print("Night4Ending: Player entered TriggerGhost! Starting Ending ", ending_type)
	
	# Disable the trigger so it doesn't fire again
	if trigger_ghost:
		trigger_ghost.set_deferred("monitoring", false)
	
	if ending_type == "A":
		_start_ending_a()
	else:
		_start_ending_b()

# ============================================================
# ENDING A: Talisman Placement
# ============================================================

func _start_ending_a() -> void:
	# Lock player movement during dialogue
	if player:
		player.movement_locked = true
	
	# Start dialogue with thaytu's guidance
	Dialogic.start("dialogic_night4")
	Dialogic.timeline_ended.connect(_on_ending_a_dialogue_ended, CONNECT_ONE_SHOT)

func _on_ending_a_dialogue_ended() -> void:
	print("Night4Ending: Ending A dialogue ended. Starting talisman task!")
	
	# Show talisman in player's hand
	_show_talisman_in_hand()
	
	# Activate enemy to chase
	_activate_enemy_chase()
	
	# Stop general ambient game sounds to focus on chase music
	var audio_manager = get_node_or_null("/root/AudioManager")
	if is_instance_valid(audio_manager):
		audio_manager.stop_game_sounds()
		
	# Play chase music
	chase_audio_player = AudioStreamPlayer.new()
	chase_audio_player.stream = load("res://sounds/fears-to-fathom-jumpscare.mp3")
	chase_audio_player.bus = &"Music"
	chase_audio_player.finished.connect(func():
		if is_instance_valid(chase_audio_player):
			chase_audio_player.play()
	)
	add_child(chase_audio_player)
	chase_audio_player.play()
	print("Night4Ending: Chase music started.")
	
	# Start talisman placement task
	talisman_task_active = true
	talismans_placed = 0
	
	# Setup task panel to show objective
	TaskManager.get_task_details(total_talismans)
	var task_panel = get_tree().get_root().find_child("TaskPanel", true, false)
	if task_panel:
		var objective_body = task_panel.get_node_or_null("VBoxContainer/ObjectiveBody")
		if objective_body:
			objective_body.text = "Place sealing talismans"
	
	# Create ghost talismans for the player to see placement locations
	_create_ghost_talismans()
	
	# Enable emulet areas for interaction
	if area_emulet:
		for child in area_emulet.get_children():
			if child is Area3D:
				child.monitoring = true
				child.monitorable = true
	
	# Unlock player so they can move and place talismans
	if player:
		player.movement_locked = false
	
	print("Night4Ending: Task started - Place 4 talismans on the walls!")

func _show_talisman_in_hand() -> void:
	if not player:
		return
	# Find the Hand marker on the player
	var hand = player.find_child("Hand", true, false)
	if hand:
		var talisman_scene = load("res://models/objects/talisman.tscn")
		if talisman_scene:
			talisman_hand_instance = talisman_scene.instantiate()
			talisman_hand_instance.scale = Vector3(3, 3, 3)
			hand.add_child(talisman_hand_instance)
			print("Night4Ending: Talisman shown in player's hand")

func _activate_enemy_chase() -> void:
	if enemy_body:
		enemy_body.speed = 2.0  # Moderate chase speed
		enemy_body.set_process(true)
		enemy_active = true
		print("Night4Ending: Enemy activated - chasing player!")

# ============================================================
# ENDING B: Immediate Jumpscare
# ============================================================

func _start_ending_b() -> void:
	# Lock player immediately
	if player:
		player.movement_locked = true
	
	# Make enemy rush toward player at high speed (manually processed in _process)
	if enemy_body:
		enemy_body.set_process(false)
		enemy_active = true
	if enemy_node:
		enemy_node.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Wait a short moment for the rush, then trigger jumpscare
	await get_tree().create_timer(1.0).timeout
	_trigger_jumpscare_ending_b()

func _trigger_jumpscare_ending_b() -> void:
	print("Night4Ending: Ending B - Jumpscare!")
	enemy_active = false
	
	# Stop enemy animation during jumpscare
	_stop_enemy_animations()
	
	# Start screen static noise overlay
	_start_jumpscare_noise(2.5)
	
	# Snap camera to face the enemy
	_snap_camera_to_enemy()
	
	# Stop enemy movement
	if enemy_body:
		enemy_body.set_process(false)
	
	# Play jumpscare audio
	var jumpscare_audio = AudioStreamPlayer.new()
	jumpscare_audio.stream = load("res://sounds/white_noise1.mp3")
	jumpscare_audio.volume_db = 15.0 # Very loud
	jumpscare_audio.bus = &"SFX"
	add_child(jumpscare_audio)
	jumpscare_audio.play()
	
	# Brief pause for scare effect (extended to 2.5s)
	await get_tree().create_timer(2.5).timeout
	
	# Show Ending B screen
	_show_ending_screen("Ending B", false)

# ============================================================
# PROCESS: Handles catch detection + talisman placement
# ============================================================

func _process(delta: float) -> void:
	# Update screen static noise frame if active
	if noise_active and noise_rect and not noise_textures.is_empty():
		noise_timer += delta
		if noise_timer >= 0.04: # ~25 frames per second
			noise_timer = 0.0
			noise_frame = (noise_frame + 1) % noise_textures.size()
			noise_rect.texture = noise_textures[noise_frame]

	# Manually move enemy towards player during Ending B rush
	if ending_active and ending_type == "B" and enemy_active and enemy_body and player:
		var target_pos = player.global_position
		var dir = (target_pos - enemy_body.global_position)
		dir.y = 0
		var dist = dir.length()
		if dist > 0.5:
			dir = dir.normalized()
			enemy_body.global_position += dir * 14.0 * delta # Fast scary straight rush
			if enemy_body.global_position.distance_to(target_pos) > 0.1:
				var look_target = target_pos
				look_target.y = enemy_body.global_position.y
				enemy_body.look_at(look_target, Vector3.UP)
				enemy_body.rotate_y(PI)

	if not ending_active or ending_screen_shown:
		return
	
	# Only process during Ending A talisman task
	if ending_type != "A" or not talisman_task_active:
		return
	
	# --- Check if enemy caught the player ---
	if enemy_active and player and enemy_body:
		var distance = player.global_position.distance_to(enemy_body.global_position)
		if distance < 1.5:
			_on_player_caught()
			return
	
	# --- Handle talisman placement (hold F) ---
	if current_emulet_area and not current_emulet_area.name in used_spots:
		if Input.is_action_pressed("hold_interact"):
			is_placing = true
			placement_progress += delta
			_update_placement_progress()
			
			if placement_progress >= placement_time:
				_place_talisman()
		else:
			if is_placing:
				_reset_placement()
	else:
		if is_placing:
			_reset_placement()

func _update_placement_progress() -> void:
	if progress_bar:
		progress_bar.visible = true
		progress_bar.value = (placement_progress / placement_time) * 100

func _reset_placement() -> void:
	is_placing = false
	placement_progress = 0.0
	if progress_bar:
		progress_bar.visible = false
		progress_bar.value = 0

func _place_talisman() -> void:
	_reset_placement()
	
	if current_emulet_area == null:
		return
	
	# Mark this spot as used
	used_spots.append(current_emulet_area.name)
	
	# Spawn talisman mesh at the wall position
	var col_shape: CollisionShape3D = null
	for child in current_emulet_area.get_children():
		if child is CollisionShape3D:
			col_shape = child
			break
	
	if col_shape:
		var talisman_scene = load("res://models/objects/talisman.tscn")
		if talisman_scene:
			var talisman = talisman_scene.instantiate()
			talisman.scale = Vector3(3.5, 3.5, 3.5)
			get_parent().add_child(talisman)
			talisman.global_position = col_shape.global_position
			talisman.global_rotation = col_shape.global_rotation
			talisman.rotate_y(deg_to_rad(90))
	
	# Remove ghost talisman for this spot
	if ghost_talismans.has(current_emulet_area.name):
		var ghost = ghost_talismans[current_emulet_area.name]
		if is_instance_valid(ghost):
			ghost.queue_free()
		ghost_talismans.erase(current_emulet_area.name)
	
	# Disable this area so it can't be used again
	current_emulet_area.monitoring = false
	current_emulet_area = null
	
	# Update task progress
	talismans_placed += 1
	TaskManager.update_task()
	
	# Clear interaction hint
	if player and player.interaction_controller:
		player.interaction_controller.forced_label_text = ""
	
	print("Night4Ending: Talisman placed! ", talismans_placed, "/", total_talismans)
	
	# Check if all talismans are placed
	if talismans_placed >= total_talismans:
		_on_all_talismans_placed()

# ============================================================
# ENDING A: All talismans placed - Enemy burns
# ============================================================

func _on_all_talismans_placed() -> void:
	print("Night4Ending: All 4 talismans placed! Enemy burning!")
	talisman_task_active = false
	enemy_active = false
	
	# Play demonic scream sound
	var scream_audio = AudioStreamPlayer.new()
	scream_audio.stream = load("res://sounds/demonic-woman-scream.mp3")
	scream_audio.volume_db = 10.0 # Loud
	scream_audio.bus = &"SFX"
	add_child(scream_audio)
	scream_audio.play()
	
	# Stop chase music
	if is_instance_valid(chase_audio_player):
		chase_audio_player.stop()
		chase_audio_player.queue_free()
		chase_audio_player = null
	
	# Stop enemy movement
	if enemy_body:
		enemy_body.set_process(false)
	
	# Remove talisman from player's hand
	if talisman_hand_instance and is_instance_valid(talisman_hand_instance):
		talisman_hand_instance.queue_free()
		talisman_hand_instance = null
	
	# Lock player to watch the burn
	if player:
		player.movement_locked = true
	
	# Snap camera to watch enemy burn
	_snap_camera_to_enemy()
	
	# Burn the enemy
	await _burn_enemy()
	
	# Show Ending A screen
	_show_ending_screen("Ending A", false)

func _burn_enemy() -> void:
	if not enemy_node:
		return
	
	# Create fire glow light at enemy position
	var fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.35, 0.0)
	fire_light.light_energy = 3.0
	fire_light.omni_range = 6.0
	enemy_node.add_child(fire_light)
	
	# Animate: intensify light + shrink enemy
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fire_light, "light_energy", 20.0, 2.0)
	tween.tween_property(fire_light, "light_color", Color(1.0, 0.8, 0.2), 2.0)
	tween.tween_property(enemy_node, "scale", Vector3(0.1, 0.1, 0.1), 2.5).set_ease(Tween.EASE_IN)
	await tween.finished
	
	# Hide enemy completely
	enemy_node.visible = false
	
	# Brief pause before showing ending
	await get_tree().create_timer(1.0).timeout

# ============================================================
# ENDING A: Player caught by enemy
# ============================================================

func _on_player_caught() -> void:
	print("Night4Ending: Player caught by enemy!")
	talisman_task_active = false
	enemy_active = false
	
	# Stop chase music
	if is_instance_valid(chase_audio_player):
		chase_audio_player.stop()
		chase_audio_player.queue_free()
		chase_audio_player = null
	
	# Stop enemy
	if enemy_body:
		enemy_body.set_process(false)
	
	# Lock player
	if player:
		player.movement_locked = true
	
	# Remove talisman from hand
	if talisman_hand_instance and is_instance_valid(talisman_hand_instance):
		talisman_hand_instance.queue_free()
		talisman_hand_instance = null
	
	# Clear forced label
	if player and player.interaction_controller:
		player.interaction_controller.forced_label_text = ""
	
	# Play jumpscare audio
	var jumpscare_audio = AudioStreamPlayer.new()
	jumpscare_audio.stream = load("res://sounds/white_noise1.mp3")
	jumpscare_audio.volume_db = 15.0 # Very loud
	jumpscare_audio.bus = &"SFX"
	add_child(jumpscare_audio)
	jumpscare_audio.play()
	
	# Stop enemy animation during jumpscare
	_stop_enemy_animations()
	
	# Start screen static noise overlay
	_start_jumpscare_noise(2.5)
	
	# Jumpscare - snap camera to enemy face
	_snap_camera_to_enemy()
	
	# Wait for jumpscare impact (extended to 2.5s)
	await get_tree().create_timer(2.5).timeout
	
	# Show death screen with Try Again
	_show_ending_screen("You are dead", true)

# ============================================================
# UTILITY FUNCTIONS
# ============================================================

func _snap_camera_to_enemy() -> void:
	if not player or not enemy_node:
		return
	
	var enemy_pos = enemy_body.global_position if enemy_body else enemy_node.global_position
	var dir_to_enemy = enemy_pos - player.global_position
	var flat_dist = Vector2(dir_to_enemy.x, dir_to_enemy.z).length()
	
	# Calculate target yaw (Y rotation) for player body
	var target_yaw = atan2(-dir_to_enemy.x, -dir_to_enemy.z)
	player.global_rotation.y = target_yaw
	
	# Calculate target pitch (X rotation) for player head
	var target_pitch = atan2(dir_to_enemy.y, flat_dist)
	player.head.rotation.x = clamp(target_pitch, deg_to_rad(-85), deg_to_rad(85))
	player.head.rotation.y = 0
	player.head.rotation.z = 0

func _show_ending_screen(title: String, show_try_again: bool) -> void:
	if ending_screen_shown:
		return
	ending_screen_shown = true
	
	# Create the ending screen overlay
	var ending_screen = CanvasLayer.new()
	ending_screen.set_script(load("res://UI/ending_screen.gd"))
	get_tree().current_scene.add_child(ending_screen)
	
	# Wait one frame for _ready() to execute and create UI elements
	await get_tree().process_frame
	
	if show_try_again:
		ending_screen.show_jumpscare_death()
	else:
		ending_screen.show_ending(title, false, true)

# ============================================================
# EMULET AREA SIGNALS
# ============================================================

func _on_emulet_area_entered(body: Node3D, area: Area3D) -> void:
	if not (body.is_in_group("player") or body is Player):
		return
	if area.name in used_spots:
		return
	if not talisman_task_active:
		return
	
	current_emulet_area = area
	
	# Show interaction hint
	if player and player.interaction_controller:
		player.interaction_controller.forced_label_text = "[F] Place Talisman"

func _on_emulet_area_exited(body: Node3D, area: Area3D) -> void:
	if not (body.is_in_group("player") or body is Player):
		return
	if current_emulet_area == area:
		current_emulet_area = null
		_reset_placement()
		
		# Clear interaction hint
		if player and player.interaction_controller:
			player.interaction_controller.forced_label_text = ""

func _create_ghost_talismans() -> void:
	if not area_emulet:
		return
	
	var talisman_scene = load("res://models/objects/talisman.tscn")
	if not talisman_scene:
		print("Night4Ending: Cannot load talisman scene for ghosts!")
		return
		
	# Create yellow transparent material
	var ghost_material = StandardMaterial3D.new()
	ghost_material.albedo_color = Color(1.0, 0.85, 0.0, 0.4) # Yellow, 40% alpha
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	for child in area_emulet.get_children():
		if child is Area3D:
			# Find collision shape for transform
			var col_shape: CollisionShape3D = null
			for sub_child in child.get_children():
				if sub_child is CollisionShape3D:
					col_shape = sub_child
					break
			
			if col_shape:
				var ghost = talisman_scene.instantiate()
				ghost.scale = Vector3(3.5, 3.5, 3.5)
				get_parent().add_child(ghost)
				ghost.global_position = col_shape.global_position
				ghost.global_rotation = col_shape.global_rotation
				ghost.rotate_y(deg_to_rad(90))
				
				# Apply ghost material recursively
				_apply_ghost_material_recursive(ghost, ghost_material)
				# Disable physics/collision recursively
				_disable_physics_recursive(ghost)
				
				ghost_talismans[child.name] = ghost
				print("Night4Ending: Ghost talisman created for ", child.name)

func _apply_ghost_material_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		for i in range(mesh_instance.get_surface_override_material_count()):
			mesh_instance.set_surface_override_material(i, material)
	for child in node.get_children():
		_apply_ghost_material_recursive(child, material)

func _disable_physics_recursive(node: Node) -> void:
	if node is CollisionShape3D:
		node.disabled = true
	if node is CollisionObject3D:
		if node is RigidBody3D:
			node.freeze = true
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_physics_recursive(child)

func _init_noise_textures() -> void:
	if not noise_textures.is_empty():
		return
	for i in range(8):
		var img = Image.create(128, 128, false, Image.FORMAT_L8)
		for y in range(128):
			for x in range(128):
				var grey = randf()
				img.set_pixel(x, y, Color(grey, grey, grey, 1.0))
		var tex = ImageTexture.create_from_image(img)
		noise_textures.append(tex)

func _start_jumpscare_noise(duration: float) -> void:
	_init_noise_textures()
	
	if noise_layer:
		noise_layer.queue_free()
		
	noise_layer = CanvasLayer.new()
	noise_layer.layer = 150
	
	noise_rect = TextureRect.new()
	noise_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	noise_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	noise_rect.stretch_mode = TextureRect.STRETCH_SCALE
	noise_rect.texture_filter = Control.TEXTURE_FILTER_NEAREST
	noise_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	noise_rect.modulate = Color(1, 1, 1, 0.08) # 8% opacity noise (very light)
	
	noise_layer.add_child(noise_rect)
	add_child(noise_layer)
	
	noise_active = true
	noise_frame = 0
	noise_timer = 0.0
	
	# Animate the noise overlay fading in and then disappearing
	var tween = create_tween()
	tween.tween_property(noise_rect, "modulate:a", 0.12, 0.1)
	tween.tween_property(noise_rect, "modulate:a", 0.06, 0.6)
	tween.tween_property(noise_rect, "modulate:a", 0.1, 0.6)
	tween.tween_interval(duration - 1.5)
	tween.tween_property(noise_rect, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		noise_active = false
		if is_instance_valid(noise_layer):
			noise_layer.queue_free()
			noise_layer = null
	)

func _stop_enemy_animations() -> void:
	if not enemy_node:
		return
	_stop_animations_recursive(enemy_node)

func _stop_animations_recursive(node: Node) -> void:
	if node is AnimationPlayer:
		node.stop()
	elif node is AnimationTree:
		node.active = false
	for child in node.get_children():
		_stop_animations_recursive(child)
