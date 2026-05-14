extends Node

enum InteractionType {
	DEFAULT,
	DOOR,
	SWITCH,
	WHEEL,
	NPC,
	BROOM
}

@export var object_ref: Node3D
@export var interaction_type: InteractionType = InteractionType.DEFAULT
@export var maximum_rotation: float = 90
@export var pivot_point: Node3D

var can_interact: bool = true
var is_interacting: bool = false
var lock_camera: bool = false
var starting_rotation: float
var is_front: bool
var is_open: bool = false
var door_tween: Tween

var player_hand: Marker3D
var camera: Camera3D

func _ready():
	if object_ref == null:
		object_ref = get_parent()
		
	match interaction_type:
		InteractionType.DOOR:
			starting_rotation = pivot_point.rotation.y
		InteractionType.SWITCH:
			starting_rotation = object_ref.rotation.z
			maximum_rotation = deg_to_rad(rad_to_deg(starting_rotation) + maximum_rotation)
		InteractionType.WHEEL:
			starting_rotation = object_ref.rotation.z
			maximum_rotation = deg_to_rad(rad_to_deg(starting_rotation) + maximum_rotation)
			camera = get_tree().get_current_scene().find_child("Camera3D", true, false)
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
			is_open = !is_open
			if door_tween and door_tween.is_running():
				door_tween.kill()
			door_tween = create_tween()
			
			var target_rotation = starting_rotation
			if is_open:
				if is_front:
					target_rotation = starting_rotation - deg_to_rad(maximum_rotation)
				else:
					target_rotation = starting_rotation + deg_to_rad(maximum_rotation)
			
			door_tween.set_ease(Tween.EASE_OUT)
			door_tween.set_trans(Tween.TRANS_SINE)
			door_tween.tween_property(pivot_point, "rotation:y", target_rotation, 0.5)
		InteractionType.NPC:
			Dialogic.start("timeline")
			
			# Kiểm tra xem Task hiện tại có phải là "Talk To Npc" không (Type = 0)
			if Director.shift_active:
				var current_night = Director.nights[Director.current_night_index]
				if Director.current_event_index < current_night.events.size():
					var current_event = current_night.events[Director.current_event_index]
					if current_event.type == 0: # 0 là TALK_TO_NPC
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
		rigid_body_3d.global_transform = player_hand.global_transform

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

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
