class_name BossBar
extends CanvasLayer
## Barra del boss arriba (GDD, Plan Fase 7): nombre, vida, marcas de las fases y el escalado
## por jugadores.

const BG := Color(0.06, 0.05, 0.08, 0.9)
const FILL := Color(0.78, 0.3, 0.25)
const FILL_SHADOW := Color(0.55, 0.25, 0.9)
const WIDTH := 760.0

var boss: GronkGigante
var _fill: ColorRect
var _label: Label


func setup(target: GronkGigante) -> void:
	boss = target
	layer = 32
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 132.0
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 8)
	box.add_child(_label)
	var back := ColorRect.new()
	back.color = BG
	back.custom_minimum_size = Vector2(WIDTH, 22)
	# Ancho fijo: con 2+ jugadores el texto de arriba es más ancho y estiraba el fondo, así que
	# la barra arrancaba "sin llenar" (reportado por el grupo: parecía que el boss ya tenía daño).
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	_fill = ColorRect.new()
	_fill.color = FILL
	_fill.anchor_bottom = 1.0
	_fill.anchor_right = 1.0
	back.add_child(_fill)
	# Marcas de las fases.
	for at: float in [boss.cfg.phase_two_at, boss.cfg.phase_three_at]:
		var mark := ColorRect.new()
		mark.color = Color(1, 1, 1, 0.8)
		mark.size = Vector2(3, 22)
		mark.position = Vector2(WIDTH * at - 1.5, 0)
		back.add_child(mark)
	boss.health.changed.connect(func(_current: float, _maximum: float) -> void: _refresh())
	boss.phase_changed.connect(func(_phase: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(boss):
		return
	var ratio: float = boss.health.ratio()
	_fill.anchor_right = ratio
	_fill.offset_right = 0.0
	_fill.color = FILL if boss.phase == 1 else FILL_SHADOW
	var players: int = Scaling.players_for_scaling()
	var scaling: String = "" if players <= 1 else " · vida x%.1f por %d jugadores" % [boss.health_multiplier, players]
	_label.text = "%s · Fase %d de 3 · %d / %d%s" % [boss.data.display_name, boss.phase,
			ceili(boss.health.current), ceili(boss.health.max_health), scaling]
	visible = ratio > 0.0
