extends Node3D

signal shift_started
signal shift_ended
signal event_triggered(event_type: String)

signal talk_to_npc_requested(count: int)
signal empty_shelves_requested(count: int)
signal customer_shopping_requested(count: int)
signal clean_floor_requested(count: int)
signal monster_interaction_requested(count: int)
signal go_home_requested(count: int)

signal task_delay_started(delay: float)

@export var nights: Array[ShiftData] = []

var current_night_index: int = 0
var current_event_index: int = 0
var shift_active: bool = false
var delay_timer: float = 0.0
var waiting_for_delay: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	TaskManager.task_completed.connect(_on_task_completed)

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

func _on_task_completed() -> void:
	print("Director: Task Completed")
	var current_night = nights[current_night_index]
	
	var completed_event = current_night.events[current_event_index]
	var dialogue_to_play: String = ""
	if completed_event != null:
		if completed_event.type == 1: # RESTOCK_SHELVES
			dialogue_to_play = "dialogic_after_restock"
		elif completed_event.type == 3: # CLEAN_FLOOR
			dialogue_to_play = "dialogic_off_work"
	
	current_event_index += 1
	
	if dialogue_to_play != "":
		Dialogic.start(dialogue_to_play)
		Dialogic.timeline_ended.connect(_on_dialogue_ended_after_task)
		return
		
	_proceed_to_next_event()

func _on_dialogue_ended_after_task() -> void:
	if Dialogic.timeline_ended.is_connected(_on_dialogue_ended_after_task):
		Dialogic.timeline_ended.disconnect(_on_dialogue_ended_after_task)
	_proceed_to_next_event()

func _proceed_to_next_event() -> void:
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

func get_random_number() -> int:
	return randi_range(1, 2)

func _end_shift() -> void:
	print("Director: Shift Ended")
	shift_active = false
	current_night_index += 1 # Advance to next night for next time
	emit_signal("shift_ended")
