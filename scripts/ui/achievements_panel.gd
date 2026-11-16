class_name AchievementsPanel
extends CanvasLayer
## Cartelera de logros de Birig Bamba (pedido del grupo): la lista con los que ya tienen y los
## que faltan (con cómo se consiguen). Se cierra con E / X, B o Esc.

signal closed

const BG := Color(0.07, 0.06, 0.1, 0.95)
const GOLD := Color(1.0, 0.82, 0.3)

var player: PlayerCharacter
var _wait: float = 0.25


func open(by: PlayerCharacter) -> void:
	player = by
	layer = 37
	player.menu_locked = true
	player.slot.input.consume_all()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(900, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var ids: Array = Achievements.all_ids()
	box.add_child(_label("Logros del grupo · %d de %d" % [Achievements.unlocked_count(), ids.size()], 32, GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	for id: Variant in ids:
		var done: bool = Achievements.is_unlocked(id)
		var line := VBoxContainer.new()
		line.add_theme_constant_override("separation", -2)
		line.add_child(_label(("★ " if done else "☆ ") + Achievements.title(id), 20,
				GOLD if done else Color(0.6, 0.6, 0.65)))
		line.add_child(_label("   " + Achievements.how(id), 15, Color(0.82, 0.82, 0.88) if done else Color(0.5, 0.5, 0.55)))
		grid.add_child(line)
	box.add_child(_label("E / X o B / Esc: cerrar", 16, Color(0.6, 0.6, 0.66)))


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or not is_instance_valid(player):
		return
	var input: PlayerInput = player.slot.input
	for action: PlayerInput.Action in [PlayerInput.Action.INTERACT, PlayerInput.Action.BACK,
			PlayerInput.Action.PAUSE, PlayerInput.Action.CONFIRM]:
		if input.just_pressed(action):
			close()
			return


func close() -> void:
	if is_instance_valid(player):
		player.menu_locked = false
		player.slot.input.consume_all()
	closed.emit()
	queue_free()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
