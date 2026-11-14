class_name Sound
extends Node
## Sonido y música placeholder (generados por tools/gen_audio.py). Un solo nodo vive en la raíz
## del árbol (sobrevive a los cambios de escena) y escucha los eventos del juego para sonar solo.
##   Sound.play("coin")            efecto, con un límite para que no sature.
##   Sound.music("birig_bamba")    tema con fundido.
##   Sound.set_combat(true)        en Talinorthland, entra la capa de combate.

const SFX_PATH := "res://assets/audio/sfx/%s.wav"
const MUSIC_PATH := "res://assets/audio/music/%s.wav"
const VOICES := 12
## Mínimo entre dos veces el mismo efecto (segundos).
const MIN_GAP := 0.05
const MUSIC_DB := -9.0
const SFX_DB := -4.0

static var _instance: Sound

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _combat_layer: AudioStreamPlayer
var _current_music: String = ""
var _combat: bool = false


## El nodo de sonido (lo crea la primera vez).
static func get_instance() -> Sound:
	if is_instance_valid(_instance):
		return _instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_instance = Sound.new()
	_instance.name = "Sound"
	tree.root.add_child.call_deferred(_instance)
	return _instance


static func play(sfx: String, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	var sound: Sound = get_instance()
	if sound != null:
		sound._play(sfx, volume_db, pitch_jitter)


static func music(track: String) -> void:
	var sound: Sound = get_instance()
	if sound != null:
		sound._music(track)


static func set_combat(active: bool) -> void:
	var sound: Sound = get_instance()
	if sound != null:
		sound._combat = active


## Se prepara al crearse (antes de entrar al árbol), así se puede usar enseguida.
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_combat_layer = _make_music_player()
	Events.hit_landed.connect(_on_hit_landed)
	Events.enemy_died.connect(func(_enemy: Node3D) -> void: _play("enemy_death", -6.0))
	Events.player_downed.connect(func(_player: Node3D) -> void: _play("player_hurt", 2.0, 0.0))
	Events.ultimate_used.connect(func(_player: Node3D) -> void: _play("ult", -2.0, 0.0))
	Events.gold_changed.connect(_on_gold_changed)
	Events.room_cleared.connect(func() -> void: _play("pickup", -4.0, 0.0))


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _process(delta: float) -> void:
	# La capa de combate entra y sale suave.
	var target: float = MUSIC_DB if _combat and _current_music == "talinorthland_explore" else -60.0
	_combat_layer.volume_db = move_toward(_combat_layer.volume_db, target, delta * 30.0)


func _play(sfx: String, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if not is_inside_tree():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sfx, -1.0)) < MIN_GAP:
		return
	_last_played[sfx] = now
	var stream: AudioStream = _load(SFX_PATH % sfx)
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = SFX_DB + volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func _music(track: String) -> void:
	if not is_inside_tree():
		_music.call_deferred(track)
		return
	if track == _current_music:
		return
	_current_music = track
	var stream: AudioStream = _loop(_load(MUSIC_PATH % track))
	var old: AudioStreamPlayer = _music_a
	_music_a = _music_b
	_music_b = old
	_music_a.stream = stream
	_music_a.volume_db = -40.0
	_music_a.play()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_music_a, "volume_db", MUSIC_DB, 1.2)
	tween.tween_property(_music_b, "volume_db", -60.0, 1.2)
	tween.chain().tween_callback(_music_b.stop)
	# Capa de combate sincronizada con la exploración de Talinorthland.
	_combat_layer.stop()
	if track == "talinorthland_explore":
		_combat_layer.stream = _loop(_load(MUSIC_PATH % "talinorthland_combat"))
		_combat_layer.volume_db = -60.0
		_combat_layer.play()


func _make_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = -60.0
	add_child(player)
	return player


func _load(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


## Los temas se repiten (loop) de punta a punta.
func _loop(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return stream
	var copy: AudioStreamWAV = wav.duplicate()
	copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
	copy.loop_begin = 0
	copy.loop_end = int(wav.get_length() * wav.mix_rate)
	return copy


func _on_hit_landed(info: DamageInfo, target: Node3D) -> void:
	if info.has_tag(&"tick"):
		return
	if target is PlayerCharacter:
		_play("player_hurt", -2.0)
	elif info.attacker_team == DamageInfo.Team.PLAYERS:
		if info.is_crit:
			_play("crit", -3.0)
		else:
			_play("hit_heavy" if info.amount >= 50.0 else "hit", -6.0)


var _last_gold: Dictionary = {}


func _on_gold_changed(slot_index: int, amount: int) -> void:
	if amount > int(_last_gold.get(slot_index, amount)):
		_play("coin", -8.0)
	_last_gold[slot_index] = amount
