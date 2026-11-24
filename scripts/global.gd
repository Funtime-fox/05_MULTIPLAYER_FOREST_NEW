extends Node
# Сигнал передает имя предмета 
signal item_collected(item_name: String)
signal update_selection_visual
var name_player: String = "Игрок"
var players: Dictionary = {}
signal players_updated

# Сигнал уведомления об обновлении инвентаря (удаляем старый сигнал)
signal inventory_updated
var inventory: Array[ItemData] = []
@export var max_inventory_size: int = 10
var amount: int

func add_item(item: ItemData):
	# 1. Проверяем, есть ли уже такой предмет в массиве инвентаря
	var index = inventory.find(item)
	
	if index != -1:
		# Если предмет найден, увеличиваем его количество внутри самого ресурса
		inventory[index].amount += 1
		inventory_updated.emit()
	else:
		# 2. Если предмета нет, проверяем, есть ли свободное место для нового слота
		if inventory.size() < max_inventory_size:
			# Убеждаемся, что у нового предмета количество хотя бы 1
			if item.amount == 0:
				item.amount = 1
			inventory.append(item)
			inventory_updated.emit()


var active_slot_index: int = 0

@rpc("authority", "call_local", "reliable")
func collect_item(player_id: int, item_name: String) -> void:
	# Счётчик увеличивается только у игрока,
	# который действительно собрал гриб.
	if multiplayer.get_unique_id() != player_id:
		return

	item_collected.emit(item_name)
	
