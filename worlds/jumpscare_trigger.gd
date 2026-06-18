extends Area3D

@export var npc_crying: Node3D
@export var npc2: Node3D
@export var dialogue_timeline: String = "dialogic_jumpscare"

var active: bool = false
var triggered: bool = false
var waiting_for_turn_around: bool = false

func _ready() -> void:
	# Connect body_entered signal
	body_entered.connect(_on_body_entered)
	
	# Make sure NPC2 is hidden initially
	if npc2:
		npc2.visible = false
		npc2.process_mode = Node.PROCESS_MODE_DISABLED

func _process(_delta: float) -> void:
	# Only work if active, not yet triggered
	if not active or triggered:
		return
		
	# Verify current task is CLEAN_FLOOR (event type 3)
	if Director.get_current_event_type() != 3:
		return
		
	if waiting_for_turn_around:
		var player = get_tree().get_first_node_in_group("player")
		if player and npc2:
			# Check if player is facing away from NPC2
			var dir_to_npc = (npc2.global_position - player.global_position)
			dir_to_npc.y = 0
			dir_to_npc = dir_to_npc.normalized()
			
			var player_facing = - player.global_transform.basis.z
			player_facing.y = 0
			player_facing = player_facing.normalized()
			
			var dot = player_facing.dot(dir_to_npc)
			
			# If dot < -0.5, player has turned their back (angle > 120 degrees away)
			if dot < -0.5:
				_trigger_jumpscare(player)

func _on_body_entered(body: Node3D) -> void:
	if triggered:
		return
	if body.is_in_group("player"):
		# Verify current task is CLEAN_FLOOR (event type 3)
		if Director.get_current_event_type() == 3:
			active = true
			waiting_for_turn_around = true
			
			# 1. npc_crying disappears
			if npc_crying:
				npc_crying.queue_free()
				
			# 2. NPC2 becomes visible and enabled
			if npc2:
				npc2.visible = true
				npc2.process_mode = Node.PROCESS_MODE_INHERIT

func _trigger_jumpscare(player: Player) -> void:
	triggered = true
	waiting_for_turn_around = false
	
	# 3. Snap player's camera to focus directly on NPC2
	var dir_to_npc = (npc2.global_position - player.global_position)
	var flat_dist = Vector2(dir_to_npc.x, dir_to_npc.z).length()
	
	# Calculate target yaw (Y rotation) for player body
	var target_yaw = atan2(-dir_to_npc.x, -dir_to_npc.z)
	player.global_rotation.y = target_yaw
	
	# Calculate target pitch (X rotation) for player head
	var target_pitch = atan2(dir_to_npc.y, flat_dist)
	player.head.rotation.x = clamp(target_pitch, deg_to_rad(-85), deg_to_rad(85))
	player.head.rotation.y = 0
	player.head.rotation.z = 0
	
	# 4. Open dialogue
	Dialogic.start(dialogue_timeline)
	
	# 5. When dialogue ends, NPC2 disappears
	Dialogic.timeline_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

func _on_dialogue_ended() -> void:
	if npc2:
		# Hide and free NPC2
		npc2.queue_free()
	# Free this trigger area as it's a one-time event
	queue_free()
