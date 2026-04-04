extends CharacterBody3D
@onready var head: Node3D = $Head
@onready var eyes: Node3D = $Head/Eyes
@onready var camera_3d: Camera3D = $Head/Eyes/Camera3D
@onready var standing_collision_shape: CollisionShape3D = $StandingCollisionShape
@onready var crouching_collision_shape: CollisionShape3D = $CrouchingCollisionShape
@onready var standup_check: RayCast3D = $StandupCheck

# Movement Variables
const walking_speed: float = 3.0
const sprinting_speed: float = 5.0
const crouching_speed: float = 1.0
const crouching_depth: float = -0.9
const jump_velocity: float = 4.0
const SPEED = 5.0
var moving: bool = false
# var input_dir: Vector2 = Vector2.ZERO
# var direction: Vector3 = Vector3.ZERO
var lerp_speed: float = 10.0
var mouse_input: Vector2
var is_in_air: bool = false

# State Machine
enum PlayerState {
	IDLE_STAND,
	IDLE_CROUCH,
	CROUCHING,
	WALKING,
	SPRINTING,
	AIR
	}
var player_state: PlayerState = PlayerState.IDLE_STAND

var mouse_sensitivty: float = 0.2


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivty))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivty))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))


func _physics_process(delta: float) -> void:
	# updatePLayerState()
	# updateCamera(delta)
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

# func updatePLayerState() -> void:
# 	moving = (input_dir != Vector2.ZERO)
# 	if not is_on_floor():
# 		player_state = PlayerState.AIR
# 	else:
# 		if Input.is_action_pressed("crouch"):
# 			if not moving:
# 				player_state = PlayerState.IDLE_CROUCH
# 			else:
# 				player_state = PlayerState.CROUCHING
# 		elif standup_check.is_colliding():
# 			if not moving:
# 				player_state = PlayerState.IDLE_STAND
# 			elif Input.is_action_pressed("sprint"):
# 				player_state = PlayerState.SPRINTING
# 			else:
# 				player_state = PlayerState.WALKING
