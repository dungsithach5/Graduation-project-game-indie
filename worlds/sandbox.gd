extends Node3D
@onready var sandbox = $"."
@onready var pause_menu = $CanvasLayer/PauseMenu

@onready var shelf_container = $ShelfContainer

var customers: Array[Node] = []
var current_customer_index: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Thiết lập thaytu chỉ xuất hiện ở đêm 3 (current_night_index = 2)
	var thaytu_node = get_node_or_null("thaytu")
	if thaytu_node:
		if Director.current_night_index != 2:
			thaytu_node.queue_free()

	# Thiết lập NPC1 ẩn từ đêm 3 trở đi (current_night_index >= 2)
	var npc1_node = get_node_or_null("NPC1")
	if npc1_node:
		if Director.current_night_index >= 2:
			npc1_node.queue_free()
	
	# Thiết lập Night 4 (current_night_index = 3)
	var enemy3d_node = get_node_or_null("Enemy3D")
	var area_emulet_node = get_node_or_null("Area_emulet")
	var trigger_ghost_node = get_node_or_null("TriggerGhost")
	
	if Director.current_night_index == 3:
		# Night 4: Thêm Night4EndingHandler để quản lý ending
		var ending_handler = Node.new()
		ending_handler.set_script(load("res://worlds/night4_ending.gd"))
		ending_handler.name = "Night4EndingHandler"
		call_deferred("add_child", ending_handler)
		print("Sandbox: Night 4 - Ending handler added")
	else:
		# Không phải Night 4: Xóa các node không cần
		if enemy3d_node:
			enemy3d_node.queue_free()
		if area_emulet_node:
			area_emulet_node.queue_free()
		if trigger_ghost_node:
			trigger_ghost_node.queue_free()

	TaskManager.task_completed.connect(_on_all_tasks_completed)
	
	# Connect to Director's task signals
	Director.talk_to_npc_requested.connect(_on_talk_to_npc_requested)
	Director.empty_shelves_requested.connect(get_shelf_children)
	Director.customer_shopping_requested.connect(_on_customer_shopping_requested)
	Director.clean_floor_requested.connect(_on_clean_floor_requested)
	Director.turn_on_power_requested.connect(_on_turn_on_power_requested)
	
	# Bắt sự kiện khi hết đêm để chuyển cảnh
	Director.shift_ended.connect(_on_shift_ended)
	
	# Setup interaction for fuse boxes in the scene
	var root_node = get_node_or_null("NavigationRegion3D/weenmart/Sketchfab_model/6twelve_fbx/RootNode")
	if root_node:
		for name in ["Fuse_Boxes", "Fuse_Boxes_01", "Fuse_Boxes_02"]:
			var box_node = root_node.get_node_or_null(name)
			if box_node:
				var static_body = _find_static_body(box_node)
				if static_body:
					var interaction_comp_scene = load("res://interaction/interaction_component.tscn")
					if interaction_comp_scene:
						var comp = interaction_comp_scene.instantiate()
						comp.interaction_type = 7 # 7 là FUSE_BOX
						comp.name = "InteractionComponent"
						static_body.add_child(comp)
						comp.object_ref = static_body
						print("Sandbox: Attached InteractionComponent to fuse box " + name)
	
	Director.start_shift()


	customers = find_children("npc_customer*", "", true, false)
	customers.sort_custom(func(a, b): return a.name < b.name)
	for c in customers:
		c.visible = false
		c.process_mode = Node.PROCESS_MODE_DISABLED
	if customers.size() == 0:
		print("Sandbox: Cảnh báo - Không tìm thấy NPC khách hàng nào lúc khởi động.")
	
	pause_menu.visible = false

func _on_all_tasks_completed() -> void:
	pass

func _on_talk_to_npc_requested(limit: int) -> void:
	print("Sandbox: Bắt đầu Task 1 - Đi gặp Quản lý")
	# Task 1 đang chờ người chơi bấm E vào NPC Quản lý để hoàn thành.

func _on_customer_shopping_requested(limit: int) -> void:
	print("Sandbox: Bắt đầu Task 3 - Khách hàng vào quán. Số lượng yêu cầu: ", limit)
	current_customer_index = 0
	_activate_next_customer()

func _activate_next_customer() -> void:
	if current_customer_index < customers.size():
		var next_customer = customers[current_customer_index]
		if is_instance_valid(next_customer):
			next_customer.visible = true
			next_customer.process_mode = Node.PROCESS_MODE_INHERIT
			if not next_customer.tree_exited.is_connected(_on_customer_exited):
				next_customer.tree_exited.connect(_on_customer_exited)
			print("Sandbox: Đã kích hoạt NPC khách hàng: ", next_customer.name)
		else:
			current_customer_index += 1
			_activate_next_customer()
	else:
		print("Sandbox: Không còn khách hàng nào trong danh sách để kích hoạt.")

func _on_customer_exited() -> void:
	if Director.shift_active and Director.current_night_index < Director.nights.size():
		var current_night = Director.nights[Director.current_night_index]
		if Director.current_event_index < current_night.events.size():
			var current_event = current_night.events[Director.current_event_index]
			if current_event != null and current_event.type == 2: # CUSTOMER_SHOPPING
				TaskManager.update_task()
				if Director.get_current_event_type() != 2:
					return
				current_customer_index += 1
				call_deferred("_activate_next_customer")

func _on_clean_floor_requested(limit: int) -> void:
	print("Sandbox: Bắt đầu Task 4 - Lau dọn")
	# Tương tự, nếu bạn đang giấu sẵn vết bẩn, thì bật nó lên
	# Hoặc instantiate() vết bẩn ở đây.
	
	# Ví dụ tìm vết bẩn đã giấu trong scene:
	# var stain = get_node_or_null("Stain")
	# if stain:
	# 	stain.visible = true
	# 	stain.process_mode = Node.PROCESS_MODE_INHERIT
	
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
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_shift_ended() -> void:
	# Night 4 ending được xử lý bởi Night4EndingHandler
	if get_node_or_null("Night4EndingHandler"):
		print("Sandbox: Night 4 shift ended - Night4EndingHandler sẽ xử lý")
		return
	print("Sandbox: Chuyển cảnh sang màn hình thông báo đêm mới...")
	# Mở chuột lên để bấm nút (nếu có)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Tải scene panel_night_2
	get_tree().change_scene_to_file("res://panel_night_2.tscn")

func _on_turn_on_power_requested(limit: int) -> void:
	print("Sandbox: Bắt đầu Task - Mở nguồn điện tại hộp điện")

func _find_static_body(node: Node) -> StaticBody3D:
	if node is StaticBody3D:
		return node
	for child in node.get_children():
		var found = _find_static_body(child)
		if found:
			return found
	return null
