extends Node3D
## Sala de prueba de Talinorthland: crea a los jugadores en sus puntos de aparición
## y aplica el preset de calidad al entorno.
##
## Si se abre directo desde el editor (F6) sin pasar por la pantalla de unión,
## se une sola: teclado y mouse más todos los joysticks conectados.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player_character.tscn")
const RESULT_SCENE: PackedScene = preload("res://scenes/ui/room_result.tscn")

## Si tiene oleadas, es una sala de combate (se gana o se pierde). Si no, sala de prueba
## con enemigos infinitos.
@export var combat_waves: RoomWaves

@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _spawn_points: Node3D = $SpawnPoints
@onready var _players_root: Node3D = $Players
@onready var _camera: SharedCamera = $SharedCamera

var players: Array[PlayerCharacter] = []
var director: CombatDirector


func _ready() -> void:
	GameSettings.apply_to_environment(_environment.environment)
	Events.quality_changed.connect(_on_quality_changed)
	Events.room_tint_requested.connect(_on_room_tint)
	if PlayerManager.player_count() == 0:
		_auto_join_for_testing()
	GameSettings.auto_revive_players = combat_waves == null
	_spawn_players()
	if combat_waves != null:
		_start_combat()
	Fx.prewarm(_camera_focus_node())


func _camera_focus_node() -> Node3D:
	return _players_root


func _spawn_players() -> void:
	var camera_targets: Array[Node3D] = []
	for slot: PlayerSlot in PlayerManager.active_slots():
		var player: PlayerCharacter = PLAYER_SCENE.instantiate()
		player.setup(slot)
		var spawn: Node3D = _spawn_points.get_child(slot.index) as Node3D
		player.position = spawn.position if spawn != null else Vector3.ZERO
		player.velocity_limiter = _camera.limit_velocity.bind(player)
		_players_root.add_child(player)
		player.reset_physics_interpolation()
		players.append(player)
		camera_targets.append(player)
	_camera.set_targets(camera_targets)


func _auto_join_for_testing() -> void:
	PlayerManager.reset()
	PlayerManager.join(true)
	for device: int in Input.get_connected_joypads():
		PlayerManager.join(false, device)
	PlayerManager.joining_open = false
	RunState.start_run()


func _on_quality_changed(_preset: QualityPreset) -> void:
	GameSettings.apply_to_environment(_environment.environment)


## Tiñe la luz del sol un rato y la vuelve a su color.
func _on_room_tint(color: Color, duration: float) -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		return
	if not has_meta(&"sun_color"):
		set_meta(&"sun_color", sun.light_color)
		set_meta(&"sun_energy", sun.light_energy)
	var base_color: Color = get_meta(&"sun_color")
	var base_energy: float = get_meta(&"sun_energy")
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sun, "light_color", base_color.lerp(color, 0.7), 0.4)
	tween.tween_property(sun, "light_energy", base_energy * 0.7, 0.4)
	tween.chain().tween_interval(maxf(duration - 0.8, 0.0))
	tween.chain().set_parallel(true)
	tween.tween_property(sun, "light_color", base_color, 0.4)
	tween.tween_property(sun, "light_energy", base_energy, 0.4)
	# Velo de color sobre la escena (debajo del HUD), porque el cielo sigue iluminando.
	var layer := CanvasLayer.new()
	layer.layer = 1
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(color.darkened(0.3), 0.0)
	layer.add_child(veil)
	add_child(layer)
	var veil_tween: Tween = create_tween()
	veil_tween.tween_property(veil, "color:a", 0.22, 0.4)
	veil_tween.tween_interval(maxf(duration - 0.8, 0.0))
	veil_tween.tween_property(veil, "color:a", 0.0, 0.4)
	veil_tween.tween_callback(layer.queue_free)


func _start_combat() -> void:
	var spawner := get_node_or_null("EnemySpawner") as EnemySpawner
	if spawner != null:
		spawner.queue_free()
	director = CombatDirector.new()
	director.name = "CombatDirector"
	director.waves = combat_waves
	add_child(director)
	var result: CanvasLayer = RESULT_SCENE.instantiate()
	add_child(result)
	director.room_cleared.connect(result.show_result.bind(true))
	director.room_failed.connect(result.show_result.bind(false))
