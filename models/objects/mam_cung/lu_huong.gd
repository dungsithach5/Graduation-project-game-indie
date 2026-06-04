extends Node3D

@export var insert_time: float = 2.0

var player_in_range: bool = false
var player_ref: Node3D = null
var insert_progress: float = 0.0
var is_inserting: bool = false
var incense_inserted: bool = false

@onready var restock_ui := get_tree().get_root().find_child("ProgressUI", true, false)
@onready var progress_bar := restock_ui.get_node("ProgressBar") if restock_ui else null

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if incense_inserted:
		return
		
	# Kiểm tra xem Task hiện tại có phải là thắp hương (LIGHT_INCENSE = 6) không
	var is_incense_task = false
	if Director.shift_active:
		var current_night = Director.nights[Director.current_night_index]
		if Director.current_event_index < current_night.events.size():
			var current_event = current_night.events[Director.current_event_index]
			if current_event != null and current_event.type == 6: # 6 là LIGHT_INCENSE
				is_incense_task = true
				
	if is_incense_task and player_in_range and player_ref:
		var current_obj = player_ref.interaction_controller.current_object
		var has_incense = false
		if current_obj != null:
			if "nhang" in current_obj.name.to_lower() or (current_obj.get_parent() != null and "nhang" in current_obj.get_parent().name.to_lower()):
				has_incense = true
		
		if has_incense:
			# Hiển thị prompt thắp hương
			if player_ref.interaction_controller:
				player_ref.interaction_controller.forced_label_text = "Hold F to thắp hương"
				
			if Input.is_action_pressed("hold_interact"):
				is_inserting = true
				insert_progress += delta
				_update_progress_bar()
				if insert_progress >= insert_time:
					_finish_insertion()
			else:
				_reset_insertion()
		else:
			_reset_insertion()
	else:
		_reset_insertion()

func _update_progress_bar() -> void:
	if progress_bar:
		progress_bar.visible = true
		progress_bar.value = (insert_progress / insert_time) * 100

func _reset_insertion() -> void:
	is_inserting = false
	insert_progress = 0.0
	if progress_bar:
		progress_bar.visible = false
		progress_bar.value = 0
	if player_ref and player_ref.interaction_controller:
		if player_ref.interaction_controller.forced_label_text == "Hold F to thắp hương":
			player_ref.interaction_controller.forced_label_text = ""

func _finish_insertion() -> void:
	incense_inserted = true
	_reset_insertion()
	
	# Xóa cây nhang cầm trên tay người chơi
	if player_ref and player_ref.interaction_controller.current_object:
		var held_obj = player_ref.interaction_controller.current_object
		var parent_node = held_obj.get_parent()
		if parent_node and "nhang" in parent_node.name.to_lower():
			parent_node.queue_free()
		else:
			held_obj.queue_free()
		player_ref.interaction_controller.current_object = null
		
	# Hiển thị cây nhang cắm tĩnh trong lư hương
	_spawn_incense_in_burner()
	
	# Kích hoạt jumpscare Node3D
	_trigger_jumpscare()
	
	# Cập nhật nhiệm vụ thắp hương hoàn thành
	TaskManager.update_task()

func _spawn_incense_in_burner() -> void:
	var nhang_scene = load("res://models/objects/mam_cung/nhang.tscn")
	if nhang_scene:
		var nhang_instance = nhang_scene.instantiate()
		nhang_instance.name = "NhangBurned"
		
		# Loại bỏ khả năng nhặt lại nhang
		var static_body = nhang_instance.get_node_or_null("StaticBody3D")
		if static_body:
			var interact = static_body.get_node_or_null("InteractionComponent")
			if interact:
				interact.queue_free()
				
			# Tắt va chạm của cây nhang cắm tĩnh để tránh bị các Collider khác (như bàn/lư hương) đẩy ra ngoài
			var collision_shape = static_body.get_node_or_null("CollisionShape3D")
			if collision_shape:
				collision_shape.disabled = true
				
			if static_body is RigidBody3D:
				static_body.freeze = true
				
		add_child(nhang_instance)
		
		# Căn vị trí nhang cắm thẳng đứng dựa trên vị trí TOÀN CỤC của mesh lư hương
		var target_pos = global_position + Vector3(0, 0.05, 0)
		var burner_mesh = find_child("*lu-huong*", true, false)
		if burner_mesh:
			target_pos = burner_mesh.global_position
			# Nhích lên một chút để phần chân nhang cắm đúng độ cao
			target_pos.y += 0.05
				
		nhang_instance.global_position = target_pos
		nhang_instance.global_rotation = Vector3.ZERO
		nhang_instance.scale = Vector3(10.0, 10.0, 10.0) # Do lu_huong bị scale 0.1 nên nhang con cần scale bù
		
		# Tạo hiệu ứng khói bốc lên từ đầu nhang
		_create_smoke_particles(nhang_instance)

func _create_smoke_particles(nhang: Node) -> void:
	# Sử dụng CPUParticles3D để dễ dàng cấu hình bằng code
	var particles = CPUParticles3D.new()
	particles.name = "SmokeParticles"
	
	# Cấu hình hạt khói
	particles.amount = 20
	particles.lifetime = 2.0
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 10.0
	particles.gravity = Vector3(0, 0.1, 0) # Khói bay lên nhẹ
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.5
	particles.scale_amount_min = 0.01
	particles.scale_amount_max = 0.05
	
	# Tạo mesh cho hạt khói (một khối cầu nhỏ màu xám nhạt bán trong suốt)
	var sphere = SphereMesh.new()
	sphere.radius = 0.02
	sphere.height = 0.04
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = mat
	particles.mesh = sphere
	
	# Cấu hình thay đổi kích thước và độ mờ theo thời gian
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = curve
	
	nhang.add_child(particles)
	# Đặt khói xuất hiện ở đầu cây nhang (khoảng 0.45m theo chiều cao của cây nhang)
	particles.position = Vector3(0, 0.45, 0)
	particles.emitting = true

# Các hàm nhận tín hiệu từ Area3D được cấu hình qua Godot Editor
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		_reset_insertion()

func _trigger_jumpscare() -> void:
	var jumpscare_node = get_tree().current_scene.get_node_or_null("Node3D")
	if jumpscare_node:
		var target_pos = Vector3.ZERO
		var altar = get_tree().current_scene.get_node_or_null("mam_cung")
		
		if altar and player_ref:
			# Vector từ player tới bàn thờ
			var to_altar = altar.global_position - player_ref.global_position
			to_altar.y = 0.0 # Giữ trên mặt phẳng ngang
			# Đặt đối diện bàn thờ (phía sau mâm cúng từ góc nhìn của player), cách bàn thờ 1.5m
			target_pos = altar.global_position + to_altar.normalized() * 1.5
			target_pos.y = jumpscare_node.global_position.y
		elif altar:
			# Nếu không có player_ref, đặt mặc định phía sau bàn thờ (hướng Z âm)
			target_pos = altar.global_position + Vector3(0, 0, -1.5)
			target_pos.y = jumpscare_node.global_position.y
		else:
			target_pos = Vector3(-11.18, jumpscare_node.global_position.y, -5.0)
		
		# Di chuyển node cực nhanh (0.2s) tới đối diện bàn thờ/mặt người chơi
		var tween = jumpscare_node.create_tween()
		tween.tween_property(jumpscare_node, "global_position", target_pos, 0.2)
