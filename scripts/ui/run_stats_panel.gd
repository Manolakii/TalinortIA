class_name RunStatsPanel
extends HBoxContainer
## Estadísticas de la partida (pedido del grupo): una columna por jugador con lo que hizo y lo
## que juntó. Los objetos van como íconos; el detalle se ve pasando el mouse por arriba.
## Arriba de cada columna, los premios en joda ("El que más pegó", "El más torpe"...).

const AWARDS: Dictionary = {
	&"damage": "El que más pegó",
	&"kills": "Exterminador",
	&"taken": "Esponja de golpes",
	&"downs": "El más torpe",
	&"gold": "Rata del oro",
}
const ICONS_PER_ROW := 8


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	alignment = BoxContainer.ALIGNMENT_CENTER
	build()


func build() -> void:
	for child: Node in get_children():
		child.queue_free()
	var awards: Dictionary = _awards()
	for slot: PlayerSlot in PlayerManager.active_slots():
		add_child(_column(slot, awards.get(slot.index, [])))


## A quién le toca cada premio (solo si hay más de un jugador y alguien tiene algo).
func _awards() -> Dictionary:
	var result: Dictionary = {}
	var slots: Array[PlayerSlot] = PlayerManager.active_slots()
	if slots.size() < 2:
		return result
	for key: StringName in AWARDS:
		var best: int = -1
		var best_value: float = 0.0
		for slot: PlayerSlot in slots:
			var value: float = RunState.get_stat(slot.index, key)
			if value > best_value:
				best_value = value
				best = slot.index
		if best >= 0:
			if not result.has(best):
				result[best] = []
			result[best].append(AWARDS[key])
	return result


func _column(slot: PlayerSlot, awards: Array) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.9)
	style.border_color = slot.color
	style.set_border_width_all(2)
	style.border_width_top = 5
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(330, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var name_label := _label("%s · %s" % [slot.label, slot.character.display_name if slot.character != null else ""],
			22, slot.color.lightened(0.3))
	box.add_child(name_label)
	if not awards.is_empty():
		box.add_child(_label("★ " + " · ".join(awards), 17, Color(1.0, 0.82, 0.3)))
	var i: int = slot.index
	for line: String in [
			"Daño hecho: %d" % roundi(RunState.get_stat(i, &"damage")),
			"Enemigos: %d  (élites: %d)" % [roundi(RunState.get_stat(i, &"kills")), roundi(RunState.get_stat(i, &"elites"))],
			"Daño recibido: %d" % roundi(RunState.get_stat(i, &"taken")),
			"Caídas: %d" % roundi(RunState.get_stat(i, &"downs")),
			"Oro juntado: %d" % roundi(RunState.get_stat(i, &"gold"))]:
		box.add_child(_label(line, 17, Color(0.88, 0.88, 0.92)))
	box.add_child(_section("Objetos", _item_icons(i)))
	box.add_child(_section("Mejoras", _upgrade_icons(i)))
	return panel


func _section(title: String, icons: Array[ItemIcon]) -> Control:
	var box := VBoxContainer.new()
	box.add_child(_label("%s (%d)" % [title, icons.size()] if not icons.is_empty() else "%s: ninguno" % title,
			15, Color(0.65, 0.65, 0.72)))
	var grid := GridContainer.new()
	grid.columns = ICONS_PER_ROW
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for icon: ItemIcon in icons:
		grid.add_child(icon)
	box.add_child(grid)
	return box


## Objetos de sala (con su nivel) y reliquias del Black Market (con el borde de su rareza).
func _item_icons(index: int) -> Array[ItemIcon]:
	var icons: Array[ItemIcon] = []
	for entry: Dictionary in RunInventory.items(index) + RunInventory.relics(index):
		icons.append(RunInventory.icon_for(entry))
	return icons


func _upgrade_icons(index: int) -> Array[ItemIcon]:
	var icons: Array[ItemIcon] = []
	for entry: Dictionary in RunInventory.upgrades(index):
		icons.append(RunInventory.icon_for(entry))
	return icons


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
