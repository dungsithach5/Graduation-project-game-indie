extends Resource
class_name shiftEvent

enum EventType {
	RESTOCK_SHELVES,
	CUSTOMER_SHOPPING,
	MONSTER_INTERACTION
}
@export var type: EventType = EventType.RESTOCK_SHELVES
@export var delay: float = 0.0
@export var task_count_required: int = 1
@export var description: String = ""
