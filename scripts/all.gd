extends Node2D

@export var item_name: String = "mushrooms"

var collected: bool = false

@onready var pickup_area: Area2D = $Area2D


func _ready() -> void:
	# Не подключаем сигнал повторно, если он уже
	# подключён к этому обработчику в редакторе.
	if not pickup_area.body_entered.is_connected(
		_on_area_2d_body_entered
	):
		pickup_area.body_entered.connect(
			_on_area_2d_body_entered
		)


func _on_area_2d_body_entered(body: Node2D) -> void:
	# Только сервер решает, можно ли собрать предмет.
	if not multiplayer.is_server():
		return

	# Защита от одновременного сбора двумя игроками.
	if collected:
		return

	# По заданию имя игрока — его сетевой ID.
	if not str(body.name).is_valid_int():
		return

	var player_id := str(body.name).to_int()

	if player_id <= 0:
		return

	collected = true

	# Удаляем предмет у всех и уведомляем собравшего игрока.
	_collect.rpc(player_id)


@rpc("authority", "call_local", "reliable")
func _collect(player_id: int) -> void:
	collected = true

	# Локальный счётчик меняется только у того,
	# кто подобрал предмет.
	if multiplayer.get_unique_id() == player_id:
		Global.item_collected.emit(item_name)

	queue_free()
