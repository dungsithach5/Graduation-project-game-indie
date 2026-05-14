extends Resource
class_name shiftEvent

enum EventType {
	TALK_TO_NPC,
	RESTOCK_SHELVES,
	CUSTOMER_SHOPPING,
	CLEAN_FLOOR,
	MONSTER_INTERACTION
}
@export var type: EventType = EventType.RESTOCK_SHELVES
@export var delay: float = 0.0
@export var task_count_required: int = 1
@export var description: String = ""
