extends Decal

@export var clean_time: float = 2.0

var player_in_range: bool = false
var player_ref: Node3D = null
var clean_progress: float = 0.0
var is_cleaning: bool = false

@onready var restock_ui := get_tree().get_root().find_child("ProgressUI", true, false)
@onready var progress_bar := restock_ui.get_node("ProgressBar") if restock_ui else null

func _process(delta: float) -> void:
	if player_in_range and player_ref:
		if Input.is_action_pressed("hold_interact"):
			if player_ref.interaction_controller.current_object != null:
				var current_obj = player_ref.interaction_controller.current_object
				var obj_name = current_obj.name.to_lower()
				var parent_name = ""
				if current_obj.get_parent():
					parent_name = current_obj.get_parent().name.to_lower()
				
				# Kiểm tra tên của vật hoặc tên của cha nó (vì bạn cầm StaticBody3D, cha của nó là Broom)
				if "broom" in obj_name or "broom" in parent_name:
					is_cleaning = true
					clean_progress += delta
					_update_progress_bar()
					if clean_progress >= clean_time:
						_finish_clean()
				else:
					_reset_clean()
			else:
				_reset_clean()
		else:
			if is_cleaning:
				_reset_clean()
	else:
		if is_cleaning:
			is_cleaning = false

func _update_progress_bar() -> void:
	if progress_bar:
		progress_bar.visible = true
		progress_bar.value = (clean_progress / clean_time) * 100

func _reset_clean() -> void:
	is_cleaning = false
	clean_progress = 0.0
	if progress_bar:
		progress_bar.visible = false
		progress_bar.value = 0

func _finish_clean() -> void:
	_reset_clean()
	# Xóa luôn vết bẩn (Decal)
	queue_free()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		_reset_clean()
