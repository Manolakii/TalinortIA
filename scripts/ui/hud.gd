extends CanvasLayer
## HUD de la partida (GDD, Interfaz): un panel por jugador abajo, el estado de la sala
## arriba, nombres sobre los personajes al empezar y al revivir, y barritas de vida.
##
## Panel: retrato, nombre y oro; vida; barra propia del personaje (Furia, Hambre, arma,
## Relevo); habilidades con el cooldown encima del ícono. Si un personaje pasa por detrás,
## el panel se vuelve semitransparente.

const GOLD_COLOR := Color(1.0, 0.8, 0.25)
const PANEL_BG := Color(0.06, 0.06, 0.09, 0.82)
const NAME_TIME := 2.5
## Máscara redonda para los retratos de los paneles con arte.
const CIRCLE_SHADER: Shader = preload("res://assets/shaders/circle_mask.gdshader")

## Hueco de habilidad: cooldown que baja como sombra y número encima del ícono.
class AbilitySlot:
	extends Control
	var slot_name: String = ""
	var ratio: float = 0.0
	var text: String = ""
	var accent: Color = Color.WHITE
	## Con ícono (paneles con arte): cuadrado con la imagen y el nombre abajo.
	var icon: Texture2D
	var frame: Color = Color(0.3, 0.3, 0.32)
	var glow: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(84, 40)

	func _draw() -> void:
		if icon != null:
			_draw_icon()
			return
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.14, 0.14, 0.18, 0.95))
		draw_rect(Rect2(0, 0, size.x, size.y * ratio), Color(0, 0, 0, 0.55))
		draw_rect(r, accent if ratio <= 0.0 else Color(0.4, 0.4, 0.45), false, 2.0)
		var font: Font = get_theme_default_font()
		draw_string(font, Vector2(4, size.y - 5), slot_name, HORIZONTAL_ALIGNMENT_CENTER,
				size.x - 8, 12, Color(0.85, 0.85, 0.9))
		if text != "":
			draw_string(font, Vector2(0, 19), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color.WHITE)

	func _draw_icon() -> void:
		var side: float = size.x
		var box := Rect2(Vector2.ZERO, Vector2(side, side))
		if glow and ratio <= 0.0:
			draw_rect(box.grow(3.0), Color(accent, 0.55))
		draw_texture_rect(icon, box, false, Color.WHITE if ratio <= 0.0 else Color(0.55, 0.55, 0.58))
		if ratio > 0.0:
			draw_rect(Rect2(0, 0, side, side * ratio), Color(0, 0, 0, 0.6))
		draw_rect(box, frame if ratio > 0.0 or not glow else accent, false, 3.0)
		var font: Font = get_theme_default_font()
		if text != "":
			draw_string_outline(font, Vector2(0, side * 0.5 + 9), text, HORIZONTAL_ALIGNMENT_CENTER, side, 22, 6,
					Color(0, 0, 0, 0.95))
			draw_string(font, Vector2(0, side * 0.5 + 9), text, HORIZONTAL_ALIGNMENT_CENTER, side, 22, Color.WHITE)
		draw_string_outline(font, Vector2(0, side + 16), slot_name, HORIZONTAL_ALIGNMENT_CENTER, side, 13, 4,
				Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(0, side + 16), slot_name, HORIZONTAL_ALIGNMENT_CENTER, side, 13,
				Color(0.96, 0.92, 0.84))


## Barra con texto (vida, Furia, Hambre...). `marks` son rayitas (por ejemplo, el fin de la Lucidez).
class Bar:
	extends Control
	var value: float = 1.0
	var color: Color = Color.WHITE
	var label: String = ""
	var pulse: bool = false
	var marks: Array = []
	## Escudo (0 a 1 de la barra), se dibuja celeste arriba de la vida.
	var shield: float = 0.0
	var trough: Color = Color(0.12, 0.12, 0.16, 0.95)
	var border: Color = Color(0, 0, 0, 0)

	func _init() -> void:
		custom_minimum_size = Vector2(0, 18)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, trough)
		var fill_color: Color = color
		if pulse:
			fill_color = color.lightened(0.25 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)))
		draw_rect(Rect2(0, 0, size.x * clampf(value, 0.0, 1.0), size.y), fill_color)
		if shield > 0.0:
			var w: float = size.x * clampf(shield, 0.0, 1.0)
			draw_rect(Rect2(0, 0, w, size.y * 0.4), Color(0.72, 0.88, 1.0, 0.95))
			draw_rect(Rect2(0, 0, w, size.y), Color(0.72, 0.88, 1.0), false, 2.0)
		for mark: float in marks:
			draw_line(Vector2(size.x * mark, 0), Vector2(size.x * mark, size.y), Color(1, 1, 1, 0.7), 2.0)
		if border.a > 0.0:
			draw_rect(r, border, false, 2.0)
		var font: Font = get_theme_default_font()
		draw_string_outline(font, Vector2(6, 14), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 13, 4,
				Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(6, 14), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 13, Color.WHITE)


class PlayerPanel:
	var player: PlayerCharacter
	var root: PanelContainer
	var name_label: Label
	var gold_label: Label
	var crown_label: Label
	var health: Bar
	var special: Bar
	var chips: HBoxContainer
	var slots: Array = []
	var status_label: Label
	## Panel con arte (HudThemes): estado actual ("tali", "tali_furia"...), retrato y estilo.
	var theme_state: String = ""
	var portrait: TextureRect
	var style: StyleBoxFlat
	var basic_slot: AbilitySlot


var _panels: Array[PlayerPanel] = []
var _row: HBoxContainer
var _room_label: Label
var _toast_box: VBoxContainer


func _ready() -> void:
	layer = 30
	_row = HBoxContainer.new()
	_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_row.offset_bottom = -10.0
	_row.add_theme_constant_override("separation", 12)
	add_child(_row)
	_room_label = Label.new()
	_room_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_room_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_room_label.offset_top = 14.0
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.add_theme_font_size_override("font_size", 22)
	_room_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_room_label.add_theme_constant_override("outline_size", 6)
	add_child(_room_label)
	Events.hit_landed.connect(_on_hit_landed)
	Events.achievement_unlocked.connect(_show_achievement)
	Events.player_revived.connect(func(p: Node3D) -> void: _show_name(p as PlayerCharacter))


func _process(_delta: float) -> void:
	_sync_panels()
	for panel: PlayerPanel in _panels:
		if is_instance_valid(panel.player):
			_update_panel(panel)
	_update_room_label()


func _sync_panels() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player.kit == null:
			continue
		var known: bool = false
		for panel: PlayerPanel in _panels:
			if panel.player == player:
				known = true
		if not known:
			_panels.append(_make_panel(player))
			_show_name(player)


# --- Panel ---

func _make_panel(player: PlayerCharacter) -> PlayerPanel:
	var state: String = HudThemes.state_for(player)
	if state != "":
		return _make_themed_panel(player, state)
	var panel := PlayerPanel.new()
	panel.player = player
	var color: Color = player.slot.color
	panel.root = PanelContainer.new()
	panel.root.custom_minimum_size = Vector2(390, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(8)
	panel.root.add_theme_stylebox_override("panel", style)
	_row.add_child(panel.root)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.root.add_child(hbox)

	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(62, 62)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = color.darkened(0.35)
	portrait_style.border_color = color.lightened(0.3)
	portrait_style.set_border_width_all(2)
	portrait_style.set_corner_radius_all(31)
	portrait.add_theme_stylebox_override("panel", portrait_style)
	var initials := Label.new()
	initials.text = player.data.initials if player.data.initials != "" else player.data.display_name.left(1)
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.add_theme_font_size_override("font_size", 24)
	portrait.add_child(initials)
	hbox.add_child(portrait)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	hbox.add_child(column)

	var top := HBoxContainer.new()
	panel.name_label = Label.new()
	panel.name_label.text = "%s · %s" % [player.slot.label, player.data.display_name]
	panel.name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.name_label.clip_text = true
	panel.name_label.add_theme_font_size_override("font_size", 15)
	panel.name_label.add_theme_color_override("font_color", color.lightened(0.35))
	top.add_child(panel.name_label)
	# Corona del Líder Supremo (reportado por el grupo: no se sabía qué hacía): se ve mientras
	# esté sin usar, para saber que te va a levantar una vez.
	panel.crown_label = Label.new()
	panel.crown_label.text = "Corona lista "
	panel.crown_label.tooltip_text = "Si caés, te levantás solo con el 40% de la vida (una vez)"
	panel.crown_label.add_theme_font_size_override("font_size", 13)
	panel.crown_label.add_theme_color_override("font_color", GOLD_COLOR)
	panel.crown_label.visible = false
	top.add_child(panel.crown_label)
	panel.gold_label = Label.new()
	panel.gold_label.add_theme_font_size_override("font_size", 15)
	panel.gold_label.add_theme_color_override("font_color", GOLD_COLOR)
	top.add_child(panel.gold_label)
	column.add_child(top)

	panel.health = Bar.new()
	panel.health.color = color.lightened(0.15)
	column.add_child(panel.health)

	panel.chips = HBoxContainer.new()
	panel.chips.add_theme_constant_override("separation", 4)
	column.add_child(panel.chips)
	for chip_name: String in player.kit.hud_chips():
		var chip := Label.new()
		chip.text = chip_name
		chip.add_theme_font_size_override("font_size", 12)
		var chip_style := StyleBoxFlat.new()
		chip_style.set_corner_radius_all(6)
		chip_style.set_content_margin_all(3)
		chip_style.content_margin_left = 8
		chip_style.content_margin_right = 8
		chip.add_theme_stylebox_override("normal", chip_style)
		panel.chips.add_child(chip)

	panel.special = Bar.new()
	column.add_child(panel.special)

	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 6)
	column.add_child(slots_row)
	for i: int in 3:
		var slot := AbilitySlot.new()
		slot.accent = color
		slots_row.add_child(slot)
		panel.slots.append(slot)

	panel.status_label = Label.new()
	panel.status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.status_label.add_theme_font_size_override("font_size", 26)
	panel.status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	panel.status_label.add_theme_constant_override("outline_size", 8)
	panel.status_label.visible = false
	panel.root.add_child(panel.status_label)
	return panel


## Panel con el arte del personaje (prueba con los diseños del grupo). Mismo contenido que el de
## siempre, con retrato redondo, íconos y los colores del tema. La vida va en el color del jugador
## (P1 azul, P2 rojo...) para que en co-op se sepa de quién es cada panel.
func _make_themed_panel(player: PlayerCharacter, state: String) -> PlayerPanel:
	var panel := PlayerPanel.new()
	panel.player = player
	var color: Color = player.slot.color
	panel.root = PanelContainer.new()
	panel.root.custom_minimum_size = Vector2(440, 0)
	panel.style = StyleBoxFlat.new()
	panel.style.set_border_width_all(4)
	panel.style.set_corner_radius_all(6)
	panel.style.set_content_margin_all(10)
	panel.style.content_margin_left = 6
	panel.style.shadow_size = 10
	panel.root.add_theme_stylebox_override("panel", panel.style)
	_row.add_child(panel.root)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.root.add_child(hbox)

	# Retrato redondo con aro.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(104, 104)
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(holder)
	panel.portrait = TextureRect.new()
	panel.portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.portrait.offset_left = 5.0
	panel.portrait.offset_top = 5.0
	panel.portrait.offset_right = -5.0
	panel.portrait.offset_bottom = -5.0
	panel.portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var mask := ShaderMaterial.new()
	mask.shader = CIRCLE_SHADER
	panel.portrait.material = mask
	holder.add_child(panel.portrait)
	var ring := Panel.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_meta(&"ring", true)
	holder.add_child(ring)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	hbox.add_child(column)

	var top := HBoxContainer.new()
	var tag := Label.new()
	tag.text = "%s · " % player.slot.label
	tag.add_theme_font_size_override("font_size", 20)
	tag.add_theme_color_override("font_color", color.lightened(0.25))
	_outline(tag)
	top.add_child(tag)
	panel.name_label = Label.new()
	panel.name_label.text = player.data.display_name
	panel.name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.name_label.clip_text = true
	panel.name_label.add_theme_font_size_override("font_size", 20)
	_outline(panel.name_label)
	top.add_child(panel.name_label)
	panel.crown_label = Label.new()
	panel.crown_label.text = "Corona lista "
	panel.crown_label.add_theme_font_size_override("font_size", 13)
	panel.crown_label.add_theme_color_override("font_color", GOLD_COLOR)
	panel.crown_label.visible = false
	top.add_child(panel.crown_label)
	panel.gold_label = Label.new()
	panel.gold_label.add_theme_font_size_override("font_size", 20)
	panel.gold_label.add_theme_color_override("font_color", GOLD_COLOR)
	_outline(panel.gold_label)
	top.add_child(panel.gold_label)
	column.add_child(top)

	panel.health = Bar.new()
	panel.health.custom_minimum_size = Vector2(0, 22)
	panel.health.color = color.lightened(0.1)
	column.add_child(panel.health)
	panel.chips = HBoxContainer.new()
	panel.chips.add_theme_constant_override("separation", 4)
	column.add_child(panel.chips)
	for chip_name: String in player.kit.hud_chips():
		var chip := Label.new()
		chip.text = chip_name
		chip.add_theme_font_size_override("font_size", 12)
		var chip_style := StyleBoxFlat.new()
		chip_style.set_corner_radius_all(6)
		chip_style.set_content_margin_all(3)
		chip_style.content_margin_left = 8
		chip_style.content_margin_right = 8
		chip.add_theme_stylebox_override("normal", chip_style)
		panel.chips.add_child(chip)
	panel.special = Bar.new()
	panel.special.custom_minimum_size = Vector2(0, 20)
	column.add_child(panel.special)

	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 8)
	column.add_child(slots_row)
	panel.basic_slot = AbilitySlot.new()
	panel.basic_slot.custom_minimum_size = Vector2(64, 82)
	slots_row.add_child(panel.basic_slot)
	for i: int in 3:
		var slot := AbilitySlot.new()
		slot.custom_minimum_size = Vector2(64, 82)
		slot.glow = i == 2
		slots_row.add_child(slot)
		panel.slots.append(slot)

	panel.status_label = Label.new()
	panel.status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.status_label.add_theme_font_size_override("font_size", 26)
	panel.status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	panel.status_label.add_theme_constant_override("outline_size", 8)
	panel.status_label.visible = false
	panel.root.add_child(panel.status_label)
	_apply_theme(panel, state)
	return panel


## Pone los colores, el retrato y los íconos del tema (también al cambiar, como Tali en Furia).
func _apply_theme(panel: PlayerPanel, state: String) -> void:
	panel.theme_state = state
	var theme: Dictionary = HudThemes.THEMES[state]
	panel.style.bg_color = Color(theme["bg"], 0.94)
	panel.style.border_color = theme["border"]
	panel.style.shadow_color = theme["glow"]
	panel.name_label.add_theme_color_override("font_color", theme["title"])
	panel.health.trough = theme["trough"]
	panel.health.border = (theme["border"] as Color).darkened(0.2)
	panel.special.trough = theme["trough"]
	panel.special.border = (theme["border"] as Color).darkened(0.2)
	panel.portrait.texture = HudThemes.portrait(state)
	var holder: Control = panel.portrait.get_parent()
	for child: Node in holder.get_children():
		if child.has_meta(&"ring"):
			var ring_style := StyleBoxFlat.new()
			ring_style.draw_center = false
			ring_style.border_color = (theme["border"] as Color).lightened(0.15)
			ring_style.set_border_width_all(5)
			ring_style.set_corner_radius_all(52)
			ring_style.shadow_color = theme["glow"]
			ring_style.shadow_size = 6
			(child as Panel).add_theme_stylebox_override("panel", ring_style)
	var frame: Color = (theme["border"] as Color).darkened(0.1)
	var all_slots: Array = [panel.basic_slot] + panel.slots
	for i: int in all_slots.size():
		var slot: AbilitySlot = all_slots[i]
		slot.icon = HudThemes.icon(state, i)
		slot.frame = frame
		slot.accent = (theme["glow"] as Color).lightened(0.2) if (theme["glow"] as Color).a > 0.0 \
				else (theme["border"] as Color).lightened(0.3)
		slot.queue_redraw()
	panel.basic_slot.slot_name = theme["basic"]


func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)


func _update_panel(panel: PlayerPanel) -> void:
	var player: PlayerCharacter = panel.player
	var kit: CharacterKit = player.kit
	panel.gold_label.text = "● %d" % RunState.get_gold(player.slot.index)
	panel.crown_label.visible = RunState.has_special(player.slot.index, &"corona_lider") 			and RunState.get_bonus(player.slot.index, &"corona_used") == 0
	panel.health.value = player.health.ratio()
	panel.health.label = "%d / %d" % [roundi(player.health.current), roundi(player.health.max_health)]
	panel.health.shield = player.health.shield / maxf(player.health.max_health, 1.0)
	if player.health.shield > 0.0:
		panel.health.label += "  +%d escudo" % ceili(player.health.shield)

	var active: int = kit.hud_chip_active()
	for i: int in panel.chips.get_child_count():
		var chip := panel.chips.get_child(i) as Label
		var chip_style := chip.get_theme_stylebox("normal") as StyleBoxFlat
		var on: bool = i == active
		chip_style.bg_color = player.slot.color.darkened(0.2) if on else Color(0.16, 0.16, 0.2)
		chip.add_theme_color_override("font_color", Color.WHITE if on else Color(0.6, 0.6, 0.65))

	var bar: Dictionary = kit.hud_bar()
	panel.special.visible = not bar.is_empty()
	if not bar.is_empty():
		panel.special.value = bar.get("value", 0.0)
		panel.special.color = bar.get("color", Color.WHITE)
		panel.special.label = bar.get("label", "")
		panel.special.pulse = bar.get("pulse", false)
		panel.special.marks = bar.get("marks", [])
		if panel.theme_state != "" and not panel.special.pulse:
			panel.special.color = HudThemes.THEMES[panel.theme_state]["special"]

	if panel.theme_state != "":
		var state: String = HudThemes.state_for(player)
		if state != panel.theme_state:
			_apply_theme(panel, state)
	var abilities: Array[Dictionary] = kit.hud_abilities()
	for i: int in panel.slots.size():
		var slot: AbilitySlot = panel.slots[i]
		slot.visible = i < abilities.size()
		if slot.visible:
			slot.slot_name = abilities[i]["name"]
			slot.ratio = abilities[i]["ratio"]
			slot.text = abilities[i]["text"]
			slot.queue_redraw()

	# Caído o afuera
	panel.status_label.visible = player.is_downed() or player.is_out()
	# Caído o afuera: el resto del panel se atenúa para que el cartel se lea limpio.
	(panel.root.get_child(0) as Control).modulate.a = 0.25 if panel.status_label.visible else 1.0
	if panel.status_label.visible:
		if player.is_out():
			panel.status_label.text = "AFUERA"
			panel.status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		else:
			panel.status_label.text = "¡CAÍDO! %d s" % ceili(player.down_time_left())
			panel.status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))

	# Si un personaje pasa por detrás del panel, el panel se vuelve semitransparente.
	panel.root.modulate.a = 0.3 if _someone_behind(panel.root.get_global_rect()) else 1.0


func _someone_behind(rect: Rect2) -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return false
	var area: Rect2 = rect.grow(16.0)
	for node: Node in get_tree().get_nodes_in_group(&"enemy_targets"):
		var body := node as Node3D
		if body == null or camera.is_position_behind(body.global_position):
			continue
		if area.has_point(camera.unproject_position(body.global_position + Vector3.UP)):
			return true
	return false


func _update_room_label() -> void:
	var director := get_tree().get_first_node_in_group(&"combat_director") as CombatDirector
	var difficulty: String = Balance.difficulty.names[RunState.difficulty]
	var stage_run: Node = get_tree().get_first_node_in_group(&"room_title")
	if stage_run != null:
		var text: String = "%s · %s" % [stage_run.room_title(), difficulty]
		if director != null and director.wave_index >= 0 and director.state != CombatDirector.Phase.CLEARED:
			text += " · Oleada %d de %d" % [director.wave_index + 1, director.total_waves()]
		_room_label.text = text
	elif director != null:
		_room_label.text = "%s · %s · Oleada %d de %d" % [director.waves.room_name, difficulty,
				maxi(director.wave_index + 1, 1), director.total_waves()]
	else:
		_room_label.text = "Sala de prueba · %s · F7 más enemigos · F8 menos · F9 matar a todos" % difficulty


# --- Mundo: nombres y barritas de vida ---

## El nombre aparece al empezar la sala y al revivir (sin carteles fijos, GDD Interfaz).
func _show_name(player: PlayerCharacter) -> void:
	if player == null:
		return
	var label := Label3D.new()
	label.text = "%s · %s" % [player.slot.label, player.data.display_name]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 34
	label.outline_size = 10
	label.outline_modulate = Color(0.05, 0.05, 0.08, 0.9)
	label.modulate = player.slot.color.lightened(0.35)
	label.position.y = player.hurtbox.height + 0.9
	player.add_child(label)
	var tween: Tween = label.create_tween()
	tween.tween_interval(NAME_TIME)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


## Cartelito de logro desbloqueado, arriba a la derecha.
func _show_achievement(title: String, how: String) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.1, 0.92)
	style.border_color = GOLD_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(440, 0)
	if _toast_box == null:
		# Los cartelitos se apilan uno abajo del otro, arriba a la derecha.
		_toast_box = VBoxContainer.new()
		_toast_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_toast_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_toast_box.offset_right = -20.0
		_toast_box.offset_top = 70.0
		_toast_box.add_theme_constant_override("separation", 8)
		add_child(_toast_box)
	var text := Label.new()
	text.text = "★ ¡Logro! %s
%s" % [title, how]
	text.add_theme_font_size_override("font_size", 18)
	text.add_theme_color_override("font_color", GOLD_COLOR)
	panel.add_child(text)
	_toast_box.add_child(panel)
	var tween: Tween = panel.create_tween()
	panel.modulate.a = 0.0
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(3.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)


func _on_hit_landed(_info: DamageInfo, target: Node3D) -> void:
	var combatant := target as Combatant
	if combatant == null or combatant.health == null:
		return
	var bar := combatant.get_node_or_null("HealthBar3D") as HealthBar3D
	if bar == null:
		bar = HealthBar3D.new()
		bar.name = "HealthBar3D"
		combatant.add_child(bar)
		bar.setup(combatant)
	bar.reveal()
