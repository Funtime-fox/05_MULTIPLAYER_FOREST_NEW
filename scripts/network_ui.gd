extends CanvasLayer

const PORT: int = 7000

@export var player_scene: PackedScene

var peer: ENetMultiplayerPeer

@onready var name_input: LineEdit = $Menu/NameInput
@onready var ip_input: LineEdit = $Menu/IPInput
@onready var host_btn: Button = $Menu/HostBtn
@onready var join_btn: Button = $Menu/JoinBtn


func _ready() -> void:
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

	multiplayer.connected_to_server.connect(
		_on_connected_to_server
	)
	multiplayer.connection_failed.connect(
		_on_connection_failed
	)
	multiplayer.server_disconnected.connect(
		_on_server_disconnected
	)

	# Подключаем кнопки, если они ещё не подключены в редакторе.
	if not host_btn.pressed.is_connected(_on_host_btn_pressed):
		host_btn.pressed.connect(_on_host_btn_pressed)

	if not join_btn.pressed.is_connected(_on_join_btn_pressed):
		join_btn.pressed.connect(_on_join_btn_pressed)


func _save_name() -> void:
	Global.name_player = name_input.text.strip_edges()

	if Global.name_player.is_empty():
		Global.name_player = "Игрок"


func _set_buttons_disabled(value: bool) -> void:
	host_btn.disabled = value
	join_btn.disabled = value


func _on_host_btn_pressed() -> void:
	if player_scene == null:
		push_error("Назначь Player Scene в инспекторе NetworkUI.")
		return

	_save_name()
	_set_buttons_disabled(true)

	peer = ENetMultiplayerPeer.new()

	var error := peer.create_server(PORT)

	if error != OK:
		push_error("Не удалось создать сервер: " + error_string(error))
		_reset_connection()
		_set_buttons_disabled(false)
		return

	multiplayer.multiplayer_peer = peer

	# ID сервера всегда 1.
	add_player(1)
	register_player(Global.name_player)
	hide()
	print("Сервер запущен. Порт: ", PORT)


func _on_join_btn_pressed() -> void:
	_save_name()

	var ip := ip_input.text.strip_edges()

	if ip.is_empty():
		ip = "127.0.0.1"

	_set_buttons_disabled(true)

	peer = ENetMultiplayerPeer.new()

	var error := peer.create_client(ip, PORT)

	if error != OK:
		push_error("Не удалось начать подключение: " + error_string(error))
		_reset_connection()
		_set_buttons_disabled(false)
		return

	multiplayer.multiplayer_peer = peer

	# Меню скроется после успешного подключения.


func _on_connected_to_server() -> void:
	register_player.rpc_id(1, Global.name_player)
	hide()
	print("Подключено. Мой ID: ", multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	_reset_connection()
	_set_buttons_disabled(false)
	show()

	push_warning("Не удалось подключиться. Проверь IP и запуск хоста.")


func _on_server_disconnected() -> void:
	_reset_connection()
	get_tree().call_deferred("reload_current_scene")


func _reset_connection() -> void:
	if peer != null:
		peer.close()

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null

const SPAWN_POSITION := Vector2(100, 50)


func add_player(id: int) -> void:
	if not multiplayer.is_server():
		return

	if get_parent().has_node(str(id)):
		return

	var player := player_scene.instantiate()

	# Имя нужно установить до добавления игрока в дерево.
	player.name = str(id)

	# Устанавливаем позицию до add_child.
	player.position = SPAWN_POSITION

	# Владелец этого персонажа — соответствующий клиент.
	player.set_multiplayer_authority(id)

	get_parent().add_child(player)

	print(
		"Создан игрок: ",
		id,
		" | Позиция: ",
		player.position,
		" | Авторитет: ",
		player.get_multiplayer_authority()
	)

func remove_player(id: int) -> void:
	if not multiplayer.is_server():
		return
	if Global.players.has(id):
		Global.players.erase(id)
		update_all_players.rpc(Global.players)
	# Игроки находятся в World, а не внутри NetworkUI.
	var player := get_parent().get_node_or_null(str(id))

	if player != null:
		player.queue_free()

# Вызывается клиентом на сервере для отправки своего имени
@rpc("any_peer", "call_local", "reliable")
func register_player(nick_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id = multiplayer.get_remote_sender_id()
	Global.players[id] = nick_name
	# Сервер рассылает обновленный список всем клиентам
	update_all_players.rpc(Global.players)

# Сервер отправляет полный список игроков всем
@rpc("authority", "call_local", "reliable")
func update_all_players(players_dict: Dictionary) -> void:
	Global.players = players_dict
	Global.players_updated.emit()
