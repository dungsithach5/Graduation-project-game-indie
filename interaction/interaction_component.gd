extends Node

enum InteractionType {
	DEFAULT,
	DOOR,
	SWITCH,
	WHEEL
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

var player_hand: Marker3D
var camera: Camera3D

func _ready():
	match interaction_type:
		InteractionType.DOOR:
			starting_rotation = pivot_point.rotation.x
			maximum_rotation = deg_to_rad(rad_to_deg(starting_rotation) + maximum_rotation)
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
		InteractionType.DOOR:
			lock_camera = true

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

func _input(event: InputEvent) -> void:
	if is_interacting:
		match interaction_type:
			InteractionType.DOOR:
				if event is InputEventMouseMotion:
					if is_front:
						pivot_point.rotate_y(-event.relative.y * .001)
					else:
						pivot_point.rotate_y(event.relative.y * .001)

				pivot_point.rotation.y = clamp(pivot_point.rotation.y, starting_rotation, maximum_rotation)

func _default_interact() -> void:
	var object_current_position: Vector3 = object_ref.global_transform.origin
	var player_hand_position: Vector3 = player_hand.global_transform.origin
	var object_distance: Vector3 = player_hand_position - object_current_position

	var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D
	if rigid_body_3d:
		rigid_body_3d.set_linear_velocity((object_distance) * (5 / rigid_body_3d.mass))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _default_throw() -> void:
	var object_current_position: Vector3 = object_ref.global_transform.origin
	var player_hand_position: Vector3 = player_hand.global_transform.origin
	var object_distance: Vector3 = player_hand_position - object_current_position
	
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
