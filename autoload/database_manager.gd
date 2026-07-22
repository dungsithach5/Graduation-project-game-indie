extends Node

# Database Manager - Handles Local JSON Database operations
const SETTINGS_FILE_PATH := "user://game_settings.json"
const SAVE_GAME_FILE_PATH := "user://save_game.json"

var nights_database: Dictionary = {}
var items_database: Array = []
var game_settings: Dictionary = {}

func _ready() -> void:
	print("DatabaseManager: Initializing Local JSON Database Systems...")
	load_all_databases()

func load_all_databases() -> void:
	load_nights_config_json()
	load_items_catalog_json()
	load_settings_json()

# --- 1. Nights & Events JSON Database ---
func load_nights_config_json() -> Dictionary:
	var path = "res://resources/nights_config.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var parsed = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				nights_database = parsed
				print("DatabaseManager: Successfully loaded nights_config.json database (", nights_database.get("nights", []).size(), " nights)")
				return nights_database
	print("DatabaseManager: Could not load nights_config.json")
	return {}

# --- 2. Items Catalog JSON Database ---
func load_items_catalog_json() -> Array:
	var path = "res://resources/items_catalog.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var parsed = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("items"):
				items_database = parsed["items"]
				print("DatabaseManager: Successfully loaded items_catalog.json database (", items_database.size(), " items)")
				return items_database
	return []

func get_item_by_id(item_id: String) -> Dictionary:
	for item in items_database:
		if item.get("id") == item_id:
			return item
	return {}

# --- 3. Settings JSON Database ---
func load_settings_json() -> Dictionary:
	var path = SETTINGS_FILE_PATH
	if not FileAccess.file_exists(path):
		path = "res://resources/game_settings.json"
		
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				game_settings = parsed
				print("DatabaseManager: Settings database loaded.")
				return game_settings
	return {}

func save_settings_json(new_settings: Dictionary) -> bool:
	game_settings = new_settings
	var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(game_settings, "\t"))
		print("DatabaseManager: Settings saved to ", SETTINGS_FILE_PATH)
		return true
	return false

# --- 4. Game Save State JSON Database ---
func save_player_progress(night_index: int, night_name: String) -> bool:
	var data = {
		"current_night_index": night_index,
		"night_name": night_name,
		"timestamp": Time.get_datetime_string_from_system(),
		"engine_version": "Godot 4"
	}
	var file = FileAccess.open(SAVE_GAME_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		print("DatabaseManager: Save game state written to JSON database at ", SAVE_GAME_FILE_PATH)
		return true
	return false

func load_player_progress() -> Dictionary:
	if FileAccess.file_exists(SAVE_GAME_FILE_PATH):
		var file = FileAccess.open(SAVE_GAME_FILE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				print("DatabaseManager: Save game state loaded from JSON database.")
				return parsed
	return {}
