extends Node3D

@export var move_speed: float = 1.0
@export var walk_duration: float = 3.0
@export var idle_duration: float = 2.0

var is_walking: bool = true
var timer: float = 0.0

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	timer += delta
	
	if is_walking:
		%PathFollow3D.progress += move_speed * delta
		
		if timer >= walk_duration:
			is_walking = false
			timer = 0.0
	else:
		if timer >= idle_duration:
			is_walking = true
			timer = 0.0
