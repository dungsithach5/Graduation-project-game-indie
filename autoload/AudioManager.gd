extends Node

var outdoor_player: AudioStreamPlayer
var indoor_player: AudioStreamPlayer
var menu_player: AudioStreamPlayer

var is_inside_shop: bool = false
var fade_duration: float = 1.5
var is_active: bool = false

func _ready() -> void:
	# Keep playing even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create outdoor player for night ambience (SFX bus)
	outdoor_player = AudioStreamPlayer.new()
	outdoor_player.bus = &"SFX"
	add_child(outdoor_player)

	# Create indoor player for shop music (Music bus)
	indoor_player = AudioStreamPlayer.new()
	indoor_player.bus = &"Music"
	add_child(indoor_player)

	# Create menu player for main menu music (Music bus)
	menu_player = AudioStreamPlayer.new()
	menu_player.bus = &"Music"
	add_child(menu_player)

func play_game_sounds() -> void:
	if is_active:
		return
	is_active = true
	is_inside_shop = false

	# Stop menu music if playing
	if is_instance_valid(menu_player) and menu_player.playing:
		menu_player.stop()

	# Load streams dynamically (looping is handled directly by .import settings)
	if not outdoor_player.stream:
		outdoor_player.stream = load("res://sounds/crickets.mp3")
	if not indoor_player.stream:
		indoor_player.stream = load("res://sounds/audio_room.mp3")

	# Initial volumes: outdoor starts full, indoor is muted
	outdoor_player.volume_db = -6.0
	indoor_player.volume_db = -80.0

	outdoor_player.play()
	indoor_player.play()
	print("AudioManager: Game sounds started playing.")

func stop_game_sounds() -> void:
	if not is_active:
		return
	is_active = false
	
	# Smoothly fade out both players
	var tween = create_tween().set_parallel(true)
	tween.tween_property(outdoor_player, "volume_db", -80.0, 1.0)
	tween.tween_property(indoor_player, "volume_db", -80.0, 1.0)
	await tween.finished
	
	# Only stop if it hasn't been reactivated
	if not is_active:
		outdoor_player.stop()
		indoor_player.stop()
		print("AudioManager: Game sounds stopped.")


func play_menu_music() -> void:
	if not is_instance_valid(menu_player):
		return
	
	# Stop game sounds
	stop_game_sounds()
	
	if not menu_player.stream:
		var stream = load("res://sounds/sound-backgroud-main-menu.mp3")
		if stream:
			if "loop" in stream:
				stream.loop = true
			menu_player.stream = stream
			
	if not menu_player.playing:
		menu_player.volume_db = 0.0
		menu_player.play()
		print("AudioManager: Menu music started playing.")


func set_location(inside: bool) -> void:
	if not is_active:
		return
	if is_inside_shop == inside:
		return
	is_inside_shop = inside
	if is_inside_shop:
		fade_to_indoors(fade_duration)
	else:
		fade_to_outdoors(fade_duration)

func fade_to_indoors(duration: float) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(indoor_player, "volume_db", -6.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Keeping outdoor ambience slightly audible (-30dB) for immersive atmosphere inside the store
	tween.tween_property(outdoor_player, "volume_db", -30.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	print("AudioManager: Transitioning to indoor music.")

func fade_to_outdoors(duration: float) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(outdoor_player, "volume_db", -6.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(indoor_player, "volume_db", -80.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	print("AudioManager: Transitioning to outdoor ambience.")

