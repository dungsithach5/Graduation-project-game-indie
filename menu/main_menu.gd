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
	current_panel = menu
	_show_panel(menu)
	_update_back_button()
	video_button.pressed.connect(_navigate_to.bind(video_settings))
	audio_button.pressed.connect(_navigate_to.bind(audio_settings))
	language_button.pressed.connect(_navigate_to.bind(language_settings))
	settings_button.pressed.connect(_navigate_to.bind(main_settings))
	back_button.pressed.connect(_on_back_pressed)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Hàm này sẽ được gọi khi bấm nút Start
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://worlds/sandbox.tscn")

# Hàm này sẽ được gọi khi bấm nút Quit
func _on_quit_pressed() -> void:
	get_tree().quit()
