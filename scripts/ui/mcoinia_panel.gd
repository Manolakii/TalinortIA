class_name McoiniaPanel
extends CanvasLayer
## Menú de McoinIA (GDD): dos columnas, General (izquierda) y Héroe (derecha, del personaje del
## jugador que lo abrió). W/S para moverse, A/D para cambiar de columna, Enter/E o A/X para
## comprar el siguiente nivel, Esc/B para salir. La McoinIA es del grupo.

signal closed

const GOLD := Color(1.0, 0.82, 0.3)
const BG := Color(0.07, 0.07, 0.1, 0.96)

var player: PlayerCharacter
var _columns: Array = [[], []]  # Array[McoiniaUpgrade] por columna
var _column: int = 0
var _row: int = 0
var _balance_label: Label
var _lists: Array[VBoxContainer] = []
var _message: Label
var _wait: float = 0.3


func open(by: PlayerCharacter) -> void:
	player = by
	layer = 37
	player.menu_locked = true
	player.slot.input.consume_all()
	_columns = [Balance.mcoinia.column(&""), Balance.mcoinia.column(player.data.id)]
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(980, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "McoinIA · la moneda intergaláctica (es del grupo)"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	_balance_label = Label.new()
	_balance_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_balance_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for i: int in 2:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(460, 0)
		column.add_theme_constant_override("separation", 6)
		var head := Label.new()
		head.text = "General (para todos)" if i == 0 else "Héroe: %s" % player.data.display_name
		head.add_theme_font_size_override("font_size", 20)
		head.add_theme_color_override("font_color", Color(0.85, 0.87, 0.95) if i == 0 else player.slot.color.lightened(0.3))
		column.add_child(head)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 4)
		column.add_child(list)
		_lists.append(list)
		row.add_child(column)
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 16)
	_message.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	_message.text = "W/S: elegir · A/D: columna · Enter/E o A/X: comprar · Esc/B: salir"
	box.add_child(_message)
	_refresh()


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or not is_instance_valid(player):
		return
	var input: PlayerInput = player.slot.input
	var size: int = (_columns[_column] as Array).size()
	if input.just_pressed(PlayerInput.Action.UP):
		_row = wrapi(_row - 1, 0, maxi(size, 1))
		Sound.play("ui_move", -6.0, 0.0)
		_refresh()
	elif input.just_pressed(PlayerInput.Action.DOWN):
		_row = wrapi(_row + 1, 0, maxi(size, 1))
		Sound.play("ui_move", -6.0, 0.0)
		_refresh()
	elif input.just_pressed(PlayerInput.Action.LEFT) or input.just_pressed(PlayerInput.Action.RIGHT):
		_column = 1 - _column
		_row = mini(_row, maxi((_columns[_column] as Array).size() - 1, 0))
		Sound.play("ui_move", -6.0, 0.0)
		_refresh()
	elif input.just_pressed(PlayerInput.Action.CONFIRM) or input.just_pressed(PlayerInput.Action.INTERACT):
		buy(_column, _row)
	elif input.just_pressed(PlayerInput.Action.BACK):
		close()


## Compra el siguiente nivel de la mejora (también lo usan los tests).
func buy(column: int, row: int) -> bool:
	var list: Array = _columns[column]
	if row >= list.size():
		return false
	var upgrade: McoiniaUpgrade = list[row]
	if not MetaProgress.buy(upgrade):
		Sound.play("ui_error", 0.0, 0.0)
		_message.text = "No alcanza la McoinIA" if MetaProgress.level(upgrade.id) < upgrade.max_level() else "Ya está al máximo"
		return false
	Sound.play("ui_confirm", 0.0, 0.0)
	_message.text = "¡Comprado! %s nivel %d (se aplica desde la próxima partida)" % [upgrade.display_name,
			MetaProgress.level(upgrade.id)]
	_refresh()
	return true


func close() -> void:
	if is_instance_valid(player):
		player.menu_locked = false
		player.slot.input.consume_all()
	closed.emit()
	queue_free()


func _refresh() -> void:
	_balance_label.text = "Tenés %d McoinIA" % MetaProgress.get_balance()
	for i: int in 2:
		var list: VBoxContainer = _lists[i]
		for child: Node in list.get_children():
			child.queue_free()
		var upgrades: Array = _columns[i]
		for r: int in upgrades.size():
			var upgrade: McoiniaUpgrade = upgrades[r]
			var level: int = MetaProgress.level(upgrade.id)
			var selected: bool = i == _column and r == _row
			var card := PanelContainer.new()
			var style := StyleBoxFlat.new()
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
			name_label.text = "%s  (nivel %d de %d)" % [upgrade.display_name, level, upgrade.max_level()]
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.add_theme_font_size_override("font_size", 16)
			top.add_child(name_label)
			var price := Label.new()
			price.text = "MÁXIMO" if level >= upgrade.max_level() else "%d McoinIA" % upgrade.costs[level]
			price.add_theme_font_size_override("font_size", 15)
			price.add_theme_color_override("font_color", GOLD)
			top.add_child(price)
			var desc := Label.new()
			desc.text = upgrade.description
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.custom_minimum_size = Vector2(430, 0)
			desc.add_theme_font_size_override("font_size", 13)
			desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
			inner.add_child(desc)
			list.add_child(card)
