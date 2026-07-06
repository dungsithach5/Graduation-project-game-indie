extends CharacterBody3D

class_name Player

@onready var head: Node3D = $Head
@onready var eyes: Node3D = $Head/Eyes
@onready var camera_3d: Camera3D = $Head/Eyes/Camera3D
@onready var standing_collision_shape: CollisionShape3D = $StandingCollisionShape
@onready var crouching_collision_shape: CollisionShape3D = $CrouchingCollisionShape
@onready var interaction_controller: Node = $InteractionController
@onready var standup_check: RayCast3D = $StandupCheck

# Movement Variables
const walking_speed: float = 1.8
const sprinting_speed: float = 3.2
const crouching_speed: float = 0.8
const crouching_depth: float = -0.9
const jump_velocity: float = 4.0
var current_speed: float = 1.8
const SPEED = 5.0
var moving: bool = false
var input_dir: Vector2 = Vector2.ZERO
var direction: Vector3 = Vector3.ZERO
var lerp_speed: float = 10.0
var mouse_input: Vector2
var is_in_air: bool = false
var footstep_player: AudioStreamPlayer
var step_played: bool = false

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
const head_bobbing_sprinting_speed: float = 13.0
const head_bobbing_walking_speed: float = 8.5
const head_bobbing_crouching_speed: float = 6.0
const head_bobbing_sprinting_intensity: float = 0.15
const head_bobbing_walking_intensity: float = 0.08
const head_bobbing_crouching_intensity: float = 0.04
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

var dialogic_active: bool = false
var movement_locked: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Dialogic.timeline_started.connect(func():
		dialogic_active = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	)
	Dialogic.timeline_ended.connect(func():
		dialogic_active = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	)
	
	# Initialize footstep audio player
	footstep_player = AudioStreamPlayer.new()
	footstep_player.stream = preload("res://sounds/footstep.mp3")
	footstep_player.bus = &"SFX"
	add_child(footstep_player)

func _input(event: InputEvent) -> void:
	if get_tree().paused or dialogic_active or movement_locked:
		return
	if event is InputEventMouseMotion:
		if not interaction_controller.isCameraLocked():
			rotation.y -= deg_to_rad(event.relative.x * mouse_sensitivty)
			head.rotation.x -= deg_to_rad(event.relative.y * mouse_sensitivty)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))


func _physics_process(delta: float) -> void:
	updatePLayerState()
	updateCamera(delta)
	
	if dialogic_active or movement_locked:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity += get_gravity() * delta
		else:
			velocity.y = -0.1
		move_and_slide()
		return

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
	if dialogic_active or movement_locked:
		moving = false
		player_state = PlayerState.IDLE_STAND
		updatePlayerColShape(player_state)
		updatePlayerSpeed(player_state)
		return

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
	head_bobbing_vector.x = 0.0
	if moving:
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)

	# Footstep sound trigger based on head bobbing cycle
	if moving and is_on_floor() and not (dialogic_active or movement_locked):
		if sin(head_bobbing_index) < 0:
			if not step_played:
				play_footstep()
				step_played = true
		else:
			step_played = false
	else:
		step_played = false
		if footstep_player and footstep_player.playing:
			footstep_player.stop()

func _process(delta) -> void:
	get_tree().call_group("enemy", "target_position", global_transform.origin)

func play_footstep() -> void:
	if not footstep_player:
		return
	
	var base_db: float = -4.0
	var pitch_min: float = 0.85
	var pitch_max: float = 1.15
	
	match player_state:
		PlayerState.SPRINTING:
			base_db = 0.0
			pitch_min = 0.95
			pitch_max = 1.25
		PlayerState.CROUCHING:
			base_db = -15.0
			pitch_min = 0.75
			pitch_max = 0.95
		PlayerState.WALKING:
			base_db = -4.0
			pitch_min = 0.85
			pitch_max = 1.15
			
	footstep_player.pitch_scale = randf_range(pitch_min, pitch_max)
	footstep_player.volume_db = base_db + randf_range(-1.5, 1.5)
	footstep_player.play()
