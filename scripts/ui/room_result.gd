extends CanvasLayer
## Cartel de fin de sala: ganaron o perdieron. Cualquiera puede elegir:
##   Enter o A: partida nueva (desde Birig Bamba) · E o X: volver a la pantalla de unión.

const JOIN_SCENE := "res://scenes/ui/join_screen.tscn"
## "Jugar de nuevo" arranca una partida nueva desde Birig Bamba.
const HUB_SCENE := "res://scenes/hub/birig_bamba.tscn"
const WIN_TITLE := "¡Sala superada!"
const WIN_LINES: Array[String] = [
	"Talinorthland, donde la supervivencia es un éxito.",
	"Ni un rasguño. Bueno, algunos.",
]
const LOSE_TITLE := "Los cegaron a todos..."
const LOSE_LINES: Array[String] = [
	"Talinorthland, donde la supervivencia es un éxito. Hoy no fue un éxito.",
	"El Croco dice que esto no se lo cobra a nadie.",
]

var _panel: Control
var _title: Label
var _line: Label
var _hint: Label
var _stats_holder: VBoxContainer
var _active: bool = false
var _wait: float = 0.0
## Si está, "seguir" llama a esto en vez de empezar una partida nueva (ganaron el stage).
var _on_continue: Callable


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 22)
	_panel.add_child(box)
	_title = _make_label(64)
	_line = _make_label(26)
	_hint = _make_label(24)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	# Estadísticas de la partida (pedido del grupo).
	_stats_holder = VBoxContainer.new()
	for node: Control in [_title, _line, _stats_holder, _hint]:
		box.add_child(node)


## `on_continue`: si se pasa, la partida sigue (por ejemplo, ganaron el stage y vuelven a
## Birig Bamba) y todavía no se cobra la McoinIA.
func show_result(won: bool, title: String = "", line: String = "", on_continue: Callable = Callable()) -> void:
	_on_continue = on_continue
	_active = true
	_wait = 1.0  # que nadie lo saltee sin querer apretando ataque
	_title.text = title if title != "" else (WIN_TITLE if won else LOSE_TITLE)
	var lines: Array[String] = WIN_LINES if won else LOSE_LINES
	_line.text = line if line != "" else lines[randi() % lines.size()]
	if _on_continue.is_valid():
		_hint.text = "Enter o A: volver a Birig Bamba  ·  pasá el mouse por un objeto para ver qué hace"
	else:
		_hint.text = "Enter o A: jugar de nuevo  ·  E o X: volver a elegir personajes"
		# Ganes o pierdas, cobrás McoinIA (GDD).
		var earned: int = RunState.award_mcoinia(won)
		if RunState.mcoinia_awarded:
			_line.text += "\n\n+%d McoinIA  ·  total: %d (se gasta en Birig Bamba)" % [earned, MetaProgress.get_balance()]
	for child: Node in _stats_holder.get_children():
		child.queue_free()
	_stats_holder.add_child(RunStatsPanel.new())
	_panel.visible = true


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	for slot: PlayerSlot in PlayerManager.active_slots():
		if _on_continue.is_valid():
			if slot.input.just_pressed(PlayerInput.Action.CONFIRM):
				_active = false
				_panel.visible = false
				_on_continue.call()
				return
			continue
		if slot.input.just_pressed(PlayerInput.Action.CONFIRM):
			_active = false
			RunState.start_run()
			get_tree().change_scene_to_file(HUB_SCENE)
			return
		if slot.input.just_pressed(PlayerInput.Action.INTERACT):
			_active = false
			RunState.end_run()
			PlayerManager.reset()
			get_tree().change_scene_to_file(JOIN_SCENE)
			return


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
