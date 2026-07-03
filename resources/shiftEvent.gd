extends Resource
class_name shiftEvent

enum EventType {
	TALK_TO_NPC,
	RESTOCK_SHELVES,
	CUSTOMER_SHOPPING,
	CLEAN_FLOOR,
	MONSTER_INTERACTION,
	GO_HOME,
	EXTINGUISH_FIRE,
	TURN_ON_POWER,
	PLACE_TALISMAN,
	RETURN_BROOM,
	RETURN_EXTINGUISHER
}
@export var type: EventType = EventType.RESTOCK_SHELVES
@export var delay: float = 0.0
@export var task_count_required: int = 1
@export var description: String = ""
