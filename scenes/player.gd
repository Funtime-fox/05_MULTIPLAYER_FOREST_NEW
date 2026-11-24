extends CharacterBody2D

var speed = 40
@export var anim: AnimatedSprite2D
@export var hand: Sprite2D
@export var item_resources: ItemData
@export var item_world_scene: PackedScene
@export var camera: Camera2D        # >>> MULTIPLAYER: назначь в инспекторе
@export var name_label: Label      # >>> MULTIPLAYER: назначь $NameLabel
const DEFAULT_SPAWN_POSITION := Vector2(100, 50)
var equipped_tool: ItemData
var is_sitting = false

# >>> MULTIPLAYER: сигнал для HUD (счётчик грибов)
signal item_collected(item_name: String)

func _debug_camera() -> void:
	var current_camera := get_viewport().get_camera_2d()

	print("Текущая камера: ", current_camera.get_path())
	print("Позиция игрока: ", global_position)
	print("Позиция камеры: ", camera.global_position)
	print("Zoom: ", camera.zoom)
	print("Центр экрана: ", current_camera.get_screen_center_position())
	call_deferred("_print_final_position")
func _ready() -> void:
	print(
		"Игрок: ", name,
		" | ID этого приложения: ", multiplayer.get_unique_id(),
		" | Владелец: ", get_multiplayer_authority(),
		" | Мой персонаж: ", is_multiplayer_authority()
	)
	
	var is_local := is_multiplayer_authority()

	if is_local and global_position == Vector2.ZERO:
		global_position = DEFAULT_SPAWN_POSITION

	camera.enabled = is_local

	if is_local:
		camera.make_current()
	
	# Камера включена только у локального игрока.
	if camera != null:
		camera.enabled = is_multiplayer_authority()
		print(
			"КАМЕРА | Игрок: ", name,
			" | Мой ID: ", multiplayer.get_unique_id(),
			" | Enabled: ", camera.enabled,
			" | Путь: ", camera.get_path()
		)
		if is_multiplayer_authority():
			camera.enabled = true
			camera.make_current()
			call_deferred("_debug_camera")
		else:
			camera.enabled = false
	# Чужой персонаж не должен менять локальный инвентарь и HUD.
	if not is_multiplayer_authority():
		return

	if item_resources != null and Global.inventory.is_empty():
		Global.add_item(item_resources)

	# Отправляем ник после завершения текущего этапа создания узлов.
	call_deferred("_send_nickname")

	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("bind_player"):
		hud.bind_player(self)

func _print_final_position() -> void:
	print(
		"Финальная позиция игрока: ",
		name,
		" | ",
		global_position,
		" | Локальный: ",
		is_multiplayer_authority()
	)


func _physics_process(_delta):
	# >>> MULTIPLAYER: чужими телами не управляем
	if not is_multiplayer_authority():
		return

	var input = Vector2(
		Input.get_action_strength('ui_right') - Input.get_action_strength('ui_left'),
		Input.get_action_strength('ui_down') - Input.get_action_strength('ui_up')
	)

	velocity = input.normalized() * speed

	if is_sitting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if input.x > 0:
		anim.flip_h = false
	elif input.x < 0:
		anim.flip_h = true
	elif input.y < 0:
		anim.flip_v = false

	if input != Vector2.ZERO:
		anim.play('walk')
	else:
		anim.play('idle')

	move_and_slide()

func _send_nickname() -> void:
	if not is_multiplayer_authority():
		return

	setup_nickname.rpc(Global.name_player)

func _unhandled_input(event: InputEvent) -> void:
	# >>> MULTIPLAYER: ввод обрабатываем только для своего тела
	if not is_multiplayer_authority():
		return

	if event.is_action_pressed('use_tool'):
		if Global.inventory.size() > 0:
			var item = Global.inventory[0]
			if item.is_tool:
				if hand.texture == null:
					hand.texture = item.icon
				else:
					hand.texture = null

	if event.is_action_pressed('interact'):
		if is_sitting:
			is_sitting = false
			anim.play('idle')
		else:
			is_sitting = true
			anim.play('sit')

	if event.is_action_pressed('next_item'):
		change_selection(1)
	if event.is_action_pressed('prev_item'):
		change_selection(-1)
	if event.is_action_pressed('drop_item'):
		drop_item()


# >>> MULTIPLAYER: RPC для ника
@rpc("any_peer", "call_local", "reliable")
func setup_nickname(nick: String) -> void:
	if name_label:
		name_label.text = nick
	else:
		var l = get_node_or_null("NameLabel")
		if l:
			l.text = nick

# >>> MULTIPLAYER: RPC для счётчика грибов
@rpc("any_peer", "call_local")
func collect_item(item_name: String) -> void:
	item_collected.emit(item_name)


func change_selection(direction: int):
	if Global.inventory.size() == 0: return
	Global.active_slot_index = (Global.active_slot_index + direction) % Global.inventory.size()
	if Global.active_slot_index < 0: Global.active_slot_index = Global.inventory.size() - 1
	Global.update_selection_visual.emit()
	update_hand_visual()


func update_hand_visual() -> void:
	if Global.inventory.is_empty():
		Global.active_slot_index = 0
		hand.texture = null
		equipped_tool = null
		return

	Global.active_slot_index = clampi(Global.active_slot_index, 0, Global.inventory.size() - 1)
	var item: ItemData = Global.inventory[Global.active_slot_index]

	if item == null:
		hand.texture = null
		equipped_tool = null
		return

	hand.texture = item.icon
	equipped_tool = item if item.is_tool else null


func drop_item():
	if Global.inventory.size() > 0:
		var item_to_drop = Global.inventory[Global.active_slot_index]
		Global.inventory.remove_at(Global.active_slot_index)
		spawn_dropped_item(item_to_drop)
		Global.active_slot_index = clamp(Global.active_slot_index, 0, Global.inventory.size() - 1)
		Global.inventory_updated.emit()
		update_hand_visual()


func spawn_dropped_item(item_to_drop: ItemData):
	# >>> MULTIPLAYER: спавн только на сервере, через MultiplayerSpawner
	if not multiplayer.is_server():
		return
	var new_item = item_world_scene.instantiate()
	new_item.item_resources = item_to_drop
	var random_offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	new_item.position = self.position + random_offset
	get_tree().current_scene.add_child(new_item)

func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())
