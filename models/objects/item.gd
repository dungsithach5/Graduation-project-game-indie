extends Node3D

var player_in_range: bool = false
var player_ref: Node3D = null
var is_scanned: bool = false
var owner_npc: Node3D = null

func setup_item(npc: Node3D) -> void:
	owner_npc = npc

func _process(_delta: float) -> void:
	if is_scanned:
		return
		
	if player_in_range and player_ref:
		if Input.is_action_just_pressed("primary"):
			if player_ref.interaction_controller.current_object != null:
				_scan_item()

func _scan_item() -> void:
	is_scanned = true
	print("Item scanned!")
	if Director.shift_active:
		var current_night = Director.nights[Director.current_night_index]
		if Director.current_event_index < current_night.events.size():
			var current_event = current_night.events[Director.current_event_index]
			if current_event != null and current_event.type == 2: # 2 là CUSTOMER_SHOPPING
				TaskManager.update_task()
	
	if owner_npc and owner_npc.has_method("all_items_scanned"):
		owner_npc.all_items_scanned()
		
	var root_node = self
	if get_parent() != get_tree().current_scene:
		root_node = get_parent()
	root_node.queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body is Player or body.is_in_group("player"):
		player_in_range = true
		player_ref = body

func _on_body_exited(body: Node3D) -> void:
	if body is Player or body.is_in_group("player"):
		player_in_range = false
		player_ref = null
