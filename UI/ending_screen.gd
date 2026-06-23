extends CanvasLayer

var fade_rect: ColorRect
var title_label: Label
var try_again_button: Button

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Black fade overlay
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	
	# Center container for text + button
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)
	
	# Ending title label
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.modulate = Color(1, 1, 1, 0)
	vbox.add_child(title_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)
	
	# Try Again button (hidden by default)
	try_again_button = Button.new()
	try_again_button.text = "Try Again"
	try_again_button.visible = false
	try_again_button.custom_minimum_size = Vector2(220, 55)
	try_again_button.add_theme_font_size_override("font_size", 24)
	try_again_button.pressed.connect(_on_try_again)
	vbox.add_child(try_again_button)

func show_ending(title: String, show_try_again: bool = false, auto_return: bool = true) -> void:
	title_label.text = title
	
	# Fade to black
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 2.0)
	await tween.finished
	
	# Show title with fade in
	var title_tween = create_tween()
	title_tween.tween_property(title_label, "modulate:a", 1.0, 1.5)
	await title_tween.finished
	
	if show_try_again:
		try_again_button.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif auto_return:
		await get_tree().create_timer(3.0).timeout
		_go_to_main_menu()

func show_jumpscare_death() -> void:
	title_label.text = "You are dead"
	
	# Quick fade to black for jumpscare
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
	await tween.finished
	
	# Show death text
	var title_tween = create_tween()
	title_tween.tween_property(title_label, "modulate:a", 1.0, 0.5)
	await title_tween.finished
	
	try_again_button.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_try_again() -> void:
	# Reset Director state to replay Night 4
	Director.current_night_index = 3
	Director.current_event_index = 0
	Director.shift_active = false
	Director.waiting_for_delay = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://worlds/sandbox.tscn")

func _go_to_main_menu() -> void:
	Director.current_night_index = 0
	Director.current_event_index = 0
	Director.shift_active = false
	Director.waiting_for_delay = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://menu/main_menu.tscn")
