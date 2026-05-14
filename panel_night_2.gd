extends CanvasLayer

func _ready() -> void:
	# Lấy số của đêm tiếp theo từ Director 
	# (Do kết thúc Đêm 1 (số 0) thì Director tự tăng biến current_night_index lên Đêm 2 (số 1))
	var next_night_number = Director.current_night_index + 1
	
	# Tìm đến Label và sửa thành "Night X"
	var label = get_node_or_null("Panel/Label")
	if label:
		label.text = "Night " + str(next_night_number)
	else:
		print("Không tìm thấy Label ở đường dẫn Panel/Label!")
	
	# Chờ 3 giây rồi tự động quay lại tiệm tạp hóa
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://worlds/sandbox.tscn")
