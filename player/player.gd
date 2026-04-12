extends CharacterBody3D
@onready var head: Node3D = $Head
@onready var eyes: Node3D = $Head/Eyes
@onready var camera_3d: Camera3D = $Head/Eyes/Camera3D
@onready var standing_collision_shape: CollisionShape3D = $StandingCollisionShape
@onready var crouching_collision_shape: CollisionShape3D = $CrouchingCollisionShape
@onready var interaction_controller: Node = $InteractionController
@onready var standup_check: RayCast3D = $StandupCheck

# Movement Variables
const walking_speed: float = 3.0
const sprinting_speed: float = 5.0
const crouching_speed: float = 1.0
const crouching_depth: float = -0.9
const jump_velocity: float = 4.0
var current_speed: float = 3.0
const SPEED = 5.0
var moving: bool = false
var input_dir: Vector2 = Vector2.ZERO
var direction: Vector3 = Vector3.ZERO
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

# Headbobbing Vars
const head_bobbing_sprinting_speed: float = 22.0
const head_bobbing_walking_speed: float = 14.0
const head_bobbing_crouching_speed: float = 10.0
const head_bobbing_sprinting_intensity: float = 0.2
const head_bobbing_walking_intensity: float = 0.1
const head_bobbing_crouching_intensity: float = 0.05
var head_bobbing_current_intensity: float = 0.0
var head_bobbing_vector: Vector2 = Vector2.ZERO
var head_bobbing_index: float = 0.0
var last_bob_position_x: float = 0.0 # Tracks the previous horizontal head-bob position
var last_bob_direction: int = 0 # Tracks the previous movement direction of the bob (-1 = left, +1 = right)

var mouse_sensitivty: float = 0.2

# Player Settings
var base_fov: float = 90.0
var normal_sensitivity: float = 0.2
var current_sensitivity: float = normal_sensitivity
var sensitivity_restore_speed: float = 5.0 # tweak for smoothness
var sensitivity_fading_in: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseMotion:
		rotation.y -= deg_to_rad(event.relative.x * mouse_sensitivty)
		head.rotation.x -= deg_to_rad(event.relative.y * mouse_sensitivty)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))


func _physics_process(delta: float) -> void:
	updatePLayerState()
	updateCamera(delta)
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Get the input direction and handle the movement/deceleration.
	input_dir = Input.get_vector("left", "right", "forward", "back")
	direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

func updatePLayerState() -> void:
	moving = (input_dir != Vector2.ZERO)
	if not is_on_floor():
		player_state = PlayerState.AIR
	else:
		if Input.is_action_pressed("crouch"):
			if not moving:
				player_state = PlayerState.IDLE_CROUCH
			else:
				player_state = PlayerState.CROUCHING
		elif !standup_check.is_colliding():
			if not moving:
				player_state = PlayerState.IDLE_STAND
			elif Input.is_action_pressed("sprint"):
				player_state = PlayerState.SPRINTING
			else:
				player_state = PlayerState.WALKING

	updatePlayerColShape(player_state)
	updatePlayerSpeed(player_state)

func updatePlayerColShape(_player_state: PlayerState) -> void:
	if _player_state == PlayerState.CROUCHING or _player_state == PlayerState.IDLE_CROUCH:
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
	else:
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
	
func updatePlayerSpeed(_player_state: PlayerState) -> void:
	if _player_state == PlayerState.CROUCHING or _player_state == PlayerState.IDLE_CROUCH:
		current_speed = crouching_speed
	elif _player_state == PlayerState.WALKING:
		current_speed = walking_speed
	elif _player_state == PlayerState.SPRINTING:
		current_speed = sprinting_speed
	else:
		current_speed = walking_speed

func updateCamera(delta: float) -> void:
	if player_state == PlayerState.AIR:
		pass
	
	if player_state == PlayerState.CROUCHING or player_state == PlayerState.IDLE_CROUCH:
		head.position.y = lerp(head.position.y, 1.8 + crouching_depth, delta * lerp_speed)
		camera_3d.fov = lerp(camera_3d.fov, base_fov * 0.95, delta * lerp_speed)
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		if moving:
			head_bobbing_index += head_bobbing_crouching_speed * delta
	elif player_state == PlayerState.IDLE_STAND:
		head.position.y = lerp(head.position.y, 1.8, delta * lerp_speed)
		camera_3d.fov = lerp(camera_3d.fov, base_fov, delta * lerp_speed)
		head_bobbing_current_intensity = head_bobbing_walking_intensity
	elif player_state == PlayerState.WALKING:
		head.position.y = lerp(head.position.y, 1.8, delta * lerp_speed)
		camera_3d.fov = lerp(camera_3d.fov, base_fov, delta * lerp_speed)
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		if moving:
			head_bobbing_index += head_bobbing_walking_speed * delta
	elif player_state == PlayerState.SPRINTING:
		head.position.y = lerp(head.position.y, 1.8, delta * lerp_speed)
		camera_3d.fov = lerp(camera_3d.fov, base_fov * 1.05, delta * lerp_speed)
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		if moving:
			head_bobbing_index += head_bobbing_sprinting_speed * delta
	
	head_bobbing_vector.y = sin(head_bobbing_index)
	head_bobbing_vector.x = (sin(head_bobbing_index / 2.0))
	if moving:
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * (head_bobbing_current_intensity), delta * lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)