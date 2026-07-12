extends Node3D

@export var menu: VBoxContainer
@export var main_settings: VBoxContainer
@export var language_settings: VBoxContainer
@export var audio_settings: VBoxContainer
@export var video_settings: VBoxContainer
@export var back_button: Button

@export var video_button: Button
@export var audio_button: Button
@export var language_button: Button
@export var settings_button: Button

var nav_stack: Array[Control] = []
var current_panel

var spotlight_menu: SpotLight3D = null
var npc_knocking: Node3D = null

func _show_panel(panel: Control) -> void:
	panel.visible = true

func _update_back_button() -> void:
	back_button.visible = nav_stack.size() > 0

func _navigate_to(panel: Control) -> void:
	if current_panel:
		nav_stack.append(current_panel)
		current_panel.visible = false
	
	current_panel = panel
	_show_panel(panel)
	_update_back_button()

func _on_back_pressed() -> void:
	if nav_stack.is_empty():
		return
	
	current_panel.visible = false
	current_panel = nav_stack.pop_back()
	_show_panel(current_panel)
	_update_back_button()

func _ready() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_menu_music()

	current_panel = menu
	_show_panel(menu)
	_update_back_button()
	video_button.pressed.connect(_navigate_to.bind(video_settings))
	audio_button.pressed.connect(_navigate_to.bind(audio_settings))
	language_button.pressed.connect(_navigate_to.bind(language_settings))
	settings_button.pressed.connect(_navigate_to.bind(main_settings))
	back_button.pressed.connect(_on_back_pressed)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Find spotlight and NPC nodes in the main menu scene
	spotlight_menu = find_child("SpotLightMenu", true, false)
	npc_knocking = find_child("npc_knocking", true, false)

	if spotlight_menu:
		spotlight_menu.visible = true
	if npc_knocking:
		npc_knocking.visible = false
		npc_knocking.process_mode = Node.PROCESS_MODE_DISABLED

	if spotlight_menu and npc_knocking:
		_start_flicker_loop()

# Hàm này sẽ được gọi khi bấm nút Start
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://worlds/sandbox.tscn")

# Hàm này sẽ được gọi khi bấm nút Quit
func _on_quit_pressed() -> void:
	get_tree().quit()

# Vòng lặp chớp tắt đèn spotlight và npc thoắt ẩn thoắt hiện
func _start_flicker_loop() -> void:
	if not spotlight_menu or not npc_knocking:
		return
		
	while is_inside_tree():
		# Giảm thời gian chờ giữa các lần chập tắt đèn (từ 6-12s xuống còn 3-7s)
		var wait_time = randf_range(3.0, 7.0)
		await get_tree().create_timer(wait_time).timeout
		if not is_inside_tree():
			break
			
		if randf() < 0.9:
			# Giảm tỷ lệ xuất hiện NPC khi đèn chập tắt xuống còn 35% để tăng sự bất ngờ
			var show_npc = randf() < 0.35
			
			var states = [
				{"light": false, "npc": false},
				{"light": true, "npc": show_npc},
				{"light": false, "npc": false},
				{"light": true, "npc": false},
				{"light": false, "npc": false},
				{"light": true, "npc": false}
			]
			
			if randf() < 0.4:
				states = [
					{"light": false, "npc": false},
					{"light": true, "npc": show_npc},
					{"light": false, "npc": false},
					{"light": true, "npc": show_npc},
					{"light": false, "npc": false},
					{"light": true, "npc": false}
				]
			
			if show_npc and is_instance_valid(npc_knocking):
				npc_knocking.process_mode = Node.PROCESS_MODE_INHERIT
				
			for state in states:
				if not is_instance_valid(spotlight_menu) or not is_instance_valid(npc_knocking):
					return
				
				spotlight_menu.visible = state["light"]
				npc_knocking.visible = state["npc"]
				
				var delay = randf_range(0.08, 0.22)
				await get_tree().create_timer(delay).timeout
				if not is_inside_tree():
					return
					
			if is_instance_valid(spotlight_menu):
				spotlight_menu.visible = true
			if is_instance_valid(npc_knocking):
				npc_knocking.visible = false
				npc_knocking.process_mode = Node.PROCESS_MODE_DISABLED
