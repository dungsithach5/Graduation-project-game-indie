extends Node3D
@onready var sandbox = $"."
@onready var pause_menu = $CanvasLayer/PauseMenu

@onready var shelf_container = $ShelfContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	TaskManager.task_completed.connect(_on_all_tasks_completed)
	Director.empty_shelves_requested.connect(get_shelf_children)
	Director.start_shift()


	pause_menu.visible = false

func _on_all_tasks_completed() -> void:
	pass

func get_shelf_children(limit: int) -> void:
	if not shelf_container:
		return
	var shelves = shelf_container.get_children()
	var count = 0
	for shelf in shelves:
		if count >= limit:
			break
		if shelf.is_full:
			shelf.empty_shelf()
			count += 1

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("esc"):
		toggle_pause()

func toggle_pause() -> void:
	get_tree().paused = !get_tree().paused
	pause_menu.visible = get_tree().paused
	
	if get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
