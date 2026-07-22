extends Node3D

@export var extinguish_time: float = 3.0

var player_in_range: bool = false
var player_ref: Player = null
var extinguish_progress: float = 0.0
var is_extinguishing: bool = false
var fire_audio: AudioStreamPlayer3D = null

@onready var progress_ui := get_tree().get_root().find_child("ProgressUI", true, false)
@onready var progress_bar := progress_ui.get_node("ProgressBar") if progress_ui else null

@onready var particles1: GPUParticles3D = get_node_or_null("GPUParticles3D")
@onready var particles2: GPUParticles3D = get_node_or_null("GPUParticles3D2")

func log_to_file(msg: String) -> void:
	var f = FileAccess.open("res://fire_debug.log", FileAccess.READ_WRITE)
	if not f:
		f = FileAccess.open("res://fire_debug.log", FileAccess.WRITE)
	else:
		f.seek_end()
	f.store_line(str(Time.get_time_string_from_system()) + ": " + msg)
	f.close()

func _ready() -> void:
	log_to_file("Fire _ready() called. Node path: " + str(get_path()))
	
	# Hide ourselves initially
	visible = false
	
	# Disable Area3D initially
	var area = get_node_or_null("Area3D")
	if area:
		area.monitoring = false
		area.monitorable = false
		area.collision_mask = 0xFFFFFFFF # Ensure it monitors all layers (avoid layer mismatch)
		log_to_file("Area3D found, monitoring set to false initially")
	else:
		log_to_file("WARNING: Area3D NOT found under fireEffect!")
		
	# Hide particles initially
	if particles1:
		particles1.emitting = false
		particles1.visible = false
	if particles2:
		particles2.emitting = false
		particles2.visible = false
		
	# Connect to Director signal
	if not Director.extinguish_fire_requested.is_connected(_on_extinguish_fire_requested):
		Director.extinguish_fire_requested.connect(_on_extinguish_fire_requested)
		
	# Initialize fire AudioStreamPlayer3D
	fire_audio = AudioStreamPlayer3D.new()
	fire_audio.stream = preload("res://sounds/fire-sounds.mp3")
	fire_audio.bus = &"SFX"
	fire_audio.unit_size = 5.0
	fire_audio.max_db = 3.0
	fire_audio.finished.connect(func():
		if is_instance_valid(fire_audio):
			fire_audio.play()
	)
	add_child(fire_audio)
		
	# If current event is already extinguish_fire (e.g. reload or ready during event), activate it
	if Director.get_current_event_type() == 6: # EXTINGUISH_FIRE
		_on_extinguish_fire_requested(1)

func _on_extinguish_fire_requested(count: int) -> void:
	log_to_file("Fire event requested. Activating fire.")
	visible = true
	
	# Show and emit particles
	if particles1:
		particles1.emitting = true
		particles1.visible = true
	if particles2:
		particles2.emitting = true
		particles2.visible = true
		
	# Enable Area3D monitoring
	var area = get_node_or_null("Area3D")
	if area:
		area.monitoring = true
		area.monitorable = true
		
	# Play fire sound
	if fire_audio and not fire_audio.playing:
		fire_audio.play()
		
	# Ensure process is active
	set_process(true)

func _process(delta: float) -> void:
	if player_in_range and player_ref:
		_update_extinguish_prompt()
		# Check if the player is holding the extinguisher and holding 'F' (hold_interact)
		if Input.is_action_pressed("hold_interact"):
			if player_ref.interaction_controller and player_ref.interaction_controller.current_object:
				var current_obj = player_ref.interaction_controller.current_object
				var obj_name = current_obj.name.to_lower()
				var parent_name = ""
				if current_obj.get_parent():
					parent_name = current_obj.get_parent().name.to_lower()
				
				if "extinguisher" in obj_name or "extinguisher" in parent_name:
					is_extinguishing = true
					extinguish_progress += delta
					_update_progress_bar()
					
					# Tell the extinguisher to start spraying
					if current_obj.has_method("start_spraying"):
						current_obj.start_spraying(player_ref.interaction_controller.hand)
					
					if extinguish_progress >= extinguish_time:
						log_to_file("Fire extinguished completely!")
						_finish_extinguish()
					return
				else:
					# Debug log if we hold F but object is not extinguisher
					if Engine.get_frames_drawn() % 60 == 0:
						log_to_file("F held but holding wrong object: " + obj_name + " / " + parent_name)
			else:
				if Engine.get_frames_drawn() % 60 == 0:
					log_to_file("F held but player holds nothing.")
		else:
			# Only reset if we were actively extinguishing and the player released the key
			if is_extinguishing:
				_reset_extinguish()
	else:
		# Player left range: fully reset and clear prompt
		_reset_extinguish()
		_clear_extinguish_prompt()

func _update_extinguish_prompt() -> void:
	if not player_ref or not player_ref.interaction_controller:
		return

	if not visible or not player_in_range:
		_clear_extinguish_prompt()
		return

	if _is_holding_extinguisher(player_ref):
		_show_extinguish_prompt()
	else:
		_clear_extinguish_prompt()

func _show_extinguish_prompt() -> void:
	if player_ref and player_ref.interaction_controller:
		player_ref.interaction_controller.forced_label_text = "Hold [F] to extinguish"

func _clear_extinguish_prompt() -> void:
	if player_ref and player_ref.interaction_controller:
		player_ref.interaction_controller.forced_label_text = ""

func _is_holding_extinguisher(player: Node) -> bool:
	if not player or not player.interaction_controller:
		return false

	var held_object = player.interaction_controller.current_object
	if held_object == null:
		return false

	var obj_name = held_object.name.to_lower()
	var parent_name = ""
	if held_object.get_parent():
		parent_name = held_object.get_parent().name.to_lower()

	return "extinguisher" in obj_name or "extinguisher" in parent_name

func _update_progress_bar() -> void:
	if progress_bar:
		progress_bar.visible = true
		progress_bar.value = (extinguish_progress / extinguish_time) * 100

func _reset_extinguish() -> void:
	if is_extinguishing:
		log_to_file("Resetting extinguish progress.")
		is_extinguishing = false
		extinguish_progress = 0.0
		if progress_bar:
			progress_bar.visible = false
			progress_bar.value = 0
		
		# Tell the extinguisher to stop spraying
		if player_ref and player_ref.interaction_controller and player_ref.interaction_controller.current_object:
			var current_obj = player_ref.interaction_controller.current_object
			if current_obj.has_method("stop_spraying"):
				current_obj.stop_spraying()


func _finish_extinguish() -> void:
	log_to_file("Finishing extinguish.")
	_reset_extinguish()
	_clear_extinguish_prompt()
	
	# Stop fire sound
	if fire_audio and fire_audio.playing:
		fire_audio.stop()
	
	# Stop spraying foam
	if player_ref and player_ref.interaction_controller and player_ref.interaction_controller.current_object:
		var current_obj = player_ref.interaction_controller.current_object
		if current_obj.has_method("stop_spraying"):
			current_obj.stop_spraying()
			
	# Hide the fire particles immediately, but keep the root node (and Gold_bars) visible
	if particles1:
		particles1.emitting = false
		particles1.visible = false
	if particles2:
		particles2.emitting = false
		particles2.visible = false
		
	# Remove the Area3D so it doesn't trigger anymore interactions or damage
	var area = get_node_or_null("Area3D")
	if area:
		area.queue_free()
		
	# Update task progress if in shift and current event is EXTINGUISH_FIRE
	if Director.shift_active and Director.current_night_index < Director.nights.size():
		var current_night = Director.nights[Director.current_night_index]
		if Director.current_event_index < current_night.events.size():
			var current_event = current_night.events[Director.current_event_index]
			if current_event != null and current_event.type == 6: # 6 là EXTINGUISH_FIRE
				TaskManager.update_task()
		
	# Disable processing on this node since it's already extinguished
	set_process(false)

func _on_area_3d_body_entered(body: Node3D) -> void:
	print("Body entered fire Area3D: " + body.name + " (Group 'player': " + str(body.is_in_group("player")) + ")")
	if body.is_in_group("player") or body is Player:
		player_in_range = true
		player_ref = body as Player
		print("Player successfully set in range.")
		_update_extinguish_prompt()

func _on_area_3d_body_exited(body: Node3D) -> void:
	print("Body exited fire Area3D: " + body.name)
	if body.is_in_group("player") or body is Player:
		_clear_extinguish_prompt()
		player_in_range = false
		_reset_extinguish()
		player_ref = null
		print("Player exited range.")
