extends CanvasLayer
## HUD de prueba (hasta el HUD real de la Fase 4): un panel por jugador abajo,
## con vida y lo que informe su kit (barras, cargas, cooldowns).

var _panels: Dictionary[PlayerCharacter, Label] = {}
var _row: HBoxContainer
var _info: Label


func _ready() -> void:
	layer = 30
	_row = HBoxContainer.new()
	_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_row.offset_top = -12.0
	_row.offset_bottom = -12.0
	_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_row.offset_left = 16.0
	_row.offset_right = -16.0
	_row.add_theme_constant_override("separation", 12)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_row)
	_info = Label.new()
	_info.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_info.offset_left = -420.0
	_info.offset_top = 12.0
	_info.offset_right = -16.0
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.add_theme_font_size_override("font_size", 16)
	_info.add_theme_color_override("font_shadow_color", Color.BLACK)
	add_child(_info)


func _process(_delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player != null and not _panels.has(player) and player.kit != null:
			_panels[player] = _make_panel(player)
	for player: PlayerCharacter in _panels.keys():
		if not is_instance_valid(player):
			continue
		var lines: Array[String] = ["%s · %s" % [player.slot.label, player.data.display_name],
				"Vida %d / %d" % [roundi(player.health.current), roundi(player.health.max_health)]]
		lines.append_array(player.kit.debug_lines())
		_panels[player].text = "\n".join(lines)
	_info.text = "Enemigos: %d   (F7 más · F8 menos · F9 matar a todos)" \
			% get_tree().get_nodes_in_group(&"enemies").size()


func _make_panel(player: PlayerCharacter) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.72)
	style.border_color = player.slot.color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 16)
	panel.add_child(label)
	_row.add_child(panel)
	return label
