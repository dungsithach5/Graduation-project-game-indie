extends Node

signal task_completed
signal task_updated(current: int, requirement: int)
signal task_started(current: int, requirement: int)

var current_task: int = 0
var task_requirement: int = 0

func get_task_details(requirement: int) -> void:
	current_task = 0
	task_requirement = requirement
	print("Task Manager: Task Started with requirement " + str(requirement))
	emit_signal("task_started", current_task, task_requirement)

func update_task() -> void:
	current_task += 1
	print("Task Manager: Task Updated to " + str(current_task) + "/" + str(task_requirement))
	emit_signal("task_updated", current_task, task_requirement)
	if current_task >= task_requirement:
		print("Task Manager: Task Completed")
		emit_signal("task_completed")
		current_task = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
