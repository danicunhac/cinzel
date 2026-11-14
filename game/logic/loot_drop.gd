class_name LootDrop
extends RefCounted
## One stack of loot rolled by LootTable.

var id: StringName
var qty: int


func _init(item_id: StringName = &"", amount: int = 1) -> void:
	id = item_id
	qty = amount
