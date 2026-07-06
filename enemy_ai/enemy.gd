extends CharacterBody3D


@onready var nav = $NavigationAgent3D
var speed = 1.5
var gravity = 9.8

func _ready():
	add_to_group("enemy")

func _process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y -= 2
		
	var next_location = nav.get_next_path_position()
	var current_location = global_transform.origin
	var new_velocity = (next_location - current_location).normalized() * speed
	
	velocity = velocity.move_toward(new_velocity, 0.25)
	move_and_slide()
	
	# Rotate to face the player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var target_pos = player.global_position
		target_pos.y = global_position.y
		if global_position.distance_to(target_pos) > 0.1:
			look_at(target_pos, Vector3.UP)
			rotate_y(PI)

func target_position(target):
	nav.target_position = target
