extends Node

@onready var interaction_controller: Node = %InteractionController
@onready var interaction_raycast: RayCast3D = %InteractionRaycast
@onready var player_camera: Camera3D = %Camera3D
@onready var hand: Marker3D = %Hand

var current_object: Object
var last_potential_object: Object
var interaction_component: Node
var interact_label: Label = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if interact_label == null:
		interact_label = get_tree().get_first_node_in_group("interact_label")
		if interact_label:
			interact_label.hide()
			
	var show_label = false

	#If on the previous frame, we were interacting with and object, lets keep interacting with it
	if current_object:
		if Input.is_action_just_pressed("secondry"):
			if interaction_component:
				interaction_component.postInteract()
				interaction_component.auxInteract()
				current_object = null
		else:
			var drop_object = false
			if interaction_component:
				if interaction_component.interaction_type == interaction_component.InteractionType.DEFAULT:
					if Input.is_action_just_pressed("interact"):
						drop_object = true
				elif interaction_component.interaction_type == interaction_component.InteractionType.DOOR:
					drop_object = true
				else:
					if not Input.is_action_pressed("interact"):
						drop_object = true
			
			if drop_object:
				if interaction_component:
					interaction_component.postInteract()
				current_object = null
			else:
				if interaction_component:
					interaction_component.interact()
	else: # we were interacting with something, lets see if we can
		var potential_object: Object = interaction_raycast.get_collider()
		
		if potential_object and potential_object is Node:
			interaction_component = potential_object.get_node_or_null("InteractionComponent")
			if interaction_component:
				if interaction_component.can_interact == false:
					if interact_label:
						interact_label.visible = false
					return
				
				show_label = true

				last_potential_object = current_object

				var pick_up = false
				if interaction_component.interaction_type == interaction_component.InteractionType.DEFAULT or interaction_component.interaction_type == interaction_component.InteractionType.DOOR:
					if Input.is_action_just_pressed("interact"):
						pick_up = true
				else:
					if Input.is_action_pressed("interact"):
						pick_up = true

				if pick_up:
					current_object = potential_object

					if interaction_component.interaction_type == interaction_component.InteractionType.DOOR:
						interaction_component.set_direction(current_object.to_local(interaction_raycast.get_collision_point()))

					interaction_component.preInteract(hand)

	if interact_label:
		interact_label.visible = show_label

func isCameraLocked() -> bool:
	if interaction_component:
		if interaction_component.lock_camera and interaction_component.is_interacting:
			return true
	return false
