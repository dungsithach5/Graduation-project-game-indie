extends Node

@onready var interaction_controller: Node = %InteractionController
@onready var interaction_raycast: RayCast3D = %InteractionRaycast
@onready var player_camera: Camera3D = %Camera3D
@onready var hand: Marker3D = %Hand

var current_object: Object
var last_potential_object: Object
var interaction_component: Node

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#If on the previous frame, we were interacting with and object, lets keep interacting with it
	if current_object:
		if Input.is_action_just_pressed("secondry"):
			if interaction_component:
				interaction_component.auxInteract()
				current_object = null
		if Input.is_action_pressed("primary"):
			if interaction_component:
				interaction_component.interact()
		else:
			if interaction_component:
				interaction_component.postInteract()
				current_object = null
	else: # we were interacting with something, lets see if we can
		var potential_object: Object = interaction_raycast.get_collider()
		
		if potential_object and potential_object is Node:
			interaction_component = potential_object.get_node_or_null("InteractionComponent")
			if interaction_component:
				if interaction_component.can_interact == false:
					return
				
				last_potential_object = current_object

				if Input.is_action_pressed("primary"):
					current_object = potential_object
					interaction_component.preInteract(hand)
