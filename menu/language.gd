extends VBoxContainer

@export var language_option: OptionButton

var languages = {
	"English": "en",
	"Tiếng Việt": "vi",
	"Japanese": "ja"
}

func _on_language_option_item_selected(index: int) -> void:
	var lang_name := language_option.get_item_text(index)
	var locale = languages[lang_name]
	TranslationServer.set_locale(locale)
	print("Locale set to:", locale)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for lang_name in languages.keys():
		language_option.add_item(lang_name)
	
	var current_locale := TranslationServer.get_locale()
	for i in range(language_option.item_count):
		var lang_name := language_option.get_item_text(i)
		if current_locale.begins_with(languages[lang_name]):
			language_option.select(i)
			break

	language_option.item_selected.connect(_on_language_option_item_selected)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
