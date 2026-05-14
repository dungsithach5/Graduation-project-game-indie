extends StaticBody3D

@export var item_id: int = 1
@export var is_full: bool = false
@export var restock_time: float = 2.0

@onready var label := $shelf/Label3D
@onready var item_spawn := $ItemSpawn
@onready var area := $Area3D

var item_instance: Node3D = null
var player_in_range: bool = false
var player_ref: Node3D = null
var restock_progress: float = 0.0
var is_restocking: bool = false

@onready var restock_ui := get_tree().get_root().find_child("ProgressUI", true, false)
@onready var progress_bar := restock_ui.get_node("ProgressBar") if restock_ui else null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_item_mesh()
	update_shelf()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !is_full and player_in_range and player_ref:
		if Input.is_action_pressed("hold_interact") and player_ref.interaction_controller.current_object != null:
			is_restocking = true
			restock_progress += delta
			_update_progress_bar()
			if restock_progress >= restock_time:
				_finish_restock()
		else:
			_reset_restock()
	else:
		is_restocking = false


func load_item_mesh() -> void:
	if item_instance:
		item_instance.queue_free()
		item_instance = null

	var path = "res://models/interactions/aisle_items_" + str(item_id) + ".glb"
	var packed = load(path)
	item_instance = packed.instantiate()
	item_spawn.add_child(item_instance)

func update_shelf() -> void:
	if item_instance:
		item_instance.visible = is_full

	label.visible = not is_full
	label.text = "Empty"

func restock() -> void:
	is_full = true
	update_shelf()

func empty_shelf() -> void:
	is_full = false
	update_shelf()

func _update_progress_bar() -> void:
	if progress_bar:
		progress_bar.visible = true
		progress_bar.value = (restock_progress / restock_time) * 100

func _reset_restock() -> void:
	is_restocking = false
	restock_progress = 0.0
	if progress_bar:
		progress_bar.visible = false
		progress_bar.value = 0

func _finish_restock() -> void:
	if player_ref and player_ref.interaction_controller.current_object:
		player_ref.interaction_controller.current_object.queue_free()
		player_ref.interaction_controller.current_object = null
		restock()
		_reset_restock()
		if Director.shift_active:
			var current_night = Director.nights[Director.current_night_index]
			if Director.current_event_index < current_night.events.size():
				var current_event = current_night.events[Director.current_event_index]
				if current_event != null and current_event.type == 1: # 1 là RESTOCK_SHELVES
					TaskManager.update_task()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		_reset_restock()
