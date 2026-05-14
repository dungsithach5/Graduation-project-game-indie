extends Node3D
@onready var sandbox = $"."
@onready var pause_menu = $CanvasLayer/PauseMenu

@onready var shelf_container = $ShelfContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	TaskManager.task_completed.connect(_on_all_tasks_completed)
	
	# Connect to Director's task signals
	Director.talk_to_npc_requested.connect(_on_talk_to_npc_requested)
	Director.empty_shelves_requested.connect(get_shelf_children)
	Director.customer_shopping_requested.connect(_on_customer_shopping_requested)
	Director.clean_floor_requested.connect(_on_clean_floor_requested)
	
	# Bắt sự kiện khi hết đêm để chuyển cảnh
	Director.shift_ended.connect(_on_shift_ended)
	
	Director.start_shift()


	var customer = find_child("npc_customer*", true, false)
	if customer:
		customer.visible = false
		customer.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		print("Sandbox: Cảnh báo - Không tìm thấy NPC khách hàng lúc khởi động.")
	
	pause_menu.visible = false

func _on_all_tasks_completed() -> void:
	pass

func _on_talk_to_npc_requested(limit: int) -> void:
	print("Sandbox: Bắt đầu Task 1 - Đi gặp Quản lý")
	# Task 1 đang chờ người chơi bấm E vào NPC Quản lý để hoàn thành.

func _on_customer_shopping_requested(limit: int) -> void:
	print("Sandbox: Bắt đầu Task 3 - Khách hàng vào quán")
	# Tìm con khách hàng trong Scene
	var customer = find_child("npc_customer*", true, false) 
	if customer:
		customer.visible = true
		customer.process_mode = Node.PROCESS_MODE_INHERIT
		print("Sandbox: Đã bật NPC khách hàng!")
		# Gọi hàm bắt đầu đi vào của khách (nếu có)
		# Ví dụ: customer.start_shopping()
	else:
		print("Sandbox: Lỗi - Không tìm thấy NPC Khách hàng!")

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
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_shift_ended() -> void:
	print("Sandbox: Chuyển cảnh sang màn hình thông báo đêm mới...")
	# Mở chuột lên để bấm nút (nếu có)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Tải scene panel_night_2
	get_tree().change_scene_to_file("res://panel_night_2.tscn")
