extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_new_pressed() -> void:
	print("PauseMenu: New game.")
	Director.start_new_game()


func _on_save_pressed() -> void:
	if Director.save_game_by_night():
		print("PauseMenu: Game saved.")
	else:
		print("PauseMenu: Save failed.")
