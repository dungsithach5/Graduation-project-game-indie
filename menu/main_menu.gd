extends Node3D

func _ready() -> void:
	# Hiện chuột để có thể bấm nút (phòng trường hợp đang bị ẩn từ scene trước)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Hàm này sẽ được gọi khi bấm nút Start
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://worlds/sandbox.tscn")

# Hàm này sẽ được gọi khi bấm nút Quit
func _on_quit_pressed() -> void:
	get_tree().quit()
