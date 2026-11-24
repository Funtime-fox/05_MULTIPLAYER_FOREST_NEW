extends CanvasLayer

# Надпись со счётчиком грибов.
@export var label: Label

# Надпись с именем игрока.
@export var label_name: Label

var item_count: int = 0


func _ready() -> void:
	update_player_name()
	update_item_count()

	# Подписываемся на сбор предметов.
	# Проверка защищает от повторного подключения.
	if not Global.item_collected.is_connected(_on_item_collected):
		Global.item_collected.connect(_on_item_collected)


func update_player_name() -> void:
	if not is_instance_valid(label_name):
		push_warning(
			"Интерфейс: назначь Label Name в инспекторе."
		)
		return

	var player_name: String = "Игрок"
	var saved_name: Variant = Global.name_player

	# Не передаём null в свойство text.
	if typeof(saved_name) == TYPE_STRING:
		var entered_name: String = str(saved_name).strip_edges()

		if not entered_name.is_empty():
			player_name = entered_name

	label_name.text = player_name


func update_item_count() -> void:
	if not is_instance_valid(label):
		push_warning(
			"Интерфейс: назначь Label со счётчиком в инспекторе."
		)
		return

	label.text = str(item_count)


func _on_item_collected(item_name: String) -> void:
	if item_name != "mushrooms":
		return

	item_count += 1
	update_item_count()
