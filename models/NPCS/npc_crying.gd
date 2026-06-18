extends Node3D

var is_triggered: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_npc_active(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# 3 là EventType.CLEAN_FLOOR
	if Director.get_current_event_type() != 3:
		if is_triggered or visible:
			is_triggered = false
			set_npc_active(false)
		return
	
	if not is_triggered:
		# Kiểm tra xem người chơi có đang cầm chổi (broom) hay không
		var player = get_tree().get_first_node_in_group("player")
		if player and player.interaction_controller and player.interaction_controller.current_object:
			var current_obj = player.interaction_controller.current_object
			var obj_name = current_obj.name.to_lower()
			var parent_name = ""
			if current_obj.get_parent():
				parent_name = current_obj.get_parent().name.to_lower()
			
			if "broom" in obj_name or "broom" in parent_name:
				is_triggered = true
				set_npc_active(true)

func set_npc_active(active: bool) -> void:
	visible = active
	var crying_female = get_node_or_null("Crying_female")
	if crying_female:
		crying_female.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	
	var anim = get_node_or_null("Crying_female/AnimationPlayer")
	var audio = get_node_or_null("AudioStreamPlayer3D")
	
	if active:
		if anim:
			anim.play("mixamo_com")
		if audio and not audio.playing:
			audio.play()
	else:
		if anim:
			anim.stop()
		if audio:
			audio.stop()
