extends CanvasLayer

@onready var tab_menu: PanelContainer = $TabMenu
@onready var player_list: VBoxContainer = $TabMenu/VBoxContainer/PlayerList
@onready var chat_messages: RichTextLabel = $Chat/VBoxContainer/ChatMessages
@onready var chat_input: LineEdit = $Chat/VBoxContainer/ChatInput


func _ready() -> void:
	tab_menu.visible = false
	chat_input.visible = false # Поле ввода скрыто до нажатия кнопки
	chat_input.text_submitted.connect(_on_chat_input_submitted)
	Global.players_updated.connect(_update_player_list)


func _unhandled_input(event: InputEvent) -> void:
	# 01: Работа со списком игроков по зажатию Tab
	if event is InputEventKey and event.keycode == KEY_TAB:
		if event.is_pressed() and not event.is_echo():
			tab_menu.visible = true
			_update_player_list()
		elif not event.is_pressed():
			tab_menu.visible = false

	# 02: Открытие чата по нажатию клавиши "C"
	if event is InputEventKey and event.keycode == KEY_C and event.is_pressed() and not event.is_echo():
		if not chat_input.has_focus():
			_open_chat()
			get_viewport().set_input_as_handled() # Поглощаем ввод, чтобы буква "c" не напечаталась

	# Закрытие чата без отправки по клавише Escape
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.is_pressed() and not event.is_echo():
		if chat_input.has_focus():
			_close_chat()
			get_viewport().set_input_as_handled()


func _open_chat() -> void:
	chat_input.visible = true
	chat_input.grab_focus()
	chat_input.text = ""


func _close_chat() -> void:
	chat_input.text = ""
	chat_input.release_focus()
	chat_input.visible = false


# Обновление списка игроков внутри TabMenu
func _update_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()

	for id in Global.players:
		var lbl := Label.new()
		var player_name: String = str(Global.players[id])
		if id == multiplayer.get_unique_id():
			lbl.text = "• %s (Вы)" % player_name
		else:
			lbl.text = "• %s" % player_name
		player_list.add_child(lbl)


# Отправка сообщения по нажатию Enter
func _on_chat_input_submitted(new_text: String) -> void:
	var text_clean := new_text.strip_edges()
	_close_chat()

	if text_clean.is_empty():
		return

	var sender_name: String = Global.name_player
	send_message.rpc(sender_name, text_clean)


# RPC-метод приема сообщения всеми игроками
@rpc("any_peer", "call_local", "reliable")
func send_message(sender_name: String, message: String) -> void:
	chat_messages.append_text("[b]%s:[/b] %s\n" % [sender_name, message])
	print("Получено сообщение чата от: ", sender_name, " | Текст: ", message)
