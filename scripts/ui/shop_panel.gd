class_name ShopPanel
extends CanvasLayer
## La tienda de Yole Sajor para UN jugador (GDD: cada jugador ve su propio stock): 4 objetos
## especiales más 1 mejora de kit, volver a tirar el stock (25, y sube 25 cada vez) e irse.
## Aparece arriba del panel de ese jugador en el HUD. W/S o cruceta para moverse,
## Enter/E o A/X para comprar, Esc/B para irse.

signal closed

const PANEL_WIDTH := 390.0
const BG := Color(0.08, 0.07, 0.1, 0.95)
const GOLD := Color(1.0, 0.82, 0.3)
const RARITY_COLORS: Array[Color] = [Color(0.85, 0.85, 0.85), Color(0.4, 0.85, 1.0),
		Color(1.0, 0.45, 0.75), Color(1.0, 0.82, 0.3)]
const KIT_COLOR := Color(1.0, 0.65, 0.35)

var player: PlayerCharacter
var _rows: Array[Dictionary] = []  # {kind, id, price, label, desc, color}
var _row_nodes: Array[PanelContainer] = []
var _selected: int = 0
var _gold_label: Label
var _quote: Label
var _list: VBoxContainer
var _wait: float = 0.3


## `column` y `columns`: en qué lugar de la fila de paneles del HUD está este jugador.
func open(shopper: PlayerCharacter, column: int, columns: int) -> void:
	player = shopper
	layer = 35
	player.menu_locked = true
	player.slot.input.consume_all()
	_ensure_stock()
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -150.0
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for i: int in columns:
		if i == column:
			row.add_child(_build_panel())
		else:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
			row.add_child(spacer)
	_say(Dialogue.line("yole_saludo"))
	_refresh()


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or not is_instance_valid(player):
		return
	var input: PlayerInput = player.slot.input
	if input.just_pressed(PlayerInput.Action.UP):
		_selected = wrapi(_selected - 1, 0, _rows.size())
		Sound.play("ui_move", -6.0, 0.0)
		_refresh()
	elif input.just_pressed(PlayerInput.Action.DOWN):
		_selected = wrapi(_selected + 1, 0, _rows.size())
		Sound.play("ui_move", -6.0, 0.0)
		_refresh()
	elif input.just_pressed(PlayerInput.Action.CONFIRM) or input.just_pressed(PlayerInput.Action.INTERACT):
		choose(_selected)
	elif (input.just_pressed(PlayerInput.Action.BACK) or input.just_pressed(PlayerInput.Action.PAUSE)):
		close()


## Elige la fila `index` (también lo usan los tests).
func choose(index: int) -> void:
	var row: Dictionary = _rows[index]
	match row["kind"]:
		&"leave":
			close()
		&"reroll":
			_reroll()
		_:
			_buy(row)


func close() -> void:
	if is_instance_valid(player):
		player.menu_locked = false
		player.slot.input.consume_all()
		Dialogue.say("yole_chau", player.global_position + Vector3.UP * 2.6, GOLD)
	closed.emit()
	queue_free()


# --- Stock ---

func _state() -> Dictionary:
	return RunState.shop_state[player.slot.index]


## Stock de esta visita (se arma la primera vez que habla con Yole).
func _ensure_stock() -> void:
	var index: int = player.slot.index
	if RunState.shop_state.has(index) and RunState.shop_state[index].get("visit", -1) == RunState.visit:
		_build_rows()
		return
	RunState.shop_state[index] = {"visit": RunState.visit, "rerolls": 0}
	_roll()


func _roll() -> void:
	var state: Dictionary = _state()
	var stock: Array[SpecialItem] = Balance.shop.roll_stock(RunState.get_specials(player.slot.index),
			RunState.visit, RunState.rng)
	state["items"] = stock.map(func(item: SpecialItem) -> StringName: return item.id)
	var kit: CharacterUpgrade = Balance.upgrades.shop_upgrade_for(player.data.id,
			RunState.get_upgrades(player.slot.index), RunState.rng)
	state["kit"] = kit.id if kit != null else &""
	var yole: CharacterUpgrade = Balance.upgrades.shop_upgrade_for(player.data.id,
			RunState.get_upgrades(player.slot.index), RunState.rng, true)
	state["yole"] = yole.id if yole != null else &""
	state["sold"] = []
	_build_rows()


func reroll_price() -> int:
	return Balance.shop.reroll_base + Balance.shop.reroll_step * int(_state().get("rerolls", 0))


func _build_rows() -> void:
	var state: Dictionary = _state()
	var sold: Array = state.get("sold", [])
	_rows.clear()
	for id: Variant in state.get("items", []):
		var item: SpecialItem = Balance.shop.get_item(id)
		if item == null:
			continue
		_rows.append({"kind": &"special", "id": item.id, "price": Balance.shop.price_of(item),
				"label": "[%s] %s" % [Balance.shop.rarity_names[item.rarity], item.display_name],
				"desc": item.description, "color": RARITY_COLORS[item.rarity], "sold": sold.has(item.id)})
	for key: String in ["yole", "kit"]:
		if state.get(key, &"") == &"":
			continue
		var upgrade: CharacterUpgrade = Balance.upgrades.get_upgrade(state[key])
		var kit_price: int = upgrade.price if upgrade.price > 0 else Balance.shop.kit_upgrade_price
		# Pedido del grupo: que se note que son únicas y que no salen como premio.
		_rows.append({"kind": &"kit", "id": upgrade.id, "price": kit_price,
				"label": ("[Kit de Yole · único] %s" if key == "yole" else "[Mejora de kit · única] %s") % upgrade.display_name,
				"desc": upgrade.description + " (solo se consigue acá)",
				"color": KIT_COLOR, "sold": sold.has(upgrade.id)})
	_rows.append({"kind": &"reroll", "id": &"", "price": reroll_price(), "label": "Volver a tirar el stock",
			"desc": "Yole busca otra cosa en el fondo del puesto", "color": Color(0.8, 0.8, 0.85), "sold": false})
	_rows.append({"kind": &"leave", "id": &"", "price": 0, "label": "Irse",
			"desc": "", "color": Color(0.7, 0.7, 0.75), "sold": false})
	_selected = mini(_selected, _rows.size() - 1)


func _buy(row: Dictionary) -> void:
	if row["sold"]:
		return
	var index: int = player.slot.index
	if RunState.get_gold(index) < row["price"]:
		_say(Dialogue.line("yole_sin_plata"))
		Sound.play("ui_error", 0.0, 0.0)
		return
	Sound.play("ui_confirm", 0.0, 0.0)
	RunState.add_gold(index, -row["price"])
	if row["kind"] == &"special":
		RunState.add_special(index, row["id"])
	else:
		RunState.add_upgrade(index, row["id"])
		var bought: CharacterUpgrade = Balance.upgrades.get_upgrade(row["id"])
		if bought != null and bought.price > 0:
			Achievements.unlock("cliente_vip")
	(_state()["sold"] as Array).append(row["id"])
	_say(Dialogue.line("yole_compra"))
	_build_rows()
	_refresh()


func _reroll() -> void:
	var index: int = player.slot.index
	var price: int = reroll_price()
	if RunState.get_gold(index) < price:
		_say(Dialogue.line("yole_sin_plata"))
		return
	RunState.add_gold(index, -price)
	_state()["rerolls"] = int(_state().get("rerolls", 0)) + 1
	_roll()
	_say(Dialogue.line("yole_retira"))
	_refresh()


# --- UI ---

func _build_panel() -> Control:
	var color: Color = player.slot.color
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Yole Sajor · mercado (negro)"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	_quote = Label.new()
	_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0)
	_quote.add_theme_font_size_override("font_size", 15)
	_quote.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	box.add_child(_quote)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 17)
	_gold_label.add_theme_color_override("font_color", GOLD)
	box.add_child(_gold_label)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	box.add_child(_list)
	return panel


func _refresh() -> void:
	if _list == null:
		return
	_gold_label.text = "%s · tu oro: %d" % [player.slot.label, RunState.get_gold(player.slot.index)]
	for child: Node in _list.get_children():
		child.queue_free()
	_row_nodes.clear()
	for i: int in _rows.size():
		var row: Dictionary = _rows[i]
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		var selected: bool = i == _selected
		style.bg_color = Color(0.16, 0.15, 0.2) if selected else Color(0.11, 0.1, 0.14)
		style.border_color = player.slot.color if selected else Color(0.25, 0.25, 0.3)
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(6)
		card.add_theme_stylebox_override("panel", style)
		var inner := VBoxContainer.new()
		card.add_child(inner)
		var top := HBoxContainer.new()
		inner.add_child(top)
		var name_label := Label.new()
		name_label.text = row["label"]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", row["color"])
		top.add_child(name_label)
		var price := Label.new()
		price.text = "VENDIDO" if row["sold"] else ("%d de oro" % row["price"] if row["price"] > 0 else "")
		price.add_theme_font_size_override("font_size", 15)
		price.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65) if row["sold"] else GOLD)
		top.add_child(price)
		if selected and row["desc"] != "":
			var desc := Label.new()
			desc.text = row["desc"]
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.custom_minimum_size = Vector2(PANEL_WIDTH - 40.0, 0)
			desc.add_theme_font_size_override("font_size", 14)
			inner.add_child(desc)
		card.modulate.a = 0.45 if row["sold"] else 1.0
		_list.add_child(card)
		_row_nodes.append(card)


func _say(text: String) -> void:
	if _quote != null:
		_quote.text = "\"%s\"" % text


func rows() -> Array[Dictionary]:
	return _rows
