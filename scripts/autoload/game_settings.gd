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
var current_preset_id: StringName = DEFAULT_PRESET

# --- Opciones del jugador (menú de Opciones en la pausa, pedido del grupo) ---
## Volúmenes de 0 a 1.
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
## Sacudida de cámara: 0 = nada, 1 = normal (por Remote Play a veces conviene bajarla).
var shake_scale: float = 1.0
var damage_numbers: bool = true
var vibration: bool = true
var fullscreen: bool = false

# --- Flags de debug ---
## Todas las dificultades disponibles sin haberlas desbloqueado (DECISIONES 2026-11-12).
var unlock_all_difficulties: bool = OS.is_debug_build()
var show_debug_overlay: bool = OS.is_debug_build()
## En la sala de prueba los jugadores se levantan solos al caer. En las salas de combate
## no (revivir llega en la Fase 4): si caen todos, se pierde.
var auto_revive_players: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_options()
	set_quality(_load_saved_preset_id())
	apply_audio()
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## Buses de audio para poder bajar música y efectos por separado.
func _ensure_buses() -> void:
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")


func apply_audio() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value
			else DisplayServer.WINDOW_MODE_WINDOWED)
	save_options()


## Guarda las opciones (volúmenes, sacudida, números, vibración, pantalla completa).
func save_options() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("game", "shake", shake_scale)
	config.set_value("game", "damage_numbers", damage_numbers)
	config.set_value("game", "vibration", vibration)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.save(SETTINGS_FILE)


func _load_options() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) != OK:
		return
	master_volume = config.get_value("audio", "master", master_volume)
	music_volume = config.get_value("audio", "music", music_volume)
	sfx_volume = config.get_value("audio", "sfx", sfx_volume)
	shake_scale = config.get_value("game", "shake", shake_scale)
	damage_numbers = config.get_value("game", "damage_numbers", damage_numbers)
	vibration = config.get_value("game", "vibration", vibration)
	fullscreen = config.get_value("graphics", "fullscreen", fullscreen)


## Vibración del joystick (si el jugador la tiene prendida y usa joystick).
func rumble(device: int, weak: float, strong: float, seconds: float) -> void:
	if vibration and device >= 0:
		Input.start_joy_vibration(device, weak, strong, seconds)


func set_quality(id: StringName) -> void:
	if not PRESET_PATHS.has(id):
		push_warning("GameSettings: preset desconocido '%s'" % id)
		id = DEFAULT_PRESET
	current_preset_id = id
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
	set_fullscreen(mode != DisplayServer.WINDOW_MODE_FULLSCREEN)


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
