extends Node3D

## Vị trí đặt bình chữa cháy gốc (sẽ được set từ sandbox.gd)
@export var ext_original_position: Vector3 = Vector3.ZERO
@export var ext_original_transform: Transform3D = Transform3D.IDENTITY

var is_active: bool = false
var ghost_ext: Node3D = null

# Theo dõi trạng thái cầm bình chữa cháy giữa các frame
var _was_holding_ext: bool = false
var _last_held_ext_obj: Node3D = null

func _ready() -> void:
	visible = false
	# Connect to Director signal
	if not Director.return_extinguisher_requested.is_connected(_on_return_extinguisher_requested):
		Director.return_extinguisher_requested.connect(_on_return_extinguisher_requested)
	
	# Tạo ghost extinguisher (bản sao vàng trong suốt)
	_create_ghost_extinguisher()

func _create_ghost_extinguisher() -> void:
	# Load extinguisher scene và instantiate
	var ext_scene = load("res://models/objects/extinguisher.tscn")
	if ext_scene == null:
		print("ExtinguisherReturnZone: Không thể load extinguisher scene!")
		return
	
	ghost_ext = ext_scene.instantiate()
	ghost_ext.name = "GhostExtinguisher"
	add_child(ghost_ext)
	
	# Tạo material vàng trong suốt
	var yellow_material = StandardMaterial3D.new()
	yellow_material.albedo_color = Color(1.0, 0.85, 0.0, 0.5) # Vàng, alpha 50%
	yellow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	yellow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# Áp dụng material vàng cho tất cả MeshInstance3D
	_apply_material_recursive(ghost_ext, yellow_material)
	
	# Disable physics và interaction trên ghost extinguisher
	_disable_physics_recursive(ghost_ext)

func _apply_material_recursive(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		for i in range(mesh_instance.get_surface_override_material_count()):
			mesh_instance.set_surface_override_material(i, material)
	for child in node.get_children():
		_apply_material_recursive(child, material)

func _disable_physics_recursive(node: Node) -> void:
	if node is CollisionShape3D:
		node.disabled = true
	if node is RigidBody3D:
		node.freeze = true
	# Xóa InteractionComponent nếu có
	var interaction_comp = node.get_node_or_null("InteractionComponent")
	if interaction_comp:
		interaction_comp.queue_free()
	for child in node.get_children():
		_disable_physics_recursive(child)

func _on_return_extinguisher_requested(_count: int) -> void:
	print("ExtinguisherReturnZone: Task Return the Extinguisher đã bắt đầu!")
	is_active = true
	visible = true

func _process(_delta: float) -> void:
	if not is_active or not visible:
		return
	
	# Tìm player trong group
	var player_ref = get_tree().get_first_node_in_group("player")
	if player_ref == null:
		_was_holding_ext = false
		_last_held_ext_obj = null
		return
	
	# Tính khoảng cách đến player
	var distance = global_position.distance_to(player_ref.global_position)
	if distance > 2.0:
		# Ngoài khoảng cách -> reset trạng thái và xóa label gợi ý
		_was_holding_ext = false
		_last_held_ext_obj = null
		_clear_interact_label(player_ref)
		return
	
	if player_ref.interaction_controller == null:
		_was_holding_ext = false
		_last_held_ext_obj = null
		return
	
	# Kiểm tra player có đang cầm bình chữa cháy frame này không
	var currently_holding_ext = false
	
	if player_ref.interaction_controller.current_object != null:
		var current_obj = player_ref.interaction_controller.current_object
		var obj_name = current_obj.name.to_lower()
		var parent_name = ""
		if current_obj.get_parent():
			parent_name = current_obj.get_parent().name.to_lower()
		if "extinguisher" in obj_name or "extinguisher" in parent_name:
			currently_holding_ext = true
			_last_held_ext_obj = current_obj
	
	if currently_holding_ext:
		# Player đang cầm bình chữa cháy trong zone, ghi nhớ và hiện label
		_was_holding_ext = true
		_show_interact_label(player_ref)
	elif _was_holding_ext:
		# Player VỪA thả bình chữa cháy ra (frame trước cầm, frame này không cầm)
		# → Tự động snap bình chữa cháy về vị trí cũ và hoàn thành task
		_was_holding_ext = false
		_clear_interact_label(player_ref)
		if is_instance_valid(_last_held_ext_obj):
			_return_extinguisher(player_ref, _last_held_ext_obj)
		_last_held_ext_obj = null
	else:
		_clear_interact_label(player_ref)

func _show_interact_label(player: Node) -> void:
	if player and player.interaction_controller:
		player.interaction_controller.forced_label_text = "[E] Return Extinguisher"

func _clear_interact_label(player: Node) -> void:
	if player and player.interaction_controller:
		if player.interaction_controller.forced_label_text == "[E] Return Extinguisher":
			player.interaction_controller.forced_label_text = ""

func _return_extinguisher(player: Node, ext_object: Node3D) -> void:
	print("ExtinguisherReturnZone: Player đã trả bình chữa cháy!")
	
	# ext_object là RigidBody3D (con của EXTINGUISHER scene)
	# Tìm extinguisher root node (EXTINGUISHER - Node3D parent)
	var ext_root = ext_object
	if ext_object.owner and ext_object.owner != get_tree().current_scene:
		ext_root = ext_object.owner
	elif ext_object.get_parent() and ext_object.get_parent() != get_tree().current_scene:
		ext_root = ext_object.get_parent()
	
	# Khóa bình chữa cháy trước - freeze RigidBody3D để physics không can thiệp
	var rigid_body = ext_object as RigidBody3D
	if rigid_body:
		rigid_body.freeze = true
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO
	
	# Snap bình chữa cháy về vị trí ban đầu
	# 1. Đặt extinguisher root (EXTINGUISHER node) về vị trí gốc
	ext_root.global_transform = ext_original_transform
	# 2. Reset RigidBody3D con về local transform identity (vị trí gốc tương đối với parent)
	if ext_object != ext_root:
		ext_object.transform = Transform3D.IDENTITY
	
	# Disable collision để bình không bị đẩy
	if rigid_body:
		for child in rigid_body.get_children():
			if child is CollisionShape3D:
				child.disabled = true
	
	# Disable interaction để player không nhặt lại được
	var interact_comp = ext_object.get_node_or_null("InteractionComponent")
	if interact_comp:
		interact_comp.can_interact = false
	
	# Nếu không tìm thấy trên ext_object, tìm trong ext_root
	if interact_comp == null and ext_root != ext_object:
		interact_comp = _find_interaction_component(ext_root)
		if interact_comp:
			interact_comp.can_interact = false
	
	# Ẩn ghost extinguisher
	if ghost_ext:
		ghost_ext.visible = false
	
	# Hoàn thành task
	if Director.shift_active and Director.current_night_index < Director.nights.size():
		var current_night = Director.nights[Director.current_night_index]
		if Director.current_event_index < current_night.events.size():
			var current_event = current_night.events[Director.current_event_index]
			if current_event != null and current_event.type == 10: # 10 là RETURN_EXTINGUISHER
				TaskManager.update_task()
	
	is_active = false
	visible = false
	print("ExtinguisherReturnZone: Task hoàn thành!")

func _find_interaction_component(node: Node) -> Node:
	var comp = node.get_node_or_null("InteractionComponent")
	if comp:
		return comp
	for child in node.get_children():
		comp = _find_interaction_component(child)
		if comp:
			return comp
	return null
