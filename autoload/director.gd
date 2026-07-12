extends Node3D

const SAVE_FILE_PATH := "user://save_game_by_night.json"

signal shift_started
signal shift_ended
signal event_triggered(event_type: String)

signal talk_to_npc_requested(count: int)
signal empty_shelves_requested(count: int)
signal customer_shopping_requested(count: int)
signal clean_floor_requested(count: int)
signal monster_interaction_requested(count: int)
signal go_home_requested(count: int)
signal extinguish_fire_requested(count: int)
signal turn_on_power_requested(count: int)
signal return_broom_requested(count: int)
signal return_extinguisher_requested(count: int)

signal task_delay_started(delay: float)

@export var nights: Array[ShiftData] = []

var current_night_index: int = 0
var current_event_index: int = 0
var shift_active: bool = false
var delay_timer: float = 0.0
var waiting_for_delay: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Director: Save file path = " + get_save_file_path())
	_load_saved_progress()
	TaskManager.task_completed.connect(_on_task_completed)

func start_new_game() -> void:
	current_night_index = 0
	current_event_index = 0
	shift_active = false
	waiting_for_delay = false
	delay_timer = 0.0
	clear_saved_progress()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://worlds/sandbox.tscn")


func save_game_by_night() -> bool:
	if nights.is_empty():
		print("Director: No nights available to save.")
		return false

	var clamped_night_index: int = clampi(current_night_index, 0, nights.size() - 1)
	var save_data := {
		"current_night_index": clamped_night_index,
		"night_name": nights[clamped_night_index].night_name,
		"saved_at": Time.get_datetime_string_from_system(),
	}

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		print("Director: Failed to open save file for writing at " + get_save_file_path())
		return false

	file.store_string(JSON.stringify(save_data))
	print("Director: Saved progress for " + nights[clamped_night_index].night_name + " at " + get_save_file_path())
	return true

func get_save_file_path() -> String:
	return ProjectSettings.globalize_path(SAVE_FILE_PATH)

func clear_saved_progress() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return

	DirAccess.remove_absolute(get_save_file_path())

func _load_saved_progress() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("Director: There is no save file at " + get_save_file_path())
		return

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		print("Director: Failed to open save file for reading.")
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		print("Director: Save file is invalid, ignoring it.")
		return

	if nights.is_empty():
		return

	var saved_night_index := int(parsed.get("current_night_index", 0))
	current_night_index = clamp(saved_night_index, 0, nights.size() - 1)
	current_event_index = 0
	shift_active = false
	waiting_for_delay = false
	delay_timer = 0.0
	print("Director: Loaded saved progress for " + nights[current_night_index].night_name + " from " + get_save_file_path())
	
func start_shift() -> void:
	if current_night_index >= nights.size():
		print("Director: No more nights available!")
		return
	shift_active = true
	current_event_index = 0
	print("Director: " + nights[current_night_index].night_name + " Started")
	emit_signal("shift_started")
	_send_current_event()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not waiting_for_delay:
		return
	delay_timer -= delta
	if delay_timer <= 0.0:
		waiting_for_delay = false
		_send_current_event()

func _send_current_event() -> void:
	if current_night_index >= nights.size():
		return
	var current_night = nights[current_night_index]
	if current_event_index >= current_night.events.size():
		_end_shift()
		return
	var event = current_night.events[current_event_index]
	if event == null:
		print("Director: Found empty event slot in send, skipping...")
		_on_task_completed()
		return
		
	print("Director: Sending event" + str(current_event_index))
	emit_signal("event_triggered", str(event))
	TaskManager.get_task_details(event.task_count_required)
	_handle_event(event)

func _handle_event(event) -> void:
	match event.type:
		0: # TALK_TO_NPC
			emit_signal("talk_to_npc_requested", event.task_count_required)
		1: # RESTOCK_SHELVES
			emit_signal("empty_shelves_requested", event.task_count_required)
		2: # CUSTOMER_SHOPPING
			emit_signal("customer_shopping_requested", event.task_count_required)
		3: # CLEAN_FLOOR
			emit_signal("clean_floor_requested", event.task_count_required)
		4: # MONSTER_INTERACTION
			emit_signal("monster_interaction_requested", event.task_count_required)
		5: # GO_HOME
			emit_signal("go_home_requested", event.task_count_required)
		6: # EXTINGUISH_FIRE
			emit_signal("extinguish_fire_requested", event.task_count_required)
		7: # TURN_ON_POWER
			var lighting_mart = get_tree().get_current_scene().find_child("LightingMart", true, false)
			if lighting_mart:
				for child in lighting_mart.get_children():
					if child is Light3D:
						child.visible = false
			
			# Play power cut sound
			var power_cut_audio = AudioStreamPlayer.new()
			power_cut_audio.stream = load("res://sounds/power-cut.mp3")
			power_cut_audio.volume_db = 10.0 # Make it louder
			power_cut_audio.bus = &"SFX"
			get_tree().get_current_scene().add_child(power_cut_audio)
			power_cut_audio.play()
			
			emit_signal("turn_on_power_requested", event.task_count_required)
		9: # RETURN_BROOM
			emit_signal("return_broom_requested", event.task_count_required)
		10: # RETURN_EXTINGUISHER
			emit_signal("return_extinguisher_requested", event.task_count_required)

func _on_task_completed() -> void:
	print("Director: Task Completed")
	if current_night_index >= nights.size():
		print("Director: All nights completed, ignoring task completed signal.")
		return
	var current_night = nights[current_night_index]
	
	var completed_event = current_night.events[current_event_index]
	var dialogue_to_play: String = ""
	if completed_event != null:
		if completed_event.type == 1: # RESTOCK_SHELVES
			dialogue_to_play = "dialogic_after_restock"
		elif completed_event.type == 3: # CLEAN_FLOOR
			dialogue_to_play = "dialogic_off_work"
		elif completed_event.type == 6: # EXTINGUISH_FIRE
			dialogue_to_play = "dialogic_after_fire"
	
	current_event_index += 1
	
	if dialogue_to_play != "":
		Dialogic.start(dialogue_to_play)
		Dialogic.timeline_ended.connect(_on_dialogue_ended_after_task)
		return
		
	_proceed_to_next_event()

func _on_dialogue_ended_after_task() -> void:
	if Dialogic.timeline_ended.is_connected(_on_dialogue_ended_after_task):
		Dialogic.timeline_ended.disconnect(_on_dialogue_ended_after_task)
		
	# Dọn dẹp/ẩn gold bar sau khi đối thoại dập lửa kết thúc
	if current_night_index < nights.size():
		var current_night = nights[current_night_index]
		var completed_event_idx = current_event_index - 1
		if completed_event_idx >= 0 and completed_event_idx < current_night.events.size():
			var completed_event = current_night.events[completed_event_idx]
			if completed_event != null and completed_event.type == 6: # EXTINGUISH_FIRE
				var fire_effect = get_tree().get_current_scene().find_child("fireEffect", true, false)
				if fire_effect:
					fire_effect.queue_free()
				
	_proceed_to_next_event()

func _proceed_to_next_event() -> void:
	if current_night_index >= nights.size():
		return
	var current_night = nights[current_night_index]
	if current_event_index >= current_night.events.size():
		_end_shift()
		return
		
	var next_event = current_night.events[current_event_index]
	
	if next_event == null:
		print("Director: Found empty event slot, skipping...")
		_on_task_completed() # skip to the next one
		return
		
	print("Director: Next Event: " + str(next_event.delay))
	if next_event.delay > 0.0:
		print("Director: Starting delay timer of " + str(next_event.delay))
		delay_timer = next_event.delay
		waiting_for_delay = true
		emit_signal("task_delay_started", next_event.delay)
	else:
		print("Director: No delay, sending next event")
		_send_current_event()

func get_current_event_type() -> int:
	if not shift_active:
		return -1
	if current_night_index >= nights.size():
		return -1
	var current_night = nights[current_night_index]
	if current_event_index >= current_night.events.size():
		return -1
	var event = current_night.events[current_event_index]
	if event == null:
		return -1
	return event.type

func get_random_number() -> int:
	return randi_range(1, 2)

func _end_shift() -> void:
	print("Director: Shift Ended")
	shift_active = false
	current_night_index += 1 # Advance to next night for next time
	save_game_by_night()
	emit_signal("shift_ended")
