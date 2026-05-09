extends CharacterBody3D

#CONSTAINS
const SPEED = 4.0

#STATES
enum State {
	IDLE,
	WAITING_TO_MOVE,
	MOVE
}
var state: State = State.IDLE

#WAYPOINTS
@export var waypoints: Array[Node3D]
var current_waypoint_index: int = 0

#TIMER
var idle_wait_time: float = 1.5 # wait time
var idle_timer_count: float = 0 # internal countdown  timer

#NODE_REFENCES
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D


func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta

	match state:
		State.IDLE:
			_on_idle()
		State.WAITING_TO_MOVE:
			_on_waiting_to_move(delta)
		State.MOVE:
			_on_move(delta)

	move_and_slide()

func _on_idle() -> void:
	velocity.x = 0
	velocity.z = 0
	idle_timer_count = idle_wait_time
	state = State.WAITING_TO_MOVE

func _on_waiting_to_move(delta) -> void:
	idle_timer_count -= delta

	# done waiting pick new target
	if idle_timer_count <= 0.0:
		var target = get_new_target_location()
		navigation_agent_3d.target_position = target
		state = State.MOVE

func _on_move(delta: float) -> void:
	var current_position = global_transform.origin
	var next_position = navigation_agent_3d.get_next_path_position()
	
	var direction = (next_position - current_position)
	direction.y = 0
	direction = direction.normalized()
	
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	
	# Xoay mặt/cơ thể về hướng di chuyển một cách mượt mà
	if direction != Vector3.ZERO:
		var target_y_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_y_rotation, delta * 10.0)

	
func get_new_target_location() -> Vector3:
	if waypoints.size() > 0:
		var target_node = waypoints[current_waypoint_index]
		var target_pos = target_node.global_transform.origin
		
		current_waypoint_index += 1
		if current_waypoint_index >= waypoints.size():
			current_waypoint_index = 0
			
		return target_pos
		
	return global_transform.origin

func _on_navigation_agent_3d_target_reached() -> void:
	state = State.IDLE
