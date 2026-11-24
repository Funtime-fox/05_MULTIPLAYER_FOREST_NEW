extends CanvasLayer

@export var grid: GridContainer

func _ready():
	if grid == null:
		push_error(
			"Inventory: назначь GridContainer в поле Grid."
		)
		return

	Global.inventory_updated.connect(refresh_ui)
	Global.update_selection_visual.connect(update_selection_visual)

	refresh_ui()


func refresh_ui():
	# Очистка старых слотов
	for child in grid.get_children(): child.queue_free()
	
	# Создание новых на основе данных из Global
	for item in Global.inventory:
		var slot = Button.new()
		slot.icon = item.icon
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.custom_minimum_size = Vector2(15,15)
		slot.text = str(item.amount)
		grid.add_child(slot)

func update_selection_visual():
	var slots = grid.get_children()
	for i in range(slots.size()):
		if i == Global.active_slot_index:
			slots[i].grab_focus()
		else:
			slots[i].release_focus()

func _create_slot(item: ItemData) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(64, 88)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Тёмный фон и светлая рамка.
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#080b12")
	style.border_color = Color("#fff1b8")
	style.set_border_width_all(3)

	slot.add_theme_stylebox_override("panel", style)

	# Иконка располагается под числом.
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	slot.add_child(icon)

	icon.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# Отступы иконки от рамки.
	icon.offset_left = 8
	icon.offset_top = 8
	icon.offset_right = -8
	icon.offset_bottom = -8

	# Количество поверх иконки, как на примере.
	var amount_label := Label.new()
	amount_label.text = str(item.amount)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	amount_label.add_theme_font_size_override(
		"font_size", 42
	)
	amount_label.add_theme_color_override(
		"font_color", Color("#eeeeee")
	)
	amount_label.add_theme_color_override(
		"font_outline_color", Color("#161616")
	)
	amount_label.add_theme_constant_override(
		"outline_size", 2
	)

	slot.add_child(amount_label)

	amount_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	return slot
