extends CharacterBody3D

#CONSTAINS
const SPEED = 1.0

#STATES
enum State {
	IDLE,
	WAITING_TO_MOVE,
	MOVE,
	FINISHED,
	WAITING_AT_TABLE
}
var state: State = State.IDLE

#WAYPOINTS
@export var waypoints: Array[Node3D]
@export var loop_path: bool = false
@export var table_waypoint_index: int = 1
@export var item_to_spawn: PackedScene
@export var table_spawn_point: Node3D
var current_waypoint_index: int = 0

#TIMER
var idle_wait_time: float = 1.5 # wait time
var idle_timer_count: float = 0 # internal countdown  timer

#NODE_REFERENCES
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var animation_tree: AnimationTree = $Walking/AnimationTree


func _ready() -> void:
	if animation_tree:
		animation_tree.active = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = -0.1 # Small downward force to stay grounded without building up gravity

	match state:
		State.IDLE:
			_on_idle()
		State.WAITING_TO_MOVE:
			_on_waiting_to_move(delta)
		State.MOVE:
			_on_move(delta)
		State.WAITING_AT_TABLE:
			velocity.x = 0
			velocity.z = 0
		State.FINISHED:
			velocity.x = 0
			velocity.z = 0

	move_and_slide()
	_update_animations()

func _update_animations() -> void:
	if animation_tree:
		var is_moving = velocity.length() > 0.1 and state == State.MOVE
		animation_tree.set("parameters/conditions/is_walking", is_moving)
		animation_tree.set("parameters/conditions/is_idle", not is_moving)

func _on_idle() -> void:
	velocity.x = 0
	velocity.z = 0
	idle_timer_count = idle_wait_time
	state = State.WAITING_TO_MOVE

func _on_waiting_to_move(delta) -> void:
	idle_timer_count -= delta

	# done waiting pick new target
	if idle_timer_count <= 0.0:
		if current_waypoint_index >= waypoints.size():
			if loop_path:
				current_waypoint_index = 0
			else:
				state = State.FINISHED
				return
				
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
			
		return target_pos
		
	return global_transform.origin

func _on_navigation_agent_3d_target_reached() -> void:
	# current_waypoint_index is already incremented in get_new_target_location,
	# so the target we just reached is current_waypoint_index - 1
	if (current_waypoint_index - 1) == table_waypoint_index:
		state = State.WAITING_AT_TABLE
		spawn_item_on_table()
	else:
		state = State.IDLE

func spawn_item_on_table() -> void:
	if item_to_spawn and table_spawn_point:
		var item = item_to_spawn.instantiate()
		get_tree().current_scene.add_child(item)
		item.global_transform.origin = table_spawn_point.global_transform.origin
		
		# Try to call setup_item on the item or its children
		if item.has_method("setup_item"):
			item.setup_item(self )
		else:
			for child in item.get_children():
				if child.has_method("setup_item"):
					child.setup_item(self )

func all_items_scanned() -> void:
	state = State.IDLE
