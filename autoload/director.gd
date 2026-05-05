extends Node3D

signal shift_started
signal shift_ended
signal event_triggered(event_type: String)
signal empty_shelves_requested(count: int)
signal task_delay_started(delay: float)

@export var shift_events: Array = []

var current_event_index: int = 0
var shift_active: bool = false
var delay_timer: float = 0.0
var waiting_for_delay: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	TaskManager.task_completed.connect(_on_task_completed)

func start_shift() -> void:
	shift_active = true
	current_event_index = 0
	print("Director: Shift Started")
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
	if current_event_index >= shift_events.size():
		_end_shift()
		return
	var event = shift_events[current_event_index]
	print("Director: Sending event" + str(current_event_index))
	emit_signal("event_triggered", str(event))
	TaskManager.get_task_details(event.task_count_required)
	_handle_event(event)

func _handle_event(event) -> void:
	emit_signal("empty_shelves_requested", event.task_count_required)

func _on_task_completed() -> void:
	print("Director: Task Completed, moving to next week")
	current_event_index += 1
	if current_event_index >= shift_events.size():
		_end_shift()
		return
	var next_event = shift_events[current_event_index]
	print("Director: Next Event: " + str(next_event.delay))
	if next_event.delay > 0.0:
		print("Director: Starting  delay timer of " + str(next_event.delay))
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
	emit_signal("shift_ended")