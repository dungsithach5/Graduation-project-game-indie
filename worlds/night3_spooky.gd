extends Node

var demon_instance: Node3D = null
var knock_audio: AudioStreamPlayer3D = null
var trigger_area: Area3D = null
var knock_timer: float = 0.0
var event_active: bool = false
var jumpscare_triggered: bool = false
var design_pos: Vector3 = Vector3.ZERO

# Ghost Month folk whispers
var whisper_timer: float = 0.0
var flying_box_triggered: bool = false

func _ready() -> void:
	print("Night3Spooky: Spooky handler initialized")
	
	# Connect to task manager signals
	TaskManager.task_started.connect(_on_task_started)
	TaskManager.task_updated.connect(_on_task_updated)
	
	# Find the user's npc_knocking node inside WeenMart scene and hide it by default
	demon_instance = get_parent().find_child("npc_knocking", true, false)
	if demon_instance:
		demon_instance.visible = false
		demon_instance.process_mode = Node.PROCESS_MODE_DISABLED
		design_pos = demon_instance.global_position
		print("Night3Spooky: Found npc_knocking node in scene at position: ", design_pos)

func _process(delta: float) -> void:
	# Handle window knocking sound loop if demon is alive and not jumpscared yet
	if is_instance_valid(demon_instance) and demon_instance.visible and not jumpscare_triggered:
		knock_timer += delta
		if knock_timer >= 3.5: # knock every 3.5 seconds
			knock_timer = 0.0
			_play_window_knock()

	# Check distance to ghost/demon if it is active
	if is_instance_valid(demon_instance) and demon_instance.visible and not jumpscare_triggered:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var dist = demon_instance.global_position.distance_to(player.global_position)
			if dist < 2.5: # Close range fallback trigger
				_trigger_jumpscare(player)

	# Random whispers during floor cleaning task (Event index 2 is CLEAN_FLOOR in Night 3)
	if Director.current_night_index == 2 and Director.current_event_index == 2:
		whisper_timer += delta
		if whisper_timer >= randf_range(18.0, 28.0):
			whisper_timer = 0.0
			_play_creepy_whisper()

func _on_task_started(current: int, requirement: int) -> void:
	_check_event()

func _on_task_updated(current: int, requirement: int) -> void:
	_check_event()

func _check_event() -> void:
	if Director.current_night_index != 2:
		return
		
	# Event 0: Restock Shelves. Trigger flying box when they restock the 1st shelf
	if Director.current_event_index == 0 and not flying_box_triggered:
		var task_manager_current = TaskManager.current_task_count if "current_task_count" in TaskManager else 0
		if task_manager_current == 1:
			flying_box_triggered = true
			_trigger_flying_box_event()

	# Trigger window-knocking ghost when all customers are gone
	# (Which is when Event Index 2: Clean the Floor begins)
	if Director.current_event_index == 2 and not event_active:
		event_active = true
		_start_window_peeping_event()

func _trigger_flying_box_event() -> void:
	await get_tree().create_timer(1.5).timeout
	print("Night3Spooky: Triggering flying box event")
	
	# Flicker lights
	_flicker_lights(2, 0.12)
	await get_tree().create_timer(0.3).timeout
	
	# Spawn a stock cardboard box
	var box_scene = load("res://models/objects/stock.tscn")
	if not box_scene:
		return
		
	var box = box_scene.instantiate()
	get_parent().add_child(box)
	
	# Position on one of the empty shelves
	box.global_position = Vector3(-20.0, 2.3, -8.0)
	
	# Play crash sound
	var crash_sfx = AudioStreamPlayer3D.new()
	crash_sfx.stream = load("res://sounds/cringe-scare.mp3")
	crash_sfx.volume_db = -8.0 # Distant clatter sound
	crash_sfx.bus = &"SFX"
	box.add_child(crash_sfx)
	
	if box is RigidBody3D:
		box.freeze = false
		# Throw it down and into the aisle
		box.apply_impulse(Vector3(-7.0, -1.5, 7.0))
		
	crash_sfx.play()

func _start_window_peeping_event() -> void:
	print("Night3Spooky: Starting window peeping event (all customers gone)")
	
	# Try to locate the node again if not cached
	if not demon_instance:
		demon_instance = get_parent().find_child("npc_knocking", true, false)
		
	if not demon_instance:
		print("Night3Spooky: Error - Could not find npc_knocking node in the scene!")
		return
		
	# Ensure the demon is at its design position
	design_pos = demon_instance.global_position
	
	# Calculate inside/outside directions relative to the cashier counter Vector3(-11.28, 0, -10.19)
	var cashier_pos = Vector3(-11.28, 0.0, -10.19)
	var inside_dir = (cashier_pos - design_pos).normalized()
	inside_dir.y = 0.0
	inside_dir = inside_dir.normalized()
	
	# Make the demon active and visible
	demon_instance.visible = true
	demon_instance.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Rotate demon to look at the checkout counter (cashier area)
	demon_instance.look_at(cashier_pos, Vector3.UP)
	demon_instance.rotate_y(PI) # mixamo models face backward
	
	# 2. Setup window knock audio player
	knock_audio = AudioStreamPlayer3D.new()
	var knock_sound_path = "res://sounds/knoking.mp3"
	if not FileAccess.file_exists(knock_sound_path):
		var dir = DirAccess.open("res://sounds")
		if dir:
			if dir.file_exists("window_knock.mp3"):
				knock_sound_path = "res://sounds/window_knock.mp3"
			elif dir.file_exists("knock.mp3"):
				knock_sound_path = "res://sounds/knock.mp3"
			else:
				knock_sound_path = "res://sounds/power-cut.mp3"
		
	knock_audio.stream = load(knock_sound_path)
	knock_audio.volume_db = 15.0 # Louder knocking
	knock_audio.max_distance = 25.0 # Hearable from further away
	knock_audio.bus = &"SFX"
	demon_instance.add_child(knock_audio)
	
	# Play first knock immediately
	_play_window_knock()
	
	# 3. Create the Area3D trigger dynamically inside the store near the glass
	trigger_area = Area3D.new()
	trigger_area.name = "SpookyTriggerArea"
	get_parent().add_child(trigger_area)
	
	# Place the trigger inside the store (1.2 meters inside from the demon's position)
	trigger_area.global_position = design_pos + inside_dir * 1.2
	
	# Create collision shape for Area3D
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 2.0 # 2.0 meters trigger radius
	collision.shape = sphere
	trigger_area.add_child(collision)
	
	# Connect signal
	trigger_area.body_entered.connect(_on_trigger_area_entered)
	print("Night3Spooky: Dynamic Area3D trigger created at ", trigger_area.global_position)

func _play_window_knock() -> void:
	if is_instance_valid(knock_audio):
		knock_audio.play()

func _on_trigger_area_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_trigger_jumpscare(body)

func _trigger_jumpscare(player: Node3D) -> void:
	if jumpscare_triggered:
		return
	jumpscare_triggered = true
	print("Night3Spooky: Triggering window jumpscare!")
	
	# Calculate direction to cashier
	var cashier_pos = Vector3(-11.28, 0.0, -10.19)
	var inside_dir = (cashier_pos - design_pos).normalized()
	inside_dir.y = 0.0
	inside_dir = inside_dir.normalized()

	# 1. Demon lunges/rushes closer to the glass window (moves 0.8 meters closer to cashier)
	if is_instance_valid(demon_instance):
		demon_instance.global_position = design_pos + inside_dir * 0.8
		
	# 2. Play scary demon scream
	var scream_sfx = AudioStreamPlayer.new()
	scream_sfx.stream = load("res://sounds/demonic-woman-scream.mp3")
	scream_sfx.volume_db = 2.0 # Loud jumpscare volume
	scream_sfx.bus = &"SFX"
	add_child(scream_sfx)
	scream_sfx.play()
	
	# 3. Flicker lights once to cover the disappearance
	_flicker_lights(1, 0.15)
	
	# 4. Wait 0.6 seconds and clean up
	await get_tree().create_timer(0.6).timeout
	_cleanup_event()

func _cleanup_event() -> void:
	print("Night3Spooky: Cleaning up peeping event")
	if is_instance_valid(demon_instance):
		demon_instance.visible = false
		demon_instance.process_mode = Node.PROCESS_MODE_DISABLED
		
	if is_instance_valid(trigger_area):
		trigger_area.queue_free()
		trigger_area = null

func _play_creepy_whisper() -> void:
	print("Night3Spooky: Playing creepy whisper")
	var whisper_sfx = AudioStreamPlayer.new()
	whisper_sfx.stream = load("res://sounds/npc_crying.wav")
	whisper_sfx.volume_db = -20.0
	whisper_sfx.bus = &"SFX"
	add_child(whisper_sfx)
	whisper_sfx.play()
	
	# Stop after 3.0s (just a short creepy crying/whispering sound in darkness)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(whisper_sfx):
		whisper_sfx.stop()
		whisper_sfx.queue_free()

func _flicker_lights(times: int = 3, interval: float = 0.15) -> void:
	var lighting_mart = get_parent().find_child("LightingMart", true, false)
	if not lighting_mart:
		return
		
	var sfx = AudioStreamPlayer.new()
	sfx.stream = load("res://sounds/power-cut.mp3")
	sfx.volume_db = -6.0
	sfx.bus = &"SFX"
	add_child(sfx)
	sfx.play()
	
	for i in range(times):
		for light in lighting_mart.get_children():
			if light is Light3D:
				light.visible = false
		await get_tree().create_timer(interval).timeout
		
		for light in lighting_mart.get_children():
			if light is Light3D:
				light.visible = true
		await get_tree().create_timer(interval).timeout
