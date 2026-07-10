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
@export var dialogic_timeline: String = "dialogic_customer_1"
var current_waypoint_index: int = 0

#TIMER
var idle_wait_time: float = 1.5 # wait time
var idle_timer_count: float = 0 # internal countdown  timer

#NODE_REFERENCES
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var animation_tree: AnimationTree = $Walking/AnimationTree

# Bone look at tracking variables
var head_bone_idx: int = -1
var neck_bone_idx: int = -1
var skeleton: Skeleton3D = null
var look_at_weight: float = 0.0


func _ready() -> void:
	if animation_tree:
		animation_tree.active = true
	_randomize_appearance()
	
	skeleton = get_node_or_null("Walking/Skeleton3D")
	if skeleton:
		head_bone_idx = skeleton.find_bone("mixamorig_Head")
		neck_bone_idx = skeleton.find_bone("mixamorig_Neck")

	# --- Self-healing fallback for waypoints ---
	if waypoints.is_empty():
		var parent = get_parent()
		if parent:
			var point_container = parent.get_node_or_null("pointContainer")
			if point_container:
				var points = point_container.get_children()
				# Sort points by name (point1, point2... or 0, 1, 2...)
				points.sort_custom(func(a, b): return a.name < b.name)
				for p in points:
					if p is Node3D:
						waypoints.append(p)
				print("NPC Customer (Self-Healing): Resolved ", waypoints.size(), " waypoints from ", parent.name)
				
				# Set table_waypoint_index based on parent node
				if parent.name == "NPC_movement":
					table_waypoint_index = 2
				else:
					table_waypoint_index = 1

	# --- Self-healing fallback for table_spawn_point ---
	if not table_spawn_point:
		table_spawn_point = get_node_or_null("../../Marker3D")
		if table_spawn_point:
			print("NPC Customer (Self-Healing): Resolved table_spawn_point to '../../Marker3D'")

	# --- Self-healing fallback for item_to_spawn ---
	if not item_to_spawn:
		item_to_spawn = load("res://models/objects/item.tscn")
		print("NPC Customer (Self-Healing): Loaded default item_to_spawn")


func _process(delta: float) -> void:
	_update_head_look_at(delta)


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
			queue_free()

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
			item.setup_item(self)
		else:
			for child in item.get_children():
				if child.has_method("setup_item"):
					child.setup_item(self)
		
		# Set up the talk interaction instead of triggering the dialogic timeline automatically
		_setup_talk_interaction()

func _setup_talk_interaction() -> void:
	var interaction_comp_scene = load("res://interaction/interaction_component.tscn")
	if interaction_comp_scene:
		var comp = interaction_comp_scene.instantiate()
		comp.interaction_type = 4 # NPC
		comp.dialogue_timeline = dialogic_timeline
		comp.name = "InteractionComponent"
		add_child(comp)
		comp.object_ref = self
		
		# Lắng nghe sự kiện bắt đầu thoại để dọn dẹp
		if not Dialogic.timeline_started.is_connected(_on_dialogue_started):
			Dialogic.timeline_started.connect(_on_dialogue_started)

func _on_dialogue_started() -> void:
	var comp = get_node_or_null("InteractionComponent")
	if comp and comp.is_interacting:
		if Dialogic.timeline_started.is_connected(_on_dialogue_started):
			Dialogic.timeline_started.disconnect(_on_dialogue_started)
		comp.can_interact = false

func all_items_scanned() -> void:
	state = State.IDLE

func _randomize_appearance() -> void:
	var mesh_instance = get_node_or_null("Walking/Skeleton3D/Character_01")
	if not mesh_instance:
		return

	var characters = [
		# Male civilians
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_01.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_01.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_02.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_02.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_03.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_03.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_04.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_04.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_05.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_05.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_06.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_06.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_07.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_07.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_08.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_08.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_09.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_09.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_10.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_10.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_11.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_11.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_12.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_12.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_13.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_13.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_14.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_14.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_15.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_15.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_16.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_16.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_29.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_29.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_30.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_30.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_31.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_31.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Male/Character_32.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_32.png"
		},

		# Female civilians
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_01.fbx",
			"tex": "res://assets/Characters_psx/Models/textures/Character_Female_01.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_02.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_02.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_03.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_03.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_04.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_04.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_05.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_05.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_06.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_06.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_07.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_07.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_08.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_08.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_09.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_09.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_10.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_10.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_11.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_11.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_12.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_12.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_13.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_13.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_14.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_14.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_15.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_15.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_Female_16.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_Female_16.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_29_Female.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_29_Female.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_30_Female.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_30_Female.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_31_Female.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_31_Female.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_32_Female.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_32_Female.png"
		},
		{
			"mesh": "res://assets/Characters_psx/Models/Female/Character_33_Female.fbx",
			"tex": "res://assets/Characters_psx/Textures/Character_33_Female.png"
		}
	]

	randomize()
	var choice = characters[randi() % characters.size()]
	
	# Load the FBX scene
	var fbx_scene = load(choice["mesh"])
	if not fbx_scene:
		return
		
	var fbx_instance = fbx_scene.instantiate()
	if not fbx_instance:
		return
		
	var other_mi = _find_mesh_instance(fbx_instance)
	if other_mi and other_mi.mesh:
		# Assign mesh and skin from the imported fbx
		mesh_instance.mesh = other_mi.mesh
		if other_mi.skin:
			mesh_instance.skin = other_mi.skin
			
		# Load and set the texture on the PSX shader material
		var tex = load(choice["tex"])
		if tex:
			var mat = mesh_instance.get_surface_override_material(0)
			if mat == null:
				mat = mesh_instance.material_override
				
			if mat:
				var unique_mat = mat.duplicate()
				mesh_instance.set_surface_override_material(0, unique_mat)
				if mesh_instance.material_override:
					mesh_instance.material_override = unique_mat
				
				if unique_mat is ShaderMaterial:
					unique_mat.set_shader_parameter("albedo", tex)
				elif unique_mat is StandardMaterial3D:
					unique_mat.albedo_texture = tex
					
	# Clean up the temporary instantiated instance
	fbx_instance.queue_free()

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null

func _update_head_look_at(delta: float) -> void:
	if not skeleton or head_bone_idx == -1:
		return
		
	var player = get_tree().get_first_node_in_group("player")
	var is_close = false
	var player_pos = Vector3.ZERO
	
	if player:
		player_pos = player.global_transform.origin + Vector3(0, 1.5, 0) # look at player's eyes
		var dist = global_transform.origin.distance_to(player.global_transform.origin)
		if dist < 4.5: # 4.5 meters trigger range
			is_close = true
			
	if is_close:
		look_at_weight = move_toward(look_at_weight, 1.0, delta * 3.0) # smooth fade in
	else:
		look_at_weight = move_toward(look_at_weight, 0.0, delta * 3.0) # smooth fade out
		
	if look_at_weight <= 0.0:
		return
		
	# Calculate look at rotation in skeleton space
	var bone_global_pose = skeleton.get_bone_global_pose(head_bone_idx)
	var bone_global_transform = skeleton.global_transform * bone_global_pose
	
	if bone_global_transform.origin.distance_to(player_pos) > 0.1:
		# Limit the look angle to prevent 360-degree head rotation (exorcist style)
		var npc_forward = -global_transform.basis.z
		var dir_to_player = (player_pos - bone_global_transform.origin).normalized()
		var angle = npc_forward.angle_to(dir_to_player)
		
		# Only look at player if they are within 80 degrees of the NPC's forward view
		if angle < deg_to_rad(80.0):
			var target_global_transform = bone_global_transform.looking_at(player_pos, Vector3.UP)
			
			var parent_bone_idx = skeleton.get_bone_parent(head_bone_idx)
			if parent_bone_idx != -1:
				var parent_global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(parent_bone_idx)
				var target_local_transform = parent_global_transform.inverse() * target_global_transform
				var target_local_rot = target_local_transform.basis.get_rotation_quaternion()
				
				# Interpolate between animation pose and look_at pose
				var anim_rot = skeleton.get_bone_pose_rotation(head_bone_idx)
				var blended_rot = anim_rot.slerp(target_local_rot, look_at_weight)
				skeleton.set_bone_pose_rotation(head_bone_idx, blended_rot)
				
				# Rotate the neck slightly (35% of the weight) for a more natural look
				if neck_bone_idx != -1:
					var neck_parent_idx = skeleton.get_bone_parent(neck_bone_idx)
					if neck_parent_idx != -1:
						var neck_parent_global = skeleton.global_transform * skeleton.get_bone_global_pose(neck_parent_idx)
						var neck_global_pose = skeleton.get_bone_global_pose(neck_bone_idx)
						var neck_global_transform = skeleton.global_transform * neck_global_pose
						if neck_global_transform.origin.distance_to(player_pos) > 0.1:
							var neck_target_global = neck_global_transform.looking_at(player_pos, Vector3.UP)
							var neck_target_local = neck_parent_global.inverse() * neck_target_global
							var neck_target_rot = neck_target_local.basis.get_rotation_quaternion()
							
							var neck_anim_rot = skeleton.get_bone_pose_rotation(neck_bone_idx)
							var neck_blended = neck_anim_rot.slerp(neck_target_rot, look_at_weight * 0.35)
							skeleton.set_bone_pose_rotation(neck_bone_idx, neck_blended)
