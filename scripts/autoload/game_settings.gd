extends Node
## Presets de calidad (bajo, medio, alto) y flags de debug.
## La calidad elegida se guarda en user://settings.cfg.
##
## Atajos (solo en builds de debug): F1 bajo, F2 medio, F3 alto, F4 overlay de debug.
## F11 alterna pantalla completa siempre.

const PRESET_PATHS: Dictionary[StringName, String] = {
	&"low": "res://data/quality/low.tres",
	&"medium": "res://data/quality/medium.tres",
	&"high": "res://data/quality/high.tres",
}
const SETTINGS_FILE := "user://settings.cfg"
const DEFAULT_PRESET: StringName = &"high"

var current_preset: QualityPreset

# --- Flags de debug ---
## Todas las dificultades disponibles sin haberlas desbloqueado (DECISIONES 2026-11-12).
var unlock_all_difficulties: bool = OS.is_debug_build()
var show_debug_overlay: bool = OS.is_debug_build()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_quality(_load_saved_preset_id())


func set_quality(id: StringName) -> void:
	if not PRESET_PATHS.has(id):
		push_warning("GameSettings: preset desconocido '%s'" % id)
		id = DEFAULT_PRESET
	current_preset = load(PRESET_PATHS[id]) as QualityPreset
	_apply_to_viewport(current_preset)
	_save_preset_id(id)
	Events.quality_changed.emit(current_preset)


## Las salas llaman a esto con su Environment, al entrar y cuando cambia el preset.
func apply_to_environment(env: Environment) -> void:
	if env == null or current_preset == null:
		return
	env.ssao_enabled = current_preset.ssao
	env.ssil_enabled = current_preset.ssil
	env.glow_enabled = current_preset.glow
	env.fog_enabled = current_preset.fog


func _apply_to_viewport(preset: QualityPreset) -> void:
	var viewport: Viewport = get_viewport()
	viewport.msaa_3d = preset.msaa_3d as Viewport.MSAA
	viewport.scaling_3d_scale = preset.render_scale
	RenderingServer.directional_shadow_atlas_set_size(preset.shadow_atlas_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
			preset.soft_shadow_quality as RenderingServer.ShadowQuality)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F11:
		_toggle_fullscreen()
		return
	if not OS.is_debug_build():
		return
	match key.physical_keycode:
		KEY_F1:
			set_quality(&"low")
		KEY_F2:
			set_quality(&"medium")
		KEY_F3:
			set_quality(&"high")
		KEY_F4:
			show_debug_overlay = not show_debug_overlay


func _toggle_fullscreen() -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _load_saved_preset_id() -> StringName:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) != OK:
		return DEFAULT_PRESET
	return StringName(config.get_value("graphics", "quality", String(DEFAULT_PRESET)))


func _save_preset_id(id: StringName) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)  # si no existe, arranca vacío
	config.set_value("graphics", "quality", String(id))
	config.save(SETTINGS_FILE)
