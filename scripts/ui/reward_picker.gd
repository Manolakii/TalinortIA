class_name RewardPicker
extends CanvasLayer
## Elegir 1 de 3 (GDD: mejoras de personaje y objetos genéricos). Cada jugador elige en su
## propio panel, arriba de su panel del HUD: W/S o la cruceta para moverse, Enter/E o A/X
## para elegir. Mientras elige no se mueve. Cuando eligieron todos, emite `finished`.

signal finished

enum Kind { UPGRADE, ITEM }

const PANEL_WIDTH := 390.0
const BG := Color(0.07, 0.07, 0.09, 0.92)
const CARD_BG := Color(0.13, 0.13, 0.16, 0.95)
const GOLD := Color(1.0, 0.82, 0.3)
## Si a alguien no le queda ninguna mejora para elegir, recibe este oro.
const NOTHING_LEFT_GOLD := 25

class Choice:
	var player: PlayerCharacter
	var options: Array = []  # [{id, name, description}]
	var selected: int = 0
	var done: bool = false
	var cards: Array[PanelContainer] = []
	var title: Label

var kind: Kind = Kind.UPGRADE
var _choices: Array[Choice] = []
var _wait: float = 0.35


func start(which: Kind, players: Array[PlayerCharacter], heading: String = "") -> void:
	kind = which
	layer = 35
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -150.0
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	var top := Label.new()
	top.text = heading if heading != "" else ("¡Elegí una mejora!" if kind == Kind.UPGRADE else "¡Elegí un objeto!")
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 60.0
	top.add_theme_font_size_override("font_size", 40)
	top.add_theme_color_override("font_color", GOLD)
	top.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	top.add_theme_constant_override("outline_size", 10)
	add_child(top)
	for player: PlayerCharacter in players:
		var choice := Choice.new()
		choice.player = player
		choice.options = _options_for(player)
		_choices.append(choice)
		row.add_child(_build_panel(choice))
		if choice.options.is_empty():
			# No le queda nada para elegir: oro de consuelo.
			RunState.add_gold(player.slot.index, NOTHING_LEFT_GOLD)
			_finish_choice(choice, "Ya tenés todas: +%d de oro" % NOTHING_LEFT_GOLD)
		else:
			player.menu_locked = true
			player.slot.input.consume_all()
			_refresh(choice)
	_check_all_done()


func _options_for(player: PlayerCharacter) -> Array:
	var result: Array = []
	var rng: RandomNumberGenerator = RunState.rng
	if kind == Kind.UPGRADE:
		var owned: Array = RunState.get_upgrades(player.slot.index)
		for upgrade: CharacterUpgrade in Balance.upgrades.offer(player.data.id, owned, rng, 3):
			var level: int = owned.count(upgrade.id)
			var name: String = upgrade.display_name
			if level >= 1:
				name += " (nivel 2)" if upgrade.senda_slot != &"" else " (x%d)" % (level + 1)
			result.append({"id": upgrade.id, "name": name, "description": upgrade.description})
	else:
		var pool: Array[GenericItem] = Balance.generic_items.items.duplicate()
		while not pool.is_empty() and result.size() < 3:
			var item: GenericItem = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			result.append({"id": item.id, "name": item.display_name, "description": item.description})
	return result


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	for choice: Choice in _choices:
		if choice.done or not is_instance_valid(choice.player):
			continue
		var input: PlayerInput = choice.player.slot.input
		if input.just_pressed(PlayerInput.Action.UP):
			choice.selected = wrapi(choice.selected - 1, 0, choice.options.size())
			_refresh(choice)
		elif input.just_pressed(PlayerInput.Action.DOWN):
			choice.selected = wrapi(choice.selected + 1, 0, choice.options.size())
			_refresh(choice)
		elif input.just_pressed(PlayerInput.Action.CONFIRM) or input.just_pressed(PlayerInput.Action.INTERACT):
			_pick(choice)


## Elige la opción marcada (también lo usan los tests).
func pick(player_index: int, option: int) -> void:
	var choice: Choice = _choices[player_index]
	choice.selected = option
	_pick(choice)


func _pick(choice: Choice) -> void:
	if choice.done:
		return
	var option: Dictionary = choice.options[choice.selected]
	if kind == Kind.UPGRADE:
		RunState.add_upgrade(choice.player.slot.index, option["id"])
	else:
		RunState.add_item(choice.player.slot.index, option["id"])
	_finish_choice(choice, "Elegiste: %s" % option["name"])
	_check_all_done()


func _finish_choice(choice: Choice, text: String) -> void:
	choice.done = true
	if is_instance_valid(choice.player):
		choice.player.menu_locked = false
		choice.player.slot.input.consume_all()
	choice.title.text = text
	for i: int in choice.cards.size():
		choice.cards[i].modulate.a = 1.0 if i == choice.selected else 0.25


func _check_all_done() -> void:
	for choice: Choice in _choices:
		if not choice.done:
			return
	set_physics_process(false)
	var tween: Tween = create_tween()
	tween.tween_interval(0.9)
	tween.tween_callback(func() -> void: finished.emit())


func is_done() -> bool:
	for choice: Choice in _choices:
		if not choice.done:
			return false
	return true


# --- UI ---

func _build_panel(choice: Choice) -> Control:
	var color: Color = choice.player.slot.color
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
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	choice.title = Label.new()
	choice.title.text = "%s · %s" % [choice.player.slot.label, choice.player.data.display_name]
	choice.title.add_theme_font_size_override("font_size", 20)
	choice.title.add_theme_color_override("font_color", color.lightened(0.3))
	choice.title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(choice.title)
	for option: Dictionary in choice.options:
		var card := PanelContainer.new()
		var inner := VBoxContainer.new()
		card.add_child(inner)
		var name_label := Label.new()
		name_label.text = option["name"]
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.add_theme_color_override("font_color", GOLD)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(name_label)
		var description := Label.new()
		description.text = option["description"]
		description.add_theme_font_size_override("font_size", 15)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size = Vector2(PANEL_WIDTH - 44.0, 0)
		inner.add_child(description)
		box.add_child(card)
		choice.cards.append(card)
	return panel


func _refresh(choice: Choice) -> void:
	for i: int in choice.cards.size():
		var selected: bool = i == choice.selected
		var style := StyleBoxFlat.new()
		style.bg_color = CARD_BG.lightened(0.12) if selected else CARD_BG
		style.border_color = choice.player.slot.color if selected else Color(0.3, 0.3, 0.34)
		style.set_border_width_all(3 if selected else 1)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(8)
		choice.cards[i].add_theme_stylebox_override("panel", style)
