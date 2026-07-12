extends Node3D

var player_in_range: bool = false
var player_ref: Node3D = null
var is_scanned: bool = false
var owner_npc: Node3D = null

func setup_item(npc: Node3D) -> void:
	owner_npc = npc

func _process(_delta: float) -> void:
	_update_scan_prompt()

	if is_scanned:
		return
		
	if player_in_range and player_ref:
		if Input.is_action_just_pressed("primary"):
			if player_ref.interaction_controller.current_object != null:
				_scan_item()

func _scan_item() -> void:
	is_scanned = true
	print("Item scanned!")
	
	if owner_npc and owner_npc.has_method("all_items_scanned"):
		owner_npc.all_items_scanned()
		
	var root_node = self
	if get_parent() != get_tree().current_scene:
		root_node = get_parent()
	root_node.queue_free()

func _update_scan_prompt() -> void:
	if not player_ref or not player_ref.interaction_controller:
		return

	if is_scanned or not player_in_range:
		_clear_scan_prompt()
		return

	if _is_holding_scanner(player_ref):
		_show_scan_prompt()
	else:
		_clear_scan_prompt()

func _show_scan_prompt() -> void:
	if player_ref and player_ref.interaction_controller:
		player_ref.interaction_controller.forced_label_text = "Click to scan"

func _clear_scan_prompt() -> void:
	if player_ref and player_ref.interaction_controller:
		if player_ref.interaction_controller.forced_label_text == "Click to scan":
			player_ref.interaction_controller.forced_label_text = ""

func _is_holding_scanner(player: Node) -> bool:
	if not player or not player.interaction_controller:
		return false

	var held_object = player.interaction_controller.current_object
	if held_object == null:
		return false

	var obj_name = held_object.name.to_lower()
	var parent_name = ""
	if held_object.get_parent():
		parent_name = held_object.get_parent().name.to_lower()

	return "scanner" in obj_name or "scanner" in parent_name

func _on_body_entered(body: Node3D) -> void:
	if body is Player or body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		_update_scan_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body is Player or body.is_in_group("player"):
		_clear_scan_prompt()
		player_in_range = false
		player_ref = null
