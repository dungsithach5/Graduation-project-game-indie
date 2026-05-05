extends Panel

@onready var objective_body := $VBoxContainer/ObjectiveBody
@onready var objective_counter := $VBoxContainer/ObjectiveCounter

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	TaskManager.task_updated.connect(_on_task_updated)
	TaskManager.task_started.connect(_on_task_started)
	Director.event_triggered.connect(_on_event_triggered)
	Director.task_delay_started.connect(_on_task_delay_started)

func _on_event_triggered(event_type: String) -> void:
	var event = Director.shift_events[Director.current_event_index]
	objective_body.text = event.description

func _on_task_started(current: int, requirement: int) -> void:
	objective_counter.text = str(current) + "/" + str(requirement)

func _on_task_updated(current: int, requirement: int) -> void:
	objective_counter.text = str(current) + "/" + str(requirement)

func _on_task_delay_started(delay: float) -> void:
	objective_body.text = ""
	objective_counter.text = ""

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
