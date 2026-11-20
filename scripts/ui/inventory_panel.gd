class_name InventoryPanel
extends CanvasLayer
## Tabla de lo que juntaste en la partida (pedido del grupo, 2026-11-20): objetos, reliquias y
## mejoras de un jugador. Se abre con Tab (teclado) o Back / Select (joystick) y pausa a todos.
## Con el stick o la cruceta (o WASD) se mueve un seleccionador y abajo se lee qué hace lo
## elegido; con el mouse, alcanza con pasar por arriba. Se cierra con Tab / Back, B / Esc o Start.

signal closed

const COLUMNS := 10
const ICON_SIZE := 50.0
const BG := Color(0.07, 0.07, 0.09, 0.96)
const SECTIONS: Array[String] = ["Objetos", "Reliquias", "Mejoras"]

var slot: PlayerSlot
## Por sección: las entradas (RunInventory) y sus íconos.
var _entries: Array = [[], [], []]
var _icons: Array = [[], [], []]
var _section: int = 0
var _index: int = 0
var _detail_title: Label
var _detail_tag: Label
var _detail_text: Label
var _wait: float = 0.15


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 45


func open(owner_slot: PlayerSlot) -> void:
	slot = owner_slot
	slot.input.consume_all()
	_entries = [RunInventory.items(slot.index), RunInventory.relics(slot.index),
			RunInventory.upgrades(slot.index)]
	_build()
	_section = 0
	while _section < SECTIONS.size() - 1 and _entries[_section].is_empty():
		_section += 1
	_index = 0
	_refresh()
	Sound.play("ui_confirm", -8.0, 0.0)


func close() -> void:
	slot.input.consume_all()
	closed.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or slot == null:
		return
	var input: PlayerInput = slot.input
	if input.just_pressed(PlayerInput.Action.INVENTORY) or input.just_pressed(PlayerInput.Action.BACK) \
			or input.just_pressed(PlayerInput.Action.PAUSE):
		close()
		return
	if input.just_pressed(PlayerInput.Action.LEFT):
		_move_horizontal(-1)
	elif input.just_pressed(PlayerInput.Action.RIGHT):
		_move_horizontal(1)
	elif input.just_pressed(PlayerInput.Action.UP):
		_move_vertical(-1)
	elif input.just_pressed(PlayerInput.Action.DOWN):
		_move_vertical(1)


# --- Seleccionador ---

## Izquierda / derecha: al anterior o al siguiente, pasando de una sección a otra.
func _move_horizontal(step: int) -> void:
	var flat: Array[Vector2i] = _flat_positions()
	if flat.is_empty():
		return
	var at: int = maxi(flat.find(Vector2i(_section, _index)), 0)
	var next: Vector2i = flat[wrapi(at + step, 0, flat.size())]
	_select(next.x, next.y)


## Arriba / abajo: una fila; si se va de la sección, a la misma columna de la sección vecina.
func _move_vertical(step: int) -> void:
	var count: int = _entries[_section].size()
	var target: int = _index + step * COLUMNS
	if target >= 0 and target < count:
		_select(_section, target)
		return
	var column: int = _index % COLUMNS
	var section: int = _section
	for i: int in SECTIONS.size():
		section = wrapi(section + step, 0, SECTIONS.size())
		var size: int = _entries[section].size()
		if size == 0:
			continue
		var rows: int = ceili(size / float(COLUMNS))
		var row: int = 0 if step > 0 else rows - 1
		_select(section, mini(row * COLUMNS + column, size - 1))
		return


func _flat_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for section: int in SECTIONS.size():
		for i: int in _entries[section].size():
			result.append(Vector2i(section, i))
	return result


func _select(section: int, index: int) -> void:
	if section == _section and index == _index:
		return
	_section = section
	_index = index
	Sound.play("ui_move", -8.0, 0.0)
	_refresh()


func _refresh() -> void:
	for section: int in SECTIONS.size():
		for i: int in _icons[section].size():
			(_icons[section][i] as ItemIcon).selected = section == _section and i == _index
	if _entries[_section].is_empty():
		_detail_title.text = "Todavía no juntaste nada"
		_detail_title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		_detail_tag.text = ""
		_detail_text.text = "Elegí objetos en las salas, comprale reliquias a Yole y subí de nivel tus habilidades."
		return
	var entry: Dictionary = _entries[_section][_index]
	_detail_title.text = entry["title"]
	_detail_title.add_theme_color_override("font_color", entry["color"])
	_detail_tag.text = entry["tag"]
	_detail_text.text = entry["description"]


# --- Armado ---

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = slot.color
	style.set_border_width_all(3)
	style.border_width_top = 6
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(COLUMNS * (ICON_SIZE + 6) + 36, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var character: String = slot.character.display_name if slot.character != null else ""
	box.add_child(_label("%s · %s — Lo que juntaste" % [slot.label, character], 28, slot.color.lightened(0.3)))
	box.add_child(_label("Oro: %d" % RunState.get_gold(slot.index), 18, Color(1.0, 0.82, 0.3)))
	for section: int in SECTIONS.size():
		box.add_child(_section_node(section))

	var detail := PanelContainer.new()
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.12, 0.12, 0.15)
	detail_style.set_corner_radius_all(8)
	detail_style.set_content_margin_all(12)
	detail.add_theme_stylebox_override("panel", detail_style)
	detail.custom_minimum_size = Vector2(0, 120)
	box.add_child(detail)
	var detail_box := VBoxContainer.new()
	detail.add_child(detail_box)
	_detail_title = _label("", 24, Color.WHITE)
	_detail_tag = _label("", 16, Color(0.65, 0.65, 0.72))
	_detail_text = _label("", 19, Color(0.9, 0.9, 0.94))
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label: Label in [_detail_title, _detail_tag, _detail_text]:
		detail_box.add_child(label)
	var hint: String = "Tab: cerrar · pasá el mouse por arriba para leer" if slot.is_keyboard \
			else "Stick o cruceta: elegir · Back o B: cerrar"
	box.add_child(_label(hint, 15, Color(0.6, 0.6, 0.66)))


func _section_node(section: int) -> Control:
	var box := VBoxContainer.new()
	var entries: Array = _entries[section]
	box.add_child(_label("%s (%d)" % [SECTIONS[section], entries.size()] if not entries.is_empty()
			else "%s: ninguno" % SECTIONS[section], 17, Color(0.7, 0.7, 0.78)))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for i: int in entries.size():
		var icon: ItemIcon = RunInventory.icon_for(entries[i])
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.tooltip_text = ""  # el detalle va abajo
		icon.mouse_entered.connect(_select.bind(section, i))
		grid.add_child(icon)
		_icons[section].append(icon)
	return box


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
