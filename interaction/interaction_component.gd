extends Node

enum InteractionType {
	DEFAULT
}

@export var object_ref: Node3D
@export var interaction_type: InteractionType = InteractionType.DEFAULT

var can_interact: bool = true
var is_interacting: bool = false

var player_hand: Marker3D

# run once, when the player FISRT clicks on an object is interact with
func preInteract(hand: Marker3D) -> void:
	is_interacting = true
	match interaction_type:
		InteractionType.DEFAULT:
			player_hand = hand

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
	# is_interacting = false
	return

func _input(event: InputEvent) -> void:
	pass

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
