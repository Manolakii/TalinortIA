extends CanvasLayer
## Datos de debug arriba a la izquierda: fps, preset, semilla y tamaño de los personajes.
## Se muestra con GameSettings.show_debug_overlay (F4 lo alterna en builds de debug).

var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)


func _process(_delta: float) -> void:
	visible = GameSettings.show_debug_overlay
	if not visible:
		return
	var lines: Array[String] = [
		"%d fps" % Engine.get_frames_per_second(),
		"Calidad: %s  (F1 bajo, F2 medio, F3 alto)" % GameSettings.current_preset.display_name,
		"Semilla: %d" % RunState.seed_value,
		"Jugadores: %d" % PlayerManager.player_count(),
	]
	var camera := get_viewport().get_camera_3d() as SharedCamera
	if camera != null:
		lines.append("Cámara: zoom %.2f, personaje %.0f px" % [camera.current_zoom(), camera.current_character_px()])
	lines.append("F4 oculta esto · F11 pantalla completa")
	_label.text = "\n".join(lines)
