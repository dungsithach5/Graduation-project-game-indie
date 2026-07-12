extends Node

enum InteractionType {
	DEFAULT,
	DOOR,
	SWITCH,
	WHEEL,
	NPC,
	BROOM,
	GO_HOME,
	FUSE_BOX,
	NPC_THAYTU
}

@export var object_ref: Node3D
@export var interaction_type: InteractionType = InteractionType.DEFAULT
@export var maximum_rotation: float = 90
@export var pivot_point: Node3D
@export var dialogue_timeline: String = "timeline"

var can_interact: bool = true
var is_interacting: bool = false
var lock_camera: bool = false
var starting_rotation: float
var is_front: bool
var is_open: bool = false
var door_tween: Tween
var distance_check_timer: float = 0.0

var player_hand: Marker3D
var camera: Camera3D

func _ready():
	if object_ref == null:
		object_ref = get_parent()
		
	match interaction_type:
		InteractionType.DOOR:
			if pivot_point:
				starting_rotation = pivot_point.rotation.y
		InteractionType.SWITCH:
			starting_rotation = object_ref.rotation.z
			maximum_rotation = deg_to_rad(rad_to_deg(starting_rotation) + maximum_rotation)
		InteractionType.WHEEL:
			starting_rotation = object_ref.rotation.z
			maximum_rotation = deg_to_rad(rad_to_deg(starting_rotation) + maximum_rotation)
			camera = get_tree().get_current_scene().find_child("Camera3D", true, false)

func _check_npcs_distance(delta: float) -> void:
	distance_check_timer += delta
	if distance_check_timer < 0.1:
		return
	distance_check_timer = 0.0
	
	if not pivot_point:
		return
		
	var door_pos = pivot_point.global_transform.origin
	var npc_detected = false
	
	# Check distance for player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		var root = get_tree().current_scene
		if root:
			player = root.find_child("player", true, false)
			
	if player and is_instance_valid(player) and player is Node3D:
		var dist = door_pos.distance_to(player.global_transform.origin)
		if dist < 3.0:
			npc_detected = true
			
	# If player not detected close, check for NPCs
	if not npc_detected:
		var all_npcs = []
		all_npcs.append_array(get_tree().get_nodes_in_group("npc_customer_shopping"))
		for n in get_tree().get_nodes_in_group("npc"):
			if not n in all_npcs:
				all_npcs.append(n)
				
		if all_npcs.is_empty():
			var root = get_tree().current_scene
			if root:
				all_npcs = _find_all_npcs_recursive(root)
				
		for npc in all_npcs:
			if is_instance_valid(npc) and npc is Node3D:
				var dist = door_pos.distance_to(npc.global_transform.origin)
				if dist < 3.0:
					npc_detected = true
					break
				
	if npc_detected:
		if not is_open:
			set_door_open(true)
	else:
		if is_open and not is_interacting:
			set_door_open(false)

func _find_all_npcs_recursive(node: Node) -> Array:
	var result = []
	if is_instance_valid(node):
		if "npc" in node.name.to_lower() and node is Node3D and node != self and node != get_parent():
			result.append(node)
		for child in node.get_children():
			result.append_array(_find_all_npcs_recursive(child))
	return result

func _is_main_door() -> bool:
	if name.to_lower() == "door":
		return true
	if get_parent():
		if get_parent().name.to_lower() == "door":
			return true
		if get_parent().get_parent() and get_parent().get_parent().name.to_lower() == "door":
			return true
	return false

func _play_bell_sound() -> void:
	if _is_main_door():
		var bell_player = AudioStreamPlayer.new()
		bell_player.stream = load("res://sounds/conveniencestore-bell.mp3")
		bell_player.volume_db = 15.0 # Make it louder!
		get_tree().current_scene.add_child(bell_player)
		bell_player.play()
		bell_player.finished.connect(bell_player.queue_free)

func _is_door_locked() -> bool:
	var current_scene = get_tree().current_scene
	if current_scene:
		var ending_handler = current_scene.get_node_or_null("Night4EndingHandler")
		if ending_handler and ending_handler.get("blackout_triggered"):
			return true
	return false

func set_door_open(open: bool) -> void:
	if _is_door_locked() and _is_main_door():
		if is_open:
			is_open = false
			if door_tween and door_tween.is_running():
				door_tween.kill()
			door_tween = create_tween()
			door_tween.set_ease(Tween.EASE_OUT)
			door_tween.set_trans(Tween.TRANS_SINE)
			door_tween.tween_property(pivot_point, "rotation:y", starting_rotation, 0.5)
		return

	var was_open = is_open
	is_open = open
	if door_tween and door_tween.is_running():
		door_tween.kill()
	door_tween = create_tween()
	door_tween.set_ease(Tween.EASE_OUT)
	door_tween.set_trans(Tween.TRANS_SINE)
	
	var target_rotation = starting_rotation
	if is_open:
		if is_front:
			target_rotation = starting_rotation - deg_to_rad(maximum_rotation)
		else:
			target_rotation = starting_rotation + deg_to_rad(maximum_rotation)
			
		# Play bell sound when opening
		if not was_open:
			_play_bell_sound()
	
	door_tween.tween_property(pivot_point, "rotation:y", target_rotation, 0.5)

# run once, when the player FISRT clicks on an object is interact with
func preInteract(hand: Marker3D) -> void:
	is_interacting = true
	match interaction_type:
		InteractionType.DEFAULT:
			player_hand = hand
			var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D
			if rigid_body_3d:
				rigid_body_3d.freeze = true
				for child in rigid_body_3d.get_children():
					if child is CollisionShape3D:
						child.disabled = true
		InteractionType.DOOR:
			set_door_open(!is_open)
		InteractionType.NPC:
			Dialogic.start(dialogue_timeline)
			
			# Kiểm tra xem Task hiện tại có phải là "Talk To Npc" không (Type = 0)
			if Director.shift_active and Director.current_night_index < Director.nights.size():
				var current_night = Director.nights[Director.current_night_index]
				if Director.current_event_index < current_night.events.size():
					var current_event = current_night.events[Director.current_event_index]
					if current_event.type == 0: # 0 là TALK_TO_NPC
						TaskManager.update_task()
						var on_timeline_ended = func():
							var target = object_ref
							if is_instance_valid(target):
								if target.owner:
									target = target.owner
								elif target.get_parent() and target.get_parent() != get_tree().current_scene:
									target = target.get_parent()
								target.queue_free()
						Dialogic.timeline_ended.connect(on_timeline_ended, CONNECT_ONE_SHOT)
		InteractionType.NPC_THAYTU:
			Dialogic.start(dialogue_timeline)
			var on_timeline_ended = func():
				var target = object_ref
				if is_instance_valid(target):
					if target.owner:
						target = target.owner
					elif target.get_parent() and target.get_parent() != get_tree().current_scene:
						target = target.get_parent()
					target.queue_free()
			Dialogic.timeline_ended.connect(on_timeline_ended, CONNECT_ONE_SHOT)
		InteractionType.GO_HOME:
			if Director.shift_active and Director.current_night_index < Director.nights.size():
				var current_night = Director.nights[Director.current_night_index]
				if Director.current_event_index < current_night.events.size():
					var current_event = current_night.events[Director.current_event_index]
					if current_event.type == 5: # 5 là GO_HOME
						TaskManager.update_task()
		InteractionType.FUSE_BOX:
			if Director.shift_active and Director.current_night_index < Director.nights.size():
				var current_night = Director.nights[Director.current_night_index]
				if Director.current_event_index < current_night.events.size():
					var current_event = current_night.events[Director.current_event_index]
					if current_event.type == 7: # 7 là TURN_ON_POWER
						var lighting_mart = get_tree().get_current_scene().find_child("LightingMart", true, false)
						if lighting_mart:
							for child in lighting_mart.get_children():
								if child is Light3D:
									child.visible = true
						TaskManager.update_task()

# run every frame, perform some logic on this object
func interact() -> void:
	if not can_interact:
		return

	match interaction_type:
		InteractionType.DEFAULT:
			_default_interact()

func auxInteract() -> void:
	match interaction_type:
		InteractionType.DEFAULT:
			_default_throw()

# runs once, when the player LAST interacts with an object 
func postInteract() -> void:
	is_interacting = false
	lock_camera = false
	match interaction_type:
		InteractionType.DEFAULT:
			var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D
			if rigid_body_3d:
				rigid_body_3d.freeze = false
				for child in rigid_body_3d.get_children():
					if child is CollisionShape3D:
						child.disabled = false

func _input(event: InputEvent) -> void:
	pass

func _default_interact() -> void:
	var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D
	if rigid_body_3d:
		var original_scale = rigid_body_3d.scale
		rigid_body_3d.global_transform = player_hand.global_transform
		rigid_body_3d.scale = original_scale

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if interaction_type == InteractionType.DOOR and pivot_point:
		if _is_door_locked() and _is_main_door():
			can_interact = false
		_check_npcs_distance(delta)

func _default_throw() -> void:
	var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D
	if rigid_body_3d:
		var throw_direction: Vector3 = - player_hand.global_transform.basis.z.normalized()
		var throw_strength: float = (20.0 / rigid_body_3d.mass)
		rigid_body_3d.set_linear_velocity(throw_direction * throw_strength)

		can_interact = false
		await get_tree().create_timer(2.0).timeout
		can_interact = true

func set_direction(_normal: Vector3) -> void:
	if _normal.z == 0:
		is_front = true
	else:
		is_front = false
		is_front = false
