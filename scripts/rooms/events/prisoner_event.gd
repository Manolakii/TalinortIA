class_name PrisonerEvent
extends Node3D
## Evento "Colonia de presos" (GDD): jaulas con Talinorteanos conscientes mientras los Aguccis
## atacan. Hay un tiempo límite para liberarlos (pedido del grupo: que sea difícil); los que
## sigan en la jaula cuando se acaba se los llevan. Si se salva a todos es "perfecto" (mejora
## de 4 y un objeto extra). Pedido del grupo: las jaulas están bien separadas y, liberados
## todos, hay que aguantar una súper oleada (`defense_time` s); recién ahí sale el cofre.

## `won`: salvaron a todos (y abrieron el cofre). Si no, se pierde el evento y no hay premio.
signal resolved(won: bool)
## Se terminó el evento (se acabó el tiempo): hay que cortar la pelea.
signal ended
## Liberaron a todos: arranca la defensa (la sala manda la súper oleada).
signal defense_started(time: float)

## Zona donde pueden ir las jaulas (lejos de la entrada, abajo, y de las puertas, arriba).
const CAGE_AREA := Rect2(-19.0, -10.0, 38.0, 17.0)
const ENTRY := Vector3(0, 0, 11.0)
const ROCK_CLEARANCE := 3.5
const ENTRY_CLEARANCE := 7.0

var _cages: Array[PrisonerCage] = []
var _saved: int = 0
var _chest_spot: Vector3
var _gold: int = 6
var _time_left: float = 35.0
var _timer_label: Label
var _timer_over: bool = false
var _finished: bool = false
## Defensa después de liberar a todos (0 = sin defensa: gana al instante, como antes).
var defense_time: float = 0.0
var _defending: bool = false
var _defense_left: float = 0.0


func setup(spots: Array[Vector3], count: int, open_time: float, gold: int, chest_spot: Vector3,
		time_limit: float = 35.0) -> void:
	_chest_spot = chest_spot
	_gold = gold
	_time_left = time_limit
	var layer := CanvasLayer.new()
	layer.layer = 31
	add_child(layer)
	_timer_label = Label.new()
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timer_label.offset_top = 92.0
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 34)
	_timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_timer_label.add_theme_constant_override("outline_size", 10)
	layer.add_child(_timer_label)
	for i: int in mini(count, spots.size()):
		var cage := PrisonerCage.new()
		cage.open_time = open_time
		cage.position = spots[i]
		add_child(cage)
		cage.freed.connect(_on_freed.bind(cage))
		_cages.append(cage)
	var title := Label3D.new()
	title.text = "¡Liberá a los presos antes de que se los lleven!"
	title.font_size = 42
	title.outline_size = 12
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.position = Vector3(0, 4.0, 0)
	add_child(title)
	var fade: Tween = title.create_tween()
	fade.tween_interval(6.0)
	fade.tween_property(title, "modulate:a", 0.0, 1.0)


## Lugares para las jaulas: `count` puntos libres (sin rocas ni cosas en `avoid`), separados
## por al menos `spacing` si se puede (si no, lo más lejos posible entre sí).
static func spread_spots(count: int, avoid: Array[Vector3], spacing: float,
		rng: RandomNumberGenerator) -> Array[Vector3]:
	var candidates: Array[Vector3] = []
	var x: float = CAGE_AREA.position.x
	while x <= CAGE_AREA.end.x + 0.01:
		var z: float = CAGE_AREA.position.y
		while z <= CAGE_AREA.end.y + 0.01:
			var point := Vector3(x, 0, z)
			var free: bool = _flat_distance(point, ENTRY) >= ENTRY_CLEARANCE
			for blocked: Vector3 in avoid:
				if _flat_distance(point, blocked) < ROCK_CLEARANCE:
					free = false
					break
			if free:
				candidates.append(point)
			z += 1.0
		x += 1.0
	var result: Array[Vector3] = []
	while result.size() < count and not candidates.is_empty():
		var far_enough: Array[Vector3] = []
		var best := Vector3.ZERO
		var best_gap: float = -1.0
		for point: Vector3 in candidates:
			var gap: float = INF
			for chosen: Vector3 in result:
				gap = minf(gap, _flat_distance(point, chosen))
			if gap >= spacing:
				far_enough.append(point)
			if gap > best_gap:
				best_gap = gap
				best = point
		var pick: Vector3 = far_enough[rng.randi_range(0, far_enough.size() - 1)] 				if not far_enough.is_empty() else best
		result.append(pick)
		candidates.erase(pick)
	return result


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _physics_process(delta: float) -> void:
	if _defending:
		_defense_tick(delta)
		return
	if _timer_over:
		return
	_time_left -= delta
	var left: int = 0
	for cage: PrisonerCage in _cages:
		if is_instance_valid(cage) and not cage.is_free and not cage.is_lost:
			left += 1
	if left == 0:
		_timer_over = true
		if defense_time > 0.0:
			_defending = true
			_defense_left = defense_time
			Events.floating_text_requested.emit(_chest_spot + Vector3.UP * 3.0,
					"¡Liberaron a todos! Ahora defiéndanse", Color(1.0, 0.82, 0.3))
			defense_started.emit(defense_time)
			return
		_timer_label.text = "¡Liberaron a todos! Los Aguccis salen corriendo"
		_timer_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
		_hide_timer_later()
		ended.emit()
		return
	_timer_label.text = "Presos: %d · ¡Quedan %d s!" % [left, ceili(maxf(_time_left, 0.0))]
	_timer_label.add_theme_color_override("font_color",
			Color(1.0, 0.45, 0.3) if _time_left < 10.0 else Color.WHITE)
	if _time_left <= 0.0:
		_timer_over = true
		_lose_remaining()
		_timer_label.text = "Se acabó el tiempo: se llevaron a %d" % left
		_hide_timer_later()
		ended.emit()


## Cuenta de la defensa (la termina la sala cuando se acaba el aguante del director).
func _defense_tick(delta: float) -> void:
	_defense_left = maxf(_defense_left - delta, 0.0)
	_timer_label.text = "¡Súper oleada! Aguanten %d s" % ceili(_defense_left)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))


func is_defending() -> bool:
	return _defending and not _finished


func _lose_remaining() -> void:
	for cage: PrisonerCage in _cages:
		if is_instance_valid(cage):
			cage.lose()


## Los liberados que se quedaron peleando se despiden.
func _dismiss_freed() -> void:
	for cage: PrisonerCage in _cages:
		if is_instance_valid(cage):
			cage.dismiss()


func _hide_timer_later() -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_timer_label, "modulate:a", 0.0, 0.5)


func _on_freed(_cage: PrisonerCage) -> void:
	_saved += 1


## Terminó la pelea: los que quedan se pierden y aparece el cofre de evento.
func finish_combat() -> void:
	if _finished:
		return
	_finished = true
	_timer_over = true
	_defending = false
	_lose_remaining()
	_dismiss_freed()
	_timer_label.modulate.a = 0.0
	var all_saved: bool = saved_count() == _cages.size()
	if not all_saved:
		Events.floating_text_requested.emit(_chest_spot + Vector3.UP * 3.0,
				"Salvaron a %d de %d: perdieron el evento" % [saved_count(), _cages.size()], Color(0.8, 0.8, 0.85))
		resolved.emit(false)
		return
	Events.floating_text_requested.emit(_chest_spot + Vector3.UP * 3.0, "¡Salvaron a todos!", Color(1.0, 0.82, 0.3))
	var chest := Chest.new()
	chest.gold_table = Balance.economy.event_chest_gold
	chest.position = _chest_spot
	add_child(chest)
	chest.opened.connect(func(_by: PlayerCharacter) -> void:
		# Los presos agradecidos también ponen su parte.
		Loot.drop_for_all(self, _chest_spot, [_gold * _cages.size()])
		resolved.emit(true))


func saved_count() -> int:
	return _saved
